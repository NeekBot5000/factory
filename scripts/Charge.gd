class_name Charge
extends Machine
## A stick of dynamite stuck on something. Wire it (wire spool) to a switch that has power: the moment power
## reaches it, it goes off. Rocks close by burst into all their chunks and loose things get thrown about.

const BLAST_R := 1.9
var _fuse := -1.0


func plant(at: Vector3, normal: Vector3) -> void:
	collision_layer = 1
	collision_mask = 0
	set_uid(Machine.take_uid())
	activate(1.0)
	add_to_group("charges")
	var up := normal.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	global_transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), at + up * 0.03)
	var red := LowPoly.mat(Color("c0392b"), 0.6)
	for k in 3:
		LowPoly.mesh_instance(self, LowPoly.cyl(0.03, 0.03, 0.22, 8), red, Vector3((k - 1) * 0.06, 0.03, 0), Vector3(90, 0, 0))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.19, 0.065, 0.03)), LowPoly.mat(Color("2b2d33"), 0.8), Vector3(0, 0.032, 0.05))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.19, 0.065, 0.03)), LowPoly.mat(Color("2b2d33"), 0.8), Vector3(0, 0.032, -0.05))
	LowPoly.mesh_instance(self, LowPoly.cyl(0.004, 0.004, 0.12, 4), LowPoly.mat(Color("d9c08a"), 0.9), Vector3(0, 0.1, -0.1), Vector3(30, 0, 0))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.2, 0.08, 0.24)
	cs.shape = sh
	cs.position = Vector3(0, 0.03, 0)
	add_child(cs)
	Sfx.play_at("clink", at, 0.7, -6.0)


func terminal() -> Vector3:
	return Vector3(0, 0.15, -0.14)


func display_name() -> String:
	return "Dynamite"


func hint_text() -> String:
	return "Dynamite  ·  wire it to a switch with power to set it off"


func _power_on() -> void:
	if _fuse < 0.0:
		_fuse = 0.35         # a short hiss of fuse, then boom
		Sfx.play_at("hiss", global_position, 1.6, 0.0)


func _physics_process(delta: float) -> void:
	if _fuse < 0.0:
		return
	var sparks := global_transform * Vector3(0, 0.16, -0.14)
	Nature.burst(get_parent(), sparks, Vector3.UP, Color("ffd36a"), 3, 1.5, 0.012, 3.0, 0.25, 70.0, 3.0)
	_fuse -= delta
	if _fuse <= 0.0:
		explode()


func explode() -> void:
	if is_queued_for_deletion():
		return
	var world := get_parent()
	var at := global_position
	remove_from_group("machines")
	remove_from_group("charges")
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = BLAST_R
	q.shape = sph
	q.transform = Transform3D(Basis(), at)
	q.collision_mask = 1 | 2
	q.exclude = [get_rid()]
	var hit_rocks := []
	for r in get_world_3d().direct_space_state.intersect_shape(q, 64):
		var c: Object = r.collider
		if c is Rock and not hit_rocks.has(c):
			hit_rocks.append(c)
		elif c is Charge and c != self:
			(c as Charge)._fuse = 0.12 if (c as Charge)._fuse < 0.0 else (c as Charge)._fuse      # sets off its neighbours
		elif c is RigidBody3D and not (c as RigidBody3D).freeze:
			var b := c as RigidBody3D
			var d := b.global_position - at
			var push := (d.normalized() + Vector3.UP * 0.6).normalized() * clampf(9.0 - d.length() * 3.0, 2.0, 9.0)
			b.sleeping = false
			b.apply_central_impulse(push * b.mass)
	for rk in hit_rocks:
		(rk as Rock).shatter(2, at)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null:
		var dist := p.global_position.distance_to(at)
		p.blast_shake(clampf(1.2 - dist / 14.0, 0.0, 1.0))
		if dist < 3.5:
			p.take_damage(lerpf(45.0, 10.0, dist / 3.5))
	Nature.burst(world, at, Vector3.UP, Color("ffb347"), 50, 7.0, 0.05, 2.0, 0.45, 180.0, 4.0)
	Nature.burst(world, at, Vector3.UP, Color("4a4540"), 40, 2.5, 0.2, -0.8, 2.2, 140.0)
	Nature.burst(world, at, Vector3.UP, Color("8a8780"), 30, 6.0, 0.05, 9.0, 1.0, 160.0)
	var light := OmniLight3D.new()
	light.light_color = Color("ffcf8a")
	light.light_energy = 6.0
	light.omni_range = 12.0
	world.add_child(light)
	light.global_position = at + Vector3.UP * 0.5
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.4)
	tw.tween_callback(light.queue_free)
	Sfx.play_at("boom", at, 1.0, 8.0)
	world.call("bend_grass", at, 3.0)
	queue_free()
