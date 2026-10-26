extends Node
## Every control through real input events (keys, mouse buttons), not direct function calls: a binding that's
## missing or swallowed fails here. (Hammer + X once had no key handler at all and a direct-call test hid it.)
var main: Node3D
var player: Player
var fails := 0
var finished := false


func check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func key(k: Key, hold_frames := 2) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await frames(hold_frames)
	var u := e.duplicate() as InputEventKey
	u.pressed = false
	Input.parse_input_event(u)
	await frames(2)


func mouse(button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var u := e.duplicate() as InputEventMouseButton
	u.pressed = false
	Input.parse_input_event(u)
	await frames(2)


func _ready() -> void:
	Game.save_enabled = false
	Game.reset()
	for id in ["hatchet", "saw", "hammer", "wires"]:
		Game.owned[id] = true
	Game.has_phone = true
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await frames(5)
	player = main.player
	player.assume_captured = true
	await run()
	check(finished, "the whole test ran to the end")
	print("INPUT RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit()


func run() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await frames(2)
	var owned: Array = Tools.TOOL_ORDER.filter(func(t): return Game.in_toolbar(t))
	# number keys
	await key(KEY_2)
	await frames(10)
	check(player.tool == owned[1], "2 picks the second tool you own (%s)" % player.tool)
	await key(KEY_1)
	check(player.tool == owned[0], "1 picks the first (%s)" % player.tool)
	# mouse wheel
	var before := player.tool
	await mouse(MOUSE_BUTTON_WHEEL_DOWN)
	await frames(6)
	check(player.tool != before, "the mouse wheel switches tools (%s -> %s)" % [before, player.tool])
	# WASD moves, Space jumps
	var p0 := player.global_position
	await key(KEY_W, 40)
	check(player.global_position.distance_to(p0) > 0.5, "W walks (%.2f m)" % player.global_position.distance_to(p0))
	var y0 := player.global_position.y
	var top := y0
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	for i in 20:
		await frames(1)
		top = maxf(top, player.global_position.y)
	var u := e.duplicate() as InputEventKey
	u.pressed = false
	Input.parse_input_event(u)
	check(top > y0 + 0.4, "Space jumps (%.2f m)" % (top - y0))
	await frames(60)
	# Q drops the tool, E picks it back up
	await key(KEY_2)
	await frames(10)
	var t := player.tool
	await key(KEY_Q)
	await frames(30)
	check(player.tool == "hands" and not Game.in_toolbar(t), "Q drops the tool")
	var items := get_tree().get_nodes_in_group("tool_items")
	if not items.is_empty():
		var it := items[0] as Node3D
		var to := it.global_position - (player.global_position + Vector3(0, 1.58, 0))
		player.set("_yaw", atan2(-to.x, -to.z))
		player.set("_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
		await frames(3)
	await key(KEY_E)
	await frames(5)
	check(Game.in_toolbar(t), "E picks it back up")
	# R tips what you hold
	var log := Log.new()
	main.add_child(log)
	var tr: ForestTree = main.trees[0]
	log.setup_from(tr, 0, 3, Transform3D(Basis(), player.global_position + Vector3(0, 0.5, -1.2)))
	player.held = null
	await frames(5)
	player.held = log
	await frames(5)
	var r := InputEventKey.new()
	r.keycode = KEY_R
	r.physical_keycode = KEY_R
	r.pressed = true
	Input.parse_input_event(r)
	await frames(5)
	check(bool(player.get("_pouring")), "holding R tips what you're carrying")
	var ru := r.duplicate() as InputEventKey
	ru.pressed = false
	Input.parse_input_event(ru)
	await frames(3)
	check(not bool(player.get("_pouring")), "letting go of R stops")
	await key(KEY_E)
	check(player.held == null, "E drops it")
	# hammer: click opens the build menu, Esc closes it; R turns a placement, right click cancels it
	player.equip("hammer")
	await frames(20)
	player.set("_pitch", -0.6)
	await frames(3)
	await mouse(MOUSE_BUTTON_LEFT)
	await frames(3)
	check(main.shop_ui is BuildMenu, "hammer click opens the build menu")
	await key(KEY_ESCAPE)
	await frames(3)
	check(main.shop_ui == null, "Esc closes it")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.builder.start("bench")
	await frames(3)
	var turn0: float = player.builder.turn
	await key(KEY_R)
	check(player.builder.turn != turn0, "R turns the plan you're placing")
	await mouse(MOUSE_BUTTON_RIGHT)
	check(not player.builder.busy(), "right click cancels placing")
	# Tab: phone
	await key(KEY_TAB)
	await frames(3)
	check(main.shop_ui != null, "Tab opens the phone")
	await key(KEY_TAB)
	await frames(3)
	check(main.shop_ui == null, "Tab again closes it")
	# Esc: the settings menu (and the mouse is free to use it); sliders apply straight away; Esc resumes
	await key(KEY_ESCAPE)
	await frames(3)
	check(main.shop_ui is SettingsMenu and not player.controls_enabled, "Esc opens the settings menu")
	Game.settings.sens = 2.0
	Game.settings.fov = 90.0
	SettingsMenu.apply_all(main)
	check(is_equal_approx(player.mouse_sens, 0.005) and is_equal_approx(player.cam.fov, 90.0), "settings apply to the game (sensitivity, field of view)")
	await key(KEY_ESCAPE)
	await frames(3)
	check(main.shop_ui == null and player.controls_enabled, "Esc again resumes")
	finished = true
