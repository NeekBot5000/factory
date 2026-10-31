class_name Machines
extends RefCounted
## Models and finishing for the hammer's machines (crank, lever, button, piston, rotator, conveyors, truck caller).
## They always build at 1x on a 1 m grid, facing one of four directions. Their front (the way a piston pushes or a
## belt carries) is local -Z, away from you as you place them.

const IDS := ["crank", "lever", "button", "piston", "rotator", "conveyor", "ramp", "truck_caller",
	"windmill", "generator", "battery", "gate_diode", "gate_and", "gate_not", "gate_timer", "gate_delay", "gate_latch",
	"gate_counter", "pressure_plate", "item_sensor", "lamp", "bell", "sawmill", "chipper", "planter", "sprinkler", "feller"]
const GATE_COLOR := {"diode": Color("f2c12e"), "and": Color("3fa66b"), "not": Color("d64034"), "timer": Color("4fa3e3"),
	"delay": Color("9b6ad6"), "latch": Color("e8642b"), "counter": Color("e2e2e2")}

const STONE := Color("8a8780")
const COPPER := Color("c8703a")
const IRON := Color("5d6068")
const DARK := Color("2b2d33")
const RED := Color("d64034")

const BELT_Y := 0.5         # top of a conveyor belt
const BELT_W := 1.0         # a belt fills its whole grid square, border to border
const RAMP_LEN := 2.0       # horizontal length of a ramp conveyor
const RAMP_RISE := 1.0
const RAMP_Z := -0.5        # a ramp covers its own grid cell and the one in front, so it lines up with belts


static func is_machine(id: String) -> bool:
	return id in IDS


static func _p(parts: Array, parent: Node3D, mesh: Mesh, pos: Vector3, res: String, real: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return Builds._part(parts, parent, mesh, pos, res, real, rot)


static func _node(parent: Node3D, n: String, pos := Vector3.ZERO) -> Node3D:
	var nd := Node3D.new()
	nd.name = n
	nd.position = pos
	parent.add_child(nd)
	return nd


static func model(id: String, root: Node3D, parts: Array) -> void:
	if id.begins_with("gate_"):
		_gate(root, parts, id.trim_prefix("gate_"), LowPoly.mat(STONE, 1.0), LowPoly.mat(COPPER, 0.35, 0.05), LowPoly.mat(DARK, 0.7))
		return
	var stone := LowPoly.mat(STONE, 1.0)
	var copper := LowPoly.mat(COPPER, 0.35, 0.05)
	var logm := LowPoly.mat(Builds.LOGC, 0.9)
	var bark := LowPoly.mat(Builds.BARK, 0.95)
	var iron := LowPoly.mat(IRON, 0.45)
	var dark := LowPoly.mat(DARK, 0.7)
	var red := LowPoly.mat(RED, 0.5)
	match id:
		"crank":
			for k in 4:
				var o := Vector3(0.15 if k & 1 else -0.15, 0.08, 0.15 if k & 2 else -0.15)
				_p(parts, root, LowPoly.box(Vector3(0.29, 0.16, 0.29)), o, "stone", stone)
			_p(parts, root, LowPoly.cyl(0.09, 0.1, 0.62, 8), Vector3(0, 0.47, 0), "log", logm)
			_p(parts, root, LowPoly.box(Vector3(0.26, 0.2, 0.26)), Vector3(0, 0.86, 0), "copper", copper)
			var h := _node(root, "Handle", Vector3(0.16, 0.86, 0))
			_p(parts, h, LowPoly.cyl(0.03, 0.03, 0.08, 6), Vector3(0.04, 0, 0), "", iron, Vector3(0, 0, 90))
			_p(parts, h, LowPoly.box(Vector3(0.04, 0.34, 0.05)), Vector3(0.08, 0.14, 0), "", iron)
			_p(parts, h, LowPoly.cyl(0.035, 0.035, 0.14, 6), Vector3(0.15, 0.29, 0), "", red, Vector3(0, 0, 90))
		"lever":
			for sx in [-0.13, 0.13]:
				_p(parts, root, LowPoly.box(Vector3(0.25, 0.14, 0.42)), Vector3(sx, 0.07, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.3, 0.06, 0.34)), Vector3(0, 0.17, 0), "copper", copper)
			var h := _node(root, "Handle", Vector3(0, 0.2, 0))
			_p(parts, h, LowPoly.box(Vector3(0.05, 0.5, 0.05)), Vector3(0, 0.25, 0), "", iron)
			_p(parts, h, LowPoly.cyl(0.05, 0.05, 0.1, 8), Vector3(0, 0.52, 0), "", red, Vector3(0, 0, 90))
			h.rotation_degrees.x = 35.0
		"button":
			_p(parts, root, LowPoly.cyl(0.07, 0.08, 0.7, 8), Vector3(0, 0.35, 0), "log", logm)
			for k in 2:
				_p(parts, root, LowPoly.box(Vector3(0.3, 0.14, 0.24)), Vector3(0, 0.77 + k * 0.14, 0), "stone", stone)
			_p(parts, root, LowPoly.cyl(0.1, 0.1, 0.03, 12), Vector3(0, 0.92, 0.13), "copper", copper, Vector3(90, 0, 0))
			var cap := _node(root, "Cap", Vector3(0, 0.92, 0.15))
			_p(parts, cap, LowPoly.cyl(0.075, 0.08, 0.06, 12), Vector3.ZERO, "", red, Vector3(90, 0, 0))
		"piston":
			# housing: stone blocks, banded with copper coils; the wooden push plate and its rod slide out the front
			for k in 8:
				var o := Vector3(0.2 if k & 1 else -0.2, 0.2 if k & 2 else 0.6, -0.27 if k & 4 else 0.27)
				_p(parts, root, LowPoly.box(Vector3(0.39, 0.39, 0.53)), o, "stone", stone)
			for k in 2:
				_p(parts, root, LowPoly.box(Vector3(0.84, 0.84, 0.08)), Vector3(0, 0.4, -0.2 + k * 0.5), "copper", copper)
			var plate := _node(root, "Plate", Vector3(0, 0.4, -0.6))
			# an iron push plate on an iron rod
			_p(parts, plate, LowPoly.box(Vector3(0.78, 0.78, 0.1)), Vector3.ZERO, "iron", iron)
			_p(parts, plate, LowPoly.cyl(0.06, 0.06, 1.05, 8), Vector3(0, 0, 0.55), "iron", iron, Vector3(90, 0, 0))
			for k in 4:
				_p(parts, plate, LowPoly.cyl(0.03, 0.03, 0.02, 6), Vector3(0.3 if k & 1 else -0.3, 0.3 if k & 2 else -0.3, -0.06), "", dark, Vector3(90, 0, 0))
		"rotator":
			for k in 4:
				var a := TAU * k / 4.0 + PI / 4.0
				_p(parts, root, LowPoly.box(Vector3(0.5, 0.24, 0.5)), Vector3(cos(a) * 0.24, 0.12, sin(a) * 0.24), "stone", stone, Vector3(0, -rad_to_deg(a) + 45.0, 0))
			_p(parts, root, LowPoly.cyl(0.52, 0.52, 0.06, 16), Vector3(0, 0.27, 0), "copper", copper)
			var table := _node(root, "Table", Vector3(0, 0.33, 0))
			_p(parts, table, LowPoly.cyl(0.6, 0.6, 0.07, 16), Vector3.ZERO, "log", logm)
			for k in 4:
				_p(parts, table, LowPoly.box(Vector3(0.05, 0.012, 1.1)), Vector3(0, 0.04, 0), "iron" if k % 2 == 0 else "", iron if k % 2 == 0 else dark, Vector3(0, 45.0 * k, 0))
		"conveyor":
			_belt(root, parts, 1.0, 0.0, bark, stone, iron, dark)
		"ramp":
			_belt(root, parts, RAMP_LEN, RAMP_RISE, bark, stone, iron, dark, RAMP_Z)
		"pillar":
			# a 1 m block of dressed stone: belts on top of it run at the height of a ramp's top end
			for k in 8:
				var o := Vector3(0.245 if k & 1 else -0.245, 0.25 if k & 4 else 0.75, 0.245 if k & 2 else -0.245)
				_p(parts, root, LowPoly.box(Vector3(0.48, 0.49, 0.48)), o, "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(1.0, 0.04, 1.0)), Vector3(0, 0.99, 0), "", LowPoly.mat(STONE.lightened(0.15), 1.0))
		"windmill": _windmill(root, parts, stone, logm, bark, copper, iron)
		"generator": _generator(root, parts, stone, bark, copper, iron, dark)
		"battery":
			_p(parts, root, LowPoly.box(Vector3(0.7, 0.15, 0.5)), Vector3(0, 0.075, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.6, 0.6, 0.4)), Vector3(0, 0.45, 0), "copper", copper)
			_p(parts, root, LowPoly.box(Vector3(0.62, 0.05, 0.42)), Vector3(0, 0.77, 0), "iron", iron)
			for sx in [-0.18, 0.18]:
				_p(parts, root, LowPoly.cyl(0.04, 0.04, 0.08, 8), Vector3(sx, 0.83, 0), "", red if sx < 0 else dark)
			_p(parts, root, LowPoly.box(Vector3(0.1, 0.5, 0.02)), Vector3(0, 0.45, 0.205), "", dark)
			var bar := _node(root, "Bar", Vector3(0, 0.21, 0.212))
			var gl := StandardMaterial3D.new()
			gl.albedo_color = Color("7dff8a")
			gl.emission_enabled = true
			gl.emission = Color("4fe36a")
			gl.emission_energy_multiplier = 1.5
			_p(parts, bar, LowPoly.box(Vector3(0.07, 0.48, 0.01)), Vector3(0, 0.24, 0), "", gl)
			bar.scale.y = 0.02
		"pressure_plate":
			_p(parts, root, LowPoly.box(Vector3(0.9, 0.04, 0.9)), Vector3(0, 0.02, 0), "stone", stone)
			var plate := _node(root, "Plate", Vector3(0, 0.06, 0))
			_p(parts, plate, LowPoly.box(Vector3(0.74, 0.04, 0.74)), Vector3.ZERO, "log", logm)
			_p(parts, root, LowPoly.box(Vector3(0.08, 0.06, 0.08)), Vector3(0.36, 0.05, 0.36), "copper", copper)
		"item_sensor":
			_p(parts, root, LowPoly.box(Vector3(0.36, 0.12, 0.36)), Vector3(0, 0.06, 0), "stone", stone)
			_p(parts, root, LowPoly.cyl(0.05, 0.06, 0.55, 8), Vector3(0, 0.38, 0), "log", logm)
			_p(parts, root, LowPoly.box(Vector3(0.22, 0.18, 0.16)), Vector3(0, 0.7, 0), "copper", copper)
			_p(parts, root, LowPoly.cyl(0.06, 0.06, 0.04, 10), Vector3(0, 0.7, -0.09), "", dark, Vector3(90, 0, 0))
			_p(parts, root, LowPoly.cyl(0.035, 0.035, 0.045, 10), Vector3(0, 0.7, -0.1), "", LowPoly.mat(Color("ff5a4a"), 0.3, 1.0), Vector3(90, 0, 0))
		"lamp":
			_p(parts, root, LowPoly.box(Vector3(0.3, 0.1, 0.3)), Vector3(0, 0.05, 0), "stone", stone)
			_p(parts, root, LowPoly.cyl(0.04, 0.05, 1.05, 7), Vector3(0, 0.6, 0), "log", logm)
			var bulb := _p(parts, root, LowPoly.box(Vector3(0.16, 0.2, 0.16)), Vector3(0, 1.25, 0), "", LowPoly.mat(Color("6b6458")))
			bulb.name = "Bulb"
			_p(parts, root, LowPoly.box(Vector3(0.24, 0.04, 0.24)), Vector3(0, 1.37, 0), "copper", copper)
			_p(parts, root, LowPoly.box(Vector3(0.22, 0.03, 0.22)), Vector3(0, 1.13, 0), "", iron)
		"bell":
			for sx in [-0.25, 0.25]:
				_p(parts, root, LowPoly.box(Vector3(0.08, 1.1, 0.08)), Vector3(sx, 0.55, 0), "log", logm)
			_p(parts, root, LowPoly.box(Vector3(0.6, 0.08, 0.1)), Vector3(0, 1.12, 0), "log", logm)
			var bell := _node(root, "Bell", Vector3(0, 1.08, 0))
			_p(parts, bell, LowPoly.cyl(0.07, 0.18, 0.28, 10), Vector3(0, -0.16, 0), "copper", copper)
			_p(parts, bell, LowPoly.cyl(0.03, 0.03, 0.05, 6), Vector3(0, -0.32, 0), "", dark)
		"sawmill":
			_p(parts, root, LowPoly.box(Vector3(0.9, 0.5, 0.9)), Vector3(0, 0.25, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(1.0, 0.06, 1.0)), Vector3(0, 0.55, 0), "iron", iron)
			var blade := _node(root, "Blade", Vector3(0, 0.56, 0))
			_p(parts, blade, LowPoly.cyl(0.3, 0.3, 0.015, 16), Vector3.ZERO, "iron", LowPoly.mat(Color("c9ced6"), 0.3), Vector3(0, 0, 90))
			for k in 8:
				_p(parts, blade, LowPoly.box(Vector3(0.02, 0.05, 0.05)), Vector3(0, 0.3, 0).rotated(Vector3.RIGHT, TAU * k / 8.0), "", dark, Vector3(rad_to_deg(TAU * k / 8.0), 0, 0))
			_p(parts, root, LowPoly.box(Vector3(0.6, 0.04, 0.5)), Vector3(0, 0.38, -0.62), "log", logm, Vector3(-25, 0, 0))
			_p(parts, root, LowPoly.box(Vector3(0.12, 0.3, 0.9)), Vector3(0.47, 0.75, 0), "", logm)
		"chipper":
			_p(parts, root, LowPoly.box(Vector3(0.8, 0.55, 0.8)), Vector3(0, 0.275, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.7, 0.2, 0.7)), Vector3(0, 0.65, 0), "copper", copper)
			_hopper(root, parts, 0.75, 0.75, bark)
			var drum := _node(root, "Drum", Vector3(0, 0.62, 0))
			for k in 4:
				_p(parts, drum, LowPoly.box(Vector3(0.6, 0.03, 0.12)), Vector3.ZERO, "", iron, Vector3(k * 45.0, 0, 0))
			_p(parts, root, LowPoly.box(Vector3(0.5, 0.04, 0.4)), Vector3(0, 0.3, -0.55), "", iron, Vector3(-25, 0, 0))
		"planter":
			_p(parts, root, LowPoly.box(Vector3(0.8, 0.5, 0.8)), Vector3(0, 0.25, 0), "stone", stone)
			_hopper(root, parts, 0.5, 0.7, bark)
			_p(parts, root, LowPoly.box(Vector3(0.12, 0.12, 0.7)), Vector3(0, 0.35, -0.6), "log", logm)
			_p(parts, root, LowPoly.box(Vector3(0.2, 0.04, 0.16)), Vector3(0, 0.25, -0.95), "", iron, Vector3(30, 0, 0))
		"sprinkler":
			_p(parts, root, LowPoly.box(Vector3(0.36, 0.1, 0.36)), Vector3(0, 0.05, 0), "stone", stone)
			_p(parts, root, LowPoly.cyl(0.03, 0.03, 0.55, 6), Vector3(0, 0.37, 0), "copper", copper)
			var head := _node(root, "Head", Vector3(0, 0.66, 0))
			_p(parts, head, LowPoly.box(Vector3(0.36, 0.04, 0.04)), Vector3.ZERO, "", iron)
			for sx in [-0.18, 0.18]:
				_p(parts, head, LowPoly.cyl(0.02, 0.03, 0.06, 6), Vector3(sx, 0.03, 0), "", iron)
		"feller":
			_p(parts, root, LowPoly.box(Vector3(0.9, 0.3, 0.9)), Vector3(0, 0.15, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.18, 0.9, 0.18)), Vector3(0, 0.75, 0.2), "log", logm)
			_p(parts, root, LowPoly.box(Vector3(0.16, 0.16, 0.9)), Vector3(0, 1.1, -0.2), "iron", iron)
			_p(parts, root, LowPoly.box(Vector3(0.1, 0.7, 0.1)), Vector3(0, 0.75, -0.6), "iron", iron)
			_node(root, "Arm", Vector3(0, 0.45, -0.75))
			_p(parts, root, LowPoly.box(Vector3(0.3, 0.06, 0.3)), Vector3(0, 0.33, 0.2), "copper", copper)
		"truck_caller":
			for sx in [-0.14, 0.14]:
				_p(parts, root, LowPoly.box(Vector3(0.27, 0.2, 0.5)), Vector3(sx, 0.1, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.5, 0.12, 0.3)), Vector3(0, 0.26, 0), "stone", stone)
			_p(parts, root, LowPoly.cyl(0.07, 0.08, 1.5, 8), Vector3(0, 1.0, 0), "log", logm)
			for k in 2:
				_p(parts, root, LowPoly.box(Vector3(0.6, 0.18, 0.04)), Vector3(0, 1.45 + k * 0.19, 0.08), "copper", copper)
			_p(parts, root, LowPoly.box(Vector3(0.62, 0.03, 0.05)), Vector3(0, 1.36, 0.09), "copper", copper)
			# a little truck painted on the sign and a horn on top
			_p(parts, root, LowPoly.box(Vector3(0.26, 0.1, 0.01)), Vector3(-0.04, 1.54, 0.105), "", LowPoly.mat(Color("3f7d4a"), 0.7))
			_p(parts, root, LowPoly.box(Vector3(0.1, 0.12, 0.01)), Vector3(0.15, 1.56, 0.105), "", LowPoly.mat(Color("3f7d4a"), 0.7))
			for sx in [-0.1, 0.12]:
				_p(parts, root, LowPoly.cyl(0.035, 0.035, 0.012, 8), Vector3(sx, 1.48, 0.11), "", dark, Vector3(90, 0, 0))
			_p(parts, root, LowPoly.cyl(0.03, 0.09, 0.2, 10), Vector3(0, 1.9, 0.02), "iron", iron, Vector3(80, 0, 0))
			_p(parts, root, LowPoly.box(Vector3(0.66, 0.05, 0.08)), Vector3(0, 1.75, 0.07), "iron", iron)


## A logic block: stone slab, copper top, an arrow pointing to its front and a coloured gem for its mode.
static func _gate(root: Node3D, parts: Array, mode: String, stone: Material, copper: Material, dark: Material) -> void:
	_p(parts, root, LowPoly.box(Vector3(0.7, 0.12, 0.7)), Vector3(0, 0.06, 0), "stone", stone)
	_p(parts, root, LowPoly.box(Vector3(0.6, 0.04, 0.6)), Vector3(0, 0.14, 0), "copper", copper)
	var paint := LowPoly.mat(Color("f2c12e"), 0.6)
	var arrow := Tools.prism(PackedVector2Array([Vector2(0.0, -0.2), Vector2(0.16, 0.0), Vector2(0.07, 0.0), Vector2(0.07, 0.16), Vector2(-0.07, 0.16), Vector2(-0.07, 0.0), Vector2(-0.16, 0.0)]), 0.01, Color("f2c12e"))
	var mi := _p(parts, root, arrow, Vector3(0, 0.165, 0.02), "", paint)
	mi.basis = Basis(Vector3.BACK, -PI * 0.5)
	mi.set_meta("arrow", true)
	var col: Color = GATE_COLOR.get(mode, Color.WHITE)
	var gem := StandardMaterial3D.new()
	gem.albedo_color = col
	gem.emission_enabled = true
	gem.emission = col
	gem.emission_energy_multiplier = 0.6
	_p(parts, root, LowPoly.box(Vector3(0.12, 0.08, 0.12)), Vector3(0, 0.2, 0.2), "", gem)
	# little posts: copper at the back (input), dark on the sides (control)
	_p(parts, root, LowPoly.cyl(0.03, 0.03, 0.1, 6), Vector3(0, 0.2, 0.3), "", copper)
	for sx in [-0.3, 0.3]:
		_p(parts, root, LowPoly.cyl(0.03, 0.03, 0.1, 6), Vector3(sx, 0.2, 0), "", dark)


## A bark hopper on top of a machine: open-topped walls `w` wide whose floor is at `y`.
static func _hopper(root: Node3D, parts: Array, y: float, w: float, bark: Material) -> void:
	for s in [-1.0, 1.0]:
		_p(parts, root, LowPoly.box(Vector3(w, 0.35, 0.04)), Vector3(0, y + 0.42, s * w * 0.5), "bark", bark, Vector3(s * -12.0, 0, 0))
		_p(parts, root, LowPoly.box(Vector3(0.04, 0.35, w)), Vector3(s * w * 0.5, y + 0.42, 0), "bark", bark, Vector3(0, 0, s * 12.0))


static func _windmill(root: Node3D, parts: Array, stone: Material, logm: Material, bark: Material, copper: Material, iron: Material) -> void:
	for k in 4:
		var o := Vector3(0.2 if k & 1 else -0.2, 0.1, 0.2 if k & 2 else -0.2)
		_p(parts, root, LowPoly.box(Vector3(0.38, 0.2, 0.38)), o, "stone", stone)
	_p(parts, root, LowPoly.cyl(0.08, 0.14, 2.5, 7), Vector3(0, 1.45, 0), "log", logm)
	_p(parts, root, LowPoly.box(Vector3(0.22, 0.22, 0.5)), Vector3(0, 2.7, 0.05), "copper", copper)
	_p(parts, root, LowPoly.box(Vector3(0.03, 0.35, 0.5)), Vector3(0, 2.75, 0.5), "bark", bark)
	var rotor := _node(root, "Rotor", Vector3(0, 2.7, -0.25))
	_p(parts, rotor, LowPoly.cyl(0.08, 0.08, 0.12, 8), Vector3.ZERO, "", iron, Vector3(90, 0, 0))
	for k in 4:
		var a := TAU * k / 4.0
		var blade := _p(parts, rotor, LowPoly.box(Vector3(0.22, 1.1, 0.03)), Vector3(sin(a), cos(a), 0) * 0.62, "bark", bark)
		blade.rotation.z = -a


static func _generator(root: Node3D, parts: Array, stone: Material, bark: Material, copper: Material, iron: Material, dark: Material) -> void:
	_p(parts, root, LowPoly.box(Vector3(0.9, 0.8, 0.9)), Vector3(0, 0.4, 0), "stone", stone)
	_p(parts, root, LowPoly.box(Vector3(0.4, 0.3, 0.04)), Vector3(0, 0.3, -0.46), "", dark)
	_p(parts, root, LowPoly.box(Vector3(0.92, 0.08, 0.92)), Vector3(0, 0.6, 0), "copper", copper)
	_hopper(root, parts, 0.8, 0.7, bark)
	_p(parts, root, LowPoly.cyl(0.07, 0.08, 0.8, 8), Vector3(-0.3, 1.15, 0.3), "iron", iron)
	_p(parts, root, LowPoly.cyl(0.1, 0.1, 0.08, 8), Vector3(-0.3, 1.58, 0.3), "", dark)


## A belt `len` long (along Z), rising `rise` toward the front (-Z). Belt top starts at BELT_Y.
static func _belt(root: Node3D, parts: Array, len: float, rise: float, bark: Material, stone: Material, iron: Material, dark: Material, z0 := 0.0) -> void:
	var tilt := atan2(rise, len)
	var slope := Vector3(0, rise, -len)
	var run := slope.length()
	var c := Vector3(0, BELT_Y - 0.04 + rise * 0.5, z0)
	var rot := Vector3(rad_to_deg(tilt), 0, 0)
	var dir := slope.normalized()
	var nrm := Vector3(0, cos(tilt), sin(tilt))
	var n := int(round(run * 3.0))
	for k in n:
		var p := c + dir * (-run * 0.5 + run * (k + 0.5) / n)
		_p(parts, root, LowPoly.box(Vector3(BELT_W - 0.08, 0.07, run / n - 0.01)), p, "bark", bark, rot)
	# low borders along both edges, so the belt fills its whole grid square and neighbours butt up against it
	for sx in [-1.0, 1.0]:
		var border := _p(parts, root, LowPoly.box(Vector3(0.04, 0.1, run)), c + Vector3(sx * (BELT_W * 0.5 - 0.02), 0, 0) + nrm * 0.05, "bark", bark, rot)
		border.name = "BorderL" if sx < 0 else "BorderR"
	# legs at each end, longer at the high end
	for e in [-1.0, 1.0]:
		var at: Vector3 = c + dir * run * 0.5 * e
		var h: float = at.y - 0.04
		_p(parts, root, LowPoly.box(Vector3(BELT_W - 0.04, 0.1, 0.12)), Vector3(0, 0.05, at.z), "stone", stone)
		for sx in [-0.42, 0.42]:
			_p(parts, root, LowPoly.box(Vector3(0.06, h, 0.06)), Vector3(sx, h * 0.5, at.z), "", iron)
		_p(parts, root, LowPoly.cyl(0.05, 0.05, BELT_W - 0.1, 8), at + Vector3(0, -0.01, 0), "", iron, Vector3(0, 0, 90))
	# painted arrows on the belt bed show which way it runs (they glow on the hologram while you place it)
	var paint := LowPoly.mat(Color("f2c12e"), 0.6)
	var chevron := Tools.prism(PackedVector2Array([Vector2(0.0, -0.11), Vector2(0.19, 0.05), Vector2(0.12, 0.09), Vector2(0.0, -0.02), Vector2(-0.12, 0.09), Vector2(-0.19, 0.05)]), 0.006, Color("f2c12e"))
	var na := int(round(run * 2.0))
	for k in na:
		var mi := _p(parts, root, chevron, c + dir * (-run * 0.5 + run * (k + 0.5) / na) + nrm * 0.036, "", paint)
		mi.basis = Basis.from_euler(Vector3(tilt, 0, 0)) * Basis(Vector3.BACK, -PI * 0.5)
		mi.set_meta("arrow", true)
	# belt cleats: these slide along while the belt runs
	var slats := _node(root, "Slats")
	for k in int(ceil(run * 4.0)):
		var mi := LowPoly.mesh_instance(slats, LowPoly.box(Vector3(BELT_W - 0.1, 0.012, 0.03)), dark, c + dir * (-run * 0.5 + (k + 0.5) / 4.0) + nrm * 0.04, rot)
		parts.append({"mi": mi, "res": "", "real": dark})
	slats.set_meta("run", run)
	slats.set_meta("dir", dir)
	slats.set_meta("start", c - dir * run * 0.5 + nrm * 0.04)


static var _arrow: StandardMaterial3D


## The bright, unlit yellow the direction arrows have on a hologram (so you can see which way a belt will run).
static func arrow_mat() -> StandardMaterial3D:
	if _arrow == null:
		_arrow = StandardMaterial3D.new()
		_arrow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_arrow.albedo_color = Color("ffd84a")
		_arrow.render_priority = 1
	return _arrow


## A fresh body for a machine build.
static func new_body(id: String) -> Machine:
	match id:
		"crank": return Crank.new()
		"lever": return Lever.new()
		"button": return PushButton.new()
		"piston": return Piston.new()
		"rotator": return Rotator.new()
		"conveyor", "ramp": return Conveyor.new()
		"truck_caller": return TruckCaller.new()
		"windmill": return Windmill.new()
		"generator": return Generator.new()
		"battery": return Battery.new()
		"pressure_plate", "item_sensor": return Sensor.new()
		"lamp", "bell": return Lamp.new()
		"sawmill": return Sawmill.new()
		"chipper": return Chipper.new()
		"planter": return Planter.new()
		"sprinkler": return Sprinkler.new()
		"feller": return Feller.new()
	if id.begins_with("gate_"):
		return Gate.new()
	return Machine.new()


## Colliders and moving parts, once the model is built under body/Model.
static func finish(id: String, body: Machine) -> void:
	body.collision_layer = 1
	var model := body.get_node("Model") as Node3D
	if id.begins_with("gate_"):
		Builds._box_col(body, Vector3(0.7, 0.25, 0.7), Vector3(0, 0.12, 0))
	match id:
		"crank":
			Builds._box_col(body, Vector3(0.6, 0.16, 0.6), Vector3(0, 0.08, 0))
			Builds._box_col(body, Vector3(0.22, 0.85, 0.22), Vector3(0, 0.55, 0))
		"lever":
			Builds._box_col(body, Vector3(0.5, 0.2, 0.42), Vector3(0, 0.1, 0))
			Builds._box_col(body, Vector3(0.12, 0.5, 0.12), Vector3(0, 0.45, 0))
		"button":
			Builds._box_col(body, Vector3(0.3, 1.0, 0.3), Vector3(0, 0.5, 0))
		"piston":
			Builds._box_col(body, Vector3(0.8, 0.8, 1.08), Vector3(0, 0.4, 0))
			(body as Piston).setup_plate(model.get_node("Plate"))
		"rotator":
			Builds._box_col(body, Vector3(0.9, 0.3, 0.9), Vector3(0, 0.15, 0))
			(body as Rotator).setup_table(model.get_node("Table"))
		"conveyor", "ramp":
			var rise := RAMP_RISE if id == "ramp" else 0.0
			var len := RAMP_LEN if id == "ramp" else 1.0
			var tilt := atan2(rise, len)
			var run := Vector3(0, rise, -len).length()
			var c := Vector3(0, BELT_Y - 0.04 + rise * 0.5, RAMP_Z if id == "ramp" else 0.0)
			var b := Basis(Vector3.RIGHT, tilt)
			Builds._rot_col(body, Vector3(BELT_W - 0.06, 0.08, run), c, b)
			# the borders look low, but their colliders stand a little taller so things don't tip off the edge
			for sx in [-1.0, 1.0]:
				var bcs := Builds._rot_col(body, Vector3(0.04, 0.24, run), c + Vector3(sx * (BELT_W * 0.5 - 0.02), 0.08, 0), b)
				bcs.name = "BorderColL" if sx < 0 else "BorderColR"
			for e in [-1.0, 1.0]:
				var at: Vector3 = c + Vector3(0, rise, -len).normalized() * run * 0.5 * e
				Builds._box_col(body, Vector3(BELT_W - 0.04, maxf(0.1, at.y - 0.08), 0.12), Vector3(0, maxf(0.1, at.y - 0.08) * 0.5, at.z))
			var pm := PhysicsMaterial.new()
			pm.friction = 1.0
			body.physics_material_override = pm
			(body as Conveyor).setup_belt(model.get_node("Slats"), Vector3(0, rise, -len).normalized(), c, run, tilt)
		"windmill":
			Builds._box_col(body, Vector3(0.8, 0.2, 0.8), Vector3(0, 0.1, 0))
			Builds._box_col(body, Vector3(0.25, 2.6, 0.25), Vector3(0, 1.4, 0))
		"generator", "chipper", "planter":
			var hy := 0.8 if id == "generator" else (0.75 if id == "chipper" else 0.5)
			var hw := 0.75 if id == "chipper" else 0.7
			Builds._box_col(body, Vector3(0.9, hy, 0.9), Vector3(0, hy * 0.5, 0))
			for sgn in [-1.0, 1.0]:
				Builds._box_col(body, Vector3(hw + 0.1, 0.4, 0.06), Vector3(0, hy + 0.25, sgn * hw * 0.5))
				Builds._box_col(body, Vector3(0.06, 0.4, hw + 0.1), Vector3(sgn * hw * 0.5, hy + 0.25, 0))
		"battery":
			Builds._box_col(body, Vector3(0.7, 0.85, 0.5), Vector3(0, 0.42, 0))
		"pressure_plate":
			Builds._box_col(body, Vector3(0.9, 0.06, 0.9), Vector3(0, 0.03, 0))
		"item_sensor":
			Builds._box_col(body, Vector3(0.3, 0.85, 0.3), Vector3(0, 0.42, 0))
		"lamp":
			Builds._box_col(body, Vector3(0.24, 1.4, 0.24), Vector3(0, 0.7, 0))
		"bell":
			Builds._box_col(body, Vector3(0.62, 1.16, 0.12), Vector3(0, 0.58, 0))
		"sawmill":
			Builds._box_col(body, Vector3(1.0, 0.58, 1.0), Vector3(0, 0.29, 0))
			Builds._box_col(body, Vector3(0.12, 0.3, 0.9), Vector3(0.47, 0.75, 0))
		"sprinkler":
			Builds._box_col(body, Vector3(0.36, 0.7, 0.36), Vector3(0, 0.35, 0))
		"feller":
			Builds._box_col(body, Vector3(0.9, 0.3, 0.9), Vector3(0, 0.15, 0))
			Builds._box_col(body, Vector3(0.2, 1.2, 0.5), Vector3(0, 0.75, 0.1))
		"truck_caller":
			Builds._box_col(body, Vector3(0.5, 0.32, 0.5), Vector3(0, 0.16, 0))
			Builds._box_col(body, Vector3(0.16, 1.6, 0.16), Vector3(0, 1.0, 0))
			Builds._box_col(body, Vector3(0.6, 0.4, 0.06), Vector3(0, 1.54, 0.08))
	body.uid = Machine.take_uid()
	if not body.has_meta("build"):
		body.set_meta("build", {"id": id})     # (the full record is filled in by Builds.finish right after)
	body.activate(1.0)
