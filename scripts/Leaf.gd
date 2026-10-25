class_name Leaf
extends RigidBody3D
## A chunky low-poly clump of leaves snipped off a crown or bush with the shears. Cheap, but there are lots.

const VALUE := 0.05

var color := Color("4f9a3c")
var value := VALUE


func setup(p_color: Color, size: float) -> void:
	color = p_color.lerp(p_color.lightened(0.15), randf())
	collision_layer = 2
	collision_mask = 1 | 2
	mass = clampf(size * 0.6, 0.05, 0.4)
	linear_damp = 1.2          # leafy: drifts a little as it falls
	angular_damp = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = LowPoly.blob(size, 0.45, randi() % 60)
	mi.material_override = LowPoly.mat(color, 1.0)
	mi.scale = Vector3(1.0, randf_range(0.55, 0.85), randf_range(0.8, 1.1))
	add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(size * 1.6, size * 1.1, size * 1.6)
	cs.shape = sh
	add_child(cs)
	add_to_group("grabbable")
	add_to_group("leaves")
