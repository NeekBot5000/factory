--!strict
-- Tools the Godot way: no Roblox backpack. You own tools; the ones you haven't put down are in your tool bar
-- (1-9, the mouse wheel); one is in your hand (the player's "Tool" attribute). Q puts it down as a real object on
-- the ground (it leaves the bar), and E on it picks it up again. Other players see the tool in your hand.
-- Each tool's model is built from its `look` in Config; ReplicatedStorage.ToolModels has one of each for the
-- first-person view, the tool bar icons and the shop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local ToolService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local lastDrop: { [Player]: number } = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function piece(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = true
	p.Parent = m
	return p
end

-- A tool's model: the Handle along its Y axis (held upright, grip at the bottom), the head at the top with its
-- blade facing forward (-Z). The model's pivot is where the hand holds it.
function ToolService.build(id: string): Model?
	-- the Godot game's own model, once it's loaded (WorldMeshes)
	local models = ReplicatedStorage:FindFirstChild("ToolModels")
	local godot = models and models:FindFirstChild(id)
	if godot and godot:GetAttribute("Godot") then
		local c = (godot :: Model):Clone()
		for _, p in c:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.Massless = true
			end
		end
		return c
	end
	local def = (Config.Tools :: any)[id]
	if not def or not def.look then
		return nil
	end
	local look = def.look
	local m = Instance.new("Model")
	m.Name = id
	local handle = piece(m, "Handle", Vector3.new(0.3, look.handle, 0.3), CFrame.new(), rgb(look.handleColor), Enum.Material.Wood)
	local h = look.head
	local headY = look.handle / 2 - h[2] / 2 - 0.1
	local function blade(dir: number)
		local head = piece(m, "Head", Vector3.new(h[1], h[2], h[3]), CFrame.new(0, headY, -dir * (h[3] / 2 + 0.1)), rgb(look.headColor), Enum.Material.Metal)
		piece(m, "Edge", Vector3.new(h[1] + 0.02, h[2] * 1.05, 0.08), head.CFrame * CFrame.new(0, 0, -dir * h[3] / 2), Color3.fromRGB(235, 240, 245), Enum.Material.Metal)
	end
	blade(1)
	if look.double then
		blade(-1)
	end
	if look.band then
		piece(m, "Band", Vector3.new(0.34, 0.25, 0.34), CFrame.new(0, headY - h[2] / 2 - 0.2, 0), rgb(look.band), Enum.Material.SmoothPlastic)
	end
	-- a dark knob at the end of the handle, like the Godot models
	piece(m, "Knob", Vector3.new(0.36, 0.25, 0.36), CFrame.new(0, -look.handle / 2 + 0.12, 0), Color3.fromRGB(90, 62, 40), Enum.Material.Wood)
	m.PrimaryPart = handle
	m.WorldPivot = CFrame.new(0, -look.handle * 0.3, 0)       -- the grip, near the bottom of the handle
	return m
end

local function owned(data: any, id: string): boolean
	return id == "hands" or data.owned[id] == true
end

local function inBar(data: any, id: string): boolean
	return owned(data, id) and not (data.dropped and data.dropped[id])
end

-- the copy of the tool other players see in your hand
local function showInHand(player: Player, id: string)
	local char = player.Character
	if not char then
		return
	end
	local old = char:FindFirstChild("HeldTool")
	if old then
		old:Destroy()
	end
	local hand = (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	if id == "hands" or not hand then
		return
	end
	local m = ToolService.build(id)
	if not m then
		return
	end
	m.Name = "HeldTool"
	local grip = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	m:PivotTo(grip)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.LocalTransparencyModifier = 0
			weld(hand, p)
		end
	end
	m.Parent = char
end

-- Puts a tool in the player's hand (it must be in their tool bar). Returns whether it did.
function ToolService.equip(player: Player, id: string): boolean
	local data = DataService.get(player)
	if not data or not inBar(data, id) then
		return false
	end
	player:SetAttribute("Tool", id)
	showInHand(player, id)
	return true
end

-- The tool now in the player's hand ("hands" when it's empty).
function ToolService.current(player: Player): string
	local id = player:GetAttribute("Tool")
	return if typeof(id) == "string" then id else "hands"
end

-- Gives a tool for good (bought, or taken from the chopping block), straight into the hand.
function ToolService.grant(player: Player, id: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.owned[id] = true
	if data.dropped then
		data.dropped[id] = nil
	end
	DataService.publish(player)
	ToolService.equip(player, id)
end

-- Q: the tool in your hand goes down on the ground in front of you, as a real object anyone can see.
local function drop(player: Player)
	local data = DataService.get(player)
	local id = ToolService.current(player)
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not data or id == "hands" or not head or os.clock() - (lastDrop[player] or 0) < 0.25 then
		return
	end
	lastDrop[player] = os.clock()
	local m = ToolService.build(id)
	if not m then
		return
	end
	m.Name = "Tool_" .. id
	local look = head.CFrame.LookVector * Vector3.new(1, 0, 1)
	local at = head.Position + (if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis) * 2.1 + Vector3.new(0, -0.9, 0)
	m:PivotTo(CFrame.new(at) * CFrame.Angles(math.rad(-90), math.random() * 6.28, 0))
	local handle = m.PrimaryPart :: BasePart
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = true
			p.CanQuery = true
			p.Massless = false
			p.CastShadow = true
			if p ~= handle then
				weld(handle, p)
			end
		end
	end
	m:SetAttribute("Kind", "tool")
	m:SetAttribute("ToolId", id)
	m:SetAttribute("Owner", player.UserId)
	m.Parent = workspace:FindFirstChild("Loose") or workspace
	handle.AssemblyLinearVelocity = look * 4.5
	data.dropped = data.dropped or {}
	data.dropped[id] = true
	DataService.publish(player)
	ToolService.equip(player, "hands")
end

-- E on a dropped tool: it's yours again (only its owner can take it; it was their tool).
function ToolService.pickUp(player: Player, item: Model): boolean
	local id = item:GetAttribute("ToolId")
	local data = DataService.get(player)
	if not data or typeof(id) ~= "string" or item:GetAttribute("Owner") ~= player.UserId then
		return false
	end
	item:Destroy()
	ToolService.grant(player, id)
	return true
end

local function onJoin(player: Player)
	for _ = 1, 120 do
		if DataService.get(player) or not player.Parent then
			break
		end
		task.wait(0.5)
	end
	-- a tool put down last time isn't lying around on this server: it's back in the bar
	local data = DataService.get(player)
	if data then
		data.dropped = {}
		DataService.publish(player)
	end
	player:SetAttribute("Tool", "hands")
	player.CharacterAdded:Connect(function()
		task.wait()
		showInHand(player, ToolService.current(player))
	end)
end

function ToolService.start()
	local models = Instance.new("Folder")
	models.Name = "ToolModels"
	for _, id in Config.ShopOrder do
		local m = ToolService.build(id)
		if m then
			m.Parent = models
		end
	end
	models.Parent = ReplicatedStorage
	remotes.Equip.OnServerEvent:Connect(function(player, id)
		if typeof(id) == "string" then
			ToolService.equip(player, id)
		end
	end)
	remotes.DropTool.OnServerEvent:Connect(drop)
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(function(p)
		lastDrop[p] = nil
		-- their dropped tools go with them (they'll be back in the bar next time)
		local loose = workspace:FindFirstChild("Loose")
		for _, m in if loose then loose:GetChildren() else {} do
			if m:GetAttribute("Kind") == "tool" and m:GetAttribute("Owner") == p.UserId then
				m:Destroy()
			end
		end
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(onJoin, p)
	end
end

return ToolService
