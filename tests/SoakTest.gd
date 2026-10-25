extends Node
## Random-input soak test: one of every build, wired machines, then a few minutes of mashing every input
## (tools, swings, grabs, building, wiring, taking things down, shipping), then save and reload.
## Passes if the reload brings back the same builds and wires (CI also fails on any script error).
var main: Node3D
var player: Player
var rng := RandomNumberGenerator.new()
var t := 0.0
var actions := {}


func _ready() -> void:
	Game.save_path = "user://timber_monkey.json"
	Game.save_enabled = true
	Game.reset()
	Game.money = 1e6
	for id in Tools.SHOP_ORDER:
		Game.owned[id] = true
	Game.has_phone = true
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	player = main.player
	rng.seed = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	# one of everything around the clearing, machines wired in a chain
	var prev: Machine = null
	var n := 0
	for id in Builds.ORDER:
		var p := Vector3(-12 + (n % 6) * 2.0, 0, 6 + (n / 6) * 3.0)
		p.y = main.terrain.height_at(p.x, p.z)
		var b := Builds.finish(id, main, Transform3D(Basis(), p), 3.05, [], 1.0)
		b.set_meta("sale_value", 3.0)
		if b is Machine:
			if prev != null:
				Circuit.toggle_wire(main, prev, b)
			prev = b
		n += 1
	for c in get_tree().get_nodes_in_group("machines"):
		if c is Crank:
			(c as Crank).charge = 100.0
		if c is Lever:
			(c as Lever).set_on(true)
	for i in 1200:     # 2 minutes of game time at 10 actions/s
		await _act()
		for k in 6:
			await get_tree().physics_frame
	print("SOAK actions ", actions)
	var n_builds := get_tree().get_nodes_in_group("builds").size()
	var n_wires := get_tree().get_nodes_in_group("wires").size()
	Game.save_game()
	main.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	Game.reset_memory_only()
	Game.load_game()
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	for k in 240:
		await get_tree().physics_frame
	var nb := get_tree().get_nodes_in_group("builds").size()
	var nw := get_tree().get_nodes_in_group("wires").size()
	print("SOAK reload: builds %d -> %d, wires %d -> %d" % [n_builds, nb, n_wires, nw])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	print("SOAK RESULT: %s" % ("PASS" if nb == n_builds and nw == n_wires and n_builds > 10 else "FAIL"))
	get_tree().quit()


func _act() -> void:
	var a := rng.randi() % 16
	actions[a] = actions.get(a, 0) + 1
	if main.shop_ui != null and a != 12:
		main.close_ui()
	match a:
		0, 1:
			var owned: Array = Tools.TOOL_ORDER.filter(func(x): return Game.in_toolbar(x))
			player.equip(owned[rng.randi() % owned.size()])
		2, 3:
			player.set("_yaw", float(player.get("_yaw")) + rng.randf_range(-1.2, 1.2))
			player.set("_pitch", clampf(rng.randf_range(-0.9, 0.5), -1.5, 1.5))
		4, 5:
			player.primary()
		6:
			player.force_trigger = not player.force_trigger
		7:
			player.interact()
		8:
			# walk somewhere near the cabin / forest
			var p := Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-15, 25))
			p.y = main.terrain.height_at(p.x, p.z) + 0.1
			player.global_position = p
			player.velocity = Vector3.ZERO
		9:
			player.drop_tool()
		10:
			player.set("_pouring", not bool(player.get("_pouring")))
		11:
			if player.tool == "hammer" and not player.builder.busy():
				player.builder.start(Builds.ORDER[rng.randi() % Builds.ORDER.size()])
			elif player.builder.busy():
				player.builder.rotate(1)
				player.builder.scroll(rng.randi_range(-1, 1))
		12:
			if rng.randf() < 0.3:
				main.open_build_menu()
		13:
			var b := Player.build_of(player.look_ray(4.0, 3).get("collider"))
			if b != null and player.tool == "hammer":
				player.take_down(b)
		14:
			if player.tool == "wires":
				player.wire_click(Machine.of(player.look_ray(4.0, 3).get("collider")))
		15:
			if rng.randf() < 0.2:
				Game.save_game()
				main.ship_truck.ship()
