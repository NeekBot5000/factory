--!strict
-- Timber's numbers in one place: tools, tree species, products, recipes and prices.
-- Pure data, no Roblox calls, so the server, the client and the command-line tests all read the same table.
-- (Values come from the Godot version: scripts/Tools.gd, ForestTree.SPECIES, Product.gd, Processor.gd.)

local Config = {}

-- strip radius is in bark panels (one panel is 1/16 of the way round a trunk and one band high).
-- look: how the tool is built (handle length, head size {x, y, z} in studs, colours {r, g, b} 0-255, a second blade);
-- tag + desc: the shop card. (Plain numbers, not Vector3/Color3, so this file needs nothing from Roblox.)
-- Godot's numbers for each tool (scripts/Tools.gd): reach in metres (x3 for studs), cooldown = seconds per swing,
-- impact = how far through the swing the blade lands (impacts: more than one hit per swing), move = walk speed
-- multiplier while holding it, anim = the swing's shape. radius is in bark panels on the Roblox bark grid, and
-- stripRadius is Godot's circle in metres (the crosshair ring's size).
Config.Tools = {
	hands = { name = "Bare Hands", price = 0, radius = 0, stripRadius = 0.05, cooldown = 0.34, impact = 0.42, hurt = 6, anim = "karate", reach = 2.1 },
	hatchet = { name = "Trusty Hatchet", price = 30, radius = 1, stripRadius = 0.18, cooldown = 0.5, impact = 0.45, hurt = 0, anim = "chop", reach = 2.3, tag = "Light",
		desc = "A light forged hatchet with a hickory handle. No more bruised hands, and it lifts a palm-sized sheet of bark per swing.",
		look = { handle = 2.6, head = { 0.25, 0.8, 1.0 }, headColor = { 150, 158, 170 }, handleColor = { 160, 112, 60 }, band = { 192, 57, 43 } } },
	double_bit = { name = "Double-Bit Axe", price = 160, radius = 1, stripRadius = 0.2, cooldown = 1.0, impact = 0.35, impacts = { 0.32, 0.74 }, hurt = 0, anim = "double", reach = 2.5, tag = "Balanced",
		desc = "Two balanced heads on a straight handle. Swing it sideways in a wide arc to peel off big strips of bark.",
		look = { handle = 3.4, head = { 0.25, 0.9, 1.1 }, headColor = { 170, 176, 186 }, handleColor = { 185, 138, 82 }, double = true } },
	scraper = { name = "Bark Scraper", price = 400, radius = 2, stripRadius = 0.3, cooldown = 0.42, impact = 0.45, hurt = 0, only = "outer", anim = "chop", reach = 2.3, tag = "Wide",
		desc = "A wide flat blade that lifts big sheets of outer bark and never touches the inner layer.",
		look = { handle = 2.4, head = { 1.6, 0.3, 0.6 }, headColor = { 120, 126, 136 }, handleColor = { 110, 78, 50 } } },
	combo = { name = "Combo Axe", price = 550, radius = 1, stripRadius = 0.12, cooldown = 0.4, impact = 0.45, hurt = 0, anim = "chop", reach = 2.3, tag = "Rhythmic",
		desc = "Keep the rhythm going and every hit grows the next.",
		look = { handle = 3.0, head = { 0.25, 1.0, 1.2 }, headColor = { 110, 180, 230 }, handleColor = { 70, 50, 40 }, band = { 110, 200, 255 } } },
	labrys = { name = "Crescent Labrys", price = 600, radius = 2, stripRadius = 0.38, cooldown = 0.72, impact = 0.55, hurt = 0, anim = "slam", reach = 2.6, tag = "Heavy",
		desc = "A two-handed axe with mirrored crescent blades. A spinning overhead slam strips a huge patch in one blow.",
		look = { handle = 4.2, head = { 0.3, 1.6, 1.4 }, headColor = { 196, 202, 212 }, handleColor = { 60, 44, 36 }, double = true, band = { 220, 170, 60 } } },
	greataxe = { name = "Greataxe", price = 900, radius = 3, stripRadius = 0.58, cooldown = 1.2, impact = 0.62, hurt = 0, anim = "slam", reach = 2.7, move = 0.55, tag = "Massive",
		desc = "The biggest bite of all. Slow, and you walk slower carrying it.",
		look = { handle = 4.8, head = { 0.35, 2.0, 1.8 }, headColor = { 90, 96, 106 }, handleColor = { 90, 60, 40 }, band = { 150, 40, 30 } } },
}
-- the tool bar's order (Godot's TOOL_ORDER) and the shop's
Config.ToolOrder = { "hands", "hatchet", "double_bit", "combo", "scraper", "labrys", "greataxe" }
Config.ShopOrder = { "hatchet", "double_bit", "combo", "scraper", "labrys", "greataxe" }

-- the player (Godot's Player.gd, in metres; x3 for studs)
Config.Player = { walk = 4.2, sprint = 6.8, jump = 4.6, gravity = 12, grabReach = 2.6, fov = 75, regenDelay = 3, regenPerSecond = 5, faintSeconds = 2.2 }
Config.StudsPerMetre = 3

-- the truck (Godot's Truck.gd): drives to the mill, waits, pays, comes back
Config.Truck = { speed = 10, awaySeconds = 4 }

-- "Getting started" (Godot's Tutorial.gd), one step at a time; `check` is what the server tests to move on
Config.Tutorial = {
	{ text = "Take the hatchet from the chopping block: look at it and press E.", check = "hatchet" },
	{ text = "Swing at a tree (left click) to peel off its bark. Peel off a few pieces.", check = "peeled", goal = 6 },
	{ text = "Pick the bark up (E), carry it to the green truck and drop it in the back (E again).", check = "loaded" },
	{ text = "Look at the truck and press E to send it to the mill. You're paid when it gets there.", check = "earned" },
	{ text = "Keep at it until you have $160 for a Double-Bit Axe.", check = "money", goal = 160 },
	{ text = "Walk over to the TimberMart stall, look at the counter, press E and buy the Double-Bit Axe.", check = "owns", item = "double_bit" },
}
Config.TutorialDone = "That's the basics. The rest is yours to find out."

-- Trees, from the Godot game's ForestTree.gd (metres; x3 for studs). A trunk is 16 panels round and `bands` panels
-- high (0.18 m each), with two layers of bark: outer (0.045 m thick) over inner (0.035 m) over the wood.
Config.Tree = { sectors = 16, bandH = 0.18, outerT = 0.045, innerT = 0.035, minRadius = 0.3, maxRadius = 0.46, minBands = 26, maxBands = 40 }

-- bark / inner / wood colours, what each layer is worth (oak = 1), and each kind's quirk
Config.Species = {
	oak = { name = "Oak", bark = "5b4030", inner = "b5653a", wood = "e2c08d", outer = 1.0, innerV = 1.0 },
	pine = { name = "Pine", bark = "4d3a2e", inner = "b7703f", wood = "ead1a0", outer = 1.0, innerV = 1.0 },
	birch = { name = "Birch", bark = "e8e4da", inner = "c9875a", wood = "f0dcb4", outer = 1.6, innerV = 1.0 },
	hickory = { name = "Shagbark Hickory", bark = "6e6458", inner = "d0a878", wood = "e8d2a8", outer = 1.1, innerV = 1.1, handsSafe = true },
	cedar = { name = "Western Red Cedar", bark = "7a4a35", inner = "a5482e", wood = "c98f6b", outer = 1.6, innerV = 1.6, tallStrips = true },
	cork = { name = "Cork Oak", bark = "b09d80", inner = "b5653a", wood = "e2c08d", outer = 1.5, innerV = 1.0, regrows = true },
	eucalyptus = { name = "Rainbow Eucalyptus", bark = "a9aca0", inner = "6ccf6a", wood = "efe2c4", outer = 0.8, innerV = 1.0, ages = true },
}

-- dollars per bark panel before the species multiplier
Config.PanelValue = { outer = 0.6, inner = 1.0 }

Config.Products = {
	plank = { name = "Plank", value = 1.5, fuel = 8 },
	copper_bar = { name = "Copper Bar", value = 4, fuel = 0 },
	iron_bar = { name = "Iron Bar", value = 6, fuel = 0 },
	oil_barrel = { name = "Barrel of Oil", value = 8, fuel = 90 },
	fuel_can = { name = "Fuel Can", value = 6.4, fuel = 240 },
	plastic = { name = "Plastic Sheet", value = 4.8, fuel = 0 },
	lawn_chair = { name = "Lawn Chair", value = 24, fuel = 0 },
}

-- assembler recipes: inputs -> one output worth `mult` x what went in
Config.Recipes = {
	chair = { inputs = { plank = 2 }, mult = 2.5 },
	lawn_chair = { inputs = { plastic = 2 }, mult = 2.5 },
	battery_cell = { inputs = { copper_bar = 1, iron_bar = 1 }, mult = 1.2 },
}

-- the refinery: one barrel in, these out (each worth this share of the barrel)
Config.Refinery = { input = "oil_barrel", outputs = { fuel_can = 0.8, plastic = 0.6 }, seconds = 4 }

Config.Oil = { minRichness = 0.12, barrelsPerSecondAtFull = 1 / 25 }

return Config
