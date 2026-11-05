--!strict
-- The world, built from the Godot game's (Shared.GodotWorld, made by tools/ExportRobloxWorld.gd): the same rolling
-- ground, every tree where it stands in Godot with its kind and size, the cabin you start on the porch of, the
-- chopping block with the old hatchet in it, the computer that runs TimberMart, the log truck in its spot with its
-- road to the mill, rocks and bushes.
-- What you see comes from Godot's own meshes (WorldMeshes loads them once they're uploaded: see roblox/SETUP.md);
-- until then, simple stand-ins show where things are. What you walk on is Roblox ground shaped from Godot's heights,
-- and what you bump into are Godot's own collision boxes.
-- Only builds when the place has no Forest folder yet (a hand-built map can put a Folder named "Forest" in Workspace).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local W = require(ReplicatedStorage.Shared.GodotWorld) :: any

local WorldService = {}
local M = Config.StudsPerMetre

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

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function hex(h: string, lighten: number?): Color3
	local c = Color3.fromHex(h)
	local k = lighten or 0
	return if k >= 0 then c:Lerp(Color3.new(1, 1, 1), k) else c:Lerp(Color3.new(0, 0, 0), -k)
end

-- the ground height (studs) at x, z: Godot's heights every 3 m, between them a straight blend (like its mesh)
function WorldService.heightAt(x: number, z: number): number
	local g = W.ground
	local fx = math.clamp((x - g.origin) / g.step, 0, g.n - 1.001)
	local fz = math.clamp((z - g.origin) / g.step, 0, g.n - 1.001)
	local ix, iz = math.floor(fx), math.floor(fz)
	local tx, tz = fx - ix, fz - iz
	local function h(i: number, k: number): number
		return g.heights[k * g.n + i + 1]
	end
	local a = h(ix, iz) + (h(ix + 1, iz) - h(ix, iz)) * tx
	local b = h(ix, iz + 1) + (h(ix + 1, iz + 1) - h(ix, iz + 1)) * tx
	return a + (b - a) * tz
end

-- The ground you walk on: Roblox terrain shaped from Godot's heights, a little below Godot's ground mesh (which
-- is what you see), coloured like Godot's grass where it shows.
local function ground()
	local terrain = workspace.Terrain
	terrain.Decoration = false
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromHex("4f8a35"))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromHex("8a6a45"))
	local g = W.ground
	local res = 4
	local x0, z0 = math.floor(g.origin / res) * res, math.floor(g.origin / res) * res
	local size = (g.n - 1) * g.step
	local nx = math.floor(size / res)
	local y0, ny = -24, 18                  -- -24 .. +48 studs covers Godot's lowest valley to its outer rim
	local SINK = Config.GroundSink          -- studs below the mesh, so the voxels' softer shape stays hidden under it
	local mats, occ = {}, {}
	for ix = 1, nx do
		mats[ix], occ[ix] = {}, {}
		for iy = 1, ny do
			mats[ix][iy], occ[ix][iy] = {}, {}
		end
		for iz = 1, nx do
			-- (Roblox puts a voxel's surface half a voxel above where its occupancy says: measured by the engine check,
			-- surface = 2 + 4 x occupancy studs above the full voxel under it - so aim half a voxel lower)
			local h = WorldService.heightAt(x0 + (ix - 0.5) * res, z0 + (iz - 0.5) * res) - SINK - res / 2
			for iy = 1, ny do
				local bottom = y0 + (iy - 1) * res
				local o = math.clamp((h - bottom) / res, 0, 1)
				mats[ix][iy][iz] = if o > 0 then Enum.Material.Grass else Enum.Material.Air
				occ[ix][iy][iz] = o
			end
		end
	end
	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + nx * res, y0 + ny * res, z0 + nx * res))
	terrain:WriteVoxels(region, res, mats, occ)
end

-- A tree, built like the Godot game's ForestTree: an invisible trunk to hit and bump into (the bark itself is drawn
-- by each client, panel by panel: Client/Controllers/TreeVisuals), a darker root flare, and the crown for its kind.
-- radius is in metres, bands the trunk's height in 0.18 m panels; the model's pivot is the base of the trunk.
local function makeTree(parent: Instance, species: string, at: Vector3, radius: number, bands: number, rng: Random, yaw: number?, crowns: boolean?)
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
	if crowns == false then
		-- (the Godot meshes have this tree's root flare and crown)
		m.WorldPivot = CFrame.new(at) * CFrame.Angles(0, yaw or 0, 0)
		m:SetAttribute("Species", species)
		m:SetAttribute("Sectors", T.sectors)
		m:SetAttribute("Bands", bands)
		m:SetAttribute("Radius", R)
		m:SetAttribute("Height", H)
		m:SetAttribute("Seed", rng:NextInteger(1, 1000000))
		m.Parent = parent
		CollectionService:AddTag(m, "Tree")
		return
	end
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
	m.WorldPivot = CFrame.new(at) * CFrame.Angles(0, yaw or 0, 0)   -- the base of the trunk: the bark is measured from here
	m:SetAttribute("Species", species)
	m:SetAttribute("Sectors", T.sectors)
	m:SetAttribute("Bands", bands)
	m:SetAttribute("Radius", R)            -- studs (the bark is drawn from this)
	m:SetAttribute("Height", H)
	m:SetAttribute("Seed", rng:NextInteger(1, 1000000))
	m.Parent = parent
	CollectionService:AddTag(m, "Tree")
end


-- an invisible solid box (Godot's collision shapes: cabin walls, the porch, rocks, the chopping block)
local function solid(parent: Instance, s: any, name: string?): Part
	local cf = CFrame.fromMatrix(v3(s.p), v3(s.x), v3(s.y), v3(s.z))
	local p = part({ Name = name or "Solid", Size = v3(s.size), CFrame = cf, Transparency = 1, CastShadow = false })
	p.Parent = parent
	return p
end

-- the log truck, parked where Godot parks it: an invisible bed (what's on it ships), an invisible body to look at and
-- bump into, and simple shapes in Godot's colours until its mesh arrives
local function makeTruck()
	local t = W.truck
	local truck = Instance.new("Model")
	truck.Name = "Truck"
	local park = CFrame.new(v3(t.at)) * CFrame.Angles(0, t.yaw, 0)
	local function body(name: string, size: Vector3, at: Vector3, color: string, visible: boolean)
		local p = part({ Name = name, Size = size * M, CFrame = park * CFrame.new(at * M), Color = Color3.fromHex(color),
			Transparency = if visible then 0 else 1, CanCollide = name ~= "Bed" })
		p:SetAttribute("Standin", visible)
		p.Parent = truck
		return p
	end
	-- Godot's level-0 truck (Truck.gd): chassis, cab, hood, flatbed 2.2 x 4.0 m with 0.7 m sides
	body("Chassis", Vector3.new(2.0, 0.6, 6.2), Vector3.new(0, 0.75, 0), "2a2c31", true)
	body("Cab", Vector3.new(2.1, 2.2, 2.9), Vector3.new(0, 1.4, -2.6), "2f7d4a", true)
	body("Floor", Vector3.new(2.2, 0.15, 4.0), Vector3.new(0, 1.0, 1.0), "8a5a36", true)
	body("SideL", Vector3.new(0.12, 0.8, 4.0), Vector3.new(-1.08, 1.45, 1.0), "6f4728", true)
	body("SideR", Vector3.new(0.12, 0.8, 4.0), Vector3.new(1.08, 1.45, 1.0), "6f4728", true)
	body("Tail", Vector3.new(2.2, 0.8, 0.12), Vector3.new(0, 1.45, 3.0), "6f4728", true)
	-- what's inside this box ships (Godot's bed area)
	body("Bed", Vector3.new(2.0, 1.4, 3.8), Vector3.new(0, 1.75, 1.0), "8a5a36", false)
	truck.WorldPivot = park
	truck:SetAttribute("State", "parked")
	truck.Parent = workspace
end

-- A bigger truck (Godot's Truck.BEDS: the Big Truck and the Log Hauler): its bed, and its stand-in, grow
local BEDS = { { 2.2, 0.7, 4.0 }, { 2.6, 1.4, 4.6 }, { 2.9, 1.9, 5.2 } }
local CAB = { "2f7d4a", "2e6fb3", "b3262e" }
function WorldService.setTruckLevel(level: number)
	local truck = workspace:FindFirstChild("Truck") :: Model?
	if not truck then
		return
	end
	local park = truck:GetPivot()
	local b = BEDS[level + 1]
	local w, h, len = b[1], b[2], b[3]
	local function set(name: string, size: Vector3, at: Vector3)
		local p = truck:FindFirstChild(name) :: BasePart?
		if p then
			p.Size = size * M
			p.CFrame = park * CFrame.new(at * M)
		end
	end
	set("Floor", Vector3.new(w, 0.15, len), Vector3.new(0, 1.0, 1.0))
	set("SideL", Vector3.new(0.12, h + 0.1, len), Vector3.new(-w / 2 + 0.02, 1.1 + h / 2, 1.0))
	set("SideR", Vector3.new(0.12, h + 0.1, len), Vector3.new(w / 2 - 0.02, 1.1 + h / 2, 1.0))
	set("Tail", Vector3.new(w, h + 0.1, 0.12), Vector3.new(0, 1.1 + h / 2, 1.0 + len / 2))
	local lv = W.truck.levels and W.truck.levels[level]
	local bed = truck:FindFirstChild("Bed") :: BasePart?
	if bed then
		if level == 0 then
			bed.Size = Vector3.new(2.0, 1.4, 3.8) * M
			bed.CFrame = park * CFrame.new(Vector3.new(0, 1.75, 1.0) * M)
		elseif lv then
			bed.Size = v3(lv.size)
			bed.CFrame = park * CFrame.new(v3(lv.center))
		end
	end
	local cab = truck:FindFirstChild("Cab") :: BasePart?
	if cab then
		cab.Color = Color3.fromHex(CAB[level + 1])
	end
	truck:SetAttribute("Level", level)
end

-- TimberMart lives on the computer in the cabin (E on it opens the shop)
local function makeComputer()
	local m = Instance.new("Model")
	m.Name = "TimberMart"
	for _, c in W.computer do
		local p = solid(m, c, "Computer")
		p:SetAttribute("Standin", true)
		p.Transparency = 0
		p.Color = Color3.fromHex("d8d2c4")
	end
	m.Parent = workspace
end

-- the chopping block on the porch steps, with the old hatchet stuck in it (Godot's Main._porch_hatchet)
local function choppingBlock()
	local m = Instance.new("Model")
	m.Name = "ChoppingBlock"
	local at = v3(W.block)
	local stump = part({ Name = "Stump", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45 * M, 0.66 * M, 0.66 * M),
		CFrame = CFrame.new(at + Vector3.new(0, 0.22 * M, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromHex("6b4a32") })
	stump:SetAttribute("Standin", true)
	stump.Parent = m
	local ok, ToolService = pcall(require, script.Parent.ToolService)
	local h = ok and (ToolService :: any).build("hatchet")
	if h then
		h.Name = "Hatchet"
		WorldService.placeBlockHatchet(h)
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

-- Godot: the head 0.47 m above the block, turned 2.4 rad round, tipped 130 degrees so the blade bites into the wood
function WorldService.placeBlockHatchet(h: Model)
	local head = v3(W.block) + Vector3.new(0, 0.47 * M, 0)
	local b = CFrame.Angles(0, 2.4, 0) * CFrame.Angles(math.rad(-130), 0, 0)
	local cf, _size = h:GetBoundingBox()
	local center = h:GetPivot():PointToObjectSpace(cf.Position)
	-- Godot centres the item's model on its box; its head is 0.13 m above that centre
	h:PivotTo(CFrame.new(head) * b * CFrame.new(-Vector3.new(0, 0.13, -0.06) * M) * CFrame.new(-center))
end

function WorldService.start()
	if workspace:FindFirstChild("Forest") then
		return
	end
	-- (the Roblox baseplate would cut through Godot's valleys: the ground is Godot's now)
	local plate = workspace:FindFirstChild("Baseplate")
	if plate then
		plate:Destroy()
	end
	pcall(ground)      -- (the Lune playtests have no terrain)
	-- you start on the porch, looking out at the chopping block and the forest
	local spawnPart = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnPart then
		spawnPart.CFrame = CFrame.new(v3(W.spawn.at) + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, W.spawn.yaw, 0)
		spawnPart.Transparency = 1
		spawnPart.CanCollide = false
		spawnPart.Size = Vector3.new(4, 1, 4)
	end
	local forest = Instance.new("Folder")
	forest.Name = "Forest"
	forest.Parent = workspace
	local haveMeshes = WorldService.meshesExpected()
	local rng = Random.new(42)
	for k, t in W.trees do
		makeTree(forest, t.kind, v3(t.at), t.radius, t.bands, rng, t.yaw, not haveMeshes)
		local made = forest:GetChildren()
		made[#made]:SetAttribute("Index", k - 1)        -- (the exporter counts from 0)
		if t.giant then
			local made = forest:GetChildren()
			local tree = made[#made]
			tree:SetAttribute("Giant", true)
			tree:SetAttribute("Legendary", t.bands >= 90)
		end
	end
	-- Godot's collision boxes: cabin walls and porch, rocks, the chopping block (visible stand-ins until meshes come)
	local solids = Instance.new("Folder")
	solids.Name = "Solids"
	for _, s in W.solid do
		local p = solid(solids, s)
		-- what your feet hear (Godot: rocks are stone, the cabin, porch and dock are wood)
		local rockIdx = string.match(s.kind, "^rock_(%d+)$")
		p.Material = if string.find(s.kind, "^rock") then Enum.Material.Slate else Enum.Material.WoodPlanks
		if rockIdx then
			-- (a rock's box: mining the rock away takes its box with it, see MiningService)
			p.Name = "Rock_" .. rockIdx
			p:SetAttribute("Rock", tonumber(rockIdx))
		end
		if not haveMeshes then
			p.Transparency = 0
			p.Color = Color3.fromHex("9a8a70")
		end
	end
	solids.Parent = workspace
	-- the bushes: something for the shears to find (Godot's bushes are on their own layer that only tools look at)
	local bushes = Instance.new("Folder")
	bushes.Name = "Bushes"
	for i, b in W.bushes or {} do
		local p = part({ Name = "Bush_" .. (i - 1), Shape = Enum.PartType.Ball, Size = Vector3.one * b.r * 2,
			CFrame = CFrame.new(v3(b.at) + Vector3.new(0, b.r * 0.5, 0)), Transparency = 1, CanCollide = false, CastShadow = false })
		p:SetAttribute("Bush", i - 1)
		p:SetAttribute("Color", b.color)
		p:SetAttribute("Snips", 6)
		p.Parent = bushes
	end
	bushes.Parent = workspace
	-- Godot's lights that are part of the world (the lamp on the cabin's table)
	for _, l in W.lights or {} do
		local holder = part({ Name = "Light", Size = Vector3.one * 0.2, CFrame = CFrame.new(v3(l.at)), Transparency = 1, CanCollide = false, CanQuery = false })
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromHex(l.color)
		pl.Brightness = l.energy
		pl.Range = math.min(l.range, 60)
		pl.Shadows = false          -- (Godot's lamp casts none)
		pl.Parent = holder
		holder.Parent = workspace
	end
	makeTruck()
	makeComputer()
	choppingBlock()
end

-- a sapling has grown into a full tree (Godot's Sapling._become_tree: a new ForestTree of its kind, Godot's sizes)
function WorldService.grow(species: string, at: Vector3): Model?
	local forest = workspace:FindFirstChild("Forest")
	if not forest or not (Config.Species :: any)[species] then
		return nil
	end
	local rng = Random.new()
	makeTree(forest, species, at, rng:NextNumber(0.3, 0.46), rng:NextInteger(26, 40), rng, rng:NextNumber(0, 2 * math.pi), true)
	local made = forest:GetChildren()
	local tree = made[#made] :: Model
	tree:SetAttribute("Grown", true)
	return tree
end

-- the Godot meshes have been uploaded (Shared.Assets has their ids): the world will show them
function WorldService.meshesExpected(): boolean
	local ok, Assets = pcall(require, ReplicatedStorage.Shared.Assets)
	return ok and type(Assets) == "table" and (Assets :: any).GodotWorld ~= nil
end

return WorldService
