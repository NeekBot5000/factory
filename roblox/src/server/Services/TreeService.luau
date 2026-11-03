--!strict
-- Trees and bark, server-authoritative. Each tree is a Model tagged "Tree" with attributes Species, Sectors, Bands,
-- Radius and Height. Its bark lives in a BarkGrid (a 1.3 KB buffer) on the server only. A client asks to strip at a
-- point; the server checks it (cooldown, distance, tool owned), takes the bark off, spawns the bark sheet as a loose
-- part the player owns physically (so carrying it is smooth), and tells nearby clients which panels went, so each
-- client redraws just that tree.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local BarkGrid = require(ReplicatedStorage.Shared.BarkGrid)
local Economy = require(ReplicatedStorage.Shared.Economy)
local BarkLook = require(ReplicatedStorage.Shared.BarkLook)
local DataService = require(script.Parent.DataService)
local ToolService = require(script.Parent.ToolService)
local TutorialService = require(script.Parent.TutorialService)

local TreeService = {}
local M = Config.StudsPerMetre
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local grids: { [Model]: BarkGrid.Grid } = {}
local lastSwing: { [Player]: number } = {}
local comboOf: { [Player]: { n: number, t: number } } = {}
local spiralOf: { [Player]: any } = {}
local toldGouge: { [Player]: boolean } = {}

local SLACK = 5               -- studs of reach allowed beyond the tool's own (lag, and the head isn't the camera)
local CORK_EVERY = 5

local loose = Instance.new("Folder")
loose.Name = "Loose"
loose.Parent = workspace

local function gridOf(tree: Model): BarkGrid.Grid
	local g = grids[tree]
	if not g then
		g = BarkGrid.new(tree:GetAttribute("Sectors") :: number or 16, tree:GetAttribute("Bands") :: number or 40)
		local saved = tree:GetAttribute("Bark")
		if typeof(saved) == "string" then
			g = BarkGrid.decode(g.sectors, g.bands, saved) or g
		end
		grids[tree] = g
	end
	return g
end

-- which panel a world point is on: the angle round the trunk and the height up it
-- other services (felling, logs) read and replace a tree's bark here
TreeService.gridOf = gridOf
function TreeService.setGrid(tree: Model, g: BarkGrid.Grid)
	grids[tree] = g
	tree:SetAttribute("Bark", BarkGrid.encode(g))
end

local function panelAt(tree: Model, g: BarkGrid.Grid, point: Vector3): (number, number)
	local base = tree:GetPivot()
	local loc = base:PointToObjectSpace(point)
	local angle = math.atan2(loc.Z, loc.X) % (2 * math.pi)
	local i = math.floor(angle / (2 * math.pi) * g.sectors)
	local height = tree:GetAttribute("Height") :: number or 20
	local j = math.clamp(math.floor(loc.Y / height * g.bands), 0, g.bands - 1)
	return i, j
end

-- A sheet of bark comes off (Godot's Chip): exactly the panels the hit took, where they were on the trunk, each in
-- its own shade with the layer beneath showing on the back. It springs off the trunk and tumbles; its worth is in its
-- attributes (set here on the server, so a client can't change it). The first panel is the sheet; the rest ride on it.
local MAX_CHIPS = 600          -- (Godot keeps the newest 600 sheets in the world)
local chips: { BasePart } = {}

local function spawnSheet(player: Player, tree: Model, strip: any, mult: number)
	local species = tree:GetAttribute("Species") :: string or "oak"
	local seed = tree:GetAttribute("Seed") :: number or 1
	local sectors = tree:GetAttribute("Sectors") :: number or 16
	local base = tree:GetPivot()
	local rOut, thick = BarkLook.layerRadius(tree:GetAttribute("Radius") :: number or 1.2, strip.layer)
	local under = BarkLook.underColor(species, strip.layer)
	local root: Part? = nil
	for _, ij in strip.panels do
		local cf, size = BarkLook.panel(base, sectors, ij[1], ij[2], rOut, thick)
		-- the face (its own shade) and, behind it, the layer it came off
		local face = Instance.new("Part")
		face.Size = Vector3.new(size.X, size.Y, size.Z * 0.6)
		face.CFrame = cf * CFrame.new(0, 0, -size.Z * 0.2)
		face.Color = BarkLook.panelColor(species, strip.layer, ij[1], ij[2] + (tree:GetAttribute("J0") :: number? or 0), seed)
		face.Material = Enum.Material.SmoothPlastic
		face.TopSurface = Enum.SurfaceType.Smooth
		face.BottomSurface = Enum.SurfaceType.Smooth
		face.CastShadow = false
		local back = Instance.new("Part")
		back.Size = Vector3.new(size.X, size.Y, size.Z * 0.4)
		back.CFrame = cf * CFrame.new(0, 0, size.Z * 0.3)
		back.Color = under
		back.Material = Enum.Material.SmoothPlastic
		back.CastShadow = false
		back.CanQuery = false
		if root then
			face.Parent = root
		else
			root = face
		end
		back.Parent = root
		for _, p in { face, back } do
			if p ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	local sheet = root :: Part
	sheet:SetAttribute("Value", math.floor(Economy.barkValue(Config, species, strip.layer, #strip.panels) * mult * 100 + 0.5) / 100)
	sheet:SetAttribute("Owner", player.UserId)
	sheet:SetAttribute("Kind", "bark")
	sheet:SetAttribute("Panels", #strip.panels)       -- (what it counts for in a build: Godot's Chip.panels)
	sheet:SetAttribute("Layer", strip.layer)
	sheet:SetAttribute("Species", species)
	sheet.Parent = loose
	-- off it springs: out from the trunk, a little up, tumbling (Godot's Main.spawn_chip, in studs)
	local first = strip.panels[1]
	local a = (first[1] + 0.5) / sectors * 2 * math.pi
	local out = base:VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a)))
	sheet.AssemblyLinearVelocity = out * (0.8 + math.random() * 0.8) * M + Vector3.new(0, (0.6 + math.random() * 0.8) * M, 0)
	sheet.AssemblyAngularVelocity = Vector3.new(math.random() * 10 - 5, math.random() * 10 - 5, math.random() * 10 - 5)
	-- the player who peeled it simulates it, so carrying feels instant (can fail if the player just left)
	pcall(function()
		sheet:SetNetworkOwner(player)
	end)
	table.insert(chips, sheet)
	while #chips > MAX_CHIPS do
		local old = table.remove(chips, 1)
		if old and old.Parent and not old:GetAttribute("HeldBy") then
			old:Destroy()
		end
	end
end

-- the shortest time between two hits, as a share of the swing (the double-bit hits twice per swing)
local function minGap(tool: any): number
	local hits = tool.impacts or { tool.impact }
	local gap = 1 - hits[#hits] + hits[1]
	for k = 2, #hits do
		gap = math.min(gap, hits[k] - hits[k - 1])
	end
	return gap
end

local thunderAt: { [Player]: number } = {}

local function onStrip(player: Player, tree: unknown, point: unknown, toolId: unknown, strike: unknown)
	-- never trust the client: check every argument
	if typeof(tree) ~= "Instance" or not (tree :: Instance):IsA("Model") or not CollectionService:HasTag(tree :: Instance, "Tree") then
		return
	end
	if typeof(point) ~= "Vector3" or typeof(toolId) ~= "string" then
		return
	end
	local data = DataService.get(player)
	local tool = (Config.Tools :: any)[toolId :: string]
	-- it has to be the tool in their hand
	if not data or not tool or ToolService.current(player) ~= toolId then
		return
	end
	local now = os.clock()
	if now - (lastSwing[player] or 0) < tool.cooldown * minGap(tool) * 0.8 then
		return
	end
	lastSwing[player] = now
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not head or not hum or hum.Health <= 0 or (head.Position - (point :: Vector3)).Magnitude > tool.reach * Config.StudsPerMetre + SLACK then
		return
	end
	local t = tree :: Model
	local g = gridOf(t)
	local species = Config.Species[t:GetAttribute("Species") :: string or "oak"] or Config.Species.oak
	local strips = {}
	local now2 = os.clock()
	-- the combo axe: each hit in quick succession grows the next (Godot: +0.05 m a hit, up to 4, gone after 1.25 s)
	local combo = comboOf[player]
	if not combo or now2 - combo.t > 1.25 then
		combo = { n = 0, t = now2 }
		comboOf[player] = combo
	end
	local r = tool.stripRadius
	if tool.combo then
		r += 0.05 * combo.n
	end
	if toolId == "hands" and species.handsSafe then
		r = 0.17          -- shagbark: the strips come away in your hands
	end
	local only = if tool.only == "outer" then BarkGrid.OUTER elseif tool.only == "inner" then BarkGrid.INNER else nil
	local R = (t:GetAttribute("Radius") :: number or 1.2) / M
	local function hitAt(at: Vector3): (number, number, any)
		local i, j = panelAt(t, g, at)
		local loc = t:GetPivot():PointToObjectSpace(at) / M
		return i, j, { x = loc.X, y = loc.Y, z = loc.Z }
	end
	local function add(res: any)
		if res then
			table.insert(strips, res)
		end
	end
	local function circle(at: Vector3)
		local i, j, loc = hitAt(at)
		add(BarkGrid.stripCircleAt(g, i, j, loc, r, R, R - Config.Tree.outerT, Config.Tree.bandH, only))
	end
	if strike == true and tool.charge then
		-- the Thunder Axe, fully charged: lightning takes every sheet off the whole tree (then it rests 6 s)
		if now2 - (thunderAt[player] or -math.huge) < tool.rest * 0.9 then
			return
		end
		thunderAt[player] = now2
		for _, res in BarkGrid.stripAll(g, 4) do
			add(res)
		end
		remotes.Fx:FireAllClients("lightning", point)
	elseif tool.ring then
		local i, j = hitAt(point :: Vector3)
		add(BarkGrid.stripRing(g, i, j))
	elseif tool.through then
		local i, j, loc = hitAt(point :: Vector3)
		for _, res in BarkGrid.stripThrough(g, i, j, loc, r, R, Config.Tree.bandH, tool.grid) do
			add(res)
		end
	elseif tool.spiral then
		-- the stripe carries on from where the last hit on this trunk ended (Godot's _spiral_hit)
		local i, j = hitAt(point :: Vector3)
		local sp = spiralOf[player]
		if sp and sp.tree == t and now2 - sp.t < 1.6 and sp.j < g.bands then
			i, j = sp.i, sp.j
			sp.n += 1
		else
			sp = { tree = t, n = 0, i = i, j = j, t = now2 }
			spiralOf[player] = sp
		end
		local width = 1 + math.min(sp.n // 3, 2)
		local list = {}
		for k = 0, 3 do
			for w = 0, width - 1 do
				table.insert(list, { i + k, j + k - w })
			end
		end
		sp.t = now2
		sp.i, sp.j = (i + 4) % g.sectors, j + 4
		for _, res in BarkGrid.stripPanels(g, list) do
			add(res)
		end
	elseif tool.kind == "washer" then
		-- the jet eats a soft round patch: the 3 panels nearest where it lands (Godot's strip_soft)
		local i, j, loc = hitAt(point :: Vector3)
		for _, res in BarkGrid.stripSoft(g, i, j, loc, r, R, Config.Tree.bandH, 3) do
			add(res)
		end
	elseif tool.kind == "planer" then
		-- logs lying down only: a strip the whole length of the log, in one long sheet (Godot's strip_column)
		if not t:GetAttribute("Log") then
			return
		end
		local i, j = hitAt(point :: Vector3)
		add(BarkGrid.stripColumn(g, i, j))
	elseif tool.bits == 2 then
		-- the twin auger: two bits side by side, 0.17 m either side of the aim (Godot's camera right)
		local look = ((point :: Vector3) - head.Position) * Vector3.new(1, 0, 1)
		local side = if look.Magnitude > 0.01 then look.Unit:Cross(Vector3.yAxis) * 0.17 * M else Vector3.new(0.17 * M, 0, 0)
		circle((point :: Vector3) - side)
		circle((point :: Vector3) + side)
	else
		circle(point :: Vector3)
		if species.tallStrips then
			-- cedar bark is stringy: a hit pulls a long strip, above and below
			circle((point :: Vector3) + Vector3.new(0, r * 1.3 * M, 0))
			circle((point :: Vector3) - Vector3.new(0, r * 1.3 * M, 0))
		end
	end
	if tool.combo then
		-- any hit on the trunk keeps the rhythm going
		combo.n = math.min(combo.n + 1, Config.ComboMax)
		combo.t = now2
	end
	if #strips == 0 and tool.only == "inner" and not toldGouge[player] then
		toldGouge[player] = true
		remotes.Notify:FireClient(player, "The gouge only cuts inner bark - take the outer bark off first", "ffd27a")
	end
	if #strips > 0 then
		-- the bark state first (clients redraw when it changes), then the effects event
		t:SetAttribute("Bark", BarkGrid.encode(g))
	end
	for _, s in strips do
		spawnSheet(player, t, s, tool.value or 1)
		remotes.TreeChanged:FireAllClients(t, s.layer, s.panels)
	end
	if #strips > 0 then
		data.peeled = (data.peeled or 0) + #strips
		TutorialService.check(player)
	end
	-- bare hands on rough bark hurt, every hit (Godot: everything but the shagbark hickory). At 0 you faint.
	if tool.hurt > 0 and not species.handsSafe then
		hum:TakeDamage(tool.hurt)
	end
end

function TreeService.start()
	remotes.StripRequest.OnServerEvent:Connect(onStrip)
	Players.PlayerRemoving:Connect(function(p)
		lastSwing[p] = nil
		comboOf[p] = nil
		spiralOf[p] = nil
		toldGouge[p] = nil
		thunderAt[p] = nil
		-- their bark goes with them
		for _, s in loose:GetChildren() do
			if s:GetAttribute("Kind") == "bark" and s:GetAttribute("Owner") == p.UserId then
				s:Destroy()
			end
		end
	end)
	-- cork grows back, slowly, on a low-rate loop (never per frame)
	task.spawn(function()
		while true do
			task.wait(CORK_EVERY)
			for tree, g in grids do
				if tree.Parent and tree:GetAttribute("Species") == "cork" and BarkGrid.regrow(g, 6) > 0 then
					tree:SetAttribute("Bark", BarkGrid.encode(g))
					remotes.TreeChanged:FireAllClients(tree, -1, {})     -- -1: redraw from the Bark attribute
				end
			end
		end
	end)
end

return TreeService
