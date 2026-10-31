class_name ForSale
extends StaticBody3D
## A "for sale" sign on a plot of land next to yours.

var land: Land
var key := ""


func setup(p_land: Land, k: String) -> void:
	land = p_land
	key = k
	collision_layer = 1
	var wood := LowPoly.mat(Color("a0703c"), 0.9)
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.1, 1.3, 0.1)), wood, Vector3(0, 0.65, 0))
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.8, 0.5, 0.05)), LowPoly.mat(Color("f2ede0"), 0.8), Vector3(0, 1.25, 0))
	# a red band and a little gold coin: "for sale" without words
	LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.82, 0.1, 0.06)), LowPoly.mat(Color("d64034"), 0.6), Vector3(0, 1.45, 0))
	LowPoly.mesh_instance(self, LowPoly.cyl(0.12, 0.12, 0.03, 12), LowPoly.mat(Color("e8b923"), 0.3), Vector3(0, 1.2, 0.03), Vector3(90, 0, 0))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.8, 1.5, 0.2)
	cs.shape = sh
	cs.position.y = 0.75
	add_child(cs)


func hint_text() -> String:
	return "[E] buy this plot of land    $%s" % String.num(Land.next_price(), 0)


func on_use(_player: Node) -> void:
	land.buy(key)
