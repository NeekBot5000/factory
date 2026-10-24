class_name CameraRig
extends Node3D
## RTS-style orbit camera: WASD pan, Q/E rotate, wheel zoom, RMB orbit, MMB pan.

signal right_clicked

var camera: Camera3D
var focus := Vector3(0, 0, 0)
var yaw := 35.0
var pitch := 48.0
var dist := 22.0

var _t_focus := Vector3.ZERO
var _t_dist := 22.0
var _t_yaw := 35.0
var _t_pitch := 48.0
var _rmb_down := false
var _rmb_moved := 0.0
var _mmb_down := false
var enabled := true


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 52.0
	camera.near = 0.1
	camera.far = 700.0
	add_child(camera)
	camera.current = true
	_t_focus = focus
	_t_dist = dist
	_t_yaw = yaw
	_t_pitch = pitch
	_apply()


func _process(delta: float) -> void:
	if enabled:
		var b := Basis(Vector3.UP, deg_to_rad(yaw))
		var f := b * Vector3(0, 0, -1)
		var r := b * Vector3(1, 0, 0)
		var mv := Vector3.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			mv += f
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			mv -= f
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			mv += r
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			mv -= r
		var spd := (10.0 + _t_dist * 0.6) * (2.2 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		if mv != Vector3.ZERO:
			_t_focus += mv.normalized() * spd * delta
		if Input.is_key_pressed(KEY_Q):
			_t_yaw += 90.0 * delta
		if Input.is_key_pressed(KEY_E):
			_t_yaw -= 90.0 * delta
	_t_focus.x = clampf(_t_focus.x, -28.0, 28.0)
	_t_focus.z = clampf(_t_focus.z, -28.0, 28.0)
	_t_focus.y = clampf(_t_focus.y, 0.0, 10.0)
	var k := 1.0 - exp(-12.0 * delta)
	focus = focus.lerp(_t_focus, k)
	dist = lerpf(dist, _t_dist, k)
	yaw = lerpf(yaw, _t_yaw, k)
	pitch = lerpf(pitch, _t_pitch, k)
	_apply()


func _apply() -> void:
	var basis := Basis.from_euler(Vector3(-deg_to_rad(pitch), deg_to_rad(yaw), 0))
	camera.global_transform = Transform3D(basis, focus + basis * Vector3(0, 0, dist))


func jump_to(p: Vector3) -> void:
	_t_focus = p


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed and not e.ctrl_pressed:
			_t_dist = clampf(_t_dist * 0.9, 5.0, 70.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed and not e.ctrl_pressed:
			_t_dist = clampf(_t_dist / 0.9, 5.0, 70.0)
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			if e.pressed:
				_rmb_down = true
				_rmb_moved = 0.0
			else:
				if _rmb_down and _rmb_moved < 6.0:
					right_clicked.emit()
				_rmb_down = false
		elif e.button_index == MOUSE_BUTTON_MIDDLE:
			_mmb_down = e.pressed
	elif event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if _rmb_down:
			_rmb_moved += m.relative.length()
			_t_yaw -= m.relative.x * 0.3
			_t_pitch = clampf(_t_pitch + m.relative.y * 0.25, 15.0, 85.0)
		elif _mmb_down:
			var b := Basis(Vector3.UP, deg_to_rad(yaw))
			var s := _t_dist * 0.0016
			_t_focus += b * Vector3(-m.relative.x * s, 0, -m.relative.y * s)
