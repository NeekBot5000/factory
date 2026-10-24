extends Part
## Packs N items into one physical crate worth 30% more. The market counts a crate as a single sale.

var count := 0
var total := 0.0
var _bar: MeshInstance3D
var _lid: Node3D


func init_config() -> void:
	config = {"count": int(def.count)}


func build() -> void:
	_deck(Color("b07a45"), 1.6)
	var wood := Meshes.mat(Color("b07a45"), 0.0, 0.9)
	var dark := Meshes.mat(Color("6b4a2f"), 0.0, 0.9)
	for sx in [-1, 1]:
		_box(Vector3(0.1, 1.0, 1.0), Vector3(0.45 * sx, 0.6, 0), wood)
	_box(Vector3(1.0, 0.12, 1.0), Vector3(0, 1.12, 0), dark)
	_box(Vector3(0.8, 0.45, 0.1), Vector3(0, 0.88, 0.44), wood)
	_box(Vector3(0.8, 0.45, 0.1), Vector3(0, 0.88, -0.44), wood)
	_box(Vector3(0.62, 0.12, 0.04), Vector3(0, 1.0, -0.5), Meshes.mat(Color("1b2030")))
	_bar = _anim(Meshes.box_mesh(Vector3(0.58, 0.08, 0.02)), Meshes.mat(Color("57e08a"), 0.8), Vector3(0, 1.0, -0.52))
	_lid = _pivot(Vector3(0, 1.2, 0))
	_anim(Meshes.crate_mesh(), Meshes.mat(Color("c48a50")), Vector3(0, 0.12, 0), Vector3.ZERO, _lid).scale = Vector3.ONE * 0.24
	if not ghost:
		_make_area(Vector3(0.7, 0.6, 0.7), Vector3(0, 0.45, 0), _on_enter)


func needs_anim() -> bool:
	return true


func apply_speed() -> void:
	_deck_speed(1.6)


func config_options() -> Array:
	return [{"key": "count", "label": "Items per crate", "values": [4, 8, 16, 32]}]


func info_lines() -> Array:
	return ["Packing %d / %d  (%s so far)" % [count, int(config.count), Util.money(total)], "Crates are worth +30%"]


func _on_enter(b: Node3D) -> void:
	var it := b as Item
	if it == null or not it.active or it.form == "crate" or not enabled():
		return
	world.queue_job(func():
		if not is_instance_valid(it) or not it.active:
			return
		total += it.value()
		count += 1
		world.consume_item(it)
		if count >= int(config.count):
			var v := total * 1.3
			count = 0
			total = 0.0
			var xf := Transform3D(Basis.looking_at(dir_vec(), Vector3.UP), local_to_world(Vector3(0, 0.5, -0.8)))
			world.spawn_item({"mat": "oak", "shape": "box", "size": Vector3(0.5, 0.5, 0.5), "form": "crate", "crate_value": v}, xf, dir_vec() * 1.0, true)
			FX.play("cast", 0.7, 0.1))


func animate(delta: float) -> void:
	var f := float(count) / float(config.count)
	_bar.scale.x = lerpf(_bar.scale.x, maxf(0.02, f), minf(1.0, delta * 8.0))
	_bar.position.x = -0.29 + 0.29 * _bar.scale.x
	_lid.rotation.y += delta * 0.8
