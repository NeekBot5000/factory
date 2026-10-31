extends Node
## Headless test of the big machine update: windmill, generator, battery, the seven logic blocks, sensors, lamp and
## bell, sawmill, chipper, planter, sprinkler and the automatic tree feller.
var main: Node3D
var player: Player
var fails := 0
var finished := false
const BASE := Vector3(-60, 40, -60)


func check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func secs(s: float) -> void:
	await frames(int(s * 60.0))


func place(id: String, at: Vector3, yaw_deg := 0.0, base := BASE) -> Node3D:
	return Builds.finish(id, main, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), base + at), Builds.HOOP_DEFAULT, [], 1.0)


func wire(a: Machine, b: Machine) -> void:
	check(Circuit.toggle_wire(main, a, b) == "added", "wired %s to %s" % [a.display_name(), b.display_name()])


func crank(at: Vector3, charge := 0.0) -> Crank:
	var c := place("crank", at) as Crank
	c.charge = charge
	return c


func ore_at(at: Vector3) -> Ore:
	var o := Ore.new()
	main.add_child(o)
	o.setup("stone", 0.14)
	o.global_position = at
	return o


func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await frames(3)
	player = main.player
	var sb := LowPoly.static_box(main, Vector3(60, 1, 60), BASE + Vector3(0, -0.5, 0))
	sb.collision_layer = 1
	await frames(2)
	await run()
	check(finished, "the whole test ran to the end")
	print("FACTORY RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit()


func run() -> void:
	# --- catalogue: every new build has a blueprint in the shop and a model with parts
	var missing: Array = []
	for id in ["windmill", "generator", "battery", "gate_diode", "gate_and", "gate_not", "gate_timer", "gate_delay", "gate_latch",
			"gate_counter", "pressure_plate", "item_sensor", "lamp", "bell", "sawmill", "chipper", "planter", "sprinkler", "feller"]:
		var bp := String(Builds.BUILDS[id].get("bp", ""))
		if bp == "" or not Tools.SHOP.has(bp) or not Tools.SHOP_ORDER.has(bp) or not Builds.ORDER.has(id):
			missing.append(id)
	check(missing.is_empty(), "every new machine is in the build menu and has a blueprint in the shop %s" % str(missing))

	# --- windmill
	var wm := place("windmill", Vector3(-20, 0, 20)) as Windmill
	await frames(2)
	check(wm.is_source() == (Windmill.wind() >= Windmill.MIN_WIND), "the windmill gives power when the wind is up (wind %d%%)" % int(Windmill.wind() * 100))

	# --- generator burns what you drop in, and powers a lamp
	var gen := place("generator", Vector3(-15, 0, 15)) as Generator
	var lamp := place("lamp", Vector3(-15, 0, 13)) as Lamp
	wire(gen, lamp)
	await frames(3)
	check(not lamp.powered, "an empty generator gives no power")
	var lf: Leaf = null
	for k in 6:
		lf = Leaf.new()
		main.add_child(lf)
		lf.setup(Color("6aa846"), 0.15)
		lf.global_position = gen.global_transform * Vector3(randf_range(-0.15, 0.15), 1.3 + k * 0.1, 0)
	await secs(1.0)
	check(not is_instance_valid(lf) and gen.fuel > 1.0, "leaves dropped in the hopper burn as fuel (%.1fs)" % gen.fuel)
	await frames(4)
	check(lamp.powered, "and the lamp lights up")

	# --- battery takes over when the crank runs down
	var cb := crank(Vector3(-10, 0, 15), 3.0)
	var bat := place("battery", Vector3(-10, 0, 13)) as Battery
	var lamp2 := place("lamp", Vector3(-10, 0, 11)) as Lamp
	wire(cb, bat)
	wire(bat, lamp2)
	await secs(2.5)
	check(bat.charge > 1.5 and lamp2.powered and not bat.is_source(), "the battery charges while the crank powers the line (%.1fs stored)" % bat.charge)
	await secs(1.5)
	check(cb.charge <= 0.0 and bat.is_source() and lamp2.powered, "when the crank runs out the battery keeps the lamp lit")

	# --- logic blocks: power in the back, out the front
	var x := 0.0
	var c1 := crank(Vector3(x, 0, 1), 60.0)
	var d1 := place("gate_diode", Vector3(x, 0, 0)) as Gate
	var l1 := place("lamp", Vector3(x, 0, -1)) as Lamp
	wire(c1, d1)
	wire(d1, l1)
	await frames(4)
	check(l1.powered and d1.passing, "one-way: power in the back comes out the front")
	x = 3.0
	var c2 := crank(Vector3(x, 0, -1), 60.0)          # crank in FRONT of the diode
	var d2 := place("gate_diode", Vector3(x, 0, 0)) as Gate
	var l2 := place("lamp", Vector3(x, 0, 1)) as Lamp  # lamp behind it
	wire(c2, d2)
	wire(d2, l2)
	await frames(4)
	check(not l2.powered, "one-way: power can't go backwards through it")

	# relay (AND)
	x = 6.0
	var ca := crank(Vector3(x, 0, 1), 60.0)
	var g_and := place("gate_and", Vector3(x, 0, 0)) as Gate
	var la := place("lamp", Vector3(x, 0, -1)) as Lamp
	var side_lever := place("lever", Vector3(x + 1.2, 0, 0)) as Lever
	var cs := crank(Vector3(x + 2.4, 0, 0), 60.0)
	wire(ca, g_and)
	wire(g_and, la)
	wire(cs, side_lever)
	wire(side_lever, g_and)
	await frames(4)
	check(not la.powered, "relay: back powered but side off -> no output")
	side_lever.set_on(true)
	await frames(4)
	check(la.powered, "relay: back and side powered -> output on")

	# inverting relay (NOT)
	x = 11.0
	var cn := crank(Vector3(x, 0, 1), 60.0)
	var g_not := place("gate_not", Vector3(x, 0, 0)) as Gate
	var ln := place("lamp", Vector3(x, 0, -1)) as Lamp
	var nl := place("lever", Vector3(x + 1.2, 0, 0)) as Lever
	var cns := crank(Vector3(x + 2.4, 0, 0), 60.0)
	wire(cn, g_not)
	wire(g_not, ln)
	wire(cns, nl)
	wire(nl, g_not)
	await frames(4)
	check(ln.powered, "inverting relay: side off -> output on")
	nl.set_on(true)
	await frames(4)
	check(not ln.powered, "inverting relay: side on -> output off")

	# timer: pulses
	x = 16.0
	var ct := crank(Vector3(x, 0, 1), 60.0)
	var g_t := place("gate_timer", Vector3(x, 0, 0)) as Gate
	var lt := place("lamp", Vector3(x, 0, -1)) as Lamp
	wire(ct, g_t)
	wire(g_t, lt)
	var flips := 0
	var was := lt.powered
	for k in 300:
		await get_tree().physics_frame
		if lt.powered != was:
			flips += 1
			was = lt.powered
	check(flips >= 6, "timer: pulses on and off (%d changes in 5 s)" % flips)

	# delay
	x = 19.0
	var dl := place("lever", Vector3(x, 0, 1.2)) as Lever
	var cdl := crank(Vector3(x, 0, 2.4), 60.0)
	var g_d := place("gate_delay", Vector3(x, 0, 0)) as Gate     # 0.5 s by default
	var ld := place("lamp", Vector3(x, 0, -1)) as Lamp
	wire(cdl, dl)
	wire(dl, g_d)
	wire(g_d, ld)
	dl.set_on(true)
	await frames(10)
	check(not ld.powered, "delay: not on straight away")
	await secs(0.8)
	check(ld.powered, "delay: on after half a second")

	# toggle latch: a pulse at the back flips it; supply from the side
	x = 23.0
	var btn := place("button", Vector3(x, 0, 1.2)) as PushButton
	var cbtn := crank(Vector3(x, 0, 2.4), 60.0)
	var g_l := place("gate_latch", Vector3(x, 0, 0)) as Gate
	var ll := place("lamp", Vector3(x, 0, -1)) as Lamp
	var csup := crank(Vector3(x + 1.2, 0, 0), 60.0)
	wire(cbtn, btn)
	wire(btn, g_l)
	wire(csup, g_l)
	wire(g_l, ll)
	await frames(4)
	check(not ll.powered, "latch: starts off")
	btn.press()
	await secs(2.0)
	check(ll.powered, "latch: one press turns it on (and it stays on after the button pops out)")
	btn.press()
	await secs(2.0)
	check(not ll.powered, "latch: another press turns it off")

	# counter: every 2 pulses
	x = 27.0
	var btn2 := place("button", Vector3(x, 0, 1.2)) as PushButton
	var cbt2 := crank(Vector3(x, 0, 2.4), 60.0)
	var g_c := place("gate_counter", Vector3(x, 0, 0)) as Gate
	var lc := place("lamp", Vector3(x, 0, -1)) as Lamp
	var csc := crank(Vector3(x + 1.2, 0, 0), 60.0)
	wire(cbt2, btn2)
	wire(btn2, g_c)
	wire(csc, g_c)
	wire(g_c, lc)
	btn2.press()
	await secs(1.8)
	var after1 := lc.powered
	btn2.press()
	var lit := false
	for k in 60:
		await get_tree().physics_frame
		lit = lit or lc.powered
	check(not after1 and lit, "counter: the second pulse lets power through")

	# --- sensors
	var cp := crank(Vector3(-5, 0, 6), 60.0)
	var plate := place("pressure_plate", Vector3(-5, 0, 5)) as Sensor
	var lp := place("lamp", Vector3(-5, 0, 3.8)) as Lamp
	wire(cp, plate)
	wire(plate, lp)
	await frames(4)
	check(not lp.powered, "pressure plate: nothing on it -> off")
	var weight := ore_at(BASE + Vector3(-5, 0.4, 5))
	await secs(0.8)
	check(lp.powered, "pressure plate: an ore chunk on it -> on")
	weight.queue_free()
	var ci := crank(Vector3(-8, 0, 6), 60.0)
	var eye := place("item_sensor", Vector3(-8, 0, 5)) as Sensor
	var li := place("lamp", Vector3(-9.2, 0, 5)) as Lamp
	wire(ci, eye)
	wire(eye, li)
	await frames(4)
	check(not li.powered, "item sensor: nothing in front -> off")
	ore_at(BASE + Vector3(-8, 0.3, 4.1))
	await secs(0.8)
	check(li.powered, "item sensor: something in front -> on")

	# --- sawmill: a log becomes planks worth more
	var csaw := crank(Vector3(5, 0, 10), 60.0)
	var mill := place("sawmill", Vector3(5, 0, 8)) as Sawmill
	wire(csaw, mill)
	var trees: Array = main.trees.filter(func(t): return not (t as ForestTree).giant)
	var lg := (trees[0] as ForestTree).fell(5, Vector3.RIGHT)
	lg.buck(5)
	await frames(2)
	var piece: Log = null
	for l in get_tree().get_nodes_in_group("logs"):
		if (l as Log).length < 1.2:
			piece = l
			break
	check(piece != null, "got a short log")
	var worth := piece.value()
	piece.global_transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), mill.global_transform * Vector3(0, 1.0, 0))
	piece.linear_velocity = Vector3.ZERO
	await secs(2.5)
	var planks: Array = get_tree().get_nodes_in_group("products").filter(func(p): return (p as Product).kind == "plank")
	var total := 0.0
	for p in planks:
		total += (p as Product).value
	check(not is_instance_valid(piece) and planks.size() >= 1, "the sawmill cuts the log into planks (%d)" % planks.size())
	check(absf(total - worth * 1.5) < 0.05 and Truck.sale_value(planks[0]) > 0.0, "planks are worth 1.5x the log ($%.2f -> $%.2f)" % [worth, total])

	# --- chipper: bark and leaves into a bag of mulch
	var cch := crank(Vector3(9, 0, 10), 60.0)
	var chip := place("chipper", Vector3(9, 0, 8)) as Chipper
	wire(cch, chip)
	for k in 30:
		var leaf := Leaf.new()
		main.add_child(leaf)
		leaf.setup(Color("6aa846"), 0.18)
		leaf.global_position = chip.global_transform * Vector3(randf_range(-0.2, 0.2), 1.3 + k * 0.05, randf_range(-0.2, 0.2))
	await secs(3.0)
	var bags: Array = get_tree().get_nodes_in_group("products").filter(func(p): return (p as Product).kind == "mulch")
	check(bags.size() >= 1 or chip.stock > 0.5, "the chipper shreds leaves into mulch (%d bags, %.2f in the hopper)" % [bags.size(), chip.stock])

	# --- planter, sprinkler and feller work on the real ground near a tree
	var tree: ForestTree = trees[3]
	var tp := tree.global_position
	var away := Vector3(0, 0, 14) - tp
	away.y = 0
	away = away.normalized()
	var spot := tp + away * 1.6
	spot.y = main.terrain.height_at(spot.x, spot.z)
	var yaw := atan2(away.x, away.z)               # its front (-Z) faces the tree
	var feller := Builds.finish("feller", main, Transform3D(Basis(Vector3.UP, yaw), spot), Builds.HOOP_DEFAULT, [], 1.0) as Feller
	var side := Vector3(away.z, 0, -away.x)
	var cf_at := spot + side * 1.5
	cf_at.y = main.terrain.height_at(cf_at.x, cf_at.z)
	var cf := Builds.finish("crank", main, Transform3D(Basis(), cf_at), Builds.HOOP_DEFAULT, [], 1.0) as Crank
	wire(cf, feller)
	await frames(2)
	Game.owned["saw"] = true
	player.equip("saw")
	await frames(20)
	feller.on_use(player)
	check(feller.saw_id == "saw" and player.tool == "hands" and not Game.in_toolbar("saw"), "put the bow saw into the tree feller")
	cf.charge = 120.0
	var fell_ok := false
	for k in 900:
		await get_tree().physics_frame
		if tree.felled:
			fell_ok = true
			break
	check(fell_ok, "the powered tree feller saws the tree down")
	player.take_down(feller)
	await frames(3)
	var back := false
	for t in get_tree().get_nodes_in_group("tool_items"):
		back = back or (t as ToolItem).tool == "saw"
	check(back, "taking the feller down gives the saw back (lying beside it)")

	# planter
	var pspot := Vector3(-4, 0, 22)
	pspot.y = main.terrain.height_at(pspot.x, pspot.z)
	var planter := Builds.finish("planter", main, Transform3D(Basis(), pspot), Builds.HOOP_DEFAULT, [], 1.0) as Planter
	var cpl_at := pspot + Vector3(1.5, 0, 0)
	cpl_at.y = main.terrain.height_at(cpl_at.x, cpl_at.z)
	var cpl := Builds.finish("crank", main, Transform3D(Basis(), cpl_at), Builds.HOOP_DEFAULT, [], 1.0) as Crank
	wire(cpl, planter)
	cpl.charge = 60.0
	var sap := Sapling.new()
	main.add_child(sap)
	sap.setup("oak")
	sap.global_position = planter.global_transform * Vector3(0, 1.2, 0)
	await secs(1.5)
	check(sap.is_rooted() and sap.global_position.distance_to(planter.global_position) > 1.5, "the planter plants a sapling from its hopper in front of it")
	# sprinkler next to it
	var sp_at := sap.global_position + Vector3(-1.5, 0, 0)
	sp_at.y = main.terrain.height_at(sp_at.x, sp_at.z)
	var spr := Builds.finish("sprinkler", main, Transform3D(Basis(), sp_at), Builds.HOOP_DEFAULT, [], 1.0) as Sprinkler
	wire(cpl, spr)
	await secs(1.5)
	check(sap.boost > 0.0, "the sprinkler waters saplings nearby")

	# --- products survive a save
	var ws := WorldSave.save(main)
	check((ws.get("products", []) as Array).size() >= 1, "planks and mulch are saved with the world")
	finished = true
