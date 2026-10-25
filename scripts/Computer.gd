class_name Computer
extends StaticBody3D
## The cabin computer: a chunky desk PC that boots straight into the TimberMart store.

var main: Node
var _screen: MeshInstance3D
var _off_mat: Material
var _on_mat: Material


func build(p_main: Node) -> void:
	main = p_main
	collision_layer = 1
	var wood := LowPoly.mat(Color("7d5434"), 0.9)
	var beige := LowPoly.mat(Color("d9d2bf"), 0.7)
	var dark := LowPoly.mat(Color("2b2d33"), 0.7)
	# desk
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(1.3, 0.06, 0.65)), wood, Vector3(0, 0.76, 0))
	for sx in [-1, 1]:
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.06, 0.76, 0.6)), wood, Vector3(sx * 0.6, 0.38, 0))
	# monitor
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.62, 0.48, 0.4)), beige, Vector3(-0.05, 1.08, -0.08))
	_off_mat = LowPoly.mat(Color("1a1d1c"), 0.15)
	_on_mat = LowPoly.mat(Color("1d5c3a"), 0.3, 1.2)
	_screen = LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.5, 0.36, 0.01)), _off_mat, Vector3(-0.05, 1.1, 0.125))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.2, 0.06, 0.2)), beige, Vector3(-0.05, 0.82, -0.05))
	# keyboard, mouse, tower
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.45, 0.03, 0.16)), beige, Vector3(-0.05, 0.805, 0.2))
	for k in 3:
		LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.4, 0.01, 0.03)), LowPoly.mat(Color("a8a290")), Vector3(-0.05, 0.825, 0.15 + k * 0.045))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.06, 0.03, 0.1)), beige, Vector3(0.3, 0.805, 0.2))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.2, 0.45, 0.45)), beige, Vector3(0.45, 1.02, -0.05))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.02, 0.02, 0.01)), LowPoly.mat(Color("5cff8a"), 0.3, 2.0), Vector3(0.38, 0.9, 0.18))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.21, 0.04, 0.3)), dark, Vector3(0.45, 1.15, 0.0))
	# chair (stump)
	LowPoly.mesh_instance(self, LowPoly.cyl(0.2, 0.22, 0.45, 7), LowPoly.mat(Color("8a5a36")), Vector3(0, 0.22, 0.6))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.3, 1.4, 0.7)
	cs.shape = sh
	cs.position = Vector3(0, 0.7, 0)
	add_child(cs)


## Screen is dark and blank until someone is using the store.
func set_on(on: bool) -> void:
	_screen.material_override = _on_mat if on else _off_mat


func hint_text() -> String:
	return "[E] use"


func on_use(_player: Node) -> void:
	main.call("open_computer")


func on_click(_player: Node) -> void:
	main.call("open_computer")
