class_name Player
extends CharacterBody3D
## First-person lumberjack. WASD + mouse look, Shift sprint, Space jump, 1-5 / wheel switch tools.
## Left click: use tool (or click things like boxes). E: use / pick up / drop. Tab: phone.

signal health_changed(health: float, max_health: float)
signal hurt(amount: float)
signal fainted
signal revived
signal tool_changed(id: String)

const WALK := 4.2
const SPRINT := 6.8
const JUMP := 4.6
const GRAVITY := 12.0
const GRAB_REACH := 2.6
const HOLD_OFFSET := Vector3(0.0, -0.28, -0.9)

var max_health := 100.0
var health := 100.0
var head: Node3D
var cam: Camera3D
var arm: Node3D
var hand_flat: Node3D
var hand_fist: Node3D
var tool_root: Node3D
var tool_model: Node3D
var tool := "hands"
var held: RigidBody3D = null
var spawn_xform := Transform3D.IDENTITY
var mouse_sens := 0.0025
var controls_enabled := true
var chops := 0
var pieces_stripped := 0

var _yaw := 0.0
var _pitch := 0.0
var _swing := -1.0
var _impact_done := false
var _drill_cd := 0.0
var _drilling := false
var _equip_t := 1.0
var _since_hurt := 99.0
var _shake := 0.0
var _bob := 0.0
var _step_acc := 0.0
var _snag := 0.0
var _arm_base := Vector3(0.26, -0.3, -0.46)
var _cap: CapsuleShape3D
var _mouse_avg := 10.0
const STEP_H := 0.42


func _ready() -> void:
	collision_layer = 4
	add_to_group("player")
	collision_mask = 1          # items don't block or shove the player; the player pushes them (see _push_items)
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	_cap = cap
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.58
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.03
	cam.far = 400.0
	head.add_child(cam)
	cam.current = true
	_build_arm()
	spawn_xform = global_transform
	_yaw = rotation.y
	rotation.y = 0.0
	Game.tools_changed.connect(_on_tools_changed)


func _build_arm() -> void:
	arm = Node3D.new()
	arm.position = _arm_base
	cam.add_child(arm)
	var sleeve := LowPoly.mat(Color("b8322c"), 0.9)
	var plaid := LowPoly.mat(Color("2a2a2a"), 0.9)
	var skin := LowPoly.mat(Color("e0a989"), 0.7)
	LowPoly.mesh_instance(arm, LowPoly.cyl(0.042, 0.05, 0.34, 6), sleeve, Vector3(0, 0, 0.17), Vector3(90, 0, 0))
	LowPoly.mesh_instance(arm, LowPoly.cyl(0.051, 0.051, 0.025, 6), plaid, Vector3(0, 0, 0.08), Vector3(90, 0, 0))
	LowPoly.mesh_instance(arm, LowPoly.cyl(0.046, 0.046, 0.04, 6), plaid, Vector3(0, 0, 0.0), Vector3(90, 0, 0))
	LowPoly.mesh_instance(arm, LowPoly.cyl(0.03, 0.034, 0.07, 6), skin, Vector3(0, 0, -0.05), Vector3(90, 0, 0))
	# flat karate hand
	hand_flat = Node3D.new()
	arm.add_child(hand_flat)
	LowPoly.mesh_instance(hand_flat, LowPoly.box(Vector3(0.026, 0.085, 0.11)), skin, Vector3(0, 0.0, -0.13))
	LowPoly.mesh_instance(hand_flat, LowPoly.box(Vector3(0.024, 0.075, 0.035)), skin, Vector3(0, -0.004, -0.2))
	LowPoly.mesh_instance(hand_flat, LowPoly.box(Vector3(0.022, 0.022, 0.06)), skin, Vector3(0.016, 0.036, -0.1), Vector3(0, -20, 0))
	# closed fist gripping a tool
	hand_fist = Node3D.new()
	arm.add_child(hand_fist)
	LowPoly.mesh_instance(hand_fist, LowPoly.box(Vector3(0.06, 0.075, 0.08)), skin, Vector3(0, 0.0, -0.12))
	LowPoly.mesh_instance(hand_fist, LowPoly.box(Vector3(0.062, 0.03, 0.05)), skin, Vector3(0.0, -0.035, -0.15))
	tool_root = Node3D.new()
	tool_root.position = Vector3(0, -0.01, -0.13)
	arm.add_child(tool_root)
	for m in arm.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply_tool_visuals()


func tdef() -> Dictionary:
	return Tools.TOOLS[tool]


func equip(id: String) -> void:
	if not Game.is_owned(id) or not Tools.TOOLS.has(id) or id == tool:
		return
	tool = id
	_swing = -1.0
	_equip_t = 0.0
	_apply_tool_visuals()
	Sfx.play("equip")
	tool_changed.emit(tool)


func _apply_tool_visuals() -> void:
	if tool_model != null:
		tool_model.queue_free()
		tool_model = null
	hand_flat.visible = tool == "hands"
	hand_fist.visible = tool != "hands"
	if tool != "hands":
		tool_model = Tools.build_model(tool, tool_root)
		match tool:
			"drill":
				tool_model.rotation_degrees = Vector3(0, 0, 0)
				tool_model.position = Vector3(0, -0.02, 0.0)
			"labrys":
				tool_model.rotation_degrees = Vector3(-40, 0, 0)
				tool_model.position = Vector3(0, 0, 0.0)
			_:
				tool_model.rotation_degrees = Vector3(-35, 0, 0)


func _on_tools_changed() -> void:
	pass


func cycle_tool(step: int) -> void:
	var owned: Array = Tools.TOOL_ORDER.filter(func(t): return Game.is_owned(t))
	var i := owned.find(tool)
	equip(owned[posmod(i + step, owned.size())])


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls_enabled:
		var m := event as InputEventMouseMotion
		# Browsers sometimes report one bogus giant jump while the pointer is locked; drop those spikes.
		var len := m.relative.length()
		if len > 120.0 and len > _mouse_avg * 8.0:
			return
		_mouse_avg = lerpf(_mouse_avg, len, 0.2)
		_yaw -= m.relative.x * mouse_sens
		_pitch = clampf(_pitch - m.relative.y * mouse_sens, deg_to_rad(-88.0), deg_to_rad(88.0))
	elif event is InputEventMouseButton and event.pressed:
		var b := event as InputEventMouseButton
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if controls_enabled:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if b.button_index == MOUSE_BUTTON_LEFT:
			primary()
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			interact()
		elif b.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_tool(-1)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_tool(1)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if not controls_enabled:
			return
		if k == KEY_E or k == KEY_F:
			interact()
		elif k == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif k == KEY_TAB:
			if Game.has_phone:
				get_parent().call("open_phone")
			else:
				Game.toast.emit("No phone", Color("ffd27a"))
		elif k >= KEY_1 and k <= KEY_5:
			var id: String = Tools.TOOL_ORDER[k - KEY_1]
			if Game.is_owned(id):
				equip(id)


## Left click: click an object (box), throw what you hold, or swing the tool.
func primary() -> void:
	if not controls_enabled:
		return
	if held != null:
		return
	var hit := look_ray(float(tdef().reach), 1 | 2)
	if not hit.is_empty() and hit.collider.has_method("on_click"):
		hit.collider.call("on_click", self)
		return
	if bool(tdef().get("hold", false)):
		return   # continuous tools run while the button is held (see _physics_process)
	start_swing()


## E: use an object (computer, truck, item), pick up / drop.
func interact() -> void:
	if not controls_enabled:
		return
	if held != null:
		drop_held()
		return
	var hit := look_ray(GRAB_REACH, 1 | 2)
	if not hit.is_empty() and hit.collider.has_method("on_use"):
		hit.collider.call("on_use", self)
		return
	try_grab()


# ------------------------------------------------------------------ looking

func look_ray(length: float, mask: int) -> Dictionary:
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * length
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.exclude = [get_rid()]
	if held != null:
		q.exclude.append(held.get_rid())
	return get_world_3d().direct_space_state.intersect_ray(q)


func look_target_text() -> String:
	if held != null:
		return "[E] drop"
	var hit := look_ray(GRAB_REACH, 1 | 2)
	if hit.is_empty():
		return ""
	var c: Object = hit.collider
	if c.has_method("hint_text"):
		return String(c.call("hint_text"))
	if c is Node and (c as Node).is_in_group("grabbable"):
		return "[E] grab"
	return ""


## Screen-space radius (pixels) of the tool's stripping circle where the player is aiming.
func aim_ring_px(viewport_h: float) -> float:
	var reach := float(tdef().reach)
	var hit := look_ray(reach, 1)
	var dist := reach
	if not hit.is_empty() and hit.collider is ForestTree:
		dist = cam.global_position.distance_to(hit.position)
	var r := float(tdef().radius)
	return clampf(r / (maxf(dist, 0.3) * tan(deg_to_rad(cam.fov * 0.5))) * viewport_h * 0.5, 5.0, 400.0)


func aiming_at_tree() -> bool:
	var hit := look_ray(float(tdef().reach), 1)
	return not hit.is_empty() and hit.collider is ForestTree


# ------------------------------------------------------------------ chopping

func start_swing() -> void:
	if _swing >= 0.0 or _equip_t < 1.0:
		return
	_swing = 0.0
	_impact_done = false
	if tool != "hands":
		Sfx.play("whoosh", 1.4 - float(tdef().radius), -8.0)


func _do_impact() -> void:
	chops += 1
	var d := tdef()
	var hit := look_ray(float(d.reach), 1 | 2 | Bush.LAYER)
	if hit.is_empty():
		if tool == "hands":
			Sfx.play("whoosh", 1.2, -6.0)
		return
	var c: Object = hit.collider
	if c is ForestTree:
		var t := c as ForestTree
		var res := t.strip_circle(hit.position, float(d.radius))
		if not res.is_empty():
			var data := t.piece_data(int(res.layer), res.panels)
			get_parent().call("spawn_chip", data, t.kind, -cam.global_transform.basis.z)
			pieces_stripped += (res.panels as Array).size()
			if tool == "drill":
				Sfx.play("drill", 1.0, -8.0)
			else:
				Sfx.play("chop" if tool == "hands" else "axe", 1.0 if int(res.layer) == 0 else 1.15)
			_burst(hit.position, t.bark_color if int(res.layer) == 0 else t.inner_color, 10 + (res.panels as Array).size() * 2)
		else:
			Sfx.play("chop_wood")
			_burst(hit.position, t.wood_color, 8)
		if float(d.hurt) > 0.0:
			take_damage(float(d.hurt))
		t.shake_crown(-cam.global_transform.basis.z, 0.4 + float(d.radius))
	elif c is RigidBody3D:
		(c as RigidBody3D).apply_central_impulse(-cam.global_transform.basis.z * 1.5)
		Sfx.play("drop", 1.3)
	elif c.has_method("on_hit"):
		c.call("on_hit", hit.position, hit.normal, tool)
	elif c is Terrain:
		# grass flattens where you hit (visual only) and some dirt flies
		get_parent().call("bend_grass", hit.position, 1.0 + float(d.radius) * 3.0)
		Nature.burst(get_parent(), hit.position, hit.normal, Color("7a5a3a"), 8, 1.8, 0.03, 9.0, 0.6)
		Nature.burst(get_parent(), hit.position, hit.normal, Color("5f9a3a"), 6, 1.4, 0.03, 5.0, 0.8)
		Sfx.play("thud", 1.4, -6.0)
	else:
		Sfx.play("thud", 1.0, -4.0)
	_shake = 0.06 if tool == "drill" else 0.12 + float(d.radius) * 0.3


## Walks up steps, porch edges and small ledges instead of needing a jump.
func _step_up(delta: float) -> void:
	if not is_on_floor() or velocity.y > 0.1:
		return
	var h := Vector3(velocity.x, 0, velocity.z)
	if h.length() < 0.3:
		return
	var fwd := h.normalized() * maxf(h.length() * delta, 0.08)
	var t := global_transform
	var wall := KinematicCollision3D.new()
	if not test_move(t, fwd, wall) or wall.get_normal().y > 0.9:
		return                                  # nothing in the way
	if test_move(t, Vector3.UP * STEP_H):
		return                                  # no head room
	t.origin += Vector3.UP * STEP_H
	if test_move(t, fwd):
		return                                  # too tall: a real wall
	t.origin += fwd
	var col := KinematicCollision3D.new()
	if not test_move(t, Vector3.DOWN * STEP_H, col):
		return
	if col.get_normal().y < 0.7:
		return
	t.origin += col.get_travel()
	global_position = t.origin - fwd             # keep the forward motion for move_and_slide
	global_position.y += 0.01


## The player shoves loose items (bark, boxes) out of the way instead of being moved by them.
func _push_items() -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = _cap.radius + 0.08
	shape.height = _cap.height
	q.shape = shape
	q.transform = Transform3D(Basis(), global_position + Vector3(0, _cap.height * 0.5, 0))
	q.collision_mask = 2
	var hv := Vector3(velocity.x, 0, velocity.z)
	for r in get_world_3d().direct_space_state.intersect_shape(q, 16):
		var b := r.collider as RigidBody3D
		if b == null or b == held or b.freeze:
			continue
		var away := b.global_position - global_position
		away.y = 0.0
		if away.length() < 0.01:
			away = -global_transform.basis.z
		away = away.normalized()
		# match the player's speed along the push direction, plus a gentle nudge out of the capsule
		var want := maxf(hv.dot(away), 0.0) + 0.6
		var cur := b.linear_velocity.dot(away)
		if cur < want:
			b.apply_central_impulse(away * (want - cur) * b.mass * 0.5)


func _burst(pos: Vector3, color: Color, amount: int) -> void:
	Nature.burst(get_parent(), pos, cam.global_position - pos, color, amount, 2.2, 0.02, 9.0, 0.6)


# ------------------------------------------------------------------ health

func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_since_hurt = 0.0
	hurt.emit(amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_faint()
	elif health < 40.0:
		Sfx.play("ouch", 1.0, -4.0)


func _faint() -> void:
	controls_enabled = false
	drop_held()
	Sfx.play("faint")
	fainted.emit()
	await get_tree().create_timer(2.2).timeout
	global_transform = spawn_xform
	_yaw = spawn_xform.basis.get_euler().y
	_pitch = 0.0
	velocity = Vector3.ZERO
	health = max_health
	health_changed.emit(health, max_health)
	controls_enabled = true
	revived.emit()


# ------------------------------------------------------------------ holding

func try_grab() -> bool:
	var hit := look_ray(GRAB_REACH, 2)
	if hit.is_empty():
		return false
	var b := hit.collider as RigidBody3D
	if b == null or not b.is_in_group("grabbable"):
		return false
	held = b
	add_collision_exception_with(held)
	held.sleeping = false
	Sfx.play("pickup")
	return true


func drop_held() -> void:
	if held == null:
		return
	if is_instance_valid(held):
		remove_collision_exception_with(held)
		# it keeps whatever momentum it had in your hands: spin round fast and let go to fling it
	held = null
	Sfx.play("drop", 0.9, -6.0)


func _update_held(delta: float) -> void:
	if held == null:
		return
	if not is_instance_valid(held) or held.freeze:
		held = null
		return
	var target := cam.global_transform * HOLD_OFFSET
	var d := target - held.global_position
	if d.length() > 1.8:
		_snag += delta
		if _snag > 0.5:
			drop_held()
			return
	else:
		_snag = 0.0
	held.linear_velocity = (d * 16.0).limit_length(28.0)
	held.angular_velocity = held.angular_velocity.lerp(Vector3.ZERO, minf(1.0, delta * 10.0))
	var want := Basis(Vector3.UP, _yaw)
	var q := held.global_basis.get_rotation_quaternion().slerp(want.get_rotation_quaternion(), minf(1.0, delta * 6.0))
	held.global_basis = Basis(q)


# ------------------------------------------------------------------ frame

func _physics_process(delta: float) -> void:
	rotation.y = _yaw
	head.rotation.x = _pitch
	var input := Vector2.ZERO
	if controls_enabled:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input.y += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input.x += 1
	input = input.normalized()
	var sprint := Input.is_key_pressed(KEY_SHIFT) and controls_enabled
	var speed := SPRINT if sprint else WALK
	var dir := (global_transform.basis * Vector3(input.x, 0, input.y))
	var accel := 12.0 if is_on_floor() else 3.0
	velocity.x = lerpf(velocity.x, dir.x * speed, minf(1.0, accel * delta))
	velocity.z = lerpf(velocity.z, dir.z * speed, minf(1.0, accel * delta))
	if is_on_floor():
		if Input.is_key_pressed(KEY_SPACE) and controls_enabled:
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	_step_up(delta)
	move_and_slide()
	_push_items()
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.5:
		_bob += delta * hspeed * 2.2
		_step_acc += hspeed * delta
		if _step_acc > (0.9 if sprint else 0.7):
			_step_acc = 0.0
			Sfx.play("step", randf_range(0.8, 1.1), -10.0)
	else:
		_bob = lerpf(_bob, round(_bob / PI) * PI, minf(1.0, delta * 6.0))
	_update_held(delta)
	_equip_t = minf(1.0, _equip_t + delta * 4.0)
	var d := tdef()
	if _swing >= 0.0:
		_swing += delta / float(d.cooldown)
		if _swing >= float(d.impact) and not _impact_done:
			_impact_done = true
			_do_impact()
		if _swing >= 1.0:
			_swing = -1.0
	# continuous tools (drill): run while the button is held
	_drilling = bool(d.get("hold", false)) and controls_enabled and held == null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _drilling:
		_drill_cd -= delta
		if _drill_cd <= 0.0:
			_drill_cd = float(d.cooldown)
			if aiming_at_tree():
				_do_impact()
	_since_hurt += delta
	if _since_hurt > 3.0 and health < max_health and health > 0.0:
		health = minf(max_health, health + 5.0 * delta)
		health_changed.emit(health, max_health)
	if global_position.y < -30.0:
		global_transform = spawn_xform
		velocity = Vector3.ZERO


## Used by tests to drive the drill without a mouse.
func drill_once() -> void:
	if aiming_at_tree():
		_do_impact()


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.15
	cam.position = Vector3(0, sin(_bob) * 0.035, 0) + sh
	_animate_arm(delta)


# ------------------------------------------------------------------ animation

## Returns [rest, windup, strike] poses as [position offset, rotation degrees] per tool.
func _poses() -> Array:
	match String(tdef().anim):
		"chop":
			return [[Vector3(0, 0, 0), Vector3(12, 4, 0)], [Vector3(0.03, 0.14, 0.12), Vector3(75, 0, 12)], [Vector3(-0.06, -0.12, -0.22), Vector3(-55, 12, 0)]]
		"sweep":
			return [[Vector3(0, 0, 0), Vector3(14, 4, 0)], [Vector3(0.24, 0.06, 0.06), Vector3(8, -80, -25)], [Vector3(-0.3, -0.02, -0.16), Vector3(-6, 65, 18)]]
		"slam":
			return [[Vector3(-0.02, 0, 0), Vector3(16, 6, 0)], [Vector3(-0.12, 0.32, 0.16), Vector3(100, 0, 0)], [Vector3(-0.14, -0.16, -0.26), Vector3(-62, 0, 0)]]
		"drill":
			return [[Vector3(-0.02, 0.02, 0), Vector3(2, 4, 0)], [Vector3(-0.04, 0.02, -0.06), Vector3(0, 2, 0)], [Vector3(-0.05, 0.02, -0.12), Vector3(0, 0, 0)]]
	return [[Vector3(0, 0, 0), Vector3(4, 6, 0)], [Vector3(0.06, 0.24, 0.1), Vector3(55, -5, 30)], [Vector3(-0.2, -0.02, -0.26), Vector3(-20, 25, -15)]]


func _animate_arm(delta: float) -> void:
	var poses := _poses()
	var rest_p: Vector3 = _arm_base + poses[0][0] + Vector3(0, sin(_bob * 0.5) * 0.01, 0)
	var rest_r: Vector3 = poses[0][1]
	var up_p: Vector3 = _arm_base + poses[1][0]
	var up_r: Vector3 = poses[1][1]
	var hit_p: Vector3 = _arm_base + poses[2][0]
	var hit_r: Vector3 = poses[2][1]
	var p := rest_p
	var r := rest_r
	var spin := 0.0
	var impact := float(tdef().impact)
	if held != null:
		p = _arm_base + Vector3(-0.05, -0.2, 0.08)
		r = Vector3(-10, 10, 0)
	elif _drilling:
		p = hit_p + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.004
		r = hit_r
	elif _swing >= 0.0:
		var t := _swing
		var wind_end := impact * 0.7
		if t < wind_end:
			var k := ease(t / wind_end, 0.5)
			p = rest_p.lerp(up_p, k)
			r = rest_r.lerp(up_r, k)
		elif t < impact:
			var k2 := ease((t - wind_end) / (impact - wind_end), 2.0)
			p = up_p.lerp(hit_p, k2)
			r = up_r.lerp(hit_r, k2)
			if String(tdef().anim) == "slam":
				spin = k2 * 360.0
		else:
			var k3 := ease((t - impact) / (1.0 - impact), 0.6)
			p = hit_p.lerp(rest_p, k3)
			r = hit_r.lerp(rest_r, k3)
	# raise the tool into view after switching
	p.y -= (1.0 - ease(_equip_t, 0.4)) * 0.35
	arm.position = arm.position.lerp(p, 0.6)
	arm.rotation_degrees = arm.rotation_degrees.lerp(r, 0.6)
	if tool_model != null:
		tool_model.rotation_degrees.y = spin
		var bit := tool_model.get_node_or_null("Bit")
		if bit != null:
			bit.rotation.z += delta * (40.0 if _drilling else 0.0)
