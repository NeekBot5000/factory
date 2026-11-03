--!strict
-- Draws the bark the way the Godot game does (ForestTree.gd _rebuild / _panel_color): the trunk is 16 panels round
-- and one panel per 0.18 m high, every panel a slightly different shade of its kind's bark (birch has dark flecks),
-- so a tree has that checkered low-poly look. Peel the outer bark and the inner layer shows underneath in its own
-- colour; peel that and the pale wood shows.
-- Each panel is a Part, made on this client only (never replicated, so no network cost), and only for trees near
-- you. Far trees are the server's plain trunk. A tree is redrawn when its "Bark" attribute changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local BarkGrid = require(ReplicatedStorage.Shared.BarkGrid)

local TreeVisuals = {}
local M = Config.StudsPerMetre
local T = Config.Tree
local DETAIL_RANGE = 110          -- studs: nearer trees get their panels
local PER_FRAME = 2               -- trees built per frame, so walking into the forest doesn't hitch
local queue: { Model } = {}

local function shade(c: Color3, k: number): Color3
	-- Godot's Color.lightened (k > 0) / darkened (k < 0)
	return if k >= 0 then c:Lerp(Color3.new(1, 1, 1), k) else c:Lerp(Color3.new(0, 0, 0), -k)
end

-- a fixed pseudo-random 0..1 for a panel (Godot hashes (i, j, seed + layer * 7) the same way every time)
local function hash01(i: number, j: number, seed: number): number
	local h = bit32.bxor(bit32.band(i * 73856093, 0xFFFFFFFF), bit32.band(j * 19349663, 0xFFFFFFFF), bit32.band(seed * 83492791, 0xFFFFFFFF))
	h = bit32.band(bit32.bxor(h, bit32.rshift(h, 13)) * 1274126177, 0xFFFFFFFF)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return (h % 1000) / 1000
end

-- the colour of one panel (Godot's _panel_color)
function TreeVisuals.panelColor(species: string, layer: number, i: number, j: number, seed: number): Color3
	local sp = (Config.Species :: any)[species] or Config.Species.oak
	local h = hash01(i, j, seed + layer * 7)
	if layer == BarkGrid.OUTER then
		local bark = Color3.fromHex(sp.bark)
		if species == "birch" then
			return if h < 0.12 then shade(bark, -0.35) else shade(bark, -h * 0.08)
		end
		return shade(bark, (h - 0.5) * 0.18)
	end
	return shade(Color3.fromHex(sp.inner), (h - 0.5) * 0.12)
end

local function panel(folder: Instance, base: CFrame, i: number, j: number, rOut: number, thick: number, color: Color3)
	-- a flat panel whose outer face is the Godot quad between corners i and i+1 at radius rOut
	local half = math.pi / T.sectors
	local chord = 2 * rOut * math.sin(half)
	local a = (i + 0.5) / T.sectors * 2 * math.pi
	local bandH = T.bandH * M
	local face = rOut * math.cos(half)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(chord * 1.005, bandH, thick)
	p.Color = color
	-- Godot's angle runs from +X towards +Z: x = cos(a) r, z = sin(a) r
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local center = base.Position + base:VectorToWorldSpace(dir * (face - thick / 2) + Vector3.new(0, (j + 0.5) * bandH, 0))
	p.CFrame = CFrame.lookAt(center, center + base:VectorToWorldSpace(dir))
	p.Parent = folder
end

function TreeVisuals.build(tree: Model)
	local old = tree:FindFirstChild("BarkPanels")
	if old then
		old:Destroy()
	end
	local sectors, bands = tree:GetAttribute("Sectors") :: number or 16, tree:GetAttribute("Bands") :: number or 33
	local s = tree:GetAttribute("Bark")
	local g = if typeof(s) == "string" then BarkGrid.decode(sectors, bands, s) else BarkGrid.new(sectors, bands)
	if not g then
		return
	end
	local species = tree:GetAttribute("Species") :: string or "oak"
	local sp = (Config.Species :: any)[species] or Config.Species.oak
	local seed = tree:GetAttribute("Seed") :: number or 1
	local R = tree:GetAttribute("Radius") :: number or 1.2
	local rMid = R - T.outerT * M
	local rCore = rMid - T.innerT * M
	local base = tree:GetPivot()
	local folder = Instance.new("Folder")
	folder.Name = "BarkPanels"
	-- the wood: one tall panel per side (only seen where both layers are gone)
	local wood = Color3.fromHex(sp.wood)
	for i = 0, sectors - 1 do
		local half = math.pi / sectors
		local a = (i + 0.5) / sectors * 2 * math.pi
		local h = bands * T.bandH * M
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Size = Vector3.new(2 * rCore * 0.985 * math.sin(half) * 1.01, h, rCore * 0.4)
		p.Color = wood
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local center = base.Position + base:VectorToWorldSpace(dir * (rCore * 0.985 * math.cos(half) - rCore * 0.2) + Vector3.new(0, h / 2, 0))
		p.CFrame = CFrame.lookAt(center, center + base:VectorToWorldSpace(dir))
		p.Parent = folder
	end
	for j = 0, bands - 1 do
		for i = 0, sectors - 1 do
			if BarkGrid.has(g, BarkGrid.OUTER, i, j) then
				panel(folder, base, i, j, R, T.outerT * M, TreeVisuals.panelColor(species, BarkGrid.OUTER, i, j, seed))
			elseif BarkGrid.has(g, BarkGrid.INNER, i, j) then
				panel(folder, base, i, j, rMid, T.innerT * M, TreeVisuals.panelColor(species, BarkGrid.INNER, i, j, seed))
			end
		end
	end
	folder.Parent = tree
	local trunk = tree:FindFirstChild("Trunk") :: BasePart?
	if trunk then
		trunk.LocalTransparencyModifier = 1
	end
end

local function drop(tree: Model)
	local f = tree:FindFirstChild("BarkPanels")
	if f then
		f:Destroy()
	end
	local trunk = tree:FindFirstChild("Trunk") :: BasePart?
	if trunk then
		trunk.LocalTransparencyModifier = 0
	end
end

local function want(tree: Model)
	if not table.find(queue, tree) then
		table.insert(queue, tree)
	end
end

function TreeVisuals.start()
	-- a tree's bark changed: redraw it straight away if it's near
	local function watch(inst: Instance)
		local tree = inst :: Model
		tree:GetAttributeChangedSignal("Bark"):Connect(function()
			if tree:FindFirstChild("BarkPanels") then
				TreeVisuals.build(tree)
			end
		end)
	end
	for _, t in CollectionService:GetTagged("Tree") do
		watch(t)
	end
	CollectionService:GetInstanceAddedSignal("Tree"):Connect(watch)
	local acc = 1
	RunService.Heartbeat:Connect(function(dt)
		-- build a couple of queued trees each frame
		for _ = 1, PER_FRAME do
			local tree = table.remove(queue, 1)
			if not tree then
				break
			end
			if tree.Parent and not tree:FindFirstChild("BarkPanels") then
				TreeVisuals.build(tree)
			end
		end
		-- twice a second: queue trees that came near, drop the ones that went far
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		for _, inst in CollectionService:GetTagged("Tree") do
			local tree = inst :: Model
			local near = (tree:GetPivot().Position - cam.CFrame.Position).Magnitude < DETAIL_RANGE
			local built = tree:FindFirstChild("BarkPanels") ~= nil
			if near and not built then
				want(tree)
			elseif not near and built then
				drop(tree)
			end
		end
	end)
end

return TreeVisuals
