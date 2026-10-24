extends Part
## Spinning brushes polish refined gems (x2.5, -10% volume) and metal plates/sheets (+30%).

var _brushes: Array[MeshInstance3D] = []


func build() -> void:
	_deck(Color("ff7ad9"), float(def.speed))
	var body_m := Meshes.mat(Color("8e4fb5"), 0.0, 0.4)
	for sz in [-1, 1]:
		_box(Vector3(1.0, 0.7, 0.1), Vector3(0, 0.55, 0.44 * sz), body_m)
	_box(Vector3(1.0, 0.1, 0.98), Vector3(0, 0.95, 0), body_m)
	_box(Vector3(0.3, 0.2, 0.3), Vector3(0, 1.1, 0), Meshes.metal_mat(STEEL))
	for i in 2:
		var b := _anim(Meshes.roller_mesh(0.12, 0.8, 14), Meshes.mat(Color("ffe08a"), 0.0, 1.0), Vector3(0, 0.5, -0.18 + i * 0.36), Vector3(0, 90, 0))
		_brushes.append(b)
	if not ghost:
		_make_area(Vector3(0.8, 0.5, 0.8), Vector3(0, 0.42, 0), _on_enter)


func needs_anim() -> bool:
	return true


func apply_speed() -> void:
	_deck_speed(belt_speed() if enabled() else 0.0)


func info_lines() -> Array:
	return ["Gem shards: x2.5 value (-10% volume)", "Metal plates/sheets: +30%"]


func _on_enter(b: Node3D) -> void:
	var it := b as Item
	if it == null or not it.active or it.polished or not enabled():
		return
	var c := it.cat()
	if (c == "gem" and it.refined) or (c == "metal" and (it.form == "plate" or it.form == "sheet")):
		world.queue_job(func():
			if is_instance_valid(it) and it.active and not it.polished:
				it.polished = true
				if c == "gem":
					it.quality *= 2.5
					it.set_geometry(it.shape, it.size * 0.965)
				else:
					it.quality *= 1.3
					it.form = it.classify()
					it.refresh_look()
				FX.play("polish", randf_range(1.0, 1.2), 0.08))


func animate(delta: float) -> void:
	if not enabled():
		return
	for b in _brushes:
		b.rotate_object_local(Vector3(0, 0, 1), delta * 18.0)
