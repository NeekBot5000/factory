--!strict
-- Tools as real Roblox Tools: they sit in the standard hotbar (1-9, or tap on mobile) and are kept when you respawn.
-- Each tool's model is built from its `look` in Config (a handle, a head, maybe a second blade and a coloured band).
-- A copy of every model also goes in ReplicatedStorage.ToolModels for the shop's 3D previews.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local ToolService = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

-- the tool: a Handle along its Y axis (held upright), the head near the top, its blade facing forward (-Z)
function ToolService.build(id: string): Tool?
	local def = (Config.Tools :: any)[id]
	if not def or not def.look then
		return nil
	end
	local look = def.look
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool:SetAttribute("ToolId", id)
	tool.ToolTip = def.tag or ""
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, look.handle, 0.3)
	handle.Color = rgb(look.handleColor)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local h = look.head
	local headY = look.handle / 2 - h[2] / 2 - 0.1
	local function blade(dir: number)
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(h[1], h[2], h[3])
		head.Color = rgb(look.headColor)
		head.Material = Enum.Material.Metal
		head.CanCollide = false
		head.Massless = true
		head.CFrame = handle.CFrame * CFrame.new(0, headY, -dir * (h[3] / 2 + 0.1))
		head.Parent = tool
		weld(handle, head)
		-- a bright edge
		local edge = Instance.new("Part")
		edge.Size = Vector3.new(h[1] + 0.02, h[2] * 1.05, 0.08)
		edge.Color = Color3.fromRGB(235, 240, 245)
		edge.Material = Enum.Material.Metal
		edge.CanCollide = false
		edge.Massless = true
		edge.CFrame = head.CFrame * CFrame.new(0, 0, -dir * h[3] / 2)
		edge.Parent = tool
		weld(handle, edge)
	end
	blade(1)
	if look.double then
		blade(-1)
	end
	if look.band then
		local band = Instance.new("Part")
		band.Size = Vector3.new(0.34, 0.25, 0.34)
		band.Color = rgb(look.band)
		band.Material = Enum.Material.SmoothPlastic
		band.CanCollide = false
		band.Massless = true
		band.CFrame = handle.CFrame * CFrame.new(0, headY - h[2] / 2 - 0.2, 0)
		band.Parent = tool
		weld(handle, band)
	end
	tool.Grip = CFrame.new(0, -look.handle * 0.3, 0)     -- held near the bottom of the handle
	return tool
end

function ToolService.give(player: Player, id: string)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local gear = player:FindFirstChild("StarterGear")
	for _, container in { backpack, gear } do
		if container then
			local have = false
			for _, t in container:GetChildren() do
				if t:GetAttribute("ToolId") == id then
					have = true
				end
			end
			local tool = if have then nil else ToolService.build(id)
			if tool then
				tool.Parent = container
			end
		end
	end
end

local function onJoin(player: Player)
	-- wait for the save, then hand over everything they own
	local data = DataService.get(player)
	local tries = 0
	while not data and player.Parent and tries < 120 do
		task.wait(0.5)
		tries += 1
		data = DataService.get(player)
	end
	if not data then
		return
	end
	if not player:FindFirstChildOfClass("Backpack") then
		player.ChildAdded:Wait()
	end
	for _, id in Config.ShopOrder do
		if data.owned[id] then
			ToolService.give(player, id)
		end
	end
end

function ToolService.start()
	local models = Instance.new("Folder")
	models.Name = "ToolModels"
	for _, id in Config.ShopOrder do
		local t = ToolService.build(id)
		if t then
			local m = Instance.new("Model")
			m.Name = id
			for _, c in t:GetChildren() do
				if c:IsA("BasePart") then
					c.Anchored = true
					c.Parent = m
				end
			end
			t:Destroy()
			m.Parent = models
		end
	end
	models.Parent = ReplicatedStorage
	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do
		task.spawn(onJoin, p)
	end
end

return ToolService
