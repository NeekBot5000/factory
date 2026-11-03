--!strict
-- A small test world, so the very first Play in a fresh place has something to do: a ring of trees of every species
-- around the spawn, and a log truck with a "Ship" prompt. Only builds when the place has no Forest folder yet
-- (once you've built your own map, put a Folder named "Forest" in Workspace and this does nothing).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local TestWorld = {}

local SPECIES_COLORS = {
	oak = { Color3.fromRGB(91, 64, 48), Color3.fromRGB(79, 154, 60) },
	pine = { Color3.fromRGB(77, 58, 46), Color3.fromRGB(47, 107, 58) },
	birch = { Color3.fromRGB(232, 228, 218), Color3.fromRGB(127, 179, 74) },
	hickory = { Color3.fromRGB(110, 100, 88), Color3.fromRGB(79, 154, 60) },
	cedar = { Color3.fromRGB(122, 74, 53), Color3.fromRGB(61, 107, 69) },
	cork = { Color3.fromRGB(176, 157, 128), Color3.fromRGB(90, 140, 70) },
	eucalyptus = { Color3.fromRGB(169, 172, 160), Color3.fromRGB(120, 170, 90) },
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function makeTree(parent: Instance, species: string, at: Vector3, radius: number, height: number)
	local m = Instance.new("Model")
	m.Name = "Tree_" .. species
	local colors = SPECIES_COLORS[species]
	-- the wooden core shows where both bark layers are gone
	local core = part({ Name = "Core", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, (radius - 0.3) * 2, (radius - 0.3) * 2),
		CFrame = CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(226, 192, 141), Material = Enum.Material.Wood })
	core.Parent = m
	local trunk = part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = core.CFrame, Color = colors[1], Material = Enum.Material.Wood })
	trunk.Parent = m
	local crown = part({ Name = "Crown", Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 7,
		Position = at + Vector3.new(0, height + radius * 2, 0), Color = colors[2], Material = Enum.Material.Grass, CanCollide = false })
	crown.Parent = m
	m.WorldPivot = CFrame.new(at)          -- the pivot is the base of the trunk: the bark grid measures up from here
	m:SetAttribute("Species", species)
	m:SetAttribute("Sectors", 16)
	m:SetAttribute("Bands", 40)
	m:SetAttribute("Radius", radius)
	m:SetAttribute("Height", height)
	m.Parent = parent
	CollectionService:AddTag(m, "Tree")
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
	for n = 1, 35 do
		local a = n / 35 * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local d = rng:NextNumber(35, 110)
		makeTree(forest, species[(n % #species) + 1], Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), rng:NextNumber(1.1, 1.6), rng:NextNumber(18, 26))
	end
	-- the log truck: drop bark in the back, then use the prompt on the cab
	local truck = Instance.new("Model")
	truck.Name = "Truck"
	local bed = part({ Name = "Bed", Size = Vector3.new(8, 1, 12), Position = Vector3.new(0, 2.5, -24), Color = Color3.fromRGB(110, 78, 50) })
	bed.Parent = truck
	for _, side in { { Vector3.new(4, 4, -24), Vector3.new(0.5, 3, 12) }, { Vector3.new(-4, 4, -24), Vector3.new(0.5, 3, 12) }, { Vector3.new(0, 4, -18), Vector3.new(8, 3, 0.5) } } do
		part({ Size = side[2], Position = side[1], Color = Color3.fromRGB(80, 60, 40) }).Parent = truck
	end
	local cab = part({ Name = "Cab", Size = Vector3.new(8, 7, 6), Position = Vector3.new(0, 4.5, -33), Color = Color3.fromRGB(47, 140, 70) })
	cab.Parent = truck
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ship to the mill"
	prompt.ObjectText = "Log truck"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = cab
	truck.Parent = workspace
end

return TestWorld
