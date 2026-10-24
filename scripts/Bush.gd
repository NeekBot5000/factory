class_name Bush
extends StaticBody3D
## A leafy bush. Sways in the wind, and shakes and sheds leaves when you hit it or push through it.
## Lives on its own physics layer (8) so tools and the look ray find it, but nothing collides with it.

const LAYER := 8

var _leaves: Node3D
var _shake := 0.0
var _shake_dir := Vector3.RIGHT
var _t := 0.0
var _color := Color("3f7f33")
var _player_inside := false
var _radius := 0.6


func build(rng: RandomNumberGenerator, size: float) -> void:
	collision_layer = LAYER
	collision_mask = 0
	_radius = 0.6 * size
	_color = Color("3f7f33").lerp(Color("5a9a3a"), rng.randf())
	_leaves = Node3D.new()
	add_child(_leaves)
	var m := Nature.wind_mat(_color, 0.05, 1.0, -0.4)
	var m2 := Nature.wind_mat(_color.lightened(0.12), 0.06, 1.0, -0.4)
	LowPoly.mesh_instance(_leaves, LowPoly.blob(0.6, 0.3, rng.randi() % 40), m, Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1.2, 0.8, 1.2) * size)
	for k in 2:
		var off := Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.35, 0.55), rng.randf_range(-0.35, 0.35)) * size
		LowPoly.mesh_instance(_leaves, LowPoly.blob(0.35, 0.3, rng.randi() % 40), m2 if k == 0 else m, off, Vector3.ZERO, Vector3.ONE * size)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = _radius
	cs.shape = sh
	cs.position.y = 0.3 * size
	add_child(cs)
	add_to_group("bushes")


func hint_text() -> String:
	return "Bush"


## Called by the player's tools.
func on_hit(pos: Vector3, normal: Vector3, _tool: String) -> void:
	shake(1.0, global_position - pos)
	Sfx.play("rustle", randf_range(0.9, 1.15))
	Nature.burst(get_parent(), pos, normal + Vector3.UP * 0.6, _color.lightened(0.15), 18, 2.4, 0.065, 3.0, 1.3, 70.0)


func shake(amount: float, dir: Vector3) -> void:
	dir.y = 0.0
	_shake_dir = dir.normalized() if dir.length() > 0.01 else Vector3.RIGHT
	_shake = maxf(_shake, amount)
	set_process(true)


func _ready() -> void:
	set_process(false)


func _physics_process(_delta: float) -> void:
	# rustle when the player walks through (bushes have no collision for the player)
	var p: Node3D = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var d := p.global_position - global_position
	d.y = 0.0
	var inside := d.length() < _radius + 0.25
	if inside and not _player_inside:
		shake(0.6, -d)
		Sfx.play("rustle", randf_range(1.0, 1.25), -8.0)
		Nature.burst(get_parent(), global_position + Vector3.UP * 0.5, Vector3.UP, _color.lightened(0.1), 5, 1.2, 0.04, 2.5, 1.0, 80.0)
	_player_inside = inside


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 1.6)
	# damped wobble: tilt away from the hit, springing back and forth
	var a := sin(_t * 22.0) * _shake * 0.28
	var axis := Vector3.UP.cross(_shake_dir).normalized()
	_leaves.basis = Basis(axis, a) if axis.length() > 0.5 else Basis()
	_leaves.scale = Vector3.ONE * (1.0 + sin(_t * 30.0) * _shake * 0.05)
	if _shake <= 0.0:
		_leaves.basis = Basis()
		set_process(false)
