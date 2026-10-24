extends Part
## Sieve: a belt made of bars running along the belt. Anything narrower than the gap physically falls through.

var _bars := 0


func build() -> void:
	var gap: float = def.gap
	var bar := 0.04
	_box(Vector3(1.0, 0.06, 1.0), Vector3(0, 0.0, 0), Meshes.mat(DECK_COLOR))
	for sx in [-0.47, 0.47]:
		_box(Vector3(0.06, 0.26, 1.0), Vector3(sx, 0.13, 0), Meshes.mat(FRAME_COLOR))
		_box(Vector3(0.06, 0.12, 1.0), Vector3(sx, 0.32, 0), Meshes.mat(Color("c9a13a"), 0.0, 0.6))
	var n := int(floor((0.88 + gap) / (bar + gap)))
	_bars = n
	var span := n * bar + (n - 1) * gap
	var bm := Meshes.metal_mat(Color("9fb4c8"), 0.4)
	if not ghost:
		body = _make_body()
	for i in n:
		var x := -span * 0.5 + bar * 0.5 + i * (bar + gap)
		_box(Vector3(bar, 0.04, 1.0), Vector3(x, 0.18, 0), bm)
		if body != null:
			_add_shape(body, Vector3(bar, 0.04, 1.0), Vector3(x, 0.18, 0))
	if body != null:
		for sx in [-0.5, 0.5]:
			_add_shape(body, Vector3(0.08, 0.5, 1.0), Vector3(sx, 0.25, 0))
	# hollow underneath: items drop to the layer below


func apply_speed() -> void:
	_deck_speed(belt_speed())


func info_lines() -> Array:
	return ["Gap %.2f between %d bars: smaller pieces fall through" % [float(def.gap), _bars]]
