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


func setup_belt(slats: Node3D, dir: Vector3, center: Vector3, run: float, tilt: float) -> void:
	_slats = slats
	_dir = dir
	_run = run
	_start = slats.get_meta("start")
	for c in slats.get_children():
		_slat_list.append(c)
	_area_xf = Transform3D(Basis(Vector3.RIGHT, tilt), center + Basis(Vector3.RIGHT, tilt) * Vector3(0, 0.25, 0))
	_area_size = Vector3(0.66, 0.45, run)


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
