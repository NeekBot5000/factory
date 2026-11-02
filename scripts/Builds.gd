class_name Builds
extends RefCounted
## Things the hammer can build, and their models. Every model is built from parts; a part either needs a
## resource ("bark" = one panel of any bark, "log" = any log) and takes that material's colour when it is
## filled in, or is a finishing part that appears when the build completes.

const BUILDS := {
	"basket": {"name": "Bark Basket", "needs": {"bark": 50}},
	"wheelbarrow": {"name": "Wheelbarrow", "needs": {"bark": 24, "log": 1, "stone": 2}, "bp": "bp_wheelbarrow"},
	"bench": {"name": "Log Bench", "needs": {"log": 1, "bark": 6}, "sell": 2.5},
	"campfire": {"name": "Campfire", "needs": {"bark": 6, "leaf": 10}, "sell": 2.5},
	"hammock": {"name": "Leaf Hammock", "needs": {"log": 2, "leaf": 30}, "sell": 2.5},
	"chute": {"name": "Bark Chute", "needs": {"log": 3, "bark": 12}},
	"rack": {"name": "Log Rack", "needs": {"log": 4}},
	"compost": {"name": "Compost Pile", "needs": {"leaf": 40}},
	"ball": {"name": "Basketball", "needs": {"leaf": 8}, "sell": 2.0},
	"hoop": {"name": "Basketball Hoop", "needs": {"bark": 12, "log": 1}, "sell": 2.5},
	"catapult": {"name": "Catapult", "needs": {"log": 3, "bark": 10, "leaf": 6}},
	# machines: you need the blueprint from TimberMart first ("bp"); they build at 1x on a grid. The simple ones
	# take stone and copper; the advanced ones (piston, rotator, truck caller) need iron ore too
	"crank": {"name": "Hand Crank", "needs": {"stone": 4, "log": 1, "copper": 1}, "bp": "bp_crank"},
	"lever": {"name": "Lever", "needs": {"stone": 2, "copper": 1}, "bp": "bp_lever"},
	"button": {"name": "Push Button", "needs": {"log": 1, "stone": 2, "copper": 1}, "bp": "bp_button"},
	"piston": {"name": "Piston", "needs": {"stone": 6, "iron": 3, "copper": 2}, "bp": "bp_piston"},
	"rotator": {"name": "Rotator", "needs": {"stone": 4, "iron": 2, "copper": 1, "log": 1}, "bp": "bp_rotator"},
	"conveyor": {"name": "Conveyor", "needs": {"bark": 5, "stone": 2}, "bp": "bp_conveyor"},
	"ramp": {"name": "Ramp Conveyor", "needs": {"bark": 8, "stone": 2}, "bp": "bp_ramp"},
	"pillar": {"name": "Stone Pillar", "needs": {"stone": 4}},
	"truck_caller": {"name": "Truck Caller", "needs": {"stone": 3, "log": 1, "copper": 3, "iron": 2}, "bp": "bp_truck_caller"},
	# power
	"windmill": {"name": "Windmill", "needs": {"log": 2, "bark": 10, "stone": 4, "copper": 2}, "bp": "bp_windmill"},
	"generator": {"name": "Generator", "needs": {"stone": 8, "iron": 2, "copper": 2, "bark": 4}, "bp": "bp_generator"},
	"battery": {"name": "Battery", "needs": {"stone": 2, "copper": 4, "iron": 2}, "bp": "bp_battery"},
	# logic (one kit unlocks them all)
	"gate_diode": {"name": "One-Way", "needs": {"stone": 2, "copper": 1}, "bp": "bp_logic"},
	"gate_and": {"name": "Relay", "needs": {"stone": 2, "copper": 1}, "bp": "bp_logic"},
	"gate_not": {"name": "Inverting Relay", "needs": {"stone": 2, "copper": 1}, "bp": "bp_logic"},
	"gate_timer": {"name": "Timer", "needs": {"stone": 2, "copper": 1}, "bp": "bp_logic"},
	"gate_delay": {"name": "Delay", "needs": {"stone": 2, "copper": 1}, "bp": "bp_logic"},
	"gate_latch": {"name": "Toggle Latch", "needs": {"stone": 2, "copper": 1}, "bp": "bp_logic"},
	"gate_counter": {"name": "Counter", "needs": {"stone": 2, "copper": 1}, "bp": "bp_logic"},
	"pressure_plate": {"name": "Pressure Plate", "needs": {"stone": 2, "log": 1, "copper": 1}, "bp": "bp_sensors"},
	"item_sensor": {"name": "Item Sensor", "needs": {"stone": 1, "log": 1, "copper": 2}, "bp": "bp_sensors"},
	"lamp": {"name": "Lamp", "needs": {"stone": 1, "log": 1, "copper": 1}, "bp": "bp_lamp"},
	"bell": {"name": "Bell", "needs": {"log": 2, "copper": 2}, "bp": "bp_lamp"},
	# production and the tree farm
	"sawmill": {"name": "Sawmill", "needs": {"stone": 6, "iron": 3, "log": 1}, "bp": "bp_sawmill"},
	"chipper": {"name": "Chipper", "needs": {"stone": 4, "iron": 2, "copper": 1, "bark": 6}, "bp": "bp_chipper"},
	"planter": {"name": "Planter", "needs": {"stone": 4, "bark": 6, "log": 1, "copper": 1}, "bp": "bp_planter"},
	"sprinkler": {"name": "Sprinkler", "needs": {"stone": 1, "copper": 2}, "bp": "bp_sprinkler"},
	"feller": {"name": "Tree Feller", "needs": {"stone": 6, "iron": 3, "log": 1, "copper": 1}, "bp": "bp_feller"},
	"smelter": {"name": "Smelter", "needs": {"stone": 10, "iron": 2}, "bp": "bp_smelter"},
	"kiln": {"name": "Kiln", "needs": {"stone": 8, "copper": 1}, "bp": "bp_kiln"},
	"assembler": {"name": "Assembler", "needs": {"plank": 6, "iron_bar": 2, "copper_bar": 2}, "bp": "bp_assembler"},
	# logistics
	"grabber": {"name": "Grabber Arm", "needs": {"stone": 3, "iron": 2, "copper": 2}, "bp": "bp_grabber"},
	"sorter": {"name": "Sorter Belt", "needs": {"bark": 5, "stone": 2, "copper": 1}, "bp": "bp_sorter"},
	"splitter": {"name": "Splitter Belt", "needs": {"bark": 5, "stone": 2, "copper": 1}, "bp": "bp_sorter"},
	"crate": {"name": "Storage Crate", "needs": {"plank": 8, "log": 1, "iron": 1}, "bp": "bp_crate"},
	"drill_rig": {"name": "Drill Rig", "needs": {"stone": 6, "iron": 4, "copper": 2, "log": 2}, "bp": "bp_drill_rig"},
	"transmitter": {"name": "Transmitter", "needs": {"stone": 2, "copper_bar": 2}, "bp": "bp_wireless"},
	"receiver": {"name": "Receiver", "needs": {"stone": 2, "copper_bar": 2}, "bp": "bp_wireless"},
	# rails and carts
	"minecart_1": {"name": "Minecart (1 long)", "needs": {"iron_bar": 2, "plank": 2, "copper_bar": 1}, "bp": "bp_carts"},
	"minecart_2": {"name": "Minecart (2 long)", "needs": {"iron_bar": 3, "plank": 4, "copper_bar": 1}, "bp": "bp_carts"},
	"minecart_3": {"name": "Minecart (3 long)", "needs": {"iron_bar": 4, "plank": 6, "copper_bar": 2}, "bp": "bp_carts"},
	"minecart_4": {"name": "Minecart (4 long)", "needs": {"iron_bar": 5, "plank": 8, "copper_bar": 2}, "bp": "bp_carts"},
	"cart_go": {"name": "Go", "needs": {"stone": 1, "copper_bar": 1}, "bp": "bp_carts"},
	"cart_back": {"name": "Reverse", "needs": {"stone": 1, "copper_bar": 1}, "bp": "bp_carts"},
	"cart_sensor": {"name": "Cart Sensor", "needs": {"stone": 2, "copper_bar": 1}, "bp": "bp_carts"},
	"rail_layer": {"name": "Rail Layer", "needs": {"stone": 2, "iron_bar": 2, "copper_bar": 1}, "bp": "bp_rail_tools"},
	"rail_lifter": {"name": "Rail Lifter", "needs": {"stone": 2, "iron_bar": 2, "copper_bar": 1}, "bp": "bp_rail_tools"},
	"charger": {"name": "Charger", "needs": {"stone": 3, "copper_bar": 2, "iron_bar": 1}, "bp": "bp_charger"},
	"level_sensor": {"name": "Level Sensor", "needs": {"stone": 1, "log": 1, "copper": 2}, "bp": "bp_sensors"},
	"rail_switch": {"name": "Rail Switch", "needs": {"stone": 2, "iron_bar": 1, "copper_bar": 1}, "bp": "bp_rail_extras"},
	"rail_buffer": {"name": "Rail Buffer", "needs": {"stone": 2, "iron_bar": 1, "log": 1}, "bp": "bp_rail_extras"},
	"cart_unloader": {"name": "Cart Unloader", "needs": {"stone": 3, "iron_bar": 2, "copper_bar": 1}, "bp": "bp_rail_extras"},
	"drone_pad": {"name": "Drone Pad", "needs": {"stone": 4, "copper_bar": 2}, "bp": "bp_drones"},
	"oil_pump": {"name": "Oil Pump", "needs": {"iron_bar": 6, "copper_bar": 2, "stone": 4}, "bp": "bp_oil"},
	"refinery": {"name": "Refinery", "needs": {"iron_bar": 5, "copper_bar": 4, "stone": 8}, "bp": "bp_oil"},
	"drone_small": {"name": "Small Drone", "needs": {"iron_bar": 1, "copper_bar": 2, "plank": 1}, "bp": "bp_drones"},
	"drone_medium": {"name": "Medium Drone", "needs": {"iron_bar": 2, "copper_bar": 3, "plank": 2}, "bp": "bp_drones"},
	"drone_large": {"name": "Large Drone", "needs": {"iron_bar": 4, "copper_bar": 5, "plank": 3}, "bp": "bp_drones"},
	# decorations: worth far more than what goes into them ("sell" = sale value per $ of materials)
	"bark_wreath": {"name": "Bark Wreath", "needs": {"bark": 12}, "sell": 2.5},
	"lamppost": {"name": "Lamp Post", "needs": {"stone": 2, "iron_bar": 2, "copper_bar": 1}, "sell": 3.0},
	"garden_table": {"name": "Garden Table", "needs": {"plank": 8, "iron_bar": 1}, "sell": 3.0},
	"statue": {"name": "Lumberjack Statue", "needs": {"stone": 10, "copper_bar": 6}, "sell": 3.5},
	"fountain": {"name": "Fountain", "needs": {"stone": 14, "copper_bar": 2, "iron_bar": 1}, "sell": 3.5},
}
const ORDER := ["basket", "wheelbarrow", "bench", "campfire", "hammock", "chute", "rack", "compost", "ball", "hoop", "catapult",
	"crank", "lever", "button", "windmill", "generator", "battery", "conveyor", "ramp", "pillar", "piston", "rotator", "truck_caller",
	"gate_diode", "gate_and", "gate_not", "gate_timer", "gate_delay", "gate_latch", "gate_counter", "pressure_plate", "item_sensor",
	"lamp", "bell", "sawmill", "chipper", "planter", "sprinkler", "feller", "smelter", "kiln", "assembler", "grabber", "sorter",
	"splitter", "crate", "transmitter", "receiver", "drill_rig", "minecart_1", "minecart_2", "minecart_3", "minecart_4", "cart_go", "cart_back", "cart_sensor",
	"rail_layer", "rail_lifter", "charger", "level_sensor", "drone_small", "drone_medium", "drone_large", "rail_switch", "rail_buffer", "cart_unloader", "drone_pad", "oil_pump", "refinery", "bark_wreath", "lamppost", "garden_table", "statue", "fountain"]
const CATEGORIES := [
	{"name": "Storage", "items": ["basket", "wheelbarrow", "rack"]},
	{"name": "Furniture", "items": ["bench", "hammock", "garden_table"]},
	{"name": "Decorations", "items": ["bark_wreath", "lamppost", "statue", "fountain"]},
	{"name": "Fire & Garden", "items": ["campfire", "compost"]},
	{"name": "Workshop", "items": ["chute", "catapult"]},
	{"name": "Fun", "items": ["ball", "hoop"]},
	{"name": "Power & Switches", "items": ["crank", "windmill", "generator", "battery", "charger", "lever", "button"]},
	{"name": "Logic & Sensors", "items": ["gate_diode", "gate_and", "gate_not", "gate_timer", "gate_delay", "gate_latch", "gate_counter", "pressure_plate", "item_sensor", "level_sensor", "lamp", "bell"]},
	{"name": "Production", "items": ["sawmill", "chipper", "smelter", "kiln", "assembler"]},
	{"name": "Mining", "items": ["drill_rig"]},
	{"name": "Oil", "items": ["oil_pump", "refinery"]},
	{"name": "Rails & Carts", "items": ["minecart_1", "minecart_2", "minecart_3", "minecart_4", "cart_go", "cart_back", "rail_layer", "rail_lifter", "cart_sensor", "rail_switch", "rail_buffer", "cart_unloader"]},
	{"name": "Logistics", "items": ["grabber", "sorter", "splitter", "crate", "transmitter", "receiver"]},
	{"name": "Drones", "items": ["drone_small", "drone_medium", "drone_large", "drone_pad"]},
	{"name": "Tree Farm", "items": ["planter", "sprinkler", "feller"]},
	{"name": "Machines", "items": ["conveyor", "ramp", "pillar", "piston", "rotator", "truck_caller"]},
]
const SIZES := [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]

static var _S := 1.0     # scale applied to colliders while finishing a sized build
const RES_NAME := {"bark": "bark", "log": "log", "leaf": "leaves", "stone": "stone", "copper": "copper ore", "iron": "iron ore",
	"plank": "planks", "copper_bar": "copper bars", "iron_bar": "iron bars"}

const HOOP_DEFAULT := 3.05


## Bigger builds cost more: materials scale with the footprint (size squared), at least 1 of each.
## Machines (and the pillar they stand on) always build at 1x, on the grid.
static func fixed(id: String) -> bool:
	return Machines.is_machine(id) or id == "pillar" or id == "wheelbarrow"


## Whether you have the plans for it (machines need a blueprint from the shop).
static func unlocked(id: String) -> bool:
	var bp := String(BUILDS[id].get("bp", ""))
	return bp == "" or Game.is_owned(bp)


static func needs_for(id: String, size: float = 1.0) -> Dictionary:
	var out := {}
	var n: Dictionary = BUILDS[id].needs
	for r in n:
		out[r] = maxi(1, int(ceil(float(n[r]) * size * size - 0.001)))
	return out


static func needs_text(id: String, size: float = 1.0) -> String:
	var parts: Array[String] = []
	var n := needs_for(id, size)
	for r in n:
		parts.append("%d %s" % [n[r], RES_NAME[r]])
	return "  +  ".join(parts)


## What a dropped body is worth to a build: {res, amount} or {} if it's no use.
static func resource_of(body: Node) -> Dictionary:
	if body is Chip:
		return {"res": "bark", "amount": (body as Chip).panels, "color": (body as Chip).color}
	if body is Log:
		return {"res": "log", "amount": 1, "color": (body as Log).trunk.bark_color}
	if body is Leaf:
		return {"res": "leaf", "amount": 1, "color": (body as Leaf).color}
	if body is Product:
		var pr := body as Product
		var res := String(Product.KINDS[pr.kind].res)
		if res == "":
			return {}
		return {"res": res, "amount": 1, "color": pr.color if res == "plank" else (Machines.COPPER if res == "copper_bar" else Color("9aa1ab"))}
	if body is Ore:
		var o := body as Ore
		return {"res": o.kind, "amount": 1, "color": Machines.COPPER if o.kind == "copper" else (Machines.IRON if o.kind == "iron" else Ore.KINDS.stone.color)}
	return {}


## Builds the model's parts under `parent`. Returns [{mi, res, real}] - res "" for finishing parts.
## Parts hang off a "Model" node scaled to `size`; the hoop keeps its rim at `height` whatever the size.
static func make(id: String, root: Node3D, height: float = HOOP_DEFAULT, size: float = 1.0) -> Array:
	var parts: Array = []
	var parent := Node3D.new()
	parent.name = "Model"
	parent.scale = Vector3.ONE * size
	root.add_child(parent)
	if id == "hoop":
		height = height / size
	match id:
		"basket": _basket(parent, parts)
		"wheelbarrow": _wheelbarrow(parent, parts)
		"hoop": _hoop(parent, parts, height)
		"bench": _bench(parent, parts)
		"campfire": _campfire(parent, parts)
		"hammock": _hammock(parent, parts)
		"chute": _chute(parent, parts)
		"rack": _rack(parent, parts)
		"compost": _compost(parent, parts)
		"ball": _ball(parent, parts)
		"catapult": _catapult(parent, parts)
		_: Machines.model(id, parent, parts)     # machines, and the stone pillar they can stand on
	for p in parts:
		(p.mi as MeshInstance3D).material_override = p.real
	return parts


static func _part(parts: Array, parent: Node3D, mesh: Mesh, pos: Vector3, res: String, real: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := LowPoly.mesh_instance(parent, mesh, real, pos, rot)
	parts.append({"mi": mi, "res": res, "real": real})
	return mi


const BASKET_W := 0.7
const BASKET_D := 0.5
const BASKET_H := 0.44


static func _basket(root: Node3D, parts: Array) -> void:
	var bark := LowPoly.mat(Color("8a5a36"), 0.95)
	var trim := LowPoly.mat(Color("c9875a"), 0.9)
	# floor: 4 slats
	for k in 4:
		_part(parts, root, LowPoly.box(Vector3(BASKET_W, 0.035, BASKET_D / 4.0 - 0.006)), Vector3(0, 0.018, -BASKET_D * 0.5 + BASKET_D / 8.0 + k * BASKET_D / 4.0), "bark", bark)
	# walls: 3 woven strips per side, alternately offset like weaving
	var sh := (BASKET_H - 0.04) / 3.0
	for k in 3:
		var y := 0.04 + sh * (k + 0.5)
		var wob := 0.008 if k % 2 == 0 else -0.008
		for s in [-1.0, 1.0]:
			_part(parts, root, LowPoly.box(Vector3(BASKET_W + 0.03, sh - 0.01, 0.03)), Vector3(0, y, s * (BASKET_D * 0.5 + wob)), "bark", bark)
			_part(parts, root, LowPoly.box(Vector3(0.03, sh - 0.01, BASKET_D)), Vector3(s * (BASKET_W * 0.5 - wob), y, 0), "bark", bark)
	# finishing: rim band + two handles
	_part(parts, root, LowPoly.box(Vector3(BASKET_W + 0.06, 0.04, 0.05)), Vector3(0, BASKET_H, BASKET_D * 0.5), "", trim)
	_part(parts, root, LowPoly.box(Vector3(BASKET_W + 0.06, 0.04, 0.05)), Vector3(0, BASKET_H, -BASKET_D * 0.5), "", trim)
	_part(parts, root, LowPoly.box(Vector3(0.05, 0.04, BASKET_D)), Vector3(BASKET_W * 0.5, BASKET_H, 0), "", trim)
	_part(parts, root, LowPoly.box(Vector3(0.05, 0.04, BASKET_D)), Vector3(-BASKET_W * 0.5, BASKET_H, 0), "", trim)
	for s in [-1.0, 1.0]:
		_part(parts, root, LowPoly.box(Vector3(0.04, 0.12, 0.03)), Vector3(s * (BASKET_W * 0.5 + 0.03), BASKET_H + 0.06, -0.08), "", trim)
		_part(parts, root, LowPoly.box(Vector3(0.04, 0.12, 0.03)), Vector3(s * (BASKET_W * 0.5 + 0.03), BASKET_H + 0.06, 0.08), "", trim)
		_part(parts, root, LowPoly.box(Vector3(0.04, 0.03, 0.19)), Vector3(s * (BASKET_W * 0.5 + 0.03), BASKET_H + 0.125, 0), "", trim)


## Wheelbarrow: a bark tray on two log rails, a stone wheel at the front (-Z), legs and handles at the back.
const BARROW_TRAY := Vector3(0.31, 0.3, 0.4)       # tray half width, wall height, half length
const BARROW_Y := 0.34                             # tray floor height
const BARROW_WHEEL := 0.17


static func _wheelbarrow(root: Node3D, parts: Array) -> void:
	var bark := LowPoly.mat(Color("8a5a36"), 0.95)
	var log_mat := LowPoly.mat(Color("6b4a32"), 0.9)
	var stone := LowPoly.mat(Color("8a8780"), 0.9)
	var trim := LowPoly.mat(Color("c9875a"), 0.9)
	var dark := LowPoly.mat(Color("2b2d33"), 0.7)
	var hw := BARROW_TRAY.x
	var hd := BARROW_TRAY.z
	var y := BARROW_Y
	for k in 4:
		_part(parts, root, LowPoly.box(Vector3(hw * 2.0, 0.035, hd * 0.5 - 0.006)), Vector3(0, y + 0.018, -hd + hd * 0.25 + k * hd * 0.5), "bark", bark)
	var sh := (BARROW_TRAY.y - 0.04) / 2.0
	for k in 2:
		var wy := y + 0.04 + sh * (k + 0.5)
		for s in [-1.0, 1.0]:
			_part(parts, root, LowPoly.box(Vector3(0.03, sh - 0.01, hd * 2.0)), Vector3(s * (hw + k * 0.02), wy, 0), "bark", bark, Vector3(0, 0, s * -8.0))
			_part(parts, root, LowPoly.box(Vector3(hw * 2.0 + 0.04, sh - 0.01, 0.03)), Vector3(0, wy, s * (hd + k * 0.02)), "bark", bark)
	# two log rails from the wheel to the handles
	for s in [-1.0, 1.0]:
		_part(parts, root, LowPoly.cyl(0.03, 0.03, 1.35, 6), Vector3(s * 0.2, y - 0.04, 0.12), "log" if s < 0 else "", log_mat, Vector3(90, 0, 0))
		_part(parts, root, LowPoly.box(Vector3(0.05, y - 0.05, 0.05)), Vector3(s * 0.2, (y - 0.05) * 0.5, 0.3), "", log_mat)
		_part(parts, root, LowPoly.cyl(0.036, 0.036, 0.16, 7), Vector3(s * 0.2, y - 0.04, 0.74), "", trim, Vector3(90, 0, 0))
	# the stone wheel
	_part(parts, root, LowPoly.cyl(BARROW_WHEEL, BARROW_WHEEL, 0.05, 12), Vector3(-0.03, BARROW_WHEEL, -0.55), "stone", stone, Vector3(0, 0, 90))
	_part(parts, root, LowPoly.cyl(BARROW_WHEEL, BARROW_WHEEL, 0.05, 12), Vector3(0.03, BARROW_WHEEL, -0.55), "stone", stone, Vector3(0, 0, 90))
	_part(parts, root, LowPoly.cyl(0.02, 0.02, 0.44, 6), Vector3(0, BARROW_WHEEL, -0.55), "", dark, Vector3(0, 0, 90))


## Hoop facing +Z. `h` = rim height above the ground.
static func _hoop(root: Node3D, parts: Array, h: float) -> void:
	var log_mat := LowPoly.mat(Color("6b4a32"), 0.9)
	var birch := LowPoly.mat(Color("e8e4da"), 0.9)
	var wood := LowPoly.mat(Color("a0703c"), 0.8)
	var rim := LowPoly.mat(Color("e8642b"), 0.5)
	var net := LowPoly.mat(Color("f2efe6"), 0.9)
	var top := h + 0.6
	# the pole is one log
	_part(parts, root, LowPoly.cyl(0.1, 0.12, top, 8), Vector3(0, top * 0.5, -0.45), "log", log_mat)
	# backboard: 4 x 3 tiles of bark
	var bw := 1.2
	var bh := 0.84
	var cy := h + 0.3
	for row in 3:
		for col in 4:
			var x := -bw * 0.5 + bw / 8.0 + col * bw / 4.0
			var y := cy - bh * 0.5 + bh / 6.0 + row * bh / 3.0
			_part(parts, root, LowPoly.box(Vector3(bw / 4.0 - 0.01, bh / 3.0 - 0.01, 0.04)), Vector3(x, y, -0.2), "bark", birch)
	# finishing: braces, a target square, the rim and a net of bark strips
	_part(parts, root, LowPoly.box(Vector3(0.08, 0.08, 0.28)), Vector3(0, cy + 0.2, -0.33), "", wood)
	_part(parts, root, LowPoly.box(Vector3(0.08, 0.08, 0.28)), Vector3(0, cy - 0.25, -0.33), "", wood)
	_part(parts, root, LowPoly.box(Vector3(0.36, 0.03, 0.01)), Vector3(0, h + 0.36, -0.175), "", rim)
	for s in [-1.0, 1.0]:
		_part(parts, root, LowPoly.box(Vector3(0.03, 0.27, 0.01)), Vector3(s * 0.18, h + 0.23, -0.175), "", rim)
	var n := 14
	var rr := 0.23
	var c := Vector3(0, h, 0.1)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * rr
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * rr
		var mi := _part(parts, root, LowPoly.box(Vector3(0.025, 0.025, p0.distance_to(p1) + 0.01)), (p0 + p1) * 0.5, "", rim)
		mi.basis = Basis.looking_at((p1 - p0).normalized(), Vector3.UP)
	_part(parts, root, LowPoly.box(Vector3(0.05, 0.03, 0.1)), Vector3(0, h, -0.16), "", rim)
	for i in 8:
		var a := TAU * i / 8.0
		var p := c + Vector3(cos(a), 0, sin(a)) * rr * 0.92
		var mi2 := _part(parts, root, LowPoly.box(Vector3(0.012, 0.36, 0.012)), p + Vector3(0, -0.17, 0) - Vector3(cos(a), 0, sin(a)) * 0.04, "", net)
		mi2.rotation = Vector3(sin(a) * 0.2, 0, -cos(a) * 0.2)


const BARK := Color("8a5a36")
const LOGC := Color("6b4a32")
const LEAF := Color("5aa041")
const STONE := Color("8a8780")


static func _bench(root: Node3D, parts: Array) -> void:
	var bark := LowPoly.mat(BARK, 0.95)
	var logm := LowPoly.mat(LOGC, 0.9)
	for sx in [-0.5, 0.5]:
		_part(parts, root, LowPoly.cyl(0.13, 0.14, 0.42, 8), Vector3(sx, 0.21, 0), "log", logm)
	for k in 6:
		_part(parts, root, LowPoly.box(Vector3(1.4, 0.04, 0.065)), Vector3(0, 0.44, -0.18 + k * 0.072), "bark", bark)


static func _campfire(root: Node3D, parts: Array) -> void:
	var bark := LowPoly.mat(BARK, 0.95)
	var leaf := LowPoly.mat(LEAF, 0.9)
	var stone := LowPoly.mat(STONE, 1.0)
	for k in 9:
		var a := TAU * k / 9.0
		_part(parts, root, LowPoly.blob(0.1, 0.3, 11 + k), Vector3(cos(a) * 0.42, 0.06, sin(a) * 0.42), "", stone)
	for k in 5:
		var a2 := TAU * k / 5.0 + 0.3
		_part(parts, root, LowPoly.blob(0.07, 0.3, 21 + k), Vector3(cos(a2) * 0.12, 0.06, sin(a2) * 0.12), "leaf", leaf)
	for k in 6:
		var a3 := TAU * k / 6.0
		var mi := _part(parts, root, LowPoly.box(Vector3(0.05, 0.6, 0.05)), Vector3(cos(a3) * 0.14, 0.26, sin(a3) * 0.14), "bark", bark)
		mi.basis = Basis(Vector3(-sin(a3), 0, cos(a3)), deg_to_rad(-24.0))


static func _hammock(root: Node3D, parts: Array) -> void:
	var logm := LowPoly.mat(LOGC, 0.9)
	var leaf := LowPoly.mat(LEAF, 0.9)
	var rope := LowPoly.mat(Color("c9b48a"), 0.9)
	for sx in [-1.35, 1.35]:
		_part(parts, root, LowPoly.cyl(0.1, 0.12, 1.75, 8), Vector3(sx, 0.875, 0), "log", logm)
	var n := 10
	for k in n:
		var x := -1.0 + (k + 0.5) * 2.0 / n
		var y := 0.95 - 0.28 * (1.0 - pow(x / 1.1, 2.0))
		_part(parts, root, LowPoly.box(Vector3(2.0 / n + 0.01, 0.05, 0.85)), Vector3(x, y, 0), "leaf", leaf, Vector3(0, 0, -rad_to_deg(atan(0.28 * 2.0 * x / 1.21))))
	for sx in [-1.0, 1.0]:
		var mi := _part(parts, root, LowPoly.box(Vector3(0.42, 0.02, 0.02)), Vector3(sx * 1.17, 1.25, 0), "", rope)
		mi.rotation_degrees.z = 32.0 * -sx


## Trough sloping down away from you (local -Z), resting on three log posts.
const CHUTE_TILT := 20.0
const CHUTE_C := Vector3(0, 0.85, -0.1)


static func _chute_dir() -> Vector3:
	return Vector3(0, -sin(deg_to_rad(CHUTE_TILT)), -cos(deg_to_rad(CHUTE_TILT)))


static func _chute(root: Node3D, parts: Array) -> void:
	var bark := LowPoly.mat(BARK, 0.95)
	var logm := LowPoly.mat(LOGC, 0.9)
	var d := _chute_dir()
	var nrm := Vector3(0, cos(deg_to_rad(CHUTE_TILT)), -sin(deg_to_rad(CHUTE_TILT)))
	var rot := Vector3(-CHUTE_TILT, 0, 0)
	for i in 4:
		var c := CHUTE_C + d * (-1.2 + i * 0.8)
		_part(parts, root, LowPoly.box(Vector3(0.6, 0.04, 0.8)), c, "bark", bark, rot)
		for sx in [-1.0, 1.0]:
			_part(parts, root, LowPoly.box(Vector3(0.04, 0.2, 0.8)), c + Vector3(sx * 0.3, 0, 0) + nrm * 0.1, "bark", bark, rot)
	var top := CHUTE_C - d * 1.4
	var bottom := CHUTE_C + d * 1.4
	for sx in [-0.34, 0.34]:
		_part(parts, root, LowPoly.cyl(0.07, 0.08, top.y, 7), Vector3(sx, top.y * 0.5, top.z), "log", logm)
	_part(parts, root, LowPoly.cyl(0.07, 0.08, bottom.y, 7), Vector3(0, bottom.y * 0.5, bottom.z), "log", logm)


## Two V-shaped cradles; logs lie across them along X.
static func _rack(root: Node3D, parts: Array) -> void:
	var logm := LowPoly.mat(LOGC, 0.9)
	var wood := LowPoly.mat(Color("a0703c"), 0.85)
	for sx in [-0.7, 0.7]:
		for sz in [-1.0, 1.0]:
			_part(parts, root, LowPoly.cyl(0.06, 0.07, 1.0, 7), Vector3(sx, 0.46, sz * 0.24), "log", logm, Vector3(sz * 22.0, 0, 0))
	_part(parts, root, LowPoly.box(Vector3(1.6, 0.08, 0.12)), Vector3(0, 0.05, 0), "", wood)


static func _compost(root: Node3D, parts: Array) -> void:
	var leaf := LowPoly.mat(LEAF.darkened(0.15), 0.95)
	var wood := LowPoly.mat(Color("8a5e38"), 0.9)
	var mound := Node3D.new()
	mound.name = "Mound"
	root.add_child(mound)
	var pts := [Vector3(0, 0.25, 0), Vector3(0.28, 0.18, 0.15), Vector3(-0.28, 0.18, 0.1), Vector3(0.1, 0.18, -0.3),
		Vector3(-0.15, 0.18, 0.3), Vector3(0.0, 0.45, 0.05), Vector3(0.2, 0.36, -0.1), Vector3(-0.2, 0.36, -0.12)]
	for k in pts.size():
		_part(parts, mound, LowPoly.blob(0.24, 0.3, 31 + k), pts[k], "leaf", leaf)
	for sx in [-1.0, 1.0]:
		_part(parts, root, LowPoly.box(Vector3(0.05, 0.35, 1.2)), Vector3(sx * 0.6, 0.175, 0), "", wood)
		_part(parts, root, LowPoly.box(Vector3(1.2, 0.35, 0.05)), Vector3(0, 0.175, sx * 0.6), "", wood)


static func _ball(root: Node3D, parts: Array) -> void:
	var leaf := LowPoly.mat(LEAF, 0.85)
	for k in 8:
		var o := Vector3(1 if k & 1 else -1, 1 if k & 2 else -1, 1 if k & 4 else -1) * 0.045
		_part(parts, root, LowPoly.blob(0.075, 0.2, 41 + k), Vector3(0, Basketball.R, 0) + o, "leaf", leaf)


## Fires along -Z. Arm pivots at the axle, cup at its end, resting back toward you.
const CAT_PIVOT := Vector3(0, 0.38, 0.25)
const CAT_ARM := 1.1


static func _catapult(root: Node3D, parts: Array) -> void:
	var bark := LowPoly.mat(BARK, 0.95)
	var logm := LowPoly.mat(LOGC, 0.9)
	var leaf := LowPoly.mat(LEAF.darkened(0.2), 0.9)
	var wood := LowPoly.mat(Color("a0703c"), 0.85)
	for sx in [-0.45, 0.45]:
		_part(parts, root, LowPoly.cyl(0.09, 0.09, 1.9, 8), Vector3(sx, 0.1, 0.2), "log", logm, Vector3(90, 0, 0))
	_part(parts, root, LowPoly.cyl(0.08, 0.08, 1.05, 8), Vector3(0, 0.95, -0.45), "log", logm, Vector3(0, 0, 90))
	for sx in [-0.45, 0.45]:
		_part(parts, root, LowPoly.box(Vector3(0.08, 0.9, 0.08)), Vector3(sx, 0.5, -0.45), "", wood)
	# the arm (a child node so it can swing); its parts are still listed so they fill in like the rest
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = CAT_PIVOT
	root.add_child(arm)
	for k in 4:
		_part(parts, arm, LowPoly.box(Vector3(0.12, 0.05, CAT_ARM / 4.0 - 0.01)), Vector3(0, 0, CAT_ARM * (k + 0.5) / 4.0), "bark", bark)
	_part(parts, arm, LowPoly.box(Vector3(0.42, 0.04, 0.42)), Vector3(0, 0.03, CAT_ARM), "bark", bark)
	_part(parts, arm, LowPoly.box(Vector3(0.42, 0.18, 0.04)), Vector3(0, 0.12, CAT_ARM + 0.2), "bark", bark)
	# leaf-rope torsion spring around the axle
	for sx in [-0.25, 0.25]:
		_part(parts, root, LowPoly.cyl(0.11, 0.11, 0.16, 8), CAT_PIVOT + Vector3(sx, 0, 0), "leaf", leaf, Vector3(0, 0, 90))
	_part(parts, root, LowPoly.cyl(0.03, 0.03, 0.95, 6), CAT_PIVOT, "", wood, Vector3(0, 0, 90))


## The finished object, coloured with the materials that went into it.
static func finish(id: String, world: Node, xform: Transform3D, height: float, colors: Array, size: float = 1.0) -> Node3D:
	_S = size
	var body: Node3D
	match id:
		"basket":
			var rb := RigidBody3D.new()
			rb.collision_layer = 2
			rb.collision_mask = 1 | 2
			rb.mass = 4.0
			rb.angular_damp = 1.0
			rb.continuous_cd = true
			body = rb
		"wheelbarrow":
			var wb := RigidBody3D.new()
			wb.collision_layer = 2
			wb.collision_mask = 1 | 2
			wb.mass = 6.0
			wb.angular_damp = 1.5
			wb.continuous_cd = true
			body = wb
		"ball":
			var ball := Basketball.new()
			world.add_child(ball)
			ball.global_transform = xform * Transform3D(Basis(), Vector3(0, Basketball.R * size + 0.02, 0))
			ball.setup(colors, size)
			ball.add_to_group("builds")
			ball.set_meta("build", {"id": id, "height": height, "size": size, "colors": colors})
			return ball
		"campfire":
			body = Campfire.new()
		"hammock":
			body = Hammock.new()
		"compost":
			body = Compost.new()
		"catapult":
			body = Catapult.new()
		"hoop":
			body = Hoop.new()
		_:
			body = Machines.new_body(id) if Machines.is_machine(id) else StaticBody3D.new()
	if body is StaticBody3D:
		(body as StaticBody3D).collision_layer = 1
	world.add_child(body)
	body.global_transform = xform
	var parts := make(id, body, height, size)
	var k := 0
	for p in parts:
		if p.res != "" and k < colors.size():
			(p.mi as MeshInstance3D).material_override = LowPoly.mat(colors[k], 0.9)
			k += 1
	match id:
		"basket":
			# a thick floor slab (top face level with the woven floor) and thick walls, so nothing tunnels through
			_box_col(body, Vector3(BASKET_W + 0.1, 0.08, BASKET_D + 0.1), Vector3(0, 0.04, 0))
			for s in [-1.0, 1.0]:
				_box_col(body, Vector3(BASKET_W + 0.14, BASKET_H, 0.1), Vector3(0, BASKET_H * 0.5, s * (BASKET_D * 0.5 + 0.03)))
				_box_col(body, Vector3(0.1, BASKET_H, BASKET_D + 0.14), Vector3(s * (BASKET_W * 0.5 + 0.03), BASKET_H * 0.5, 0))
			body.add_to_group("grabbable")
			body.add_to_group("baskets")
			body.set_meta("size", size)
		"wheelbarrow":
			var t := BARROW_TRAY
			_box_col(body, Vector3(t.x * 2.0 + 0.1, 0.08, t.z * 2.0 + 0.1), Vector3(0, BARROW_Y + 0.0, 0))
			for s in [-1.0, 1.0]:
				_box_col(body, Vector3(0.1, t.y, t.z * 2.0 + 0.12), Vector3(s * (t.x + 0.04), BARROW_Y + t.y * 0.5, 0))
				_box_col(body, Vector3(t.x * 2.0 + 0.12, t.y, 0.1), Vector3(0, BARROW_Y + t.y * 0.5, s * (t.z + 0.04)))
				_box_col(body, Vector3(0.06, BARROW_Y, 0.06), Vector3(s * 0.2, BARROW_Y * 0.5, 0.3))
			var wcs := CollisionShape3D.new()
			var wsh := SphereShape3D.new()
			wsh.radius = BARROW_WHEEL
			wcs.shape = wsh
			wcs.position = Vector3(0, BARROW_WHEEL, -0.55)
			body.add_child(wcs)
			body.add_to_group("grabbable")
			body.add_to_group("baskets")
			body.set_meta("barrow", true)
			body.set_meta("tray_y", BARROW_Y)
			body.set_meta("tray", BARROW_TRAY)
		"hoop":
			var hh := height / size
			var top := hh + 0.6
			_box_col(body, Vector3(0.22, top, 0.22), Vector3(0, top * 0.5, -0.45))
			_box_col(body, Vector3(1.2, 0.84, 0.05), Vector3(0, hh + 0.3, -0.2))
			# a real rim the ball can clang off, and a net sensor to count baskets
			var c := Vector3(0, hh, 0.1) * size
			for i in 12:
				var a := TAU * i / 12.0
				_box_col(body, Vector3(0.04, 0.04, 0.04), c / size + Vector3(cos(a), 0, sin(a)) * 0.24)
			var net := Area3D.new()
			net.collision_layer = 0
			net.collision_mask = 2
			var ncs := CollisionShape3D.new()
			var nsh := CylinderShape3D.new()
			nsh.radius = 0.16 * size
			nsh.height = 0.12 * size
			ncs.shape = nsh
			ncs.position = c + Vector3(0, -0.12, 0) * size
			net.add_child(ncs)
			body.add_child(net)
			var hoop := body as Hoop
			hoop.rim_center = c / size
			hoop.scale_hint = size
			for p in parts:
				var col: Color = (p.real as StandardMaterial3D).albedo_color
				if col.is_equal_approx(Color("f2efe6")):
					hoop.net_parts.append(p.mi)
				elif col.is_equal_approx(Color("e8642b")) and absf((p.mi as Node3D).position.y - hh) < 0.06:
					hoop.rim_parts.append(p.mi)
			net.body_entered.connect(func(b):
				if b is Basketball and (b as RigidBody3D).linear_velocity.y < 0.0:
					hoop.score(b))
			body.add_to_group("hoops")
		"bark_wreath":
			_box_col(body, Vector3(0.7, 1.3, 0.2), Vector3(0, 0.65, 0))
		"lamppost":
			_box_col(body, Vector3(0.4, 2.5, 0.4), Vector3(0, 1.25, 0))
		"garden_table":
			_box_col(body, Vector3(1.4, 0.8, 1.6), Vector3(0, 0.4, 0))
		"statue":
			_box_col(body, Vector3(0.9, 1.6, 0.9), Vector3(0, 0.8, 0))
		"fountain":
			_box_col(body, Vector3(1.9, 0.4, 1.9), Vector3(0, 0.2, 0))
			_box_col(body, Vector3(0.3, 1.3, 0.3), Vector3(0, 0.65, 0))
		"bench":
			_box_col(body, Vector3(1.4, 0.06, 0.45), Vector3(0, 0.44, 0))
			for sx in [-0.5, 0.5]:
				_box_col(body, Vector3(0.26, 0.42, 0.26), Vector3(sx, 0.21, 0))
		"campfire":
			_box_col(body, Vector3(0.6, 0.16, 0.6), Vector3(0, 0.08, 0))
			(body as Campfire).light_up(size)
		"hammock":
			(body as Hammock).bed_h = 0.55 * size
			for sx in [-1.35, 1.35]:
				_box_col(body, Vector3(0.22, 1.75, 0.22), Vector3(sx, 0.875, 0))
			_box_col(body, Vector3(2.0, 0.08, 0.85), Vector3(0, 0.72, 0))
		"chute":
			var d := _chute_dir()
			var nrm := Vector3(0, cos(deg_to_rad(CHUTE_TILT)), -sin(deg_to_rad(CHUTE_TILT)))
			var bas := Basis(Vector3.RIGHT, deg_to_rad(-CHUTE_TILT))
			_rot_col(body, Vector3(0.6, 0.04, 3.2), CHUTE_C, bas)
			for sx in [-1.0, 1.0]:
				_rot_col(body, Vector3(0.04, 0.22, 3.2), CHUTE_C + Vector3(sx * 0.3, 0, 0) + nrm * 0.1, bas)
			var top := CHUTE_C - d * 1.4
			for sx in [-0.34, 0.34]:
				_box_col(body, Vector3(0.15, top.y, 0.15), Vector3(sx, top.y * 0.5, top.z))
			var pm := PhysicsMaterial.new()
			pm.friction = 0.04
			(body as StaticBody3D).physics_material_override = pm
		"rack":
			for sx in [-0.7, 0.7]:
				for sz in [-1.0, 1.0]:
					_rot_col(body, Vector3(0.13, 1.0, 0.13), Vector3(sx, 0.46, sz * 0.24), Basis(Vector3.RIGHT, deg_to_rad(sz * 22.0)))
		"compost":
			_box_col(body, Vector3(1.2, 0.3, 1.2), Vector3(0, 0.15, 0))
			(body as Compost).activate(body.get_node("Model/Mound"), size)
		"catapult":
			for sx in [-0.45, 0.45]:
				_box_col(body, Vector3(0.18, 0.18, 1.9), Vector3(sx, 0.1, 0.2))
			_box_col(body, Vector3(1.05, 0.16, 0.16), Vector3(0, 0.95, -0.45))
			var cup := CAT_PIVOT + Vector3(0, 0, CAT_ARM)
			_box_col(body, Vector3(0.42, 0.04, 0.42), cup + Vector3(0, 0.03, 0))
			_box_col(body, Vector3(0.42, 0.18, 0.04), cup + Vector3(0, 0.12, 0.2))
			(body as Catapult).setup_arm(body.get_node("Model/Arm"), cup * size, size)
		"pillar":
			_box_col(body, Vector3(0.98, 1.0, 0.98), Vector3(0, 0.5, 0))
		_:
			if body is Machine:
				Machines.finish(id, body as Machine)
	body.add_to_group("builds")
	body.set_meta("build", {"id": id, "height": height, "size": size, "colors": colors})
	# machines are built from lots of little parts: merge the ones that never move into a few meshes
	if body is Machine and body.get_node_or_null("Model") != null:
		LowPoly.bake(body.get_node("Model"))
	return body


# ------------------------------------------------------------------ saving

## Positions to the millimetre and rotations to 4 decimals: plenty, and it keeps the save file (and the
## autosave hitch) small.
static func xf_to_array(t: Transform3D) -> Array:
	var q := t.basis.get_rotation_quaternion()
	return [snappedf(t.origin.x, 0.001), snappedf(t.origin.y, 0.001), snappedf(t.origin.z, 0.001),
		snappedf(q.x, 0.0001), snappedf(q.y, 0.0001), snappedf(q.z, 0.0001), snappedf(q.w, 0.0001)]


static func xf_from_array(a: Array) -> Transform3D:
	var q := Quaternion(a[3], a[4], a[5], a[6])
	q = q.normalized() if q.length_squared() > 0.000001 else Quaternion.IDENTITY
	return Transform3D(Basis(q), Vector3(a[0], a[1], a[2]))


static func colors_to_array(cols: Array) -> Array:
	return cols.map(func(c): return (c as Color).to_html() if c is Color else "")


static func colors_from_array(a: Array) -> Array:
	return a.map(func(h): return Color.html(h) if String(h) != "" else null)


## Everything you've built (and plans in progress), as plain data for the save file.
static func save_world(world: Node) -> Array:
	var out: Array = []
	for n in world.get_tree().get_nodes_in_group("builds"):
		var b := n as Node3D
		# skip things on their way to the mill or otherwise not lying in the world
		if not is_instance_valid(b) or b.get_parent() != world or not b.has_meta("build"):
			continue
		if b is RigidBody3D and (b as RigidBody3D).freeze:
			continue
		var m: Dictionary = b.get_meta("build")
		var e := {"kind": "build", "id": m.id, "xf": xf_to_array(b.global_transform), "height": m.height,
			"size": m.size, "colors": colors_to_array(m.colors), "value": float(b.get_meta("sale_value", 0.0))}
		if b is Machine:
			e["uid"] = (b as Machine).uid
			e["state"] = (b as Machine).save_state()
			if (b as Machine).port_cell != null and is_instance_valid((b as Machine).port_cell):
				e["port"] = snappedf((b as Machine).port_cell.charge, 0.001)
		out.append(e)
	for n in world.get_tree().get_nodes_in_group("blueprints"):
		var bp := n as Blueprint
		if bp != null and is_instance_valid(bp):
			out.append(bp.save_data())
	for n in world.get_tree().get_nodes_in_group("wires"):
		var w := n as Wire
		if w != null and is_instance_valid(w.a) and is_instance_valid(w.b) and not w.is_queued_for_deletion():
			out.append({"kind": "wire", "a": w.a.uid, "b": w.b.uid})
	return out


static func load_world(world: Node, data: Array) -> void:
	var by_uid := {}
	var states := []
	for d in data:
		if typeof(d) == TYPE_DICTIONARY and d.get("kind", "") == "wire" and by_uid.has(int(d.get("a", -1))) and by_uid.has(int(d.get("b", -1))):
			var nw := Wire.new()
			world.add_child(nw)
			nw.setup(by_uid[int(d.a)], by_uid[int(d.b)])
		if typeof(d) != TYPE_DICTIONARY or not BUILDS.has(String(d.get("id", ""))):
			continue
		var xf := xf_from_array(d.xf)
		if d.get("kind", "") == "build":
			var cols: Array = colors_from_array(d.get("colors", [])).filter(func(c): return c != null)
			var obj := finish(String(d.id), world, xf, float(d.height), cols, float(d.size))
			if float(d.get("value", 0.0)) > 0.0:
				obj.set_meta("sale_value", float(d.value))
			if obj is Basketball:
				obj.global_transform = xf
			if obj is Machine:
				var mc := obj as Machine
				if d.has("uid"):
					mc.set_uid(int(d.uid))
				by_uid[mc.uid] = mc
				states.append([mc, d.get("state", {})])
				if d.has("port") and mc.accepts_cell():
					var pc := Product.new()
					world.add_child(pc)
					pc.setup("battery_cell", 6.0, Color.WHITE)
					pc.set_charge(float(d.port))
					mc.plug(pc)
		elif d.get("kind", "") == "plan":
			var bp := Blueprint.new()
			world.add_child(bp)
			bp.global_transform = xf
			bp.setup(String(d.id), float(d.height), world, float(d.size))
			bp.restore(d)
	for st in states:
		(st[0] as Machine).load_state(st[1])
	Minecart.adopt_all(world.get_tree())


static func _rot_col(body: Node3D, size: Vector3, pos: Vector3, basis: Basis) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size * _S
	cs.shape = sh
	cs.transform = Transform3D(basis, pos * _S)
	body.add_child(cs)
	return cs


static func _box_col(body: Node3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size * _S
	cs.shape = sh
	cs.position = pos * _S
	body.add_child(cs)
