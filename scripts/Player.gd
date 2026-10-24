class_name Player
extends CharacterBody3D
## First-person lumberjack. WASD + mouse look, Shift sprint, Space jump.
## Left click: karate chop (hurts you!). E: pick up / drop the thing you look at. Left click while holding: throw.

signal health_changed(health: float, max_health: float)
signal hurt(amount: float)
signal fainted
signal revived

const WALK := 4.2
const SPRINT := 6.8
const JUMP := 4.6
const GRAVITY := 12.0
const REACH := 2.1
const GRAB_REACH := 2.6
const CHOP_TIME := 0.34
const CHOP_IMPACT := 0.42      # fraction of the swing where the hand connects
const CHOP_DAMAGE := 6.0
const HOLD_OFFSET := Vector3(0.0, -0.28, -0.9)

var max_health := 100.0
var health := 100.0
var head: Node3D
var cam: Camera3D
var arm: Node3D
var held: RigidBody3D = null
var spawn_xform := Transform3D.IDENTITY
var mouse_sens := 0.0025
var controls_enabled := true
var chops := 0
var pieces_stripped := 0

var _yaw := 0.0
var _pitch := 0.0
var _chop := -1.0
var _impact_done := false
var _since_hurt := 99.0
var _shake := 0.0
var _bob := 0.0
var _step_acc := 0.0
var _snag := 0.0
var _arm_base := Vector3(0.26, -0.3, -0.46)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
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


func _build_arm() -> void:
	arm = Node3D.new()
	arm.position = _arm_base
	cam.add_child(arm)
	var sleeve := LowPoly.mat(Color("b8322c"), 0.9)
	var plaid := LowPoly.mat(Color("2a2a2a"), 0.9)
	var skin := LowPoly.mat(Color("e0a989"), 0.7)
	# forearm in a red flannel sleeve, karate hand held flat like a blade
	LowPoly.mesh_instance(arm, LowPoly.cyl(0.042, 0.05, 0.34, 6), sleeve, Vector3(0, 0, 0.17), Vector3(90, 0, 0))
	LowPoly.mesh_instance(arm, LowPoly.cyl(0.051, 0.051, 0.025, 6), plaid, Vector3(0, 0, 0.08), Vector3(90, 0, 0))
	LowPoly.mesh_instance(arm, LowPoly.cyl(0.046, 0.046, 0.04, 6), plaid, Vector3(0, 0, 0.0), Vector3(90, 0, 0))
	LowPoly.mesh_instance(arm, LowPoly.cyl(0.03, 0.034, 0.07, 6), skin, Vector3(0, 0, -0.05), Vector3(90, 0, 0))
	LowPoly.mesh_instance(arm, LowPoly.box(Vector3(0.026, 0.085, 0.11)), skin, Vector3(0, 0.0, -0.13))
	LowPoly.mesh_instance(arm, LowPoly.box(Vector3(0.024, 0.075, 0.035)), skin, Vector3(0, -0.004, -0.2))
	LowPoly.mesh_instance(arm, LowPoly.box(Vector3(0.022, 0.022, 0.06)), skin, Vector3(0.016, 0.036, -0.1), Vector3(0, -20, 0))
	for m in arm.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls_enabled:
		var m := event as InputEventMouseMotion
		_yaw -= m.relative.x * mouse_sens
		_pitch = clampf(_pitch - m.relative.y * mouse_sens, deg_to_rad(-88.0), deg_to_rad(88.0))
	elif event is InputEventMouseButton and event.pressed:
		var b := event as InputEventMouseButton
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if b.button_index == MOUSE_BUTTON_LEFT:
			primary()
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			interact()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_E or k == KEY_F:
			interact()
		elif k == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Left click: chop, or throw what you are holding.
func primary() -> void:
	if not controls_enabled:
		return
	if held != null:
		throw_held()
	else:
		start_chop()


## E: pick up what you look at, or drop what you hold.
func interact() -> void:
	if not controls_enabled:
		return
	if held != null:
		drop_held()
	else:
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
		var n: String = held.call("display_name") if held.has_method("display_name") else "it"
		return "Holding %s    [E] drop    [Left click] throw" % n
	var hit := look_ray(GRAB_REACH, 1 | 2)
	if hit.is_empty():
		return ""
	var c: Object = hit.collider
	if c is ForestTree:
		if global_position.distance_to(hit.position) > REACH + 0.6:
			return ""
		var t := c as ForestTree
		var pj := t.panel_at(hit.position)
		var what := "bare wood"
		if pj.x >= 0:
			if t.has_panel(ForestTree.OUTER, pj.x, pj.y):
				what = "bark"
			elif t.has_panel(ForestTree.INNER, pj.x, pj.y):
				what = "inner bark"
		return "%s tree  -  %s    [Left click] karate chop (it hurts!)" % [t.kind.capitalize(), what]
	if c is Node and (c as Node).is_in_group("grabbable"):
		var n2: String = c.call("display_name") if c.has_method("display_name") else "item"
		return "[E] pick up %s" % n2
	return ""


# ------------------------------------------------------------------ chopping

func start_chop() -> void:
	if _chop >= 0.0:
		return
	_chop = 0.0
	_impact_done = false


func _do_impact() -> void:
	chops += 1
	var hit := look_ray(REACH, 1 | 2)
	if hit.is_empty():
		Sfx.play("whoosh", 1.2, -6.0)
		return
	var c: Object = hit.collider
	if c is ForestTree:
		var t := c as ForestTree
		var res := t.strip_at(hit.position)
		if not res.is_empty():
			var data := t.chip_data(int(res.layer), int(res.i), int(res.j))
			get_parent().call("spawn_chip", data, t.kind, -cam.global_transform.basis.z)
			pieces_stripped += 1
			Sfx.play("chop", 1.0 if int(res.layer) == 0 else 1.2)
			_burst(hit.position, t.bark_color if int(res.layer) == 0 else t.inner_color)
		else:
			Sfx.play("chop_wood")
			_burst(hit.position, t.wood_color)
		take_damage(CHOP_DAMAGE)
	elif c is RigidBody3D:
		(c as RigidBody3D).apply_central_impulse(-cam.global_transform.basis.z * 1.5)
		Sfx.play("drop", 1.3)
	else:
		Sfx.play("thud")
		take_damage(CHOP_DAMAGE * 0.5)
	_shake = 0.12


func _burst(pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.6
	p.mesh = LowPoly.box(Vector3(0.02, 0.02, 0.02))
	p.material_override = LowPoly.mat(color)
	p.direction = (cam.global_position - pos).normalized()
	p.spread = 55.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -9.0, 0)
	p.local_coords = false
	get_parent().add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


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
		held.linear_velocity = velocity * 0.5
	held = null
	Sfx.play("drop", 0.9, -6.0)


func throw_held() -> void:
	if held == null:
		return
	var b := held
	drop_held()
	b.linear_velocity = -cam.global_transform.basis.z * 7.0 + velocity
	b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	Sfx.play("whoosh", 0.9)


func _update_held(delta: float) -> void:
	if held == null:
		return
	if not is_instance_valid(held):
		held = null
		return
	var target := cam.global_transform * HOLD_OFFSET
	var d := target - held.global_position
	# only let go if the piece stays snagged on something for a moment
	if d.length() > 1.8:
		_snag += delta
		if _snag > 0.5:
			drop_held()
			return
	else:
		_snag = 0.0
	held.linear_velocity = (d * 16.0).limit_length(20.0)
	held.angular_velocity = held.angular_velocity.lerp(Vector3.ZERO, minf(1.0, delta * 10.0))
	# gently turn the piece so it faces the camera
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
	move_and_slide()
	# footsteps + head bob
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
	# chop timing lives in physics so the hit happens on a physics frame
	if _chop >= 0.0:
		_chop += delta / CHOP_TIME
		if _chop >= CHOP_IMPACT and not _impact_done:
			_impact_done = true
			_do_impact()
		if _chop >= 1.0:
			_chop = -1.0
	_since_hurt += delta
	if _since_hurt > 3.0 and health < max_health and health > 0.0:
		health = minf(max_health, health + 5.0 * delta)
		health_changed.emit(health, max_health)
	if global_position.y < -30.0:
		global_transform = spawn_xform
		velocity = Vector3.ZERO


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.15
	cam.position = Vector3(0, sin(_bob) * 0.035, 0) + sh
	_animate_arm()


func _animate_arm() -> void:
	# poses: rest -> wind-up (hand raised) -> strike (forward, across and down) -> rest
	var rest_p := _arm_base + Vector3(0, sin(_bob * 0.5) * 0.01, 0)
	var rest_r := Vector3(4, 6, 0)
	var up_p := _arm_base + Vector3(0.06, 0.24, 0.1)
	var up_r := Vector3(55, -5, 30)
	var hit_p := _arm_base + Vector3(-0.2, -0.02, -0.26)
	var hit_r := Vector3(-20, 25, -15)
	var p := rest_p
	var r := rest_r
	if held != null:
		p = _arm_base + Vector3(-0.05, -0.12, 0.05)
		r = Vector3(-10, 10, 0)
	elif _chop >= 0.0:
		var t := _chop
		if t < 0.3:
			var k := ease(t / 0.3, 0.5)
			p = rest_p.lerp(up_p, k)
			r = rest_r.lerp(up_r, k)
		elif t < CHOP_IMPACT:
			var k2 := ease((t - 0.3) / (CHOP_IMPACT - 0.3), 2.0)
			p = up_p.lerp(hit_p, k2)
			r = up_r.lerp(hit_r, k2)
		else:
			var k3 := ease((t - CHOP_IMPACT) / (1.0 - CHOP_IMPACT), 0.6)
			p = hit_p.lerp(rest_p, k3)
			r = hit_r.lerp(rest_r, k3)
	arm.position = arm.position.lerp(p, 0.6)
	arm.rotation_degrees = arm.rotation_degrees.lerp(r, 0.6)
