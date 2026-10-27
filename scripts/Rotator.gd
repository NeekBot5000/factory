class_name Rotator
extends Machine
## A powered turntable. Hit it (or what's sitting on it) with the hammer to stick everything on the table to it;
## hit it again to let go. A piston pushed out against the table clamps whatever is between them the same way,
## until the piston pulls back. While powered it spins, carrying whatever is stuck on round with it.

const SPIN := 1.2          # radians per second at full speed

var _table: AnimatableBody3D
var _speed := 0.0
var stuck: Array = []      # [{body, off, clamp}] - offsets relative to the table; clamp = the piston holding it, or null


func setup_table(model_table: Node3D) -> void:
	_table = AnimatableBody3D.new()
	_table.collision_layer = 1
	_table.collision_mask = 0
	_table.sync_to_physics = false
	_table.position = model_table.position
	add_child(_table)
	model_table.reparent(_table, false)
	model_table.position = Vector3.ZERO
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.6
	sh.height = 0.07
	cs.shape = sh
	_table.add_child(cs)
	add_to_group("rotators")


func activate(p_size: float) -> void:
	super(p_size)
	add_lamp(Vector3(0.38, 0.27, 0.38))


func terminal() -> Vector3:
	return Vector3(0.45, 0.2, 0) * size


func hint_text() -> String:
	return "%s    [Hammer] %s" % [super(), "let go" if not stuck.is_empty() else "stick what's on it"]


## The rotator something is sitting on (or stuck to), if any.
static func holding(b: Node) -> Rotator:
	for r in b.get_tree().get_nodes_in_group("rotators"):
		var rot := r as Rotator
		if rot.is_stuck(b) or rot._on_table().has(b):
			return rot
	return null


func is_stuck(b: Node) -> bool:
	for s in stuck:
		if s.body == b:
			return true
	return false


func on_hammer() -> void:
	# (things a piston is clamping stay clamped either way)
	if not stuck.any(func(s): return s.get("clamp") == null):
		var n := stick_all()
		if n > 0:
			Sfx.play("clink", 0.8)
			Game.toast.emit("Stuck %d to the rotator" % n, Color("bfeaff"))
		else:
			Sfx.play("thud", 1.4, -6.0)
	else:
		for i in range(stuck.size() - 1, -1, -1):
			if stuck[i].get("clamp") == null:
				_let_go(stuck[i].body)
				stuck.remove_at(i)
		Sfx.play("clink", 1.2)


func stick_all() -> int:
	var held: Node = get_parent().player.held if "player" in get_parent() else null
	for b in _on_table():
		if b == held or is_stuck(b):
			continue
		_stick(b as RigidBody3D, null)
	return stuck.size()


func _stick(rb: RigidBody3D, piston: Piston) -> void:
	rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	rb.set_meta("stuck", true)
	rb.remove_from_group("grabbable")
	stuck.append({"body": rb, "off": _table.global_transform.affine_inverse() * rb.global_transform, "clamp": piston})


func _let_go(rb: RigidBody3D) -> void:
	if not is_instance_valid(rb):
		return
	rb.remove_meta("stuck")
	if rb is Log and (rb as Log).locked:
		return
	rb.freeze = false
	rb.add_to_group("grabbable")


## Pistons pushed out against the table pin what's between them to it; when a piston pulls back, it lets go.
func _check_clamps() -> void:
	for i in range(stuck.size() - 1, -1, -1):
		var p: Variant = stuck[i].get("clamp")
		if p == null:
			continue
		if not is_instance_valid(p) or not (p as Piston).clamping():
			_let_go(stuck[i].body)
			stuck.remove_at(i)
	var on: Array = []
	for pn in get_tree().get_nodes_in_group("pistons"):
		var ps := pn as Piston
		if not ps.clamping() or ps.global_position.distance_to(_table.global_position) > 3.5:
			continue
		if on.is_empty():
			on = _on_table()
			if on.is_empty():
				return
		var held: Node = get_parent().player.held if "player" in get_parent() else null
		for b in ps.call("_touching", 0.25):
			# pinned: right up against the table (not just somewhere in front of it)
			if on.has(b) and b != held and not is_stuck(b) and not (b as RigidBody3D).freeze and _table.to_local(b.global_position).y < 0.4:
				_stick(b, ps)
				Sfx.play_at("clink", b.global_position, 0.7, -6.0)


func unstick_all() -> void:
	for s in stuck:
		_let_go(s.body)
	stuck.clear()


## Loose things resting on the table.
func _on_table() -> Array:
	var out: Array = []
	if _table == null or not is_inside_tree():
		return out
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.62
	sh.height = 1.2
	q.shape = sh
	q.transform = Transform3D(_table.global_basis, _table.global_position + _table.global_basis.y * 0.6)
	q.collision_mask = 2
	for r in get_world_3d().direct_space_state.intersect_shape(q, 24):
		if r.collider is RigidBody3D and not out.has(r.collider):
			out.append(r.collider)
	return out


func _physics_process(delta: float) -> void:
	_check_clamps()      # every tick: a piston closes fast, and has to catch what it's pinning
	_speed = move_toward(_speed, SPIN if powered else 0.0, delta * 1.5)
	if _speed > 0.0:
		_table.rotation.y += _speed * delta
	for i in range(stuck.size() - 1, -1, -1):
		var s: Dictionary = stuck[i]
		var rb := s.body as RigidBody3D
		# gone: sold, picked up by something else, or let go of by another tool
		if not is_instance_valid(rb) or not rb.has_meta("stuck"):
			stuck.remove_at(i)
			continue
		rb.global_transform = _table.global_transform * (s.off as Transform3D)


func save_state() -> Dictionary:
	# clamped things aren't saved as stuck: the piston simply clamps them again after loading
	return {"angle": _table.rotation.y if _table != null else 0.0, "stuck": stuck.any(func(s): return s.get("clamp") == null)}


func load_state(d: Dictionary) -> void:
	if _table != null:
		_table.rotation.y = float(d.get("angle", 0.0))
	if bool(d.get("stuck", false)):
		_restick()


## After loading: the things that were stuck are back in the world, sitting on the table - stick them again.
func _restick() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_inside_tree():
		stick_all()
