extends Part
## Tree farms grow a tree that topples a real log forward; drills drop ore boulders / geodes from a hopper.

var _t := 0.0
var _fall := -1.0
var _tree: Node3D
var _bit: Node3D
var _piston: Node3D


func is_tree() -> bool:
	return String(def.src) == "tree"


func build() -> void:
	if is_tree():
		_build_tree()
	else:
		_build_drill()


func _build_tree() -> void:
	var plank := Meshes.mat(Color("9a6a3e"))
	var plank2 := Meshes.mat(Color("7d5431"))
	_box(Vector3(0.92, 0.26, 0.92), Vector3(0, 0.13, 0), plank)
	for i in 3:
		_box(Vector3(0.94, 0.03, 0.94), Vector3(0, 0.05 + i * 0.08, 0), plank2)
	_box(Vector3(0.8, 0.04, 0.8), Vector3(0, 0.27, 0), Meshes.mat(Color("4a3324")))
	# little marker showing which way the tree falls
	_box(Vector3(0.12, 0.05, 0.22), Vector3(0, 0.29, -0.36), Meshes.mat(Color("ffcf4a"), 0.5))
	var mdef: Dictionary = Defs.MATERIALS[def.mat]
	_tree = _pivot(Vector3(0, 0.28, 0.1))
	var bark: Color = mdef.bark
	_anim(Meshes.cyl_mesh(0.08, 0.11, 1.0, 6), Meshes.mat(bark), Vector3(0, 0.5, 0), Vector3.ZERO, _tree)
	match String(def.mat):
		"frostpine":
			for k in 3:
				_anim(Meshes.cyl_mesh(0.0, 0.42 - k * 0.1, 0.5, 6), Meshes.mat(Color("dfeeff").darkened(k * 0.06)), Vector3(0, 0.9 + k * 0.32, 0), Vector3.ZERO, _tree)
		"mahogany":
			_anim(Meshes.icosa(0.5, 0.15, 3), Meshes.mat(Color("2a7a3a")), Vector3(0, 1.25, 0), Vector3.ZERO, _tree)
			_anim(Meshes.icosa(0.32, 0.15, 4), Meshes.mat(Color("3a8f45")), Vector3(0.2, 1.55, 0.1), Vector3.ZERO, _tree)
		_:
			_anim(Meshes.icosa(0.42, 0.18, 5), Meshes.mat(Color("4caa3e")), Vector3(0, 1.2, 0), Vector3.ZERO, _tree)
			_anim(Meshes.icosa(0.28, 0.18, 6), Meshes.mat(Color("5cbf4a")), Vector3(-0.12, 1.5, 0.05), Vector3.ZERO, _tree)
	_tree.scale = Vector3.ONE * (0.9 if ghost else 0.25)
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(0.92, 0.28, 0.92), Vector3(0, 0.14, 0))


func _build_drill() -> void:
	var mdef: Dictionary = Defs.MATERIALS[def.mat]
	var c: Color = mdef.color
	var frame := Meshes.metal_mat(Color("6b7387"), 0.5)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(0.07, 1.5, 0.07), Vector3(0.4 * sx, 0.75, 0.4 * sz), frame)
	_box(Vector3(0.9, 0.06, 0.06), Vector3(0, 1.45, 0.4), frame)
	_box(Vector3(0.9, 0.06, 0.06), Vector3(0, 1.45, -0.4), frame)
	_box(Vector3(0.06, 0.06, 0.9), Vector3(0.4, 1.45, 0), frame)
	_box(Vector3(0.06, 0.06, 0.9), Vector3(-0.4, 1.45, 0), frame)
	# hopper
	_cyl(0.42, 0.45, Vector3(0, 0.72, 0), Meshes.mat(Color("3b4256").lerp(c, 0.3), 0.0, 0.6), Vector3.ZERO, 8, 0.14)
	_cyl(0.43, 0.08, Vector3(0, 0.95, 0), Meshes.mat(c, 0.3, 0.5), Vector3.ZERO, 8)
	_cyl(0.14, 0.12, Vector3(0, 0.44, 0), Meshes.metal_mat(STEEL), Vector3.ZERO, 8)
	# motor housing on top
	_box(Vector3(0.36, 0.22, 0.36), Vector3(0, 1.6, 0), Meshes.mat(c.darkened(0.35), 0.0, 0.5))
	_box(Vector3(0.12, 0.12, 0.3), Vector3(0.24, 1.6, 0), Meshes.metal_mat(STEEL))
	_piston = _pivot(Vector3(0, 1.0, 0))
	_anim(Meshes.cyl_mesh(0.05, 0.05, 0.5, 6), Meshes.metal_mat(STEEL, 0.2), Vector3(0, 0.25, 0), Vector3.ZERO, _piston)
	_bit = _anim(Meshes.cyl_mesh(0.12, 0.0, 0.3, 6), Meshes.metal_mat(Color("c8ccd6"), 0.25), Vector3(0, -0.05, 0), Vector3.ZERO, _piston)
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(0.84, 0.62, 0.84), Vector3(0, 0.69, 0))


func needs_tick() -> bool:
	return true


func needs_anim() -> bool:
	return true


func interval() -> float:
	return float(def.interval) / (Game.src_mult() * level_mult())


func info_lines() -> Array:
	var m: String = Defs.MATERIALS[def.mat].name
	var l := ["Produces %s every %.1fs" % [("a %s log" % m) if is_tree() else ("%s ore" % m), interval()]]
	l.append("Progress %d%%%s" % [int(_t * 100.0), "" if enabled() else "  (OFF)"])
	return l


func tick(delta: float) -> void:
	if _fall >= 0.0:
		_fall += delta / 0.45
		if _fall >= 1.0:
			_fall = -1.0
			_spawn_log()
			_t = 0.0
		return
	if not enabled():
		return
	_t = minf(1.0, _t + delta / interval())
	if _t >= 1.0 and world.can_spawn():
		if is_tree():
			_fall = 0.0
		else:
			_spawn_boulder()
			_t = 0.0


func _spawn_log() -> void:
	var rich := 1.0 + 0.03 * Game.upg("rich_veins")
	var length := randf_range(1.2, 1.8) * minf(rich, 1.6)
	var dia := randf_range(0.26, 0.34) * minf(rich, 1.3)
	var d := dir_vec()
	var front := global_position + d * 1.0
	var pos := front + d * (length * 0.5 - 0.45) + Vector3(0, 0.22 + dia * 0.5 + 0.06, 0)
	var basis := Basis.looking_at(d, Vector3.UP)
	world.spawn_item({"mat": def.mat, "shape": "cyl", "size": Vector3(dia, dia, length)}, Transform3D(basis, pos), d * 0.5, true)
	FX.play("thud", randf_range(0.9, 1.1), 0.1)


func _spawn_boulder() -> void:
	var pur := clampf(randf_range(0.3, 0.5) + 0.02 * Game.upg("rich_veins"), 0.05, 0.95)
	var s := Vector3(randf_range(0.36, 0.5), randf_range(0.32, 0.46), randf_range(0.36, 0.5))
	if String(def.mat) == "sand":
		pur = clampf(0.85 + 0.005 * Game.upg("rich_veins"), 0.0, 0.98)
		s = Vector3(randf_range(0.17, 0.23), randf_range(0.12, 0.17), randf_range(0.17, 0.23))
	var y := 0.06
	if not world.cells.has(cell + Vector3i(0, -1, 0)) and cell.y == 0:
		y = s.y * 0.5 + 0.03
	var xf := Transform3D(Basis.from_euler(Vector3(0, randf() * TAU, 0)), global_position + Vector3(randf_range(-0.04, 0.04), y, randf_range(-0.04, 0.04)))
	world.spawn_item({"mat": def.mat, "shape": "chunk", "size": s, "purity": pur}, xf, Vector3.ZERO, true)


func animate(delta: float) -> void:
	if is_tree():
		if _fall >= 0.0:
			_tree.rotation.x = -_fall * _fall * PI * 0.5
		else:
			_tree.rotation.x = 0.0
			var s := 0.25 + 0.75 * _t
			_tree.scale = _tree.scale.lerp(Vector3.ONE * s, minf(1.0, delta * 6.0))
	else:
		if enabled():
			_bit.rotation.y += delta * 14.0
			_piston.position.y = 1.0 - 0.12 * absf(sin(Time.get_ticks_msec() * 0.004))
