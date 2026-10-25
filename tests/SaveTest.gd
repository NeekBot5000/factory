extends Node
## Builds and half-filled plans survive a restart.
var fails := 0


func check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	Game.save_path = "user://timber_savetest.json"
	Game.save_enabled = true
	Game.reset()
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await frames(5)
	var at := Vector3(3.0, 0, 9.0)
	at.y = main.terrain.height_at(at.x, at.z)
	var cols: Array = []
	for i in 16:
		cols.append(Color("e8e4da") if i % 2 == 0 else Color("5b4030"))
	var basket := Builds.finish("basket", main, Transform3D(Basis(Vector3.UP, 0.7), at), 0.0, cols, 1.5)
	basket.set_meta("sale_value", 42.0)
	var hp := Vector3(-3.0, 0, 9.0)
	hp.y = main.terrain.height_at(hp.x, hp.z)
	Builds.finish("hoop", main, Transform3D(Basis(), hp), 3.05, [Color("6b4a32")], 1.0)
	var bp := Blueprint.new()
	main.add_child(bp)
	bp.global_transform = Transform3D(Basis(), at + Vector3(0, 0, 3))
	bp.setup("bench", 3.05, main, 1.0)
	var tr: ForestTree = main.trees[0]
	for i in 3:
		var c: Chip = main.spawn_chip(tr.piece_data(0, [Vector2i(i, 1)]), "birch", Vector3.ZERO)
		c.global_position = bp.global_position + Vector3(0, 0.6, 0)
		await frames(10)
	await frames(60)
	var basket_pos: Vector3 = basket.global_position
	var bark_in := int(bp.have.get("bark", 0))
	Game.save_game()
	# "restart": throw the world away and load it again from the save file
	main.queue_free()
	await frames(2)
	Game.reset_memory_only()
	Game.load_game()
	var main2: Node3D = load("res://scenes/Main.tscn").instantiate()
	add_child(main2)
	await frames(5)
	var baskets := get_tree().get_nodes_in_group("baskets")
	check(baskets.size() == 1, "the basket is still there after a restart")
	if baskets.size() == 1:
		var b := baskets[0] as Node3D
		check(b.global_position.distance_to(basket_pos) < 0.2, "in the same place")
		check(absf(float(b.get_meta("build").size) - 1.5) < 0.01, "at the same size")
		check(absf(float(b.get_meta("sale_value", 0.0)) - 42.0) < 0.01, "and still worth the same")
	check(get_tree().get_nodes_in_group("hoops").size() == 1, "the hoop is still there")
	var plans := get_tree().get_nodes_in_group("blueprints")
	check(plans.size() == 1 and int((plans[0] as Blueprint).have.get("bark", 0)) == bark_in and bark_in > 0, "the half-built bench keeps its progress (%d bark)" % bark_in)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	print("SAVE RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit()
