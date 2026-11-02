class_name Machines
extends RefCounted
## Models and finishing for the hammer's machines (crank, lever, button, piston, rotator, conveyors, truck caller).
## They always build at 1x on a 1 m grid, facing one of four directions. Their front (the way a piston pushes or a
## belt carries) is local -Z, away from you as you place them.

const IDS := ["crank", "lever", "button", "piston", "rotator", "conveyor", "ramp", "truck_caller",
	"windmill", "generator", "battery", "gate_diode", "gate_and", "gate_not", "gate_timer", "gate_delay", "gate_latch",
	"gate_counter", "pressure_plate", "item_sensor", "lamp", "bell", "sawmill", "chipper", "planter", "sprinkler", "feller",
	"smelter", "kiln", "assembler", "grabber", "sorter", "splitter", "crate", "transmitter", "receiver", "drill_rig",
	"minecart_1", "minecart_2", "minecart_3", "minecart_4", "cart_go", "cart_back", "cart_sensor", "rail_layer", "rail_lifter",
	"charger", "level_sensor", "drone_small", "drone_medium", "drone_large",
	"rail_switch", "rail_buffer", "cart_unloader", "drone_pad", "oil_pump", "refinery"]
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
		"smelter":
			_p(parts, root, LowPoly.box(Vector3(0.9, 0.75, 0.9)), Vector3(0, 0.375, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.36, 0.26, 0.04)), Vector3(0, 0.3, -0.46), "", LowPoly.mat(Color("ff8a3d"), 0.4, 1.5))
			_p(parts, root, LowPoly.box(Vector3(0.92, 0.06, 0.92)), Vector3(0, 0.72, 0), "iron", iron)
			_hopper(root, parts, 0.75, 0.75, stone)
			_p(parts, root, LowPoly.cyl(0.08, 0.1, 0.9, 8), Vector3(0.3, 1.2, 0.3), "stone", stone)
		"kiln":
			_p(parts, root, LowPoly.box(Vector3(0.9, 0.75, 0.9)), Vector3(0, 0.375, 0), "stone", stone)
			_p(parts, root, LowPoly.cyl(0.42, 0.42, 0.2, 10), Vector3(0, 0.62, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.4, 0.22, 0.04)), Vector3(0, 0.25, -0.46), "", LowPoly.mat(Color("d9783a"), 0.5, 0.6))
			_hopper(root, parts, 0.75, 0.75, bark)
		"assembler":
			_p(parts, root, LowPoly.box(Vector3(0.9, 0.7, 0.9)), Vector3(0, 0.35, 0), "log", logm)
			_p(parts, root, LowPoly.box(Vector3(0.94, 0.06, 0.94)), Vector3(0, 0.72, 0), "copper", copper)
			_hopper(root, parts, 0.75, 0.75, bark)
			for sx in [-0.3, 0.3]:
				_p(parts, root, LowPoly.box(Vector3(0.06, 0.06, 0.4)), Vector3(sx, 0.55, -0.48), "", iron)
			_p(parts, root, LowPoly.box(Vector3(0.18, 0.18, 0.04)), Vector3(0, 0.45, -0.46), "", red)
		"grabber":
			_p(parts, root, LowPoly.cyl(0.32, 0.36, 0.25, 10), Vector3(0, 0.125, 0), "stone", stone)
			_p(parts, root, LowPoly.cyl(0.1, 0.1, 0.5, 8), Vector3(0, 0.5, 0), "iron", iron)
			var arm := _node(root, "Arm", Vector3(0, 0.8, 0))
			_p(parts, arm, LowPoly.box(Vector3(0.1, 0.1, 0.9)), Vector3(0, 0, -0.45), "copper", copper)
			_p(parts, arm, LowPoly.box(Vector3(0.28, 0.06, 0.06)), Vector3(0, -0.06, -0.9), "", dark)
			for sx in [-0.12, 0.12]:
				_p(parts, arm, LowPoly.box(Vector3(0.03, 0.2, 0.05)), Vector3(sx, -0.16, -0.9), "", dark)
			var paint := LowPoly.mat(Color("f2c12e"), 0.6)
			_p(parts, root, LowPoly.box(Vector3(0.06, 0.01, 0.5)), Vector3(0, 0.255, 0), "", paint)
		"sorter", "splitter":
			_belt(root, parts, 1.0, 0.0, bark, stone, iron, dark)
			_p(parts, root, LowPoly.box(Vector3(0.05, 0.9, 0.05)), Vector3(0.47, 0.75, 0.4), "", iron)
			_p(parts, root, LowPoly.box(Vector3(0.02, 0.18, 0.28)), Vector3(0.47, 1.1, 0.27), "", LowPoly.mat(Color("3f8ee8") if id == "sorter" else Color("9b6ad6"), 0.6))
		"crate":
			_p(parts, root, LowPoly.box(Vector3(1.0, 0.1, 1.0)), Vector3(0, 0.05, 0), "log", logm)
			for k in 3:
				var side := [Vector3(0, 0, 0.47), Vector3(0.47, 0, 0), Vector3(-0.47, 0, 0)][k] as Vector3
				var sz := Vector3(1.0, 0.95, 0.06) if k == 0 else Vector3(0.06, 0.95, 1.0)
				_p(parts, root, LowPoly.box(sz), side + Vector3(0, 0.525, 0), "plank", logm)
			var door := _node(root, "Door", Vector3(0, 0.3, -0.47))
			_p(parts, door, LowPoly.box(Vector3(0.9, 0.5, 0.06)), Vector3.ZERO, "", iron)
			_p(parts, root, LowPoly.box(Vector3(1.0, 0.45, 0.06)), Vector3(0, 0.78, -0.47), "plank", logm)
		"transmitter", "receiver":
			_p(parts, root, LowPoly.box(Vector3(0.4, 0.2, 0.4)), Vector3(0, 0.1, 0), "stone", stone)
			_p(parts, root, LowPoly.cyl(0.03, 0.04, 1.2 if id == "transmitter" else 0.7, 6), Vector3(0, 0.8 if id == "transmitter" else 0.55, 0), "copper", copper)
			var gem := _p(parts, root, LowPoly.box(Vector3(0.12, 0.12, 0.12)), Vector3(0, 1.45 if id == "transmitter" else 0.95, 0), "", LowPoly.mat(Color.WHITE))
			gem.name = "Gem"
			if id == "receiver":
				_p(parts, root, LowPoly.cyl(0.22, 0.05, 0.12, 10), Vector3(0, 0.82, 0), "", iron)
		"minecart_1", "minecart_2", "minecart_3", "minecart_4":
			_minecart(root, parts, int(id.trim_prefix("minecart_")), logm, iron, copper, dark)
		"cart_go", "cart_back":
			_p(parts, root, LowPoly.box(Vector3(0.5, 0.16, 0.5)), Vector3(0, 0.08, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.44, 0.06, 0.44)), Vector3(0, 0.19, 0), "copper_bar", copper)
			var col := LowPoly.mat(Color("3fbf5f") if id == "cart_go" else Color("e8503a"), 0.5)
			var sgn := 1.0 if id == "cart_go" else -1.0
			_p(parts, root, LowPoly.box(Vector3(0.08, 0.04, 0.24)), Vector3(0, 0.24, 0.06 * sgn), "", col)
			_p(parts, root, LowPoly.box(Vector3(0.08, 0.04, 0.18)), Vector3(-0.06, 0.24, -0.1 * sgn), "", col, Vector3(0, -40.0 * sgn, 0))
			_p(parts, root, LowPoly.box(Vector3(0.08, 0.04, 0.18)), Vector3(0.06, 0.24, -0.1 * sgn), "", col, Vector3(0, 40.0 * sgn, 0))
		"cart_sensor":
			_p(parts, root, LowPoly.box(Vector3(0.36, 0.12, 0.36)), Vector3(0, 0.06, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.1, 0.6, 0.1)), Vector3(0, 0.42, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.26, 0.14, 0.12)), Vector3(0, 0.75, 0), "copper_bar", copper)
			_p(parts, root, LowPoly.box(Vector3(0.05, 0.05, 0.4)), Vector3(0, 0.75, -0.25), "", LowPoly.mat(Color("f2c12e"), 0.5))
		"rail_layer", "rail_lifter":
			_p(parts, root, LowPoly.box(Vector3(0.7, 0.2, 0.6)), Vector3(0, 0.1, 0), "stone", stone)
			for sx in [-0.3, 0.3]:
				_p(parts, root, LowPoly.box(Vector3(0.08, 0.6, 0.08)), Vector3(sx, 0.5, 0), "iron_bar", iron)
			_p(parts, root, LowPoly.box(Vector3(0.7, 0.08, 0.08)), Vector3(0, 0.82, 0), "iron_bar", iron)
			var arm := _node(root, "Arm", Vector3(0, 0.78, 0))
			var dz := -0.45 if id == "rail_layer" else 0.45
			_p(parts, arm, LowPoly.box(Vector3(0.08, 0.08, 0.5)), Vector3(0, 0, dz * 0.5), "copper_bar", copper)
			if id == "rail_layer":
				for sx in [-0.15, 0.15]:
					_p(parts, arm, LowPoly.box(Vector3(0.04, 0.05, 0.4)), Vector3(sx, -0.08, dz), "", Tools.steel(Color("8d949e"), 0.4))
				_p(parts, arm, LowPoly.box(Vector3(0.42, 0.04, 0.08)), Vector3(0, -0.12, dz), "", logm)
			else:
				for sx in [-0.1, 0.1]:
					_p(parts, arm, LowPoly.box(Vector3(0.04, 0.22, 0.04)), Vector3(sx, -0.12, dz), "", dark)
					_p(parts, arm, LowPoly.box(Vector3(0.04, 0.04, 0.1)), Vector3(sx, -0.22, dz - 0.04), "", dark)
		"charger":
			_p(parts, root, LowPoly.box(Vector3(0.8, 0.5, 0.8)), Vector3(0, 0.25, 0), "stone", stone)
			for k in 3:
				_p(parts, root, LowPoly.cyl(0.32, 0.32, 0.04, 12), Vector3(0, 0.12 + k * 0.12, 0), "copper_bar", copper)
			for sx in [-1.0, 1.0]:
				_p(parts, root, LowPoly.box(Vector3(0.8, 0.18, 0.05)), Vector3(0, 0.59, sx * 0.38), "iron_bar", iron)
				_p(parts, root, LowPoly.box(Vector3(0.05, 0.18, 0.8)), Vector3(sx * 0.38, 0.59, 0), "iron_bar", iron)
			_p(parts, root, LowPoly.box(Vector3(0.7, 0.02, 0.7)), Vector3(0, 0.51, 0), "", LowPoly.mat(Color("3fbf5f"), 0.6))
		"level_sensor":
			_p(parts, root, LowPoly.box(Vector3(0.36, 0.12, 0.36)), Vector3(0, 0.06, 0), "stone", stone)
			_p(parts, root, LowPoly.cyl(0.05, 0.06, 0.4, 8), Vector3(0, 0.3, 0), "log", logm)
			_p(parts, root, LowPoly.box(Vector3(0.34, 0.3, 0.1)), Vector3(0, 0.6, 0), "copper", copper)
			_p(parts, root, LowPoly.box(Vector3(0.28, 0.24, 0.02)), Vector3(0, 0.6, 0.055), "", LowPoly.mat(Color("e8e2d0"), 0.8))
			var needle := _node(root, "Needle", Vector3(0, 0.52, 0.07))
			_p(parts, needle, LowPoly.box(Vector3(0.02, 0.18, 0.01)), Vector3(0, 0.09, 0), "", red)
		"drone_small", "drone_medium", "drone_large":
			_drone(root, parts, float(Drone.SIZES[id].w), logm, iron, copper, dark)
		"rail_switch":
			_p(parts, root, LowPoly.box(Vector3(0.4, 0.2, 0.5)), Vector3(0, 0.1, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.3, 0.06, 0.4)), Vector3(0, 0.23, 0), "copper_bar", copper)
			var sarm := _node(root, "Arm", Vector3(0, 0.24, 0))
			_p(parts, sarm, LowPoly.box(Vector3(0.05, 0.55, 0.05)), Vector3(0, 0.27, 0), "iron_bar", iron)
			_p(parts, sarm, LowPoly.box(Vector3(0.1, 0.1, 0.1)), Vector3(0, 0.56, 0), "", red)
			_p(parts, root, LowPoly.box(Vector3(0.06, 0.03, 0.3)), Vector3(0, 0.27, -0.12), "", LowPoly.mat(Color("f2c12e"), 0.5))
		"rail_buffer":
			_p(parts, root, LowPoly.box(Vector3(0.3, 0.2, 0.3)), Vector3(0, 0.1, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.12, 0.7, 0.12)), Vector3(0, 0.55, 0), "iron_bar", iron)
			var barm := _node(root, "Arm", Vector3(0, 0.75, -0.1))
			for k in 6:
				_p(parts, barm, LowPoly.box(Vector3(0.06, 0.12, 0.2)), Vector3(0, 0, -0.1 - k * 0.2), "log" if k % 2 == 0 else "", logm if k % 2 == 0 else red)
		"cart_unloader":
			_p(parts, root, LowPoly.box(Vector3(0.8, 0.3, 0.6)), Vector3(0, 0.15, 0), "stone", stone)
			for sx in [-0.35, 0.35]:
				_p(parts, root, LowPoly.box(Vector3(0.08, 1.1, 0.08)), Vector3(sx, 0.85, 0.2), "iron_bar", iron)
			_p(parts, root, LowPoly.box(Vector3(0.78, 0.08, 0.08)), Vector3(0, 1.4, 0.2), "iron_bar", iron)
			_p(parts, root, LowPoly.box(Vector3(0.08, 0.08, 0.9)), Vector3(0, 1.32, 0.45), "copper_bar", copper)
			_p(parts, root, LowPoly.box(Vector3(0.3, 0.06, 0.06)), Vector3(0, 1.22, 0.85), "", dark)
			_p(parts, root, LowPoly.box(Vector3(0.6, 0.04, 0.5)), Vector3(0, 0.45, -0.45), "", logm, Vector3(-20, 0, 0))
		"drone_pad":
			_p(parts, root, LowPoly.box(Vector3(1.0, 0.1, 1.0)), Vector3(0, 0.05, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.8, 0.02, 0.8)), Vector3(0, 0.11, 0), "copper_bar", copper)
			var yel := LowPoly.mat(Color("f2c12e"), 0.5)
			_p(parts, root, LowPoly.box(Vector3(0.08, 0.025, 0.5)), Vector3(-0.15, 0.125, 0), "", yel)
			_p(parts, root, LowPoly.box(Vector3(0.08, 0.025, 0.5)), Vector3(0.15, 0.125, 0), "", yel)
			_p(parts, root, LowPoly.box(Vector3(0.3, 0.025, 0.08)), Vector3(0, 0.125, 0), "", yel)
		"oil_pump":
			# a pumpjack: a frame, a nodding walking beam with a horse head, and the wellhead below the head
			_p(parts, root, LowPoly.box(Vector3(0.9, 0.12, 1.0)), Vector3(0, 0.06, 0), "stone", stone)
			for sx in [-0.18, 0.18]:
				var post := _p(parts, root, LowPoly.box(Vector3(0.07, 1.2, 0.07)), Vector3(sx, 0.66, 0.08), "iron_bar", iron)
				post.rotation.x = deg_to_rad(-8.0)
			_p(parts, root, LowPoly.box(Vector3(0.3, 0.3, 0.3)), Vector3(0, 0.27, 0.32), "copper_bar", copper)
			var beam := _node(root, "Beam", Vector3(0, 1.22, 0.0))
			_p(parts, beam, LowPoly.box(Vector3(0.1, 0.1, 1.1)), Vector3(0, 0, -0.05), "iron_bar", iron)
			_p(parts, beam, LowPoly.box(Vector3(0.14, 0.32, 0.12)), Vector3(0, -0.08, -0.6), "", LowPoly.mat(Color("f2c12e"), 0.5))
			_p(parts, beam, LowPoly.box(Vector3(0.16, 0.18, 0.22)), Vector3(0, -0.05, 0.42), "", dark)
			_p(parts, root, LowPoly.cyl(0.07, 0.09, 0.3, 8), Vector3(0, 0.27, -0.6), "", iron)
			_p(parts, root, LowPoly.cyl(0.015, 0.015, 0.75, 6), Vector3(0, 0.75, -0.6), "", dark)
			_p(parts, root, LowPoly.box(Vector3(0.36, 0.04, 0.4)), Vector3(0, 0.3, -0.78), "", logm, Vector3(-18, 0, 0))
		"refinery":
			_p(parts, root, LowPoly.box(Vector3(0.9, 0.75, 0.9)), Vector3(0, 0.375, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.92, 0.06, 0.92)), Vector3(0, 0.72, 0), "iron_bar", iron)
			_hopper(root, parts, 0.75, 0.75, iron)
			_p(parts, root, LowPoly.cyl(0.12, 0.12, 1.3, 10), Vector3(0.36, 1.4, 0.36), "copper_bar", copper)
			_p(parts, root, LowPoly.cyl(0.05, 0.06, 0.8, 8), Vector3(-0.36, 1.15, 0.36), "iron_bar", iron)
			_p(parts, root, LowPoly.box(Vector3(0.3, 0.2, 0.04)), Vector3(0, 0.3, -0.46), "", LowPoly.mat(Color("5cc8e0"), 0.4))
		"drill_rig":
			_p(parts, root, LowPoly.box(Vector3(1.0, 0.12, 1.0)), Vector3(0, 0.06, 0), "stone", stone)
			for k in 4:
				var c := Vector3(0.42 if k & 1 else -0.42, 0, 0.42 if k & 2 else -0.42)
				var leg := _p(parts, root, LowPoly.box(Vector3(0.07, 2.1, 0.07)), c * 0.5 + Vector3(0, 1.05, 0), "iron", iron)
				leg.rotation = Vector3(-c.z * 0.4, 0, c.x * 0.4)
			_p(parts, root, LowPoly.box(Vector3(0.3, 0.2, 0.3)), Vector3(0, 2.05, 0), "copper", copper)
			_p(parts, root, LowPoly.cyl(0.03, 0.03, 1.6, 6), Vector3(0, 1.2, 0), "", dark)
			var bit := _node(root, "Bit", Vector3(0, 0.4, 0))
			_p(parts, bit, LowPoly.cyl(0.0, 0.1, 0.35, 6), Vector3(0, 0, 0), "", iron, Vector3(180, 0, 0))
			for k in 3:
				_p(parts, bit, LowPoly.box(Vector3(0.2, 0.02, 0.04)), Vector3(0, 0.05 + k * 0.08, 0), "", copper, Vector3(0, k * 60.0, 0))
			_p(parts, root, LowPoly.box(Vector3(0.4, 0.04, 0.5)), Vector3(0, 0.5, -0.6), "", logm, Vector3(-30, 0, 0))
		"bark_wreath":
			# a ring of bark on a little easel
			for sx in [-0.18, 0.18]:
				_p(parts, root, LowPoly.box(Vector3(0.05, 0.95, 0.05)), Vector3(sx, 0.47, 0.06), "", logm, Vector3(-8, 0, sx * -30.0))
			for k in 12:
				var a := TAU * k / 12.0
				var piece := _p(parts, root, LowPoly.box(Vector3(0.16, 0.08, 0.05)), Vector3(cos(a) * 0.26, 0.95 + sin(a) * 0.26, 0), "bark", bark)
				piece.rotation.z = a + PI * 0.5
			_p(parts, root, LowPoly.box(Vector3(0.12, 0.1, 0.06)), Vector3(0, 1.22, 0.01), "", red)
		"lamppost":
			_p(parts, root, LowPoly.box(Vector3(0.4, 0.25, 0.4)), Vector3(0, 0.125, 0), "stone", stone)
			_p(parts, root, LowPoly.cyl(0.05, 0.06, 2.2, 8), Vector3(0, 1.35, 0), "iron_bar", iron)
			_p(parts, root, LowPoly.box(Vector3(0.6, 0.05, 0.05)), Vector3(0.22, 2.4, 0), "iron_bar", iron)
			_p(parts, root, LowPoly.box(Vector3(0.18, 0.26, 0.18)), Vector3(0.48, 2.25, 0), "copper_bar", copper)
			_p(parts, root, LowPoly.box(Vector3(0.12, 0.18, 0.12)), Vector3(0.48, 2.25, 0), "", LowPoly.mat(Color("ffd68a"), 0.3, 2.0))
		"garden_table":
			_p(parts, root, LowPoly.box(Vector3(1.4, 0.07, 0.8)), Vector3(0, 0.75, 0), "plank", logm)
			for k in 4:
				_p(parts, root, LowPoly.box(Vector3(0.06, 0.72, 0.06)), Vector3(0.62 if k & 1 else -0.62, 0.36, 0.34 if k & 2 else -0.34), "iron_bar", iron)
			for sz in [-0.65, 0.65]:
				_p(parts, root, LowPoly.box(Vector3(1.3, 0.05, 0.28)), Vector3(0, 0.45, sz), "plank", logm)
		"statue":
			_p(parts, root, LowPoly.box(Vector3(0.9, 0.5, 0.9)), Vector3(0, 0.25, 0), "stone", stone)
			_p(parts, root, LowPoly.box(Vector3(0.4, 0.7, 0.28)), Vector3(0, 0.95, 0), "copper_bar", copper)
			_p(parts, root, LowPoly.box(Vector3(0.24, 0.24, 0.24)), Vector3(0, 1.45, 0), "copper_bar", copper)
			_p(parts, root, LowPoly.box(Vector3(0.12, 0.55, 0.12)), Vector3(0.28, 1.0, -0.05), "copper_bar", copper, Vector3(0, 0, -25))
			_p(parts, root, LowPoly.cyl(0.03, 0.03, 0.9, 6), Vector3(-0.32, 1.1, 0), "copper_bar", copper)
			_p(parts, root, LowPoly.box(Vector3(0.05, 0.2, 0.22)), Vector3(-0.32, 1.55, -0.08), "copper_bar", copper)
		"fountain":
			_p(parts, root, LowPoly.cyl(0.9, 1.0, 0.4, 12), Vector3(0, 0.2, 0), "stone", stone)
			var water := StandardMaterial3D.new()
			water.albedo_color = Color(0.35, 0.6, 0.85, 0.8)
			water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_p(parts, root, LowPoly.cyl(0.8, 0.8, 0.05, 12), Vector3(0, 0.38, 0), "", water)
			_p(parts, root, LowPoly.cyl(0.12, 0.16, 0.9, 8), Vector3(0, 0.8, 0), "copper_bar", copper)
			_p(parts, root, LowPoly.cyl(0.4, 0.3, 0.12, 10), Vector3(0, 1.25, 0), "iron_bar", iron)
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
## A minecart: an iron frame on four wheels with a plank deck, `n` grid squares long (from its front square back),
## and a little cradle for the battery cell hanging off the back.
static func _minecart(root: Node3D, parts: Array, n: int, logm: Material, iron: Material, copper: Material, dark: Material) -> void:
	var mid := (n - 1) * 0.5
	_p(parts, root, LowPoly.box(Vector3(0.9, 0.08, n - 0.1)), Vector3(0, 0.41, mid), "plank", logm)
	for sx in [-0.44, 0.44]:
		_p(parts, root, LowPoly.box(Vector3(0.06, 0.16, n - 0.06)), Vector3(sx, 0.33, mid), "iron_bar", iron)
	for k in n:
		_p(parts, root, LowPoly.box(Vector3(0.82, 0.08, 0.08)), Vector3(0, 0.29, k), "iron_bar", iron)
		for sx in [-0.25, 0.25]:
			_p(parts, root, LowPoly.cyl(0.1, 0.1, 0.06, 10), Vector3(sx, 0.13, k), "", dark, Vector3(0, 0, 90))
	_p(parts, root, LowPoly.box(Vector3(0.36, 0.04, 0.34)), Vector3(0, 0.24, n - 0.28), "copper_bar", copper)
	for sx in [-0.17, 0.17]:
		_p(parts, root, LowPoly.box(Vector3(0.03, 0.14, 0.34)), Vector3(sx, 0.31, n - 0.28), "copper_bar", copper)
	_p(parts, root, LowPoly.box(Vector3(0.36, 0.14, 0.03)), Vector3(0, 0.31, n - 0.11), "copper_bar", copper)


## A drone: a flat body with four arms and rotors, a pad underneath, the battery cradle on its back, and five dials
## (front, right, back, left, and the pad dial on top) that light up in their wireless channel's colour.
static func _drone(root: Node3D, parts: Array, w: float, logm: Material, iron: Material, copper: Material, dark: Material) -> void:
	var h := w * 0.5
	_p(parts, root, LowPoly.box(Vector3(w, 0.16, w)), Vector3(0, 0.16, 0), "iron_bar", iron)
	_p(parts, root, LowPoly.box(Vector3(w * 0.8, 0.04, w * 0.8)), Vector3(0, 0.06, 0), "plank", logm)
	for k in 4:
		var o := Vector3(1.0 if k & 1 else -1.0, 0, 1.0 if k & 2 else -1.0) * (h + 0.12)
		var arm := _p(parts, root, LowPoly.box(Vector3(0.06, 0.05, (h + 0.12) * 1.41)), o * 0.5 + Vector3(0, 0.2, 0), "copper_bar", copper)
		arm.rotation.y = atan2(o.x, o.z)
		_p(parts, root, LowPoly.cyl(0.05, 0.06, 0.1, 8), o + Vector3(0, 0.24, 0), "copper_bar", copper)
		var rotor := _node(root, "Rotor%d" % k, o + Vector3(0, 0.3, 0))
		_p(parts, rotor, LowPoly.box(Vector3(0.05, 0.015, w * 0.55)), Vector3.ZERO, "", dark)
		_p(parts, rotor, LowPoly.box(Vector3(w * 0.55, 0.015, 0.05)), Vector3.ZERO, "", dark)
	# the cradle for the cell
	_p(parts, root, LowPoly.box(Vector3(0.28, 0.03, 0.28)), Vector3(0, 0.255, h - 0.12), "", dark)
	for i in 5:
		var at: Vector3
		match i:
			0: at = Vector3(0, 0.18, -h - 0.02)
			1: at = Vector3(h + 0.02, 0.18, 0)
			2: at = Vector3(-0.15, 0.18, h + 0.02)
			3: at = Vector3(-h - 0.02, 0.18, 0)
			_: at = Vector3(-0.12, 0.27, -0.05)
		var d := _p(parts, root, LowPoly.cyl(0.045, 0.045, 0.04, 8), at, "", dark, Vector3(0, 0, 0) if i == 4 else (Vector3(90, 0, 0) if i % 2 == 0 else Vector3(0, 0, 90)))
		d.name = "Dial%d" % i


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
		border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # paper-thin: no shadow worth drawing
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
		"smelter", "kiln", "assembler", "refinery": return Processor.new()
		"oil_pump": return OilPump.new()
		"grabber": return Grabber.new()
		"sorter", "splitter": return Sorter.new()
		"crate": return Crate.new()
		"transmitter", "receiver": return Wireless.new()
		"drill_rig": return DrillRig.new()
		"minecart_1", "minecart_2", "minecart_3", "minecart_4": return Minecart.new()
		"cart_go", "cart_back", "rail_layer", "rail_lifter": return CartPart.new()
		"cart_sensor", "level_sensor": return Sensor.new()
		"charger": return Charger.new()
		"drone_small", "drone_medium", "drone_large": return Drone.new()
		"rail_switch", "rail_buffer", "cart_unloader", "drone_pad": return TrackPart.new()
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
		"conveyor", "ramp", "sorter", "splitter":
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
		"generator", "chipper", "planter", "smelter", "kiln", "assembler", "refinery":
			var hy := 0.8 if id == "generator" else (0.5 if id == "planter" else 0.75)
			var hw := 0.7 if id == "generator" or id == "planter" else 0.75
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
		"grabber":
			Builds._box_col(body, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0))
		"crate":
			Builds._box_col(body, Vector3(1.0, 0.1, 1.0), Vector3(0, 0.05, 0))
			Builds._box_col(body, Vector3(1.0, 1.0, 0.08), Vector3(0, 0.5, 0.47))
			for sgn in [-1.0, 1.0]:
				Builds._box_col(body, Vector3(0.08, 1.0, 1.0), Vector3(sgn * 0.47, 0.5, 0))
			Builds._box_col(body, Vector3(1.0, 0.45, 0.08), Vector3(0, 0.78, -0.47))
			var door := Builds._rot_col(body, Vector3(1.0, 0.56, 0.08), Vector3(0, 0.28, -0.47), Basis())
			door.name = "DoorCol"
		"transmitter", "receiver":
			Builds._box_col(body, Vector3(0.4, 1.0, 0.4), Vector3(0, 0.5, 0))
		"drill_rig":
			Builds._box_col(body, Vector3(1.0, 0.12, 1.0), Vector3(0, 0.06, 0))
			Builds._box_col(body, Vector3(0.4, 2.1, 0.4), Vector3(0, 1.1, 0))
		"minecart_1", "minecart_2", "minecart_3", "minecart_4":
			var n := int(id.trim_prefix("minecart_"))
			Builds._box_col(body, Vector3(0.9, 0.24, n - 0.1), Vector3(0, Minecart.DECK_Y - 0.12, (n - 1) * 0.5))
			Builds._box_col(body, Vector3(0.36, 0.04, 0.34), Vector3(0, 0.24, n - 0.28))
			for sx in [-0.17, 0.17]:
				Builds._box_col(body, Vector3(0.03, 0.2, 0.34), Vector3(sx, 0.34, n - 0.28))
			Builds._box_col(body, Vector3(0.36, 0.2, 0.03), Vector3(0, 0.34, n - 0.11))
		"cart_go", "cart_back":
			Builds._box_col(body, Vector3(0.5, 0.26, 0.5), Vector3(0, 0.13, 0))
		"cart_sensor", "level_sensor":
			Builds._box_col(body, Vector3(0.36, 0.8, 0.36), Vector3(0, 0.4, 0))
		"rail_layer", "rail_lifter":
			Builds._box_col(body, Vector3(0.7, 0.86, 0.6), Vector3(0, 0.43, 0))
		"charger":
			Builds._box_col(body, Vector3(0.8, 0.5, 0.8), Vector3(0, 0.25, 0))
			for sgn in [-1.0, 1.0]:
				Builds._box_col(body, Vector3(0.8, 0.2, 0.05), Vector3(0, 0.6, sgn * 0.38))
				Builds._box_col(body, Vector3(0.05, 0.2, 0.8), Vector3(sgn * 0.38, 0.6, 0))
		"drone_small", "drone_medium", "drone_large":
			var dw := float(Drone.SIZES[id].w)
			Builds._box_col(body, Vector3(dw, 0.2, dw), Vector3(0, 0.14, 0))
		"rail_switch":
			Builds._box_col(body, Vector3(0.4, 0.3, 0.5), Vector3(0, 0.15, 0))
		"rail_buffer":
			Builds._box_col(body, Vector3(0.3, 0.9, 0.3), Vector3(0, 0.45, 0))
		"cart_unloader":
			Builds._box_col(body, Vector3(0.8, 0.3, 0.6), Vector3(0, 0.15, 0))
			Builds._box_col(body, Vector3(0.8, 1.45, 0.12), Vector3(0, 0.72, 0.2))
		"drone_pad":
			Builds._box_col(body, Vector3(1.0, 0.12, 1.0), Vector3(0, 0.06, 0))
		"oil_pump":
			Builds._box_col(body, Vector3(0.9, 0.12, 1.0), Vector3(0, 0.06, 0))
			Builds._box_col(body, Vector3(0.4, 1.3, 0.3), Vector3(0, 0.65, 0.1))
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
	body.make_port()
