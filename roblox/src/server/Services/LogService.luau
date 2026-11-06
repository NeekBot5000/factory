--!strict
-- Felling and logs, the Godot game's way (ForestTree.fell, Log.gd, Player._saw_step):
--   * hold a saw against a standing trunk: when it's through (2.6 s for an average tree with the bow saw; bigger
--     trees take longer; the chainsaw is 3.2x faster), the tree falls away from you as a log, crown and all, and
--     leaves a stump. The ancient giants need a chainsaw.
--   * a log keeps the tree's bark (axes still peel it), can be sawn in two, or bucked into rounds with the buck saw,
--     carried when it's 3 m or shorter, and sold in the truck: 60 a metre for clean timber at Godot's average
--     radius, but a log still in all its bark fetches only 15% of that.
-- The client saws and says when it's through; the server checks the saw, the reach and that it took long enough.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local BarkGrid = require(ReplicatedStorage.Shared.BarkGrid)
local ToolService = require(script.Parent.ToolService)
local TreeService = require(script.Parent.TreeService)

local LogService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local T = Config.Tree
local started: { [Player]: { target: Instance, t: number } } = {}

-- logs have a folder of their own (swings pass through loose bark lying around, but not through logs)
local function loose(): Instance
	local f = workspace:FindFirstChild("Logs")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Logs"
		f.Parent = workspace
	end
	return f :: Instance
end

-- the trunk Part of a tree or log
local function trunkOf(m: Model): BasePart?
	return m:FindFirstChild("Trunk") :: BasePart?
end

-- how long this cut should take (seconds), Godot's numbers
function LogService.sawTime(target: Model, tool: any): number
	if target:GetAttribute("Log") then
		return Config.Saw.logTime / (tool.speed or 1)
	end
	local r = (target:GetAttribute("Radius") :: number or 1.14) / M
	return Config.Saw.treeTime * (r / 0.38) * (if target:GetAttribute("Legendary") then 3 else 1) / (tool.speed or 1)
end

-- What a log is worth at the mill (Godot's Log.value)
function LogService.value(log: Model): number
	local g = TreeService.gridOf(log)
	local length = (log:GetAttribute("Bands") :: number) * T.bandH
	local r = (log:GetAttribute("Radius") :: number) / M
	local clean = if log:GetAttribute("Clean") then 1.2 else 1
	return math.floor(BarkGrid.logValue(g, length, r) * clean * 100 + 0.5) / 100
end

-- A log of bands j0..j1 of `src`'s bark, lying where that part of the trunk was (`base`: its bottom, +Y along it).
local function makeLog(src: Model, g: BarkGrid.Grid, j0: number, j1: number, base: CFrame, j0Colour: number): Model
	local bands = j1 - j0
	local R = src:GetAttribute("Radius") :: number
	local L = bands * T.bandH * M
	local log = Instance.new("Model")
	log.Name = "Log_" .. (src:GetAttribute("Species") :: string)
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(L, R * 2, R * 2)
	trunk.CFrame = base * CFrame.new(0, L / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Color = Color3.fromHex(((Config.Species :: any)[src:GetAttribute("Species")] or Config.Species.oak).bark)
	trunk.Material = Enum.Material.SmoothPlastic
	trunk.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.9, 0.05)     -- Godot: friction 0.9, bounce 0.05
	trunk.Parent = log
	log.PrimaryPart = trunk
	-- the pivot is the log's bottom end, +Y along it (like a standing tree's), so the bark grid fits it the same way
	trunk.PivotOffset = CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(0, -L / 2, 0)
	for _, k in { "Species", "Sectors", "Radius", "Seed", "Clean", "Golden" } do      -- (a golden tree's logs keep their gold)
		log:SetAttribute(k, src:GetAttribute(k))
	end
	log:SetAttribute("Bands", bands)
	log:SetAttribute("Height", L)
	log:SetAttribute("J0", j0Colour)
	log:SetAttribute("Log", true)
	log:SetAttribute("Kind", "log")
	log:SetAttribute("Bark", BarkGrid.encode(BarkGrid.slice(g, j0, j1)))
	log.Parent = loose()
	CollectionService:AddTag(log, "Tree")
	return log
end

-- a standing tree's crown: its Godot mesh parts, or the stand-in parts
function LogService.crownParts(tree: Model): { BasePart }
	local parts: { BasePart } = {}
	local crowns = workspace:FindFirstChild("GodotCrowns")
	local idx = tree:GetAttribute("Index")
	if crowns and idx then
		for _, p in crowns:GetChildren() do
			if p:IsA("BasePart") and p:GetAttribute("GodotName") == "crown_" .. tostring(idx) then
				table.insert(parts, p)
			end
		end
	end
	local standin = tree:FindFirstChild("Crown")
	if standin then
		for _, p in standin:GetDescendants() do
			if p:IsA("BasePart") then
				table.insert(parts, p)
			end
		end
	end
	return parts
end

-- the crown of a standing tree goes with the log
local function moveCrown(tree: Model, log: Model)
	local trunk = trunkOf(log) :: BasePart
	local parts = LogService.crownParts(tree)
	local standin = tree:FindFirstChild("Crown")
	for _, p in parts do
		p.Anchored = false
		p.Massless = true
		p.CanCollide = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = trunk
		w.Part1 = p
		w.Parent = p
		p.Parent = log
	end
	if standin then
		standin:Destroy()
	end
	log:SetAttribute("HasCrown", #parts > 0)
end

-- the standing tree is felled at band cutJ: the stump stays (shorter, with the bark it had), the rest falls
function LogService.fell(tree: Model, cutJ: number, away: Vector3, player: Player?): Model?
	-- (Godot's trophies: your first tree, an ancient giant, the Legendary Tree)
	if player then
		local TrophyService = require(script.Parent.TrophyService) :: any
		if tree:GetAttribute("Legendary") then
			TrophyService.award(player, "legend")
		elseif tree:GetAttribute("Giant") then
			TrophyService.award(player, "giant")
		end
		TrophyService.award(player, "first_tree")
		-- (the golden tree: the whole server hears who got it, and there's a badge for it)
		if tree:GetAttribute("Golden") == true then
			local ok, display = pcall(function()
				return player.DisplayName
			end)
			remotes.Notify:FireAllClients(string.format("%s felled the golden tree!", if ok and display ~= "" then display else player.Name), "ffd27a", "reveal")
			TrophyService.badge(player, "golden")
		end
		-- (trees felled: the phone's Lumberjacks list shows everyone's)
		local DataService = require(script.Parent.DataService) :: any
		local data = DataService.get(player)
		if data then
			data.felled = (data.felled or 0) + 1
			player:SetAttribute("Felled", data.felled)
			;(require(script.Parent.JobsService) :: any).check(player)
		end
	end
	local bands = tree:GetAttribute("Bands") :: number
	cutJ = math.clamp(cutJ, 1, bands - 2)
	local g = TreeService.gridOf(tree)
	local base = tree:GetPivot()
	local log = makeLog(tree, g, cutJ, bands, base * CFrame.new(0, cutJ * T.bandH * M + 0.03 * M, 0), (tree:GetAttribute("J0") :: number? or 0) + cutJ)
	moveCrown(tree, log)
	-- the stump
	local stump = BarkGrid.slice(g, 0, cutJ)
	local H = cutJ * T.bandH * M
	tree:SetAttribute("Bands", cutJ)
	tree:SetAttribute("Height", H)
	tree:SetAttribute("Felled", true)
	TreeService.setGrid(tree, stump)
	local trunk = trunkOf(tree)
	if trunk then
		trunk.Size = Vector3.new(H, trunk.Size.Y, trunk.Size.Z)
		trunk.CFrame = CFrame.new(base.Position + base.UpVector * H / 2) * CFrame.Angles(0, 0, math.rad(90))
	end
	-- over it goes, away from the sawyer (Godot's Log.topple)
	local t = trunkOf(log) :: BasePart
	local dir = away * Vector3.new(1, 0, 1)
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.zAxis
	local L = t.Size.X
	pcall(function()
		t:ApplyImpulseAtPosition(dir * t.AssemblyMass * 0.9 * M, t.Position + base.UpVector * L * 0.45)
	end)
	remotes.Fx:FireAllClients("timber", base.Position + base.UpVector * H)
	-- it lands with a deep thump and a rush of leaves
	task.delay(2.2, function()
		if t.Parent then
			remotes.Fx:FireAllClients("crumble", t.Position, 0.55, 6)
			remotes.Fx:FireAllClients("rustle", t.Position, 0.7, 4)
		end
	end)
	local _ = player
	return log
end

-- saws a log in two at the band nearest `at` (Godot's Log.cut_at); returns the pieces
function LogService.cutAt(log: Model, at: Vector3): { Model }
	local bands = log:GetAttribute("Bands") :: number
	local j = math.floor(log:GetPivot():PointToObjectSpace(at).Y / (T.bandH * M) + 0.5)
	if j < 1 or j > bands - 1 then
		return {}
	end
	return LogService.split(log, { 0, j, bands })
end

-- the buck saw: the whole log into rounds of 7 bands (the last one takes a leftover stub)
function LogService.buck(log: Model): { Model }
	local n = log:GetAttribute("Bands") :: number
	local section = Config.Saw.buckBands
	if n <= section then
		return {}
	end
	local cuts = { 0 }
	local j = 0
	while j < n do
		local j1 = math.min(j + section, n)
		if n - j1 < 3 then
			j1 = n
		end
		table.insert(cuts, j1)
		j = j1
	end
	return LogService.split(log, cuts)
end

-- splits a log at the given bands (cuts = {0, a, b, ..., bands})
function LogService.split(log: Model, cuts: { number }): { Model }
	local g = TreeService.gridOf(log)
	local base = log:GetPivot()
	local trunk = trunkOf(log) :: BasePart
	local v, w = Vector3.zero, Vector3.zero
	pcall(function()
		v, w = trunk.AssemblyLinearVelocity, trunk.AssemblyAngularVelocity
	end)
	local out = {}
	local j0c = log:GetAttribute("J0") :: number? or 0
	for k = 1, #cuts - 1 do
		local a, b = cuts[k], cuts[k + 1]
		local piece = makeLog(log, g, a, b, base * CFrame.new(0, a * T.bandH * M + 0.02 * M * (k - 1), 0), j0c + a)
		local t = trunkOf(piece) :: BasePart
		pcall(function()
			t.AssemblyLinearVelocity = v
			t.AssemblyAngularVelocity = w * 0.5
		end)
		if log:GetAttribute("Locked") then
			-- (a locked log's pieces stay nailed in place)
			piece:SetAttribute("Locked", true)
			t.Anchored = true
		end
		table.insert(out, piece)
	end
	-- the leafy top stays with the top piece
	local top = out[#out]
	for _, p in log:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Trunk" then
			for _, wc in p:GetChildren() do
				if wc:IsA("WeldConstraint") then
					wc.Part0 = trunkOf(top)
				end
			end
			p.Parent = top
			top:SetAttribute("HasCrown", true)
		end
	end
	log:Destroy()
	return out
end

-- the client's saw is through: check it, then fell / cut / buck
-- ------------------------------------------------------------------ the pole saw
local MAX_LEAVES = 400
local leaves: { BasePart } = {}

local function looseFolder(): Instance
	local f = workspace:FindFirstChild("Loose")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Loose"
		f.Parent = workspace
	end
	return f
end

-- a clump of leaves (Godot's Leaf): a squashed little ball in the crown's green, a touch lighter or not
local function leaf(at: Vector3, color: Color3, owner: number?): BasePart
	local size = 0.12 + math.random() * 0.08
	local p = Instance.new("Part")
	p.Name = "Leaves"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * size * 1.6 * M
	p.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6.3, math.random() * 6.3, 0)
	p.Color = color:Lerp(color:Lerp(Color3.new(1, 1, 1), 0.15), math.random())
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.6, 0.1)
	p:SetAttribute("Kind", "leaf")
	p:SetAttribute("Value", Config.Leaf.value)
	if owner then
		p:SetAttribute("Owner", owner)
	end
	p.Parent = looseFolder()
	p.AssemblyLinearVelocity = Vector3.new(math.random() * 2 - 1, math.random() - 0.5, math.random() * 2 - 1) * M
	p.AssemblyAngularVelocity = Vector3.new(math.random() * 6 - 3, math.random() * 6 - 3, math.random() * 6 - 3)
	table.insert(leaves, p)
	while #leaves > MAX_LEAVES do
		local old = table.remove(leaves, 1)
		if old and old.Parent and not old:GetAttribute("HeldBy") then
			old:Destroy()
		end
	end
	return p
end

-- a sapling (Godot's Sapling): a stem, two leafy blobs and a clod of earth, `scale` times the size
function LogService.buildSprout(root: BasePart, species: string, scale: number)
	for _, c in root:GetChildren() do
		if c:IsA("BasePart") then
			c:Destroy()
		end
	end
	local green = Color3.fromHex(if species == "pine" or species == "cedar" then "2f6b3a" else "6aa846")
	local s = scale * M
	local upright = root.CFrame * CFrame.Angles(0, 0, math.rad(-90))     -- (the clod is a cylinder on its side)
	local function piece(name: string, shape: Enum.PartType, size: Vector3, off: Vector3, color: Color3)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.CFrame = upright * CFrame.new(off) * (if shape == Enum.PartType.Cylinder then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.Massless = true
		p.Anchored = root.Anchored
		p.Parent = root
		if not root.Anchored then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
		end
	end
	piece("Stem", Enum.PartType.Cylinder, Vector3.new(0.3 * s, 0.035 * s, 0.035 * s), Vector3.new(0, 0.15 * s, 0), Color3.fromHex("6b4a32"))
	piece("Leaf", Enum.PartType.Ball, Vector3.one * 0.18 * s, Vector3.new(0.04 * s, 0.3 * s, 0), green)
	piece("Leaf", Enum.PartType.Ball, Vector3.one * 0.14 * s, Vector3.new(-0.04 * s, 0.26 * s, 0.03 * s), green)
end

function LogService.sapling(at: Vector3, species: string): BasePart
	-- the clod of earth is the sapling (what you grab); the sprout rides on it
	local root = Instance.new("Part")
	root.Name = "Sapling"
	root.Shape = Enum.PartType.Cylinder
	root.Size = Vector3.new(0.08 * M, 0.14 * M, 0.14 * M)
	root.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	root.Color = Color3.fromHex("5a3d28")
	root.Material = Enum.Material.SmoothPlastic
	root:SetAttribute("Kind", "sapling")
	root:SetAttribute("Species", species)
	root:SetAttribute("Grow", 0)
	LogService.buildSprout(root, species, 1)
	root.Parent = looseFolder()
	return root
end

-- Pole saw: the crown comes off a standing tree (Godot's ForestTree.cut_crown / Foliage.drop_all). Every clump of
-- leaves rains down (2 to 6 a blob), with a sapling or two of the tree's kind.
function LogService.cutCrown(tree: Model, player: Player?): boolean
	if tree:GetAttribute("Log") or tree:GetAttribute("Felled") or tree:GetAttribute("CrownCut") then
		return false
	end
	local parts = LogService.crownParts(tree)
	if #parts == 0 then
		return false
	end
	local owner = if player then player.UserId else nil
	local centre = Vector3.zero
	for _, p in parts do
		centre += p.Position
		-- a clump of leaves for every couple of metres of crown, spread through it
		local n = math.clamp(math.floor(p.Size.Magnitude / M * 1.2), 2, 12)
		for _ = 1, n do
			local off = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * p.Size * 0.8
			leaf(p.CFrame:PointToWorldSpace(off), p.Color, owner)
		end
		remotes.Fx:FireAllClients("rustle", p.Position, 0.7, 2)
		p:Destroy()
	end
	centre /= #parts
	local standin = tree:FindFirstChild("Crown")
	if standin then
		standin:Destroy()
	end
	local base = tree:GetPivot().Position
	for _ = 1, math.random(1, 2) do
		local a = math.random() * 2 * math.pi
		LogService.sapling(Vector3.new(base.X + math.cos(a) * 1.4 * M, centre.Y - 2.5 * M, base.Z + math.sin(a) * 1.4 * M), tree:GetAttribute("Species") :: string or "oak")
	end
	tree:SetAttribute("CrownCut", true)
	remotes.Fx:FireAllClients("timber", centre, 1.4, -4)
	return true
end

-- Shears: one snip tears 2 or 3 clumps of leaves off the bit of crown you hit; it shrinks, and after 4 to 16 snips
-- (more for a bigger crown) it's gone. The very last clump always holds a sapling or two (Godot's Foliage.snip).
local lastSnip: { [Player]: number } = {}
function LogService.snip(player: Player?, tree: Model, at: Vector3): boolean
	if tree:GetAttribute("Log") or tree:GetAttribute("Felled") or tree:GetAttribute("CrownCut") then
		return false
	end
	local best, bestD = nil, math.huge
	for _, p in LogService.crownParts(tree) do
		local d = (p.Position - at).Magnitude - p.Size.Magnitude / 2
		if d < bestD then
			best, bestD = p, d
		end
	end
	if not best or bestD > 1.5 * M then
		return false
	end
	local p = best :: BasePart
	local hp = p:GetAttribute("Snips") :: number?
	if not hp then
		hp = math.clamp(math.floor(p.Size.Magnitude / M * 0.35 * 7), 4, 16)
	end
	local owner = if player then player.UserId else nil
	local head = player and player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	local out = if head then (head.Position - at).Unit else Vector3.yAxis
	for _ = 1, math.random(2, 3) do
		local lf = leaf(at + Vector3.new(math.random() * 0.3 - 0.15, math.random() * 0.2 - 0.1, math.random() * 0.3 - 0.15) * M, p.Color, owner)
		lf.AssemblyLinearVelocity = (out * (0.5 + math.random()) + Vector3.new(math.random() - 0.5, 0.3, math.random() - 0.5)) * M
	end
	remotes.Fx:FireAllClients("rustle", at, 1.1 + math.random() * 0.2, -4)
	hp -= 1
	p:SetAttribute("Snips", hp)
	p.Size *= 0.9
	if hp <= 0 then
		p:Destroy()
		if #LogService.crownParts(tree) == 0 then
			local standin = tree:FindFirstChild("Crown")
			if standin then
				standin:Destroy()
			end
			for _ = 1, math.random(1, 2) do
				LogService.sapling(at + Vector3.new(math.random() * 0.4 - 0.2, 0.1, math.random() * 0.4 - 0.2) * M, tree:GetAttribute("Species") :: string or "oak")
			end
			tree:SetAttribute("CrownCut", true)
			remotes.Fx:FireAllClients("reveal", at, 1.3, -6)
		end
	end
	return true
end

-- Shears on a bush (Godot's Bush.snip): 2 or 3 clumps of leaves in its colour, it shrinks a little each time
-- (0.88), and after 6 snips it's trimmed away
function LogService.snipBush(player: Player?, bush: BasePart, at: Vector3)
	local color = Color3.fromHex(bush:GetAttribute("Color") :: string? or "3f7f33")
	local head = player and player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	local out = if head then (head.CFrame.Position - at).Unit else Vector3.yAxis
	for _ = 1, math.random(2, 3) do
		local lf = leaf(at + Vector3.new(math.random() * 0.2 - 0.1, 0.05, math.random() * 0.2 - 0.1) * M, color, player and player.UserId)
		lf.AssemblyLinearVelocity = (out * (0.6 + math.random() * 0.8) + Vector3.new(0, 0.8, 0)) * M
	end
	remotes.Fx:FireAllClients("rustle", at, 1.1 + math.random() * 0.2, -4)
	local left = (bush:GetAttribute("Snips") :: number? or 6) - 1
	bush:SetAttribute("Snips", left)
	local trim = (bush:GetAttribute("Trim") :: number? or 1) * 0.88
	bush:SetAttribute("Trim", trim)
	local idx = bush:GetAttribute("Bush")
	local world = workspace:FindFirstChild("GodotWorld")
	local centre = bush.CFrame.Position
	for _, p in if world then world:GetChildren() else {} do
		if p:IsA("BasePart") and string.match(p.Name, "^bush_(%d+)_") == tostring(idx) then
			local home = p:GetAttribute("HomeCF") :: CFrame?
			local size = p:GetAttribute("HomeSize") :: Vector3?
			if not home or not size then
				p:SetAttribute("HomeCF", p.CFrame)
				p:SetAttribute("HomeSize", p.Size)
				home, size = p.CFrame, p.Size
			end
			if left <= 0 then
				p:Destroy()
			else
				local rel = (home :: CFrame).Position - centre
				p.Size = (size :: Vector3) * trim
				p.CFrame = CFrame.new(centre + rel * trim) * ((home :: CFrame) - (home :: CFrame).Position)
			end
		end
	end
	if left <= 0 then
		bush:Destroy()
	end
end

local function onSnip(player: Player, target: unknown, at: unknown)
	if typeof(target) == "Instance" and typeof(at) == "Vector3" and (target :: Instance):GetAttribute("Bush") ~= nil then
		local tool = (Config.Tools :: any)[ToolService.current(player)]
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		local now = os.clock()
		if tool and tool.snip and head and (head.CFrame.Position - (at :: Vector3)).Magnitude <= tool.reach * M + 5 and now - (lastSnip[player] or 0) >= tool.cooldown * 0.8 then
			lastSnip[player] = now
			LogService.snipBush(player, target :: BasePart, at :: Vector3)
		end
		return
	end
	if typeof(target) ~= "Instance" or typeof(at) ~= "Vector3" or not (target :: Instance):IsA("Model") or not (target :: Instance):HasTag("Tree") then
		return
	end
	local tool = (Config.Tools :: any)[ToolService.current(player)]
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not tool or not tool.snip or not head or (head.Position - (at :: Vector3)).Magnitude > tool.reach * M + 5 then
		return
	end
	local now = os.clock()
	if now - (lastSnip[player] or 0) < tool.cooldown * 0.8 then
		return
	end
	lastSnip[player] = now
	LogService.snip(player, target :: Model, at :: Vector3)
end

local function sawn(player: Player, target: unknown, at: unknown)
	if typeof(target) ~= "Instance" or typeof(at) ~= "Vector3" then
		return
	end
	local m = (target :: Instance):FindFirstAncestorWhichIsA("Model")
	while m and not m:HasTag("Tree") do
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	local id = ToolService.current(player)
	local tool = (Config.Tools :: any)[id]
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if m and tool and tool.kind == "polesaw" and head and (head.Position - (at :: Vector3)).Magnitude <= tool.reach * M + 5 then
		-- up in the leaves of a standing tree, for Godot's 1.8 s
		local s = started[player]
		local high = m:GetPivot():PointToObjectSpace(at :: Vector3).Y > (m:GetAttribute("Height") :: number) - Config.Saw.crownReach * M
		if s and s.target == m and os.clock() - s.t >= Config.Saw.crownTime * 0.8 and high then
			started[player] = nil
			LogService.cutCrown(m, player)
		end
		return
	end
	if not m or not tool or tool.kind ~= "saw" or not head or (head.Position - (at :: Vector3)).Magnitude > tool.reach * M + 5 then
		return
	end
	-- it has to have taken (nearly) as long as Godot's saw takes
	local s = started[player]
	if not s or s.target ~= m or os.clock() - s.t < LogService.sawTime(m, tool) * 0.8 then
		return
	end
	started[player] = nil
	local away = ((at :: Vector3) - head.Position)
	if m:GetAttribute("Log") then
		if tool.buck then
			LogService.buck(m)
			remotes.Fx:FireAllClients("thud", at, 1.0)
		else
			for _, piece in LogService.cutAt(m, at :: Vector3) do
				if tool.clean then
					piece:SetAttribute("Clean", true)
				end
			end
			remotes.Fx:FireAllClients("thud", at, 1.2)
		end
		return
	end
	if tool.fell == false or (m:GetAttribute("Bands") :: number) < 4 then
		return
	end
	if (m:GetAttribute("Legendary") and not tool.big) or (m:GetAttribute("Giant") and not tool.big and id ~= "chainsaw") then
		return
	end
	local cutJ = math.floor(m:GetPivot():PointToObjectSpace(at :: Vector3).Y / (T.bandH * M))
	local log = LogService.fell(m, cutJ, away, player)
	if log and tool.clean then
		log:SetAttribute("Clean", true)       -- the crosscut's clean cut: worth 20% more
	end
end

function LogService.start()
	remotes.SawStart.OnServerEvent:Connect(function(player, target)
		if typeof(target) ~= "Instance" then
			started[player] = nil
			return
		end
		local m = (target :: Instance):FindFirstAncestorWhichIsA("Model")
		while m and not m:HasTag("Tree") do
			m = m:FindFirstAncestorWhichIsA("Model")
		end
		if m then
			started[player] = { target = m, t = os.clock() }
		end
	end)
	remotes.Sawn.OnServerEvent:Connect(sawn)
	remotes.Snip.OnServerEvent:Connect(onSnip)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		started[p] = nil
		lastSnip[p] = nil
	end)
end

return LogService
