extends Node
## Pacing bot: plays a fresh game with real physics, following a reasonable build order, and logs milestones.
## Run: godot --headless --path . res://tests/Bot.tscn --fixed-fps 60 -- [minutes]

var world: Node
var frames := 0
var minutes := 40.0
var rows: Array = []          # free rows: {x0, z}
var lines: Array = []         # {type, x0, z, stage}
var think := 0.0
var level_times := {}
var log_every := 300.0
var next_log := 0.0
var t0 := 0


func _ready() -> void:
	Game.save_enabled = false
	Game.new_game()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		minutes = float(args[0])
	world = load("res://scripts/World.gd").new()
	add_child(world)
	await get_tree().process_frame
	world.hud.close_panel()
	_refresh_rows()
	t0 = Time.get_ticks_msec()


func gt() -> float:
	return frames / 60.0


func _refresh_rows() -> void:
	rows.clear()
	for p in Game.plots:
		for dz in [-3, -1, 1, 3]:
			var row := {"x0": p.x * 8 - 4, "z": p.y * 8 + dz}
			var used := false
			for l in lines:
				if l.x0 == row.x0 and l.z == row.z:
					used = true
			if not used:
				rows.append(row)


func cell(l: Dictionary, i: int, y: int = 0) -> Vector3i:
	return Vector3i(int(l.x0) + i, y, int(l.z))


func replace(l: Dictionary, i: int, id: String, cfg: Dictionary = {}) -> bool:
	if not Game.part_unlocked(id) and not Game.try_unlock(id):
		return false
	if not Game.can_afford(Game.part_cost(id) + 5.0):
		return false
	var old: Part = world.cells.get(cell(l, i))
	if old != null:
		world.remove(old, true)
	return world.place(id, cell(l, i), 1, true, -1.0, cfg) != null


func build_line(kind: String) -> bool:
	if rows.is_empty():
		return false
	var r: Dictionary = rows[0]
	var l := {"type": kind, "x0": r.x0, "z": r.z, "stage": 0}
	var ids := []
	if kind == "wood":
		ids = ["treefarm_oak", "conveyor", "conveyor", "conveyor", "conveyor", "conveyor", "conveyor", "seller"]
	else:
		ids = ["conveyor", "crusher", "conveyor", "furnace", "conveyor", "conveyor", "conveyor", "seller"]
	var cost := 0.0
	for id in ids:
		cost += Game.part_cost(id)
	if kind == "metal":
		cost += Game.part_cost("drill_copper")
	for id in ids:
		if not Game.part_unlocked(id):
			cost += float(Defs.PARTS[id].unlock)
	if not Game.can_afford(cost * 1.05):
		return false
	for id in ids:
		if not Game.part_unlocked(id) and not Game.try_unlock(id):
			return false
	if kind == "metal" and not Game.part_unlocked("drill_copper") and not Game.try_unlock("drill_copper"):
		return false
	for i in ids.size():
		world.place(ids[i], cell(l, i), 1, true)
	if kind == "metal":
		world.place("drill_copper", cell(l, 0, 1), 1, true)
	lines.append(l)
	rows.remove_at(0)
	return true


func _think() -> void:
	# 1. upgrade existing lines
	for l in lines:
		if l.type == "wood":
			if l.stage == 0 and Game.level >= 1 and replace(l, 3, "rip_saw", {"offset": 0.0}):
				l.stage = 1
			elif l.stage == 1 and replace(l, 4, "rip_saw", {"offset": 0.075}):
				l.stage = 2
			elif l.stage == 2 and replace(l, 5, "rip_saw", {"offset": -0.075}):
				l.stage = 3
		else:
			if l.stage == 0 and Game.level >= 6 and replace(l, 5, "press"):
				l.stage = 1
			elif l.stage == 1 and replace(l, 6, "press"):
				l.stage = 2
	# 2. global upgrades when cheap relative to wallet
	for id in ["sell_value", "src_speed", "machine_speed", "belt_speed", "item_cap"]:
		var c := Game.upgrade_cost(id, Game.upg(id))
		if c < Game.money * 0.1 and Game.upg(id) < int(Defs.UPGRADES[id].max):
			Game.buy_upgrade(id, 1)
	# 3. new lines (alternate wood/metal once metal is available)
	var metal_count := 0
	for l in lines:
		if l.type == "metal":
			metal_count += 1
	var want := "metal" if Game.level >= 3 and metal_count * 2 < lines.size() else "wood"
	var built := build_line(want)
	if not built and want == "metal" and Game.money > 20000.0:
		built = false
	elif not built and want == "metal":
		built = build_line("wood")
	if not built:
		if rows.is_empty():
			# 4. buy land
			for i in range(-2, 3):
				for j in range(-2, 3):
					var p := Vector2i(i, j)
					if Game.can_buy_plot(p) and Game.can_afford(Game.plot_cost()) and Defs.plot_biome(p) == "meadow":
						if Game.buy_plot(p):
							_refresh_rows()
							return
	# 5. part upgrades on sources with leftover money
	if Game.level >= 4:
		for p in world.parts:
			if p.kind() == "source" and p.can_upgrade() and p.upgrade_cost() < Game.money * 0.05:
				world.upgrade_part(p)


func _physics_process(delta: float) -> void:
	frames += 1
	think += delta
	if think >= 1.0:
		think = 0.0
		_think()
	if not level_times.has(Game.level):
		level_times[Game.level] = gt()
		print("BOT t=%5.1fmin  reached level %d  (money %s, income %s/s, lines %d, quests %d)" % [gt() / 60.0, Game.level, Util.money(Game.money), Util.money(Game.income_rate), lines.size(), Game.quest_index])
	if gt() >= next_log:
		next_log += log_every
		print("BOT t=%5.1fmin  money %s  income %s/s  level %d  parts %d  items %d  plots %d  orders %d  wall %.0fs" % [gt() / 60.0, Util.money(Game.money), Util.money(Game.income_rate), Game.level, world.parts.size(), world.active_items.size(), Game.plots.size(), int(Game.stats.orders), (Time.get_ticks_msec() - t0) / 1000.0])
	if gt() >= minutes * 60.0:
		print("BOT DONE: forms ", Game.forms_sold)
		print("BOT DONE: demand ", Game.demand_map)
		get_tree().quit()
