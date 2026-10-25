class_name Basketball
extends RigidBody3D
## A bouncy ball wound from leaves. Spin round and let go of it to shoot; drop it through a hoop to score.

const R := 0.12


func setup(colors: Array, size: float = 1.0) -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	mass = 0.6 * size * size
	continuous_cd = true
	angular_damp = 0.3
	linear_damp = 0.05
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.75
	pm.friction = 0.6
	physics_material_override = pm
	var col: Color = colors[0] if colors.size() > 0 else Color("6aa846")
	var vis := Node3D.new()
	vis.scale = Vector3.ONE * size
	add_child(vis)
	LowPoly.mesh_instance(vis, LowPoly.blob(R, 0.06, 7), LowPoly.mat(col, 0.8), Vector3.ZERO)
	# seams of darker leaf strips
	var seam := LowPoly.mat(col.darkened(0.45), 0.9)
	LowPoly.mesh_instance(vis, LowPoly.cyl(R * 1.01, R * 1.01, 0.012, 12), seam, Vector3.ZERO)
	LowPoly.mesh_instance(vis, LowPoly.cyl(R * 1.01, R * 1.01, 0.012, 12), seam, Vector3.ZERO, Vector3(90, 0, 0))
	LowPoly.mesh_instance(vis, LowPoly.cyl(R * 1.01, R * 1.01, 0.012, 12), seam, Vector3.ZERO, Vector3(0, 0, 90))
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = R * size
	cs.shape = sh
	add_child(cs)
	add_to_group("grabbable")
	add_to_group("balls")
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(func(_b):
		if linear_velocity.length() > 2.0:
			Sfx.play("thud", 1.7, -10.0 + minf(linear_velocity.length(), 8.0)))
