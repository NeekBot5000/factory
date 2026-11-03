--!strict
-- A small test world, so the very first Play in a fresh place has something to do: a ring of trees of every species
-- around the spawn, and a log truck with a "Ship" prompt. Only builds when the place has no Forest folder yet
-- (once you've built your own map, put a Folder named "Forest" in Workspace and this does nothing).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local TestWorld = {}


local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local M = Config.StudsPerMetre

local function hex(h: string, lighten: number?): Color3
	local c = Color3.fromHex(h)
	local k = lighten or 0
	return if k >= 0 then c:Lerp(Color3.new(1, 1, 1), k) else c:Lerp(Color3.new(0, 0, 0), -k)
end

-- A tree, built like the Godot game's ForestTree: an invisible trunk to hit and bump into (the bark itself is drawn
-- by each client, panel by panel: Client/Controllers/TreeVisuals), a darker root flare, and the crown for its kind.
-- radius is in metres, bands the trunk's height in 0.18 m panels; the model's pivot is the base of the trunk.
local function makeTree(parent: Instance, species: string, at: Vector3, radius: number, bands: number, rng: Random)
	local T = Config.Tree
	local sp = (Config.Species :: any)[species]
	local m = Instance.new("Model")
	m.Name = "Tree_" .. species
	local R = radius * M
	local H = bands * T.bandH * M
	-- the trunk: what you hit and walk into, and what far-away trees show (until a client draws the panels)
	local trunk = part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(H, R * 2, R * 2),
		CFrame = CFrame.new(at + Vector3.new(0, H / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromHex(sp.bark), Material = Enum.Material.SmoothPlastic })
	trunk.Parent = m
	-- the root flare (Godot: a 0.35 m cone from 1.45 to 1.02 of the radius, a little darker)
	part({ Name = "Roots", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35 * M, R * 2.47, R * 2.47),
		CFrame = CFrame.new(at + Vector3.new(0, 0.1 * M, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = hex(sp.bark, -0.15),
		Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = m
	local crown = Instance.new("Model")
	crown.Name = "Crown"
	local function blob(center: Vector3, r: number, color: Color3)
		part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * r * 2 * M, CFrame = CFrame.new(at + center * M),
			Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = crown
	end
	local th = bands * T.bandH
	if species == "pine" or species == "cedar" then
		-- four stacked cones, shrinking upwards
		local green = if species == "pine" then "2f6b3a" else "3d6b45"
		for k = 0, 3 do
			local r = 2.0 - k * 0.42
			local y = th - 1.2 + k * 1.05 + 0.9
			local tier = part({ Name = "Leaves", Size = Vector3.new(r * 1.45 * M, 1.9 * M, r * 1.45 * M),
				CFrame = CFrame.new(at + Vector3.new(0, y * M, 0)) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 60)), 0),
				Color = hex(green, k * 0.04), Material = Enum.Material.SmoothPlastic, CanCollide = false })
			tier.Parent = crown
		end
	elseif species == "birch" or species == "eucalyptus" then
		for _ = 1, 4 do
			local off = Vector3.new(rng:NextNumber(-0.8, 0.8), th + rng:NextNumber(-0.6, 1.2), rng:NextNumber(-0.8, 0.8))
			blob(off, rng:NextNumber(0.9, 1.4), hex("7fb34a", math.floor(rng:NextNumber(0, 0.1) / 0.02 + 0.5) * 0.02))
		end
	else
		blob(Vector3.new(0, th + 0.9, 0), 1.9, hex("4f9a3c"))
		for _ = 1, 3 do
			local off = Vector3.new(rng:NextNumber(-1.3, 1.3), th + rng:NextNumber(0.2, 1.6), rng:NextNumber(-1.3, 1.3))
			blob(off, 1.2, hex("5aab44", math.floor(rng:NextNumber(0, 0.08) / 0.02 + 0.5) * 0.02))
		end
	end
	crown.Parent = m
	m.WorldPivot = CFrame.new(at)          -- the pivot is the base of the trunk: the bark grid measures up from here
	m:SetAttribute("Species", species)
	m:SetAttribute("Sectors", T.sectors)
	m:SetAttribute("Bands", bands)
	m:SetAttribute("Radius", R)            -- studs (the bark is drawn from this)
	m:SetAttribute("Height", H)
	m:SetAttribute("Seed", rng:NextInteger(1, 1000000))
	m.Parent = parent
	CollectionService:AddTag(m, "Tree")
end

local function rock(parent: Instance, at: Vector3, s: number, rng: Random)
	for k = 1, 3 do
		part({ Size = Vector3.new(s * rng:NextNumber(0.7, 1.3), s * rng:NextNumber(0.5, 0.9), s * rng:NextNumber(0.7, 1.3)),
			CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-s, s) * 0.4, s * 0.2, rng:NextNumber(-s, s) * 0.4)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5)),
			Color = Color3.fromRGB(138, 135, 128):Lerp(Color3.fromRGB(100, 98, 94), rng:NextNumber(0, 1)), Material = Enum.Material.Slate }).Parent = parent
	end
end

-- the log truck: a cab, a wooden bed with sides, wheels; drop bark in the back, then look at it and press E
local function makeTruck(at: Vector3)
	local truck = Instance.new("Model")
	truck.Name = "Truck"
	local green = Color3.fromRGB(47, 140, 70)
	local bed = part({ Name = "Bed", Size = Vector3.new(8, 1, 12), Position = at + Vector3.new(0, 3, 0), Color = Color3.fromRGB(110, 78, 50), Material = Enum.Material.WoodPlanks })
	bed.Parent = truck
	for _, side in { { Vector3.new(4, 1.5, 0), Vector3.new(0.5, 2.5, 12) }, { Vector3.new(-4, 1.5, 0), Vector3.new(0.5, 2.5, 12) }, { Vector3.new(0, 1.5, 6), Vector3.new(8, 2.5, 0.5) } } do
		part({ Size = side[2], Position = bed.Position + side[1], Color = Color3.fromRGB(86, 62, 42), Material = Enum.Material.WoodPlanks }).Parent = truck
	end
	part({ Size = Vector3.new(8.4, 1, 21), Position = at + Vector3.new(0, 2, -4.5), Color = Color3.fromRGB(45, 48, 54), Material = Enum.Material.Metal }).Parent = truck
	local cab = part({ Name = "Cab", Size = Vector3.new(8, 6, 7), Position = at + Vector3.new(0, 5.5, -10), Color = green, Material = Enum.Material.SmoothPlastic })
	cab.Parent = truck
	part({ Size = Vector3.new(7, 2.6, 0.2), Position = cab.Position + Vector3.new(0, 1, -3.5), Color = Color3.fromRGB(170, 220, 240), Material = Enum.Material.Glass, Transparency = 0.2 }).Parent = truck
	part({ Size = Vector3.new(8, 3, 3.5), Position = at + Vector3.new(0, 3.5, -14.6), Color = green, Material = Enum.Material.SmoothPlastic }).Parent = truck
	for _, z in { 3.5, -3.5, -12 } do
		for _, x in { -4.2, 4.2 } do
			part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 3.4, 3.4), CFrame = CFrame.new(at + Vector3.new(x, 1.7, z)),
				Color = Color3.fromRGB(35, 36, 40), Material = Enum.Material.Rubber }).Parent = truck
		end
	end
	truck.WorldPivot = CFrame.new(at)        -- it drives by its pivot (forward is -Z, the way the cab faces)
	truck:SetAttribute("State", "parked")
	truck.Parent = workspace
end

-- TimberMart: a market stall with an awning; E at its counter opens the tool shop
local function makeShop(at: Vector3)
	local stall = Instance.new("Model")
	stall.Name = "TimberMart"
	local wood = Color3.fromRGB(150, 105, 62)
	local counter = part({ Name = "Counter", Size = Vector3.new(10, 3.5, 3), Position = at + Vector3.new(0, 1.75, 0), Color = wood, Material = Enum.Material.WoodPlanks })
	counter.Parent = stall
	for _, x in { -4.6, 4.6 } do
		part({ Size = Vector3.new(0.6, 9, 0.6), Position = at + Vector3.new(x, 4.5, 1.2), Color = wood, Material = Enum.Material.Wood }).Parent = stall
	end
	-- a striped awning (alternating colours read as "shop" instantly)
	for k = 0, 4 do
		part({ Size = Vector3.new(2.2, 0.3, 4.4), CFrame = CFrame.new(at + Vector3.new(-4.4 + k * 2.2, 9, 0.4)) * CFrame.Angles(math.rad(-14), 0, 0),
			Color = if k % 2 == 0 then Color3.fromRGB(232, 96, 60) else Color3.fromRGB(250, 240, 220), Material = Enum.Material.Fabric }).Parent = stall
	end
	local sign = part({ Name = "Sign", Size = Vector3.new(7, 1.8, 0.3), Position = at + Vector3.new(0, 10.6, -1.6), Color = Color3.fromRGB(43, 33, 24), Material = Enum.Material.Wood })
	sign.Parent = stall
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "TimberMart"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 207, 106)
	label.Parent = gui
	gui.Parent = sign
	stall:SetAttribute("Marker", "shop")
	stall.Parent = workspace
end

-- Godot's chopping block, just in front of where you start, with the old hatchet stuck in it (E takes it)
local function choppingBlock(at: Vector3)
	local m = Instance.new("Model")
	m.Name = "ChoppingBlock"
	local stump = part({ Name = "Stump", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 2.8, 2.8),
		CFrame = CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(122, 86, 56), Material = Enum.Material.Wood })
	stump.Parent = m
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 2.5, 2.5), CFrame = CFrame.new(at + Vector3.new(0, 2.42, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(214, 176, 128), Material = Enum.Material.Wood }).Parent = m
	-- the hatchet: blade buried in the top, handle rising at about 40 degrees (only shown while you don't own one)
	local ok, ToolService = pcall(require, script.Parent.ToolService)
	local h = ok and (ToolService :: any).build("hatchet")
	if h then
		h.Name = "Hatchet"
		local look = (Config.Tools :: any).hatchet.look
		h:PivotTo(CFrame.new(at + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, math.rad(30), 0) * CFrame.Angles(math.rad(-50), 0, 0)
			* CFrame.new(0, -look.handle * 0.5 + 0.9, 0.35) * CFrame.new(0, look.handle * 0.3, 0))
		for _, p in h:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanQuery = true
				p.CastShadow = true
			end
		end
		h.Parent = m
	end
	m.Parent = workspace
end

-- the dirt road the truck drives down to the mill
local ROAD_X = -18
local function road()
	part({ Name = "Road", Size = Vector3.new(14, 0.2, 520), Position = Vector3.new(ROAD_X, 0.1, 0), Color = Color3.fromRGB(156, 128, 92),
		Material = Enum.Material.Ground, CanQuery = false }).Parent = workspace
end

function TestWorld.start()
	if workspace:FindFirstChild("Forest") then
		return
	end
	local forest = Instance.new("Folder")
	forest.Name = "Forest"
	forest.Parent = workspace
	local species = {}
	for k in Config.Species do
		table.insert(species, k)
	end
	table.sort(species)
	local rng = Random.new(42)
	-- the first trees are close and right in front of the spawn, so the first swing is seconds away
	for n = 1, 40 do
		local a = n / 40 * math.pi * 2 + rng:NextNumber(-0.06, 0.06)
		local d = if n <= 6 then rng:NextNumber(24, 34) else rng:NextNumber(38, 120)
		if n <= 6 then
			a = math.rad(-120 + n * 14)
		end
		local at = Vector3.new(math.cos(a) * d, 0, math.sin(a) * d - 6)
		if math.abs(at.X - ROAD_X) < 12 then
			at += Vector3.new(if at.X < ROAD_X then -14 else 14, 0, 0)      -- keep the road clear for the truck
		end
		makeTree(forest, species[(n % #species) + 1], at, rng:NextNumber(Config.Tree.minRadius, Config.Tree.maxRadius),
			rng:NextInteger(Config.Tree.minBands, Config.Tree.maxBands), rng)
	end
	local rocks = Instance.new("Folder")
	rocks.Name = "Rocks"
	rocks.Parent = forest
	for _ = 1, 14 do
		local a = rng:NextNumber(0, 6.28)
		local d = rng:NextNumber(30, 130)
		local at = Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if math.abs(at.X - ROAD_X) > 12 then
			rock(rocks, at, rng:NextNumber(2, 4.5), rng)
		end
	end
	road()
	makeTruck(Vector3.new(ROAD_X, 0, 4))
	makeShop(Vector3.new(18, 0, 6))
	choppingBlock(Vector3.new(2.5, 0, 6))
end

return TestWorld
