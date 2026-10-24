extends Node
## Renders screenshots of a demo factory. Run under xvfb:
##   xvfb-run -a godot --path . res://tests/Shot.tscn --rendering-driver opengl3 --resolution 1280x720

var world: Node
var step := 0
var t := 0.0
var out_dir := "res://tests/shots"


func _ready() -> void:
	Game.save_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	world = load("res://scripts/World.gd").new()
	add_child(world)
	await get_tree().process_frame
	Game.money = 5e5
	Game.lifetime = 1e5
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


func _build_demo() -> void:
	# 8 parallel lines heading east into a collector column
	for k in 8:
		var z := -7 + k * 2
		var res := "dropper_copper" if k % 2 == 0 else "dropper_iron"
		for x in range(-8, 6):
			if x == -2:
				world.place("polisher", Vector3i(x, 0, z), 1)
			elif x == 1 and k % 2 == 0:
				world.place("smelter", Vector3i(x, 0, z), 1)
			else:
				world.place("conveyor", Vector3i(x, 0, z), 1)
		world.place(res, Vector3i(-7, 1, z), 1)
		world.place(res, Vector3i(-5, 1, z), 1)
		world.place("seller2", Vector3i(6, 0, z), 1)
	world.place("platform", Vector3i(-10, 0, -7), 0)
	world.place("platform", Vector3i(-10, 1, -7), 0)


func _process(delta: float) -> void:
	t += delta
	var rig: CameraRig = world.rig
	if step == 0 and t > 6.0:
		_snap("01_overview")
		rig._t_dist = 12.0
		rig._t_focus = Vector3(0, 0, -4)
		rig._t_yaw = 60.0
		rig._t_pitch = 35.0
		step = 1
	elif step == 1 and t > 8.5:
		_snap("02_closeup")
		world.hud.open_panel("upgrades")
		step = 2
	elif step == 2 and t > 9.2:
		_snap("03_upgrades")
		world.hud.open_panel("land")
		step = 3
	elif step == 3 and t > 9.8:
		_snap("04_land")
		world.hud.close_panel()
		world.builder.select_part("polisher")
		step = 4
	elif step == 4 and t > 10.6:
		_snap("05_building")
		get_tree().quit()


func _snap(name: String) -> void:
	print("DRAWCALLS ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " objects ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), " fps ", Engine.get_frames_per_second())
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [out_dir, name])
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size())
