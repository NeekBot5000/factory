--!strict
-- Swinging. Aims from the centre of the screen (the crosshair), which works the same in first person, third person,
-- on touch and on a gamepad. Everything you feel happens on this client straight away:
--   the standard slash animation, a swing whoosh, and on a hit: a chop sound, bark chips flying, the crown shaking
--   and a small camera kick.
-- The server decides what actually comes off and tells everyone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local InputController = require(script.Parent.InputController)
local UiKit = require(script.Parent.Parent.Ui.UiKit)
local Sfx = require(script.Parent.Parent.Sfx)

local ToolController = {}
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local last = 0
local crownHome: { [Model]: CFrame } = {}

-- the tool in your hand (a Tool with a ToolId), or bare hands
local function current(): (string, Tool?)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("ToolId")
	if typeof(id) == "string" then
		return id, tool
	end
	return "hands", nil
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

local function chips(at: Vector3, normal: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.lookAt(at, at + normal)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.3))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.1) })
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(10, 18)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-300, 300)
	e.EmissionDirection = Enum.NormalId.Front
	e.Rate = 0
	e.Parent = p
	e:Emit(14)
	task.delay(1.2, function()
		p:Destroy()
	end)
end

local function shake(tree: Model)
	local crown = tree:FindFirstChild("Crown") :: Model?
	if not crown then
		return
	end
	local home = crownHome[crown] or crown:GetPivot()
	crownHome[crown] = home
	local v = Instance.new("CFrameValue")
	v.Value = home * CFrame.Angles(math.rad(2.5), 0, math.rad(1.5))
	v.Changed:Connect(function(cf)
		if crown.Parent then
			crown:PivotTo(cf)
		end
	end)
	crown:PivotTo(v.Value)
	local t = TweenService:Create(v, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Value = home })
	t:Play()
	t.Completed:Once(function()
		v:Destroy()
	end)
end

local function kick()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	hum.CameraOffset = Vector3.new(0, -0.18, 0)
	TweenService:Create(hum, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { CameraOffset = Vector3.zero }):Play()
end

local function swing()
	local id, tool = current()
	local def = (Config.Tools :: any)[id]
	if not def or os.clock() - last < def.cooldown then
		return
	end
	last = os.clock()
	-- the standard Roblox slash animation (the default Animate script listens for this)
	if tool then
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		task.delay(0.3, function()
			anim:Destroy()
		end)
	end
	Sfx.play("whoosh", 1.2, -8)
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character :: Instance }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 40, params)
	if not hit then
		return
	end
	local tree = treeOf(hit.Instance)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not tree or not root or (root.Position - hit.Position).Magnitude > 13 then
		return
	end
	-- feel first, then ask the server
	Sfx.play(if id == "hands" then "chop" else "axe")
	chips(hit.Position, hit.Normal, hit.Instance.Color)      -- (aim rays pass the drawn bark and land on the trunk)
	shake(tree)
	kick()
	remotes.StripRequest:FireServer(tree, hit.Position, id)
end

function ToolController.start()
	InputController.on("Swing", function(state)
		if state == Enum.UserInputState.Begin then
			swing()
		end
	end)
	-- a little sound when a tool comes out
	player.CharacterAdded:Connect(function(char)
		char.ChildAdded:Connect(function(c)
			if c:IsA("Tool") then
				Sfx.play("equip")
			end
		end)
		-- bare hands on rough bark: an ouch
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		local hp = hum.Health
		hum.HealthChanged:Connect(function(now)
			if now < hp - 0.5 then
				Sfx.play("ouch", 1, -4)
			end
			hp = now
		end)
	end)
end

return ToolController
