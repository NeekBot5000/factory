extends Part
## Rip saw: spinning blade(s) parallel to the belt. Splits items lengthwise exactly where the blade meets them.
## The blade offset (sideways position) is configurable; the gang saw has 4 blades 0.08 apart.

const OFFSETS := [-0.2, -0.15, -0.1, -0.075, -0.05, -0.025, 0.0, 0.025, 0.05, 0.075, 0.1, 0.15, 0.2]

var _blades: Array[MeshInstance3D] = []
var _areas: Array[Area3D] = []
var _hood: Node3D


func init_config() -> void:
	config = {"offset": 0.0}


func blade_offsets() -> Array:
	var o: float = float(config.offset)
	if int(def.blades) <= 1:
		return [o]
	var out := []
	for i in int(def.blades):
		out.append(o + (i - (int(def.blades) - 1) * 0.5) * 0.08)
	return out


func build() -> void:
	_deck(Color("ff8a3d"), float(def.speed))
	var housing := Meshes.mat(Color("e0652a"), 0.0, 0.5)
	for sz in [-1, 1]:
		_box(Vector3(1.0, 0.7, 0.08), Vector3(0, 0.55, 0.44 * sz), housing)
	_box(Vector3(0.24, 0.7, 0.24), Vector3(0.38, 0.55, 0.0), Meshes.mat(Color("bf4f1c"), 0.0, 0.5))
	_box(Vector3(1.0, 0.08, 0.96), Vector3(0, 0.92, 0), housing)
	_box(Vector3(0.14, 0.14, 0.4), Vector3(0.38, 1.0, 0), Meshes.metal_mat(STEEL))
	_hood = _pivot(Vector3.ZERO)
	for o in blade_offsets():
		var b := _anim(Meshes.blade_mesh(0.28), Meshes.metal_mat(Color("dfe4ec"), 0.15), Vector3(o, 0.34, 0), Vector3(0, 90, 0), _hood)
		_blades.append(b)
		if not ghost:
			var key := _blades.size() - 1
			_areas.append(_make_area(Vector3(0.03, 0.45, 0.8), Vector3(o, 0.42, 0), func(body_hit: Node3D): _on_enter(body_hit, key)))


func needs_anim() -> bool:
	return true


func apply_speed() -> void:
	_deck_speed(belt_speed() if enabled() else 0.0)


func config_options() -> Array:
	if int(def.blades) > 1:
		return [{"key": "offset", "label": "Blade set offset", "values": [-0.04, 0.0, 0.04]}]
	return [{"key": "offset", "label": "Blade offset (sideways)", "values": OFFSETS}]


func interact() -> bool:
	return false


func on_config_changed() -> void:
	var offs := blade_offsets()
	for i in _blades.size():
		_blades[i].position.x = offs[i]
		if i < _areas.size():
			(_areas[i].get_child(0) as CollisionShape3D).position.x = offs[i]


func info_lines() -> Array:
	var s := ""
	for o in blade_offsets():
		s += "%+.3f " % float(o)
	return ["Blade offset: %s(click to adjust)" % s, "Splits items lengthwise where the blade hits"]


func _on_enter(b: Node3D, key: int) -> void:
	var it := b as Item
	if it == null or not it.active or not enabled():
		return
	var o: float = blade_offsets()[key]
	var point := local_to_world(Vector3(o, 0.4, 0))
	var normal := right_vec()
	var mk := uid * 8 + key
	world.queue_job(func():
		if is_instance_valid(it) and it.active and is_instance_valid(self) and it.mark(mk):
			if world.cut_item(it, point, normal).size() > 1:
				FX.play("saw", randf_range(1.0, 1.2), 0.05))


func animate(delta: float) -> void:
	if not enabled():
		return
	for b in _blades:
		b.rotate_object_local(Vector3(0, 0, 1), delta * 30.0)
