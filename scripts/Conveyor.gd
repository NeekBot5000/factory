class_name Conveyor
extends Machine
## A powered belt (flat, or a ramp up to the next level). It carries whatever sits on it toward its front.

const SPEED := 1.3

var _slats: Node3D
var _dir := Vector3.FORWARD    # local direction of travel along the belt
var _start := Vector3.ZERO
var _run := 1.0
var _phase := 0.0
var _slat_list: Array[Node3D] = []
var _area_xf := Transform3D.IDENTITY
var _area_size := Vector3.ONE
var _query: PhysicsShapeQueryParameters3D
var _hum: AudioStreamPlayer3D
var _center := Vector3.ZERO


func setup_belt(slats: Node3D, dir: Vector3, center: Vector3, run: float, tilt: float) -> void:
	_slats = slats
	_dir = dir
	_run = run
	_start = slats.get_meta("start")
	_center = center
	for c in slats.get_children():
		_slat_list.append(c)
	_area_xf = Transform3D(Basis(Vector3.RIGHT, tilt), center + Basis(Vector3.RIGHT, tilt) * Vector3(0, 0.25, 0))
	_area_size = Vector3(Machines.BELT_W - 0.06, 0.45, run)


## The two ends of the belt (world space): where things come on, and where they go off.
func ends() -> Array:
	return [global_transform * (_center - _dir * _run * 0.5), global_transform * (_center + _dir * _run * 0.5)]


## Belts touching end to end (or one running into the side of another, a turn) share power, no wire needed.
func touches(o: Conveyor) -> bool:
	var a: Array = ends()
	var b: Array = o.ends()
	for e in a:
		if _seg_dist(e, b[0], b[1]) < 0.56:
			return true
	for e in b:
		if _seg_dist(e, a[0], a[1]) < 0.56:
			return true
	return false


static func _seg_dist(p: Vector3, s0: Vector3, s1: Vector3) -> float:
	var d := s1 - s0
	var t := clampf((p - s0).dot(d) / maxf(d.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(s0 + d * t)


## A border opens up where another belt runs into this one's side (a turn), so things can come across onto it.
func set_sides_open(left: bool, right: bool) -> void:
	for side in [["L", left], ["R", right]]:
		var mi := get_node_or_null("Model/Border%s" % side[0]) as Node3D
		if mi != null:
			mi.visible = not side[1]
		var cs := get_node_or_null("BorderCol%s" % side[0]) as CollisionShape3D
		if cs != null:
			cs.disabled = side[1]


## Which of this belt's sides another belt's end feeds into: [left, right].
func fed_sides(others: Array) -> Array:
	var out := [false, false]
	for o in others:
		for e in (o as Conveyor).ends():
			var lp := to_local(e) - _center
			var along := lp.dot(_dir)
			if absf(lp.x) > 0.3 and absf(lp.x) < 0.75 and absf(along) < _run * 0.5 - 0.15:
				out[0 if lp.x < 0.0 else 1] = true
	return out


func activate(p_size: float) -> void:
	super(p_size)
	add_lamp(Vector3(0.36, 0.14, 0.3))


func terminal() -> Vector3:
	return Vector3(0.36, 0.2, 0.1) * size


func _power_on() -> void:
	constant_linear_velocity = global_basis * _dir * SPEED
	Sfx.play_at("click", global_position, 0.6, -6.0)
	# a quiet hum while it runs (only nearby: lots of belts shouldn't drone across the map)
	if _hum == null:
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = Sfx.hum_stream()
		_hum.volume_db = -16.0
		_hum.unit_size = 1.5
		_hum.max_distance = 14.0
		_hum.position = Vector3(0, 0.4, 0)
		add_child(_hum)
	_hum.pitch_scale = randf_range(0.95, 1.05)
	_hum.play()


func _power_off() -> void:
	constant_linear_velocity = Vector3.ZERO
	if _hum != null:
		_hum.stop()


func _physics_process(delta: float) -> void:
	if not powered:
		return
	constant_linear_velocity = global_basis * _dir * SPEED
	# the cleats slide along and wrap round
	_phase = fmod(_phase + delta * SPEED, 0.25)
	for k in _slat_list.size():
		var t := fmod((k + 0.5) / 4.0 + _phase, _run)
		_slat_list[k].position = _start + _dir * t
	# a belt that's running keeps what's on it awake (sleeping bodies would ignore it)
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		var sh := BoxShape3D.new()
		sh.size = _area_size
		_query.shape = sh
		_query.collision_mask = 2
	_query.transform = global_transform * _area_xf
	for r in get_world_3d().direct_space_state.intersect_shape(_query, 24):
		if r.collider is RigidBody3D:
			(r.collider as RigidBody3D).sleeping = false
