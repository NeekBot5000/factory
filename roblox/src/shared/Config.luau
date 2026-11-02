--!strict
-- Timber's numbers in one place: tools, tree species, products, recipes and prices.
-- Pure data, no Roblox calls, so the server, the client and the command-line tests all read the same table.
-- (Values come from the Godot version: scripts/Tools.gd, ForestTree.SPECIES, Product.gd, Processor.gd.)

local Config = {}

-- strip radius is in bark panels (one panel is 1/16 of the way round a trunk and one band high)
Config.Tools = {
	hands = { name = "Bare Hands", price = 0, radius = 0, cooldown = 0.34, hurt = 6 },
	hatchet = { name = "Trusty Hatchet", price = 30, radius = 1, cooldown = 0.5, hurt = 0 },
	double_bit = { name = "Double-Bit Axe", price = 160, radius = 1, cooldown = 0.5, hurt = 0 },
	scraper = { name = "Bark Scraper", price = 400, radius = 2, cooldown = 0.42, hurt = 0, only = "outer" },
	combo = { name = "Combo Axe", price = 550, radius = 1, cooldown = 0.4, hurt = 0 },
	labrys = { name = "Crescent Labrys", price = 600, radius = 2, cooldown = 0.72, hurt = 0 },
	greataxe = { name = "Greataxe", price = 900, radius = 3, cooldown = 1.2, hurt = 0 },
	hammer = { name = "Builder's Hammer", price = 120, radius = 0, cooldown = 0.4, hurt = 0 },
}

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
