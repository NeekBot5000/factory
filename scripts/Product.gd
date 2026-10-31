class_name Product
extends RigidBody3D
## Something your machines made: planks, dried planks, mulch, metal bars, and finished furniture. Sells on the truck,
## burns in a generator (the wooden ones), and planks and bars go into builds.

const KINDS := {
	"plank": {"name": "Plank", "fuel": 8.0, "res": "plank"},
	"dry_plank": {"name": "Dried Plank", "fuel": 10.0, "res": "plank"},
	"mulch": {"name": "Bag of Mulch", "fuel": 30.0, "res": ""},
	"copper_bar": {"name": "Copper Bar", "fuel": 0.0, "res": "copper_bar"},
	"iron_bar": {"name": "Iron Bar", "fuel": 0.0, "res": "iron_bar"},
	"chair": {"name": "Chair", "fuel": 20.0, "res": ""},
	"table": {"name": "Table", "fuel": 30.0, "res": ""},
	"lantern": {"name": "Lantern", "fuel": 0.0, "res": ""},
	"cabinet": {"name": "Cabinet", "fuel": 40.0, "res": ""},
	"toy_truck": {"name": "Toy Truck", "fuel": 10.0, "res": ""},
	"battery_cell": {"name": "Battery Cell", "fuel": 0.0, "res": ""},
	"rail": {"name": "Rail", "fuel": 0.0, "res": ""},
}
const RAIL_VALUE := 2.0

var charge := 0.0               # battery cells: 0..1
var _stripe: MeshInstance3D

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
	var wood := LowPoly.mat(color, 0.8)
	var dark := LowPoly.mat(Color("2b2d33"), 0.8)
	var size := Vector3(0.3, 0.3, 0.3)
	match kind:
		"plank", "dry_plank":
			mass = 2.0
			size = Vector3(0.22, 0.05, 0.9)
			_box(size, wood, Vector3.ZERO)
			_box(Vector3(0.222, 0.004, 0.902), LowPoly.mat(color.darkened(0.12 if kind == "plank" else 0.3), 0.8), Vector3(0, 0.024, 0))
		"mulch":
			mass = 1.5
			size = Vector3(0.36, 0.22, 0.26)
			_box(size, LowPoly.mat(Color("4a6b3a"), 0.9), Vector3.ZERO)
			_box(Vector3(0.3, 0.12, 0.262), LowPoly.mat(color, 0.95), Vector3(0, 0.03, 0))
			_box(Vector3(0.37, 0.03, 0.27), dark, Vector3(0, 0.12, 0))
		"copper_bar", "iron_bar":
			mass = 3.0
			size = Vector3(0.12, 0.07, 0.3)
			var m := LowPoly.mat(Machines.COPPER if kind == "copper_bar" else Color("9aa1ab"), 0.3, 0.0)
			m = m.duplicate()
			m.metallic = 0.8
			_box(size, m, Vector3.ZERO)
			_box(Vector3(0.09, 0.02, 0.26), m, Vector3(0, 0.04, 0))
		"chair":
			mass = 3.0
			size = Vector3(0.42, 0.85, 0.42)
			_box(Vector3(0.42, 0.05, 0.42), wood, Vector3(0, 0.0, 0))
			_box(Vector3(0.42, 0.42, 0.05), wood, Vector3(0, 0.23, 0.185))
			for k in 4:
				_box(Vector3(0.05, 0.4, 0.05), wood, Vector3(0.18 if k & 1 else -0.18, -0.22, 0.18 if k & 2 else -0.18))
		"table":
			mass = 6.0
			size = Vector3(0.9, 0.6, 0.6)
			_box(Vector3(0.9, 0.06, 0.6), wood, Vector3(0, 0.27, 0))
			for k in 4:
				_box(Vector3(0.06, 0.54, 0.06), LowPoly.mat(Color("6d7480"), 0.4), Vector3(0.4 if k & 1 else -0.4, -0.03, 0.25 if k & 2 else -0.25))
		"lantern":
			mass = 1.0
			size = Vector3(0.2, 0.34, 0.2)
			_box(Vector3(0.2, 0.04, 0.2), LowPoly.mat(Machines.COPPER, 0.4), Vector3(0, -0.15, 0))
			_box(Vector3(0.2, 0.04, 0.2), LowPoly.mat(Machines.COPPER, 0.4), Vector3(0, 0.15, 0))
			var glow := StandardMaterial3D.new()
			glow.albedo_color = Color("ffd68a")
			glow.emission_enabled = true
			glow.emission = Color("ffb84a")
			glow.emission_energy_multiplier = 2.0
			_box(Vector3(0.12, 0.24, 0.12), glow, Vector3.ZERO)
			for k in 4:
				_box(Vector3(0.02, 0.28, 0.02), wood, Vector3(0.09 if k & 1 else -0.09, 0, 0.09 if k & 2 else -0.09))
		"cabinet":
			mass = 8.0
			size = Vector3(0.6, 0.9, 0.4)
			_box(size, wood, Vector3.ZERO)
			_box(Vector3(0.02, 0.8, 0.005), LowPoly.mat(color.darkened(0.3), 0.8), Vector3(0, 0, -0.2))
			for sx in [-0.06, 0.06]:
				_box(Vector3(0.03, 0.08, 0.03), LowPoly.mat(Machines.COPPER, 0.3), Vector3(sx, 0.05, -0.215))
		"battery_cell":
			mass = 2.0
			size = Vector3(0.2, 0.32, 0.2)
			_box(size, LowPoly.mat(Color("2b2d33"), 0.6), Vector3.ZERO)
			_box(Vector3(0.1, 0.05, 0.1), LowPoly.mat(Machines.COPPER, 0.35), Vector3(0, 0.18, 0))
			_box(Vector3(0.205, 0.26, 0.04), LowPoly.mat(Color("15161a"), 0.8), Vector3(0, 0, -0.085))
			_stripe = LowPoly.mesh_instance(self, LowPoly.box(Vector3(0.21, 0.26, 0.03)), LowPoly.mat(Color("4be36b")), Vector3(0, 0, -0.09))
			set_charge(charge)
		"rail":
			mass = 4.0
			size = Vector3(0.6, 0.12, 0.76)
			var iron := Tools.steel(Color("8d949e"), 0.4)
			for k in 2:
				_box(Vector3(0.6, 0.05, 0.12), LowPoly.mat(Color("6b4a32"), 0.95), Vector3(0, -0.035, -0.22 + k * 0.44))
			for sx in [-0.2, 0.2]:
				_box(Vector3(0.06, 0.07, 0.76), iron, Vector3(sx, 0.025, 0))
		"toy_truck":
			mass = 1.0
			size = Vector3(0.18, 0.16, 0.36)
			_box(Vector3(0.18, 0.08, 0.36), wood, Vector3(0, 0, 0))
			_box(Vector3(0.16, 0.08, 0.12), LowPoly.mat(Color("c0392b"), 0.6), Vector3(0, 0.08, -0.1))
			for k in 4:
				_box(Vector3(0.04, 0.07, 0.07), dark, Vector3(0.1 if k & 1 else -0.1, -0.05, 0.12 if k & 2 else -0.12))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)
	add_to_group("grabbable")
	add_to_group("products")
	ImpactSound.attach(self, "clink" if kind.ends_with("_bar") else "thud", 1.4, 2.0)


## Battery cells: how full it is, 0..1. The green stripe on its side fills up with it (no numbers on it).
func set_charge(v: float) -> void:
	charge = clampf(v, 0.0, 1.0)
	if _stripe != null:
		_stripe.scale = Vector3(1, maxf(0.02, charge), 1)
		_stripe.position.y = -0.13 + 0.13 * maxf(0.02, charge)
		_stripe.visible = charge > 0.0


func _box(s: Vector3, m: Material, at: Vector3) -> void:
	LowPoly.mesh_instance(self, LowPoly.box(s), m, at)


func fuel() -> float:
	return float(KINDS[kind].fuel)


func display_name() -> String:
	return String(KINDS[kind].name)


func hint_text() -> String:
	if kind == "battery_cell":
		return "[E] grab    Battery Cell  ·  %s" % ("empty - charge it in a charger" if charge <= 0.0 else "%d%% charged" % int(charge * 100.0))
	if kind == "rail":
		var p := get_tree().get_first_node_in_group("player")
		if p != null and String(p.get("tool")) == "hammer":
			return "[Click] lay it here    Rail"
		return "[E] grab    Rail  ·  lay it with the hammer"
	return "[E] grab    %s  ·  worth $%.2f" % [display_name(), value]
