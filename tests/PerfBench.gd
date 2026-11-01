extends Node
## Not part of CI: a big factory (240 belts, 300 ore, 120 machines, carts, drones) for measuring frame time and draw
## calls. Run windowed: xvfb-run godot --path . res://tests/PerfBench.tscn --rendering-driver opengl3
var main: Node3D
const B := Vector3(-60, 40, -60)
func fin(id: String, p: Vector3, yaw := 0.0) -> Node3D:
	return Builds.finish(id, main, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), B + p), Builds.HOOP_DEFAULT, [], 1.0)
func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	var sb := LowPoly.static_box(main, Vector3(80, 1, 80), B + Vector3(0, -0.5, 0))
	sb.collision_layer = 1
	await measure("empty world")
	# 6 belt loops of 40 belts each, with items riding
	var ck := fin("windmill", Vector3(-30, 0, -30)) as Machine
	for loop in 6:
		var ox := -25.0 + loop * 8.0
		var prev: Machine = null
		for k in 40:
			var side := k / 10
			var i := k % 10
			var p: Vector3
			var yaw: float
			match side:
				0: p = Vector3(ox, 0, -20 + i); yaw = 180.0
				1: p = Vector3(ox + i * 0.0 + 1, 0, -10); yaw = 180.0
				2: p = Vector3(ox + 1, 0, -10 - i); yaw = 0.0
				_: p = Vector3(ox, 0, -20); yaw = 0.0
			var b := fin("conveyor", p, yaw) as Machine
			if k == 0:
				Circuit.toggle_wire(main, ck, b)
	await measure("+240 belts")
	for k in 300:
		var o := Ore.new()
		main.add_child(o)
		o.setup("stone", 0.13)
		o.global_position = B + Vector3(-25 + (k % 6) * 8, 1.0 + (k / 60) * 0.3, -20 + (k % 10))
	await measure("+300 ore chunks")
	var ids := ["sawmill", "smelter", "kiln", "assembler", "grabber", "lamp", "sprinkler", "crate", "item_sensor", "gate_timer", "lever", "chipper"]
	var prev: Machine = null
	for k in 120:
		var m := fin(ids[k % ids.size()], Vector3(-30 + (k % 20) * 2.5, 0, 5 + (k / 20) * 2.5)) as Machine
		if prev != null and prev.terminal_world().distance_to(m.terminal_world()) < 13:
			Circuit.toggle_wire(main, prev, m)
		prev = m
	Circuit.toggle_wire(main, ck, prev)
	await measure("+120 machines with wires")
	for k in 4:
		var x := 20 + k * 3
		for z in range(-25, 5):
			Rail.lay(main, Vector2i(x, z) + Vector2i(int(B.x), int(B.z)), false, B.y)
		var c := Builds.finish("minecart_3", main, Transform3D(Basis(), Vector3(B.x + x, Rail.at(Vector2i(x, -20) + Vector2i(int(B.x), int(B.z))).top(), B.z - 20)), Builds.HOOP_DEFAULT, [], 1.0) as Minecart
		var go := Builds.finish("cart_go", main, c.global_transform * Transform3D(Basis(), Vector3(0, Minecart.DECK_Y, 0)), Builds.HOOP_DEFAULT, [], 1.0) as Machine
		Builds.finish("lamp", main, c.global_transform * Transform3D(Basis(), Vector3(0, Minecart.DECK_Y, 1)), Builds.HOOP_DEFAULT, [], 1.0)
		Minecart.adopt_all(get_tree())
		Circuit.toggle_wire(main, c, go)
		var cell := Product.new()
		main.add_child(cell)
		cell.setup("battery_cell", 6.0, Color.WHITE)
		cell.set_charge(1.0)
		cell.global_position = c.global_transform * (c.cradle() + Vector3(0, 0.3, 0))
	for k in 6:
		var d := fin("drone_small", Vector3(-10 + k * 3, 0, 25)) as Drone
		var cell := Product.new()
		main.add_child(cell)
		cell.setup("battery_cell", 6.0, Color.WHITE)
		cell.set_charge(1.0)
		cell.global_position = d.global_transform * (d.cradle() + Vector3(0, 0.3, 0))
	await measure("+4 carts, 6 drones")
	print("PERF done")
	get_tree().quit()
func measure(label: String) -> void:
	for k in 60:
		await get_tree().physics_frame
	var n := 240
	var worst := 0
	var t0 := Time.get_ticks_usec()
	var last := t0
	for k in n:
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
	var pl: Node3D = main.player
	pl.global_position = B + Vector3(0, 0.5, 35)
	pl.set("_yaw", 0.0)
	pl.set("_pitch", deg_to_rad(-15))
	await get_tree().process_frame
	await get_tree().process_frame
	print("PERF draw calls %d  objects drawn %d  primitives %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	print("PERF %-28s frame %.2f ms (worst %.1f)  nodes %d" % [label, (Time.get_ticks_usec() - t0) / 1000.0 / n, worst / 1000.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
