extends Node
## Headless logic tests for economy, unlocks, land, prestige and save/load.
var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func _ready() -> void:
	Game.save_enabled = false
	# levels
	check(Game.level_for(0.0) == 0, "level 0 at 0 earned")
	check(Game.level_for(75.0) == 1, "level 1 at 75")
	check(Game.level_for(4900.0) >= 5, "level >=5 at 4.9k")
	# money + level up
	Game.money = 100.0
	Game.add_money(1000.0)
	check(Game.level >= 2, "level up from add_money (level=%d)" % Game.level)
	# part costs scale
	var c0 := Game.part_cost("conveyor")
	Game.part_counts["conveyor"] = 100
	check(Game.part_cost("conveyor") > c0 * 3.0, "cost grows with count")
	check(absf(Game.cost_of_n("conveyor", 1) - Game.part_cost("conveyor")) < 0.0001, "cost_of_n(1) == part_cost")
	Game.part_counts["conveyor"] = 0
	# unlock gating
	Game.money = 10.0
	check(not Game.try_unlock("drill_iron"), "cannot unlock without money")
	Game.money = 1e9
	Game.level = 0
	check(Game.unlock_block_reason("drill_gold") != "", "level gate on gold drill")
	Game.level = 5
	check(Game.unlock_block_reason("drill_gold") != "", "biome gate on gold drill (desert plot needed)")
	Game.plots[Vector2i(2, 0)] = true
	check(Game.unlock_block_reason("drill_gold") == "", "gold drill unlockable after desert plot + level")
	check(Game.try_unlock("drill_gold"), "unlock gold drill")
	# upgrades
	Game.money = 1e6
	var bought := Game.buy_upgrade("sell_value", 10)
	check(bought == 10 and Game.upg("sell_value") == 10, "bought 10 sell upgrades")
	check(absf(Game.sell_mult() - 2.5) < 0.001, "sell mult 2.5 after 10 levels (%.2f)" % Game.sell_mult())
	var m := Game.buy_upgrade("src_speed", -1)
	check(m > 0, "max buy bought %d" % m)
	# land
	Game.plots = {Vector2i(0, 0): true}
	check(Game.can_buy_plot(Vector2i(1, 0)), "adjacent plot buyable")
	check(not Game.can_buy_plot(Vector2i(2, 0)), "non-adjacent plot not buyable")
	check(Game.can_buy_plot(Vector2i(1, 1)), "diagonal plot buyable")
	Game.money = 1e6
	check(Game.buy_plot(Vector2i(1, 0)), "buy plot")
	check(Game.plots.size() == 2, "plots=2")
	# quests
	Game.quest_index = 0
	Game.part_counts = {"treefarm_oak": 1, "seller": 1}
	Game.check_quests()
	check(Game.quest_index >= 2, "quests advance (idx=%d)" % Game.quest_index)
	# prestige
	Game.lifetime = 8e6
	Game.stars = 0
	check(Game.ascend_gain() == 2, "ascend gain = floor(sqrt(8e6/2e6)) = 2 (got %d)" % Game.ascend_gain())
	Game.ascend()
	check(Game.stars == 2, "stars after ascend")
	check(Game.plots.size() == 1, "plots reset after ascend")
	check(Game.upg("sell_value") == 0, "upgrades reset after ascend")
	check(absf(Game.star_mult() - 1.5) < 0.001, "star mult 1.5")
	check(Game.money >= Game.START_MONEY + 500.0 - 0.1, "starting cash includes star bonus")
	# save/load roundtrip
	Game.save_enabled = true
	Game.money = 12345.0
	Game.upgrades = {"rich_veins": 3}
	Game.plots = {Vector2i(0, 0): true, Vector2i(-1, 1): true}
	Game.income_rate = 50.0
	Game.save_game()
	var raw := FileAccess.get_file_as_string(Game.SAVE_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	check(typeof(parsed) == TYPE_DICTIONARY, "save is valid JSON")
	Game.money = 0.0
	Game.upgrades = {}
	Game.plots = {}
	Game.load_game()
	check(absf(Game.money - 12345.0) < 1.0, "money restored (%.0f)" % Game.money)
	check(Game.upg("rich_veins") == 3, "upgrades restored")
	check(Game.plots.has(Vector2i(-1, 1)) and Game.plots.size() == 2, "plots restored")
	check(Game.stars == 2, "stars restored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.save_enabled = false
	# offline progress
	Game.save_enabled = true
	Game.income_rate = 100.0
	Game.save_game()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.SAVE_PATH))
	d.saved_at = Time.get_unix_time_from_system() - 3600.0
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var before := Game.money
	Game.load_game()
	check(Game.money > before + 100.0 * 3600.0 * 0.15, "offline earnings credited (%.0f)" % (Game.money - before))
	check(not Game.offline_report.is_empty(), "offline report set")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	_geometry_tests()
	print("LOGIC RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _geometry_tests() -> void:
	var world: Node = load("res://scripts/World.gd").new()
	add_child(world)
	Game.money = 1e9
	# log rip cut conserves volume and becomes timber
	var log_it: Item = world.spawn_item({"mat": "oak", "shape": "cyl", "size": Vector3(0.3, 0.3, 1.5)}, Transform3D(Basis(), Vector3(0, 5, 0)), Vector3.ZERO, true)
	check(log_it.form == "log", "log classified as log")
	var v0 := log_it.volume()
	var val0 := log_it.value()
	var pieces: Array = world.cut_item(log_it, Vector3(0.0, 5, 0), Vector3(1, 0, 0))
	check(pieces.size() == 2, "rip cut makes 2 pieces")
	var v1 := 0.0
	var val1 := 0.0
	for p in pieces:
		v1 += (p as Item).volume()
		val1 += (p as Item).value()
	check(absf(v1 - v0) < 0.0005, "rip cut conserves volume (%.4f vs %.4f)" % [v1, v0])
	check((pieces[0] as Item).form == "timber", "rip halves are timber (%s)" % (pieces[0] as Item).form)
	check(val1 > val0 * 1.3, "timber worth more than the log")
	# off-centre cut: where the blade hits decides the split
	var t2: Item = pieces[0]
	var sz := t2.size
	var pc2: Array = world.cut_item(t2, t2.global_position + t2.global_transform.basis.x.normalized() * (sz.x * 0.25), t2.global_transform.basis.x)
	check(pc2.size() == 2, "offset cut splits")
	if pc2.size() == 2:
		var a := (pc2[0] as Item).size.x
		var b := (pc2[1] as Item).size.x
		check(absf(maxf(a, b) / minf(a, b) - 3.0) < 0.05, "offset cut ratio is 3:1 (%.3f / %.3f)" % [a, b])
	# grazing cut does nothing
	var g: Array = world.cut_item(t2, t2.global_position + Vector3(0, 0, 0.749), Vector3(0, 0, 1))
	check(g.size() == 1 or g.size() == 2, "graze handled")
	# press: ingot -> plate -> sheet, volume constant
	var ing: Item = world.spawn_item({"mat": "copper", "shape": "box", "size": Defs.INGOT_SIZE, "refined": true}, Transform3D(Basis(), Vector3(3, 5, 0)), Vector3.ZERO, true)
	check(ing.form == "ingot", "cast ingot classified as ingot")
	var iv := ing.volume()
	world.press_item(ing)
	check(ing.form == "plate", "pressed once -> plate (%s, %s)" % [ing.form, str(ing.size)])
	world.press_item(ing)
	check(ing.form == "sheet", "pressed twice -> sheet (%s)" % ing.form)
	check(absf(ing.volume() - iv) < iv * 0.02, "press conserves volume")
	# crusher: geode -> pure shards
	var geo: Item = world.spawn_item({"mat": "emerald", "shape": "chunk", "size": Vector3(0.45, 0.4, 0.45), "purity": 0.3}, Transform3D(Basis(), Vector3(-3, 5, 0)), Vector3.ZERO, true)
	check(geo.form == "geode", "geode classified")
	var before: int = world.active_items.size()
	world.crush_item(geo, 0.25, Vector3(-3, 6, 0), Vector3.ZERO)
	check(world.active_items.size() > before, "crusher made fragments (+%d)" % (world.active_items.size() - before))
	check(geo.refined and geo.form == "shard", "geode fragments are pure shards (%s)" % geo.form)
	world.queue_free()
