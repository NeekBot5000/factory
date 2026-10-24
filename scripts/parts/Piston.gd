extends Part
## Physically shoves items in the cell in front of it. Fires on a rising wire signal, or every interval unwired.

var _paddle: AnimatableBody3D
var _rod: MeshInstance3D
var _ext := 0.0
var _phase := -1.0
var _timer := 0.0

const REACH := 0.95


func build() -> void:
	var body_m := Meshes.mat(Color("3d5a80"), 0.0, 0.5)
	_box(Vector3(0.7, 0.42, 0.8), Vector3(0, 0.31, 0.06), body_m)
	_box(Vector3(0.74, 0.1, 0.84), Vector3(0, 0.05, 0.06), Meshes.mat(FRAME_COLOR))
	_box(Vector3(0.5, 0.06, 0.06), Vector3(0, 0.55, 0.06), Meshes.mat(Color("ffcf4a")))
	_rod = _anim(Meshes.cyl_mesh(0.05, 0.05, 1.0, 8), Meshes.metal_mat(Color("e0e4ea"), 0.15), Vector3(0, 0.36, -0.34), Vector3(90, 0, 0))
	_rod.scale = Vector3(1, 0.05, 1)
	_paddle = AnimatableBody3D.new()
	_paddle.sync_to_physics = true
	_paddle.collision_layer = 1 if not ghost else 0
	_paddle.collision_mask = 0
	_paddle.position = Vector3(0, 0.36, -0.42)
	_paddle.set_meta("part", self)
	add_child(_paddle)
	var pm := MeshInstance3D.new()
	pm.mesh = Meshes.box_mesh(Vector3(0.8, 0.28, 0.08))
	pm.material_override = Meshes.mat(Color("ffcf4a"), 0.0, 0.5)
	_paddle.add_child(pm)
	if not ghost:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.8, 0.28, 0.1)
		cs.shape = sh
		_paddle.add_child(cs)
		body = _make_body()
		_add_shape(body, Vector3(0.7, 0.5, 0.8), Vector3(0, 0.25, 0.06))


func on_placed() -> void:
	var n: Part = world.cells.get(cell + Defs.DIRS[rot])
	if n != null:
		n.on_neighbor_changed()


func needs_tick() -> bool:
	return true


func needs_anim() -> bool:
	return true


func cycle_time() -> float:
	return float(def.interval) / machine_mult()


func info_lines() -> Array:
	return ["Pushes the cell in front %s" % ("on each pulse" if wired_in else "every %.1fs" % cycle_time())]


func tick(delta: float) -> void:
	if _phase < 0.0:
		var fire := false
		if wired_in:
			fire = rising_edge()
		else:
			_timer += delta / cycle_time()
			fire = _timer >= 1.0
		if fire:
			_timer = 0.0
			_phase = 0.0
			FX.play("piston", randf_range(0.9, 1.1), 0.05)
	else:
		_phase += delta / 0.5
		if _phase < 0.2:
			_ext = _phase / 0.2
		elif _phase < 0.35:
			_ext = 1.0
		else:
			_ext = 1.0 - (_phase - 0.35) / 0.65
		if _phase >= 1.0:
			_phase = -1.0
			_ext = 0.0
	_paddle.position.z = -0.42 - _ext * REACH


func animate(_delta: float) -> void:
	var len := 0.05 + _ext * REACH
	_rod.scale = Vector3(1, len, 1)
	_rod.position.z = -0.34 - len * 0.5 + 0.04
