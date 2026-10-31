class_name Product
extends RigidBody3D
## Something your machines made: planks from the sawmill, bags of mulch from the chipper. Sells on the truck, burns in
## a generator.

const KINDS := {
	"plank": {"name": "Plank", "fuel": 8.0},
	"mulch": {"name": "Bag of Mulch", "fuel": 30.0},
}

var kind := "plank"
var value := 1.0
var color := Color("e2c08d")


func setup(p_kind: String, p_value: float, p_color: Color) -> void:
	kind = p_kind
	value = p_value
	color = p_color
	collision_layer = 2
	collision_mask = 1 | 2
	continuous_cd = true
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	match kind:
		"plank":
			mass = 2.0
			sh.size = Vector3(0.22, 0.05, 0.9)
			LowPoly.mesh_instance(self, LowPoly.box(sh.size), LowPoly.mat(color, 0.8), Vector3.ZERO)
			LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.222, 0.004, 0.902)), LowPoly.mat(color.darkened(0.12), 0.8), Vector3(0, 0.024, 0))
		_:
			mass = 1.5
			sh.size = Vector3(0.36, 0.22, 0.26)
			LowPoly.mesh_instance(self, LowPoly.box(sh.size), LowPoly.mat(Color("4a6b3a"), 0.9), Vector3.ZERO)
			LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.3, 0.12, 0.262)), LowPoly.mat(color, 0.95), Vector3(0, 0.03, 0))
			LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.37, 0.03, 0.27)), LowPoly.mat(Color("2b2d33"), 0.8), Vector3(0, 0.12, 0))
	cs.shape = sh
	add_child(cs)
	add_to_group("grabbable")
	add_to_group("products")
	ImpactSound.attach(self, "thud", 1.4, 2.0)


func fuel() -> float:
	return float(KINDS[kind].fuel)


func hint_text() -> String:
	return "[E] grab    %s  ·  worth $%.2f" % [KINDS[kind].name, value]
