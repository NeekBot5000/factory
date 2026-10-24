class_name Chip
extends RigidBody3D
## A physical piece of bark (outer or inner layer) knocked off a tree. Can be picked up and carried.

var layer := 0
var kind := "oak"
var size := Vector3.ONE * 0.1


func setup(data: Dictionary, p_kind: String) -> void:
	layer = data.layer
	kind = p_kind
	size = data.size
	collision_layer = 2
	collision_mask = 1 | 2
	mass = clampf(size.x * size.y * size.z * 700.0, 0.03, 2.0)
	linear_damp = 0.2
	angular_damp = 0.8
	continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.15
	physics_material_override = pm
	var mi := MeshInstance3D.new()
	mi.mesh = data.mesh
	mi.material_override = LowPoly.vcol_mat(0.95)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size.max(Vector3(0.02, 0.02, 0.02))
	cs.shape = sh
	add_child(cs)
	add_to_group("grabbable")
	add_to_group("chips")


func display_name() -> String:
	var k := kind.capitalize()
	return "%s bark" % k if layer == 0 else "%s inner bark" % k
