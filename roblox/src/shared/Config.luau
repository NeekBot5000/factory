--!strict
-- Timber's numbers in one place: tools, tree species, products, recipes and prices.
-- Pure data, no Roblox calls, so the server, the client and the command-line tests all read the same table.
-- (Values come from the Godot version: scripts/Tools.gd, ForestTree.SPECIES, Product.gd, Processor.gd.)

local Config = {}

-- strip radius is in bark panels (one panel is 1/16 of the way round a trunk and one band high).
-- look: how the tool is built (handle length, head size {x, y, z} in studs, colours {r, g, b} 0-255, a second blade);
-- tag + desc: the shop card. (Plain numbers, not Vector3/Color3, so this file needs nothing from Roblox.)
Config.Tools = {
	hands = { name = "Bare Hands", price = 0, radius = 0, cooldown = 0.34, hurt = 6 },
	hatchet = { name = "Trusty Hatchet", price = 30, radius = 1, cooldown = 0.5, hurt = 0, tag = "Light",
		desc = "No more bruised knuckles. Peels a sheet the size of your hand.",
		look = { handle = 2.6, head = { 0.25, 0.8, 1.0 }, headColor = { 150, 158, 170 }, handleColor = { 160, 112, 60 }, band = { 192, 57, 43 } } },
	double_bit = { name = "Double-Bit Axe", price = 160, radius = 1, cooldown = 0.5, hurt = 0, tag = "Balanced",
		desc = "A blade on both sides: every swing bites twice.",
		look = { handle = 3.4, head = { 0.25, 0.9, 1.1 }, headColor = { 170, 176, 186 }, handleColor = { 185, 138, 82 }, double = true } },
	scraper = { name = "Bark Scraper", price = 400, radius = 2, cooldown = 0.42, hurt = 0, only = "outer", tag = "Wide",
		desc = "Lifts big sheets of outer bark and never touches the inner layer.",
		look = { handle = 2.4, head = { 1.6, 0.3, 0.6 }, headColor = { 120, 126, 136 }, handleColor = { 110, 78, 50 } } },
	combo = { name = "Combo Axe", price = 550, radius = 1, cooldown = 0.4, hurt = 0, tag = "Rhythmic",
		desc = "Keep the rhythm going and every hit grows the next.",
		look = { handle = 3.0, head = { 0.25, 1.0, 1.2 }, headColor = { 110, 180, 230 }, handleColor = { 70, 50, 40 }, band = { 110, 200, 255 } } },
	labrys = { name = "Crescent Labrys", price = 600, radius = 2, cooldown = 0.72, hurt = 0, tag = "Heavy",
		desc = "A great two-headed slam that tears off a huge patch.",
		look = { handle = 4.2, head = { 0.3, 1.6, 1.4 }, headColor = { 196, 202, 212 }, handleColor = { 60, 44, 36 }, double = true, band = { 220, 170, 60 } } },
	greataxe = { name = "Greataxe", price = 900, radius = 3, cooldown = 1.2, hurt = 0, tag = "Massive",
		desc = "The biggest bite of all. Slow, and you walk slower carrying it.",
		look = { handle = 4.8, head = { 0.35, 2.0, 1.8 }, headColor = { 90, 96, 106 }, handleColor = { 90, 60, 40 }, band = { 150, 40, 30 } } },
}
Config.ShopOrder = { "hatchet", "double_bit", "scraper", "combo", "labrys", "greataxe" }

-- the first few minutes: each step teaches one thing by doing it
Config.Quests = {
	{ id = "peel", text = "Peel bark off a tree", goal = 5, reward = 0 },
	{ id = "carry", text = "Carry bark to the truck", goal = 3, reward = 0 },
	{ id = "ship", text = "Ship the truck to the mill", goal = 1, reward = 15 },
	{ id = "buy", text = "Buy a hatchet at TimberMart", goal = 1, reward = 20 },
	{ id = "earn", text = "Earn $150", goal = 150, reward = 50 },
}

-- sounds that ship with every Roblox install (swap for uploaded ones later; a missing one just stays silent)
-- The uploaded sound sheet (roblox/sounds/timber-sounds.ogg): every sound from the Godot game in one audio file.
-- Empty until it's uploaded; then a few built-in Roblox sounds stand in.
Config.SoundSheetId = ""

Config.Species = {
	oak = { name = "Oak", outer = 1.0, inner = 1.0 },
	pine = { name = "Pine", outer = 1.0, inner = 1.0 },
	birch = { name = "Birch", outer = 1.6, inner = 1.0 },
	hickory = { name = "Shagbark Hickory", outer = 1.1, inner = 1.1, handsSafe = true },
	cedar = { name = "Western Red Cedar", outer = 1.6, inner = 1.6, tallStrips = true },
	cork = { name = "Cork Oak", outer = 1.5, inner = 1.0, regrows = true },
	eucalyptus = { name = "Rainbow Eucalyptus", outer = 0.8, inner = 1.0, ages = true },
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
