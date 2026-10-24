extends Part
## Cross-cut saw: the blade carriage drops every interval (or on a wire pulse) and cuts every item under the
## blade plane exactly where it crosses that plane.

var _timer := 0.0
var _phase := -1.0
var _cut_done := false
var _carriage: Node3D
var _blade: MeshInstance3D
var _area: Area3D

const REST_Y := 0.88
const CUT_Y := 0.44


func build() -> void:
	_deck(Color("ffcf4a"), float(def.speed))
	var frame := Meshes.mat(Color("d9a400"), 0.0, 0.5)
	for sx in [-1, 1]:
		_box(Vector3(0.1, 1.3, 0.12), Vector3(0.46 * sx, 0.65, 0.0), frame)
		_box(Vector3(0.16, 0.06, 0.3), Vector3(0.46 * sx, 0.03, 0.0), Meshes.mat(FRAME_COLOR))
	_box(Vector3(1.02, 0.12, 0.16), Vector3(0, 1.32, 0), frame)
	_box(Vector3(0.12, 0.3, 0.12), Vector3(0, 1.15, 0), Meshes.metal_mat(STEEL))
	# blade slot in the deck
	_box(Vector3(0.9, 0.051, 0.04), Vector3(0, 0.176, 0), Meshes.mat(Color("101218")))
	_carriage = _pivot(Vector3(0, REST_Y, 0))
	_anim(Meshes.box_mesh(Vector3(0.7, 0.08, 0.12)), Meshes.metal_mat(STEEL), Vector3(0, 0.34, 0), Vector3.ZERO, _carriage)
	_anim(Meshes.box_mesh(Vector3(0.22, 0.2, 0.2)), Meshes.mat(Color("d9a400"), 0.0, 0.5), Vector3(0.2, 0.32, 0.0), Vector3.ZERO, _carriage)
	_anim(Meshes.box_mesh(Vector3(0.72, 0.12, 0.08)), Meshes.mat(Color("e8b400"), 0.0, 0.5), Vector3(0, 0.26, 0.0), Vector3.ZERO, _carriage)
	_blade = _anim(Meshes.blade_mesh(0.3), Meshes.metal_mat(Color("dfe4ec"), 0.15), Vector3.ZERO, Vector3.ZERO, _carriage)
	if not ghost:
		_area = _make_area(Vector3(0.9, 0.5, 0.05), Vector3(0, 0.45, 0))


func needs_tick() -> bool:
	return true


func needs_anim() -> bool:
	return true


func apply_speed() -> void:
	_deck_speed(belt_speed())


func cycle_time() -> float:
	return float(def.interval) / machine_mult()


func info_lines() -> Array:
	return ["Chops every %.1fs%s" % [cycle_time(), " (on pulse)" if wired_in else ""], "Cuts across the belt, where the blade lands"]


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
			_cut_done = false
		return
	_phase += delta / 0.38
	if _phase >= 0.35 and not _cut_done:
		_cut_done = true
		var n := 0
		for it in _items_in(_area):
			var kind_fx := "sawdust" if it.cat() == "wood" else "sparks"
			if world.cut_item(it, local_to_world(Vector3(0, 0.4, 0)), dir_vec()).size() > 1:
				n += 1
				FX.burst(kind_fx, local_to_world(Vector3(0, 0.35, 0)), dir_vec())
		if n > 0:
			FX.play("saw", randf_range(0.9, 1.1), 0.05)
	if _phase >= 1.0:
		_phase = -1.0


func animate(delta: float) -> void:
	_blade.rotation.z += delta * 30.0
	var y := REST_Y
	if _phase >= 0.0:
		var p := _phase
		if p < 0.35:
			y = lerpf(REST_Y, CUT_Y, p / 0.35)
		else:
			y = lerpf(CUT_Y, REST_Y, (p - 0.35) / 0.65)
	_carriage.position.y = y
