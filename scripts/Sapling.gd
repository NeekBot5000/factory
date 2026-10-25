class_name Sapling
extends RigidBody3D
## A little tree from the compost pile. Put it down on open ground and leave it: it roots, grows, and becomes a
## full-size tree you can strip and saw like any other.

const GROW_TIME := 45.0

var kind := "oak"
var _rest := 0.0
var _rooted := false
var _grow := 0.0
var _sprout: Node3D


func setup(p_kind := "") -> void:
	kind = p_kind if p_kind != "" else ["oak", "birch", "pine"][randi() % 3]
	collision_layer = 2
	collision_mask = 1 | 2
	mass = 0.4
	angular_damp = 2.0
	_sprout = Node3D.new()
	add_child(_sprout)
	_build_sprout()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.2, 0.35, 0.2)
	cs.shape = sh
	cs.position = Vector3(0, 0.17, 0)
	add_child(cs)
	add_to_group("grabbable")
	add_to_group("saplings")


func _build_sprout() -> void:
	var stem := LowPoly.mat(Color("6b4a32"), 0.9)
	var leaf := LowPoly.mat(Color("6aa846") if kind != "pine" else Color("2f6b3a"), 0.9)
	LowPoly.mesh_instance(_sprout, LowPoly.cyl(0.012, 0.02, 0.3, 5), stem, Vector3(0, 0.15, 0))
	LowPoly.mesh_instance(_sprout, LowPoly.blob(0.09, 0.3, 3), leaf, Vector3(0.04, 0.3, 0))
	LowPoly.mesh_instance(_sprout, LowPoly.blob(0.07, 0.3, 5), leaf, Vector3(-0.04, 0.26, 0.03))
	LowPoly.mesh_instance(_sprout, LowPoly.cyl(0.07, 0.05, 0.06, 6), LowPoly.mat(Color("5a3d28"), 1.0), Vector3(0, 0.03, 0))


func hint_text() -> String:
	return "[E] grab" if not _rooted else "%d%%" % int(_grow / GROW_TIME * 100.0)


func _physics_process(delta: float) -> void:
	if not _rooted:
		var main := get_parent()
		var held: Node = main.player.held if "player" in main else null
		if held != self and linear_velocity.length() < 0.15 and _on_ground():
			_rest += delta
			if _rest > 1.5:
				_root()
		else:
			_rest = 0.0
		return
	_grow += delta
	var k := clampf(_grow / GROW_TIME, 0.0, 1.0)
	_sprout.scale = Vector3.ONE * lerpf(1.0, 6.0, k)
	if k >= 1.0:
		_become_tree()


func _on_ground() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 0.3, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider is Terrain


func _root() -> void:
	_rooted = true
	freeze = true
	remove_from_group("grabbable")
	global_basis = Basis()
	Nature.burst(get_parent(), global_position, Vector3.UP, Color("7a5a3a"), 10, 1.0, 0.03, 6.0, 0.6, 80.0)
	Sfx.play("pickup", 0.6)


func _become_tree() -> void:
	var main := get_parent()
	var rng := RandomNumberGenerator.new()
	var grow_seed := randi()
	rng.seed = grow_seed
	var tree := ForestTree.new()
	tree.set_meta("grown", {"seed": grow_seed, "kind": kind})
	main.add_child(tree)
	tree.position = global_position - Vector3(0, 0.05, 0)
	tree.rotation.y = rng.randf() * TAU
	tree.setup(rng, kind)
	if "trees" in main:
		main.trees.append(tree)
	Nature.burst(main, global_position + Vector3.UP * 2.0, Vector3.UP, Color("6aa846"), 40, 3.0, 0.1, 3.0, 1.4, 160.0)
	Sfx.play("reveal")
	queue_free()
