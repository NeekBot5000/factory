extends Part
## Solid support block (build platforms for elevated factories).


func build() -> void:
	_box(Vector3(1, 0.94, 1), Vector3(0, 0.47, 0), Meshes.mat(Color("7b8497"), 0.0, 0.9))
	_box(Vector3(1.0, 0.06, 1.0), Vector3(0, 0.97, 0), Meshes.mat(Color("98a2b8"), 0.0, 0.9))
	for sx in [-1, 1]:
		_box(Vector3(0.04, 0.94, 0.04), Vector3(0.49 * sx, 0.47, 0.49), Meshes.mat(Color("5d6578")))
		_box(Vector3(0.04, 0.94, 0.04), Vector3(0.49 * sx, 0.47, -0.49), Meshes.mat(Color("5d6578")))
	if not ghost:
		body = _make_body()
		_add_shape(body, Vector3(1, 1, 1), Vector3(0, 0.5, 0))
