extends Part
## Hydraulic press: the hammer slams down every interval (or on a pulse). Metal under it is flattened
## (height x0.5, width & length x1.41 - same volume): ingot -> plate -> sheet. Gems shatter, ore breaks.

var _timer := 0.0
var _phase := -1.0
var _done := false
var _ram: Node3D
var _area: Area3D

const REST_Y := 0.95
const HIT_Y := 0.0


func build() -> void:
	_deck(Color("9fb4c8"), float(def.speed))
	var frame := Meshes.mat(Color("3d5a80"), 0.0, 0.5)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(0.1, 1.5, 0.1), Vector3(0.44 * sx, 0.75, 0.38 * sz), frame)
	_box(Vector3(1.0, 0.2, 0.9), Vector3(0, 1.5, 0), frame)
	_cyl(0.16, 0.5, Vector3(0, 1.75, 0), Meshes.metal_mat(STEEL, 0.3), Vector3.ZERO, 10)
	_box(Vector3(0.2, 0.12, 0.2), Vector3(0, 2.02, 0), Meshes.mat(Color("ffcf4a")))
	_ram = _pivot(Vector3(0, REST_Y, 0))
	_anim(Meshes.cyl_mesh(0.07, 0.07, 0.55, 8), Meshes.metal_mat(Color("e0e4ea"), 0.15), Vector3(0, 0.45, 0), Vector3.ZERO, _ram)
	_anim(Meshes.box_mesh(Vector3(0.82, 0.14, 0.72)), Meshes.metal_mat(Color("5b6375"), 0.4), Vector3(0, 0.27, 0), Vector3.ZERO, _ram)
	_anim(Meshes.box_mesh(Vector3(0.84, 0.03, 0.74)), Meshes.mat(Color("ffcf4a"), 0.2), Vector3(0, 0.19, 0), Vector3.ZERO, _ram)
	if not ghost:
		_area = _make_area(Vector3(0.78, 0.5, 0.68), Vector3(0, 0.45, 0))


func needs_tick() -> bool:
	return true


func needs_anim() -> bool:
	return true


func apply_speed() -> void:
	_deck_speed(belt_speed())


func cycle_time() -> float:
	return float(def.interval) / machine_mult()


func info_lines() -> Array:
	return ["Presses %s" % ("on each wire pulse" if wired_in else "when an item is centred (max every %.1fs)" % (cycle_time() * 0.35)), "Metal & hot glass: half height, wider (volume kept)"]


func tick(delta: float) -> void:
	if _phase < 0.0:
		var fire := false
		if wired_in:
			fire = rising_edge()
		else:
			# light curtain: slam when something is centred under the hammer (rate-limited by cycle time)
			_timer += delta / cycle_time()
			if _timer >= 0.35:
				for it in _items_in(_area):
					var lp := to_local(it.global_position)
					if absf(lp.z) < 0.14 and absf(lp.x) < 0.3:
						fire = true
						break
		if fire:
			_timer = 0.0
			_phase = 0.0
			_done = false
		return
	_phase += delta / 0.5
	if _phase >= 0.3 and not _done:
		_done = true
		var n := 0
		for it in _items_in(_area):
			if world.press_item(it):
				n += 1
		if n > 0:
			FX.burst("sparks", local_to_world(Vector3(0, 0.3, 0)))
		FX.play("press", randf_range(0.9, 1.05), 0.05)
	if _phase >= 1.0:
		_phase = -1.0


func animate(_delta: float) -> void:
	var y := REST_Y
	if _phase >= 0.0:
		if _phase < 0.3:
			y = lerpf(REST_Y, HIT_Y, pow(_phase / 0.3, 2.0))
		else:
			y = lerpf(HIT_Y, REST_Y, (_phase - 0.3) / 0.7)
	_ram.position.y = y
