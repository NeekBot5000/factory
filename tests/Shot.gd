extends Node
## First-person screenshots. Run: xvfb-run -a godot --path . res://tests/Shot.tscn --rendering-driver opengl3
var main: Node3D
var player: Player
var t := 0.0
var step := 0
var tree: ForestTree
var plan: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	player = main.player
	var best := 1e9
	for tr in main.trees:
		var d: float = tr.global_position.distance_to(Vector3(0, 0, 12))
		if d < best:
			best = d
			tree = tr
	plan = [
		[2.0, "01_start", func(): pass],
		[3.5, "02_porch", func(): main.hud.hide_start = true],
		[5.0, "03_cabin", func(): _stand(Vector3(0, 0, 13), Vector3(0, 1.5, 0), -5)],
		[6.5, "04_tree", func(): _face_tree()],
		[10.0, "05_stripped", func(): _chop_lots()],
		[11.0, "06_chips_ground", func(): _look_down()],
		[11.12, "07_swing", func():
			_face_tree()
			player.start_chop()],
		[12.5, "08_holding", func():
			player.set("_yaw", player.get("_yaw") + PI * 0.6)
			player.rotation.y = player.get("_yaw")
			player.head.rotation.x = 0.0
			player.set("_pitch", 0.0)
			var c: Chip = main.chips[0]
			c.global_position = player.cam.global_position - player.cam.global_transform.basis.z * 1.0
			c.linear_velocity = Vector3.ZERO
			player.interact()],
		[14.0, "09_inside", func():
			player.drop_held()
			_stand(Vector3(1.2, Cabin.FLOOR_Y, 1.4), Vector3(-2, 1.3, -2.4), 0)],
	]
	(plan[0][2] as Callable).call()


func _stand(pos: Vector3, look_at: Vector3, pitch_deg: float) -> void:
	pos.y = maxf(pos.y, main.terrain.height_at(pos.x, pos.z)) + 0.05
	player.global_position = pos
	player.velocity = Vector3.ZERO
	var to := look_at - pos
	player.set("_yaw", atan2(-to.x, -to.z))
	player.set("_pitch", deg_to_rad(pitch_deg))


func _face_tree() -> void:
	var tp := tree.global_position
	var away := Vector3(0, 0, 12) - tp
	away.y = 0
	away = away.normalized()
	_stand(tp + away * (tree.radius + 1.1), tp, -8)


func _chop_lots() -> void:
	player.max_health = 10000.0
	player.health = 10000.0
	for k in 40:
		var yaw0: float = player.get("_yaw")
		player.head.rotation.x = deg_to_rad(randf_range(-35.0, 15.0))
		player.rotation.y = yaw0 + deg_to_rad(randf_range(-20.0, 20.0))
		player.call("_do_impact")
	player.max_health = 100.0
	player.health = 100.0


func _look_down() -> void:
	player.set("_pitch", deg_to_rad(-45.0))


func _process(delta: float) -> void:
	t += delta
	if step < plan.size() and t > float(plan[step][0]):
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://tests/shots/%s.png" % plan[step][1]))
		print("SHOT ", plan[step][1])
		step += 1
		if step < plan.size():
			(plan[step][2] as Callable).call()
		# (actions are listed with the shot they lead up to)
		else:
			get_tree().quit()
