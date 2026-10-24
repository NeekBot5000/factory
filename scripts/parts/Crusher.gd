extends Part
## Two toothed rollers break anything bigger than 0.25 into real fragments (repeated random plane cuts).
## Geodes release pure gem shards; wood turns into chips; metal passes through untouched.

const MAX_PIECE := 0.25

var _rollers: Array[MeshInstance3D] = []


func build() -> void:
	_deck(Color("9fb4c8"), 1.6)
	var steel := Meshes.mat(Color("5b6375"), 0.0, 0.5)
	var hazard := Meshes.mat(Color("ffcf4a"), 0.0, 0.6)
	for sx in [-1, 1]:
		_box(Vector3(0.1, 0.95, 0.96), Vector3(0.45 * sx, 0.55, 0), steel)
		_box(Vector3(0.11, 0.08, 0.97), Vector3(0.45 * sx, 0.95, 0), hazard)
	_box(Vector3(0.8, 0.5, 0.08), Vector3(0, 0.78, -0.44), steel)
	# hopper lip on top
	for sz in [-1, 1]:
		_box(Vector3(1.0, 0.08, 0.3), Vector3(0, 1.08, 0.36 * sz), steel, Vector3(-30 * sz, 0, 0))
	_box(Vector3(0.18, 0.18, 0.4), Vector3(0.58, 0.62, 0.0), Meshes.metal_mat(STEEL))
	for sz in [-1, 1]:
		var r := _anim(Meshes.roller_mesh(0.16, 0.78, 8), Meshes.metal_mat(Color("aab2c0"), 0.3), Vector3(0, 0.62, 0.15 * sz), Vector3(0, 90, 0))
		_rollers.append(r)
	if not ghost:
		_make_area(Vector3(0.8, 0.7, 0.8), Vector3(0, 0.5, 0), _on_enter)


func needs_anim() -> bool:
	return true


func apply_speed() -> void:
	_deck_speed(1.6 if enabled() else 0.0)


func info_lines() -> Array:
	return ["Breaks items into pieces <= %.2f" % MAX_PIECE]


func _on_enter(b: Node3D) -> void:
	var it := b as Item
	if it == null or not it.active or not enabled():
		return
	if it.cat() == "metal" or it.form == "crate":
		return
	if it.max_dim() <= MAX_PIECE and not (it.cat() == "gem" and not it.refined):
		return
	world.queue_job(func():
		if is_instance_valid(it) and it.active and is_instance_valid(self):
			FX.burst("chips" if it.cat() == "wood" else "dust", local_to_world(Vector3(0, 0.9, 0)))
			world.crush_item(it, MAX_PIECE, local_to_world(Vector3(0, 0.35, -0.3)), dir_vec() * 1.2)
			FX.play("crush", randf_range(0.85, 1.1), 0.06))


func animate(delta: float) -> void:
	if not enabled():
		return
	for i in _rollers.size():
		_rollers[i].rotate_object_local(Vector3(0, 0, 1), delta * (6.0 if i == 0 else -6.0))
