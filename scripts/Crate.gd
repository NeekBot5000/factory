class_name Crate
extends Machine
## Storage: a big open-topped crate. Anything that lands in it stays there (it's all still real, physical stuff). While
## it has power its front hatch opens and it pushes things out one at a time, onto a belt or into a machine.

const EVERY := 0.45

var _cd := 0.0
var _door: CollisionShape3D
var _door_mesh: Node3D


func activate(p_size: float) -> void:
	super(p_size)
	_door = get_node_or_null("DoorCol") as CollisionShape3D
	_door_mesh = get_node_or_null("Model/Door") as Node3D
	add_lamp(Vector3(0.48, 0.12, 0.48))


func terminal() -> Vector3:
	return Vector3(0.48, 0.25, 0.48) * size


func contents() -> Array:
	return bodies_in(Vector3(0, 0.55, 0.04), Vector3(0.8, 0.9, 0.74))


func hint_text() -> String:
	return "Storage Crate  ·  %d things inside  ·  power it to empty it out of the front" % contents().size()


func _physics_process(delta: float) -> void:
	if _door != null:
		_door.disabled = powered
	if _door_mesh != null:
		_door_mesh.position.y = lerpf(_door_mesh.position.y, 0.75 if powered else 0.3, 0.2)
	if not powered:
		return
	_cd -= delta
	if _cd > 0.0:
		return
	var low: RigidBody3D = null
	for b in contents():
		var rb := b as RigidBody3D
		if rb != null and (low == null or rb.global_position.y < low.global_position.y):
			low = rb
	if low != null:
		_cd = EVERY
		low.sleeping = false
		# a hop and a shove towards the middle of the door: rough ore chunks would scrape to a stop on the crate's
		# floor otherwise, and need several goes to get out
		var lp := to_local(low.global_position)
		low.linear_velocity = -global_basis.z * 3.4 + Vector3.UP * 1.1 - global_basis.x * clampf(lp.x, -0.3, 0.3) * 2.5
