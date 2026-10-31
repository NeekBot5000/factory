class_name Planter
extends Machine
## Drop saplings into its hopper (by hand or off a belt) and power it: it plants them in a row in front of it, a
## couple of metres apart, wherever there's open ground.

const EVERY := 2.0

var _cd := 0.0


func activate(p_size: float) -> void:
	super(p_size)
	add_lamp(Vector3(0.4, 0.3, 0.4))


func terminal() -> Vector3:
	return Vector3(0.4, 0.45, 0.4) * size


func hint_text() -> String:
	return "Planter  ·  drop saplings in the hopper and power it: they're planted in a row in front"


func _physics_process(delta: float) -> void:
	_cd -= delta
	if not powered or _cd > 0.0:
		return
	for b in bodies_in(Vector3(0, 0.95, 0), Vector3(0.7, 0.5, 0.7)):
		if b is Sapling and not (b as Sapling).is_rooted():
			var spot := _free_spot()
			if spot == Vector3.INF:
				return
			_cd = EVERY
			var sp := b as Sapling
			sp.linear_velocity = Vector3.ZERO
			sp.global_transform = Transform3D(Basis(), spot)
			sp.call("_root")
			Nature.burst(get_parent(), spot, Vector3.UP, Color("7a5a3a"), 12, 1.4, 0.03, 6.0, 0.6)
			Sfx.play_at("thud", global_position, 1.3, -4.0)
			return


## The nearest open patch of ground in front (no tree or sapling within 1.8 m), up to 10 m out.
func _free_spot() -> Vector3:
	var world := get_parent()
	var space := get_world_3d().direct_space_state
	for k in 5:
		var at := global_transform * Vector3(0, 0, -2.0 - k * 2.0)
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 4.0, 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or not (hit.collider is Terrain):
			continue
		var p: Vector3 = hit.position
		var clear := true
		for t in world.get_tree().get_nodes_in_group("trees"):
			if Vector2(t.global_position.x - p.x, t.global_position.z - p.z).length() < 1.8:
				clear = false
				break
		if clear:
			for s in world.get_tree().get_nodes_in_group("saplings"):
				if (s as Sapling).is_rooted() and (s as Node3D).global_position.distance_to(p) < 1.8:
					clear = false
					break
		if clear:
			return p + Vector3.UP * 0.02
	return Vector3.INF
