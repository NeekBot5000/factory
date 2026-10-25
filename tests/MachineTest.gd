extends Node
## Headless test of the industrial side: pickaxes and ore, saplings from the last leaves, wires and power,
## pistons, conveyors, rotators, the truck caller, blueprint gating and saving machines + wires.
var main: Node3D
var player: Player
var fails := 0
var finished := false     # a script error stops the run part-way; that must not count as a pass
var floor_y := 40.0
const BASE := Vector3(60, 40, 60)


func check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func secs(s: float) -> void:
	await frames(int(s * 60.0))


func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	for id in ["pickaxe", "steel_pick", "wires", "hammer", "shears"]:
		Game.owned[id] = true
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await frames(3)
	player = main.player
	await run()
	check(finished, "the whole test ran to the end")
	print("MACHINE RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit()


func ores() -> Array:
	return get_tree().get_nodes_in_group("ores")


## A flat test floor up in the sky, away from trees and terrain bumps.
func make_floor() -> void:
	var sb := LowPoly.static_box(main, Vector3(40, 1, 40), BASE + Vector3(0, -0.5, 0))
	sb.collision_layer = 1


func place(id: String, at: Vector3, yaw_deg := 0.0) -> Node3D:
	return Builds.finish(id, main, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), BASE + at), Builds.HOOP_DEFAULT, [], 1.0)


func spawn_ore(at: Vector3, kind := "stone") -> Ore:
	var o := Ore.new()
	main.add_child(o)
	o.setup(kind, 0.14)
	o.global_position = at
	return o


func run() -> void:
	# --- mining
	var rock := Rock.new()
	main.add_child(rock)
	rock.position = Vector3(30, main.terrain.height_at(30, 30) + 0.2, 30)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	rock.build(rng, 0.8, "copper")
	var n0 := ores().size()
	rock.on_hit(rock.global_position + Vector3(0, 0.3, 0.6), Vector3(0, 0, 1), "hatchet")
	check(ores().size() == n0, "an axe just throws sparks off a rock")
	rock.on_hit(rock.global_position + Vector3(0, 0.3, 0.6), Vector3(0, 0, 1), "pickaxe")
	await frames(2)
	check(ores().size() == n0 + 1, "a pickaxe knocks a chunk off")
	var kinds := {}
	for i in 30:
		if not is_instance_valid(rock):
			break
		rock.on_hit(rock.global_position + Vector3(0, 0.3, 0.6), Vector3(0, 0, 1), "pickaxe")
	await frames(2)
	for o in ores():
		kinds[(o as Ore).kind] = true
	check(not is_instance_valid(rock) or rock.is_queued_for_deletion(), "enough hits and the rock crumbles away")
	check(kinds.has("copper"), "a copper vein gives copper ore (%s)" % ", ".join(kinds.keys()))
	var iron := Rock.new()
	main.add_child(iron)
	iron.position = Vector3(32, main.terrain.height_at(32, 30) + 0.2, 30)
	iron.build(rng, 0.8, "iron")
	var n1 := ores().size()
	iron.on_hit(iron.global_position + Vector3(0, 0.3, 0.6), Vector3(0, 0, 1), "pickaxe")
	check(ores().size() == n1, "iron is too hard for a plain pickaxe")
	iron.on_hit(iron.global_position + Vector3(0, 0.3, 0.6), Vector3(0, 0, 1), "steel_pick")
	check(ores().size() == n1 + 1, "the steel pickaxe gets through")
	var cu := spawn_ore(Vector3(30, 5, 30), "copper")
	check(Builds.resource_of(cu).res == "copper" and Truck.sale_value(cu) > Truck.sale_value(spawn_ore(Vector3(31, 5, 30))), "copper ore counts for builds and sells for more than stone")
	for q in main.get_tree().get_nodes_in_group("rocks"):
		if q.has_meta("rock_id") and int(q.get_meta("rock_id")) >= 1000:
			kinds["quarry"] = true
	check(kinds.has("quarry"), "there's a quarry out in the woods")
	var n_rocks := get_tree().get_nodes_in_group("rocks").filter(func(r): return r.has_meta("rock_id")).size()
	var gone := get_tree().get_nodes_in_group("rocks").filter(func(r): return r.has_meta("rock_id"))[3] as Rock
	gone.remove_from_group("rocks")
	gone.queue_free()
	await frames(2)
	check(main.regrow_rock() and get_tree().get_nodes_in_group("rocks").filter(func(r): return r.has_meta("rock_id")).size() == n_rocks, "mined-out rocks grow back over time")
	var gone2 := get_tree().get_nodes_in_group("rocks").filter(func(r): return r.has_meta("rock_id"))[5] as Rock
	var spot := gone2.global_position
	gone2.remove_from_group("rocks")
	gone2.queue_free()
	var blocker := Builds.finish("pillar", main, Transform3D(Basis(), spot - Vector3(0, 0.3, 0)), 3.05, [], 1.0)
	await frames(2)
	check(not main.regrow_rock(), "but not inside something you've built on the spot")
	blocker.remove_from_group("builds")
	blocker.queue_free()

	# --- the last leaves of a crown always hold saplings
	var t: ForestTree = main.trees[5]
	var fol := t.find_children("*", "Foliage", true, false)
	check(not fol.is_empty(), "trees have snippable crowns")
	if not fol.is_empty():
		var f := fol[0] as Foliage
		var s0 := get_tree().get_nodes_in_group("saplings").size()
		var guard := 0
		while is_instance_valid(f) and not f.is_queued_for_deletion() and guard < 3000:
			guard += 1
			if not f.snip(0, f.global_position, Vector3.UP, main):
				await frames(1)
		await frames(2)
		var got := get_tree().get_nodes_in_group("saplings").size() - s0
		check(got >= 1 and got <= 2, "snipping off the last leaves drops %d sapling(s)" % got)
	check(Sapling.GROW_TIME >= 300.0, "saplings take a good while to grow (%ds)" % int(Sapling.GROW_TIME))

	# --- blueprints gate machines
	check(not Builds.unlocked("piston"), "machines are locked until you own the blueprint")
	Game.owned["bp_piston"] = true
	check(Builds.unlocked("piston") and Builds.unlocked("basket"), "the blueprint unlocks it")

	# --- power and wires
	make_floor()
	await frames(2)
	var crank := place("crank", Vector3(0, 0, 0)) as Crank
	var lever := place("lever", Vector3(2, 0, 0)) as Lever
	var piston := place("piston", Vector3(4, 0, 0)) as Piston
	await frames(2)
	check(crank != null and lever != null and piston != null, "machines build")
	check(Circuit.toggle_wire(main, crank, lever) == "added" and Circuit.toggle_wire(main, lever, piston) == "added", "wires connect machines")
	check(Circuit.toggle_wire(main, crank, place("lever", Vector3(19, 0, 19))) == "", "but not across the map")
	var box := spawn_ore(BASE + Vector3(4, 0.2, -1.1))
	await secs(0.5)
	var z0 := box.global_position.z
	check(not piston.powered, "nothing runs without power")
	crank.wind()
	await secs(0.5)
	check(not piston.powered and lever.powered, "the lever's off: power stops there")
	lever.set_on(true)
	await secs(1.0)
	check(piston.powered and piston.ext > 0.95, "lever on: the piston shoves out")
	check(box.global_position.z < z0 - 0.5, "and pushes what's in front of it (%.2f m)" % (z0 - box.global_position.z))
	var lit := (piston.get_node("Lamp") as MeshInstance3D).material_override as StandardMaterial3D
	check(lit.emission_energy_multiplier > 1.0, "its lamp lights up")
	lever.set_on(false)
	await secs(1.0)
	check(not piston.powered and piston.ext < 0.05, "lever off: it pulls back")
	check(Circuit.toggle_wire(main, lever, piston) == "removed", "wiring the same pair again takes the wire down")
	await frames(2)

	# --- conveyor and ramp
	var belt := place("conveyor", Vector3(-4, 0, 4))
	var belt2 := place("conveyor", Vector3(-4, 0, 3))
	var ramp := place("ramp", Vector3(-4, 0, 2))
	Circuit.toggle_wire(main, crank, belt)
	Circuit.toggle_wire(main, belt, belt2)
	Circuit.toggle_wire(main, belt2, ramp)
	place("pillar", Vector3(-4, 0, 0))
	var belt3 := place("conveyor", Vector3(-4, 1, 0))
	Circuit.toggle_wire(main, ramp, belt3)
	var rider := spawn_ore(BASE + Vector3(-4, 0.75, 4.2))
	await secs(1.0)
	var rz := rider.global_position.z
	crank.charge = 30.0
	await secs(2.5)
	check(rider.global_position.z < rz - 1.5, "a running belt carries things forward (%.2f m)" % (rz - rider.global_position.z))
	var top := 0.0
	var on_top := false
	for k in 300:
		await frames(1)
		var rp := rider.global_position - BASE
		top = maxf(top, rp.y)
		if rp.y > 1.45 and rp.z < 0.3 and rp.z > -0.5:
			on_top = true
	check(top > 1.2, "and the ramp carries them up (%.2f m high)" % top)
	check(on_top, "onto a belt standing on a pillar at the top (%s)" % str(rider.global_position - BASE))

	# a belt on a pillar carries on from the top of the ramp
	var pil := place("pillar", Vector3(8, 0, 8))
	var on_pil := place("conveyor", Vector3(8, 1.0, 8))
	check(pil is StaticBody3D and not (pil is Machine) and Builds.fixed("pillar") and Builds.unlocked("pillar"), "the stone pillar is a plain grid block, no blueprint needed")
	check(absf(on_pil.global_position.y + Machines.BELT_Y - (BASE.y + Machines.BELT_Y + Machines.RAMP_RISE)) < 0.01, "a belt on a pillar lines up with the top of a ramp")

	# --- rotator
	var rot := place("rotator", Vector3(6, 0, 6)) as Rotator
	Circuit.toggle_wire(main, crank, rot)
	var on_it := spawn_ore(BASE + Vector3(6.3, 0.6, 6))
	crank.charge = 0.0
	await secs(1.5)
	rot.on_hammer()
	check(rot.stuck.size() == 1 and on_it.freeze, "the hammer sticks things to the rotator")
	var p0 := on_it.global_position
	crank.charge = 30.0
	await secs(2.0)
	check(on_it.global_position.distance_to(p0) > 0.2, "powered, it turns them round (%.2f m)" % on_it.global_position.distance_to(p0))
	check(Rotator.holding(on_it) == rot, "the hammer finds the rotator from the thing stuck on it")

	# --- truck caller
	var truck: Truck = main.ship_truck
	var sale := spawn_ore(truck.global_transform * Vector3(0, 1.6, 1.0), "iron")
	await secs(1.0)
	check(truck.load_value() > 0.0, "ore in the truck counts toward the load ($%.2f)" % truck.load_value())
	var caller := place("truck_caller", Vector3(-6, 0, -6))
	var button := place("button", Vector3(-6, 0, -4)) as PushButton
	Circuit.toggle_wire(main, crank, button)
	Circuit.toggle_wire(main, button, caller)
	await secs(0.5)
	check(truck.state == "parked", "the truck waits until called")
	button.press()
	await secs(0.5)
	check(truck.state == "leaving", "pressing the button wired to the truck caller sends the truck")

	# --- wire spool in hand
	player.equip("wires")
	await frames(20)
	check(player.wire_click(lever) == "picked" and player.wire_click(piston) == "added", "the wire spool connects two machines you click")

	# --- saving machines and wires
	lever.set_on(true)
	var data := Builds.save_world(main)
	var n_wires := data.filter(func(d): return d.kind == "wire").size()
	var n_mach := data.filter(func(d): return d.kind == "build" and Machines.is_machine(d.id)).size()
	check(n_wires >= 6 and n_mach >= 10, "the save holds the machines (%d) and wires (%d)" % [n_mach, n_wires])
	for n in get_tree().get_nodes_in_group("wires"):
		n.remove_from_group("wires")
		n.queue_free()
	for n in get_tree().get_nodes_in_group("machines"):
		n.remove_from_group("machines")
		n.remove_from_group("builds")
		n.queue_free()
	await frames(3)
	Builds.load_world(main, data.filter(func(d): return d.kind == "wire" or Machines.is_machine(String(d.get("id", "")))))
	await frames(3)
	var levers := get_tree().get_nodes_in_group("machines").filter(func(m): return m is Lever and (m as Lever).on)
	check(get_tree().get_nodes_in_group("wires").size() == n_wires, "wires come back after loading (%d)" % get_tree().get_nodes_in_group("wires").size())
	check(levers.size() == 1, "and the lever is still on")

	# --- taking builds down
	var tl := place("lever", Vector3(10, 0, 10))
	tl.set_meta("sale_value", 5.0)
	var w := Circuit.toggle_wire(main, tl, place("crank", Vector3(11, 0, 10)))
	var m0 := Game.money
	check(Player.build_of(tl.get_node("Model").get_child(0)) == tl, "the hammer knows which build a part belongs to")
	player.take_down(tl)
	await frames(3)
	check(not is_instance_valid(tl) and is_equal_approx(Game.money, m0 + 5.0), "hammer + X takes a build down and gives back what it's worth")
	check(w == "added" and get_tree().get_nodes_in_group("wires").all(func(x): return is_instance_valid(x.a) and is_instance_valid(x.b)), "and its wires go with it")
	check(Player.build_of(on_it) == null, "loose things aren't builds")
	# graphics fallback levels apply cleanly (only real builds step down on their own)
	var qn := main.get_node("Quality") as Quality
	qn.apply(3)
	check(not main.sun.shadow_enabled and main.grass_mmi.multimesh.visible_instance_count < main.grass_mmi.multimesh.instance_count and player.cam.far < 200.0, "the lowest graphics level drops shadows, grass and view distance")
	qn.apply(0)
	check(main.sun.shadow_enabled and main.grass_mmi.multimesh.visible_instance_count == -1 and Game.quality == 0, "and full quality puts them back")
	finished = true
