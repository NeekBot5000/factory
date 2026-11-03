--!strict
-- E, the Godot way (Player.gd interact / look_target_text): with something in your hands, E drops it. Otherwise E
-- uses what you're looking at within reach: a tool you put down ("[E] take"), the hatchet in the chopping block,
-- the truck when there's bark in the back ("[E] ship  $12.40"), the cabin computer that runs TimberMart ("[E] use"), or picks up
-- loose bark ("[E] grab"). The HUD shows the same hint text under the crosshair. A held thing floats in front of
-- you where Godot holds it, and the truck shows what its load is worth (its sign) and runs its engine on the road.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local BarkGrid = require(ReplicatedStorage.Shared.BarkGrid)
local InputController = require(script.Parent.InputController)
local ShopController = require(script.Parent.ShopController)
local State = require(script.Parent.Parent.State)
local Sfx = require(script.Parent.Parent.Sfx)

local InteractController = {}
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local REACH = Config.Player.grabReach * M
local HOLD = Vector3.new(0, -0.28, -0.9) * M          -- Godot's HOLD_OFFSET

local function held(): BasePart?
	local loose = workspace:FindFirstChild("Loose")
	if loose then
		for _, p in loose:GetChildren() do
			if p:IsA("BasePart") and p:GetAttribute("HeldBy") == player.UserId then
				return p
			end
		end
	end
	-- (or a log)
	local logs = workspace:FindFirstChild("Logs")
	for _, m in if logs then logs:GetChildren() else {} do
		local t = m:FindFirstChild("Trunk")
		if t and t:GetAttribute("HeldBy") == player.UserId then
			return t :: BasePart
		end
	end
	return nil
end

-- what a log would fetch at the mill (Godot's Log.value), from the bark still on it
function InteractController.logValue(log: Instance): number
	local bands = log:GetAttribute("Bands") :: number or 1
	local s = log:GetAttribute("Bark")
	local g = if typeof(s) == "string" then BarkGrid.decode(log:GetAttribute("Sectors") :: number or 16, bands, s) else nil
	if not g then
		return 0
	end
	return BarkGrid.logValue(g, bands * Config.Tree.bandH, (log:GetAttribute("Radius") :: number or 1.2) / M)
end
InteractController.held = held

local function owns(id: string): boolean
	local s = player:GetAttribute("Owned")
	return typeof(s) == "string" and table.find(string.split(s, ","), id) ~= nil
end

local function look(): RaycastResult?
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	local ignore: { Instance } = { cam }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local h = held()
	if h then
		table.insert(ignore, h)
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	return workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * REACH, params)
end

local function truck(): Model?
	return workspace:FindFirstChild("Truck") :: Model?
end

-- what the truck's load is worth (everyone's bark in its bed), while it's parked
function InteractController.truckValue(): number
	local t = truck()
	local bed = t and t:FindFirstChild("Bed") :: BasePart?
	local loose = workspace:FindFirstChild("Loose")
	if not t or not bed or not loose or t:GetAttribute("State") ~= "parked" then
		return 0
	end
	local v = 0
	for _, p in loose:GetChildren() do
		local value = p:GetAttribute("Value")
		if p:IsA("BasePart") and typeof(value) == "number" then
			local lp = bed.CFrame:PointToObjectSpace(p.Position)
			if math.abs(lp.X) <= bed.Size.X / 2 and math.abs(lp.Z) <= bed.Size.Z / 2 and lp.Y > -1 and lp.Y < 5.5 then
				v += value
			end
		end
	end
	return v
end

-- the tool lying on the ground that this part belongs to, if it's yours
local function toolItem(part: Instance): Model?
	local m = part:FindFirstAncestorWhichIsA("Model")
	while m do
		if m:GetAttribute("Kind") == "tool" then
			return if m:GetAttribute("Owner") == player.UserId then m else nil
		end
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

-- What E would do here: (hint text, action). Godot's look_target_text and interact, in one place.
function InteractController.target(): (string, (() -> ())?)
	if State.uiOpen or State.fainted then
		return "", nil
	end
	local h = held()
	if h then
		return "[E] drop", function()
			remotes.Grab:FireServer(nil)
			Sfx.play("drop", 0.9, -6)
		end
	end
	local hit = look()
	if not hit then
		return "", nil
	end
	local part = hit.Instance
	local item = toolItem(part)
	if item then
		return "[E] take", function()
			remotes.Use:FireServer(part)
		end
	end
	-- a TimberMart box: click to open it, or carry it
	if part:GetAttribute("Kind") == "box" and part:GetAttribute("Owner") == player.UserId and not part:GetAttribute("Opened") then
		return "[Click] open    [E] grab", function()
			remotes.Grab:FireServer(part)
			Sfx.play("pickup")
		end
	end
	-- the tool rising out of an opened box
	local pickup = part:FindFirstAncestorWhichIsA("Model")
	while pickup and pickup:GetAttribute("Kind") ~= "pickup" do
		pickup = pickup:FindFirstAncestorWhichIsA("Model")
	end
	if pickup and pickup:GetAttribute("Owner") == player.UserId then
		return "[E] take", function()
			remotes.Use:FireServer(part)
		end
	end
	local t = truck()
	if t and part:IsDescendantOf(t) then
		local v = InteractController.truckValue()
		if v > 0 then
			return string.format("[E] ship  $%.2f", v), function()
				remotes.Use:FireServer(part)
			end
		end
		return "", nil
	end
	local block = part:FindFirstAncestor("ChoppingBlock")
	if block then
		if not owns("hatchet") then
			return "[E] take", function()
				remotes.Use:FireServer(part)
			end
		end
		return "", nil
	end
	if part.Name == "Computer" and part.Parent and part.Parent.Name == "TimberMart" then
		return "[E] use", ShopController.open
	end
	local loose = workspace:FindFirstChild("Loose")
	-- (a sheet of several panels: the panels ride on the first one, which is the sheet)
	local sheet = part
	if loose and part.Parent and part.Parent:IsA("BasePart") and part.Parent.Parent == loose then
		sheet = part.Parent :: BasePart
	end
	if loose and sheet.Parent == loose and sheet:IsA("BasePart") and not sheet.Anchored and not sheet:GetAttribute("HeldBy") then
		local value = sheet:GetAttribute("Value")
		return if typeof(value) == "number" then string.format("[E] grab    $%.2f", value) else "[E] grab", function()
			remotes.Grab:FireServer(sheet)
			Sfx.play("pickup")
		end
	end
	-- a log: grab it if it's short enough, and what it's worth (Godot's Log.hint_text)
	local log = part:FindFirstAncestorWhichIsA("Model")
	if log and log:GetAttribute("Kind") == "log" then
		local worth = string.format("worth $%.2f", InteractController.logValue(log))
		local liftable = not log:GetAttribute("HasCrown") and (log:GetAttribute("Bands") :: number) * Config.Tree.bandH <= Config.Saw.carryMax
		local trunk = log:FindFirstChild("Trunk")
		if liftable and trunk and not trunk:GetAttribute("HeldBy") then
			return "[E] grab    " .. worth, function()
				remotes.Grab:FireServer(trunk)
				Sfx.play("pickup")
			end
		end
		return "Too heavy to lift - cut it up    " .. worth, nil
	end
	-- a tree says what's special about it (Godot's ForestTree.hint_text)
	local tree = part:FindFirstAncestorWhichIsA("Model")
	if tree and tree:HasTag("Tree") then
		return InteractController.treeHint(tree), nil
	end
	return "", nil
end

local TREE_HINTS = {
	hickory = "Shagbark Hickory  ·  its shaggy bark pulls off by hand",
	cedar = "Western Red Cedar  ·  long, valuable strips",
	cork = "Cork Oak  ·  the cork grows back",
	eucalyptus = "Rainbow Eucalyptus  ·  its inner bark changes colour once it's showing",
}

function InteractController.treeHint(tree: Instance): string
	if tree:GetAttribute("Legendary") then
		return "The Legendary Tree  ·  only a two-man crosscut gets through it"
	elseif tree:GetAttribute("Giant") then
		return "Ancient tree  ·  too thick for most saws"
	end
	return TREE_HINTS[tree:GetAttribute("Species") :: string] or ""
end

-- the truck's sign: what its load is worth, over the bed (the one floating number the Godot game has)
local function truckSign(): BillboardGui?
	local t = truck()
	local bed = t and t:FindFirstChild("Bed") :: BasePart?
	if not bed then
		return nil
	end
	local sign = bed:FindFirstChild("ValueSign") :: BillboardGui?
	if not sign then
		local b = Instance.new("BillboardGui")
		b.Name = "ValueSign"
		b.Size = UDim2.fromOffset(160, 44)
		b.StudsOffset = Vector3.new(0, 6, 0)
		b.AlwaysOnTop = false
		b.LightInfluence = 0
		b.MaxDistance = 80
		local l = Instance.new("TextLabel")
		l.Name = "Text"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
		l.TextScaled = true
		l.TextColor3 = Color3.fromHex("7aff9a")
		l.TextStrokeTransparency = 0.3
		l.Parent = b
		b.Parent = bed
		sign = b
	end
	return sign
end

function InteractController.start()
	InputController.on("Grab", function(state)
		if state ~= Enum.UserInputState.Begin then
			return
		end
		if State.uiOpen then
			ShopController.close()
			return
		end
		local _, action = InteractController.target()
		if action then
			action()
		end
	end)
	local engines: { [string]: Sound? } = {}
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		-- carry the held thing in front of you
		local p = held()
		local cam = workspace.CurrentCamera
		if p and cam then
			local align = p:FindFirstChildOfClass("AlignPosition")
			if align then
				align.Position = (cam.CFrame * CFrame.new(HOLD)).Position
			end
		end
		-- the hatchet in the chopping block is only there until you take it
		local block = workspace:FindFirstChild("ChoppingBlock")
		local hatchet = block and block:FindFirstChild("Hatchet")
		if hatchet then
			local gone = owns("hatchet")
			for _, d in hatchet:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = if gone then 1 else 0
				end
			end
		end
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local t = truck()
		if not t then
			return
		end
		local sign = truckSign()
		local v = InteractController.truckValue()
		if sign then
			sign.Enabled = v > 0
			(sign:FindFirstChild("Text") :: TextLabel).Text = string.format("$%.2f", v)
		end
		-- the diesel engines run while the truck or the van is on the road
		for _, name in { "Truck", "Van" } do
			local veh = workspace:FindFirstChild(name) :: Model?
			local st = veh and veh:GetAttribute("State")
			local moving = st == "leaving" or st == "returning" or st == "arriving" or st == "docking"
			local snd = engines[name]
			if veh and moving and not snd then
				snd = Sfx.loop("engine", -6, veh:FindFirstChild("Cab") or veh:FindFirstChildWhichIsA("BasePart"))
				if snd then
					snd.RollOffMaxDistance = 45 * M
					snd.RollOffMinDistance = 4 * M
				end
				engines[name] = snd
			elseif not moving and snd then
				snd:Destroy()
				engines[name] = nil
			end
		end
	end)
	-- the server's sounds for things only it knows about (the horn as the truck leaves, a tutorial step done)
	remotes.Fx.OnClientEvent:Connect(function(name: string, at: Vector3?, pitch: number?, db: number?)
		if at then
			Sfx.playAt(name, at, pitch, db)
		else
			Sfx.play(name, pitch, db)
		end
	end)
end

return InteractController
