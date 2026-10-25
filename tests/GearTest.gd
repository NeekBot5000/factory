extends Node
## Headless test of the newer gear: robo-axe, double-bit combo, chainsaw, buck saw, hole saw, twin auger, vacs.
var main: Node3D
var player: Player
var fails := 0


func check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func face(tree: Node3D, at: Vector3, dist: float) -> void:
	var away := Vector3(0, 0, 14) - at
	away.y = 0
	away = away.normalized()
	var stand := at + away * dist
	stand.y = main.terrain.height_at(stand.x, stand.z) + 0.05
	player.global_position = stand
	player.velocity = Vector3.ZERO
	await frames(2)
	var eye := player.global_position + Vector3(0, 1.58, 0)
	var to := at - eye
	player.set("_yaw", atan2(-to.x, -to.z))
	player.set("_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await frames(1)


func count(tree: ForestTree, l: int) -> int:
	var n := 0
	for b in tree.layers[l]:
		n += b
	return n


func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	for id in Tools.SHOP_ORDER:
		if id != "phone":
			Game.owned[id] = true
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await frames(3)
	player = main.player
	var trees: Array = main.trees.duplicate()
	trees.sort_custom(func(a, b): return a.global_position.distance_to(Vector3(0, 0, 14)) < b.global_position.distance_to(Vector3(0, 0, 14)))

	# shop departments
	var cats := Tools.CATEGORIES.map(func(c): return c.name)
	check(cats.has("Axes") and cats.has("Saws") and cats.has("Specialty Tools") and cats.has("Other"), "the shop has broad departments: %s" % ", ".join(cats))

	# robo-axe: 3x3 through both layers, automatic
	var t1: ForestTree = trees[0]
	player.equip("robo")
	await frames(20)
	await face(t1, t1.global_position + Vector3(0, 1.4, 0), t1.radius + 0.9)
	var o0 := count(t1, 0)
	var i0 := count(t1, 1)
	player.call("_do_impact")
	check(o0 - count(t1, 0) == 9 and i0 - count(t1, 1) == 9, "one robo-axe hit punches a 3x3 patch through both layers (%d outer, %d inner)" % [o0 - count(t1, 0), i0 - count(t1, 1)])
	var before := count(t1, 0)
	player.force_trigger = true
	player.set("_pitch", player.get("_pitch") + 0.25)
	await frames(60)
	player.force_trigger = false
	check(player.chops >= 5, "holding the trigger it chops on its own, fast (%d chops in 1 s)" % player.chops)

	# double-bit: two hits per swing
	player.equip("double_bit")
	await frames(20)
	var t2: ForestTree = trees[1]
	await face(t2, t2.global_position + Vector3(0, 1.4, 0), t2.radius + 0.9)
	var c0 := player.chops
	player.start_swing()
	await frames(70)
	check(player.chops - c0 == 2, "the double-bit hits twice per swing (%d)" % (player.chops - c0))

	# hole saw: both layers at once, small
	player.equip("holesaw")
	await frames(20)
	var t3: ForestTree = trees[2]
	await face(t3, t3.global_position + Vector3(0, 1.2, 0), t3.radius + 0.9)
	var ho := count(t3, 0)
	var hi := count(t3, 1)
	player.drill_once()
	check(count(t3, 0) < ho and count(t3, 1) < hi, "the hole saw takes outer and inner bark together")

	# twin auger: two separate spots
	player.equip("twin_auger")
	await frames(20)
	var t4: ForestTree = trees[3]
	await face(t4, t4.global_position + Vector3(0, 1.2, 0), t4.radius + 0.9)
	var chips0: int = main.chips.size()
	player.drill_once()
	check(main.chips.size() - chips0 == 2, "the twin auger bores two strips at once (%d pieces)" % (main.chips.size() - chips0))

	# chainsaw fells a tree much faster than the bow saw
	player.equip("chainsaw")
	await frames(20)
	var t5: ForestTree = trees[4]
	await face(t5, t5.global_position + Vector3(0, 0.6, 0), t5.radius + 0.8)
	player.force_trigger = true
	var f := 0
	while not t5.felled and f < 400:
		await frames(1)
		f += 1
	player.force_trigger = false
	var bow_time := Player.SAW_TREE_TIME * (t5.radius / 0.38)
	check(t5.felled and f / 60.0 < bow_time * 0.5, "the chainsaw fells a tree in %.1f s (bow saw: %.1f s)" % [f / 60.0, bow_time])

	# buck saw: can't fell, but splits a log into rounds in one cut
	player.equip("bucksaw")
	await frames(20)
	var t6: ForestTree = trees[5]
	await face(t6, t6.global_position + Vector3(0, 0.6, 0), t6.radius + 0.8)
	player.force_trigger = true
	await frames(240)
	player.force_trigger = false
	check(not t6.felled, "the buck saw can't fell a standing tree")
	var logs := get_tree().get_nodes_in_group("logs")
	await frames(150)
	var lg: Log = logs[0] if logs.size() > 0 else null
	var n_before := get_tree().get_nodes_in_group("logs").size()
	if lg != null:
		lg.buck(7)
		await frames(2)
	check(get_tree().get_nodes_in_group("logs").size() >= n_before + 3, "one buck-saw cut splits the log into several rounds (%d logs now)" % get_tree().get_nodes_in_group("logs").size())

	# vacuums
	for vid in ["twinvac", "cyclone"]:
		player.equip(vid)
		await frames(20)
		var open := Vector3(Terrain.road_x(40.0) + 3.0, 0, 40.0)
		open.y = main.terrain.height_at(open.x, open.z) + 0.05
		player.global_position = open
		player.set("_yaw", 0.0)
		player.set("_pitch", deg_to_rad(-15))
		await frames(5)
		var bits: Array[Chip] = []
		for i in 8:
			var c: Chip = main.spawn_chip(t1.piece_data(0, [Vector2i(i, 0)]), "oak", Vector3.ZERO)
			c.global_position = open + Vector3(randf_range(-1.2, 1.2), 0.4, -3.5 + randf_range(-0.5, 0.5))
			c.linear_velocity = Vector3.ZERO
			bits.append(c)
		await frames(10)
		player.force_trigger = true
		await frames(180)
		var held := (player.get("_vac_caught") as Dictionary).size()
		var xs := {}
		for c in bits:
			xs[signf(player.to_local(c.global_position).x)] = true
		player.force_trigger = false
		await frames(1)
		if vid == "twinvac":
			check(held >= 6 and xs.size() == 2, "the twin-nozzle vac holds the load in two clumps, left and right (%d caught)" % held)
		else:
			await frames(30)
			var far := 0
			for c in bits:
				if c.global_position.distance_to(open) > 6.0:
					far += 1
			check(far >= 3, "letting go of the cyclone vac fires its load forward (%d flew far)" % far)
	await lock_test()
	log_value_test()
	print("GEAR RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit()


func lock_test() -> void:
	var logs := get_tree().get_nodes_in_group("logs")
	var lg: Log = null
	for l in logs:
		if (l as Log).length < 2.5:
			lg = l
	check(lg != null, "found a log to lock")
	if lg == null:
		return
	player.equip("hammer")
	await frames(20)
	await face(lg, lg.global_position, 1.3)
	player.primary()
	await frames(5)
	check(lg.locked and lg.freeze, "hammer click locks the log")
	var p0 := lg.global_position
	lg.apply_central_impulse(Vector3(0, 0, 50))
	await frames(60)
	check(lg.global_position.distance_to(p0) < 0.01 and not lg.is_in_group("grabbable"), "a locked log doesn't budge and can't be picked up")
	player.primary()
	await frames(5)
	check(not lg.locked and not lg.freeze, "clicking again unlocks it")


func log_value_test() -> void:
	var tr: ForestTree = main.trees[0]
	var lg := Log.new()
	main.add_child(lg)
	lg.setup_from(tr, 0, 8, Transform3D(Basis(), Vector3(0, -50, 0)))
	lg.freeze = true
	var full := lg.value()
	for l in 2:
		var arr: PackedByteArray = lg.trunk.layers[l]
		arr.fill(1)
		lg.trunk.layers[l] = arr
	full = lg.value()
	for l in 2:
		var arr2: PackedByteArray = lg.trunk.layers[l]
		arr2.fill(0)
		lg.trunk.layers[l] = arr2
	var bare := lg.value()
	check(bare > full * 5.0, "a stripped log is worth far more than one in full bark ($%.2f vs $%.2f)" % [bare, full])
	lg.queue_free()
