extends Part
## A physical barrier across the belt. Open while powered (always open when unwired).

var _bar: AnimatableBody3D
var _y := 0.45

const CLOSED_Y := 0.45
const OPEN_Y := 1.05


func build() -> void:
	_deck(Color("ff4f4f"), 2.0)
	var post := Meshes.mat(Color("2b3348"), 0.0, 0.5)
	for sx in [-1, 1]:
		_box(Vector3(0.1, 1.4, 0.16), Vector3(0.46 * sx, 0.7, 0), post)
	_box(Vector3(1.02, 0.1, 0.18), Vector3(0, 1.42, 0), post)
	_bar = AnimatableBody3D.new()
	_bar.sync_to_physics = true
	_bar.collision_layer = 1 if not ghost else 0
	_bar.collision_mask = 0
	_bar.position = Vector3(0, CLOSED_Y, 0)
	_bar.set_meta("part", self)
	add_child(_bar)
	var m := MeshInstance3D.new()
	m.mesh = Meshes.box_mesh(Vector3(0.82, 0.5, 0.08))
	m.material_override = Meshes.mat(Color("ff4f4f"), 0.0, 0.5)
	_bar.add_child(m)
	var stripe := MeshInstance3D.new()
	stripe.mesh = Meshes.box_mesh(Vector3(0.84, 0.08, 0.09))
	stripe.material_override = Meshes.mat(Color("ffffff"), 0.0, 0.5)
	_bar.add_child(stripe)
	if not ghost:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.82, 0.5, 0.1)
		cs.shape = sh
		_bar.add_child(cs)
	else:
		_bar.position.y = OPEN_Y


func needs_tick() -> bool:
	return true


func apply_speed() -> void:
	_deck_speed(2.0 * Game.belt_mult())


func info_lines() -> Array:
	return ["Door is %s" % ("OPEN" if enabled() else "CLOSED")]


func tick(delta: float) -> void:
	var target := OPEN_Y if enabled() else CLOSED_Y
	_y = move_toward(_y, target, delta * 3.0)
	_bar.position.y = _y
