extends Part
## Splits items round-robin between connected outputs (left/forward/right).
## Wired: becomes a diverter - powered sends items to the configured side, unpowered forward.

var split_i := 0
var _inside := {}
var _arrow: MeshInstance3D


func init_config() -> void:
	config = {"side": 1}


func build() -> void:
	var tint: Color = def.tint
	_box(Vector3(1.0, 0.14, 1.0), Vector3(0, 0.07, 0), Meshes.mat(DECK_COLOR))
	_box(Vector3(0.9, 0.05, 0.9), Vector3(0, 0.175, 0), Meshes.mat(tint.darkened(0.5), 0.0, 0.5))
	# rotating turntable disc with an arrow showing the current route
	var disc := _pivot(Vector3(0, 0.2, 0))
	_anim(Meshes.cyl_mesh(0.36, 0.36, 0.03, 12), Meshes.mat(tint.darkened(0.25), 0.0, 0.5), Vector3.ZERO, Vector3.ZERO, disc)
	_arrow = _anim(Meshes.box_mesh(Vector3(0.1, 0.03, 0.42)), Meshes.mat(tint, 0.8, 0.4), Vector3(0, 0.02, -0.08), Vector3.ZERO, disc)
	_arrow.set_meta("disc", disc)
	for sx in [-1, 1]:
		_box(Vector3(0.1, 0.18, 0.1), Vector3(0.44 * sx, 0.23, 0.44), Meshes.mat(FRAME_COLOR))
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(1.0, 0.2, 1.0), Vector3(0, 0.1, 0))
		(body.physics_material_override as PhysicsMaterial).friction = 0.15
		_make_area(Vector3(0.9, 0.5, 0.9), Vector3(0, 0.4, 0), _on_enter, _on_exit)


func needs_tick() -> bool:
	return true


func needs_anim() -> bool:
	return true


func config_options() -> Array:
	return [{"key": "side", "label": "Diverter side (when powered)", "values": [-1, 1], "names": ["Left", "Right"]}]


func info_lines() -> Array:
	if wired_in:
		return ["Diverter: %s" % ("to the " + ("left" if int(config.side) < 0 else "right") if sig_in else "forward")]
	return ["Splitting round-robin"]


func _outputs() -> Array[int]:
	var outs: Array[int] = []
	for off in [-1, 0, 1]:
		var d: Vector3i = Defs.DIRS[posmod(rot + off, 4)]
		var n: Part = world.cells.get(cell + d)
		if n != null and n.kind() not in ["source", "block", "logic", "piston"]:
			outs.append(off)
	if outs.is_empty():
		outs.append(0)
	return outs


func _on_enter(b: Node3D) -> void:
	var it := b as Item
	if it == null or not it.active:
		return
	var nxt := 0
	if wired_in:
		nxt = int(config.side) if sig_in else 0
	else:
		var outs := _outputs()
		nxt = outs[(outs.find(split_i) + 1) % outs.size()] if outs.has(split_i) else outs[0]
	split_i = nxt
	_inside[it] = Vector3(Defs.DIRS[posmod(rot + nxt, 4)])


func _on_exit(b: Node3D) -> void:
	_inside.erase(b)


func tick(_delta: float) -> void:
	var spd := belt_speed()
	for it in _inside.keys():
		if not is_instance_valid(it) or not (it as Item).active:
			_inside.erase(it)
			continue
		var dv: Vector3 = _inside[it]
		var perp := Vector3(dv.z, 0, dv.x)
		var err := (global_position - (it as Item).global_position).dot(perp)
		var target: Vector3 = dv * spd + perp * clampf(err * 8.0, -2.5, 2.5)
		var v: Vector3 = (it as Item).linear_velocity
		(it as Item).linear_velocity = Vector3(lerpf(v.x, target.x, 0.5), v.y, lerpf(v.z, target.z, 0.5))


func animate(delta: float) -> void:
	var disc: Node3D = _arrow.get_meta("disc")
	var target := -90.0 * split_i
	disc.rotation_degrees.y = lerpf(disc.rotation_degrees.y, target, minf(1.0, delta * 12.0))
