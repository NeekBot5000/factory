class_name Sprinkler
extends Machine
## While powered it waters every sapling within a few metres, so they grow twice as fast.

const RANGE := 5.0

var _head: Node3D
var _t := 0.0


func activate(p_size: float) -> void:
	super(p_size)
	_head = get_node_or_null("Model/Head")
	add_lamp(Vector3(0.2, 0.1, 0.2))


func terminal() -> Vector3:
	return Vector3(0.2, 0.2, 0.2) * size


func hint_text() -> String:
	return "Sprinkler  ·  %s" % ("watering" if powered else "waters saplings nearby while powered")


func _physics_process(delta: float) -> void:
	if not powered:
		return
	if _head != null:
		_head.rotation.y += delta * 3.0
		Nature.burst(get_parent(), _head.global_position, _head.global_basis.x + Vector3.UP * 0.6, Color(0.7, 0.85, 1.0), 2, 4.0, 0.015, 9.0, 0.8, 8.0)
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	for s in get_tree().get_nodes_in_group("saplings"):
		var sp := s as Sapling
		if sp.is_rooted() and sp.global_position.distance_to(global_position) <= RANGE:
			sp.boost = maxf(sp.boost, 2.0)
