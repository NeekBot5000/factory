extends Part
## Wiring components: lever, button, timer, item sensor, AND/OR/NOT/XOR gates, counter, lamp.

const TIMER_VALUES := [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0, 30.0]
const COUNTER_VALUES := [2, 3, 4, 5, 8, 10, 16, 20, 50, 100]
const DELAY_VALUES := [0.1, 0.2, 0.3, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0]

var _events: Array = []   # [time_left, value] for the delay component
var _delayed := false

var _pulse := 0.0
var _acc := 0.0
var count := 0
var _indicator: MeshInstance3D
var _handle: Node3D
var _label: Label3D
var _area: Area3D
var _beam: MeshInstance3D
var _last_on := -1


func lt() -> String:
	return String(def.logic)


func init_config() -> void:
	match lt():
		"lever": config = {"on": false}
		"timer": config = {"interval": 1.0}
		"sensor": config = {"filter": "any"}
		"counter": config = {"n": 5}
		"delay": config = {"delay": 0.5}


func build() -> void:
	var t := lt()
	if t == "sensor":
		_build_sensor()
		return
	var base := Meshes.mat(Color("2b3348"), 0.0, 0.6)
	if t == "lamp":
		_box(Vector3(0.3, 0.1, 0.3), Vector3(0, 0.05, 0), base)
		_cyl(0.04, 0.8, Vector3(0, 0.5, 0), Meshes.metal_mat(STEEL), Vector3.ZERO, 6)
		_indicator = _anim(Meshes.icosa(0.16, 0.0, 1), Meshes.mat(Color("553322")), Vector3(0, 1.0, 0))
		_box(Vector3(0.2, 0.05, 0.2), Vector3(0, 0.88, 0), Meshes.metal_mat(STEEL))
	else:
		_box(Vector3(0.62, 0.22, 0.62), Vector3(0, 0.11, 0), base)
		_box(Vector3(0.66, 0.04, 0.66), Vector3(0, 0.02, 0), Meshes.mat(Color("1b2030")))
		_indicator = _anim(Meshes.box_mesh(Vector3(0.12, 0.05, 0.12)), Meshes.mat(Color("332222")), Vector3(0.2, 0.245, 0.2))
		match t:
			"lever":
				_box(Vector3(0.24, 0.06, 0.16), Vector3(0, 0.25, 0), Meshes.metal_mat(STEEL))
				_handle = _pivot(Vector3(0, 0.27, 0))
				_anim(Meshes.cyl_mesh(0.025, 0.025, 0.36, 6), Meshes.metal_mat(STEEL), Vector3(0, 0.18, 0), Vector3.ZERO, _handle)
				_anim(Meshes.icosa(0.06, 0.0, 2), Meshes.mat(Color("ff4f4f"), 0.2), Vector3(0, 0.37, 0), Vector3.ZERO, _handle)
			"button":
				_box(Vector3(0.3, 0.04, 0.3), Vector3(0, 0.24, 0), Meshes.mat(Color("ffcf4a")))
				_handle = _pivot(Vector3(0, 0.27, 0))
				_anim(Meshes.cyl_mesh(0.11, 0.12, 0.08, 10), Meshes.mat(Color("ff3b3b"), 0.3, 0.4), Vector3.ZERO, Vector3.ZERO, _handle)
			"timer":
				_cyl(0.2, 0.03, Vector3(0, 0.235, 0), Meshes.mat(Color("eef2ff")), Vector3.ZERO, 12)
				_handle = _pivot(Vector3(0, 0.26, 0))
				_anim(Meshes.box_mesh(Vector3(0.025, 0.02, 0.17)), Meshes.mat(Color("ff4f4f")), Vector3(0, 0, -0.08), Vector3.ZERO, _handle)
			_:
				_box(Vector3(0.42, 0.06, 0.32), Vector3(0, 0.25, -0.05), Meshes.mat(Color("1b2030")))
				for i in 4:
					_box(Vector3(0.03, 0.04, 0.08), Vector3(-0.15 + i * 0.1, 0.2, 0.16), Meshes.metal_mat(STEEL))
				_label = Label3D.new()
				_label.text = _label_text()
				_label.font_size = 48
				_label.pixel_size = 0.004
				_label.outline_size = 8
				_label.rotation_degrees.x = -90
				_label.position = Vector3(0, 0.29, -0.05)
				_label.modulate = Color("8fe0ff")
				add_child(_label)
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(0.62, 0.3, 0.62) if t != "lamp" else Vector3(0.3, 1.1, 0.3), Vector3(0, 0.15, 0) if t != "lamp" else Vector3(0, 0.55, 0))


func _build_sensor() -> void:
	_deck(Color("9fb4c8"), 2.0)
	var post := Meshes.mat(Color("2b3348"), 0.0, 0.5)
	for sx in [-1, 1]:
		_box(Vector3(0.1, 0.6, 0.12), Vector3(0.46 * sx, 0.4, 0), post)
		_box(Vector3(0.06, 0.06, 0.06), Vector3(0.42 * sx, 0.42, 0), Meshes.mat(Color("ff4f4f"), 0.8))
	_beam = _anim(Meshes.box_mesh(Vector3(0.84, 0.02, 0.02)), Meshes.mat(Color("ff3030"), 1.5), Vector3(0, 0.42, 0))
	_indicator = _beam
	if not ghost:
		_area = _make_area(Vector3(0.84, 0.5, 0.12), Vector3(0, 0.45, 0))


func needs_anim() -> bool:
	return true


func apply_speed() -> void:
	if lt() == "sensor":
		_deck_speed(2.0 * Game.belt_mult())


func port_out_pos() -> Vector3:
	return local_to_world(Vector3(0.22, 0.3, 0.0) if lt() != "sensor" else Vector3(0.46, 0.72, 0))


func port_in_pos() -> Vector3:
	return local_to_world(Vector3(-0.22, 0.3, 0.0) if lt() != "lamp" else Vector3(0, 0.2, 0))


func _label_text() -> String:
	match lt():
		"and": return "AND"
		"or": return "OR"
		"not": return "NOT"
		"xor": return "XOR"
		"counter": return "%d/%d" % [count, int(config.get("n", 5))]
		"delay": return "%.2fs" % float(config.get("delay", 0.5))
	return ""


func interact() -> bool:
	match lt():
		"lever":
			config.on = not bool(config.on)
			FX.play("click", 0.8 if bool(config.on) else 0.6)
			return true
		"button":
			_pulse = 1.0
			FX.play("click", 1.0)
			return true
	return false


func config_options() -> Array:
	match lt():
		"timer": return [{"key": "interval", "label": "Pulse every (s)", "values": TIMER_VALUES}]
		"sensor": return [{"key": "filter", "label": "Detect", "values": Defs.SENSOR_FILTERS}]
		"counter": return [{"key": "n", "label": "Pulse every N inputs", "values": COUNTER_VALUES}]
		"delay": return [{"key": "delay", "label": "Delay (s)", "values": DELAY_VALUES}]
		"lever": return [{"key": "on", "label": "State", "values": [false, true], "names": ["Off", "On"]}]
	return []


func on_config_changed() -> void:
	count = 0
	if _label:
		_label.text = _label_text()


func info_lines() -> Array:
	match lt():
		"lever": return ["Click to toggle"]
		"button": return ["Click to pulse (1s)"]
		"timer": return ["Pulses every %ss" % str(config.interval)]
		"sensor": return ["Detects: %s" % String(config.filter)]
		"counter": return ["Count %d / %d" % [count, int(config.n)]]
		"delay": return ["Repeats the input %.2fs later" % float(config.delay)]
		"and": return ["On when ALL inputs are on (%d/%d)" % [in_on, in_total]]
		"or": return ["On when ANY input is on (%d/%d)" % [in_on, in_total]]
		"not": return ["On when NO input is on"]
		"xor": return ["On when an odd number of inputs are on"]
		"lamp": return ["Lights up when powered"]
	return []


static func matches(it: Item, f: String) -> bool:
	match f:
		"any": return true
		"wood", "ore", "metal", "gem": return it.cat() == f
		"big": return it.max_dim() > 0.4
		"small": return it.max_dim() < 0.2
		"hot": return it.heat > 0.3
	return it.form == f


func update_output(delta: float) -> void:
	_pulse = maxf(0.0, _pulse - delta)
	match lt():
		"lever":
			sig_out = bool(config.on)
		"button":
			sig_out = _pulse > 0.0
		"timer":
			if enabled():
				_acc += delta
				if _acc >= float(config.interval):
					_acc = 0.0
					_pulse = minf(0.2, float(config.interval) * 0.5)
			sig_out = _pulse > 0.0
		"sensor":
			var on := false
			for it in _items_in(_area):
				if matches(it, String(config.filter)):
					on = true
					break
			sig_out = on
		"and":
			sig_out = in_total > 0 and in_on == in_total
		"or":
			sig_out = in_on > 0
		"not":
			sig_out = in_on == 0
		"xor":
			sig_out = in_on % 2 == 1
		"delay":
			if sig_in != _delayed:
				_events.append([float(config.delay), sig_in])
				_delayed = sig_in
			for e in _events:
				e[0] = float(e[0]) - delta
			while not _events.is_empty() and float(_events[0][0]) <= 0.0:
				sig_out = bool(_events[0][1])
				_events.pop_front()
		"counter":
			if rising_edge():
				count += 1
				if count >= int(config.n):
					count = 0
					_pulse = 0.2
				if _label:
					_label.text = _label_text()
			sig_out = _pulse > 0.0


func animate(_delta: float) -> void:
	var on := sig_in if lt() == "lamp" else sig_out
	var k := 1 if on else 0
	if k != _last_on:
		_last_on = k
		match lt():
			"lamp":
				_indicator.material_override = Meshes.mat(Color("ffe08a"), 3.0) if on else Meshes.mat(Color("553322"))
			"sensor":
				_beam.material_override = Meshes.mat(Color("40ff70"), 2.0) if on else Meshes.mat(Color("ff3030"), 1.5)
			_:
				_indicator.material_override = Meshes.mat(Color("ff4040"), 2.0) if on else Meshes.mat(Color("332222"))
	if _handle != null:
		match lt():
			"lever":
				_handle.rotation.x = lerpf(_handle.rotation.x, deg_to_rad(35.0 if bool(config.on) else -35.0), 0.3)
			"button":
				_handle.position.y = 0.25 if _pulse > 0.0 else 0.27
			"timer":
				_handle.rotation.y = -_acc / float(config.interval) * TAU
