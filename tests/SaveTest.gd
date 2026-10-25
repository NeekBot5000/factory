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
	# change the world: strip a tree, fell another, leave bark, leaves, a locked log, a dropped tool, a sapling,
	# and trim a bush away
	var t0: ForestTree = main.trees[0]
	t0.strip_circle(t0.global_transform * Vector3(t0.radius, 1.0, 0), 0.3)
	var outer_left := 0
	for b in t0.layers[0]:
		outer_left += b
	var t1: ForestTree = main.trees[1]
	var lg := t1.fell(10, Vector3.FORWARD)
	await frames(120)
	lg.set_locked(true)
	var log_pos := lg.global_position
	var lp := Vector3(6, 0, 4)
	lp.y = main.terrain.height_at(lp.x, lp.z) + 0.3
	var chip: Chip = main.spawn_chip(t0.piece_data(1, [Vector2i(3, 2), Vector2i(4, 2)]), t0.kind, Vector3.ZERO)
	chip.global_position = lp
	var lf := Leaf.new()
	main.add_child(lf)
	lf.setup(Color("5aa041"), 0.15)
	lf.global_position = lp + Vector3(0.5, 0, 0)
	var ti := ToolItem.new()
	main.add_child(ti)
	ti.setup("hatchet")
	ti.global_position = lp + Vector3(-0.6, 0, 0)
	Game.owned["hatchet"] = true
	Game.set_dropped("hatchet", true)
	# snip some leaves off one crown and every last leaf off another (its saplings are cleared away again)
	var t2: ForestTree = main.trees[2]
	var f2 := t2.find_children("*", "Foliage", true, false)[0] as Foliage
	for k in 5:
		f2.snip(0, f2.global_position, Vector3.UP, main)
	var crown2: Array = f2.state()
	var t3: ForestTree = main.trees[3]
	var f3 := t3.find_children("*", "Foliage", true, false)[0] as Foliage
	var guard := 0
	while is_instance_valid(f3) and not f3.is_queued_for_deletion() and guard < 3000:
		guard += 1
		if not f3.snip(0, f3.global_position, Vector3.UP, main):
			await frames(1)
	await frames(2)
	for l0 in get_tree().get_nodes_in_group("leaves"):
		if l0 != lf:
			l0.remove_from_group("leaves")
			l0.queue_free()
	for s0 in get_tree().get_nodes_in_group("saplings"):
		s0.remove_from_group("saplings")
		s0.queue_free()
	t3.shake_crown(Vector3.FORWARD, 0.5)      # used to touch the freed crown
	# mine: one rock gone, one chipped, an ore chunk lying around; and a wired crank + lever
	var rocks := get_tree().get_nodes_in_group("rocks").filter(func(r): return r.has_meta("rock_id"))
	var mined_id: int = rocks[0].get_meta("rock_id")
	rocks[0].remove_from_group("rocks")
	rocks[0].queue_free()
	var chipped_id: int = rocks[1].get_meta("rock_id")
	(rocks[1] as Rock).set_hp(1)
	var ore := Ore.new()
	main.add_child(ore)
	ore.setup("copper", 0.15)
	ore.global_position = lp + Vector3(0.8, 0, -0.8)
	Game.owned["bp_crank"] = true
	var mp := Vector3(-6.0, 0, 9.0)
	mp.y = main.terrain.height_at(mp.x, mp.z)
	var crank := Builds.finish("crank", main, Transform3D(Basis(), mp), 3.05, [], 1.0) as Crank
	var lever := Builds.finish("lever", main, Transform3D(Basis(), mp + Vector3(1, 0, 0)), 3.05, [], 1.0) as Lever
	Circuit.toggle_wire(main, crank, lever)
	lever.set_on(true)
	crank.charge = 40.0
	var sp := Sapling.new()
	main.add_child(sp)
	sp.setup("pine")
	sp.global_position = lp + Vector3(0, 0, 0.8)
	var bushes := get_tree().get_nodes_in_group("bushes")
	var gone_id: int = bushes[0].get_meta("bush_id")
	bushes[0].queue_free()
	await frames(60)
	var chip_pos := chip.global_position
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
	var mt: Array = main2.trees
	var o2 := 0
	for b in (mt[0] as ForestTree).layers[0]:
		o2 += b
	check(o2 == outer_left, "the bark you stripped stays stripped (%d panels left)" % o2)
	check((mt[1] as ForestTree).felled and (mt[1] as ForestTree).bands == 10, "the felled tree is still a stump")
	var logs := get_tree().get_nodes_in_group("logs")
	check(logs.size() == 1 and (logs[0] as Log).locked and (logs[0] as Node3D).global_position.distance_to(log_pos) < 0.3, "the felled log is still there, locked where you left it")
	var chips := get_tree().get_nodes_in_group("chips")
	check(chips.size() == 1 and (chips[0] as Chip).panels == 2 and (chips[0] as Node3D).global_position.distance_to(chip_pos) < 0.5, "loose bark is still lying where you left it")
	check(get_tree().get_nodes_in_group("leaves").size() == 1, "loose leaves too")
	check(get_tree().get_nodes_in_group("tool_items").size() == 1 and not Game.in_toolbar("hatchet"), "the dropped hatchet is still on the ground")
	check(get_tree().get_nodes_in_group("saplings").size() == 1, "and the sapling")
	var ids := get_tree().get_nodes_in_group("bushes").map(func(b): return b.get_meta("bush_id"))
	check(not ids.has(gone_id), "the bush you trimmed away stays gone")
	var f2b := (mt[2] as ForestTree).find_children("*", "Foliage", true, false)
	check(not f2b.is_empty() and (f2b[0] as Foliage).state() == crown2, "snipped leaves stay snipped")
	check((mt[3] as ForestTree).find_children("*", "Foliage", true, false).is_empty(), "a crown snipped bare stays bare")
	var ids2 := get_tree().get_nodes_in_group("rocks").filter(func(r): return r.has_meta("rock_id")).map(func(r): return int(r.get_meta("rock_id")))
	check(not ids2.has(mined_id), "a rock you mined away stays gone")
	var ch := get_tree().get_nodes_in_group("rocks").filter(func(r): return r.has_meta("rock_id") and int(r.get_meta("rock_id")) == chipped_id)
	check(ch.size() == 1 and (ch[0] as Rock).hp == 1, "a chipped rock keeps its damage")
	check(get_tree().get_nodes_in_group("ores").size() == 1, "the ore chunk is still lying there")
	var lv := get_tree().get_nodes_in_group("machines").filter(func(m): return m is Lever)
	var cr := get_tree().get_nodes_in_group("machines").filter(func(m): return m is Crank)
	check(lv.size() == 1 and (lv[0] as Lever).on and cr.size() == 1 and (cr[0] as Crank).charge > 30.0, "machines keep their settings (lever on, crank wound)")
	check(get_tree().get_nodes_in_group("wires").size() == 1, "and their wire")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	print("SAVE RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit()
