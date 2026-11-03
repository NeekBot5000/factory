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
local DataService = require(script.Parent.DataService)
local QuestService = require(script.Parent.QuestService)

local TreeService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local grids: { [Model]: BarkGrid.Grid } = {}
local lastSwing: { [Player]: number } = {}
local warned: { [Player]: boolean } = {}   -- told once that bare hands hurt
local HURT_FLOOR = 30          -- bare-handed peeling never takes you below this much health
local sheetsOf: { [Player]: { BasePart } } = {}

local MAX_REACH = 14          -- studs from the player's head to the hit point
local MAX_SHEETS = 120        -- loose bark sheets per player; the oldest are tidied away past this
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
local function panelAt(tree: Model, g: BarkGrid.Grid, point: Vector3): (number, number)
	local base = tree:GetPivot()
	local loc = base:PointToObjectSpace(point)
	local angle = math.atan2(loc.Z, loc.X) % (2 * math.pi)
	local i = math.floor(angle / (2 * math.pi) * g.sectors)
	local height = tree:GetAttribute("Height") :: number or 20
	local j = math.clamp(math.floor(loc.Y / height * g.bands), 0, g.bands - 1)
	return i, j
end

local function spawnSheet(player: Player, tree: Model, layer: number, n: number, at: Vector3)
	local species = tree:GetAttribute("Species") :: string or "oak"
	local sheet = Instance.new("Part")
	sheet.Size = Vector3.new(math.min(4, 0.6 + n * 0.25), 0.15, math.min(4, 0.6 + n * 0.2))
	sheet.Color = if layer == BarkGrid.OUTER then Color3.fromRGB(91, 64, 48) else Color3.fromRGB(181, 101, 58)
	sheet.Material = Enum.Material.Wood
	sheet.CFrame = CFrame.new(at)
	sheet.CastShadow = false          -- dozens of thin sheets: shadows cost more than they show
	sheet:SetAttribute("Value", Economy.barkValue(Config, species, layer, n))
	sheet:SetAttribute("Owner", player.UserId)
	sheet:SetAttribute("Kind", "bark")
	sheet.Parent = loose
	-- the player who peeled it simulates it, so carrying feels instant (can fail if the player just left)
	pcall(function()
		sheet:SetNetworkOwner(player)
	end)
	local list = sheetsOf[player] or {}
	sheetsOf[player] = list
	table.insert(list, sheet)
	while #list > MAX_SHEETS do
		local old = table.remove(list, 1)
		if old and old.Parent then
			old:Destroy()
		end
	end
end

local function onStrip(player: Player, tree: unknown, point: unknown, toolId: unknown)
	-- never trust the client: check every argument
	if typeof(tree) ~= "Instance" or not (tree :: Instance):IsA("Model") or not CollectionService:HasTag(tree :: Instance, "Tree") then
		return
	end
	if typeof(point) ~= "Vector3" or typeof(toolId) ~= "string" then
		return
	end
	local data = DataService.get(player)
	local tool = Config.Tools[toolId :: string]
	if not data or not tool or not data.owned[toolId] then
		return
	end
	local now = os.clock()
	if now - (lastSwing[player] or 0) < tool.cooldown * 0.8 then
		return
	end
	lastSwing[player] = now
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not head or (head.Position - (point :: Vector3)).Magnitude > MAX_REACH then
		return
	end
	local t = tree :: Model
	local g = gridOf(t)
	local i, j = panelAt(t, g, point :: Vector3)
	local species = Config.Species[t:GetAttribute("Species") :: string or "oak"] or Config.Species.oak
	local radius = tool.radius
	if toolId == "hands" and species.handsSafe then
		radius = 1
	end
	local strips = {}
	local r = BarkGrid.stripCircle(g, i, j, radius, tool.only)
	if r then
		table.insert(strips, r)
	end
	if species.tallStrips then
		for _, dj in { -radius - 1, radius + 1 } do
			local extra = BarkGrid.stripCircle(g, i, j + dj, radius, tool.only)
			if extra then
				table.insert(strips, extra)
			end
		end
	end
	if #strips > 0 then
		-- the bark state first (clients redraw when it changes), then the effects event
		t:SetAttribute("Bark", BarkGrid.encode(g))
	end
	for _, s in strips do
		spawnSheet(player, t, s.layer, #s.panels, point :: Vector3)
		remotes.TreeChanged:FireAllClients(t, s.layer, s.panels)
	end
	if #strips > 0 then
		QuestService.progress(player, "peel", #strips)
	end
	if tool.hurt > 0 and not species.handsSafe then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		-- it stings, but never knocks a new player out (health regrows, and the floor keeps the first minute fun)
		if hum and hum.Health > HURT_FLOOR then
			hum:TakeDamage(math.min(tool.hurt, hum.Health - HURT_FLOOR))
			if not warned[player] then
				warned[player] = true
				remotes.Notify:FireClient(player, "Ouch! Rough bark hurts bare hands. Grey hickory is smooth, or buy a hatchet.")
			end
		end
	end
end

function TreeService.start()
	remotes.StripRequest.OnServerEvent:Connect(onStrip)
	Players.PlayerRemoving:Connect(function(p)
		lastSwing[p] = nil
		warned[p] = nil
		for _, s in sheetsOf[p] or {} do
			if s.Parent then
				s:Destroy()
			end
		end
		sheetsOf[p] = nil
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
