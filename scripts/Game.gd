extends Node
## Global game state: economy, unlocks, upgrades, land, quests, prestige and save/load.

signal toast(text: String, color: Color)
signal level_up(level: int)
signal plots_changed
signal upgrades_changed
signal unlocks_changed
signal quests_changed
signal stars_changed
signal settings_changed
signal orders_changed

const SAVE_PATH := "user://factory_save.json"
const SAVE_VERSION := 1
const COST_GROWTH := 1.012
const START_MONEY := 100.0
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
const AUTOSAVE_EVERY := 20.0

var world: Node = null

var money := START_MONEY
var lifetime := 0.0
var stars := 0
var level := 0
var unlocked := {}
var upgrades := {}
var plots := {Vector2i(0, 0): true}
var part_counts := {}
var stats := {"sold": 0, "upgrades": 0, "ascensions": 0, "placed": 0, "part_upgrades": 0, "ingots": 0, "orders": 0}
var quest_index := 0
var play_time := 0.0
var income_rate := 0.0
var settings := {"shadows": true, "volume": 0.7, "music": 0.45, "seen_help": false, "show_fps": false}
var saved_buildings: Array = []
var saved_links: Array = []
var demand_map := {}
var forms_sold := {}
var orders: Array = []
var _order_timer := 5.0
var blueprints := {}
var offline_report := {}
var save_enabled := true

var _sales_acc := 0.0
var _rate_timer := 0.0
var _autosave := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_state()
	load_game()
	_apply_volume()


func _reset_state() -> void:
	money = START_MONEY
	upgrades = {}
	plots = {Vector2i(0, 0): true}
	part_counts = {}
	_unlock_free_parts()


func _unlock_free_parts() -> void:
	for id in Defs.PARTS:
		if float(Defs.PARTS[id].unlock) <= 0.0:
			unlocked[id] = true


func _process(delta: float) -> void:
	play_time += delta
	_rate_timer += delta
	if _rate_timer >= 0.5:
		var inst := _sales_acc / _rate_timer
		income_rate = lerpf(income_rate, inst, 0.25)
		if income_rate < 0.01 and inst == 0.0:
			income_rate = 0.0
		_sales_acc = 0.0
		_rate_timer = 0.0
		check_quests()
	_tick_market(delta)
	_autosave += delta
	if _autosave >= AUTOSAVE_EVERY:
		_autosave = 0.0
		save_game()


# ---------------------------------------------------------------- economy

func add_money(v: float) -> void:
	money += v
	lifetime += v
	_sales_acc += v
	var l := level_for(lifetime)
	if l > level:
		level = l
		level_up.emit(level)
		toast.emit("Factory level %d reached!" % level, Color("ffcf4a"))
		FX.play("levelup")


func add_bonus(v: float) -> void:
	money += v


func can_afford(v: float) -> bool:
	return money + 0.0001 >= v


func spend(v: float) -> bool:
	if money + 0.0001 < v:
		return false
	money -= v
	return true


static func level_for(earned: float) -> int:
	return int(floor(log(1.0 + earned / 50.0) / log(2.5)))


static func level_floor_xp(l: int) -> float:
	return 50.0 * (pow(2.5, l) - 1.0)


func level_progress() -> float:
	var a := level_floor_xp(level)
	var b := level_floor_xp(level + 1)
	return clampf((lifetime - a) / (b - a), 0.0, 1.0)


func upg(id: String) -> int:
	return int(upgrades.get(id, 0))


func star_mult() -> float:
	return 1.0 + 0.25 * stars


func sell_mult() -> float:
	return (1.0 + float(Defs.UPGRADES.sell_value.per) * upg("sell_value")) * star_mult()


func src_mult() -> float:
	return 1.0 + float(Defs.UPGRADES.src_speed.per) * upg("src_speed")


func belt_mult() -> float:
	return 1.0 + float(Defs.UPGRADES.belt_speed.per) * upg("belt_speed")


func machine_mult() -> float:
	return 1.0 + float(Defs.UPGRADES.machine_speed.per) * upg("machine_speed")


func item_cap() -> int:
	return 250 + int(float(Defs.UPGRADES.item_cap.per) * upg("item_cap"))


func offline_eff() -> float:
	return minf(1.0, 0.2 + 0.04 * level + float(Defs.UPGRADES.night_shift.per) * upg("night_shift"))


# ---------------------------------------------------------------- upgrades

func upgrade_cost(id: String, lvl: int) -> float:
	var d: Dictionary = Defs.UPGRADES[id]
	return roundf(float(d.base) * pow(float(d.growth), lvl))


func upgrade_cost_n(id: String, n: int) -> float:
	var total := 0.0
	var l := upg(id)
	for i in n:
		total += upgrade_cost(id, l + i)
	return total


func upgrade_max_affordable(id: String) -> int:
	var d: Dictionary = Defs.UPGRADES[id]
	var l := upg(id)
	var m: int = d.max
	var n := 0
	var budget := money
	while l + n < m:
		var c := upgrade_cost(id, l + n)
		if c > budget:
			break
		budget -= c
		n += 1
	return n


func buy_upgrade(id: String, qty: int) -> int:
	var d: Dictionary = Defs.UPGRADES[id]
	var bought := 0
	var want := qty
	if qty < 0:
		want = upgrade_max_affordable(id)
	for i in want:
		var l := upg(id)
		if l >= int(d.max):
			break
		var c := upgrade_cost(id, l)
		if not spend(c):
			break
		upgrades[id] = l + 1
		bought += 1
	if bought > 0:
		stats.upgrades += bought
		upgrades_changed.emit()
		FX.play("buy")
	elif upg(id) < int(d.max):
		FX.play("error")
	return bought


# ---------------------------------------------------------------- parts

func part_cost(id: String) -> float:
	return float(Defs.PARTS[id].cost) * pow(COST_GROWTH, int(part_counts.get(id, 0)))


func cost_of_n(id: String, n: int) -> float:
	if n <= 0:
		return 0.0
	var base := part_cost(id)
	return base * (pow(COST_GROWTH, n) - 1.0) / (COST_GROWTH - 1.0)


func part_unlocked(id: String) -> bool:
	return unlocked.has(id)


func part_biome_ok(id: String) -> bool:
	var d: Dictionary = Defs.PARTS[id]
	if not d.has("mat"):
		return true
	return owns_biome(Defs.MATERIALS[d.mat].biome)


func owns_biome(b: String) -> bool:
	for p in plots:
		if Defs.plot_biome(p) == b:
			return true
	return false


func unlock_block_reason(id: String) -> String:
	var d: Dictionary = Defs.PARTS[id]
	if level < int(d.level):
		return "Reach factory level %d" % int(d.level)
	if not part_biome_ok(id):
		var b: String = Defs.MATERIALS[d.mat].biome
		return "Buy a %s plot first" % Defs.BIOMES[b].name
	return ""


func try_unlock(id: String) -> bool:
	if unlocked.has(id):
		return true
	var reason := unlock_block_reason(id)
	if reason != "":
		toast.emit(reason, Color("ff7a7a"))
		FX.play("error")
		return false
	var cost: float = Defs.PARTS[id].unlock
	if not spend(cost):
		toast.emit("Need %s to unlock %s" % [Util.money(cost), Defs.PARTS[id].name], Color("ff7a7a"))
		FX.play("error")
		return false
	unlocked[id] = true
	unlocks_changed.emit()
	toast.emit("Unlocked %s!" % Defs.PARTS[id].name, Color("7aff9a"))
	FX.play("levelup")
	return true


func on_part_added(id: String) -> void:
	part_counts[id] = int(part_counts.get(id, 0)) + 1
	stats.placed += 1


func on_part_removed(id: String) -> void:
	part_counts[id] = maxi(0, int(part_counts.get(id, 0)) - 1)


func count_cat(cat: String) -> int:
	var n := 0
	for id in part_counts:
		if Defs.PARTS[id].cat == cat:
			n += int(part_counts[id])
	return n


func part_upgrade_cost(id: String, level: int) -> float:
	return float(Defs.PARTS[id].cost) * 1.5 * pow(1.9, level)


# ---------------------------------------------------------------- land

func plot_cost() -> float:
	return 300.0 * pow(1.75, plots.size() - 1)


func can_buy_plot(p: Vector2i) -> bool:
	if plots.has(p) or not Defs.plot_in_range(p):
		return false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if (dx != 0 or dy != 0) and plots.has(p + Vector2i(dx, dy)):
				return true
	return false


func buy_plot(p: Vector2i) -> bool:
	if not can_buy_plot(p):
		FX.play("error")
		return false
	if not spend(plot_cost()):
		toast.emit("Not enough money for this land", Color("ff7a7a"))
		FX.play("error")
		return false
	plots[p] = true
	plots_changed.emit()
	unlocks_changed.emit()
	FX.play("buy")
	toast.emit("New land acquired: %s" % Defs.BIOMES[Defs.plot_biome(p)].name, Color("7aff9a"))
	return true


# ---------------------------------------------------------------- prestige

func ascend_stars_total() -> int:
	return int(floor(sqrt(lifetime / 2000000.0)))


func ascend_gain() -> int:
	return maxi(0, ascend_stars_total() - stars)


func ascend() -> bool:
	var gain := ascend_gain()
	if gain <= 0:
		return false
	stars += gain
	stats.ascensions += 1
	_reset_state()
	money = START_MONEY + 250.0 * stars
	saved_buildings = []
	saved_links = []
	if world:
		world.clear_all(false)
	plots_changed.emit()
	upgrades_changed.emit()
	unlocks_changed.emit()
	stars_changed.emit()
	toast.emit("Ascended! +%d stars (x%.2f income)" % [gain, star_mult()], Color("ffcf4a"))
	FX.play("levelup")
	save_game()
	return true


# ---------------------------------------------------------------- market & orders

func demand(key: String) -> float:
	return float(demand_map.get(key, 1.0))


func _saturation_per_sale() -> float:
	return 0.002 / (1.0 + float(Defs.UPGRADES.marketing.per) * upg("marketing"))


func _recovery_rate() -> float:
	return 0.03 * (1.0 + 2.0 * float(Defs.UPGRADES.marketing.per) * upg("marketing"))


func on_sold(it: Item, amount: float) -> void:
	stats.sold += 1
	var key := it.product_key()
	demand_map[key] = maxf(0.35, demand(key) - _saturation_per_sale())
	forms_sold[it.form] = int(forms_sold.get(it.form, 0)) + 1
	for o in orders:
		if String(o.key) == key and int(o.done) < int(o.qty):
			o.done = int(o.done) + 1
			if int(o.done) >= int(o.qty):
				add_bonus(float(o.reward))
				stats.orders = int(stats.get("orders", 0)) + 1
				toast.emit("Order complete: %s  +%s" % [o.name, Util.money(float(o.reward))], Color("7aff9a"))
				FX.play("quest")
			orders_changed.emit()
			break


func _tick_market(delta: float) -> void:
	var r := _recovery_rate()
	for k in demand_map.keys():
		var d: float = demand_map[k]
		d += (1.0 - d) * r * delta
		if d > 0.999:
			demand_map.erase(k)
		else:
			demand_map[k] = d
	var changed := false
	for i in range(orders.size() - 1, -1, -1):
		var o: Dictionary = orders[i]
		if int(o.done) >= int(o.qty):
			orders.remove_at(i)
			changed = true
			continue
		o.time = float(o.time) - delta
		if float(o.time) <= 0.0:
			orders.remove_at(i)
			changed = true
	_order_timer -= delta
	if _order_timer <= 0.0:
		_order_timer = 40.0
		if orders.size() < 3:
			var o := _make_order()
			if not o.is_empty():
				orders.append(o)
				changed = true
				toast.emit("New order: %d x %s" % [int(o.qty), o.name], Color("8fd0ff"))
	if changed:
		orders_changed.emit()


const ORDER_FORMS := {
	"wood": [["log", 0, 0.12], ["timber", 1, 0.06], ["plank", 1, 0.012]],
	"ore": [["boulder", 1, 0.02], ["chunk", 2, 0.002], ["ingot", 3, 0.0054], ["plate", 6, 0.0054], ["sheet", 6, 0.0054]],
	"gem": [["shard", 8, 0.002], ["polished", 8, 0.0018]],
	"sand": [["ingot", 5, 0.0054], ["plate", 6, 0.0054]],
}


func available_materials() -> Array:
	var out := []
	for id in Defs.PARTS:
		var d: Dictionary = Defs.PARTS[id]
		if d.kind == "source" and part_counts.get(id, 0) > 0:
			if not out.has(d.mat):
				out.append(d.mat)
	return out


func _make_order() -> Dictionary:
	var mats := available_materials()
	if mats.is_empty():
		return {}
	var cands := []
	for m in mats:
		var c := Defs.mat_cat(m)
		for f in ORDER_FORMS.get(c, []):
			if level >= int(f[1]):
				cands.append([m, f[0], f[2]])
	if cands.is_empty():
		return {}
	var pick: Array = cands[randi() % cands.size()]
	var m: String = pick[0]
	var f: String = pick[1]
	var est := float(Defs.MATERIALS[m].price) * float(pick[2]) * float(Defs.FORM_MULT[f]) * sell_mult()
	var qty := randi_range(8, 30) + level * 2
	var reward := maxf(50.0, est * qty * 3.0)
	return {"key": m + ":" + f, "name": Defs.product_name(m, f), "qty": qty, "done": 0, "reward": reward, "time": 600.0, "total": 600.0}


# ---------------------------------------------------------------- quests

func stat_value(stat: String) -> float:
	if stat.begins_with("form:"):
		return float(forms_sold.get(stat.substr(5), 0))
	if stat.begins_with("part:"):
		return float(part_counts.get(stat.substr(5), 0))
	match stat:
		"sources": return count_cat("production")
		"links": return world.links.size() if world else 0
		"ingots": return stats.get("ingots", 0)
		"orders": return stats.get("orders", 0)
		"droppers": return count_cat("droppers")
		"sellers": return count_cat("sellers")
		"processors": return count_cat("processors")
		"parts":
			var n := 0
			for id in part_counts:
				n += int(part_counts[id])
			return n
		"sold": return stats.sold
		"earned": return lifetime
		"level": return level
		"plots": return plots.size()
		"upgrades": return stats.upgrades
		"part_upgrades": return stats.part_upgrades
		"stars": return stars
		"income": return income_rate
	return 0.0


func current_quest() -> Dictionary:
	if quest_index >= Defs.QUESTS.size():
		return {}
	return Defs.QUESTS[quest_index]


func check_quests() -> void:
	var guard := 0
	while quest_index < Defs.QUESTS.size() and guard < 8:
		var q: Dictionary = Defs.QUESTS[quest_index]
		if stat_value(q.stat) < float(q.target):
			break
		add_bonus(float(q.reward))
		toast.emit("Quest complete: %s  +%s" % [q.desc, Util.money(float(q.reward))], Color("7aff9a"))
		FX.play("quest")
		quest_index += 1
		quests_changed.emit()
		guard += 1


# ---------------------------------------------------------------- settings

func set_setting(key: String, v: Variant) -> void:
	settings[key] = v
	if key == "volume":
		_apply_volume()
	if key == "music":
		FX.apply_music_volume()
	settings_changed.emit()


func _apply_volume() -> void:
	var v: float = settings.volume
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))


# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	var plot_list := []
	for p in plots:
		plot_list.append([p.x, p.y])
	return {
		"version": SAVE_VERSION,
		"money": money, "lifetime": lifetime, "stars": stars,
		"unlocked": unlocked.keys(), "upgrades": upgrades,
		"plots": plot_list, "stats": stats, "quest_index": quest_index,
		"play_time": play_time, "income_rate": income_rate, "settings": settings,
		"saved_at": Time.get_unix_time_from_system(),
		"blueprints": blueprints,
		"links": world.serialize_links() if world else saved_links,
		"forms_sold": forms_sold, "orders": orders,
		"buildings": world.serialize() if world else saved_buildings,
	}


func save_game() -> void:
	if not save_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(to_dict()))
	f.close()


func load_game() -> void:
	if not save_enabled or not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	money = float(d.get("money", START_MONEY))
	lifetime = float(d.get("lifetime", 0.0))
	stars = int(d.get("stars", 0))
	level = level_for(lifetime)
	unlocked = {}
	for id in d.get("unlocked", []):
		if Defs.PARTS.has(id):
			unlocked[id] = true
	_unlock_free_parts()
	upgrades = {}
	var up: Dictionary = d.get("upgrades", {})
	for k in up:
		if Defs.UPGRADES.has(k):
			upgrades[k] = int(up[k])
	plots = {}
	for p in d.get("plots", [[0, 0]]):
		plots[Vector2i(int(p[0]), int(p[1]))] = true
	if plots.is_empty():
		plots[Vector2i(0, 0)] = true
	var st: Dictionary = d.get("stats", {})
	for k in st:
		stats[k] = int(st[k])
	quest_index = int(d.get("quest_index", 0))
	play_time = float(d.get("play_time", 0.0))
	income_rate = float(d.get("income_rate", 0.0))
	var se: Dictionary = d.get("settings", {})
	for k in se:
		settings[k] = se[k]
	saved_buildings = d.get("buildings", [])
	blueprints = d.get("blueprints", {})
	saved_links = d.get("links", [])
	forms_sold = d.get("forms_sold", {})
	orders = d.get("orders", [])
	# offline progress
	var away := clampf(Time.get_unix_time_from_system() - float(d.get("saved_at", 0.0)), 0.0, MAX_OFFLINE_SECONDS)
	if away > 60.0 and income_rate > 0.0:
		var earned := income_rate * away * offline_eff()
		money += earned
		lifetime += earned
		level = level_for(lifetime)
		offline_report = {"seconds": away, "earned": earned}


func new_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	lifetime = 0.0
	level = 0
	stars = 0
	unlocked = {}
	stats = {"sold": 0, "upgrades": 0, "ascensions": 0, "placed": 0, "part_upgrades": 0, "ingots": 0, "orders": 0}
	forms_sold = {}
	orders = []
	demand_map = {}
	quest_index = 0
	income_rate = 0.0
	saved_buildings = []
	saved_links = []
	offline_report = {}
	_reset_state()
	if world:
		world.clear_all(false)
	plots_changed.emit()
	upgrades_changed.emit()
	unlocks_changed.emit()
	stars_changed.emit()
	quests_changed.emit()
