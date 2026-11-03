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
	for _, k in { "Species", "Sectors", "Radius", "Seed", "Clean" } do
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

-- the crown of a standing tree (the Godot mesh, or the stand-in parts) goes with the log
local function moveCrown(tree: Model, log: Model)
	local trunk = trunkOf(log) :: BasePart
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
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		started[p] = nil
	end)
end

return LogService
