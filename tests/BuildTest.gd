extends Node
## Headless test of the new tools: saw (fell + cut), logs, shears, vacuum, dropping tools, hammer builds.
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


func secs(s: float) -> void:
	await frames(int(s * 60.0))


func aim_at(target: Vector3, dist: float) -> void:
	var away := player.global_position - target
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	var stand := target + away * dist
	stand.y = main.terrain.height_at(stand.x, stand.z) + 0.05
	player.global_position = stand
	player.velocity = Vector3.ZERO
	await frames(2)
	var eye := player.global_position + Vector3(0, 1.58, 0)
	var to := target - eye
	player.set("_yaw", atan2(-to.x, -to.z))
	player.set("_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await frames(1)


func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	for id in ["hatchet", "saw", "shears", "vacuum", "hammer"]:
		Game.owned[id] = true
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await frames(3)
	player = main.player
	await run()
	print("BUILD RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit()


func nearest_tree() -> ForestTree:
	var best: ForestTree = null
	var bd := 1e9
	for tr in main.trees:
		var d: float = tr.global_position.distance_to(Vector3(0, 0, 14))
		if d < bd and not tr.felled:
			bd = d
			best = tr
	return best


func run() -> void:
	# --- saw: fell a tree
	var tree := nearest_tree()
	var bands0 := tree.bands
	player.equip("saw")
	await frames(20)
	await aim_at(tree.global_position + Vector3(0, 0.6, 0), tree.radius + 0.8)
	var logs0 := get_tree().get_nodes_in_group("logs").size()
	player.force_trigger = true
	for i in 240:
		await frames(1)
		if tree.felled:
			break
	player.force_trigger = false
	check(tree.felled and tree.bands < bands0, "sawing fells the tree, leaving a %d-band stump" % tree.bands)
	var logs := get_tree().get_nodes_in_group("logs")
	check(logs.size() == logs0 + 1, "a log falls")
	var lg: Log = logs[logs.size() - 1] if logs.size() > 0 else null
	await secs(3.0)
	check(lg != null and absf(lg.global_basis.y.y) < 0.6, "the log toppled over (up-dot %.2f)" % (lg.global_basis.y.y if lg else 9.0))
	# --- shears on the fallen crown
	player.equip("shears")
	await frames(20)
	var fol: Foliage = null
	if lg != null:
		var f := lg.find_children("*", "Foliage", true, false)
		fol = f[0] if f.size() > 0 else null
	check(fol != null, "the felled log keeps its leafy crown")
	var leaves0 := get_tree().get_nodes_in_group("leaves").size()
	if fol != null:
		var shape := fol.get_child(0) as CollisionShape3D
		await aim_at(shape.global_position, 2.2)
		for i in 4:
			player.start_swing()
			await secs(0.4)
	check(get_tree().get_nodes_in_group("leaves").size() > leaves0, "shears snip leaf clumps off the crown (%d)" % (get_tree().get_nodes_in_group("leaves").size() - leaves0))
	# --- shears on a bush
	var bush: Bush = null
	var bd := 1e9
	for b in get_tree().get_nodes_in_group("bushes"):
		var d: float = (b as Node3D).global_position.length()
		if d < bd:
			bd = d
			bush = b
	var leaves1 := get_tree().get_nodes_in_group("leaves").size()
	await aim_at(bush.global_position + Vector3(0, 0.3, 0), 1.6)
	player.start_swing()
	await secs(0.4)
	check(get_tree().get_nodes_in_group("leaves").size() > leaves1, "shears snip leaves off a bush")
	# --- saw the log into two
	if lg != null and is_instance_valid(lg):
		player.equip("saw")
		await frames(20)
		await aim_at(lg.global_position + lg.global_basis.y * -lg.length * 0.2, 1.4)
		var n0 := get_tree().get_nodes_in_group("logs").size()
		player.force_trigger = true
		for i in 120:
			await frames(1)
			if not is_instance_valid(lg):
				break
		player.force_trigger = false
		await frames(2)
		check(get_tree().get_nodes_in_group("logs").size() == n0 + 1, "sawing a log cuts it in two")
	# pick the shortest log for later
	var short: Log = null
	for l in get_tree().get_nodes_in_group("logs"):
		if short == null or (l as Log).length < short.length:
			short = l
	check(short != null and short.value() > 0.0, "logs are worth money ($%.2f)" % (short.value() if short else 0.0))
	# --- axe strips bark off a log
	if short != null:
		player.equip("hatchet")
		await frames(20)
		await aim_at(short.global_position + Vector3(0, short.radius * 0.6, 0), 1.2)
		var v0 := short.value()
		var chips0: int = main.chips.size()
		player.call("_do_impact")
		await frames(2)
		check(main.chips.size() > chips0 and short.value() < v0, "axes strip bark off a lying log too")
	# --- drop a tool and take it back
	player.equip("hatchet")
	await frames(20)
	player.drop_tool()
	await secs(1.0)
	var items := get_tree().get_nodes_in_group("tool_items")
	check(player.tool == "hands" and items.size() == 1 and not Game.in_toolbar("hatchet"), "Q drops the tool on the ground")
	if items.size() == 1:
		(items[0] as ToolItem).on_use(player)
		await frames(2)
	check(player.tool == "hatchet" and Game.in_toolbar("hatchet"), "E picks it back up")
	# --- vacuum
	player.equip("vacuum")
	await frames(20)
	var spot := player.global_position + Vector3(0, 0, -3.0)
	await aim_at(spot + Vector3(0, 0.3, 0), 3.0)
	var bits: Array[Chip] = []
	for i in 6:
		var data := tree.piece_data(1, [Vector2i(i, 0)])
		var c: Chip = main.spawn_chip(data, tree.kind, Vector3.ZERO)
		c.global_position = player.global_position - player.global_basis.z * 3.0 + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))
		c.linear_velocity = Vector3.ZERO
		bits.append(c)
	await frames(10)
	player.force_trigger = true
	await frames(150)
	var nozzle: Vector3 = player.cam.global_position - player.cam.global_transform.basis.z * 1.25
	var near := 0
	for c in bits:
		if c.global_position.distance_to(nozzle) < 0.8:
			near += 1
	check(near >= 4, "the vacuum holds the bark floating at the nozzle (%d/6)" % near)
	player.force_trigger = false
	await secs(2.0)
	var fell_down := 0
	for c in bits:
		if c.global_position.y < nozzle.y - 0.4:
			fell_down += 1
	check(fell_down >= 3, "letting go drops them (%d/6 fell)" % fell_down)
	# --- hammer: basket
	player.equip("hammer")
	await frames(20)
	var ground := player.global_position - player.global_basis.z * 2.5
	ground.y = main.terrain.height_at(ground.x, ground.z)
	await aim_at(ground, 2.5)
	player.builder.selected = Builds.ORDER.find("basket")
	player.primary()
	await frames(3)
	check(player.builder.state == "place", "hammer click shows the hologram")
	player.primary()
	await frames(3)
	var bps := get_tree().get_nodes_in_group("blueprints")
	check(bps.size() == 1 and player.builder.state == "idle", "second click places the plan")
	var bp: Blueprint = bps[0] if bps.size() > 0 else null
	var fed := 0
	if bp != null:
		var i := 0
		while is_instance_valid(bp) and int(bp.have.get("bark", 0)) < 8 and i < 40:
			var data := tree.piece_data(0, [Vector2i(i % 16, 1)])
			var c: Chip = main.spawn_chip(data, ["oak", "birch", "pine"][i % 3], Vector3.ZERO)
			c.global_position = bp.global_position + Vector3(0, 0.8, 0)
			c.linear_velocity = Vector3.ZERO
			i += 1
			await frames(8)
		fed = int(bp.have.get("bark", 0)) if is_instance_valid(bp) else 0
		check(fed >= 8, "dropping bark into the plan fills it in (%d/16)" % fed)
		# cancel gives it back
		var chips_before: int = main.chips.size()
		var pieces: int = bp._stored.size()
		bp.on_use(player)
		await frames(4)
		check(main.chips.size() >= chips_before + pieces and get_tree().get_nodes_in_group("blueprints").is_empty(), "E on the plan cancels it and all %d pieces drop out" % pieces)
	# build it for real
	player.primary()
	await frames(2)
	player.primary()
	await frames(3)
	bps = get_tree().get_nodes_in_group("blueprints")
	bp = bps[0] if bps.size() > 0 else null
	var i2 := 0
	while bp != null and is_instance_valid(bp) and i2 < 60:
		var data := tree.piece_data(0, [Vector2i(i2 % 16, 2)])
		var c: Chip = main.spawn_chip(data, ["oak", "birch", "pine"][i2 % 3], Vector3.ZERO)
		c.global_position = bp.global_position + Vector3(0, 0.8, 0)
		c.linear_velocity = Vector3.ZERO
		i2 += 1
		await frames(8)
	await frames(10)
	var baskets := get_tree().get_nodes_in_group("baskets")
	check(baskets.size() == 1, "16 bark of any kind builds a basket")
	if baskets.size() == 1:
		check((baskets[0] as Node).is_in_group("grabbable"), "the basket can be picked up")
	# --- hammer: hoop with a custom height
	player.builder.scroll(1)
	check(player.builder.current() == "hoop", "scrolling picks the hoop")
	var g2 := player.global_position + player.global_basis.x * 3.0
	g2.y = main.terrain.height_at(g2.x, g2.z)
	await aim_at(g2, 3.0)
	player.primary()
	await frames(3)
	player.primary()
	await frames(3)
	check(player.builder.state == "height", "the hoop asks for a height")
	player.set("_pitch", deg_to_rad(40.0))
	player.head.rotation.x = deg_to_rad(40.0)
	await frames(4)
	player.primary()
	await frames(3)
	bps = get_tree().get_nodes_in_group("blueprints")
	bp = bps[0] if bps.size() > 0 else null
	check(bp != null and bp.height > 3.4, "looking up makes a tall hoop (%.2f m)" % (bp.height if bp else 0.0))
	if bp != null and short != null and is_instance_valid(short):
		short.global_position = bp.global_position + Vector3(0, 1.2, 0)
		short.linear_velocity = Vector3.ZERO
		await frames(20)
		check(int(bp.have.get("log", 0)) == 1, "a log goes in as the pole")
		var i3 := 0
		while is_instance_valid(bp) and i3 < 40:
			var data := tree.piece_data(0, [Vector2i(i3 % 16, 3)])
			var c: Chip = main.spawn_chip(data, "pine", Vector3.ZERO)
			c.global_position = bp.global_position + Vector3(0, 1.0, 0)
			c.linear_velocity = Vector3.ZERO
			i3 += 1
			await frames(8)
		await frames(10)
		check(get_tree().get_nodes_in_group("hoops").size() == 1, "12 bark + a log builds the hoop")
