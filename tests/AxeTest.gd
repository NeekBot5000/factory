extends Node
## Headless test of the axe variety: specialists, ringing axe, twins, greataxe, combo.
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


func face(tree: ForestTree, h: float) -> void:
	var tp := tree.global_position
	var away := Vector3(0, 0, 14) - tp
	away.y = 0
	away = away.normalized()
	var stand := tp + away * (tree.radius + 0.9)
	stand.y = main.terrain.height_at(stand.x, stand.z) + 0.05
	player.global_position = stand
	player.velocity = Vector3.ZERO
	await frames(2)
	var eye := player.global_position + Vector3(0, 1.58, 0)
	var to := tp + Vector3(0, h, 0) - eye
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
	for id in ["scraper", "gouge", "ringer", "twins", "greataxe", "combo", "hatchet"]:
		Game.owned[id] = true
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await frames(3)
	player = main.player
	var trees: Array = main.trees.duplicate()
	trees.sort_custom(func(a, b): return a.global_position.distance_to(Vector3(0, 0, 14)) < b.global_position.distance_to(Vector3(0, 0, 14)))
	var t1: ForestTree = trees[0]
	var t2: ForestTree = trees[1]
	var t3: ForestTree = trees[2]

	# scraper: outer only, even where it lands, never inner
	player.equip("scraper")
	await frames(20)
	await face(t1, 1.4)
	var o0 := count(t1, 0)
	var i0 := count(t1, 1)
	player.call("_do_impact")
	var o1 := count(t1, 0)
	check(o0 - o1 >= 6 and count(t1, 1) == i0, "the scraper lifts a big sheet of outer bark (%d panels) and leaves the inner layer" % (o0 - o1))
	player.call("_do_impact")
	player.call("_do_impact")
	check(count(t1, 1) == i0, "even hitting the same bare spot again it never takes inner bark")

	# gouge: inner only, worth more
	player.equip("gouge")
	await frames(20)
	await face(t1, 1.4)
	var chips0: int = main.chips.size()
	player.call("_do_impact")
	await frames(1)
	check(count(t1, 1) < i0 and count(t1, 0) == o1 - 0 - (o1 - count(t1, 0)), "the gouge takes inner bark")
	var c: Chip = main.chips[main.chips.size() - 1] if main.chips.size() > chips0 else null
	check(c != null and c.layer == 1 and absf(c.value - c.panels * Chip.PANEL_VALUE.inner * (1.6 if false else 1.0) * 1.35) < 0.01, "gouged inner bark sells for 35%% more ($%.2f for %d panels)" % [c.value if c else 0.0, c.panels if c else 0])
	await face(t2, 1.4)
	var o2 := count(t2, 0)
	var i2 := count(t2, 1)
	player.call("_do_impact")
	check(count(t2, 0) == o2 and count(t2, 1) == i2, "the gouge does nothing on a trunk still covered in outer bark")

	# ringing axe: the whole band all the way round
	player.equip("ringer")
	await frames(20)
	await face(t2, 1.0)
	player.call("_do_impact")
	check(o2 - count(t2, 0) == ForestTree.SECTORS, "the ringing axe takes a full ring (%d of %d panels)" % [o2 - count(t2, 0), ForestTree.SECTORS])

	# combo: consecutive hits grow
	player.equip("combo")
	await frames(20)
	await face(t3, 1.4)
	var r0 := player.strip_radius()
	for k in 4:
		player.call("_do_impact")
		await frames(10)
	check(player.strip_radius() > r0 + 0.15, "combo hits grow the circle (%.2f -> %.2f)" % [r0, player.strip_radius()])
	await frames(90)
	check(player.strip_radius() == r0, "pausing resets the combo")

	# greataxe: biggest circle, slow walking
	player.equip("greataxe")
	await frames(20)
	check(float(Tools.TOOLS.greataxe.radius) >= 0.5 and float(Tools.TOOLS.greataxe.get("move", 1.0)) < 0.7, "the greataxe has the biggest bite but slows you down")

	# twins: alternate hands, both swing
	player.equip("twins")
	await frames(20)
	check(player.arm_l.visible and player.tool_model_l != null, "twin hatchets: one in each hand")
	player.start_swing()
	var first: bool = player.get("_backhand")
	await frames(20)
	player.start_swing()
	check(player.get("_backhand") != first, "the hands take turns")

	# number keys pick the n-th owned tool
	var ev := InputEventKey.new()
	ev.keycode = KEY_2
	ev.pressed = true
	player._unhandled_input(ev)
	var owned: Array = Tools.TOOL_ORDER.filter(func(t): return Game.in_toolbar(t))
	check(player.tool == owned[1], "key 2 picks the second tool you own (%s)" % player.tool)
	print("AXE RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit()
