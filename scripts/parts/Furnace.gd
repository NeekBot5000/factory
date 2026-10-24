extends Part
## Brick furnace. Items enter through a small rear opening (big boulders don't fit), heat up inside and melt:
## ore -> metal pool (volume x purity), wood -> fuel (hotter for a while), gems crack. Ingots are cast at the front.

const OPENING := 0.36
const HEAT_RATE := 0.32

var pools := {}
var fuel := 0.0
var _inside := {}
var _window: MeshInstance3D
var _glow := 0.0
var _smoke: Array[MeshInstance3D] = []
var _cast_cool := 0.0
var ingots_made := 0


func build() -> void:
	var brick := Meshes.mat(Color("8a3b2a"), 0.0, 0.95)
	var brick2 := Meshes.mat(Color("6e2e22"), 0.0, 0.95)
	var mortar := Meshes.mat(Color("c9b8a0"), 0.0, 1.0)
	# floor
	_box(Vector3(1.0, 0.2, 1.0), Vector3(0, 0.1, 0), Meshes.mat(Color("3a2c28")))
	# side walls
	for sx in [-1, 1]:
		_box(Vector3(0.16, 1.1, 1.0), Vector3(0.42 * sx, 0.75, 0), brick)
		for k in 4:
			_box(Vector3(0.17, 0.025, 1.01), Vector3(0.42 * sx, 0.35 + k * 0.25, 0), mortar)
	_box(Vector3(1.0, 0.2, 1.0), Vector3(0, 1.4, 0), brick2)
	_box(Vector3(1.04, 0.05, 1.04), Vector3(0, 1.3, 0), mortar)
	# back wall with intake opening
	var top_h := 1.3 - (0.2 + OPENING)
	_box(Vector3(0.68, top_h, 0.16), Vector3(0, 0.2 + OPENING + top_h * 0.5, 0.42), brick)
	var side_w := (0.68 - OPENING) * 0.5
	for sx in [-1, 1]:
		_box(Vector3(side_w, OPENING, 0.16), Vector3(sx * (OPENING * 0.5 + side_w * 0.5), 0.2 + OPENING * 0.5, 0.42), brick)
	_box(Vector3(OPENING + 0.08, 0.06, 0.18), Vector3(0, 0.2 + OPENING + 0.03, 0.42), Meshes.metal_mat(STEEL))
	# front wall + output slot
	_box(Vector3(0.68, 0.85, 0.16), Vector3(0, 0.88, -0.42), brick)
	_box(Vector3(0.68, 0.1, 0.2), Vector3(0, 0.25, -0.44), Meshes.metal_mat(STEEL))
	_window = _anim(Meshes.box_mesh(Vector3(0.36, 0.22, 0.02)), Meshes.mat(Color("ff6a1a"), 1.0), Vector3(0, 0.75, -0.51))
	# chimney
	_box(Vector3(0.24, 0.6, 0.24), Vector3(0.22, 1.8, 0.22), brick2)
	_box(Vector3(0.28, 0.06, 0.28), Vector3(0.22, 2.1, 0.22), mortar)
	for i in 3:
		_smoke.append(_anim(Meshes.icosa(0.08, 0.2, 20 + i), Meshes.glass(Color(0.6, 0.6, 0.65), 0.5), Vector3(0.22, 2.2 + i * 0.3, 0.22)))
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(1.0, 0.2, 1.0), Vector3(0, 0.1, 0))
		for sx in [-1, 1]:
			_add_shape(body, Vector3(0.16, 1.3, 1.0), Vector3(0.42 * sx, 0.85, 0))
		_add_shape(body, Vector3(1.0, 0.2, 1.0), Vector3(0, 1.4, 0))
		_add_shape(body, Vector3(0.68, top_h, 0.16), Vector3(0, 0.2 + OPENING + top_h * 0.5, 0.42))
		for sx in [-1, 1]:
			_add_shape(body, Vector3(side_w, OPENING, 0.16), Vector3(sx * (OPENING * 0.5 + side_w * 0.5), 0.2 + OPENING * 0.5, 0.42))
		_add_shape(body, Vector3(0.68, 1.1, 0.16), Vector3(0, 0.75, -0.42))
		_make_area(Vector3(0.66, 0.9, 0.66), Vector3(0, 0.65, 0), _on_enter, _on_exit)


func needs_tick() -> bool:
	return true


func needs_anim() -> bool:
	return true


func apply_speed() -> void:
	if body != null:
		body.constant_linear_velocity = dir_vec() * 0.5


func capacity() -> int:
	return 4 + level


func heat_rate() -> float:
	return HEAT_RATE * machine_mult() * (2.0 if fuel > 0.0 else 1.0)


func info_lines() -> Array:
	var l := ["Rear opening %.2f wide: crush big ore first" % OPENING, "Melts %d pieces at once, heat x%.2f%s" % [capacity(), heat_rate() / HEAT_RATE, ("  fuel %.0fs" % fuel) if fuel > 0.0 else ""]]
	for m in pools:
		l.append("%s pool: %d%%" % [Defs.MATERIALS[m].name, int(float(pools[m]) / ingot_volume() * 100.0)])
	l.append("Ingots cast: %d" % ingots_made)
	return l


static func ingot_volume() -> float:
	return Defs.INGOT_SIZE.x * Defs.INGOT_SIZE.y * Defs.INGOT_SIZE.z


func _on_enter(b: Node3D) -> void:
	var it := b as Item
	if it != null and it.active:
		_inside[it] = true


func _on_exit(b: Node3D) -> void:
	_inside.erase(b)


func tick(delta: float) -> void:
	fuel = maxf(0.0, fuel - delta)
	_cast_cool = maxf(0.0, _cast_cool - delta)
	if not enabled():
		return
	var rate := heat_rate()
	var busy := false
	var slots := capacity()
	for it in _inside.keys():
		if not is_instance_valid(it) or not (it as Item).active:
			_inside.erase(it)
			continue
		var item := it as Item
		if item.form == "crate":
			continue
		if slots <= 0:
			break
		slots -= 1
		busy = true
		var c := Defs.mat_cat(item.mat)
		var k := 2.5 if c == "wood" else 1.0
		item.set_heat(item.heat + delta * rate * k / maxf(0.4, item.volume() * 80.0 + 0.6))
		if item.heat >= 1.0:
			_inside.erase(it)
			_melt(item)
	_glow = lerpf(_glow, 1.0 if busy or fuel > 0.0 else 0.25, minf(1.0, delta * 3.0))
	if _cast_cool <= 0.0:
		for m in pools.keys():
			if float(pools[m]) >= ingot_volume():
				pools[m] = float(pools[m]) - ingot_volume()
				_cast(m)
				_cast_cool = 0.35
				break


func _melt(it: Item) -> void:
	var c := Defs.mat_cat(it.mat)
	match c:
		"wood":
			fuel += 2.0 + it.volume() * 60.0
		"ore":
			var metal := it.volume() * (1.0 if it.refined else it.purity)
			pools[it.mat] = float(pools.get(it.mat, 0.0)) + metal
		"gem":
			FX.popup(global_position + Vector3(0, 1.6, 0), "cracked!", Color("ff7a7a"))
	world.consume_item(it)


func _cast(m: String) -> void:
	var xf := Transform3D(Basis.looking_at(dir_vec(), Vector3.UP), local_to_world(Vector3(0, 0.35, -0.68)))
	var it: Item = world.spawn_item({"mat": m, "shape": "box", "size": Defs.INGOT_SIZE, "refined": true, "purity": 1.0, "heat": 0.95}, xf, dir_vec() * 1.0, true)
	if it != null:
		ingots_made += 1
		Game.stats.ingots = int(Game.stats.get("ingots", 0)) + 1
		FX.play("cast", randf_range(0.95, 1.05), 0.1)


func animate(delta: float) -> void:
	var f := _glow * (0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.02))
	_window.scale = Vector3(1.0, 0.6 + 0.4 * f, 1.0)
	for i in _smoke.size():
		var s := _smoke[i]
		s.position.y += delta * 0.5 * (0.3 + _glow)
		s.scale = Vector3.ONE * (1.0 + (s.position.y - 2.2) * 1.5)
		if s.position.y > 3.1:
			s.position.y = 2.2
