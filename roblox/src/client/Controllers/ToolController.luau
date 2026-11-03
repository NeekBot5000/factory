--!strict
-- Swinging and the tool bar, the Godot way (Player.gd).
--   * The tool bar is every tool you own that you haven't put down. 1-9 (Shift for the next nine) or the mouse wheel
--     pick one; Q puts the one in your hand down on the ground.
--   * A click starts a swing. The blade lands partway through it (the tool's `impact`; the double-bit lands twice),
--     and only then does it look what's under the crosshair: bark comes off (chop / axe sound, higher for the inner
--     layer), bare wood just knocks (chop_wood, wood chips), the ground thuds and throws dirt, and a bare-handed
--     miss is a whoosh. Heavier tools kick the view harder. The server decides what actually comes off.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local BarkGrid = require(ReplicatedStorage.Shared.BarkGrid)
local InputController = require(script.Parent.InputController)
local State = require(script.Parent.Parent.State)
local Sfx = require(script.Parent.Parent.Sfx)

local ToolController = {}
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local crownHome: { [Model]: CFrame } = {}
local impacts = 0

local function def(): any
	return (Config.Tools :: any)[State.tool] or Config.Tools.hands
end

local function split(s: any): { [string]: boolean }
	local out = {}
	if typeof(s) == "string" then
		for id in string.gmatch(s, "[^,]+") do
			out[id] = true
		end
	end
	return out
end

-- the tool bar: what you own and haven't put down, in Godot's order
function ToolController.bar(): { string }
	local owned, dropped = split(player:GetAttribute("Owned")), split(player:GetAttribute("Dropped"))
	local out = {}
	for _, id in Config.ToolOrder do
		if (id == "hands" or owned[id]) and not dropped[id] then
			table.insert(out, id)
		end
	end
	return out
end

function ToolController.equip(id: string)
	if id == State.tool or not table.find(ToolController.bar(), id) then
		return
	end
	State.tool = id
	State.swing = -1
	State.equipT = 0
	Sfx.play("equip")
	remotes.Equip:FireServer(id)
	State.toolsChanged()
end

local function cycle(step: number)
	local bar = ToolController.bar()
	local i = table.find(bar, State.tool) or 1
	ToolController.equip(bar[(i - 1 + step) % #bar + 1])
end

local function treeOf(inst: Instance?): Model?
	while inst and inst ~= workspace do
		if inst:IsA("Model") and CollectionService:HasTag(inst, "Tree") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

-- what's under the crosshair within `reach` studs (loose bark and your own body don't stop a swing)
function ToolController.aim(reach: number): RaycastResult?
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local loose = workspace:FindFirstChild("Loose")
	if loose then
		table.insert(ignore, loose)
	end
	table.insert(ignore, cam)
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	return workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * reach, params)
end

-- the bark circle right now (the combo axe's grows with each hit in a row: Godot's strip_radius)
function ToolController.stripRadius(): number
	local d = def()
	local r = d.stripRadius
	if d.combo then
		r += 0.05 * State.combo
	end
	return r
end

function ToolController.aimingAtTree(): (boolean, number)
	local d = def()
	local hit = ToolController.aim(math.min(d.reach, 3) * M)
	if hit and treeOf(hit.Instance) then
		return true, (hit.Position - workspace.CurrentCamera.CFrame.Position).Magnitude
	end
	return false, d.reach * M
end

local function burst(at: Vector3, normal: Vector3, color: Color3, amount: number, speed: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.lookAt(at, at + normal)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.25))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.06) })
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, -9.8 * M, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-300, 300)
	e.EmissionDirection = Enum.NormalId.Front
	e.Rate = 0
	e.Parent = p
	e:Emit(amount)
	task.delay(1, function()
		p:Destroy()
	end)
end

-- the crown wobbles when you hit the trunk (Godot's shake_crown)
local function shake(tree: Model, strength: number)
	local crown = tree:FindFirstChild("Crown") :: Model?
	if not crown then
		return
	end
	local home = crownHome[crown] or crown:GetPivot()
	crownHome[crown] = home
	local v = Instance.new("CFrameValue")
	v.Value = home * CFrame.Angles(math.rad(3 * strength), 0, math.rad(2 * strength))
	v.Changed:Connect(function(cf)
		if crown.Parent then
			crown:PivotTo(cf)
		end
	end)
	crown:PivotTo(v.Value)
	local t = TweenService:Create(v, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Value = home })
	t:Play()
	t.Completed:Once(function()
		v:Destroy()
	end)
end

-- which layer the hit would take, read from the bark this client has (the server has the final say)
local function predictLayer(tree: Model, at: Vector3, d: any): number?
	local sectors = tree:GetAttribute("Sectors") :: number or 16
	local bands = tree:GetAttribute("Bands") :: number or 40
	local saved = tree:GetAttribute("Bark")
	local g = if typeof(saved) == "string" then BarkGrid.decode(sectors, bands, saved) else BarkGrid.new(sectors, bands)
	if not g then
		return nil
	end
	local loc = tree:GetPivot():PointToObjectSpace(at)
	local i = math.floor((math.atan2(loc.Z, loc.X) % (2 * math.pi)) / (2 * math.pi) * sectors)
	local j = math.clamp(math.floor(loc.Y / (tree:GetAttribute("Height") :: number or 20) * bands), 0, bands - 1)
	local species = (Config.Species :: any)[tree:GetAttribute("Species") or "oak"] or Config.Species.oak
	if d.ring or d.through or d.spiral then
		-- (these take bark wherever there's some near the hit: the outermost layer there)
		local i2, j2 = i, j
		return if BarkGrid.has(g, BarkGrid.OUTER, i2, j2) then BarkGrid.OUTER elseif BarkGrid.has(g, BarkGrid.INNER, i2, j2) then BarkGrid.INNER else nil
	end
	local r = if State.tool == "hands" and species.handsSafe then 0.17 else ToolController.stripRadius()
	local only = if d.only == "outer" then BarkGrid.OUTER elseif d.only == "inner" then BarkGrid.INNER else nil
	local R = (tree:GetAttribute("Radius") :: number or 1.2) / M
	local lm = loc / M
	local s = BarkGrid.stripCircleAt(g, i, j, { x = lm.X, y = lm.Y, z = lm.Z }, r, R, R - Config.Tree.outerT, Config.Tree.bandH, only)
	return if s then s.layer else nil
end

-- the blade lands (Godot's _do_impact)
local function impact()
	local d = def()
	local hit = ToolController.aim(d.reach * M)
	if not hit then
		if State.tool == "hands" then
			Sfx.play("whoosh", 1.2, -6)
		end
		return
	end
	local tree = treeOf(hit.Instance)
	if tree then
		local layer = predictLayer(tree, hit.Position, d)
		if layer ~= nil and State.tool == "robo" then
			Sfx.play("clink", 1.6, -8)
			Sfx.play("axe", 1.3, -4)
			burst(hit.Position, hit.Normal, hit.Instance.Color, 10, 22)
		elseif layer ~= nil then
			Sfx.play(if State.tool == "hands" then "chop" else "axe", if layer == BarkGrid.OUTER then 1 else 1.15)
			burst(hit.Position, hit.Normal, hit.Instance.Color, 10, 22)
		else
			Sfx.play("chop_wood")
			burst(hit.Position, hit.Normal, Color3.fromRGB(214, 176, 128), 8, 20)
		end
		State.kick = 0.01 + ToolController.stripRadius() * 0.09 + (if d.through then 0.03 else 0)
		shake(tree, 0.4 + ToolController.stripRadius())
		if d.combo then
			State.combo = math.min(State.combo + 1, Config.ComboMax)
			State.comboT = 0
		end
		remotes.StripRequest:FireServer(tree, hit.Position, State.tool)
	elseif hit.Instance == workspace.Terrain or hit.Material == Enum.Material.Grass or hit.Material == Enum.Material.Ground then
		-- dirt and grass fly where you hit the ground
		burst(hit.Position, hit.Normal, Color3.fromHex("7a5a3a"), 8, 14)
		burst(hit.Position, hit.Normal, Color3.fromHex("5f9a3a"), 6, 10)
		Sfx.play("thud", 1.4, -6)
	else
		Sfx.play("thud", 1, -4)
	end
end

local function startSwing()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if State.swing >= 0 or State.equipT < 1 or State.uiOpen or State.fainted or not hum or hum.Health <= 0 then
		return
	end
	-- (holding something: the click does nothing, like Godot's)
	local loose = workspace:FindFirstChild("Loose")
	if loose then
		for _, p in loose:GetChildren() do
			if p:GetAttribute("HeldBy") == player.UserId then
				return
			end
		end
	end
	-- (a click on a TimberMart box opens it instead, like Godot's on_click)
	local d = def()
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character :: Instance, cam }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local near = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * math.min(d.reach, 3) * M, params)
	if near and near.Instance:GetAttribute("Kind") == "box" and near.Instance:GetAttribute("Owner") == player.UserId then
		remotes.Open:FireServer(near.Instance)
		return
	end
	State.swing = 0
	impacts = 0
	if d.anim == "double" or d.anim == "sweep" or d.anim == "twin" then
		State.backhand = not State.backhand
	end
	if State.tool ~= "hands" then
		Sfx.play("whoosh", 1.4 - d.stripRadius, -8)
	end
end

function ToolController.start()
	local pressing = false
	InputController.on("Swing", function(state)
		pressing = state == Enum.UserInputState.Begin
		if state == Enum.UserInputState.Begin then
			startSwing()
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		if pressing and def().auto and State.swing < 0 then
			startSwing()
		end
		State.comboT += dt
		if State.comboT > 1.25 and State.combo > 0 then
			State.combo = 0
			Sfx.play("click", 0.5, -8)
		end
	end)
	InputController.on("NextTool", function(state)
		if state == Enum.UserInputState.Begin and not State.uiOpen then
			cycle(1)
		end
	end)
	InputController.on("PrevTool", function(state)
		if state == Enum.UserInputState.Begin and not State.uiOpen then
			cycle(-1)
		end
	end)
	InputController.on("DropTool", function(state)
		if state == Enum.UserInputState.Begin and State.tool ~= "hands" and not State.uiOpen then
			remotes.DropTool:FireServer()
			State.tool = "hands"
			State.swing = -1
			State.equipT = 0
			Sfx.play("drop", 0.8)
			State.toolsChanged()
		end
	end)
	-- 1-9 pick your first nine tools; with Shift held, the next nine
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
		Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or State.uiOpen then
			return
		end
		local n = table.find(keys, input.KeyCode)
		if n then
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				n += 9
			end
			local bar = ToolController.bar()
			if bar[n] then
				ToolController.equip(bar[n])
			end
		end
	end)
	-- the server put something in your hand (taken from the chopping block, bought, picked back up)
	local function fromServer()
		local id = player:GetAttribute("Tool")
		if typeof(id) == "string" and id ~= State.tool then
			State.tool = id
			State.swing = -1
			State.equipT = 0
			if id ~= "hands" then
				Sfx.play("equip")
			end
		end
		State.toolsChanged()
	end
	player:GetAttributeChangedSignal("Tool"):Connect(fromServer)
	player:GetAttributeChangedSignal("Owned"):Connect(State.toolsChanged)
	player:GetAttributeChangedSignal("Dropped"):Connect(State.toolsChanged)
	RunService.Heartbeat:Connect(function(dt)
		State.equipT = math.min(1, State.equipT + dt * 4)
		if State.swing < 0 then
			return
		end
		local d = def()
		State.swing += dt / d.cooldown
		local hits = d.impacts or { d.impact }
		while impacts < #hits and State.swing >= hits[impacts + 1] do
			impacts += 1
			impact()
		end
		if State.swing >= 1 then
			State.swing = -1
		end
	end)
	-- a respawn: back to bare hands in view until the server says otherwise
	player.CharacterAdded:Connect(function()
		State.swing = -1
		State.equipT = 0
	end)
end

return ToolController
