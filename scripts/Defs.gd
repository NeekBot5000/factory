class_name Defs
extends RefCounted
## Static game data: resources, biomes, parts, upgrades and quests.

const PLOT_SIZE := 8
const PLOT_RADIUS := 2
const MAX_LAYER := 14
const DIRS := [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)]

const BIOMES := {
	"meadow": {"name": "Meadow", "top": Color("6fc24a"), "side": Color("8a6a4a")},
	"desert": {"name": "Dunes", "top": Color("e9cf7a"), "side": Color("b98f4f")},
	"jungle": {"name": "Jungle", "top": Color("2f9e4f"), "side": Color("6b4a35")},
	"snow": {"name": "Tundra", "top": Color("eef6ff"), "side": Color("8d9bb0")},
	"volcano": {"name": "Volcano", "top": Color("4a3f48"), "side": Color("2c2430")},
}

# Item resources. Each is unlocked by owning a plot of its biome.
const RESOURCES := {
	"copper": {"name": "Copper", "color": Color("e0803a"), "value": 1.0, "shape": "chunk", "biome": "meadow", "rate": 1.0},
	"iron": {"name": "Iron", "color": Color("8fa3b8"), "value": 3.0, "shape": "chunk", "biome": "meadow", "rate": 0.9},
	"gold": {"name": "Gold", "color": Color("ffd23f"), "value": 10.0, "shape": "ingot", "biome": "desert", "rate": 0.85},
	"emerald": {"name": "Emerald", "color": Color("2fe08a"), "value": 40.0, "shape": "gem", "biome": "jungle", "rate": 0.75},
	"crystal": {"name": "Crystal", "color": Color("5fd8ff"), "value": 160.0, "shape": "crystal", "biome": "snow", "rate": 0.65},
	"ruby": {"name": "Ruby", "color": Color("ff3b5c"), "value": 700.0, "shape": "gem", "biome": "volcano", "rate": 0.55},
	"void": {"name": "Void Shard", "color": Color("b24bff"), "value": 4000.0, "shape": "orb", "biome": "volcano", "rate": 0.45},
}

const CATEGORIES := [
	{"id": "droppers", "name": "Droppers"},
	{"id": "belts", "name": "Belts"},
	{"id": "processors", "name": "Processors"},
	{"id": "sellers", "name": "Sellers"},
	{"id": "misc", "name": "Misc"},
]

# kind: dropper | belt | ramp | processor | seller | block
# cost: base build price; unlock: one-time blueprint price; level: factory level required.
const PARTS := {
	"dropper_copper": {"name": "Copper Dropper", "kind": "dropper", "cat": "droppers", "res": "copper", "cost": 20.0, "unlock": 0.0, "level": 0},
	"dropper_iron": {"name": "Iron Dropper", "kind": "dropper", "cat": "droppers", "res": "iron", "cost": 120.0, "unlock": 100.0, "level": 1},
	"dropper_gold": {"name": "Gold Dropper", "kind": "dropper", "cat": "droppers", "res": "gold", "cost": 900.0, "unlock": 1000.0, "level": 4},
	"dropper_emerald": {"name": "Emerald Dropper", "kind": "dropper", "cat": "droppers", "res": "emerald", "cost": 8000.0, "unlock": 15000.0, "level": 7},
	"dropper_crystal": {"name": "Crystal Dropper", "kind": "dropper", "cat": "droppers", "res": "crystal", "cost": 80000.0, "unlock": 200000.0, "level": 10},
	"dropper_ruby": {"name": "Ruby Dropper", "kind": "dropper", "cat": "droppers", "res": "ruby", "cost": 900000.0, "unlock": 3000000.0, "level": 13},
	"dropper_void": {"name": "Void Dropper", "kind": "dropper", "cat": "droppers", "res": "void", "cost": 12000000.0, "unlock": 50000000.0, "level": 16},

	"conveyor": {"name": "Conveyor", "kind": "belt", "cat": "belts", "speed": 2.0, "tint": Color("ffcf4a"), "cost": 2.0, "unlock": 0.0, "level": 0},
	"conveyor2": {"name": "Fast Conveyor", "kind": "belt", "cat": "belts", "speed": 4.5, "tint": Color("ff8a3d"), "cost": 6.0, "unlock": 250.0, "level": 3},
	"conveyor3": {"name": "Turbo Conveyor", "kind": "belt", "cat": "belts", "speed": 8.0, "tint": Color("ff4f7a"), "cost": 20.0, "unlock": 8000.0, "level": 8},
	"ramp": {"name": "Lift Ramp", "kind": "ramp", "cat": "belts", "speed": 2.6, "tint": Color("ffcf4a"), "cost": 6.0, "unlock": 60.0, "level": 1},
	"ramp2": {"name": "Fast Lift", "kind": "ramp", "cat": "belts", "speed": 5.0, "tint": Color("ff8a3d"), "cost": 25.0, "unlock": 2000.0, "level": 5},

	"polisher": {"name": "Polisher", "kind": "processor", "cat": "processors", "mult": 2.0, "speed": 2.2, "tint": Color("7fd4ff"), "cost": 100.0, "unlock": 150.0, "level": 2},
	"smelter": {"name": "Smelter", "kind": "processor", "cat": "processors", "mult": 3.0, "speed": 2.2, "tint": Color("ff7a2e"), "cost": 500.0, "unlock": 1500.0, "level": 4},
	"cutter": {"name": "Gem Cutter", "kind": "processor", "cat": "processors", "mult": 5.0, "speed": 2.4, "tint": Color("3ff08a"), "cost": 4000.0, "unlock": 20000.0, "level": 7},
	"enchanter": {"name": "Enchanter", "kind": "processor", "cat": "processors", "mult": 10.0, "speed": 2.4, "tint": Color("b26bff"), "cost": 60000.0, "unlock": 400000.0, "level": 10},
	"quantum": {"name": "Quantum Forge", "kind": "processor", "cat": "processors", "mult": 25.0, "speed": 2.6, "tint": Color("ff7ad9"), "cost": 1500000.0, "unlock": 20000000.0, "level": 13},
	"singularity": {"name": "Singularity", "kind": "processor", "cat": "processors", "mult": 80.0, "speed": 2.8, "tint": Color("f2f2ff"), "cost": 100000000.0, "unlock": 1000000000.0, "level": 17},

	"seller": {"name": "Trade Pad", "kind": "seller", "cat": "sellers", "mult": 1.0, "tint": Color("57e08a"), "cost": 10.0, "unlock": 0.0, "level": 0},
	"seller2": {"name": "Merchant Pad", "kind": "seller", "cat": "sellers", "mult": 1.6, "tint": Color("4fd0ff"), "cost": 300.0, "unlock": 400.0, "level": 3},
	"seller3": {"name": "Exchange Pad", "kind": "seller", "cat": "sellers", "mult": 3.0, "tint": Color("ffcf4a"), "cost": 12000.0, "unlock": 25000.0, "level": 7},
	"seller4": {"name": "Royal Pad", "kind": "seller", "cat": "sellers", "mult": 8.0, "tint": Color("ff6b9a"), "cost": 500000.0, "unlock": 2000000.0, "level": 11},
	"seller5": {"name": "Cosmic Pad", "kind": "seller", "cat": "sellers", "mult": 25.0, "tint": Color("b98bff"), "cost": 30000000.0, "unlock": 150000000.0, "level": 15},

	"platform": {"name": "Platform", "kind": "block", "cat": "misc", "cost": 1.0, "unlock": 0.0, "level": 0},
}

const UPGRADES := {
	"drop_speed": {"name": "Dropper Speed", "desc": "+15% drop rate per level", "base": 100.0, "growth": 1.75, "max": 60, "per": 0.15},
	"belt_speed": {"name": "Belt Speed", "desc": "+10% conveyor speed per level", "base": 150.0, "growth": 1.8, "max": 30, "per": 0.10},
	"sell_value": {"name": "Market Value", "desc": "+20% sell value per level", "base": 250.0, "growth": 2.0, "max": 80, "per": 0.20},
	"proc_power": {"name": "Processor Power", "desc": "+10% processor multipliers per level", "base": 600.0, "growth": 2.1, "max": 40, "per": 0.10},
	"item_cap": {"name": "Item Capacity", "desc": "+100 physics items allowed at once", "base": 400.0, "growth": 1.9, "max": 20, "per": 100.0},
	"lucky": {"name": "Lucky Drops", "desc": "+2% chance a drop is golden (5x value)", "base": 1200.0, "growth": 2.3, "max": 25, "per": 0.02},
	"night_shift": {"name": "Night Shift", "desc": "+5% offline earnings efficiency", "base": 5000.0, "growth": 2.6, "max": 16, "per": 0.05},
}
const UPGRADE_ORDER := ["drop_speed", "sell_value", "belt_speed", "proc_power", "item_cap", "lucky", "night_shift"]

# stat names are resolved by Game.stat_value()
const QUESTS := [
	{"desc": "Place your first dropper", "stat": "droppers", "target": 1, "reward": 25.0},
	{"desc": "Place a seller", "stat": "sellers", "target": 1, "reward": 25.0},
	{"desc": "Sell 10 items", "stat": "sold", "target": 10, "reward": 40.0},
	{"desc": "Earn $200 in total", "stat": "earned", "target": 200, "reward": 80.0},
	{"desc": "Own 15 parts", "stat": "parts", "target": 15, "reward": 120.0},
	{"desc": "Reach factory level 2", "stat": "level", "target": 2, "reward": 200.0},
	{"desc": "Place a processor", "stat": "processors", "target": 1, "reward": 300.0},
	{"desc": "Buy an upgrade", "stat": "upgrades", "target": 1, "reward": 400.0},
	{"desc": "Own 6 droppers", "stat": "droppers", "target": 6, "reward": 600.0},
	{"desc": "Buy your second plot of land", "stat": "plots", "target": 2, "reward": 900.0},
	{"desc": "Earn $10K in total", "stat": "earned", "target": 10000, "reward": 2000.0},
	{"desc": "Reach factory level 5", "stat": "level", "target": 5, "reward": 4000.0},
	{"desc": "Own 25 droppers", "stat": "droppers", "target": 25, "reward": 12000.0},
	{"desc": "Earn $100 per second", "stat": "income", "target": 100, "reward": 30000.0},
	{"desc": "Own 5 plots of land", "stat": "plots", "target": 5, "reward": 60000.0},
	{"desc": "Reach factory level 8", "stat": "level", "target": 8, "reward": 200000.0},
	{"desc": "Own 150 parts (mass production!)", "stat": "parts", "target": 150, "reward": 600000.0},
	{"desc": "Earn $5M in total", "stat": "earned", "target": 5000000, "reward": 2000000.0},
	{"desc": "Earn $5K per second", "stat": "income", "target": 5000, "reward": 8000000.0},
	{"desc": "Reach factory level 11", "stat": "level", "target": 11, "reward": 30000000.0},
	{"desc": "Ascend for the first time", "stat": "stars", "target": 1, "reward": 100000000.0},
	{"desc": "Own 400 parts", "stat": "parts", "target": 400, "reward": 600000000.0},
	{"desc": "Reach factory level 15", "stat": "level", "target": 15, "reward": 3000000000.0},
	{"desc": "Collect 10 Ascension Stars", "stat": "stars", "target": 10, "reward": 50000000000.0},
]


static func is_directional(id: String) -> bool:
	var k: String = PARTS[id].kind
	return k == "belt" or k == "ramp" or k == "processor"


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
