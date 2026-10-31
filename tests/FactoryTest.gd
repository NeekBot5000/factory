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

	await second_wave()
	await mining_test()
	await truck_test()

	# --- products survive a save
	var ws := WorldSave.save(main)
	check((ws.get("products", []) as Array).size() >= 1, "planks and mulch are saved with the world")
	finished = true


func product(kind: String, at: Vector3, v := 1.0) -> Product:
	var p := Product.new()
	main.add_child(p)
	p.setup(kind, v, Color("e2c08d"))
	p.global_position = at
	return p


func ore(kind: String, at: Vector3) -> Ore:
	var o := Ore.new()
	main.add_child(o)
	o.setup(kind, 0.14)
	o.global_position = at
	return o


func products_of(kind: String) -> Array:
	return get_tree().get_nodes_in_group("products").filter(func(p): return is_instance_valid(p) and (p as Product).kind == kind)


func truck_test() -> void:
	var old: Truck = main.ship_truck
	check(old.level == 0, "you start with the small log truck")
	Game.money = 20000.0
	check(Game.buy("truck_big"), "buy the Big Truck in the shop")
	var arrived := false
	for k in 3600:
		await get_tree().physics_frame
		if main.ship_truck != old and main.ship_truck.state == "parked":
			arrived = true
			break
	check(arrived and main.ship_truck.level == 1 and not is_instance_valid(old), "the old truck drives off and the bigger one comes back and parks")
	var bed := ((main.ship_truck.bed_area.get_child(0) as CollisionShape3D).shape as BoxShape3D).size
	check(bed.x * bed.y * bed.z > 2.0 * 1.4 * 3.8 * 2.0, "its bed holds more than twice as much (%.1f m3)" % (bed.x * bed.y * bed.z))


func mining_test() -> void:
	# find the spot near the cabin richest in copper
	var best := Vector3.ZERO
	var bv := -1.0
	for x in range(-24, 25, 2):
		for z in range(8, 30, 2):
			var r := Mining.richness("copper", x, z)
			if r > bv:
				bv = r
				best = Vector3(x, 0, z)
	best.y = main.terrain.height_at(best.x, best.z)
	# dig by hand with a pickaxe
	var sh := Mining.dig(main, best, "pickaxe")
	check(sh != null and sh.depth > 0.0, "a pickaxe on the ground starts a mine shaft")
	var kinds := {}
	for k in 60:
		var got := sh.dig(1, 1)
		kinds[got] = int(kinds.get(got, 0)) + 1
	check(sh.depth > 10.0 and kinds.has("copper"), "digging down brings up copper from the deeper layers (%s at %.1f m)" % [str(kinds), sh.depth])
	check(not kinds.has("iron"), "a basic pick can't get iron out (it comes up as stone)")
	var again := Mining.dig(main, best + Vector3(0.3, 0, 0.2), "pickaxe")
	check(again == sh, "digging the same spot again goes down the same shaft")
	var deep := Shaft.new()
	main.add_child(deep)
	deep.setup(best + Vector3(5, 0, 0))
	deep.depth = 12.0
	var irons := 0
	for k in 80:
		if deep.dig(2, 2) == "iron":
			irons += 1
	check(irons > 0 or Mining.richness("iron", best.x + 5, best.z) < 0.15, "deep down, a steel pick finds iron (%d)" % irons)
	var ws := WorldSave.save(main)
	check((ws.get("shafts", []) as Array).size() >= 2, "shafts are saved with the world")
	# a drill rig drills down by itself, into a crate in front, and stops at its limit
	var at := best + Vector3(-4, 0, 0)
	at.y = main.terrain.height_at(at.x, at.z)
	var rig := Builds.finish("drill_rig", main, Transform3D(Basis(), at), Builds.HOOP_DEFAULT, [], 1.0) as DrillRig
	var cr_at := at + Vector3(0, 0, -1.0)
	cr_at.y = main.terrain.height_at(cr_at.x, cr_at.z) - 0.05
	var crate := Builds.finish("crate", main, Transform3D(Basis(), cr_at), Builds.HOOP_DEFAULT, [], 1.0) as Crate
	var cp := at + Vector3(1.5, 0, 0)
	cp.y = main.terrain.height_at(cp.x, cp.z)
	var crk := Builds.finish("crank", main, Transform3D(Basis(), cp), Builds.HOOP_DEFAULT, [], 1.0) as Crank
	wire(crk, rig)
	Game.owned["rock_drill"] = true
	player.equip("rock_drill")
	await frames(20)
	rig.on_use(player)
	check(rig.tool_id == "rock_drill" and player.tool == "hands", "put the rock drill into the drill rig")
	crk.charge = 120.0
	await secs(6.0)
	check(rig.depth > 0.4 and crate.contents().size() >= 1, "powered, it drills down and drops what it digs into the crate in front (%.1f m, %d in the crate)" % [rig.depth, crate.contents().size()])
	rig.depth = DrillRig.DRILLS.rock_drill.max - 0.01
	await secs(1.0)
	var d0 := rig.depth
	await secs(1.0)
	check(rig.drilled_out() and rig.depth == d0, "it stops at its limit (%d m): that spot is drilled out" % int(rig.depth))


func second_wave() -> void:
	var B2 := Vector3(-60, 40, -85)
	var sb := LowPoly.static_box(main, Vector3(60, 1, 30), B2 + Vector3(0, -0.5, 0))
	sb.collision_layer = 1
	await frames(2)
	# smelter: ore -> bars
	var cs := place("crank", Vector3(0, 0, 2), 0.0, B2) as Crank
	cs.charge = 120.0
	var smelter := place("smelter", Vector3(0, 0, 0), 0.0, B2) as Processor
	wire(cs, smelter)
	var o1 := ore("iron", smelter.global_transform * Vector3(0, 1.3, 0))
	var ov := o1.value
	await secs(4.5)
	var bars := products_of("iron_bar")
	check(not is_instance_valid(o1) and bars.size() == 1 and absf((bars[0] as Product).value - ov * 2.2) < 0.02, "the smelter turns iron ore into an iron bar worth 2.2x")
	# kiln: plank -> dried plank
	var ck := place("crank", Vector3(4, 0, 2), 0.0, B2) as Crank
	ck.charge = 120.0
	var kiln := place("kiln", Vector3(4, 0, 0), 0.0, B2) as Processor
	wire(ck, kiln)
	product("plank", kiln.global_transform * Vector3(0, 1.3, 0), 2.0)
	await secs(5.0)
	var dried := products_of("dry_plank")
	check(dried.size() == 1 and absf((dried[0] as Product).value - 2.8) < 0.02, "the kiln dries a plank (worth 1.4x)")
	# assembler: 2 planks -> chair worth 2.5x
	var ca := place("crank", Vector3(8, 0, 2), 0.0, B2) as Crank
	ca.charge = 120.0
	var asm := place("assembler", Vector3(8, 0, 0), 0.0, B2) as Processor
	wire(ca, asm)
	product("plank", asm.global_transform * Vector3(0, 1.3, 0), 2.0)
	product("plank", asm.global_transform * Vector3(0.1, 1.6, 0), 2.0)
	product("copper_bar", asm.global_transform * Vector3(-0.1, 1.9, 0), 5.0)     # not part of a chair: ignored
	await secs(4.5)
	var chairs := products_of("chair")
	check(chairs.size() == 1 and absf((chairs[0] as Product).value - 10.0) < 0.02 and Truck.sale_value(chairs[0]) > 9.0, "the assembler makes a chair from two planks, worth 2.5x ($%.2f)" % ((chairs[0] as Product).value if chairs.size() > 0 else 0.0))
	check(products_of("copper_bar").size() >= 1, "things the recipe doesn't need are left alone")
	asm.on_use(player)
	check(String(Processor.RECIPE_ORDER[asm.recipe]) == "table", "E switches what the assembler makes")
	# grabber arm moves a thing from in front to behind
	var cg := place("crank", Vector3(13, 0, 0), 0.0, B2) as Crank
	cg.charge = 120.0
	var grab := place("grabber", Vector3(12, 0, 0), 0.0, B2) as Grabber
	wire(cg, grab)
	var thing := ore("stone", B2 + Vector3(12, 0.3, -1.0))
	await secs(2.0)
	check(is_instance_valid(thing) and thing.global_position.z > B2.z + 0.5, "the grabber arm swings a chunk from in front to behind it")
	# sorter: only the sample kind goes left; splitter alternates
	var cso := place("crank", Vector3(17, 0, 3), 0.0, B2) as Crank
	cso.charge = 120.0
	var srt := place("sorter", Vector3(16, 0, 0), 0.0, B2) as Sorter
	wire(cso, srt)
	srt.filter = "iron"
	var a := ore("iron", B2 + Vector3(16, 0.75, 0.3))
	var bb := ore("stone", B2 + Vector3(16.2, 0.75, 0.3))
	await secs(2.0)
	check(a.global_position.x < B2.x + 15.5 and bb.global_position.z < B2.z - 0.4 and bb.global_position.x > B2.x + 15.6, "the sorter sends iron off to the left and lets stone carry on (%.2f / %.2f)" % [a.global_position.x - B2.x, bb.global_position.z - B2.z])
	# storage crate: stores things, empties when powered
	var crate := place("crate", Vector3(21, 0, 0), 0.0, B2) as Crate
	for k in 3:
		ore("stone", crate.global_transform * Vector3(randf_range(-0.2, 0.2), 0.6 + k * 0.2, 0))
	await secs(1.0)
	check(crate.contents().size() == 3, "the crate holds what lands in it")
	var cc := place("crank", Vector3(22.3, 0, 1), 0.0, B2) as Crank
	wire(cc, crate)
	cc.charge = 30.0
	await secs(2.5)
	check(crate.contents().size() == 0, "powered, it empties out of the front")
	# wireless: a transmitter on red powers a receiver on red far away
	var ct := place("crank", Vector3(25, 0, 1), 0.0, B2) as Crank
	var tx := place("transmitter", Vector3(25, 0, 0), 0.0, B2) as Wireless
	var rx := place("receiver", Vector3(-25, 0, 0), 0.0, B2) as Wireless
	var lamp := place("lamp", Vector3(-25, 0, -1), 0.0, B2) as Lamp
	wire(ct, tx)
	wire(rx, lamp)
	await frames(4)
	check(not lamp.powered, "wireless: nothing sent, the far lamp is off")
	ct.charge = 30.0
	await frames(6)
	check(lamp.powered, "wireless: power into the transmitter lights a lamp 50 m away")
	rx.on_use(player)
	await frames(6)
	check(not lamp.powered, "on a different channel it doesn't")
	# decorations sell for far more than their materials
	check(float(Builds.BUILDS.statue.sell) >= 3.0 and float(Builds.BUILDS.bench.sell) >= 2.0, "decorations are worth several times their materials")
	check(Builds.resource_of(product("plank", B2 + Vector3(0, 3, 8))).get("res", "") == "plank" and Builds.resource_of(product("copper_bar", B2 + Vector3(1, 3, 8))).get("res", "") == "copper_bar", "planks and bars count as build materials")
	# land
	check(Land.owns(Vector3(3, 0, 5)) and not Land.owns(Vector3(45, 0, 5)), "you start owning the land around the cabin, not beyond")
	var signs := main.get_node("Land").get_children().filter(func(c): return c is ForSale)
	check(signs.size() >= 4, "for-sale signs stand on the plots next to yours (%d)" % signs.size())
	Game.money = 100000.0
	var price := Land.next_price()
	var k := (signs[0] as ForSale).key
	(signs[0] as ForSale).on_use(player)
	check(Game.land.has(k) and absf(Game.money - (100000.0 - price)) < 0.01 and Land.next_price() > price, "buying a plot costs money, and the next one costs more")
	# trophies and the company sign
	check(Game.trophies.has("first_tree") and Game.trophies.has("first_plank") and Game.trophies.has("first_iron") and Game.trophies.has("first_furniture"), "milestones land on the trophy wall")
	Game.total_earned = 60000.0
	var sign: CompanySign = null
	for c in main.get_children():
		if c is CompanySign:
			sign = c
	await secs(2.5)
	check(sign != null and sign.tier == 4, "the company sign grows as the business earns more (tier %d)" % (sign.tier if sign else -1))
