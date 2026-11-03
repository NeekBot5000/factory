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
		desc = "A flat spud blade that lifts big clean sheets of outer bark only - it never digs into the inner layer.",
		look = { handle = 2.4, head = { 1.6, 0.3, 0.6 }, headColor = { 120, 126, 136 }, handleColor = { 110, 78, 50 } } },
	combo = { name = "Combo Axe", price = 550, radius = 1, stripRadius = 0.12, cooldown = 0.4, impact = 0.45, hurt = 0, anim = "chop", reach = 2.3, combo = true, tag = "Rhythmic",
		desc = "Every hit in quick succession makes the next one bigger, up to huge patches. Stop swinging and it resets.",
		look = { handle = 3.0, head = { 0.25, 1.0, 1.2 }, headColor = { 110, 180, 230 }, handleColor = { 70, 50, 40 }, band = { 110, 200, 255 } } },
	labrys = { name = "Crescent Labrys", price = 600, radius = 2, stripRadius = 0.38, cooldown = 0.72, impact = 0.55, hurt = 0, anim = "slam", reach = 2.6, tag = "Heavy",
		desc = "A two-handed axe with mirrored crescent blades. A spinning overhead slam strips a huge patch in one blow.",
		look = { handle = 4.2, head = { 0.3, 1.6, 1.4 }, headColor = { 196, 202, 212 }, handleColor = { 60, 44, 36 }, double = true, band = { 220, 170, 60 } } },
	greataxe = { name = "Greataxe", price = 900, radius = 3, stripRadius = 0.58, cooldown = 1.2, impact = 0.62, hurt = 0, anim = "slam", reach = 2.7, move = 0.55, tag = "Massive",
		desc = "The biggest bite in the forest. A long windup, and you walk slowly while you lug it around.",
		look = { handle = 4.8, head = { 0.35, 2.0, 1.8 }, headColor = { 90, 96, 106 }, handleColor = { 90, 60, 40 }, band = { 150, 40, 30 } } },
	-- (the axes below are drawn by their Godot models; `look` is only a stand-in until those load)
	twins = { name = "Twin Hatchets", price = 300, radius = 1, stripRadius = 0.15, cooldown = 0.22, impact = 0.45, hurt = 0, anim = "twin", reach = 2.2, tag = "Fast",
		desc = "One in each hand. Lightning-quick left and right chops, small strips each - keep up the rhythm.",
		look = { handle = 2.4, head = { 0.25, 0.7, 0.9 }, headColor = { 150, 158, 170 }, handleColor = { 70, 140, 80 } } },
	gouge = { name = "Inner Gouge", price = 380, radius = 1, stripRadius = 0.13, cooldown = 0.34, impact = 0.45, hurt = 0, anim = "chop", reach = 2.2, only = "inner", value = 1.35, tag = "Precise",
		desc = "A curved gouge for the prized orange inner bark only - it can't bite through outer bark, so pair it with the scraper or an axe. Small strips, but each sells for 35% more.",
		look = { handle = 2.2, head = { 0.3, 0.3, 0.8 }, headColor = { 180, 120, 60 }, handleColor = { 120, 80, 50 } } },
	ringer = { name = "Ringing Axe", price = 750, radius = 0, stripRadius = 0.0, cooldown = 0.9, impact = 0.55, hurt = 0, anim = "sweep", reach = 2.4, ring = true, tag = "Sweeping",
		desc = "A long curved blade: every swing takes a whole ring of bark off all the way round the trunk. Slow.",
		look = { handle = 3.6, head = { 0.2, 0.5, 1.6 }, headColor = { 190, 196, 206 }, handleColor = { 90, 60, 40 } } },
	spud = { name = "Bark Spud", price = 1100, radius = 1, stripRadius = 0.22, cooldown = 1.05, impact = 0.55, hurt = 0, anim = "thrust", reach = 2.4, value = 1.5, tag = "Careful",
		desc = "The proper tool for peeling bark: a spoon-shaped blade you push under it. Slow, but the sheets come off clean and sell for 50% more.",
		look = { handle = 3.4, head = { 0.6, 0.15, 0.6 }, headColor = { 160, 166, 176 }, handleColor = { 150, 110, 60 } } },
	spiral = { name = "Spiral Axe", price = 1400, radius = 1, stripRadius = 0.1, cooldown = 0.45, impact = 0.45, hurt = 0, anim = "chop", reach = 2.4, spiral = true, tag = "Pattern",
		desc = "Every hit takes a slanted stripe that carries on from where the last one ended. Keep hitting the same trunk and the stripe winds round and up it in a spiral.",
		look = { handle = 3.0, head = { 0.25, 0.9, 1.0 }, headColor = { 120, 200, 180 }, handleColor = { 60, 50, 70 } } },
	robo = { name = "Robo-Axe X9", price = 6500, radius = 1, stripRadius = 0.0, cooldown = 0.16, impact = 0.5, hurt = 0, anim = "chop", reach = 2.4, through = true, grid = 3, auto = true, tag = "Automatic",
		desc = "Servo-driven and relentless. Hold the trigger: it chops on its own several times a second, punching a 3x3 patch through BOTH layers of bark every hit.",
		look = { handle = 3.0, head = { 0.4, 0.9, 1.1 }, headColor = { 230, 200, 60 }, handleColor = { 50, 52, 58 } } },
	throwing = { name = "Throwing Hatchet", price = 450, radius = 1, stripRadius = 0.2, cooldown = 0.62, impact = 0.42, hurt = 0, anim = "throw", reach = 12, throw = true, tag = "Reach",
		desc = "A balanced little tomahawk. Click to throw it: it spins out to whatever you're aiming at, bites off a patch of bark (even at the top of a tall trunk) and flies back to your hand.",
		look = { handle = 2.0, head = { 0.25, 0.7, 0.8 }, headColor = { 160, 166, 176 }, handleColor = { 140, 100, 60 } } },
	-- saws: hold the button against a trunk (Godot's _saw_step)
	saw = { name = "Bow Saw", price = 450, radius = 0, stripRadius = 0, cooldown = 0.3, impact = 0, hurt = 0, anim = "saw", reach = 2.2, hold = true, kind = "saw", speed = 1, tag = "Long reach",
		desc = "A steel bow saw. Hold it against a trunk to fell the whole tree, then saw the log into pieces. Logs sell by the metre.",
		look = { handle = 1.6, head = { 0.1, 0.4, 2.2 }, headColor = { 200, 60, 50 }, handleColor = { 80, 80, 86 } } },
	bucksaw = { name = "Buck Saw", price = 280, radius = 0, stripRadius = 0, cooldown = 0.3, impact = 0, hurt = 0, anim = "saw", reach = 2.4, hold = true, kind = "saw", speed = 0.8, fell = false, buck = true, tag = "Long",
		desc = "A long framed saw for lying logs only - it can't fell a tree. One cut splits the whole log into neat carryable rounds.",
		look = { handle = 1.6, head = { 0.1, 0.6, 2.6 }, headColor = { 150, 110, 60 }, handleColor = { 120, 90, 60 } } },
	crosscut = { name = "Two-Man Crosscut", price = 1600, radius = 0, stripRadius = 0, cooldown = 0.3, impact = 0, hurt = 0, anim = "saw", reach = 2.5, hold = true, kind = "saw", speed = 0.9, big = true, clean = 1.2, tag = "Huge",
		desc = "A giant old-fashioned blade, slow but steady: the only hand saw that gets through the ancient trees deep in the woods. Its clean cut makes logs worth 20% more.",
		look = { handle = 1.4, head = { 0.1, 0.5, 3.6 }, headColor = { 190, 196, 206 }, handleColor = { 120, 80, 50 } } },
	chainsaw = { name = "Chainsaw", price = 1800, radius = 0, stripRadius = 0, cooldown = 0.3, impact = 0, hurt = 0, anim = "saw", reach = 2.0, hold = true, kind = "saw", speed = 3.2, tag = "Loud",
		desc = "A two-stroke chainsaw. Fells trees and cuts logs about three times faster than a bow saw. Ear defenders not included.",
		look = { handle = 1.2, head = { 0.3, 0.3, 2.0 }, headColor = { 230, 120, 40 }, handleColor = { 40, 42, 46 } } },
}
-- Godot's saw times (Player.gd): seconds of sawing to fell an average tree (radius 0.38 m; bigger takes longer),
-- and to cut through a log; logs up to 3 m can be carried; the buck saw cuts rounds of 7 bands
Config.Saw = { treeTime = 2.6, logTime = 1.1, carryMax = 3.0, buckBands = 7 }
-- the tool bar's order and the shop's (Godot's TOOL_ORDER and SHOP_ORDER, for the axes the Roblox version has)
Config.ToolOrder = { "hands", "hatchet", "throwing", "double_bit", "twins", "combo", "spiral", "scraper", "gouge", "spud", "ringer", "labrys", "greataxe", "robo", "saw", "bucksaw", "crosscut", "chainsaw" }
Config.ShopOrder = { "hatchet", "double_bit", "twins", "combo", "throwing", "scraper", "gouge", "ringer", "labrys", "greataxe", "spud", "spiral", "robo", "saw", "bucksaw", "chainsaw", "crosscut", "phone" }

-- things you can buy that aren't tools (Godot's SHOP entries in "other")
Config.Items = {
	phone = { name = "TimberPhone", price = 350, tag = "Pocket-size",
		desc = "Shop TimberMart and send the log truck off from anywhere in the forest. Press Tab to use it." },
}
Config.ComboMax = 4             -- the combo axe grows 0.05 m a hit in a row, up to 4 (and resets after 1.25 s)

-- the player (Godot's Player.gd, in metres; x3 for studs)
Config.Player = { walk = 4.2, sprint = 6.8, jump = 4.6, gravity = 12, grabReach = 2.6, fov = 75, regenDelay = 3, regenPerSecond = 5, faintSeconds = 2.2 }
Config.StudsPerMetre = 3

-- the truck (Godot's Truck.gd): drives to the mill, waits, pays, comes back
Config.Truck = { speed = 10, awaySeconds = 4 }

-- "Getting started" (Godot's Tutorial.gd), one step at a time; `check` is what the server tests to move on
Config.Tutorial = {
	{ text = "Take the hatchet from the chopping block in front of the cabin: look at it and press E.", check = "hatchet" },
	{ text = "Swing at a tree (left click) to peel off its bark. Peel off a few pieces.", check = "peeled", goal = 6 },
	{ text = "Pick the bark up (E), carry it to the green truck and drop it in the back (E again).", check = "loaded" },
	{ text = "Look at the truck and press E to send it to the mill. You're paid when it gets there.", check = "earned" },
	{ text = "Keep at it until you have $160 for a Double-Bit Axe.", check = "money", goal = 160 },
	{ text = "Go into the cabin, use the computer (E) and buy the Double-Bit Axe from TimberMart.", check = "ordered", item = "double_bit" },
	{ text = "The delivery van brings it to the dock. Click the box to open it, then pick up your axe.", check = "owns", item = "double_bit" },
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
