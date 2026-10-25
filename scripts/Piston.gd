class_name Piston
extends Machine
## While powered it shoves its wooden plate out a metre in front, pushing whatever is there; it pulls back when
## the power goes.

const REACH := 1.0
const OUT_SPEED := 5.0
const IN_SPEED := 2.0

var ext := 0.0
var _plate: AnimatableBody3D
var _home := Vector3.ZERO


func setup_plate(model_plate: Node3D) -> void:
	_plate = AnimatableBody3D.new()
	_plate.collision_layer = 1
	_plate.collision_mask = 0
	_plate.sync_to_physics = false
	_home = model_plate.position
	_plate.position = _home
	add_child(_plate)
	model_plate.reparent(_plate, false)
	model_plate.position = Vector3.ZERO
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.78, 0.78, 0.1)
	cs.shape = sh
	_plate.add_child(cs)


func activate(p_size: float) -> void:
	super(p_size)
	add_lamp(Vector3(0, 0.83, 0.3))


func terminal() -> Vector3:
	return Vector3(0, 0.8, 0.45) * size


func _power_on() -> void:
	Sfx.play("thud", 1.3, -2.0)
	Sfx.play("whoosh", 0.7, -6.0)


func _power_off() -> void:
	Sfx.play("whoosh", 0.5, -10.0)


func _physics_process(delta: float) -> void:
	var target := 1.0 if powered else 0.0
	if is_equal_approx(ext, target):
		return
	ext = move_toward(ext, target, delta * (OUT_SPEED if powered else IN_SPEED))
	_plate.position = _home + Vector3(0, 0, -ext * REACH)
	# wake up anything the plate is about to push
	for b in _touching():
		b.sleeping = false


func _touching() -> Array[RigidBody3D]:
	var out: Array[RigidBody3D] = []
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.9, 0.9, 0.5)
	q.shape = sh
	q.transform = _plate.global_transform * Transform3D(Basis(), Vector3(0, 0, -0.25))
	q.collision_mask = 2
	for r in get_world_3d().direct_space_state.intersect_shape(q, 16):
		if r.collider is RigidBody3D:
			out.append(r.collider)
	return out


func save_state() -> Dictionary:
	return {"ext": ext}


func load_state(d: Dictionary) -> void:
	ext = float(d.get("ext", 0.0))
	if _plate != null:
		_plate.position = _home + Vector3(0, 0, -ext * REACH)
