extends Node
## Simulates mouse + keyboard input against the real builder (needs xvfb for a viewport).
var world: Node
var step := 0
var t := 0.0
var ok := true
var lever: Part
var before_demolish := 0
var target: Part


func _ready() -> void:
	Game.save_enabled = false
	world = load("res://scripts/World.gd").new()
	add_child(world)
	await get_tree().process_frame
	Game.money = 10000.0
	world.hud.close_panel()


func _mouse(pos: Vector2) -> void:
	Input.warp_mouse(pos)
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
				before_demolish = world.parts.size()
				_click(center, true)
				_click(center, false)
				step = 10
		10:
			if t > 3.9:
				_check(world.parts.size() < before_demolish, "demolish removed a part (%d -> %d)" % [before_demolish, world.parts.size()])
				var ev := InputEventKey.new()
				ev.keycode = KEY_Z
				ev.ctrl_pressed = true
				ev.pressed = true
				Input.parse_input_event(ev)
				step = 105
		105:
			if t > 4.05:
				_check(world.parts.size() == before_demolish, "Ctrl+Z restores the demolished part (%d)" % world.parts.size())
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
				world.hud.close_panel()
				world.clear_all(false)
				Game.unlocked["lever"] = true
				lever = world.place("lever", Vector3i(2, 0, 2), 0)
				target = world.place("conveyor", Vector3i(-2, 0, 2), 1)
				_key(KEY_N)
				step = 13
		13:
			if t > 4.8:
				_check(world.builder.mode == "wire", "N enters wire mode")
				var sp: Vector2 = world.rig.camera.unproject_position(lever.global_position + Vector3(0, 0.2, 0))
				_mouse(sp)
				step = 14
		14:
			if t > 5.0:
				var sp: Vector2 = world.rig.camera.unproject_position(lever.global_position + Vector3(0, 0.2, 0))
				_click(sp, true)
				_click(sp, false)
				step = 15
		15:
			if t > 5.2:
				var tp: Vector2 = world.rig.camera.unproject_position(target.global_position + Vector3(0, 0.15, 0))
				_mouse(tp)
				step = 16
		16:
			if t > 5.4:
				var tp: Vector2 = world.rig.camera.unproject_position(target.global_position + Vector3(0, 0.15, 0))
				_click(tp, true)
				_click(tp, false)
				step = 17
		17:
			if t > 5.6:
				_check(world.links.size() == 1, "wire tool linked lever -> conveyor (links=%d)" % world.links.size())
				_key(KEY_ESCAPE)
				step = 18
		18:
			if t > 5.8:
				var sp: Vector2 = world.rig.camera.unproject_position(lever.global_position + Vector3(0, 0.2, 0))
				_mouse(sp)
				step = 19
		19:
			if t > 6.0:
				var sp: Vector2 = world.rig.camera.unproject_position(lever.global_position + Vector3(0, 0.2, 0))
				_click(sp, true)
				_click(sp, false)
				step = 20
		20:
			if t > 6.3:
				_check(bool(lever.config.on), "clicking the lever toggles it on")
				_check(target.sig_in, "powered lever drives the wired belt input")
				print("INTERACT RESULT: ", "PASS" if ok else "FAIL")
				get_tree().quit(0 if ok else 1)
