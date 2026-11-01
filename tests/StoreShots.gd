extends Node
## Not part of CI: stages the itch.io screenshots in docs/itch/ (run windowed, see docs/itch/README.md).
var main: Node3D
var player: Player
var t := 0.0
var step := 0
var busy := false
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
func stand(pos: Vector3, look: Vector3) -> void:
	pos.y = main.terrain.height_at(pos.x, pos.z) + 0.05
	player.global_position = pos
	player.velocity = Vector3.ZERO
	var to := look - (pos + Vector3(0, 1.58, 0))
	player.set("_yaw", atan2(-to.x, -to.z))
	player.set("_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
func fin(id: String, x: float, z: float, yaw := 0.0, y_off := 0.0) -> Node3D:
	return Builds.finish(id, main, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(x, main.terrain.height_at(x, z) + y_off, z)), Builds.HOOP_DEFAULT, [], 1.0)
func clear_area(c: Vector3, r: float) -> void:
	for g in ["trees", "bushes", "rocks", "foliage"]:
		for n in get_tree().get_nodes_in_group(g):
			var nd := n as Node3D
			if nd != null and Vector2(nd.global_position.x - c.x, nd.global_position.z - c.z).length() < r:
				nd.queue_free()
	for tr in main.trees:
		if is_instance_valid(tr) and Vector2(tr.global_position.x - c.x, tr.global_position.z - c.z).length() < r:
			tr.queue_free()
var _cam: Camera3D
func view(pos: Vector3, look: Vector3, fov := 60.0) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		main.add_child(_cam)
	_cam.fov = fov
	_cam.global_position = pos
	_cam.look_at(look, Vector3.UP)
	_cam.make_current()
func shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/itch/%s.png" % n))
func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	for id in ["hatchet", "labrys", "hammer", "chainsaw"]:
		Game.owned[id] = true
	for x in range(-6, 6):
		for z in range(-6, 6):
			Game.land.append("%d,%d" % [x, z])
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await frames(3)
	player = main.player
	main.hud.visible = false
	await peel()
func peel() -> void:
	busy = true
	var trees: Array = main.trees.duplicate().filter(func(tr): return not (tr as ForestTree).felled and not tr.has_meta("legendary"))
	trees.sort_custom(func(a, b): return a.global_position.distance_to(Vector3(2, 0, 16)) < b.global_position.distance_to(Vector3(2, 0, 16)))
	var tr: ForestTree = trees[0]
	player.equip("labrys")
	await frames(30)
	var tp := tr.global_position
	for k in 14:
		var a := 0.6 + k * 0.35
		stand(tp + Vector3(cos(a), 0, sin(a)) * (tr.radius + 0.9), tp + Vector3(0, 0.9 + (k % 3) * 0.5, 0))
		await frames(2)
		player.call("_do_impact")
		await frames(4)
	stand(tp + Vector3(cos(1.1), 0, sin(1.1)) * (tr.radius + 1.6), tp + Vector3(0, 1.0, 0))
	await frames(40)
	player.call("start_swing")
	await frames(9)
	shot("01_peel")
	busy = false
	step = 1
func _process(d: float) -> void:
	t += d
	if busy:
		return
	if step == 1:
		step = 2
		_truck()
	elif step == 3:
		step = 4
		_factory()
	elif step == 5:
		step = 6
		_rails()
	elif step == 7:
		step = 8
		_build()
	elif step == 9:
		get_tree().quit()
func _truck() -> void:
	busy = true
	var trk: Node3D = null
	for c in main.get_children():
		if c is Truck and (c as Truck).role == "ship":
			trk = c
	player.equip("hatchet")
	if trk != null:
		var k := 0
		for ch in main.chips:
			if is_instance_valid(ch):
				ch.global_position = trk.global_transform * Vector3(randf_range(-0.7, 0.7), 1.3 + k * 0.04, randf_range(-1.4, 1.4))
				ch.linear_velocity = Vector3.ZERO
				k += 1
		await frames(90)
		var back: Vector3 = trk.global_position + trk.global_basis * Vector3(3.0, 4.2, 6.0)
		view(back, trk.global_position + trk.global_basis * Vector3(0, 0.8, 0.0))
	await frames(30)
	shot("02_truck")
	busy = false
	step = 3
func _factory() -> void:
	busy = true
	var ox := 16.0
	var oz := -8.0
	clear_area(Vector3(ox, 0, oz), 12.0)
	await frames(2)
	var wm := fin("windmill", ox - 2, oz) as Machine
	var prev: Machine = null
	for k in 6:
		var b := fin("conveyor", ox, oz - k, 0.0) as Machine
		if prev == null:
			Circuit.toggle_wire(main, wm, b)
		prev = b
	var saw := fin("sawmill", ox, oz - 6.0) as Machine
	Circuit.toggle_wire(main, wm, saw)
	var sm := fin("smelter", ox + 2, oz - 3) as Machine
	var asm := fin("assembler", ox + 2, oz - 5) as Machine
	var gb := fin("generator", ox + 4, oz - 2) as Machine
	var bt := fin("battery", ox + 4, oz - 4) as Machine
	var lp := fin("lamp", ox + 3, oz - 7) as Machine
	var cr := fin("crate", ox - 2, oz - 6) as Machine
	for pair in [[wm, bt], [bt, sm], [sm, asm], [bt, gb], [asm, lp]]:
		Circuit.toggle_wire(main, pair[0], pair[1])
	for k in 8:
		var o := Ore.new()
		main.add_child(o)
		o.setup("copper" if k % 2 == 0 else "iron", 0.13)
		o.global_position = Vector3(ox, main.terrain.height_at(ox, oz) + 1.0, oz - k * 0.6)
	var c := Product.new()
	main.add_child(c)
	c.setup("battery_cell", 6.0, Color.WHITE)
	c.set_charge(0.8)
	c.global_position = bt.terminal_world() + Vector3(0, 0.3, 0)
	await frames(120)
	var gy: float = main.terrain.height_at(ox, oz - 3)
	view(Vector3(ox - 4.0, gy + 4.0, oz + 3.5), Vector3(ox + 1.0, gy + 0.3, oz - 3.5), 55.0)
	await frames(20)
	shot("03_factory")
	busy = false
	step = 5
func _rails() -> void:
	busy = true
	var x := -14
	clear_area(Vector3(x, 0, 4), 11.0)
	await frames(2)
	for z in range(-2, 12):
		Rail.lay(main, Vector2i(x, z), false)
	Rail.lay_curve(main, Vector2i(x, -3), Vector2i(0, -1))
	for k in 4:
		Rail.lay(main, Vector2i(x + 1 + k, -3), true)
	var r := Rail.at(Vector2i(x, 4))
	var cart := Builds.finish("minecart_3", main, Transform3D(Basis(), Vector3(x, r.top(), 4)), Builds.HOOP_DEFAULT, [], 1.0) as Minecart
	var ids := ["rail_layer", "drill_rig", "crate"]
	for k in 3:
		Builds.finish(ids[k], main, cart.global_transform * Transform3D(Basis(), Vector3(0, Minecart.DECK_Y, k)), Builds.HOOP_DEFAULT, [], 1.0)
	Minecart.adopt_all(get_tree())
	var cell := Product.new()
	main.add_child(cell)
	cell.setup("battery_cell", 6.0, Color.WHITE)
	cell.set_charge(0.9)
	cell.global_position = cart.global_transform * (cart.cradle() + Vector3(0, 0.3, 0))
	var dr := fin("drone_medium", x + 1.8, 7.0) as Drone
	var dc := Product.new()
	main.add_child(dc)
	dc.setup("battery_cell", 6.0, Color.WHITE)
	dc.set_charge(1.0)
	dc.global_position = dr.global_transform * (dr.cradle() + Vector3(0, 0.3, 0))
	var pl := Product.new()
	main.add_child(pl)
	pl.setup("iron_bar", 6.0, Color.WHITE)
	pl.global_position = dr.global_position + Vector3(0, 0.3, 0)
	fin("cart_sensor", x + 1, 9, 90.0)
	await frames(200)
	var ry: float = main.terrain.height_at(x, 5)
	view(Vector3(x + 4.5, ry + 2.6, 10.5), Vector3(x + 0.6, ry + 1.4, 4.5), 58.0)
	await frames(20)
	shot("04_rails_drone")
	busy = false
	step = 7
func _build() -> void:
	busy = true
	var bx := 6.0
	var bz := 24.0
	clear_area(Vector3(bx, 0, bz), 8.0)
	await frames(2)
	var bp := Blueprint.new()
	main.add_child(bp)
	bp.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(bx + 1.2, main.terrain.height_at(bx + 1.2, bz), bz))
	bp.setup("statue", Builds.HOOP_DEFAULT, main, 1.0)
	var made := [fin("bench", bx - 1.8, bz + 1.0, 200.0), fin("lamppost", bx - 2.6, bz - 0.8), fin("bark_wreath", bx - 0.6, bz - 1.4, 180.0), fin("garden_table", bx - 0.4, bz + 2.0, 160.0), fin("fountain", bx + 3.6, bz + 1.5)]
	for m in made:
		print("SHOT build ", m, " at ", (m as Node3D).global_position if m != null else Vector3.ZERO)
	await frames(30)
	var gy: float = main.terrain.height_at(bx, bz)
	view(Vector3(bx + 1.0, gy + 2.4, bz + 6.5), Vector3(bx + 0.2, gy + 0.6, bz + 0.3), 55.0)
	await frames(5)
	shot("05_build")
	# the shop on the cabin computer
	_cam.clear_current()
	player.cam.make_current()
	Game.money = 2480.0
	main.call("open_computer")
	await frames(30)
	main.hud.visible = true
	await frames(5)
	shot("06_shop")
	busy = false
	step = 9
