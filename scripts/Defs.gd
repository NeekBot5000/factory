class_name Defs
extends RefCounted
## Static game data: materials, forms, biomes, parts, upgrades and quests.

const PLOT_SIZE := 8
const PLOT_RADIUS := 2
const MAX_LAYER := 14
const DIRS := [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)]
const LEVEL_MAX := 10
const INGOT_SIZE := Vector3(0.3, 0.1, 0.18)

const BIOMES := {
	"meadow": {"name": "Meadow", "top": Color("6fc24a"), "side": Color("8a6a4a")},
	"desert": {"name": "Dunes", "top": Color("e9cf7a"), "side": Color("b98f4f")},
	"jungle": {"name": "Jungle", "top": Color("2f9e4f"), "side": Color("6b4a35")},
	"snow": {"name": "Tundra", "top": Color("eef6ff"), "side": Color("8d9bb0")},
	"volcano": {"name": "Volcano", "top": Color("4a3f48"), "side": Color("2c2430")},
}

# price = $ per cubic unit of material (before form multipliers / purity).
const MATERIALS := {
	"oak": {"name": "Oak", "cat": "wood", "color": Color("dcb57e"), "bark": Color("6b4a2f"), "price": 40.0, "biome": "meadow"},
	"mahogany": {"name": "Mahogany", "cat": "wood", "color": Color("b85c3c"), "bark": Color("4a2a1e"), "price": 300.0, "biome": "jungle"},
	"frostpine": {"name": "Frostpine", "cat": "wood", "color": Color("eee6cf"), "bark": Color("56687a"), "price": 1500.0, "biome": "snow"},
	"copper": {"name": "Copper", "cat": "ore", "color": Color("e8803a"), "rock": Color("6d625a"), "price": 150.0, "biome": "meadow"},
	"iron": {"name": "Iron", "cat": "ore", "color": Color("b7c3d2"), "rock": Color("595b63"), "price": 400.0, "biome": "meadow"},
	"gold": {"name": "Gold", "cat": "ore", "color": Color("ffd23f"), "rock": Color("8a7350"), "price": 2500.0, "biome": "desert"},
	"sand": {"name": "Silica", "cat": "sand", "color": Color("e9d39a"), "rock": Color("c9b27a"), "price": 700.0, "biome": "desert"},
	"emerald": {"name": "Emerald", "cat": "gem", "color": Color("2fe08a"), "rock": Color("4b5d4f"), "price": 2500.0, "biome": "jungle"},
	"crystal": {"name": "Crystal", "cat": "gem", "color": Color("5fd8ff"), "rock": Color("6d7f99"), "price": 12000.0, "biome": "snow"},
	"ruby": {"name": "Ruby", "cat": "gem", "color": Color("ff3b5c"), "rock": Color("3d2a30"), "price": 50000.0, "biome": "volcano"},
	"void": {"name": "Voidsteel", "cat": "ore", "color": Color("b24bff"), "rock": Color("1d1726"), "price": 200000.0, "biome": "volcano"},
}

const FORM_MULT := {
	"log": 1.0, "timber": 1.4, "plank": 2.6, "offcut": 0.5, "chips": 0.3,
	"boulder": 1.0, "chunk": 1.05,
	"ingot": 3.0, "plate": 4.2, "sheet": 5.5, "scrap": 1.0,
	"geode": 1.0, "shard": 1.8, "polished": 4.5, "sand": 1.0,
	"crate": 1.0,
}
const FORM_NAMES := {
	"log": "Log", "timber": "Timber", "plank": "Plank", "offcut": "Offcut", "chips": "Wood Chips",
	"boulder": "Ore Boulder", "chunk": "Ore Chunk", "ingot": "Ingot", "plate": "Plate", "sheet": "Sheet",
	"scrap": "Scrap", "geode": "Geode", "shard": "Gem Shard", "polished": "Polished Gem", "crate": "Crate", "sand": "Sand",
}

const SENSOR_FILTERS := ["any", "wood", "ore", "metal", "gem", "sand", "glass", "log", "timber", "plank", "offcut", "boulder", "chunk", "ingot", "plate", "sheet", "shard", "polished", "crate", "big", "small", "hot"]
const CHANNEL_COLORS := [Color("ff4f4f"), Color("4fa8ff"), Color("57e08a"), Color("ffcf4a"), Color("c07bff"), Color("ff8a3d"), Color("4ff0e0"), Color("ff7ad9")]
const CHANNEL_NAMES := ["Red", "Blue", "Green", "Yellow", "Purple", "Orange", "Cyan", "Pink"]

const CATEGORIES := [
	{"id": "production", "name": "Production"},
	{"id": "transport", "name": "Transport"},
	{"id": "machines", "name": "Machines"},
	{"id": "sellers", "name": "Sellers"},
	{"id": "logic", "name": "Logic"},
	{"id": "misc", "name": "Misc"},
]

# Script per part kind (see Part.create).
const SCRIPTS := {
	"source": "res://scripts/parts/Source.gd",
	"belt": "res://scripts/parts/Belt.gd",
	"ramp": "res://scripts/parts/Ramp.gd",
	"splitter": "res://scripts/parts/Splitter.gd",
	"grate": "res://scripts/parts/Grate.gd",
	"teleporter": "res://scripts/parts/Teleporter.gd",
	"chop_saw": "res://scripts/parts/ChopSaw.gd",
	"rip_saw": "res://scripts/parts/RipSaw.gd",
	"crusher": "res://scripts/parts/Crusher.gd",
	"washer": "res://scripts/parts/Washer.gd",
	"furnace": "res://scripts/parts/Furnace.gd",
	"press": "res://scripts/parts/Press.gd",
	"polisher": "res://scripts/parts/Polisher.gd",
	"packer": "res://scripts/parts/Packer.gd",
	"seller": "res://scripts/parts/Seller.gd",
	"logic": "res://scripts/parts/Logic.gd",
	"piston": "res://scripts/parts/Piston.gd",
	"door": "res://scripts/parts/Door.gd",
	"block": "res://scripts/parts/Block.gd",
}

# cost: build price; unlock: one-time blueprint price; level: factory level required.
# dir: part has a facing; in/out: has a signal input / output port.
const PARTS := {
	# ---- production
	"treefarm_oak": {"name": "Oak Tree Farm", "kind": "source", "src": "tree", "mat": "oak", "interval": 5.0, "cat": "production", "dir": true, "in": true, "cost": 25.0, "unlock": 0.0, "level": 0,
		"desc": "Grows an oak and topples the log onto the cell in front."},
	"drill_copper": {"name": "Copper Drill", "kind": "source", "src": "drill", "mat": "copper", "interval": 3.5, "cat": "production", "in": true, "cost": 60.0, "unlock": 120.0, "level": 1,
		"desc": "Drills copper ore boulders and drops them straight down."},
	"drill_iron": {"name": "Iron Drill", "kind": "source", "src": "drill", "mat": "iron", "interval": 3.5, "cat": "production", "in": true, "cost": 450.0, "unlock": 1000.0, "level": 3,
		"desc": "Drills iron ore boulders."},
	"drill_gold": {"name": "Gold Drill", "kind": "source", "src": "drill", "mat": "gold", "interval": 4.0, "cat": "production", "in": true, "cost": 4000.0, "unlock": 9000.0, "level": 5,
		"desc": "Drills gold ore boulders. Needs Dunes land."},
	"dredge_sand": {"name": "Sand Dredge", "kind": "source", "src": "drill", "mat": "sand", "interval": 2.5, "cat": "production", "in": true, "cost": 3000.0, "unlock": 7000.0, "level": 5,
		"desc": "Dredges silica sand. Melt it in a furnace into glass; press glass while it is still hot. Needs Dunes land."},
	"treefarm_mahogany": {"name": "Mahogany Farm", "kind": "source", "src": "tree", "mat": "mahogany", "interval": 7.0, "cat": "production", "dir": true, "in": true, "cost": 9000.0, "unlock": 20000.0, "level": 6,
		"desc": "Grows valuable mahogany. Needs Jungle land."},
	"drill_emerald": {"name": "Emerald Drill", "kind": "source", "src": "drill", "mat": "emerald", "interval": 4.5, "cat": "production", "in": true, "cost": 40000.0, "unlock": 90000.0, "level": 8,
		"desc": "Drills emerald geodes. Crush them to free the gems. Needs Jungle land."},
	"treefarm_frostpine": {"name": "Frostpine Farm", "kind": "source", "src": "tree", "mat": "frostpine", "interval": 8.0, "cat": "production", "dir": true, "in": true, "cost": 160000.0, "unlock": 400000.0, "level": 10,
		"desc": "Grows rare frostpine. Needs Tundra land."},
	"drill_crystal": {"name": "Crystal Drill", "kind": "source", "src": "drill", "mat": "crystal", "interval": 5.0, "cat": "production", "in": true, "cost": 350000.0, "unlock": 900000.0, "level": 11,
		"desc": "Drills crystal geodes. Needs Tundra land."},
	"drill_ruby": {"name": "Ruby Drill", "kind": "source", "src": "drill", "mat": "ruby", "interval": 5.5, "cat": "production", "in": true, "cost": 3000000.0, "unlock": 8000000.0, "level": 14,
		"desc": "Drills ruby geodes. Needs Volcano land."},
	"drill_void": {"name": "Voidsteel Drill", "kind": "source", "src": "drill", "mat": "void", "interval": 6.0, "cat": "production", "in": true, "cost": 30000000.0, "unlock": 90000000.0, "level": 17,
		"desc": "Drills voidsteel ore. Needs Volcano land."},

	# ---- transport
	"conveyor": {"name": "Conveyor", "kind": "belt", "speed": 2.0, "tint": Color("ffcf4a"), "cat": "transport", "dir": true, "in": true, "cost": 2.0, "unlock": 0.0, "level": 0,
		"desc": "Moves items. Side guards open where another belt feeds in. Wire it to start/stop it."},
	"ramp": {"name": "Lift Ramp", "kind": "ramp", "speed": 2.6, "tint": Color("ffcf4a"), "cat": "transport", "dir": true, "cost": 8.0, "unlock": 80.0, "level": 1,
		"desc": "Lifts items up one layer."},
	"splitter": {"name": "Splitter", "kind": "splitter", "speed": 2.4, "tint": Color("c07bff"), "cat": "transport", "dir": true, "in": true, "cost": 40.0, "unlock": 400.0, "level": 3,
		"desc": "Alternates items between connected outputs. When wired it becomes a diverter: powered = side, off = forward."},
	"grate": {"name": "Sieve Grate", "kind": "grate", "speed": 2.0, "gap": 0.13, "tint": Color("9fb4c8"), "cat": "transport", "dir": true, "cost": 60.0, "unlock": 600.0, "level": 3,
		"desc": "A belt made of bars. Pieces small enough fall through the gaps to the layer below."},
	"conveyor2": {"name": "Fast Conveyor", "kind": "belt", "speed": 4.0, "tint": Color("ff8a3d"), "cat": "transport", "dir": true, "in": true, "cost": 8.0, "unlock": 600.0, "level": 4,
		"desc": "Twice as fast."},
	"conveyor3": {"name": "Turbo Conveyor", "kind": "belt", "speed": 7.0, "tint": Color("ff4f7a"), "cat": "transport", "dir": true, "in": true, "cost": 30.0, "unlock": 30000.0, "level": 9,
		"desc": "Very fast belt."},
	"tele_in": {"name": "Teleporter (send)", "kind": "teleporter", "role": "send", "cat": "transport", "in": true, "cost": 6000.0, "unlock": 25000.0, "level": 9,
		"desc": "Items landing on it are sent to a receiver of the same colour channel (click to change)."},
	"tele_out": {"name": "Teleporter (receive)", "kind": "teleporter", "role": "recv", "cat": "transport", "dir": true, "cost": 6000.0, "unlock": 25000.0, "level": 9,
		"desc": "Receives teleported items and launches them forward."},

	# ---- machines
	"chop_saw": {"name": "Chop Saw", "kind": "chop_saw", "interval": 1.6, "speed": 2.0, "cat": "machines", "dir": true, "in": true, "cost": 80.0, "unlock": 100.0, "level": 1,
		"desc": "Drops its blade every few seconds (or on a wire pulse) and cross-cuts whatever is under it, right where the blade lands."},
	"rip_saw": {"name": "Rip Saw", "kind": "rip_saw", "blades": 1, "speed": 1.6, "cat": "machines", "dir": true, "in": true, "cost": 150.0, "unlock": 200.0, "level": 1,
		"desc": "Spinning blade along the belt. Splits items lengthwise where the blade meets them. Click to shift the blade offset."},
	"crusher": {"name": "Crusher", "kind": "crusher", "cat": "machines", "dir": true, "in": true, "cost": 300.0, "unlock": 500.0, "level": 2,
		"desc": "Rollers break anything bigger than 0.25 into real fragments. Frees gems from geodes. Wood becomes chips."},
	"furnace": {"name": "Furnace", "kind": "furnace", "cat": "machines", "dir": true, "in": true, "cost": 1200.0, "unlock": 2500.0, "level": 3,
		"desc": "Melts ore chunks into a metal pool and casts ingots. Wood is burned as fuel. Boulders don't fit: crush them first."},
	"washer": {"name": "Ore Washer", "kind": "washer", "speed": 1.8, "cat": "machines", "dir": true, "in": true, "cost": 2500.0, "unlock": 6000.0, "level": 5,
		"desc": "Water jets wash ore: +15% purity, once per piece."},
	"press": {"name": "Hydraulic Press", "kind": "press", "interval": 2.0, "speed": 1.8, "cat": "machines", "dir": true, "in": true, "cost": 6000.0, "unlock": 15000.0, "level": 6,
		"desc": "Flattens items under the hammer: half the height, wider and longer (volume kept). Ingot -> plate -> sheet. Glass must still be hot (glowing) or it shatters. Gems shatter."},
	"gang_saw": {"name": "Gang Saw", "kind": "rip_saw", "blades": 4, "speed": 1.4, "cat": "machines", "dir": true, "in": true, "cost": 25000.0, "unlock": 80000.0, "level": 8,
		"desc": "Four rip blades 0.08 apart: timber in, planks out."},
	"polisher": {"name": "Polisher", "kind": "polisher", "speed": 1.4, "cat": "machines", "dir": true, "in": true, "cost": 40000.0, "unlock": 100000.0, "level": 8,
		"desc": "Polishes gem shards (x2.5 quality, -10% volume) and metal plates/sheets (+30%)."},
	"packer": {"name": "Crate Packer", "kind": "packer", "count": 8, "cat": "machines", "dir": true, "in": true, "cost": 100000.0, "unlock": 250000.0, "level": 10,
		"desc": "Packs items into a crate worth 30% more, which the market counts as a single sale. Click to change crate size."},

	# ---- sellers
	"seller": {"name": "Trade Pad", "kind": "seller", "mult": 1.0, "tint": Color("57e08a"), "cat": "sellers", "out": true, "cost": 15.0, "unlock": 0.0, "level": 0,
		"desc": "Sells anything that lands on it. Outputs a pulse on each sale."},
	"seller2": {"name": "Merchant Pad", "kind": "seller", "mult": 1.25, "tint": Color("4fd0ff"), "cat": "sellers", "out": true, "cost": 800.0, "unlock": 1000.0, "level": 3, "desc": "Sells at +25%."},
	"seller3": {"name": "Exchange Pad", "kind": "seller", "mult": 1.6, "tint": Color("ffcf4a"), "cat": "sellers", "out": true, "cost": 30000.0, "unlock": 60000.0, "level": 7, "desc": "Sells at +60%."},
	"seller4": {"name": "Royal Pad", "kind": "seller", "mult": 2.0, "tint": Color("ff6b9a"), "cat": "sellers", "out": true, "cost": 1500000.0, "unlock": 4000000.0, "level": 12, "desc": "Sells at x2."},
	"seller5": {"name": "Cosmic Pad", "kind": "seller", "mult": 2.6, "tint": Color("b98bff"), "cat": "sellers", "out": true, "cost": 80000000.0, "unlock": 250000000.0, "level": 16, "desc": "Sells at x2.6."},

	# ---- logic
	"lever": {"name": "Lever", "kind": "logic", "logic": "lever", "cat": "logic", "out": true, "cost": 10.0, "unlock": 150.0, "level": 2,
		"desc": "Click to toggle. Use the Wire tool to connect it to machines."},
	"button": {"name": "Button", "kind": "logic", "logic": "button", "cat": "logic", "out": true, "cost": 10.0, "unlock": 150.0, "level": 2, "desc": "Click to send a 1 second pulse."},
	"timer": {"name": "Timer", "kind": "logic", "logic": "timer", "cat": "logic", "in": true, "out": true, "cost": 30.0, "unlock": 300.0, "level": 2,
		"desc": "Pulses every N seconds (click to change). If wired, it only runs while powered."},
	"sensor": {"name": "Item Sensor", "kind": "logic", "logic": "sensor", "cat": "logic", "dir": true, "out": true, "cost": 40.0, "unlock": 500.0, "level": 3,
		"desc": "A laser across a belt; on while a matching item passes. Click to change the filter (material, form, size)."},
	"gate_and": {"name": "AND Gate", "kind": "logic", "logic": "and", "cat": "logic", "in": true, "out": true, "cost": 20.0, "unlock": 400.0, "level": 3, "desc": "On when all inputs are on."},
	"gate_or": {"name": "OR Gate", "kind": "logic", "logic": "or", "cat": "logic", "in": true, "out": true, "cost": 20.0, "unlock": 400.0, "level": 3, "desc": "On when any input is on."},
	"gate_not": {"name": "NOT Gate", "kind": "logic", "logic": "not", "cat": "logic", "in": true, "out": true, "cost": 20.0, "unlock": 400.0, "level": 3, "desc": "On when no input is on."},
	"gate_xor": {"name": "XOR Gate", "kind": "logic", "logic": "xor", "cat": "logic", "in": true, "out": true, "cost": 20.0, "unlock": 800.0, "level": 4, "desc": "On when an odd number of inputs are on."},
	"delay": {"name": "Delay", "kind": "logic", "logic": "delay", "cat": "logic", "in": true, "out": true, "cost": 30.0, "unlock": 600.0, "level": 3,
		"desc": "Repeats its input after a delay (click to set). Perfect for timing a piston to an item that a sensor saw earlier."},
	"counter": {"name": "Counter", "kind": "logic", "logic": "counter", "cat": "logic", "in": true, "out": true, "cost": 50.0, "unlock": 1200.0, "level": 4,
		"desc": "Counts input pulses; pulses its output every N (click to change N)."},
	"lamp": {"name": "Lamp", "kind": "logic", "logic": "lamp", "cat": "logic", "in": true, "cost": 15.0, "unlock": 150.0, "level": 2, "desc": "Lights up when powered."},
	"piston": {"name": "Piston", "kind": "piston", "interval": 2.0, "cat": "logic", "dir": true, "in": true, "cost": 120.0, "unlock": 1500.0, "level": 4,
		"desc": "Physically shoves items in front of it. Fires on a wire pulse (or every 2s unwired). Sensor + piston = sorter."},
	"door": {"name": "Gate Door", "kind": "door", "cat": "logic", "dir": true, "in": true, "cost": 60.0, "unlock": 800.0, "level": 3,
		"desc": "A physical barrier across the belt. Opens while powered (always open if unwired)."},

	# ---- misc
	"platform": {"name": "Platform", "kind": "block", "cat": "misc", "cost": 1.0, "unlock": 0.0, "level": 0, "desc": "Solid support block."},
}

const UPGRADES := {
	"src_speed": {"name": "Production Speed", "desc": "+12% tree growth and drill speed per level", "base": 100.0, "growth": 1.75, "max": 60, "per": 0.12},
	"sell_value": {"name": "Market Value", "desc": "+15% sell value per level", "base": 250.0, "growth": 1.9, "max": 80, "per": 0.15},
	"belt_speed": {"name": "Belt Speed", "desc": "+10% conveyor speed per level", "base": 150.0, "growth": 1.8, "max": 30, "per": 0.10},
	"machine_speed": {"name": "Machine Speed", "desc": "+10% saw/press cycles and furnace heat per level", "base": 400.0, "growth": 1.9, "max": 40, "per": 0.10},
	"item_cap": {"name": "Item Capacity", "desc": "+100 physics items allowed at once", "base": 400.0, "growth": 1.9, "max": 20, "per": 100.0},
	"rich_veins": {"name": "Rich Veins", "desc": "+2% ore/gem purity and +3% tree size per level", "base": 1200.0, "growth": 2.2, "max": 25, "per": 0.02},
	"marketing": {"name": "Marketing", "desc": "Markets saturate 10% slower and recover 20% faster per level", "base": 2000.0, "growth": 2.3, "max": 25, "per": 0.10},
	"night_shift": {"name": "Night Shift", "desc": "+5% offline earnings efficiency", "base": 5000.0, "growth": 2.6, "max": 16, "per": 0.05},
}
const UPGRADE_ORDER := ["src_speed", "sell_value", "belt_speed", "machine_speed", "item_cap", "rich_veins", "marketing", "night_shift"]

# stat names are resolved by Game.stat_value(); "form:x" = items of form x sold, "part:id" = parts owned.
const QUESTS := [
	{"desc": "Place an Oak Tree Farm facing a conveyor", "stat": "sources", "target": 1, "reward": 30.0},
	{"desc": "Place a Trade Pad at the end of the belt", "stat": "sellers", "target": 1, "reward": 30.0},
	{"desc": "Sell 5 logs", "stat": "form:log", "target": 5, "reward": 40.0},
	{"desc": "Earn $150 in total", "stat": "earned", "target": 150, "reward": 80.0},
	{"desc": "Place a Rip Saw on your log line", "stat": "part:rip_saw", "target": 1, "reward": 100.0},
	{"desc": "Sell 10 timber (rip-cut logs)", "stat": "form:timber", "target": 10, "reward": 150.0},
	{"desc": "Sell 10 planks (rip with offset blades!)", "stat": "form:plank", "target": 10, "reward": 300.0},
	{"desc": "Place a Copper Drill above a belt", "stat": "part:drill_copper", "target": 1, "reward": 300.0},
	{"desc": "Crush a boulder into chunks (sell 10 chunks)", "stat": "form:chunk", "target": 10, "reward": 500.0},
	{"desc": "Cast an ingot in a Furnace", "stat": "ingots", "target": 1, "reward": 800.0},
	{"desc": "Wire a lever or timer to a machine (Wire tool)", "stat": "links", "target": 1, "reward": 600.0},
	{"desc": "Buy a global upgrade (U)", "stat": "upgrades", "target": 1, "reward": 800.0},
	{"desc": "Buy your second plot of land (L)", "stat": "plots", "target": 2, "reward": 1500.0},
	{"desc": "Upgrade a part with the Upgrade tool (G)", "stat": "part_upgrades", "target": 1, "reward": 1500.0},
	{"desc": "Reach factory level 5", "stat": "level", "target": 5, "reward": 3000.0},
	{"desc": "Complete an order from the Orders board (O)", "stat": "orders", "target": 1, "reward": 5000.0},
	{"desc": "Sell 50 metal plates", "stat": "form:plate", "target": 50, "reward": 8000.0},
	{"desc": "Earn $100 per second", "stat": "income", "target": 100, "reward": 20000.0},
	{"desc": "Own 100 parts", "stat": "parts", "target": 100, "reward": 40000.0},
	{"desc": "Complete 10 orders", "stat": "orders", "target": 10, "reward": 150000.0},
	{"desc": "Sell 100 polished gems", "stat": "form:polished", "target": 100, "reward": 1000000.0},
	{"desc": "Earn $5K per second", "stat": "income", "target": 5000, "reward": 5000000.0},
	{"desc": "Sell 50 crates", "stat": "form:crate", "target": 50, "reward": 20000000.0},
	{"desc": "Ascend for the first time (P)", "stat": "stars", "target": 1, "reward": 100000000.0},
	{"desc": "Reach factory level 15", "stat": "level", "target": 15, "reward": 3000000000.0},
	{"desc": "Own 500 parts", "stat": "parts", "target": 500, "reward": 10000000000.0},
	{"desc": "Collect 10 Ascension Stars", "stat": "stars", "target": 10, "reward": 50000000000.0},
]


static func part(id: String) -> Dictionary:
	return PARTS[id]


static func is_directional(id: String) -> bool:
	return bool(PARTS[id].get("dir", false))


static func has_input(id: String) -> bool:
	return bool(PARTS[id].get("in", false))


static func has_output(id: String) -> bool:
	return bool(PARTS[id].get("out", false))


static func mat_cat(m: String) -> String:
	return String(MATERIALS[m].cat)


static func plot_of_cell(c: Vector3i) -> Vector2i:
	return Vector2i(floori((c.x + PLOT_SIZE / 2) / float(PLOT_SIZE)), floori((c.z + PLOT_SIZE / 2) / float(PLOT_SIZE)))


static func plot_in_range(p: Vector2i) -> bool:
	return absi(p.x) <= PLOT_RADIUS and absi(p.y) <= PLOT_RADIUS


static func plot_biome(p: Vector2i) -> String:
	if maxi(absi(p.x), absi(p.y)) <= 1:
		return "meadow"
	if absi(p.x) >= absi(p.y):
		return "desert" if p.x > 0 else "snow"
	return "jungle" if p.y > 0 else "volcano"


static func dir_index(d: Vector3i) -> int:
	for i in 4:
		if DIRS[i] == d:
			return i
	return -1


const GLASS_NAMES := {"ingot": "Glass Block", "plate": "Glass Pane", "sheet": "Fine Glass", "scrap": "Cullet", "sand": "Silica Sand", "chunk": "Silica Sand"}


static func product_name(mat: String, form: String) -> String:
	if form == "crate":
		return "Crate"
	if mat == "sand":
		return String(GLASS_NAMES.get(form, "Glass"))
	var mname: String = MATERIALS[mat].name
	return "%s %s" % [mname, FORM_NAMES.get(form, form)]
