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
	check(not Game.try_unlock("dropper_iron"), "cannot unlock without money")
	Game.money = 1e9
	Game.level = 0
	check(Game.unlock_block_reason("dropper_gold") != "", "level gate on gold dropper")
	Game.level = 5
	check(Game.unlock_block_reason("dropper_gold") != "", "biome gate on gold dropper (desert plot needed)")
	Game.plots[Vector2i(2, 0)] = true
	check(Game.unlock_block_reason("dropper_gold") == "", "gold dropper unlockable after desert plot + level")
	check(Game.try_unlock("dropper_gold"), "unlock gold dropper")
	# upgrades
	Game.money = 1e6
	var bought := Game.buy_upgrade("sell_value", 10)
	check(bought == 10 and Game.upg("sell_value") == 10, "bought 10 sell upgrades")
	check(absf(Game.sell_mult() - 3.0) < 0.001, "sell mult 3.0 after 10 levels (%.2f)" % Game.sell_mult())
	var m := Game.buy_upgrade("drop_speed", -1)
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
	Game.part_counts = {"dropper_copper": 1, "seller": 1}
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
	Game.upgrades = {"lucky": 3}
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
	check(Game.upg("lucky") == 3, "upgrades restored")
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
	print("LOGIC RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
