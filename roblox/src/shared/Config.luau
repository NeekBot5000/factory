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
	thunder = { name = "Thunder Axe", price = 18000, radius = 1, stripRadius = 0.24, cooldown = 0.6, impact = 0.45, hurt = 0, anim = "chop", reach = 2.5, charge = 1.2, rest = 6, tag = "Legendary",
		desc = "Hold the button to charge it. Let go on a trunk and lightning cracks every last sheet of bark off the whole tree at once. Needs a few seconds to recharge.",
		look = { handle = 3.2, head = { 0.4, 1.1, 1.3 }, headColor = { 70, 80, 110 }, handleColor = { 40, 36, 44 }, band = { 120, 200, 255 } } },
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
	shears = { name = "Pruning Shears", price = 90, radius = 0, stripRadius = 0, cooldown = 0.32, impact = 0.45, hurt = 0, anim = "snip", reach = 4.2, snip = true, tag = "Light",
		desc = "Long-reach shears. Snip big clumps of leaves off bushes and tree crowns. Leaves don't sell for much, but there are tons of them.",
		look = { handle = 1.6, head = { 0.1, 0.25, 0.8 }, headColor = { 190, 196, 206 }, handleColor = { 200, 60, 50 } } },
	hammer = { name = "Builder's Hammer", price = 120, radius = 0, stripRadius = 0, cooldown = 0.45, impact = 0.5, hurt = 0, anim = "hammer", reach = 2.2, build = true, tag = "Compact",
		desc = "Build things out of what you gather: pick a plan, set it down, then drop the materials into it.",
		look = { handle = 1.0, head = { 0.25, 0.25, 0.6 }, headColor = { 120, 124, 132 }, handleColor = { 150, 110, 70 } } },
	-- the little helpers
	rake = { name = "Leaf Rake", price = 40, radius = 0, stripRadius = 0, cooldown = 0.62, impact = 0.55, hurt = 0, anim = "rake", reach = 3.4, rake = true, tag = "Cheap",
		desc = "Every pull drags the bark, leaves and bits lying in front of you a step closer. Makes a pile in no time.",
		look = { handle = 3.4, head = { 0.9, 0.1, 0.25 }, headColor = { 150, 110, 70 }, handleColor = { 150, 110, 70 } } },
	blower = { name = "Leaf Blower", price = 900, radius = 0, stripRadius = 0, cooldown = 0.1, impact = 0, hurt = 0, anim = "vacuum", reach = 8, hold = true, kind = "blower", tag = "Pushy",
		desc = "Hold the trigger to blow everything in front of you away. Herd a whole pile across the clearing, onto a belt or into the truck.",
		look = { handle = 1.4, head = { 0.4, 0.4, 1.4 }, headColor = { 200, 60, 50 }, handleColor = { 40, 40, 44 } } },
	can = { name = "Watering Can", price = 70, radius = 0, stripRadius = 0, cooldown = 1.0, impact = 0.35, hurt = 0, anim = "pour", reach = 2.8, water = true, tag = "Green",
		desc = "Water a sapling that has taken root and it grows twice as fast for the next minute.",
		look = { handle = 0.6, head = { 0.6, 0.6, 0.9 }, headColor = { 60, 140, 90 }, handleColor = { 60, 140, 90 } } },
	scale = { name = "Log Scale", price = 90, radius = 0, stripRadius = 0, cooldown = 0.4, impact = 0.5, hurt = 0, anim = "scale", reach = 3.0, weigh = true, tag = "Handy",
		desc = "Point it at a log, a piece of bark or a full basket: the dial shows how heavy it is, and the hint tells you what the mill would pay for it.",
		look = { handle = 0.6, head = { 0.6, 0.8, 0.2 }, headColor = { 220, 210, 190 }, handleColor = { 120, 124, 132 } } },
	dynamite = { name = "Dynamite (box of 5)", price = 1200, radius = 0, stripRadius = 0, cooldown = 0.5, impact = 0.5, hurt = 0, anim = "pour", reach = 2.8, plant = true, consumable = 5, tag = "Explosive",
		desc = "Stick a charge on a rock, run a wire from it to a switch with power (a button and a crank, say), and set it off from a safe distance. The rock bursts into every chunk.",
		look = { handle = 0.3, head = { 0.25, 0.7, 0.25 }, headColor = { 192, 57, 43 }, handleColor = { 43, 45, 51 } } },
	detector = { name = "Ore Detector", price = 750, radius = 0, stripRadius = 0, cooldown = 0.4, impact = 0.5, hurt = 0, anim = "detector", reach = 2.0, detect = true, tag = "Beeping",
		desc = "Beeps faster the richer the ground under your feet is in copper and iron. Dig where it beeps hardest.",
		look = { handle = 1.6, head = { 0.5, 0.15, 0.5 }, headColor = { 230, 200, 60 }, handleColor = { 40, 40, 44 } } },
	-- mining: dig straight down (or knock chunks off rocks); iron needs tier 2
	pickaxe = { name = "Pickaxe", price = 80, radius = 0, stripRadius = 0.05, cooldown = 0.6, impact = 0.5, hurt = 0, anim = "chop", reach = 2.5, mine = 1, tier = 1, tag = "Sturdy",
		desc = "Dig straight down into the ground: stone near the top, copper further down. Deeper still there's iron, but it's too hard for this pick.",
		look = { handle = 2.4, head = { 0.2, 0.2, 1.4 }, headColor = { 120, 124, 132 }, handleColor = { 150, 110, 70 } } },
	steel_pick = { name = "Steel Pickaxe", price = 900, radius = 0, stripRadius = 0.05, cooldown = 0.5, impact = 0.5, hurt = 0, anim = "chop", reach = 2.6, mine = 2, tier = 2, tag = "Hardened",
		desc = "Digs twice as fast and gets iron out of the deep layers (from about 5 m down).",
		look = { handle = 2.4, head = { 0.2, 0.2, 1.4 }, headColor = { 170, 176, 190 }, handleColor = { 60, 60, 66 } } },
	rock_drill = { name = "Rock Drill", price = 650, radius = 0, stripRadius = 0.05, cooldown = 0.3, impact = 0, hurt = 0, anim = "drill", reach = 2.4, hold = true, kind = "rockdrill", mine = 1, tier = 1, tag = "Powered",
		desc = "Hold the trigger on the ground and it digs down about twice as fast as a pickaxe. Stone and copper only. Fits in a drill rig.",
		look = { handle = 1.2, head = { 0.3, 0.3, 1.0 }, headColor = { 230, 170, 40 }, handleColor = { 40, 40, 44 } } },
	core_drill = { name = "Steel Core Drill", price = 2600, radius = 0, stripRadius = 0.05, cooldown = 0.25, impact = 0, hurt = 0, anim = "drill", reach = 2.5, hold = true, kind = "rockdrill", mine = 2, tier = 2, tag = "Hardened",
		desc = "A hardened, faster drill that digs twice as hard and gets iron out of the deep layers. In a drill rig it goes much deeper.",
		look = { handle = 1.2, head = { 0.3, 0.3, 1.1 }, headColor = { 170, 176, 190 }, handleColor = { 40, 40, 44 } } },
	sledge = { name = "Sledgehammer", price = 220, radius = 0, stripRadius = 0.08, cooldown = 1.25, impact = 0.6, hurt = 0, anim = "slam", reach = 2.5, mine = 3, tier = 1, smash = 0.8, move = 0.8, tag = "Smashing",
		desc = "Slow and heavy. Small rocks burst into all their chunks in one blow; big ones lose a few at a time. Iron is still too hard for it.",
		look = { handle = 3.0, head = { 0.35, 0.35, 0.8 }, headColor = { 90, 96, 106 }, handleColor = { 150, 110, 70 } } },
	wires = { name = "Wire Spool", price = 200, radius = 0, stripRadius = 0, cooldown = 0.3, impact = 0.5, hurt = 0, anim = "snip", reach = 4.0, wire = true, tag = "Electric",
		desc = "Click one machine, then another, to run a wire between them. Do it again to take the wire down.",
		look = { handle = 0.4, head = { 0.4, 0.4, 0.3 }, headColor = { 184, 98, 44 }, handleColor = { 60, 60, 66 } } },
	-- the leaf vacuums: hold the trigger, loose things fly to the nozzle and swirl there until you let go
	vacuum = { name = "Leaf Vacuum", price = 1200, radius = 0, stripRadius = 0, cooldown = 0.1, impact = 0, hurt = 0, anim = "vacuum", reach = 7, hold = true, kind = "vacuum", tag = "Bulky",
		desc = "Hold the trigger to suck up loose bark and boxes. They float in front of the nozzle until you let go.",
		look = { handle = 1.4, head = { 0.4, 0.4, 1.4 }, headColor = { 220, 120, 40 }, handleColor = { 40, 40, 44 } } },
	twinvac = { name = "Twin-Nozzle Vac", price = 2600, radius = 0, stripRadius = 0, cooldown = 0.1, impact = 0, hurt = 0, anim = "vacuum", reach = 9, hold = true, kind = "vacuum", nozzles = { -0.32, 0.32 }, cone = 0.62, cap = 70, range = 9, tag = "Wide",
		desc = "Two intakes on a forked tube. A much wider pull, and it holds twice as much in two swirling clumps.",
		look = { handle = 1.4, head = { 0.8, 0.4, 1.4 }, headColor = { 60, 160, 90 }, handleColor = { 40, 40, 44 } } },
	cyclone = { name = "Cyclone Vac", price = 3400, radius = 0, stripRadius = 0, cooldown = 0.1, impact = 0, hurt = 0, anim = "vacuum", reach = 12, hold = true, kind = "vacuum", range = 12, cone = 0.93, cap = 25, launch = true, tag = "Powerful",
		desc = "A long-range cyclone with a narrow, strong pull. Let go of the trigger and it fires everything it caught straight ahead.",
		look = { handle = 1.4, head = { 0.45, 0.45, 1.8 }, headColor = { 120, 90, 200 }, handleColor = { 40, 40, 44 } } },
	-- the motor tools: run while the trigger is held
	planer = { name = "Electric Planer", price = 1300, radius = 0, stripRadius = 0, cooldown = 0.45, impact = 0, hurt = 0, anim = "planer", reach = 2.3, hold = true, kind = "planer", tag = "Long strips",
		desc = "For logs lying down. Hold it on one and it planes a strip off the whole length of the log at once, in one long sheet.",
		look = { handle = 1.0, head = { 0.5, 0.4, 0.9 }, headColor = { 60, 120, 200 }, handleColor = { 40, 40, 44 } } },
	washer = { name = "Pressure Washer", price = 2200, radius = 0, stripRadius = 0.2, cooldown = 0.07, impact = 0, hurt = 0, anim = "washer", reach = 6, hold = true, kind = "washer", tag = "Satisfying",
		desc = "Hold the trigger to blast a jet of water from a good distance away. Bark flakes off wherever the spray lands.",
		look = { handle = 1.6, head = { 0.2, 0.3, 1.2 }, headColor = { 230, 200, 40 }, handleColor = { 40, 40, 44 } } },
	-- the bark drills: hold the trigger and sweep across the trunk, a bite every `cooldown` seconds
	drill = { name = "Timber Auger", price = 2400, radius = 1, stripRadius = 0.24, cooldown = 0.2, impact = 0, hurt = 0, anim = "drill", reach = 2.2, hold = true, kind = "drill", tag = "Heavy",
		desc = "A cordless rotary debarker. Hold the trigger and sweep it across the trunk to strip bark continuously.",
		look = { handle = 1.2, head = { 0.3, 0.3, 0.9 }, headColor = { 230, 170, 40 }, handleColor = { 40, 40, 44 } } },
	twin_auger = { name = "Twin Auger", price = 3200, radius = 1, stripRadius = 0.2, cooldown = 0.18, impact = 0, hurt = 0, anim = "drill", reach = 2.2, hold = true, kind = "drill", bits = 2, tag = "Wide",
		desc = "Two counter-rotating bits side by side. Sweep it along a trunk to bore two tracks of bark off at once.",
		look = { handle = 1.2, head = { 0.6, 0.3, 0.9 }, headColor = { 60, 140, 220 }, handleColor = { 40, 40, 44 } } },
	holesaw = { name = "Hole Saw", price = 2100, radius = 1, stripRadius = 0.17, cooldown = 0.22, impact = 0, hurt = 0, anim = "drill", reach = 2.2, hold = true, kind = "drill", through = true, tag = "Deep",
		desc = "A toothed cup that bites straight in: every spot it touches loses its outer AND inner bark together.",
		look = { handle = 1.2, head = { 0.35, 0.35, 0.7 }, headColor = { 200, 60, 50 }, handleColor = { 40, 40, 44 } } },
	pole_saw = { name = "Pole Saw", price = 380, radius = 0, stripRadius = 0, cooldown = 0.3, impact = 0, hurt = 0, anim = "polesaw", reach = 5.5, hold = true, kind = "polesaw", tag = "Long reach",
		desc = "A curved saw on a long pole. Hold it up in the leaves of a standing tree to cut the whole crown off: the leaves, and a sapling or two, come raining down.",
		look = { handle = 5.0, head = { 0.08, 0.5, 1.0 }, headColor = { 190, 196, 206 }, handleColor = { 150, 120, 80 } } },
	crosscut = { name = "Two-Man Crosscut", price = 1600, radius = 0, stripRadius = 0, cooldown = 0.3, impact = 0, hurt = 0, anim = "saw", reach = 2.5, hold = true, kind = "saw", speed = 0.9, big = true, clean = 1.2, tag = "Huge",
		desc = "A giant old-fashioned blade, slow but steady: the only hand saw that gets through the ancient trees deep in the woods. Its clean cut makes logs worth 20% more.",
		look = { handle = 1.4, head = { 0.1, 0.5, 3.6 }, headColor = { 190, 196, 206 }, handleColor = { 120, 80, 50 } } },
	chainsaw = { name = "Chainsaw", price = 1800, radius = 0, stripRadius = 0, cooldown = 0.3, impact = 0, hurt = 0, anim = "saw", reach = 2.0, hold = true, kind = "saw", speed = 3.2, tag = "Loud",
		desc = "A two-stroke chainsaw. Fells trees and cuts logs about three times faster than a bow saw. Ear defenders not included.",
		look = { handle = 1.2, head = { 0.3, 0.3, 2.0 }, headColor = { 230, 120, 40 }, handleColor = { 40, 42, 46 } } },
}
-- Godot's saw times (Player.gd): seconds of sawing to fell an average tree (radius 0.38 m; bigger takes longer),
-- and to cut through a log; logs up to 3 m can be carried; the buck saw cuts rounds of 7 bands
Config.Saw = { treeTime = 2.6, logTime = 1.1, carryMax = 3.0, buckBands = 7, crownTime = 1.8, crownReach = 2.2 }
-- a clump of leaves off a crown (Godot's Leaf: cheap, but there are lots) and the saplings that fall with it
-- (Godot's Sapling: put it down on open ground and leave it, it roots after 1.5 s and is a full tree in 5 minutes)
Config.Leaf = { value = 0.05 }
Config.Sapling = { rest = 1.5, growTime = 300 }
-- the tool bar's order and the shop's: Godot's TOOL_ORDER and SHOP_ORDER, for what the Roblox version has
local GODOT_TOOL_ORDER = { "hands", "hatchet", "throwing", "double_bit", "twins", "combo", "spiral", "scraper", "gouge", "spud", "ringer", "labrys", "greataxe", "robo", "thunder", "saw", "bucksaw", "pole_saw", "crosscut", "chainsaw", "shears", "drill", "twin_auger", "holesaw", "planer", "washer", "rake", "vacuum", "twinvac", "cyclone", "blower", "pickaxe", "sledge", "steel_pick", "rock_drill", "core_drill", "detector", "dynamite", "wires", "hammer", "can", "scale" }
local GODOT_SHOP_ORDER = { "hatchet", "double_bit", "twins", "combo", "throwing", "scraper", "gouge", "ringer", "labrys", "greataxe", "spud", "spiral", "robo", "thunder", "saw", "bucksaw", "pole_saw", "chainsaw", "crosscut", "drill", "twin_auger", "holesaw", "planer", "washer", "shears", "vacuum", "blower", "twinvac", "cyclone", "pickaxe", "sledge", "steel_pick", "rock_drill", "detector", "core_drill", "dynamite", "wires", "hammer", "rake", "can", "scale", "bp_crank", "bp_lever", "bp_button", "bp_conveyor", "bp_ramp", "bp_piston", "bp_rotator", "bp_wheelbarrow", "bp_windmill", "bp_generator", "bp_battery", "bp_logic", "bp_sensors", "bp_lamp", "bp_sawmill", "bp_chipper", "bp_planter", "bp_sprinkler", "bp_feller", "bp_smelter", "bp_kiln", "bp_assembler", "bp_grabber", "bp_sorter", "bp_crate", "bp_wireless", "bp_drill_rig", "bp_charger", "bp_carts", "bp_rail_tools", "bp_rail_extras", "bp_drones", "bp_oil", "bp_truck_caller", "truck_big", "truck_hauler", "phone" }
Config.ToolOrder = {} :: { string }
local allTools: { [string]: any } = Config.Tools :: any
for _, id in GODOT_TOOL_ORDER do
	local have: boolean = id == "hands" or allTools[id] ~= nil
	if have then
		table.insert(Config.ToolOrder, id)
	end
end
Config.ShopOrder = {} :: { string }        -- (filled in below, once Config.Items is known)
Config._godotShopOrder = GODOT_SHOP_ORDER
Config.GodotToolOrder = GODOT_TOOL_ORDER    -- (the toast's number when a tool arrives is its place in this, like Godot's)

-- Godot's TimberMart departments (Tools.CATEGORIES) and which one each item is in (SHOP's "cat")
Config.ShopDepts = { { "all", "Everything" }, { "axes", "Axes" }, { "saws", "Saws" }, { "specialty", "Specialty Tools" }, { "mining", "Mining" }, { "blueprints", "Machine Blueprints" }, { "other", "Other" } }
Config.ShopCat = {
	hatchet = "axes",
	double_bit = "axes",
	labrys = "axes",
	twins = "axes",
	combo = "axes",
	scraper = "axes",
	gouge = "axes",
	ringer = "axes",
	greataxe = "axes",
	drill = "specialty",
	saw = "saws",
	shears = "specialty",
	robo = "axes",
	chainsaw = "saws",
	bucksaw = "saws",
	twin_auger = "specialty",
	holesaw = "specialty",
	twinvac = "specialty",
	cyclone = "specialty",
	pickaxe = "mining",
	steel_pick = "mining",
	rock_drill = "mining",
	core_drill = "mining",
	wires = "specialty",
	bp_crank = "blueprints",
	bp_lever = "blueprints",
	bp_button = "blueprints",
	bp_conveyor = "blueprints",
	bp_ramp = "blueprints",
	bp_piston = "blueprints",
	bp_rotator = "blueprints",
	bp_truck_caller = "blueprints",
	hammer = "other",
	vacuum = "specialty",
	throwing = "axes",
	spiral = "axes",
	spud = "axes",
	thunder = "axes",
	pole_saw = "saws",
	crosscut = "saws",
	planer = "specialty",
	washer = "specialty",
	rake = "other",
	blower = "specialty",
	sledge = "mining",
	detector = "mining",
	dynamite = "mining",
	can = "other",
	scale = "other",
	truck_big = "other",
	truck_hauler = "other",
	bp_windmill = "blueprints",
	bp_generator = "blueprints",
	bp_battery = "blueprints",
	bp_logic = "blueprints",
	bp_sensors = "blueprints",
	bp_lamp = "blueprints",
	bp_sawmill = "blueprints",
	bp_chipper = "blueprints",
	bp_planter = "blueprints",
	bp_sprinkler = "blueprints",
	bp_smelter = "blueprints",
	bp_kiln = "blueprints",
	bp_assembler = "blueprints",
	bp_grabber = "blueprints",
	bp_sorter = "blueprints",
	bp_crate = "blueprints",
	bp_wireless = "blueprints",
	bp_drill_rig = "blueprints",
	bp_charger = "blueprints",
	bp_carts = "blueprints",
	bp_rail_tools = "blueprints",
	bp_rail_extras = "blueprints",
	bp_oil = "blueprints",
	bp_drones = "blueprints",
	bp_feller = "blueprints",
	bp_wheelbarrow = "blueprints",
	phone = "other",
}

-- things you can buy that aren't tools (Godot's SHOP entries in "other")
Config.Items = {
	bp_crank = { name = "Hand Crank Blueprint", price = 150, tag = "Power", blueprint = true,
		desc = "Plans for a hand crank: wind it with E and it powers everything wired to it for a few seconds." },
	bp_lever = { name = "Lever Blueprint", price = 80, tag = "Switch", blueprint = true,
		desc = "Plans for a lever: flip it to let power through to the machines beyond it, or cut them off." },
	bp_button = { name = "Button Blueprint", price = 60, tag = "Switch", blueprint = true,
		desc = "Plans for a big push button: lets power through for a moment when pressed." },
	bp_conveyor = { name = "Conveyor Blueprint", price = 250, tag = "Machine", blueprint = true,
		desc = "Plans for a powered conveyor belt section. Chain them up to move logs, bark and anything else." },
	bp_ramp = { name = "Ramp Conveyor Blueprint", price = 200, tag = "Machine", blueprint = true,
		desc = "Plans for a sloped conveyor that carries things up (or down) a level." },
	bp_piston = { name = "Piston Blueprint", price = 600, tag = "Machine", blueprint = true,
		desc = "Plans for a piston: when powered it shoves its plate out a metre, pushing whatever's in front." },
	bp_rotator = { name = "Rotator Blueprint", price = 500, tag = "Machine", blueprint = true,
		desc = "Plans for a powered turntable. Stick something on it with the hammer and it spins it round." },
	bp_truck_caller = { name = "Truck Caller Blueprint", price = 900, tag = "Machine", blueprint = true,
		desc = "Plans for a signal post that sends the log truck off to the mill whenever it gets power." },
	bp_windmill = { name = "Windmill Blueprint", price = 700, tag = "Power", blueprint = true,
		desc = "Plans for a windmill: free power whenever there's enough wind. The wind comes and goes, so pair it with a battery." },
	bp_generator = { name = "Generator Blueprint", price = 1100, tag = "Power", blueprint = true,
		desc = "Plans for a generator: drop bark, leaves or wood into its hopper and it burns them for steady power." },
	bp_battery = { name = "Battery Blueprint", price = 900, tag = "Power", blueprint = true,
		desc = "Plans for a battery: it charges while its network has power and takes over when the power goes." },
	bp_logic = { name = "Logic Kit", price = 600, tag = "Logic", blueprint = true,
		desc = "Plans for seven logic blocks: one-way, relay, inverting relay, timer, delay, toggle latch and counter. Each has a back, sides and a front - the arrow shows which way power goes." },
	bp_sensors = { name = "Sensors Blueprint", price = 450, tag = "Logic", blueprint = true,
		desc = "Plans for a pressure plate, an item sensor and a level sensor (on when the crate in front holds enough): switches that the world flips for you." },
	bp_lamp = { name = "Lamp & Bell Blueprint", price = 120, tag = "Decor", blueprint = true,
		desc = "Plans for a lamp that lights while powered and a bell that rings when power arrives." },
	bp_sawmill = { name = "Sawmill Blueprint", price = 1500, tag = "Production", blueprint = true,
		desc = "Plans for a sawmill: lay a log on the table and power it to cut it into planks. Planks are worth half as much again as the log - more if you stripped the bark first." },
	bp_chipper = { name = "Chipper Blueprint", price = 1000, tag = "Production", blueprint = true,
		desc = "Plans for a chipper: feed it bark and leaves and it bags them up as mulch, worth more than the loose bits." },
	bp_planter = { name = "Planter Blueprint", price = 900, tag = "Tree Farm", blueprint = true,
		desc = "Plans for a planter: drop saplings into it and power it, and it plants them in a row in front." },
	bp_sprinkler = { name = "Sprinkler Blueprint", price = 500, tag = "Tree Farm", blueprint = true,
		desc = "Plans for a sprinkler: while powered, every sapling nearby grows twice as fast." },
	bp_smelter = { name = "Smelter Blueprint", price = 1400, tag = "Production", blueprint = true,
		desc = "Plans for a smelter: copper and iron ore in, metal bars out - worth twice the ore, and needed for the fancier builds." },
	bp_kiln = { name = "Kiln Blueprint", price = 800, tag = "Production", blueprint = true,
		desc = "Plans for a kiln: dries planks, which makes them worth 40% more." },
	bp_assembler = { name = "Assembler Blueprint", price = 1800, tag = "Production", blueprint = true,
		desc = "Plans for an assembler: feed it planks and metal bars and it makes furniture - chairs, tables, lanterns, cabinets, toy trucks - that sells for 2.5x what went in." },
	bp_grabber = { name = "Grabber Arm Blueprint", price = 1200, tag = "Logistics", blueprint = true,
		desc = "Plans for a grabber arm: picks up whatever is in front of it and swings it round behind." },
	bp_sorter = { name = "Sorter Belts Blueprint", price = 900, tag = "Logistics", blueprint = true,
		desc = "Plans for a sorter belt (sends one kind of thing off to the side) and a splitter belt (every other thing)." },
	bp_crate = { name = "Storage Crate Blueprint", price = 300, tag = "Logistics", blueprint = true,
		desc = "Plans for a big storage crate. Power it and it empties out of its front, one thing at a time." },
	bp_wireless = { name = "Wireless Blueprint", price = 1000, tag = "Logistics", blueprint = true,
		desc = "Plans for a transmitter and receiver: power on one channel turns on every receiver on that channel, however far away." },
	bp_drill_rig = { name = "Drill Rig Blueprint", price = 2000, tag = "Mining", blueprint = true,
		desc = "Plans for a drill rig: put your rock drill (or steel core drill) in it and power it, and it drills straight down by itself, dropping what it digs out of its chute. It only goes so deep - then move it." },
	bp_charger = { name = "Charger Blueprint", price = 1200, tag = "Power", blueprint = true,
		desc = "Plans for a charger: drop battery cells (made in the assembler from a copper bar and an iron bar) into it and power it to charge them. Anything that moves runs on a charged cell." },
	bp_carts = { name = "Minecart Blueprint", price = 3000, tag = "Rails", blueprint = true,
		desc = "Plans for minecarts 1 to 4 squares long, Go and Reverse blocks for their decks, and a cart sensor for stations. Build a cart on rails, give it a charged cell, build machines on its deck - they share its power - and wire up what makes it go." },
	bp_rail_tools = { name = "Rail Layer & Lifter Blueprint", price = 2500, tag = "Rails", blueprint = true,
		desc = "Plans for two cart parts: a rail layer that lays a rail from a crate on the cart when the track runs out, and a rail lifter that picks up the rail behind into a crate." },
	bp_rail_extras = { name = "Rail Yard Blueprint", price = 1800, tag = "Rails", blueprint = true,
		desc = "Plans for a rail switch (branches the track while powered), a rail buffer (stops carts until powered) and a cart unloader (empties the crate on a cart beside it out of its front, onto a belt)." },
	bp_oil = { name = "Oil Rig Blueprint", price = 4500, tag = "Oil", blueprint = true,
		desc = "Plans for an oil pump (a pumpjack: build it over an oil pocket and power it to fill barrels) and a refinery (oil in, a fuel can and a plastic sheet out). Fuel burns four times as long as wood in a generator; plastic makes lawn chairs and buckets in the assembler. The ore detector hums low over oil." },
	bp_drones = { name = "Drone Blueprint", price = 4000, tag = "Flying", blueprint = true,
		desc = "Plans for small, medium and large drones. They run on a battery cell and carry one thing - as heavy as their size can lift. No wires: five dials on each drone listen to wireless channels, one per direction and one for the pad that picks up and drops. Includes a drone pad that charges drones over it." },
	bp_feller = { name = "Tree Feller Blueprint", price = 2200, tag = "Tree Farm", blueprint = true,
		desc = "Plans for an automatic tree feller. Put your saw into it and power it: it saws down the tree in front of it." },
	bp_wheelbarrow = { name = "Wheelbarrow Blueprint", price = 600, tag = "Hauling", blueprint = true,
		desc = "Plans for a wheelbarrow: grab its handles and push it along the ground. It carries a big load of bark, ore or short logs." },
	truck_big = { name = "Big Truck", price = 3500, tag = "Hauling", vehicle = 1,
		desc = "A wider truck with tall sides: carries twice as much per trip. Your old truck drives off and this one comes back in its place." },
	truck_hauler = { name = "Log Hauler", price = 14000, tag = "Hauling", vehicle = 2,
		desc = "The biggest truck there is: a long, deep bed for whole factories' worth of goods. It replaces the truck you have." },
	phone = { name = "TimberPhone", price = 350, tag = "Pocket-size",
		desc = "Shop TimberMart and send the log truck off from anywhere in the forest. Press Tab to use it." },
}
local allItems: { [string]: any } = Config.Items :: any
for _, id in Config._godotShopOrder do
	local have: boolean = allTools[id] ~= nil or allItems[id] ~= nil
	if have then
		table.insert(Config.ShopOrder, id)
	end
end
Config.ComboMax = 4             -- the combo axe grows 0.05 m a hit in a row, up to 4 (and resets after 1.25 s)

-- the player (Godot's Player.gd, in metres; x3 for studs)
Config.Player = { walk = 4.2, sprint = 6.8, jump = 4.6, gravity = 12, grabReach = 2.6, fov = 75, regenDelay = 3, regenPerSecond = 5, faintSeconds = 2.2 }
Config.StudsPerMetre = 3
-- the walkable terrain lies this far (studs) under Godot's ground mesh, which is what you see; characters stand this
-- much higher so their feet are on the ground you see, as in Godot (WorldService, Health)
Config.GroundSink = 0.6

-- The golden tree (a timed server event, as popular Roblox games have): every `every` seconds with someone on the
-- server, a standing tree near the cabin turns gold for `lasts` seconds; its outer bark is worth `value` times as much.
Config.GoldenTree = { every = 900, lasts = 600, value = 5, within = 120 }    -- (within: metres of the cabin)

-- Codes to type into the TimberPhone (a Roblox staple: post them where players follow the game). Each pays once per
-- player. Add or retire codes here and publish; codes are matched without regard to case.
Config.Codes = {
	TIMBER = 100,
	LUMBERJACK = 250,
} :: { [string]: number }

-- Roblox badges for the trophies (and one for playing at all): make each badge on the Creator Dashboard
-- (Creations > Timber > Engagement > Badges), then put its id here. 0 = no badge yet (nothing is awarded).
Config.Badges = {
	welcome = 0,
	first_tree = 0, first_machine = 0, thousand = 0, first_plank = 0, first_iron = 0, first_furniture = 0,
	giant = 0, legend = 0, first_oil = 0,
	-- (and for the Roblox features: the golden tree felled, a week's daily streak, all of a day's jobs done)
	golden = 0, week = 0, jobs = 0,
} :: { [string]: number }

-- today's jobs (JobsService): the bonus for finishing all three in a day
Config.JobsAllBonus = 50

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
