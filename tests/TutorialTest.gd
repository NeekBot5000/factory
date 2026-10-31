extends Node
## Walks through the starting tutorial on a brand-new game: every step advances when its thing is done.
var main: Node3D
var fails := 0


func check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func step() -> int:
	await frames(25)
	return Game.tutorial


func _ready() -> void:
	Game.save_path = "user://tutorial_test_save.json"
	Game.save_enabled = false
	Game.reset()
	Game.save_enabled = true
	Game.save_game()
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await frames(5)
	var player: Player = main.player
	var tut: Tutorial = null
	for c in main.hud.root.get_children():
		if c is Tutorial:
			tut = c
	check(tut != null and Game.tutorial == 0, "a new game starts the tutorial at step 1")
	check(main.shop_ui is TitleMenu, "behind the title screen")
	main.call("_on_title", "continue")
	var block_hatchet: ToolItem = null
	for t in get_tree().get_nodes_in_group("tool_items"):
		if (t as ToolItem).tool == "hatchet":
			block_hatchet = t
	check(block_hatchet != null, "the hatchet is stuck in the chopping block")
	block_hatchet.on_use(player)
	check(await step() == 1 and player.tool == "hatchet", "taking it -> step 2 (peel bark)")
	player.pieces_stripped = 6
	check(await step() == 2, "peeling some bark -> step 3 (load the truck)")
	Game.add_money(15.0)
	check(await step() == 4, "selling a load -> step 5 (save up for the hammer)")
	Game.money = 130.0
	check(await step() == 5, "$120 saved -> step 6 (buy the hammer)")
	Game.buy("hammer")
	check(await step() == 6, "ordering it -> step 7 (open the box)")
	Game.receive("hammer")
	check(await step() == 7, "getting the hammer -> step 8 (build a bark wreath)")
	var at := Vector3(-3, 0, 8)
	at.y = main.terrain.height_at(at.x, at.z)
	var wreath := Builds.finish("bark_wreath", main, Transform3D(Basis(), at), Builds.HOOP_DEFAULT, [], 1.0)
	wreath.set_meta("sale_value", 9.0)
	check(await step() == 8, "building it -> step 9 (sell it)")
	var m0 := Game.money
	player.take_down(wreath)
	await frames(25)
	check(Game.tutorial == -1 and Game.money > m0, "selling it with the hammer finishes the tutorial")
	check(not is_instance_valid(tut), "and the panel goes away")
	Game.save_enabled = false
	print("TUTORIAL RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit()
