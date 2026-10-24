extends Node
## Places every part in a grid and screenshots close-ups (model review).
var world: Node
var t := 0.0
var idx := 0
var views: Array = []


func _ready() -> void:
	Game.save_enabled = false
	Game.fresh_start = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	world = load("res://scripts/World.gd").new()
	add_child(world)
	await get_tree().process_frame
	world.hud.close_panel()
	world.hud.root.visible = false
	for i in range(-2, 3):
		for j in range(-2, 3):
			Game.plots[Vector2i(i, j)] = true
	Game.plots_changed.emit()
	var ids: Array = Defs.PARTS.keys()
	var per_row := 8
	for k in ids.size():
		var x := -12 + (k % per_row) * 3
		var z := -12 + (k / per_row) * 4
		var y := 1 if String(Defs.PARTS[ids[k]].kind) == "source" and String(Defs.PARTS[ids[k]].get("src", "")) == "drill" else 0
		world.place(ids[k], Vector3i(x, y, z), 1, false)
	for r in range(0, (ids.size() + per_row - 1) / per_row):
		for half in [0, 1]:
			views.append(Vector3(-12 + half * 12 + 4.5, 0.4, -12 + r * 4))


func _process(delta: float) -> void:
	t += delta
	var rig: CameraRig = world.rig
	if idx < views.size():
		rig._t_focus = views[idx]
		rig._t_dist = 9.5
		rig._t_yaw = 25.0
		rig._t_pitch = 32.0
		if t > 2.2:
			t = 0.0
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://tests/shots/gallery_%02d.png" % idx))
			idx += 1
	else:
		get_tree().quit()
