extends Node
## Screenshots of every feature. Run: xvfb-run -a godot --path . res://tests/Shot.tscn --rendering-driver opengl3
var main: Node3D
var player: Player
var t := 0.0
var step := 0
var tree: ForestTree
var plan: Array = []
var box: DeliveryBox


func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	Game.money = 5000.0
	for id in ["hatchet", "double_bit", "labrys", "drill"]:
		Game.owned[id] = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	player = main.player
	main.hud.hide_start = true
	var best := 1e9
	for tr in main.trees:
		var d: float = tr.global_position.distance_to(Vector3(0, 0, 12))
		if d < best:
			best = d
			tree = tr
	plan = [
		[3.0, "01_hatchet_ring", func():
			_face_tree(-5)
			player.equip("hatchet")],
		[4.5, "02_hatchet_stripped", func():
			for k in 6:
				_aim_rand()
				player.call("_do_impact")],
		[5.6, "03_double_bit", func():
			_face_tree(-5)
			player.equip("double_bit")],
		[6.2, "04_double_bit_swing", func(): player.start_swing()],
		[7.4, "05_labrys", func(): player.equip("labrys")],
		[8.0, "06_labrys_slam", func(): player.start_swing()],
		[9.4, "07_drill", func(): player.equip("drill")],
		[10.6, "08_log_truck", func():
			player.equip("hatchet")
			_load_truck()
			_stand(Vector3(2.5, 0, 12.5), main.ship_truck.global_position + Vector3(0, 1.2, 0), -10)],
		[12.5, "09_store", func(): main.open_computer()],
		[13.5, "10_product", func(): main.shop_ui.call("_open", "labrys")],
		[14.5, "11_orders", func():
			Game.buy("labrys") if not Game.is_owned("labrys") else null
			Game.owned.erase("drill")
			Game.buy("drill")
			Game.buy("phone")
			main.on_order_placed()
			main.shop_ui.page = "orders"
			main.shop_ui.call("_render")],
		[16.0, "12_phone", func():
			main.close_ui()
			Game.has_phone = true
			main.open_phone()],
		[29.0, "13_van_unloading", func():
			main.close_ui()
			_stand(Vector3(-4.0, 0, 7.0), Terrain.road_x(14) * Vector3(1, 0, 0) + Vector3(0, 1.5, 14), -6)],
		[40.0, "13b_van_leaving", func(): pass],
		[42.0, "14_boxes", func():
			var bs := main.get_children().filter(func(n): return n is DeliveryBox)
			if bs.size() > 0:
				box = bs[0]
				_stand(box.global_position + Vector3(0.9, 0, -1.1), box.global_position, -38)],
		[42.45, "15_box_opening", func():
			if box:
				box.open()],
		[43.0, "16_item_revealed", func(): pass],
		[44.5, "17_cabin_computer", func(): _stand(Vector3(0.4, Cabin.FLOOR_Y, 0.4), main.computer.global_position + Vector3(0, 1.0, 0), -15)],
	]
	(plan[0][2] as Callable).call()


func _stand(pos: Vector3, look: Vector3, pitch_deg: float) -> void:
	pos.y = maxf(pos.y, main.terrain.height_at(pos.x, pos.z)) + 0.05
	player.global_position = pos
	player.velocity = Vector3.ZERO
	var to := look - pos
	player.set("_yaw", atan2(-to.x, -to.z))
	player.set("_pitch", deg_to_rad(pitch_deg))


func _face_tree(pitch: float) -> void:
	var tp := tree.global_position
	var away := Vector3(0, 0, 12) - tp
	away.y = 0
	away = away.normalized()
	_stand(tp + away * (tree.radius + 1.0), tp + Vector3(0, 1.4, 0), pitch)


func _aim_rand() -> void:
	player.head.rotation.x = deg_to_rad(randf_range(-25.0, 10.0))
	player.rotation.y = float(player.get("_yaw")) + deg_to_rad(randf_range(-12.0, 12.0))


func _load_truck() -> void:
	var tr: Truck = main.ship_truck
	var k := 0
	for c in main.chips:
		c.global_position = tr.global_transform * Vector3(randf_range(-0.6, 0.6), 1.5 + k * 0.08, randf_range(0.2, 2.0))
		k += 1


func _process(delta: float) -> void:
	t += delta
	if step < plan.size() and t > float(plan[step][0]):
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://tests/shots/%s.png" % plan[step][1]))
		print("SHOT ", plan[step][1])
		step += 1
		if step < plan.size():
			(plan[step][2] as Callable).call()
		else:
			get_tree().quit()
