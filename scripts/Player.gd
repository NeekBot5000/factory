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
var arm_l: Node3D                # left arm, only out for the twin hatchets
var tool_root_l: Node3D
var tool_model_l: Node3D
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
const SAW_TREE_TIME := 2.6      # seconds of sawing to fell an average tree
const SAW_LOG_TIME := 1.1
const VAC_RANGE := 7.0
const VAC_MAX := 40

var builder: Builder
var saw_progress := 0.0          # 0..1 while sawing (shown on the crosshair)
var _saw_target: Object = null
var _saw_fx := 0.0
var _sawing := false
var _vacuuming := false
var _vac_caught := {}            # RigidBody3D -> orbit phase
var _vac_fx := 0.0
var _vac_sound: AudioStreamPlayer
var _chain_sound: AudioStreamPlayer   # the chainsaw idles while you hold it and revs while it cuts
var _backhand := false           # the double-bit axe alternates forehand / backhand swings
var _combo_n := 0                # combo axe: hits in a row (each one grows the next)
var _combo_t := 0.0
var _kick := 0.0                 # view kick on impact (heavier tools kick harder)
var _impacts := 0                # impacts done this swing (the double-bit hits twice)
const COMBO_MAX := 8
var force_trigger := false       # tests: act as if the mouse button were held
var invert_y := false            # settings
var head_bob := 1.0
var assume_captured := false     # tests: headless runs can't capture the mouse; treat clicks as if it were
var lying: Node3D = null         # the hammock you're lying in, if any
var _hold_yaw := 0.0             # the held thing keeps the turn it had relative to you when you picked it up
var _pouring := false            # holding R with something in your hands: tip it forward to pour it out
var _tilt := 0.0
var _hold_dist := 0.0            # bigger things are held further away
var _lie_t := 0.0
var _told_inner := false          # the gouge's "outer bark first" hint, once
var wire_from: Machine = null     # wire spool: the machine you clicked first
var _wire_preview: MeshInstance3D
var _thrown: ThrownHatchet = null # the throwing hatchet while it's out of your hand
var _catch := 0.0                 # 1 -> 0 just after catching it (the hand gives a little)
var _spiral_tree: ForestTree = null   # spiral axe: where the stripe will carry on from
var _spiral_next := Vector2i(-1, -1)
var _spiral_t := 99.0
var _spiral_n := 0
var _charging := false            # thunder axe: holding the button to charge
var charge := 0.0
var _thunder_cd := 0.0
var _running := false             # planer, pressure washer, blower: motor on
var _run_cd := 0.0
var _beep_t := 0.0                # ore detector
var _beep_glow := 0.0
var _told := {}                   # one-off hints, by key -> time told
var _blow_sound: AudioStreamPlayer
var _wash_sound: AudioStreamPlayer
var _pole_target: ForestTree = null
var _anim_t := 0.0
var _land := 0.0                  # 1 -> 0 after landing from a jump or a drop (the view dips)
var _fall_v := 0.0


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
	builder = Builder.new()
	add_child(builder)
	builder.setup(self, get_parent())
	_vac_sound = AudioStreamPlayer.new()
	_vac_sound.volume_db = -10.0      # its sound is built the first time the vacuum runs
	add_child(_vac_sound)
	_chain_sound = AudioStreamPlayer.new()
	add_child(_chain_sound)
	_blow_sound = AudioStreamPlayer.new()
	_blow_sound.volume_db = -12.0
	add_child(_blow_sound)
	_wash_sound = AudioStreamPlayer.new()
	_wash_sound.volume_db = -11.0
	add_child(_wash_sound)
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
	tool_root.name = "ToolRoot"
	tool_root.position = Vector3(0, -0.01, -0.13)
	arm.add_child(tool_root)
	hand_fist.name = "HandFist"
	hand_flat.name = "HandFlat"
	for m in arm.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arm_l = arm.duplicate()
	cam.add_child(arm_l)
	arm_l.get_node("HandFlat").visible = false
	tool_root_l = arm_l.get_node("ToolRoot")
	arm_l.visible = false
	_apply_tool_visuals()


func tdef() -> Dictionary:
	return Tools.TOOLS[tool]


## The stripping circle right now (the combo axe grows with each hit in a row).
func strip_radius() -> float:
	var r := float(tdef().radius)
	if tool == "combo":
		r += 0.05 * _combo_n
	return r


func equip(id: String) -> void:
	if not Game.in_toolbar(id) or not Tools.TOOLS.has(id) or id == tool:
		return
	builder.cancel()
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
	if tool_model_l != null:
		tool_model_l.queue_free()
		tool_model_l = null
	arm_l.visible = tool == "twins"
	if tool == "twins":
		tool_model_l = Tools.build_model(tool, tool_root_l)
	hand_flat.visible = tool == "hands"
	hand_fist.visible = tool != "hands"
	if tool != "hands":
		tool_model = Tools.build_model(tool, tool_root)
		match tool:
			"drill", "vacuum", "saw", "shears", "chainsaw", "bucksaw", "twin_auger", "holesaw", "twinvac", "cyclone", "rock_drill", "core_drill", \
					"planer", "washer", "blower", "crosscut", "dynamite", "can", "spud":
				tool_model.rotation_degrees = Vector3(0, 0, 0)
				tool_model.position = Vector3(0, -0.02, 0.0)
			"rake":
				tool_model.rotation_degrees = Vector3(-9, 0, 0)
			"detector":
				tool_model.rotation_degrees = Vector3(10, 0, 0)
			"pole_saw":
				tool_model.rotation_degrees = Vector3(30, 0, 0)
			"scale":
				tool_model.rotation_degrees = Vector3(0, 12, 0)
				tool_model.position = Vector3(0, 0.02, 0.0)
			_:
				tool_model.rotation_degrees = Vector3(-35, 0, 0)
		if tool == "throwing" and is_instance_valid(_thrown):
			tool_model.visible = false


func _on_tools_changed() -> void:
	pass


func cycle_tool(step: int) -> void:
	if tool == "hammer" and builder.busy():
		builder.scroll(step)     # while placing a build, the wheel resizes it
		return
	var owned: Array = Tools.TOOL_ORDER.filter(func(t): return Game.in_toolbar(t))
	var i := owned.find(tool)
	equip(owned[posmod(i + step, owned.size())])


## Q: put the current tool down on the ground (pick it up again with E).
func drop_tool() -> void:
	if tool == "hands" or (tool == "throwing" and is_instance_valid(_thrown)):
		return
	var id := tool
	var item := ToolItem.new()
	get_parent().add_child(item)
	item.setup(id)
	item.global_position = cam.global_position - cam.global_transform.basis.z * 0.7 + Vector3(0, -0.3, 0)
	item.global_basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
	item.linear_velocity = velocity + (-cam.global_transform.basis.z) * 1.5
	item.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	builder.cancel()
	tool = "hands"
	_apply_tool_visuals()
	Game.set_dropped(id, true)
	tool_changed.emit(tool)
	Sfx.play("drop", 0.8)


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
		_pitch = clampf(_pitch - m.relative.y * mouse_sens * (-1.0 if invert_y else 1.0), deg_to_rad(-88.0), deg_to_rad(88.0))
	elif event is InputEventMouseButton and event.pressed:
		var b := event as InputEventMouseButton
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not assume_captured:
			if controls_enabled:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if b.button_index == MOUSE_BUTTON_LEFT:
			primary()
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			if builder.busy():
				builder.cancel()
			else:
				interact()
		elif b.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_tool(-1)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_tool(1)
	elif event is InputEventKey and not event.pressed and (event as InputEventKey).keycode == KEY_R:
		_pouring = false
	elif event is InputEventKey and event.pressed and (not event.echo or (event as InputEventKey).keycode == KEY_R):
		var k := (event as InputEventKey).keycode
		if not controls_enabled:
			return
		if k == KEY_E or k == KEY_F:
			interact()
		elif k == KEY_Q:
			drop_tool()
		elif k == KEY_X and tool == "hammer" and not builder.busy():
			hammer_take_down()
		elif k == KEY_R:
			# R turns things: the build you're placing, or whatever is in your hands
			if builder.busy():
				builder.rotate(1)
			elif held != null:
				_pouring = true
		elif k == KEY_ESCAPE:
			get_parent().call("open_settings")
		elif k == KEY_TAB:
			if Game.has_phone:
				get_parent().call("open_phone")
			else:
				Game.toast.emit("No phone", Color("ffd27a"))
		elif k >= KEY_1 and k <= KEY_9:
			# 1-9 pick your first nine tools; with Shift held, the next nine
			var owned: Array = Tools.TOOL_ORDER.filter(func(t): return Game.in_toolbar(t))
			var n := (k - KEY_1) + (9 if (event as InputEventKey).shift_pressed else 0)
			if n < owned.size():
				equip(owned[n])


## Left click: click an object (box), throw what you hold, or swing the tool.
func primary() -> void:
	if not controls_enabled:
		return
	if held != null:
		return
	var hit := look_ray(minf(float(tdef().reach), 3.0), 1 | 2)
	if not hit.is_empty() and hit.collider.has_method("on_click"):
		hit.collider.call("on_click", self)
		return
	if tool == "wires":
		# same reach as the hint text, so a click goes where the hint says it will
		wire_click(Machine.of(look_ray(float(tdef().reach), 1 | 2).get("collider")))
		return
	if tool == "hammer":
		# hammer on a rotator (or something sitting on one): stick it on / let go
		if not builder.busy() and not hit.is_empty():
			var rot := Machine.of(hit.collider) as Rotator
			if rot == null and hit.collider is RigidBody3D:
				rot = Rotator.holding(hit.collider)
			if rot != null:
				rot.on_hammer()
				start_swing()
				return
		# hammer on a log: lock it in place / unlock it; anywhere else: the build menu
		if not builder.busy() and not hit.is_empty() and hit.collider is Log:
			var lg := hit.collider as Log
			lg.set_locked(not lg.locked)
			start_swing()
			Sfx.play("clink", 0.8 if lg.locked else 1.2)
			Sfx.play("thud", 1.5, -4.0)
			return
		builder.click()
		return
	if bool(tdef().get("hold", false)):
		return   # continuous tools run while the button is held (see _physics_process)
	if tdef().has("charge"):
		# thunder axe: charges while the button is held, strikes when you let go (see _thunder_step)
		if _swing < 0.0 and _equip_t >= 1.0:
			_charging = true
		return
	start_swing()


## E: use an object (computer, truck, item), pick up / drop.
func interact() -> void:
	if not controls_enabled:
		return
	if lying != null:
		get_up()
		return
	if builder.busy():
		builder.cancel()
		return
	if held != null:
		drop_held()
		return
	var hit := look_ray(GRAB_REACH, 1 | 2 | Blueprint.LAYER)
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
	if lying != null:
		return "[E] get up"
	if builder.busy():
		return builder.hint_text()
	if held != null:
		return "[E] drop    [Hold R] tip it over"
	if tool == "wires":
		var wm := Machine.of(look_ray(float(tdef().reach), 1 | 2).get("collider"))
		if wire_from != null and is_instance_valid(wire_from):
			if wm != null and wm != wire_from:
				return "[Click] connect / disconnect %s" % Builds.BUILDS[wm.get_meta("build").id].name
			return "[Click] a second machine    [Click empty] cancel"
		if wm != null:
			return "[Click] start a wire from %s" % Builds.BUILDS[wm.get_meta("build").id].name
	if tool == "scale":
		var sc := scale_reading(look_ray(float(tdef().reach), 1 | 2).get("collider"))
		if not sc.is_empty():
			return String(sc.text)
	if tool == "dynamite":
		var dh := look_ray(float(tdef().reach), 1)
		if not dh.is_empty() and not (dh.collider is Charge):
			return "[Click] stick a charge on it  (%d left)" % int(Game.charges.get("dynamite", 0))
	if tool == "can":
		var sp := _sapling_in_front()
		if sp != null:
			return "[Click] water it" if sp.is_rooted() else "It has to take root first"
	if tool == "hammer":
		var lc: Object = look_ray(GRAB_REACH + 1.0, 1 | 2 | Blueprint.LAYER).get("collider")
		if lc is Blueprint:
			return "[X] knock down the plan (materials drop out)"
		var bt := build_of(lc)
		if bt != null:
			var extra := "    [Click] stick / let go" if bt is Rotator else ""
			return "[X] take down  +$%.2f%s" % [float(bt.get_meta("sale_value", 0.0)), extra]
	var hit := look_ray(GRAB_REACH, 1 | 2 | Blueprint.LAYER)
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
	if not hit.is_empty() and trunk_of(hit.collider) != null:
		dist = cam.global_position.distance_to(hit.position)
	var r := maxf(strip_radius(), 0.04)
	return clampf(r / (maxf(dist, 0.3) * tan(deg_to_rad(cam.fov * 0.5))) * viewport_h * 0.5, 5.0, 400.0)


func aiming_at_tree() -> bool:
	var hit := look_ray(minf(float(tdef().reach), 3.0), 1 | 2)
	return not hit.is_empty() and trunk_of(hit.collider) != null


## The barked trunk behind a collider: a standing tree, or the trunk inside a log.
static func trunk_of(c: Object) -> ForestTree:
	if c is ForestTree:
		return c as ForestTree
	if c is Log:
		return (c as Log).trunk
	return null


# ------------------------------------------------------------------ chopping

func start_swing() -> void:
	if _swing >= 0.0 or _equip_t < 1.0:
		return
	if tool == "throwing" and is_instance_valid(_thrown):
		return        # it's still in the air
	_swing = 0.0
	_impact_done = false
	_impacts = 0
	if String(tdef().anim) in ["sweep", "twin"]:
		_backhand = not _backhand
	if tool != "hands" and tool != "throwing":
		Sfx.play("whoosh", 1.4 - float(tdef().radius), -8.0)


func _do_impact() -> void:
	chops += 1
	var d := tdef()
	if tool == "shears":
		_snip()
		return
	if tool == "hammer" or tool == "wires" or tool == "scale" or tool == "detector":
		return
	match tool:
		"throwing":
			_throw()
			return
		"rake":
			rake()
			return
		"can":
			water()
			return
		"dynamite":
			plant_charge()
			return
	# swings pass through loose bark / leaves floating in front of the trunk (logs are on layer 1, so still hit)
	var hit := look_ray(float(d.reach), 1 | Bush.LAYER)
	if hit.is_empty():
		hit = look_ray(float(d.reach), 2)
	if hit.is_empty():
		if tool == "hands":
			Sfx.play("whoosh", 1.2, -6.0)
		return
	var c: Object = hit.collider
	if trunk_of(c) != null:
		var t := trunk_of(c)
		# what comes off: one sheet normally; through-tools take both layers; the twin auger bores two spots
		var results: Array = []
		var spots: Array[Vector3] = [hit.position]
		if int(d.get("bits", 1)) == 2:
			var side := cam.global_transform.basis.x * 0.17
			spots = [hit.position - side, hit.position + side]
		for at in spots:
			if bool(d.get("spiral", false)):
				results.append_array(_spiral_hit(t, at))
			elif bool(d.get("ring", false)):
				results.append(t.strip_ring(at))
			elif bool(d.get("through", false)):
				results.append_array(t.strip_through(at, strip_radius(), int(d.get("grid", 0))))
			else:
				var only := -1
				match String(d.get("layer", "")):
					"outer": only = ForestTree.OUTER
					"inner": only = ForestTree.INNER
				results.append(t.strip_circle(at, strip_radius(), only))
		results = results.filter(func(r): return not (r as Dictionary).is_empty())
		if tool == "combo":
			_combo_n = mini(_combo_n + 1, COMBO_MAX)     # any hit on the trunk keeps the rhythm going
			_combo_t = 0.0
		spawn_bark(t, results, hit.position, -cam.global_transform.basis.z, float(d.get("value", 1.0)))
		if not results.is_empty():
			if String(d.anim) == "drill":
				Sfx.play("drill", 1.0, -8.0)
			elif tool == "robo":
				Sfx.play("clink", 1.6, -8.0)
				Sfx.play("axe", 1.3, -4.0)
			else:
				Sfx.play("chop" if tool == "hands" else "axe", 1.0 if int(results[0].layer) == 0 else 1.15)
		else:
			Sfx.play("chop_wood")
			_burst(hit.position, t.wood_color, 8)
			if String(d.get("layer", "")) == "inner" and not _told_inner:
				_told_inner = true
				Game.toast.emit("The gouge only cuts inner bark - take the outer bark off first", Color("ffd27a"))
		# heavier tools kick the view harder
		_kick = 0.01 + strip_radius() * 0.09 + (0.03 if bool(d.get("through", false)) else 0.0)
		if float(d.hurt) > 0.0:
			take_damage(float(d.hurt))
		t.shake_crown(-cam.global_transform.basis.z, 0.4 + strip_radius())
		if c is Log:
			(c as Log).apply_impulse(-cam.global_transform.basis.z * 0.6, hit.position - (c as Log).global_position)
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
	_shake = 0.06 if String(d.anim) == "drill" else 0.12 + float(d.radius) * 0.3


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
		if b == null or b == held or b.freeze or b is Log:
			continue     # logs are solid to the player and too heavy to shove
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
	# grabbing something that's sitting in a basket picks up the whole basket
	var bk := _basket_around(b)
	if bk != null:
		b = bk
	held = b
	add_collision_exception_with(held)
	held.sleeping = false
	_tilt = 0.0
	_pouring = false
	_hold_yaw = wrapf(b.global_basis.get_euler().y - _yaw, -PI, PI) if not (b is Log) else 0.0
	_hold_dist = maxf(0.0, _body_radius(b) - 0.25) * 1.3
	Sfx.play("pickup")
	return true


## A container's tray in its own space: [floor height, half extents (x, wall height, z)].
static func _tray(b: Node) -> Array:
	if b.has_meta("tray"):
		return [float(b.get_meta("tray_y")), b.get_meta("tray")]
	var s := float(b.get_meta("size", 1.0))
	return [0.0, Vector3(Builds.BASKET_W * 0.5, Builds.BASKET_H, Builds.BASKET_D * 0.5) * s]


func _basket_around(b: RigidBody3D) -> RigidBody3D:
	if b.is_in_group("baskets"):
		return null
	for bk in get_tree().get_nodes_in_group("baskets"):
		var basket := bk as RigidBody3D
		var tr := _tray(basket)
		var h: Vector3 = tr[1]
		var lp := basket.to_local(b.global_position) - Vector3(0, float(tr[0]), 0)
		if absf(lp.x) < h.x and absf(lp.z) < h.z and lp.y > -0.05 and lp.y < h.y + 0.25:
			return basket
	return null


## The loose things sitting in a basket or wheelbarrow right now.
func _tray_contents(basket: RigidBody3D) -> Array:
	var out: Array = []
	for b in basket.get_meta("packed", []):
		if is_instance_valid(b):
			out.append(b)
	var tr := _tray(basket)
	var y0 := float(tr[0])
	var h: Vector3 = tr[1]
	var top := h.y + 0.15
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(h.x * 2.0, top, h.z * 2.0)
	q.shape = sh
	q.transform = basket.global_transform * Transform3D(Basis(), Vector3(0, y0 + top * 0.5, 0))
	q.collision_mask = 2
	q.exclude = [basket.get_rid(), get_rid()]
	for r in get_world_3d().direct_space_state.intersect_shape(q, 128):
		var b := r.collider as RigidBody3D
		if b == null or b.freeze or b == basket or b.is_in_group("baskets") or out.has(b):
			continue
		var lp := basket.to_local(b.global_position) - Vector3(0, y0, 0)
		if absf(lp.x) > h.x or absf(lp.z) > h.z or lp.y < -0.02 or lp.y > top:
			continue
		out.append(b)
	return out


## Carrying a basket upright: things resting inside it ride along with it (so walking, turning and bumping can
## never shake them out or through the floor). Tip it (hold R) or put it down and they're loose again.
func _carry_contents(basket: RigidBody3D) -> void:
	var packed: Array = basket.get_meta("packed", [])
	for b in _tray_contents(basket):
		if packed.has(b):
			continue
		b.set_meta("pack_layer", b.collision_layer)
		b.set_meta("pack_mask", b.collision_mask)
		b.collision_layer = 0
		b.collision_mask = 0          # otherwise it would act as a fixed peg inside the basket and pin it
		b.freeze = true
		b.reparent(basket, true)
		packed.append(b)
	basket.set_meta("packed", packed)


## Lets everything that was riding in the basket go: it keeps the basket's motion, so a flung basket spills.
func _release_contents(basket: RigidBody3D) -> void:
	if not basket.has_meta("packed"):
		return
	var world := get_parent()
	for b in basket.get_meta("packed"):
		if not is_instance_valid(b):
			continue
		var rb := b as RigidBody3D
		rb.reparent(world, true)
		rb.collision_layer = int(rb.get_meta("pack_layer", 2))
		rb.collision_mask = int(rb.get_meta("pack_mask", 3))
		rb.freeze = false
		rb.linear_velocity = basket.linear_velocity + basket.angular_velocity.cross(rb.global_position - basket.global_position)
	basket.remove_meta("packed")


## Rough radius of a body from its collision shapes (so big things are held further out).
static func _body_radius(b: Node3D) -> float:
	var r := 0.1
	for c in b.get_children():
		var cs := c as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var e := 0.1
		if cs.shape is BoxShape3D:
			e = (cs.shape as BoxShape3D).size.length() * 0.5
		elif cs.shape is SphereShape3D:
			e = (cs.shape as SphereShape3D).radius
		elif cs.shape is CylinderShape3D:
			e = Vector2((cs.shape as CylinderShape3D).radius, (cs.shape as CylinderShape3D).height * 0.5).length()
		r = maxf(r, cs.position.length() + e)
	return r


func drop_held() -> void:
	if held == null:
		return
	if is_instance_valid(held):
		remove_collision_exception_with(held)
		# it keeps whatever momentum it had in your hands: spin round fast and let go to fling it
		if held.is_in_group("baskets"):
			_release_contents(held)
	held = null
	Sfx.play("drop", 0.9, -6.0)


func _update_held(delta: float) -> void:
	if held == null:
		return
	if not is_instance_valid(held) or held.freeze:
		held = null
		return
	var target := cam.global_transform * (HOLD_OFFSET + (Vector3(0, -0.15, -0.4) if held is Log else Vector3.ZERO) + Vector3(0, -_hold_dist * 0.35, -_hold_dist))
	var barrow := held.has_meta("barrow")
	if barrow:
		# a wheelbarrow stays on the ground in front of you, wheel first, handles lifted into your hands
		var ahead := global_position - global_transform.basis.z * 1.05
		var gq := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 1.0, ahead + Vector3.DOWN * 1.5, 1)
		var gh := get_world_3d().direct_space_state.intersect_ray(gq)
		target = ahead
		target.y = (gh.position.y if not gh.is_empty() else global_position.y) + 0.06
	elif held.is_in_group("baskets"):
		# hold a basket by its middle, so tipping it pivots around the middle (not its bottom edge)
		target -= held.global_basis.y * Builds.BASKET_H * 0.5 * float(held.get_meta("size", 1.0))
	var d := target - held.global_position
	if d.length() > 1.8 + _hold_dist:
		_snag += delta
		if _snag > 0.5:
			drop_held()
			return
	else:
		_snag = 0.0
	held.sleeping = false
	held.linear_velocity = (d * 16.0).limit_length(28.0)
	if held.is_in_group("baskets"):
		if _tilt < 0.3:
			_carry_contents(held)
		else:
			_release_contents(held)
	# hold R to tip it forward (pour a basket out); let go and it rights itself
	_tilt = move_toward(_tilt, deg_to_rad(165.0) if _pouring else 0.0, delta * 5.0)
	var want := Basis(Vector3.UP, _yaw + _hold_yaw) * Basis(Vector3.RIGHT, -_tilt)
	if barrow:
		want = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, -0.12 - _tilt)
	if held is Log:
		want = want * Basis(Vector3.BACK, PI * 0.5)     # carry logs crosswise
	# turn it with angular velocity (not by snapping its rotation) so containers sweep their contents along
	var cur := held.global_basis.get_rotation_quaternion()
	var dq := want.get_rotation_quaternion() * cur.inverse()
	if dq.w < 0.0:
		dq = -dq
	var ang := 2.0 * acos(clampf(dq.w, -1.0, 1.0))
	var axis := Vector3(dq.x, dq.y, dq.z)
	if axis.length() > 0.0001 and ang > 0.0005:
		held.angular_velocity = axis.normalized() * minf(ang * 8.0, 12.0)
	else:
		held.angular_velocity = Vector3.ZERO


# ------------------------------------------------------------------ frame

## Climb into a hammock: you lie back and sway; look around freely, E to get out.
func lie_in(h: Node3D) -> void:
	drop_held()
	builder.cancel()
	lying = h
	velocity = Vector3.ZERO
	Sfx.play("rustle", 0.8, -4.0)


func get_up() -> void:
	if lying != null and is_instance_valid(lying):
		var out: Vector3 = lying.global_transform * Vector3(0, 0, 1.1)
		out.y = maxf(out.y, lying.global_position.y) + 0.05
		global_position = out
	lying = null
	head.position.y = 1.58
	cam.rotation.z = 0.0


func _physics_process(delta: float) -> void:
	rotation.y = _yaw
	head.rotation.x = _pitch
	if lying != null:
		if not is_instance_valid(lying):
			get_up()
		else:
			_lie_t += delta
			global_position = lying.global_transform * Vector3(sin(_lie_t * 0.9) * 0.04, float(lying.get("bed_h")), 0)
			head.position.y = 0.3
			cam.rotation.z = sin(_lie_t * 0.9) * 0.03
			velocity = Vector3.ZERO
			return
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
	var speed := (SPRINT if sprint else WALK) * float(tdef().get("move", 1.0))
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
	var was_floor := is_on_floor()
	_fall_v = minf(_fall_v, velocity.y)
	move_and_slide()
	if is_on_floor() and not was_floor:
		_land = clampf(-_fall_v / 8.0, 0.0, 1.0)
	if is_on_floor():
		_fall_v = 0.0
	_push_items()
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.5:
		_bob += delta * hspeed * 2.2
		_step_acc += hspeed * delta
		if _step_acc > (0.9 if sprint else 0.7):
			_step_acc = 0.0
			Sfx.play(_step_sound(), randf_range(0.85, 1.1), -8.0)
	else:
		_bob = lerpf(_bob, round(_bob / PI) * PI, minf(1.0, delta * 6.0))
	_update_held(delta)
	_equip_t = minf(1.0, _equip_t + delta * 4.0)
	_combo_t += delta
	if _combo_t > 1.25 and _combo_n > 0:
		_combo_n = 0
		Sfx.play("click", 0.5, -8.0)
	var d := tdef()
	if _swing >= 0.0:
		_swing += delta / float(d.cooldown)
		# most swings hit once; the double-bit hits twice (forehand, then backhand)
		var hits: Array = d.get("impacts", [float(d.impact)])
		while _impacts < hits.size() and _swing >= float(hits[_impacts]):
			_impacts += 1
			_impact_done = _impacts >= hits.size()
			_do_impact()
		if _swing >= 1.0:
			_swing = -1.0
	var pressing := controls_enabled and held == null and (force_trigger or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)))
	# automatic tools (robotic axe) keep swinging while the button is held
	if bool(d.get("auto", false)) and pressing and _swing < 0.0:
		start_swing()
	# continuous tools: run while the button is held
	var trigger := bool(d.get("hold", false)) and pressing
	var kind := String(d.get("kind", ""))
	_drilling = trigger and (kind == "drill" or kind == "rockdrill")
	_saw_step(delta, trigger and kind == "saw")
	_update_chainsaw(trigger)
	_vacuum_step(delta, trigger and kind == "vacuum")
	_polesaw_step(delta, trigger and kind == "polesaw")
	_motor_step(delta, trigger and kind in ["planer", "washer", "blower"], kind)
	_thunder_step(delta, pressing)
	_detector_step(delta)
	_catch = maxf(0.0, _catch - delta * 3.5)
	_spiral_t += delta
	builder.update(delta)
	if _drilling:
		_drill_cd -= delta
		if _drill_cd <= 0.0:
			_drill_cd = float(d.cooldown)
			if kind == "rockdrill":
				drill_rock()
			elif aiming_at_tree():
				_do_impact()
	_since_hurt += delta
	if _since_hurt > 3.0 and health < max_health and health > 0.0:
		health = minf(max_health, health + 5.0 * delta)
		health_changed.emit(health, max_health)
	if global_position.y < -30.0:
		global_transform = spawn_xform
		velocity = Vector3.ZERO


## The finished build a collider belongs to (benches, chutes, machines, baskets...), or null.
static func build_of(c: Object) -> Node3D:
	var n := c as Node
	while n != null and not (n is Window):
		if n.is_in_group("builds"):
			return n as Node3D
		n = n.get_parent()
	return null


## Hammer + X on whatever you're looking at: a finished build comes down (you get back what it would sell for),
## a plan that's still a hologram is cancelled (everything you put in drops out).
func hammer_take_down() -> bool:
	var c: Object = look_ray(GRAB_REACH + 1.0, 1 | 2 | Blueprint.LAYER).get("collider")
	if c is Blueprint:
		(c as Blueprint).cancel()
		start_swing()
		return true
	var b := build_of(c)
	if b == null:
		return false
	take_down(b)
	return true


## Hammer + X: knock a build down. It's gone, and you get back what it would have sold for.
func take_down(b: Node3D) -> void:
	# anything built on top of a pillar comes down with it (it would hang in the air otherwise)
	if b.has_meta("build") and String(b.get_meta("build").id) == "pillar":
		var top := b.global_position + Vector3.UP
		for o in get_tree().get_nodes_in_group("builds"):
			var on := o as Node3D
			if on != b and is_instance_valid(on) and not (on is RigidBody3D) and absf(on.global_position.y - top.y) < 0.15 \
					and Vector2(on.global_position.x - top.x, on.global_position.z - top.z).length() < 0.6:
				take_down(on)
	if b is Rotator:
		(b as Rotator).unstick_all()
	var v := float(b.get_meta("sale_value", 0.0))
	if v > 0.0:
		Game.add_money(v)
	Nature.burst(get_parent(), b.global_position + Vector3.UP * 0.4, Vector3.UP, Color("a0703c"), 30, 2.5, 0.06, 6.0, 1.0, 140.0)
	Sfx.play("thud", 0.8, 2.0)
	Sfx.play("chop_wood", 0.7)
	start_swing()
	b.remove_from_group("builds")
	b.remove_from_group("machines")
	b.queue_free()
	Game.save_game()


## Wire spool click: first click picks a machine, the second runs a wire to another (or takes it down again).
func wire_click(m: Machine) -> String:
	start_swing()
	if m == null:
		if wire_from != null:
			wire_from = null
			Sfx.play("click", 0.6, -6.0)
		return ""
	if wire_from == null or not is_instance_valid(wire_from) or wire_from == m:
		wire_from = m
		Sfx.play("clink", 1.5, -6.0)
		return "picked"
	var r := Circuit.toggle_wire(get_parent(), wire_from, m)
	match r:
		"added":
			Sfx.play("snip", 1.0)
			Sfx.play("pickup", 1.4, -8.0)
		"removed":
			Sfx.play("snip", 0.7)
		_:
			Game.toast.emit("Too far for a wire (%dm max)" % int(Wire.MAX_LEN), Color("ffd27a"))
			Sfx.play("thud", 1.4, -6.0)
	wire_from = null
	return r


## A loose length of wire from the machine you picked to where you're looking.
func _update_wire_preview() -> void:
	var on := tool == "wires" and wire_from != null and is_instance_valid(wire_from)
	if not on:
		if _wire_preview != null:
			_wire_preview.visible = false
		if tool != "wires":
			wire_from = null
		return
	if _wire_preview == null:
		_wire_preview = MeshInstance3D.new()
		_wire_preview.mesh = LowPoly.box(Vector3(0.03, 0.03, 1.0))
		_wire_preview.material_override = LowPoly.mat(Color("d9783a"), 0.4, 0.4).duplicate()     # its own copy: it turns red
		_wire_preview.top_level = true
		_wire_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_wire_preview)
	var a := wire_from.terminal_world()
	var hit := look_ray(float(tdef().reach), 1 | 2)
	var b: Vector3 = hit.position if not hit.is_empty() else cam.global_position - cam.global_transform.basis.z * 2.0
	var tm := Machine.of(hit.get("collider"))
	if tm != null:
		b = tm.terminal_world()
	var d := b - a
	if d.length() < 0.01:
		_wire_preview.visible = false
		return
	_wire_preview.visible = true
	var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
	_wire_preview.global_transform = Transform3D(Basis.looking_at(d.normalized(), up) * Basis.from_scale(Vector3(1, 1, d.length())), (a + b) * 0.5)
	var too_far := d.length() > Wire.MAX_LEN
	(_wire_preview.material_override as StandardMaterial3D).albedo_color = Color("ff5a4a") if too_far else Color("d9783a")


## Rock drills: every turn of the bit knocks a chunk off the rock you're holding it on.
func drill_rock() -> bool:
	var hit := look_ray(float(tdef().reach), 1)
	if hit.is_empty() or not hit.collider.has_method("on_hit") or not (hit.collider is Rock):
		return false
	hit.collider.call("on_hit", hit.position, hit.normal, tool)
	Sfx.play("grind", randf_range(0.9, 1.1), -6.0)
	_shake = 0.05
	return true


## Footsteps sound like what you're walking on: grass and dirt, wooden floors (cabin, porch, dock, builds), stone.
func _step_sound() -> String:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 0.4, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.collider is Terrain:
		return "step"
	if hit.collider is Rock or (hit.collider as Node).get_meta("build", {}).get("id", "") == "pillar":
		return "step_stone"
	return "step_wood"


## A hint shown once in a while (not every frame a tool is held on something).
func tell(key: String, text: String) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_told.get(key, -100000)) > 6000:
		_told[key] = now
		Game.toast.emit(text, Color("ffd27a"))


## Bark that came off `t` flies off as sheets (with a puff of bits). Returns how many panels came off.
func spawn_bark(t: ForestTree, results: Array, at: Vector3, push: Vector3, mult := 1.0, fling := 1.0) -> int:
	var n := 0
	for res in results:
		if (res as Dictionary).is_empty():
			continue
		var data := t.piece_data(int(res.layer), res.panels)
		data["value_mult"] = mult
		var chip: Chip = get_parent().call("spawn_chip", data, t.kind, push)
		if fling != 1.0 and chip != null:
			chip.linear_velocity *= fling
		n += (res.panels as Array).size()
		_burst(at, t.bark_color if int(res.layer) == 0 else t.inner_color, 10 + (res.panels as Array).size() * 2)
	pieces_stripped += n
	return n


# ------------------------------------------------------------------ the second wave of tools

## Where the hand is (the thrown hatchet flies back to it).
func hand_world() -> Vector3:
	return tool_root.global_position


## Throwing hatchet: it leaves the hand at the release point of the throw and flies along your aim.
func _throw() -> void:
	if is_instance_valid(_thrown):
		return
	var reach := float(tdef().reach)
	var aim := look_ray(reach, 1)
	var from := cam.global_position - cam.global_transform.basis.z * 0.45 + cam.global_transform.basis.x * 0.12
	var goal: Vector3 = aim.position if not aim.is_empty() else cam.global_position - cam.global_transform.basis.z * reach
	var th := ThrownHatchet.new()
	get_parent().add_child(th)
	# aim a touch high to make up for the drop on the way
	var dist := from.distance_to(goal)
	var t_flight := dist / ThrownHatchet.SPEED
	goal += Vector3.UP * 0.5 * ThrownHatchet.DROP * t_flight * t_flight
	th.launch(self, from, goal - from, reach)
	_thrown = th
	if tool_model != null:
		tool_model.visible = false
	Sfx.play("whoosh", 0.75, -2.0)


## The thrown hatchet hit a trunk: it takes a patch of the outermost bark there. Returns the panels taken.
func throw_hit(t: ForestTree, c: Object, at: Vector3, dir: Vector3) -> int:
	var r := float(Tools.TOOLS.throwing.radius)
	var res := t.strip_circle(at, r)
	var n := spawn_bark(t, [res], at, dir)
	if n > 0:
		Sfx.play_at("axe", at, 1.05, 2.0)
		t.shake_crown(dir, 0.5)
		if c is Log:
			(c as Log).apply_impulse(dir * 0.8, at - (c as Log).global_position)
	return n


func catch_hatchet() -> void:
	_thrown = null
	_catch = 1.0
	if tool == "throwing" and tool_model != null:
		tool_model.visible = true
	Sfx.play("catch", 1.0, -3.0)


## Spiral axe: each hit takes a slanted stripe of four panels that carries on where the last one ended, so the
## stripes wind round and up the trunk. Keep the rhythm going and the stripe gets wider.
func _spiral_hit(t: ForestTree, at: Vector3) -> Array:
	var start := t.panel_at(at)
	if start.x < 0:
		return []
	if _spiral_tree == t and _spiral_t < 1.6 and _spiral_next.y < t.bands:
		start = _spiral_next
		_spiral_n += 1
	else:
		_spiral_n = 0
	var width := 1 + mini(_spiral_n / 3, 2)
	var list: Array = []
	for k in 4:
		for w in width:
			list.append(Vector2i(start.x + k, start.y + k - w))
	_spiral_tree = t
	_spiral_t = 0.0
	_spiral_next = Vector2i(posmod(start.x + 4, ForestTree.SECTORS), start.y + 4)
	return t.strip_panels(list)


## Leaf rake: everything loose lying in front of you gets dragged a step toward you.
func rake() -> int:
	var fwd := -global_transform.basis.z
	var centre := global_position + fwd * 1.9 + Vector3.UP * 0.3
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.25
	q.shape = sph
	q.transform = Transform3D(Basis(), centre)
	q.collision_mask = 2
	var n := 0
	for r in get_world_3d().direct_space_state.intersect_shape(q, 64):
		var b := r.collider as RigidBody3D
		if b == null or b.freeze or b == held or not b.is_in_group("grabbable") or b.is_in_group("baskets"):
			continue
		if b is Log and (b as Log).length > 1.2:
			continue
		var to := global_position - b.global_position
		to.y = 0.0
		if to.length() < 0.7:
			continue           # already at your feet
		b.sleeping = false
		b.linear_velocity = to.normalized() * clampf(to.length() * 1.3, 1.2, 2.8) + Vector3.UP * 0.9
		n += 1
	Sfx.play("rake", randf_range(0.9, 1.1), -3.0)
	var ground := global_position + fwd * 2.2
	get_parent().call("bend_grass", ground, 1.2)
	Nature.burst(get_parent(), ground + Vector3.UP * 0.05, -fwd + Vector3.UP, Color("6a8a3a"), 8, 1.2, 0.03, 6.0, 0.5)
	return n


func _sapling_in_front() -> Sapling:
	var hit := look_ray(float(Tools.TOOLS.can.reach), 1 | 2)
	if hit.is_empty():
		return null
	if hit.collider is Sapling:
		return hit.collider as Sapling
	var best: Sapling = null
	var bd := 1.2
	for s in get_tree().get_nodes_in_group("saplings"):
		var sp := s as Sapling
		var dd := sp.global_position.distance_to(hit.position)
		if dd < bd:
			bd = dd
			best = sp
	return best


## Watering can: a rooted sapling in front grows twice as fast for a minute.
func water() -> bool:
	var spout := cam.global_position - cam.global_transform.basis.z * 0.75 + Vector3.DOWN * 0.15
	Nature.burst(get_parent(), spout, -cam.global_transform.basis.z + Vector3.DOWN * 0.6, Color(0.6, 0.8, 1.0), 26, 2.0, 0.018, 9.0, 0.7, 25.0)
	Sfx.play("pour", 1.0, -4.0)
	var sp := _sapling_in_front()
	if sp == null:
		return false
	if not sp.water():
		tell("water", "It has to take root first - leave it on the ground for a moment")
		return false
	Nature.burst(get_parent(), sp.global_position + Vector3.UP * 0.4, Vector3.UP, Color("8fe08a"), 14, 1.0, 0.03, -0.3, 1.0, 120.0, 1.0)
	return true


## Dynamite: stick a charge where you're looking (wire it to a switch with power to set it off).
func plant_charge() -> Charge:
	var left := int(Game.charges.get("dynamite", 0))
	if left <= 0:
		tell("dyn", "Out of dynamite - TimberMart sells it by the box")
		return null
	var hit := look_ray(float(tdef().reach), 1)
	if hit.is_empty() or hit.collider is Charge:
		return null
	var ch := Charge.new()
	get_parent().add_child(ch)
	ch.plant(hit.position, hit.normal)
	Game.charges["dynamite"] = left - 1
	Game.toast.emit("%d left" % (left - 1), Color("ffd27a"))
	return ch


## A blast nearby rocks the view.
func blast_shake(k: float) -> void:
	_shake = maxf(_shake, k * 0.6)
	_kick = maxf(_kick, k * 0.08)


## Log scale: what the thing you're pointing at weighs and what it's worth. {} if it isn't something to weigh.
func scale_reading(c: Object) -> Dictionary:
	if c == null:
		return {}
	var b := c as RigidBody3D
	if c is Log:
		var lg := c as Log
		var kg := PI * lg.radius * lg.radius * lg.length * 600.0
		return {"kg": kg, "text": "Log  %.1f m  ·  %d kg  ·  worth $%.2f" % [lg.length, int(kg), lg.value()]}
	if b == null or not b.is_in_group("grabbable"):
		return {}
	var bk := _basket_around(b) if not b.is_in_group("baskets") else b
	if bk != null:
		var kg2 := bk.mass
		var worth := 0.0
		var n := 0
		for o in _tray_contents(bk):
			n += 1
			worth += Truck.sale_value(o)
			kg2 += _weight(o)
		return {"kg": kg2, "text": "%d things inside  ·  %d kg  ·  worth $%.2f" % [n, int(kg2), worth]}
	return {"kg": _weight(b), "text": "%.1f kg  ·  worth $%.2f" % [_weight(b), Truck.sale_value(b)]}


static func _weight(b: Node) -> float:
	if b is Log:
		return PI * (b as Log).radius * (b as Log).radius * (b as Log).length * 600.0
	if b is Chip:
		return 0.25 * (b as Chip).panels
	if b is RigidBody3D:
		return (b as RigidBody3D).mass
	return 0.0


## Ore detector: beeps faster the closer the nearest rock with ore in it (showing, or hidden inside) is.
func _detector_step(delta: float) -> void:
	_beep_glow = maxf(0.0, _beep_glow - delta * 6.0)
	if tool != "detector" or tool_model == null:
		return
	var lamp := tool_model.get_node_or_null("Glow") as MeshInstance3D
	if lamp != null:
		(lamp.material_override as StandardMaterial3D).emission_energy_multiplier = _beep_glow * 4.0
	var best := 1e9
	for r in get_tree().get_nodes_in_group("rocks"):
		var rk := r as Rock
		if rk.inner_ore() == "stone" or rk.is_queued_for_deletion():
			continue
		best = minf(best, rk.global_position.distance_to(global_position))
	if best > 18.0:
		return
	_beep_t -= delta
	if _beep_t <= 0.0:
		var k := clampf(best / 18.0, 0.0, 1.0)
		_beep_t = lerpf(0.09, 1.3, k)
		_beep_glow = 1.0
		Sfx.play("beep", lerpf(1.5, 0.8, k), lerpf(-4.0, -12.0, k))


## Pole saw: held up in the leaves of a standing tree, it cuts the whole crown off.
func _polesaw_step(delta: float, on: bool) -> void:
	if String(tdef().get("kind", "")) != "polesaw":
		return
	var tree: ForestTree = null
	var hit := {}
	if on:
		hit = look_ray(float(tdef().reach), 1 | Foliage.LAYER)
		var c: Object = hit.get("collider")
		if c is Foliage:
			tree = (c as Node).get_parent().get_parent() as ForestTree
		elif c is ForestTree and not (c as ForestTree).felled and (c as ForestTree).to_local(hit.position).y > (c as ForestTree).trunk_h - 2.2:
			tree = c as ForestTree
	if tree == null or tree.felled or tree.get_node_or_null("Crown") == null:
		saw_progress = maxf(0.0, saw_progress - delta * 2.0)
		_pole_target = null
		return
	_sawing = true
	if tree != _pole_target:
		_pole_target = tree
		saw_progress = 0.0
	saw_progress += delta / 1.8
	_saw_fx -= delta
	if _saw_fx <= 0.0:
		_saw_fx = 0.12
		Sfx.play("saw", randf_range(1.0, 1.2), -8.0)
		Nature.burst(get_parent(), hit.position, Vector3.DOWN, Color("6aa846"), 5, 1.0, 0.04, 2.0, 1.0, 120.0)
	if saw_progress >= 1.0:
		saw_progress = 0.0
		_pole_target = null
		if tree.cut_crown(get_parent()):
			Sfx.play("timber", 1.4, -4.0)


## Planer, pressure washer and leaf blower: motors that run while the trigger is held.
func _motor_step(delta: float, on: bool, kind: String) -> void:
	_running = on
	if not on or kind != "washer":
		if _wash_sound.playing:
			_wash_sound.stop()
	if not on or kind != "blower":
		if _blow_sound.playing:
			_blow_sound.stop()
	if not on:
		return
	var d := tdef()
	var fwd := -cam.global_transform.basis.z
	match kind:
		"blower":
			if not _blow_sound.playing:
				_blow_sound.stream = Sfx.vacuum_stream()
				_blow_sound.pitch_scale = 1.35
				_blow_sound.play()
			_blow(delta, fwd)
		"washer":
			if not _wash_sound.playing:
				_wash_sound.stream = Sfx.washer_stream()
				_wash_sound.play()
			var nozzle := cam.global_position + fwd * 0.9 + cam.global_transform.basis.y * -0.16 + cam.global_transform.basis.x * 0.08
			# the jet isn't laser-straight: it wanders a little around the aim, so it eats a soft round patch
			var jet := (fwd + (cam.global_transform.basis.x * randf_range(-1, 1) + cam.global_transform.basis.y * randf_range(-1, 1)) * 0.022).normalized()
			var hq := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + jet * float(d.reach), 1)
			hq.exclude = [get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(hq)
			var end: Vector3 = hit.position if not hit.is_empty() else cam.global_position + fwd * float(d.reach)
			# the jet: a stream of spray from the nozzle, and a splash where it lands
			Nature.burst(get_parent(), nozzle, end - nozzle, Color(0.82, 0.9, 1.0), 4, (end - nozzle).length() * 2.6, 0.015, 2.0, 0.35, 3.0)
			if not hit.is_empty():
				Nature.burst(get_parent(), end, hit.normal, Color(0.85, 0.92, 1.0), 3, 1.5, 0.02, 6.0, 0.4, 70.0)
			_run_cd -= delta
			if _run_cd > 0.0 or hit.is_empty():
				return
			_run_cd = float(d.cooldown)
			var t := trunk_of(hit.collider)
			if t != null:
				var n := spawn_bark(t, t.strip_soft(hit.position, float(d.radius), 3), hit.position, fwd)
				if n > 0:
					chops += 1
					if hit.collider is Log:
						(hit.collider as Log).apply_impulse(fwd * 0.15, hit.position - (hit.collider as Log).global_position)
			elif hit.collider is RigidBody3D:
				(hit.collider as RigidBody3D).apply_central_impulse(fwd * 0.3)
		"planer":
			_run_cd -= delta
			if _run_cd > 0.0:
				return
			_run_cd = float(d.cooldown)
			var ph := look_ray(float(d.reach), 1)
			if ph.is_empty():
				return
			if ph.collider is ForestTree:
				tell("planer", "The planer only works on logs lying down - fell the tree first")
				return
			if not (ph.collider is Log):
				return
			var lg := ph.collider as Log
			var res := lg.trunk.strip_column(ph.position)
			if spawn_bark(lg.trunk, [res], ph.position, fwd + Vector3.UP * 0.5) > 0:
				chops += 1
				Sfx.play("saw", 1.6, -4.0)
				Sfx.play("drill", 1.3, -8.0)
				_shake = maxf(_shake, 0.05)
			else:
				Sfx.play("chop_wood", 1.3, -8.0)


## Leaf blower: everything loose in a cone in front of you gets blown away from you.
func _blow(delta: float, fwd: Vector3) -> void:
	var reach := float(tdef().reach)
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = reach * 0.6
	q.shape = sph
	q.transform = Transform3D(Basis(), cam.global_position + fwd * reach * 0.5)
	q.collision_mask = 2
	for r in get_world_3d().direct_space_state.intersect_shape(q, 128):
		var b := r.collider as RigidBody3D
		if b == null or b.freeze or b == held or not b.is_in_group("grabbable") or b.is_in_group("baskets"):
			continue
		if b is Log and (b as Log).length > 1.6:
			continue
		var to := b.global_position - cam.global_position
		if to.length() > reach or fwd.dot(to.normalized()) < 0.75:
			continue
		# light things (bark, leaves) fly; heavy ones (stone, logs) only shuffle along
		var k := 1.0 - to.length() / reach
		var push := (fwd + Vector3.UP * 0.35).normalized() * lerpf(6.0, 22.0, k) * delta
		b.sleeping = false
		b.linear_velocity += push * clampf(1.2 / maxf(b.mass, 0.05), 0.15, 2.0)
	_vac_fx -= delta
	if _vac_fx <= 0.0:
		_vac_fx = 0.06
		var nozzle := cam.global_position + fwd * 1.0 + cam.global_transform.basis.y * -0.2
		Nature.burst(get_parent(), nozzle, fwd, Color(0.8, 0.78, 0.7), 3, 7.0, 0.012, 0.0, 0.5, 12.0)


## Thunder axe: hold to charge, let go on a trunk and lightning strips the whole tree. Released early, it's an
## ordinary hit; it needs a few seconds to charge up again after a strike.
func _thunder_step(delta: float, pressing: bool) -> void:
	_thunder_cd = maxf(0.0, _thunder_cd - delta)
	var d := tdef()
	if not d.has("charge"):
		_charging = false
		charge = 0.0
		return
	if pressing and not _charging and _swing < 0.0 and _equip_t >= 1.0:
		_charging = true
	if _charging and pressing:
		if _thunder_cd > 0.0:
			tell("thunder", "The Thunder Axe is still recharging")
		else:
			var was := charge
			charge = minf(1.0, charge + delta / float(d.charge))
			if was < 1.0 and charge >= 1.0:
				Sfx.play("crackle", 0.8, 0.0)
			elif randf() < delta * (3.0 + charge * 12.0):
				Sfx.play("crackle", randf_range(0.9, 1.4), lerpf(-14.0, -4.0, charge))
	elif _charging:
		_charging = false
		if charge >= 1.0:
			_thunder_strike()
		else:
			start_swing()
		charge = 0.0
	var glow := tool_model.get_node_or_null("Glow") if tool_model != null else null
	if glow != null:
		var e := (0.6 + charge * 5.0 + (sin(Time.get_ticks_msec() * 0.03) * 0.8 * charge)) if _thunder_cd <= 0.0 else 0.15
		for mi in glow.get_children():
			((mi as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier = e


func _thunder_strike() -> void:
	_thunder_cd = float(tdef().get("rest", 6.0))
	start_swing()
	var hit := look_ray(float(tdef().reach) + 1.0, 1)
	var at: Vector3 = hit.position if not hit.is_empty() else cam.global_position - cam.global_transform.basis.z * 4.0
	var t := trunk_of(hit.get("collider"))
	if t != null:
		var n := spawn_bark(t, t.strip_all(4), at, -cam.global_transform.basis.z, 1.0, 2.6)
		chops += 1
		t.shake_crown(-cam.global_transform.basis.z, 3.0)
		if n == 0:
			Sfx.play("chop_wood")
	_lightning(at)


## A bolt from the sky onto `at`, a flash and a thunderclap.
func _lightning(at: Vector3) -> void:
	var world := get_parent()
	var bolt := Node3D.new()
	world.add_child(bolt)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("e8f6ff")
	m.emission_enabled = true
	m.emission = Color("bfe9ff")
	m.emission_energy_multiplier = 6.0
	var p := at + Vector3(randf_range(-2, 2), 26.0, randf_range(-2, 2))
	var steps := 9
	for i in steps:
		var k := float(i + 1) / steps
		var q := p.lerp(at, 1.0 / (steps - i)) + (Vector3(randf_range(-0.9, 0.9), 0, randf_range(-0.9, 0.9)) if i < steps - 1 else Vector3.ZERO)
		Tools._rod(bolt, p, q, 0.06 * (1.2 - k * 0.6), m, 4)
		p = q
	var light := OmniLight3D.new()
	light.light_color = Color("cfeaff")
	light.light_energy = 10.0
	light.omni_range = 30.0
	world.add_child(light)
	light.global_position = at + Vector3.UP * 2.0
	var tw := bolt.create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func(): bolt.visible = false)
	tw.tween_interval(0.06)
	tw.tween_callback(func(): bolt.visible = true)
	tw.tween_interval(0.08)
	tw.tween_callback(bolt.queue_free)
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.5)
	lt.tween_callback(light.queue_free)
	Nature.burst(world, at, Vector3.UP, Color("bfe9ff"), 40, 6.0, 0.02, 3.0, 0.4, 180.0, 4.0)
	var hud: Node = world.get("hud")
	if hud != null:
		hud.call("lightning", 0.75)
	Sfx.play("thunder", 1.0, 2.0)
	_shake = 0.5
	_kick = 0.1
	world.call("bend_grass", at, 3.0)


## Used by tests to drive the drill without a mouse.
func drill_once() -> void:
	if aiming_at_tree():
		_do_impact()


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.15
	_land = move_toward(_land, 0.0, delta * 4.0)
	cam.position = Vector3(0, sin(_bob) * 0.035 * head_bob - _land * 0.06, 0) + sh
	_kick = move_toward(_kick, 0.0, delta * 0.35)
	cam.rotation.x = -_kick * 0.6
	_animate_arm(delta)
	_update_wire_preview()


# ------------------------------------------------------------------ animation

## Swing arcs for the bladed tools (camera space): diagonal chops from up high, the head arriving at the crosshair
## with the edge leading at ~45 degrees (the double-bit alternates from the right and from the left). The forearm points along the arc's radius and the tool continues
## it, with the cutting edge facing the direction of travel - so the sharp edge always leads into the wood.
## pivot = shoulder, axis = rotation axis, r0 = radius direction at angle 0, len = forearm reach,
## angles (deg): windup, impact, follow-through.
const ARCS := {
	"chop": {"pivot": Vector3(-0.2, -0.45, -0.4), "axis": Vector3(-0.87, 0.5, 0.0), "r0": Vector3(0.5, 0.87, 0.0), "len": 0.3, "a": [-70.0, 36.0, 90.0]},
	"sweep": {"pivot": Vector3(-0.3, -0.65, -0.28), "axis": Vector3(-0.87, 0.5, 0.0), "r0": Vector3(0.5, 0.87, 0.0), "len": 0.32, "a": [-75.0, 36.0, 90.0]},
	"sweep_back": {"pivot": Vector3(0.3, -0.65, -0.28), "axis": Vector3(-0.87, -0.5, 0.0), "r0": Vector3(-0.5, 0.87, 0.0), "len": 0.32, "a": [-75.0, 36.0, 90.0]},
	"slam": {"pivot": Vector3(-0.3, -0.7, -0.25), "axis": Vector3(-0.87, 0.5, 0.0), "r0": Vector3(0.5, 0.87, 0.0), "len": 0.32, "a": [-85.0, 36.0, 90.0]},
	"twin": {"pivot": Vector3(-0.15, -0.45, -0.35), "axis": Vector3(-0.87, 0.5, 0.0), "r0": Vector3(0.5, 0.87, 0.0), "len": 0.3, "a": [-60.0, 36.0, 85.0]},
	"hammer": {"pivot": Vector3(0.1, -0.45, 0.0), "axis": Vector3(-1.0, 0.0, 0.0), "r0": Vector3(0.0, 1.0, 0.25), "len": 0.3, "a": [-30.0, 64.0, 78.0]},
}
# tool basis inside the arm: handle (+Y) along the forearm (-Z), cutting edge (-Z) along the arm's +X (the arc tangent)
const TOOL_IN_ARM := Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0))
const MIRROR := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))


## Reflects a camera-space transform left <-> right.
static func _mirror(t: Transform3D) -> Transform3D:
	return Transform3D(MIRROR * t.basis * MIRROR, Vector3(-t.origin.x, t.origin.y, t.origin.z))


func _arc_name() -> String:
	var anim := String(tdef().anim)
	if anim == "sweep" and _backhand:
		return "sweep_back"
	return anim


## Arm transform (camera space) with the hand at `hand`, forearm along `radial`, arm +X along `tangent`.
static func _arm_xform(hand: Vector3, radial: Vector3, tangent: Vector3) -> Transform3D:
	var z := -radial.normalized()
	var x := (tangent - tangent.project(z)).normalized()
	var y := z.cross(x)
	return Transform3D(Basis(x, y, z), hand + radial.normalized() * 0.13)


func _arc_xform(arc: Dictionary, deg: float) -> Transform3D:
	var axis: Vector3 = (arc.axis as Vector3).normalized()
	var r: Vector3 = (arc.r0 as Vector3).normalized().rotated(axis, deg_to_rad(deg))
	var hand: Vector3 = arc.pivot + r * float(arc.len)
	return _arm_xform(hand, r, axis.cross(r))


func _rest_xform() -> Transform3D:
	# tool held up in front, edge facing forward
	var radial := Vector3(0.15, 0.8, -0.55).normalized()
	var tangent := radial.cross(Vector3.RIGHT)
	return _arm_xform(_arm_base + Vector3(0.0, -0.04, 0.02) + _sway(), radial, tangent)


static func _blend(a: Transform3D, b: Transform3D, k: float) -> Transform3D:
	return Transform3D(Basis(a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), k)), a.origin.lerp(b.origin, k))


## Pose-based animation for hands and the powered / handheld tools: [rest, windup, strike] as [offset, rotation].
func _poses() -> Array:
	match String(tdef().anim):
		"drill":
			return [[Vector3(-0.02, 0.02, 0), Vector3(2, 4, 0)], [Vector3(-0.04, 0.02, -0.06), Vector3(0, 2, 0)], [Vector3(-0.05, 0.02, -0.12), Vector3(0, 0, 0)]]
		"saw":
			return [[Vector3(-0.06, -0.02, 0), Vector3(-4, 6, 0)], [Vector3(-0.08, -0.04, 0.05), Vector3(-6, 3, 0)], [Vector3(-0.1, -0.06, -0.12), Vector3(-8, 0, 0)]]
		"vacuum", "washer":
			return [[Vector3(-0.06, 0.0, 0), Vector3(-2, 6, 0)], [Vector3(-0.08, 0.0, -0.04), Vector3(-2, 3, 0)], [Vector3(-0.1, 0.0, -0.06), Vector3(0, 0, 0)]]
		"snip":
			return [[Vector3(-0.04, 0.04, 0), Vector3(14, 6, 0)], [Vector3(-0.05, 0.08, -0.02), Vector3(22, 4, 0)], [Vector3(-0.06, 0.12, -0.14), Vector3(28, 2, 0)]]
		"rake":
			# reach out, then drag it back toward you
			return [[Vector3(-0.06, 0.03, 0), Vector3(-2, 6, 0)], [Vector3(-0.07, 0.08, -0.17), Vector3(10, 3, 0)], [Vector3(-0.06, -0.05, 0.1), Vector3(-14, 7, 0)]]
		"pour":
			return [[Vector3(-0.04, -0.02, 0), Vector3(0, 6, 0)], [Vector3(-0.05, 0.04, -0.06), Vector3(6, 4, 0)], [Vector3(-0.07, 0.03, -0.1), Vector3(-38, 4, 0)]]
		"scale":
			return [[Vector3(-0.1, 0.07, -0.02), Vector3(12, 16, 0)], [Vector3(-0.1, 0.05, -0.02), Vector3(8, 16, 0)], [Vector3(-0.1, 0.1, -0.06), Vector3(16, 14, 0)]]
		"detector":
			return [[Vector3(-0.04, 0.05, 0), Vector3(8, 6, 0)], [Vector3(-0.04, 0.06, -0.02), Vector3(10, 6, 0)], [Vector3(-0.04, 0.03, -0.06), Vector3(4, 6, 0)]]
		"thrust":
			# draw the spud back, then push it in under the bark
			return [[Vector3(-0.02, 0.0, 0.08), Vector3(4, 14, 0)], [Vector3(-0.01, 0.02, 0.18), Vector3(6, 12, 0)], [Vector3(-0.07, -0.02, -0.2), Vector3(-3, 4, 0)]]
		"polesaw":
			return [[Vector3(-0.05, -0.06, 0), Vector3(0, 5, 0)], [Vector3(-0.06, -0.05, 0.07), Vector3(2, 4, 0)], [Vector3(-0.07, -0.02, -0.12), Vector3(4, 2, 0)]]
		"planer":
			return [[Vector3(-0.05, 0.02, 0), Vector3(-6, 8, 0)], [Vector3(-0.06, 0.01, -0.05), Vector3(-10, 5, 0)], [Vector3(-0.07, 0.0, -0.1), Vector3(-14, 2, 0)]]
		"plant":
			return [[Vector3(-0.04, -0.01, 0), Vector3(0, 8, 0)], [Vector3(-0.02, 0.05, 0.07), Vector3(18, 6, 0)], [Vector3(-0.06, -0.07, -0.22), Vector3(-30, 2, 0)]]
	return [[Vector3(0, 0, 0), Vector3(4, 6, 0)], [Vector3(0.06, 0.24, 0.1), Vector3(55, -5, 30)], [Vector3(-0.2, -0.02, -0.26), Vector3(-20, 25, -15)]]


## Frame-rate independent smoothing: the fraction of the way to move this frame, for a given speed.
static func _follow(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)


## The open hand held up and forward, ready to catch the throwing hatchet.
func _ready_xform() -> Transform3D:
	var radial := Vector3(0.05, 0.55, -0.83).normalized()
	return _arm_xform(_arm_base + Vector3(-0.03, 0.05, -0.06) + Vector3(0, sin(_anim_t * 3.0) * 0.006, 0), radial, radial.cross(Vector3.RIGHT))


## A little sway of the arm while walking, and a dip when you land.
func _sway() -> Vector3:
	return Vector3(sin(_bob * 0.5) * 0.012, -absf(sin(_bob)) * 0.008, 0) * head_bob + Vector3(0, -_land * 0.05, 0)


func _animate_arm(delta: float) -> void:
	_anim_t += delta
	var anim := String(tdef().anim)
	var impact := float(tdef().impact)
	var spin := 0.0
	var raise := (1.0 - ease(_equip_t, 0.4)) * 0.35
	if anim == "throw" and held == null:
		_animate_throw(delta, raise)
		return
	if (ARCS.has(anim) or anim == "double") and held == null:
		var arc: Dictionary = ARCS["sweep" if anim == "double" else _arc_name()]
		var t := _swing
		if anim == "double":
			# forehand into the trunk, then straight back across with the other bit
			impact = 0.7
			if _swing >= 0.5:
				arc = ARCS["sweep_back"]
				t = (_swing - 0.5) * 2.0
			elif _swing >= 0.0:
				t = _swing * 2.0
		var ang: Array = arc.a
		var rest := _rest_xform()
		var swing := rest
		if _swing >= 0.0:
			var wind_end := impact * 0.55
			var follow_end := minf(impact + 0.18, 0.95)
			if t < wind_end:
				swing = _blend(rest, _arc_xform(arc, ang[0]), ease(t / wind_end, 0.5))
			elif t < impact:
				var k := ease((t - wind_end) / (impact - wind_end), 2.2)
				swing = _arc_xform(arc, lerpf(ang[0], ang[1], k))
				if tool == "labrys":
					spin = k * 360.0
			elif t < follow_end:
				swing = _arc_xform(arc, lerpf(ang[1], ang[2], ease((t - impact) / (follow_end - impact), 0.5)))
			else:
				swing = _blend(_arc_xform(arc, ang[2]), rest, ease((t - follow_end) / (1.0 - follow_end), 0.7))
		elif _charging and charge > 0.0:
			# thunder axe: held up high in front while it charges, trembling harder as it fills
			var e := ease(charge, 0.4)
			swing = rest
			swing.origin += Vector3(0.03, 0.09, 0.05) * e
			swing.basis = Basis(Vector3.RIGHT, 0.55 * e) * Basis(Vector3.FORWARD, -0.25 * e) * swing.basis
			swing.origin += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.005 * charge
			if randf() < charge * 0.5 and tool_model != null:
				var head := tool_model.global_transform * Vector3(0, 0.55, -0.12)
				Nature.burst(get_parent(), head, Vector3.UP, Color("bfe9ff"), 2, 1.2, 0.012, 0.0, 0.25, 180.0, 3.0)
		# fast while swinging so the arc stays crisp, softer when settling back to rest
		var k2 := _follow(85.0 if _swing >= 0.0 else (40.0 if _charging else 22.0), delta)
		# twin hatchets: the hands take turns (the left hand mirrors the right one's arc)
		var right_t := swing if not (anim == "twin" and _backhand) else rest
		right_t = _raised(right_t, raise)
		arm.transform = _blend(arm.transform, right_t, k2)
		if tool_model != null:
			tool_model.position = Vector3.ZERO
			tool_model.basis = TOOL_IN_ARM * Basis(Vector3.UP, deg_to_rad(spin))
		if anim == "twin":
			var left_t := _raised(_mirror(swing if _backhand else rest), raise)
			arm_l.transform = _blend(arm_l.transform, left_t, k2)
			if tool_model_l != null:
				tool_model_l.position = Vector3.ZERO
				tool_model_l.basis = MIRROR * TOOL_IN_ARM * MIRROR
		# combo axe: the rune glows brighter with the combo
		if tool == "combo" and tool_model != null:
			var g := tool_model.get_node_or_null("Glow") as MeshInstance3D
			if g != null:
				(g.material_override as StandardMaterial3D).emission_energy_multiplier = 0.4 + _combo_n * 0.7
		return
	var poses := _poses()
	var now := Time.get_ticks_msec() * 0.001
	var sway := _sway()
	var rest_p: Vector3 = _arm_base + poses[0][0] + sway
	var rest_r: Vector3 = poses[0][1]
	var up_p: Vector3 = _arm_base + poses[1][0]
	var up_r: Vector3 = poses[1][1]
	var hit_p: Vector3 = _arm_base + poses[2][0]
	var hit_r: Vector3 = poses[2][1]
	if anim == "detector":
		# sweep the coil slowly from side to side
		var sw := sin(now * 2.2)
		rest_p.x += sw * 0.035
		rest_r.y += sw * 9.0
	var p := rest_p
	var r := rest_r
	if held != null:
		p = _arm_base + Vector3(-0.05, -0.2, 0.08) + sway
		r = Vector3(-10, 10, 0)
	elif _drilling or _vacuuming or _running:
		p = hit_p + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * (0.004 if _drilling or anim == "planer" else 0.006)
		r = hit_r
	elif _sawing:
		# push-pull strokes (the big crosscut is slower and longer)
		var k := sin(now * (7.5 if tool == "crosscut" else 13.0)) * 0.5 + 0.5
		p = up_p.lerp(hit_p, k)
		r = up_r.lerp(hit_r, k)
	elif _swing >= 0.0:
		var t := _swing
		var wind_end := impact * 0.7
		var hold_end := 0.75 if anim == "pour" else impact     # the can stays tipped while it pours
		if t < wind_end:
			var k := ease(t / wind_end, 0.5)
			p = rest_p.lerp(up_p, k)
			r = rest_r.lerp(up_r, k)
		elif t < impact:
			var k2 := ease((t - wind_end) / (impact - wind_end), 2.0)
			p = up_p.lerp(hit_p, k2)
			r = up_r.lerp(hit_r, k2)
		elif t < hold_end:
			p = hit_p
			r = hit_r
		else:
			var k3 := ease((t - hold_end) / (1.0 - hold_end), 0.6)
			p = hit_p.lerp(rest_p, k3)
			r = hit_r.lerp(rest_r, k3)
	# raise the tool into view after switching (it comes up tilted, and straightens)
	p.y -= raise
	r.x -= raise * 60.0
	var kp := _follow(55.0, delta)
	arm.position = arm.position.lerp(p, kp)
	arm.rotation_degrees = arm.rotation_degrees.lerp(r, kp)
	if tool_model != null:
		if ARCS.has(anim):
			tool_model.basis = TOOL_IN_ARM
		var bit := tool_model.get_node_or_null("Bit") as Node3D
		if bit != null:
			var spinning := _drilling or _vacuuming or _running
			if tool == "planer":
				bit.rotation.x += delta * (50.0 if spinning else 0.0)
			else:
				bit.rotation.z += delta * (40.0 if spinning else 0.0)
			if tool == "chainsaw" and _sawing:
				bit.position.z = -0.47 + fmod(Time.get_ticks_msec() * 0.001 * 3.0, 0.028)
		# shears: jaws open on the windup and snap shut at the impact
		var ba := tool_model.get_node_or_null("BladeA") as Node3D
		var bb := tool_model.get_node_or_null("BladeB") as Node3D
		if ba != null and bb != null:
			var open := 0.35
			if _swing >= 0.0:
				open = 0.6 if _swing < impact else lerpf(0.0, 0.35, clampf((_swing - impact) / 0.4, 0.0, 1.0))
			var kb := _follow(40.0, delta)
			ba.rotation.x = lerpf(ba.rotation.x, open * 0.5, kb)
			bb.rotation.x = lerpf(bb.rotation.x, -open * 0.5, kb)
		# log scale: the needle swings round to the weight of whatever you point it at
		var needle := tool_model.get_node_or_null("Needle") as Node3D
		if needle != null:
			var sc := scale_reading(look_ray(float(tdef().reach), 1 | 2).get("collider"))
			var kg := float(sc.get("kg", 0.0))
			var want := 2.2 - clampf(sqrt(kg / 800.0), 0.0, 1.0) * 4.4
			needle.rotation.z = lerpf(needle.rotation.z, want, _follow(8.0, delta))


## The equip raise: lower and tilted down, coming up into view.
static func _raised(t: Transform3D, raise: float) -> Transform3D:
	if raise <= 0.0:
		return t
	var out := t
	out.origin.y -= raise
	out.basis = Basis(Vector3.RIGHT, -raise * 1.1) * out.basis
	return out


## Throwing hatchet: draw it back behind the head, whip it forward and let go at the top of the arc, follow through
## with the empty hand, then hold the open hand up until it comes back - and give a little as you catch it.
func _animate_throw(delta: float, raise: float) -> void:
	var arc: Dictionary = ARCS["chop"]
	var rest := _rest_xform()
	var out := is_instance_valid(_thrown)
	var release := float(tdef().impact)
	var target := rest
	var t := _swing
	var fast := false
	if t >= 0.0:
		var w_end := release * 0.72
		var follow_end := release + 0.2
		if t < w_end:
			# draw back: quick at first, slowing into the cocked position
			target = _blend(rest, _arc_xform(arc, -112.0), ease(t / w_end, 0.4))
		elif t < release:
			# the throw: accelerating all the way to the release
			target = _arc_xform(arc, lerpf(-112.0, 8.0, ease((t - w_end) / (release - w_end), 2.6)))
			fast = true
		elif t < follow_end:
			target = _arc_xform(arc, lerpf(8.0, 64.0, ease((t - release) / (follow_end - release), 0.45)))
			fast = true
		else:
			target = _blend(_arc_xform(arc, 64.0), _ready_xform() if out else rest, ease((t - follow_end) / (1.0 - follow_end), 0.6))
	elif out:
		target = _ready_xform()
	elif _catch > 0.0:
		# the catch: the hand is pushed back and down by the hatchet's weight, then settles
		var c := _catch * _catch
		target.origin += Vector3(0.015, -0.06, 0.08) * c
		target.basis = Basis(Vector3.RIGHT, 0.45 * c) * target.basis
	var open := out and (t < 0.0 or t >= release)
	hand_flat.visible = open
	hand_fist.visible = not open
	if tool_model != null:
		tool_model.visible = not out
		tool_model.position = Vector3.ZERO
		# a small flourish: the hatchet settles in the hand with a quarter turn after the catch
		tool_model.basis = TOOL_IN_ARM * Basis(Vector3.RIGHT, -_catch * _catch * 0.9)
	target.origin += _sway()
	arm.transform = _blend(arm.transform, _raised(target, raise), _follow(90.0 if fast else 30.0, delta))


# ------------------------------------------------------------------ saw, shears, vacuum

## Hold the saw on a standing trunk to fell the tree, or on a log to cut it in two.
func _saw_step(delta: float, on: bool) -> void:
	_sawing = false
	if not on:
		if String(tdef().get("kind", "")) != "polesaw":
			saw_progress = maxf(0.0, saw_progress - delta * 2.0)
			if saw_progress <= 0.0:
				_saw_target = null
		return
	var hit := look_ray(float(tdef().reach), 1)      # looks past loose bark/leaves lying on a log
	var c: Object = null if hit.is_empty() else hit.collider
	var d := tdef()
	var can_fell := bool(d.get("fell", true))
	if c == null or trunk_of(c) == null or (c is ForestTree and ((c as ForestTree).bands < 4 or not can_fell)):
		saw_progress = maxf(0.0, saw_progress - delta * 2.0)
		return
	if c is ForestTree and (c as ForestTree).giant and not bool(d.get("big", false)) and tool != "chainsaw":
		# the ancient trees are too thick for an ordinary saw
		saw_progress = 0.0
		tell("giant", "Too thick for this saw - it needs a two-man crosscut, or a chainsaw")
		return
	_sawing = true
	if c != _saw_target:
		_saw_target = c
		saw_progress = 0.0
	var t := trunk_of(c)
	var need := SAW_LOG_TIME if c is Log else SAW_TREE_TIME * (t.radius / 0.38)
	saw_progress += delta / need * float(d.get("speed", 1.0))
	_saw_fx -= delta
	if _saw_fx <= 0.0:
		var chain := tool == "chainsaw"
		_saw_fx = 0.05 if chain else 0.09
		Nature.burst(get_parent(), hit.position, hit.normal + Vector3.DOWN * 0.3, t.wood_color.lightened(0.1), 10 if chain else 6, 2.6 if chain else 1.4, 0.018, 6.0, 0.5, 60.0)
		if not chain:
			Sfx.play("saw", randf_range(0.9, 1.1), -6.0)
		if chain:
			_shake = maxf(_shake, 0.05)
	if saw_progress >= 1.0:
		saw_progress = 0.0
		_saw_target = null
		var away := -cam.global_transform.basis.z
		if c is ForestTree:
			var tree := c as ForestTree
			var j := int(floor(tree.to_local(hit.position).y / ForestTree.BAND_H))
			var felled_log := tree.fell(j, away)
			if d.has("clean"):
				felled_log.set_meta("clean", true)
			Sfx.play("timber")
		elif bool(d.get("buck", false)):
			(c as Log).buck(7)        # the whole log into ~1.3 m rounds in one go
			Sfx.play("thud", 1.0)
		else:
			for lg in (c as Log).cut_at(hit.position):
				if d.has("clean"):
					lg.set_meta("clean", true)
			Sfx.play("thud", 1.2)
		Nature.burst(get_parent(), hit.position, Vector3.UP, t.wood_color, 24, 2.0, 0.03, 6.0, 0.8, 120.0)


func _update_chainsaw(trigger: bool) -> void:
	if tool != "chainsaw":
		if _chain_sound.playing:
			_chain_sound.stop()
		return
	if not _chain_sound.playing:
		if _chain_sound.stream == null:
			_chain_sound.stream = Sfx.chainsaw_stream()
		_chain_sound.play()
	var rev := 1.0 if _sawing else (0.55 if trigger else 0.0)
	_chain_sound.pitch_scale = lerpf(_chain_sound.pitch_scale, lerpf(0.75, 1.35, rev), 0.15)
	_chain_sound.volume_db = lerpf(_chain_sound.volume_db, lerpf(-20.0, -7.0, rev), 0.15)


## Shears: one snip per click. Leaves come off crowns (incl. felled ones) and bushes.
func _snip() -> void:
	var hit := look_ray(float(tdef().reach), 1 | Foliage.LAYER | Bush.LAYER)
	Sfx.play("click", 0.6, -2.0)
	if hit.is_empty():
		return
	var out := (cam.global_position - (hit.position as Vector3)).normalized()
	if hit.collider is Foliage:
		(hit.collider as Foliage).snip(int(hit.shape), hit.position, out, get_parent())
		Sfx.play("rustle", randf_range(1.1, 1.3), -4.0)
	elif hit.collider is Bush:
		(hit.collider as Bush).snip(hit.position, out)


## Vacuum: loose things in front get pulled in and swirl in a clump at the nozzle until you let go.
## Variants: two intakes (two clumps, left and right), and the cyclone that fires its clump forward on release.
func _vacuum_step(delta: float, on: bool) -> void:
	var d := tdef()
	var fwd := -cam.global_transform.basis.z
	if not on:
		_vacuuming = false
		if not _vac_caught.is_empty():
			if bool(d.get("launch", false)):
				for b in _vac_caught.keys():
					if is_instance_valid(b):
						(b as RigidBody3D).linear_velocity = fwd * 16.0 + Vector3.UP * 2.0 + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
				Sfx.play("whoosh", 0.5, 4.0)
			_vac_caught.clear()       # otherwise they just drop, keeping their momentum
		if _vac_sound.playing:
			_vac_sound.stop()
		return
	_vacuuming = true
	if not _vac_sound.playing:
		if _vac_sound.stream == null:
			_vac_sound.stream = Sfx.vacuum_stream()
		_vac_sound.play()
	var reach := float(d.get("range", VAC_RANGE))
	var cone := float(d.get("cone", 0.8))
	var cap := int(d.get("cap", VAC_MAX))
	var basis := cam.global_transform.basis
	var nozzles: Array[Vector3] = []
	for off in d.get("nozzles", [Vector3.ZERO]):
		nozzles.append(cam.global_position + fwd * 1.25 + basis.y * -0.18 + basis.x * (off as Vector3).x)
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = reach * 0.6
	q.shape = sph
	q.transform = Transform3D(Basis(), cam.global_position + fwd * reach * 0.5)
	q.collision_mask = 2
	var now := Time.get_ticks_msec() * 0.001
	for r in get_world_3d().direct_space_state.intersect_shape(q, 128):
		var b := r.collider as RigidBody3D
		if b == null or b.freeze or b == held or not b.is_in_group("grabbable"):
			continue
		if b is Log and (b as Log).length > 1.6:
			continue
		var to := b.global_position - cam.global_position
		# the nearest intake takes it
		var ni := 0
		for k in nozzles.size():
			if b.global_position.distance_to(nozzles[k]) < b.global_position.distance_to(nozzles[ni]):
				ni = k
		var nozzle := nozzles[ni]
		var caught := _vac_caught.has(b)
		if not caught:
			if to.length() > reach or fwd.dot(to.normalized()) < cone:
				continue
			if b.global_position.distance_to(nozzle) < 0.7 and _vac_caught.size() < cap:
				_vac_caught[b] = randf() * TAU
				caught = true
		b.sleeping = false
		if caught:
			var ph: float = _vac_caught[b]
			var orbit := Vector3(cos(now * 5.0 + ph), sin(now * 7.0 + ph * 1.7) * 0.6, sin(now * 5.0 + ph)) * 0.22
			b.linear_velocity = ((nozzle + orbit) - b.global_position) * 10.0
			b.angular_velocity = b.angular_velocity.lerp(Vector3(3, 5, 2), delta * 2.0)
		else:
			var pull := (nozzle - b.global_position)
			var speed := clampf(2.0 + (reach - pull.length()) * 1.4, 2.0, 11.0)
			b.linear_velocity = b.linear_velocity.lerp(pull.normalized() * speed, minf(1.0, delta * 6.0))
	for b in _vac_caught.keys():
		if not is_instance_valid(b) or (b as RigidBody3D).freeze:
			_vac_caught.erase(b)
	var nozzle0 := nozzles[randi() % nozzles.size()]
	# a stream of dust being sucked in
	_vac_fx -= delta
	if _vac_fx <= 0.0:
		_vac_fx = 0.05
		var src := nozzle0 + fwd * randf_range(1.0, 3.0) + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.4), randf_range(-0.6, 0.6))
		Nature.burst(get_parent(), src, nozzle0 - src, Color(0.8, 0.78, 0.7), 3, (nozzle0 - src).length() * 1.2, 0.012, 0.0, 0.45, 8.0)
