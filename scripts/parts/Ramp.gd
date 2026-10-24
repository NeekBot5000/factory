extends Part
## 45 degree lift belt: up one layer over one cell, with side rails.


func build() -> void:
	_vis(Meshes.wedge_mesh(), Meshes.mat(DECK_COLOR), Vector3.ZERO)
	var n := Vector3(0, 0.7071, 0.7071)
	var top_center := Vector3(0, 0.7, 0)
	var rx := Vector3(45, 0, 0)
	_box(Vector3(0.96, 0.16, 1.4142), top_center - n * 0.12, Meshes.mat(DECK_COLOR), rx)
	_box(Vector3(0.84, 0.045, 1.4142), top_center - n * 0.0225, Meshes.belt_mat(type_id, def.tint, float(def.speed)), rx)
	for sx in [-0.47, 0.47]:
		_box(Vector3(0.06, 0.14, 1.4142), top_center + Vector3(sx, 0, 0) + n * 0.06, Meshes.mat(Color("c9a13a"), 0.0, 0.6), rx)
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(1.0, 0.2, 1.4142), top_center - n * 0.1, rx)
		for sx in [-0.5, 0.5]:
			_add_shape(body, Vector3(0.1, 0.45, 1.4142), top_center + Vector3(sx, 0, 0) + n * 0.12, rx)


func apply_speed() -> void:
	if body == null:
		return
	var s := sin(PI / 4.0)
	body.constant_linear_velocity = (dir_vec() * s + Vector3.UP * s) * belt_speed()


func info_lines() -> Array:
	return ["Lifts items one layer at %.1f u/s" % belt_speed()]
