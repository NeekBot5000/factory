extends Node
## Simulates mouse + keyboard input against the real builder (needs xvfb for a viewport).
var world: Node
var step := 0
var t := 0.0
var ok := true


func _ready() -> void:
	Game.save_enabled = false
	world = load("res://scripts/World.gd").new()
	add_child(world)
	await get_tree().process_frame
	Game.money = 10000.0
	world.hud.close_panel()


func _mouse(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _click(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _key(k: Key) -> void:
	for pr in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pr
		Input.parse_input_event(e)


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		ok = false


func _process(delta: float) -> void:
	t += delta
	var center := get_viewport().get_visible_rect().size * 0.5
	match step:
		0:
			if t > 1.0:
				_key(KEY_2)   # category droppers: slot 2 -> iron? (not unlocked) use belts instead
				step = 1
		1:
			if t > 1.3:
				world.builder.select_part("conveyor")
				_mouse(center)
				step = 2
		2:
			if t > 1.8:
				_check(world.builder.hover_ok, "hover raycast hits ground (cell %s)" % str(world.builder.hover_cell))
				_click(center, true)
				_click(center, false)
				step = 3
		3:
			if t > 2.2:
				_check(world.parts.size() == 1, "click placed a conveyor (parts=%d)" % world.parts.size())
				# drag paint a line
				_mouse(center + Vector2(-120, 0))
				step = 4
		4:
			if t > 2.5:
				_click(center + Vector2(-120, 0), true)
				step = 5
		5:
			if t > 2.6:
				_mouse(center + Vector2(-60, 0))
				step = 6
		6:
			if t > 2.8:
				_mouse(center + Vector2(60, 0))
				step = 7
		7:
			if t > 3.0:
				_click(center + Vector2(60, 0), false)
				_check(world.parts.size() > 3, "drag painted multiple belts (parts=%d)" % world.parts.size())
				# demolish
				_key(KEY_T)
				step = 8
		8:
			if t > 3.3:
				_check(world.builder.mode == "demolish", "T enters demolish mode")
				var before: int = world.parts.size()
				_mouse(center)
				step = 9
		9:
			if t > 3.6:
				var before: int = world.parts.size()
				_click(center, true)
				_click(center, false)
				step = 10
		10:
			if t > 3.9:
				_check(world.parts.size() < 5, "demolish removed a part (parts=%d)" % world.parts.size())
				_key(KEY_ESCAPE)
				step = 11
		11:
			if t > 4.2:
				_check(world.builder.mode == "none", "Esc cancels tool")
				_key(KEY_U)
				step = 12
		12:
			if t > 4.5:
				_check(world.hud.modal.visible and world.hud.panel_name == "upgrades", "U opens upgrades")
				print("INTERACT RESULT: ", "PASS" if ok else "FAIL")
				get_tree().quit(0 if ok else 1)
