extends Part
## Water jets wash unrefined ore: +15% purity, once per piece.

var _drops: Array[MeshInstance3D] = []


func build() -> void:
	_deck(Color("4fa8ff"), float(def.speed))
	var body_m := Meshes.mat(Color("2f6fb0"), 0.0, 0.4)
	for sz in [-1, 1]:
		_box(Vector3(1.0, 0.8, 0.1), Vector3(0, 0.6, 0.43 * sz), body_m)
	_box(Vector3(1.0, 0.1, 0.96), Vector3(0, 1.0, 0), body_m)
	for sx in [-1, 1]:
		_box(Vector3(0.04, 0.6, 0.76), Vector3(0.48 * sx, 0.55, 0), Meshes.glass(Color("8fd0ff"), 0.35))
	_cyl(0.06, 0.8, Vector3(0, 0.9, 0), Meshes.metal_mat(STEEL), Vector3(90, 0, 0), 6)
	_box(Vector3(0.3, 0.3, 0.3), Vector3(0, 1.2, 0.2), Meshes.mat(Color("1f4f80")))
	for i in 6:
		var d := _anim(Meshes.box_mesh(Vector3(0.025, 0.12, 0.025)), Meshes.mat(Color("bfe6ff"), 0.6, 0.1), Vector3(randf_range(-0.3, 0.3), 0.8, randf_range(-0.3, 0.3)))
		_drops.append(d)
	if not ghost:
		_make_area(Vector3(0.8, 0.6, 0.8), Vector3(0, 0.45, 0), _on_enter)


func needs_anim() -> bool:
	return true


func apply_speed() -> void:
	_deck_speed(belt_speed() if enabled() else 0.0)


func info_lines() -> Array:
	return ["+15% purity to unwashed ore"]


func _on_enter(b: Node3D) -> void:
	var it := b as Item
	if it == null or not it.active or not enabled():
		return
	if Defs.mat_cat(it.mat) == "ore" and not it.refined and not it.washed:
		world.queue_job(func():
			if is_instance_valid(it) and it.active:
				it.washed = true
				FX.burst("splash", it.global_position)
				it.purity = minf(0.98, it.purity + 0.15)
				it.refresh_look())


func animate(delta: float) -> void:
	if not enabled():
		return
	for d in _drops:
		d.position.y -= delta * 2.5
		if d.position.y < 0.25:
			d.position = Vector3(randf_range(-0.3, 0.3), 0.85, randf_range(-0.3, 0.3))
