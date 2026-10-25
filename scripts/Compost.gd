class_name Compost
extends StaticBody3D
## A leaf compost pile. Drop leaves in and it rots them down; every few leaves a sapling sprouts out of the top.
## Plant the sapling on the ground and it grows into a new tree.

const LEAVES_PER_SAPLING := 8
const ROT_TIME := 8.0

var _area: Area3D
var _mound: Node3D
var _stock := 0
var _rot := 0.0


func activate(mound: Node3D) -> void:
	_mound = mound
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.3, 0.9, 1.3)
	cs.shape = sh
	cs.position = Vector3(0, 0.5, 0)
	_area.add_child(cs)
	add_child(_area)


func hint_text() -> String:
	return "%d/%d leaves" % [_stock, LEAVES_PER_SAPLING]


func _physics_process(delta: float) -> void:
	if _area == null:
		return
	var held: Node = get_tree().get_first_node_in_group("player").get("held")
	for b in _area.get_overlapping_bodies():
		if b is Leaf and b != held and not (b as RigidBody3D).freeze:
			_stock += 1
			Nature.burst(get_parent(), (b as Node3D).global_position, Vector3.UP, (b as Leaf).color.darkened(0.3), 6, 0.8, 0.04, 2.0, 0.6, 90.0)
			(b as Node3D).queue_free()
			Sfx.play("rustle", 0.7, -8.0)
	if _mound != null:
		var k := 1.0 + minf(_stock, 24) * 0.02
		_mound.scale = _mound.scale.lerp(Vector3(1.0, k, 1.0), delta * 3.0)
	if _stock >= LEAVES_PER_SAPLING:
		_rot += delta
		if _rot >= ROT_TIME:
			_rot = 0.0
			_stock -= LEAVES_PER_SAPLING
			var s := Sapling.new()
			get_parent().add_child(s)
			s.setup()
			s.global_position = global_position + Vector3(0, 1.0, 0)
			s.linear_velocity = Vector3(randf_range(-1.2, 1.2), 3.0, randf_range(-1.2, 1.2))
			Nature.burst(get_parent(), global_position + Vector3(0, 0.8, 0), Vector3.UP, Color("6aa846"), 16, 1.5, 0.05, 3.0, 1.0, 100.0)
			Sfx.play("reveal", 1.2, -4.0)
