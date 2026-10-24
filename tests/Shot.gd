extends Node
## Renders screenshots of a showcase factory. Run under xvfb:
##   xvfb-run -a godot --path . res://tests/Shot.tscn --rendering-driver opengl3 --resolution 1280x720

var world: Node
var t := 0.0
var step := 0
var out_dir := "res://tests/shots"
var shots: Array = []


func _ready() -> void:
	Game.save_enabled = false
	Game.fresh_start = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	world = load("res://scripts/World.gd").new()
	add_child(world)
	await get_tree().process_frame
	Game.money = 2.5e6
	Game.lifetime = 4e6
	Game.level = Game.level_for(Game.lifetime)
	for i in range(-1, 2):
		for j in range(-1, 2):
			Game.plots[Vector2i(i, j)] = true
	Game.plots_changed.emit()
	for id in Defs.PARTS:
		if Game.level >= int(Defs.PARTS[id].level):
			Game.unlocked[id] = true
	Game.unlocks_changed.emit()
	_build_demo()
	world.hud.close_panel()
	Input.warp_mouse(Vector2(2, 2))
	var rig: CameraRig = world.rig
	rig._t_focus = Vector3(-2, 0, -2)
	rig._t_dist = 26.0
	shots = [
		[8.0, "01_overview", func(): pass],
		[10.5, "02_wood", func(): _cam(Vector3(-6, 0.5, -9.5), 8.0, 35.0, 30.0)],
		[13.0, "03_metal", func(): _cam(Vector3(-5, 0.6, -4.5), 8.0, 50.0, 32.0)],
		[15.5, "04_logic", func(): _cam(Vector3(-6, 0.4, 2.5), 7.5, 20.0, 40.0)],
		[17.0, "05_inspector", func():
			world.hud.inspect(world.cells.get(Vector3i(-8, 0, -10)))],
		[18.5, "06_market", func():
			world.hud.inspect(null)
			world.hud.open_panel("market")],
		[19.5, "07_upgrades", func(): world.hud.open_panel("upgrades")],
		[20.5, "08_help", func(): world.hud.open_panel("help")],
		[22.0, "09_machines_tab", func():
			world.hud.close_panel()
			world.hud._set_cat("machines")
			world.builder.select_part("press")
			_cam(Vector3(2, 0.4, 3), 9.0, 30.0, 40.0)],
		[23.5, "10_dusk", func():
			world.builder.set_mode("none")
			world.day_time = 0.73
			_cam(Vector3(-4, 0, -4), 18.0, 35.0, 40.0)],
		[25.0, "11_night", func(): world.day_time = 0.88],
	]


func _cam(focus: Vector3, dist: float, yaw: float, pitch: float) -> void:
	var rig: CameraRig = world.rig
	rig._t_focus = focus
	rig._t_dist = dist
	rig._t_yaw = yaw
	rig._t_pitch = pitch


func P(id: String, x: int, y: int, z: int, r: int = 1, cfg: Dictionary = {}) -> Part:
	return world.place(id, Vector3i(x, y, z), r, false, 0.0, cfg)


func _build_demo() -> void:
	# --- wood line: tree farms -> rip saw (centre) -> two offset rip saws -> planks -> seller
	for z in [-11, -10]:
		P("treefarm_oak", -11, 0, z, 1)
	P("conveyor", -10, 0, -11, 2)
	for x in range(-10, -8):
		P("conveyor", x, 0, -10, 1)
	P("rip_saw", -8, 0, -10, 1, {"offset": 0.0})
	P("conveyor", -7, 0, -10, 1)
	P("rip_saw", -6, 0, -10, 1, {"offset": 0.075})
	P("rip_saw", -5, 0, -10, 1, {"offset": -0.075})
	P("chop_saw", -4, 0, -10, 1)
	for x in range(-3, 0):
		P("conveyor", x, 0, -10, 1)
	P("seller2", 0, 0, -10, 1)
	# --- metal line: drill -> crusher -> washer -> furnace -> press -> polisher -> seller
	P("drill_copper", -11, 1, -5)
	P("drill_iron", -10, 1, -5)
	P("conveyor", -11, 0, -5, 1)
	P("conveyor", -10, 0, -5, 1)
	P("crusher", -9, 0, -5, 1)
	P("washer", -8, 0, -5, 1)
	P("conveyor", -7, 0, -5, 1)
	P("furnace", -6, 0, -5, 1)
	P("conveyor", -5, 0, -5, 1)
	P("press", -4, 0, -5, 1)
	P("conveyor", -3, 0, -5, 1)
	P("press", -2, 0, -5, 1)
	P("conveyor", -1, 0, -5, 1)
	P("seller2", 0, 0, -5, 1)
	# --- logic demo: timer -> counter -> lamp ; sensor -> piston sorter ; teleporter
	P("drill_copper", -11, 1, 2)
	for x in range(-11, -8):
		P("conveyor", x, 0, 2, 1)
	P("sensor", -8, 0, 2, 1, {"filter": "boulder"})
	P("piston", -8, 0, 1, 2)
	world.add_link(Vector3i(-8, 0, 2), Vector3i(-8, 0, 1))
	P("conveyor", -8, 0, 3, 2)
	P("seller", -8, 0, 4, 1)
	for x in range(-7, -4):
		P("conveyor", x, 0, 2, 1)
	P("tele_in", -4, 0, 2, 0)
	P("tele_out", 3, 0, -1, 1)
	P("conveyor", 4, 0, -1, 1)
	P("seller", 5, 0, -1, 1)
	P("timer", -6, 0, 4, 0, {"interval": 1.0})
	P("counter", -5, 0, 4, 0, {"n": 3})
	P("lamp", -4, 0, 4, 0)
	P("lever", -6, 0, 5, 0, {"on": true})
	P("gate_and", -5, 0, 5, 0)
	world.add_link(Vector3i(-6, 0, 4), Vector3i(-5, 0, 4))
	world.add_link(Vector3i(-5, 0, 4), Vector3i(-5, 0, 5))
	world.add_link(Vector3i(-6, 0, 5), Vector3i(-5, 0, 5))
	world.add_link(Vector3i(-5, 0, 5), Vector3i(-4, 0, 4))
	# --- showroom row of other parts
	var x0 := 0
	for id in ["splitter", "grate", "ramp", "door", "polisher", "packer", "gang_saw", "platform"]:
		P(id, x0, 0, 3, 1)
		x0 += 1


func _process(delta: float) -> void:
	t += delta
	if step < shots.size() and t > float(shots[step][0]):
		_snap(shots[step][1])
		step += 1
		if step < shots.size():
			(shots[step][2] as Callable).call()
		else:
			get_tree().quit()


func _snap(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [out_dir, name])
	img.save_png(path)
	print("SHOT %s draw=%d" % [name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
