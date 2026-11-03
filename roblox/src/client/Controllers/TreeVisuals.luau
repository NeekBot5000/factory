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
local BarkLook = require(ReplicatedStorage.Shared.BarkLook)

local TreeVisuals = {}
local M = Config.StudsPerMetre
local T = Config.Tree
local DETAIL_RANGE = 110          -- studs: nearer trees get their panels
local PER_FRAME = 2               -- trees built per frame, so walking into the forest doesn't hitch
local queue: { Model } = {}

-- the colour of one panel (Godot's _panel_color, shared with the server's bark sheets)
TreeVisuals.panelColor = BarkLook.panelColor

local function panel(folder: Instance, base: CFrame, sectors: number, i: number, j: number, rOut: number, thick: number, color: Color3)
	local cf, size = BarkLook.panel(base, sectors, i, j, rOut, thick)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.CFrame = cf
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
				panel(folder, base, sectors, i, j, R, T.outerT * M, BarkLook.panelColor(species, BarkGrid.OUTER, i, j, seed))
			elseif BarkGrid.has(g, BarkGrid.INNER, i, j) then
				panel(folder, base, sectors, i, j, rMid, T.innerT * M, BarkLook.panelColor(species, BarkGrid.INNER, i, j, seed))
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
