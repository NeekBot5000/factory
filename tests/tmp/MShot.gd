extends Node
var main: Node3D
var player: Player
var t := 0.0
var step := 0
var plan: Array = []
var crank: Crank
var ms := {}


func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	for id in Tools.SHOP_ORDER:
		Game.owned[id] = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	player = main.player
	main.hud.hide_start = true
	var o := Vector3(-7, 0, 9)
	var specs := [["crank", Vector3(0, 0, 3)], ["lever", Vector3(1, 0, 3)], ["conveyor", Vector3(2, 0, 3)], ["conveyor", Vector3(2, 0, 2)],
		["ramp", Vector3(2, 0, 0.5)], ["piston", Vector3(-1, 0, 1)], ["rotator", Vector3(-1, 0, -1)], ["button", Vector3(1, 0, 0)], ["truck_caller", Vector3(0, 0, -2)]]
	for sp in specs:
		var p: Vector3 = o + sp[1]
		p.y = main.terrain.height_at(p.x, p.z)
		var m := Builds.finish(sp[0], main, Transform3D(Basis(), p), 3.05, [], 1.0)
		ms[sp[0]] = m
	crank = ms.crank
	Circuit.toggle_wire(main, crank, ms.lever)
	Circuit.toggle_wire(main, ms.lever, ms.conveyor)
	Circuit.toggle_wire(main, crank, ms.piston)
	Circuit.toggle_wire(main, crank, ms.rotator)
	Circuit.toggle_wire(main, crank, ms.button)
	Circuit.toggle_wire(main, ms.button, ms.truck_caller)
	plan = [
		[2.0, "m01_line_off", func(): _stand(o + Vector3(4.5, 0, 6.0), o + Vector3(0, 0.3, 0.5), -22)],
		[4.0, "m02_line_on", func():
			crank.charge = 60.0
			(ms.lever as Lever).set_on(true)],
		[5.0, "m03_close_piston", func(): _stand(o + Vector3(-3.0, 0, 3.5), o + Vector3(-1, 0.4, 0.5), -18)],
		[6.5, "m04_menu", func():
			player.equip("hammer")
			main.open_build_menu()
			main.shop_ui.cat = Builds.CATEGORIES.size() - 1
			main.shop_ui.call("_render")],
		[8.0, "m05_place", func():
			main.close_ui()
			player.builder.start("conveyor")
			_stand(o + Vector3(5, 0, 4), o + Vector3(4, 0, 1), -35)],
		[9.5, "m06_wire_preview", func():
			player.builder.cancel()
			player.equip("wires")
			player.wire_from = ms.rotator
			_stand(o + Vector3(-3.5, 0, -2.5), o + Vector3(-1, 0.3, -1), -20)],
		[11.0, "m07_quarry", func():
			player.equip("pickaxe")
			_stand(Vector3(-22, 0, -14), Vector3(-28, 0, -20), -12)],
	]
	(plan[0][2] as Callable).call()


func _stand(pos: Vector3, look: Vector3, pitch_deg: float) -> void:
	pos.y = main.terrain.height_at(pos.x, pos.z) + 0.05
	player.global_position = pos
	player.velocity = Vector3.ZERO
	var to := look - pos
	player.set("_yaw", atan2(-to.x, -to.z))
	player.set("_pitch", deg_to_rad(pitch_deg))


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
