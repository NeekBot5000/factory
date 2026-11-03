--!strict
-- The first-person arm, built from the Godot game's numbers (Player.gd _build_arm, in metres x3): a red sleeve
-- with two plaid cuffs, skin at the wrist, and either the flat karate hand (bare hands) or a fist holding the tool.
-- It's drawn on this client only, in front of the camera, and moves like Godot's: it rises into view when you take
-- a tool out, sways as you walk, winds up and strikes through each swing (the shape depends on the tool: a chop,
-- a karate chop, the double-bit's forehand and backhand, the labrys's overhead slam), and jolts on impact.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.State)

local ViewModel = {}
local M = Config.StudsPerMetre
local SLEEVE = Color3.fromHex("b8322c")
local PLAID = Color3.fromHex("2a2a2a")
local SKIN = Color3.fromHex("e0a989")
local ARM_BASE = CFrame.new(0.26 * M, -0.3 * M, -0.46 * M)
local TOOL_SCALE = 0.5          -- the tool models are sized for a character's hand; the Godot ones are half that

local model: Model
local root: Part
local handFlat: { BasePart } = {}
local handFist: { BasePart } = {}
local toolModel: Model? = nil
local shownTool = ""

local function piece(shape: Enum.PartType, size: Vector3, at: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = at
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

-- a cylinder along the arm (Godot's cylinders here are rotated to lie along Z; Roblox's run along X)
local function cyl(radius: number, length: number, z: number, color: Color3): Part
	return piece(Enum.PartType.Cylinder, Vector3.new(length * M, radius * 2 * M, radius * 2 * M), CFrame.new(0, 0, z * M) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Fabric)
end

local function build()
	model = Instance.new("Model")
	model.Name = "ViewModel"
	root = piece(Enum.PartType.Block, Vector3.new(0.05, 0.05, 0.05), CFrame.new(), SKIN)
	root.Transparency = 1
	model.PrimaryPart = root
	cyl(0.046, 0.34, 0.17, SLEEVE)
	cyl(0.051, 0.025, 0.08, PLAID)
	cyl(0.046, 0.04, 0.0, PLAID)
	cyl(0.032, 0.07, -0.05, SKIN).Material = Enum.Material.SmoothPlastic
	-- the flat karate hand
	table.insert(handFlat, piece(Enum.PartType.Block, Vector3.new(0.026, 0.085, 0.11) * M, CFrame.new(0, 0, -0.13 * M), SKIN))
	table.insert(handFlat, piece(Enum.PartType.Block, Vector3.new(0.024, 0.075, 0.035) * M, CFrame.new(0, -0.004 * M, -0.2 * M), SKIN))
	table.insert(handFlat, piece(Enum.PartType.Block, Vector3.new(0.022, 0.022, 0.06) * M, CFrame.new(0.016 * M, 0.036 * M, -0.1 * M) * CFrame.Angles(0, math.rad(-20), 0), SKIN))
	-- the fist round a handle
	table.insert(handFist, piece(Enum.PartType.Block, Vector3.new(0.06, 0.075, 0.08) * M, CFrame.new(0, 0, -0.12 * M), SKIN))
	table.insert(handFist, piece(Enum.PartType.Block, Vector3.new(0.062, 0.03, 0.05) * M, CFrame.new(0, -0.035 * M, -0.15 * M), SKIN))
	model.WorldPivot = CFrame.new()
end

local function setTool(id: string)
	shownTool = id
	if toolModel then
		toolModel:Destroy()
		toolModel = nil
	end
	for _, p in handFlat do
		p.Transparency = if id == "hands" then 0 else 1
	end
	for _, p in handFist do
		p.Transparency = if id == "hands" then 1 else 0
	end
	local models = ReplicatedStorage:FindFirstChild("ToolModels")
	local src = models and models:FindFirstChild(id)
	if id ~= "hands" and src then
		local m = (src :: Model):Clone()
		m:ScaleTo(TOOL_SCALE)
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CastShadow = false
			end
		end
		m.Parent = model
		toolModel = m
	end
end

-- the arm's pose through a swing: t is 0..1 through it, hit = when the blade lands (Godot's _poses, simplified)
local function swingPose(anim: string, t: number, hit: number, back: boolean): CFrame
	local function ease(x: number): number
		return 1 - (1 - x) * (1 - x)
	end
	local wind, strike = 0, 0
	if t < hit * 0.7 then
		wind = ease(t / (hit * 0.7))                       -- wind up
	elseif t < hit then
		wind = 1 - (t - hit * 0.7) / (hit * 0.3)          -- whip through
		strike = (t - hit * 0.7) / (hit * 0.3)
	else
		strike = 1 - ease((t - hit) / (1 - hit))           -- recover
	end
	if anim == "karate" then
		-- the flat hand goes up and out to the side, then chops across and down
		return CFrame.new(0.25 * M * wind - 0.2 * M * strike, 0.12 * M * wind - 0.05 * M * strike, 0.05 * M * wind - 0.12 * M * strike)
			* CFrame.Angles(math.rad(20 * wind - 25 * strike), math.rad(25 * wind - 35 * strike), math.rad(-35 * wind + 50 * strike))
	elseif anim == "double" then
		-- a wide flat sweep, forehand one way, backhand the other
		local s = if back then -1 else 1
		return CFrame.new(s * (0.22 * M * wind - 0.3 * M * strike), 0.02 * M, -0.1 * M * strike)
			* CFrame.Angles(0, math.rad(s * (55 * wind - 75 * strike)), math.rad(s * -60 * (wind + strike) * 0.6))
	elseif anim == "slam" then
		-- both hands overhead, then down hard
		return CFrame.new(-0.12 * M * (wind + strike), 0.3 * M * wind - 0.1 * M * strike, 0.1 * M * wind - 0.2 * M * strike)
			* CFrame.Angles(math.rad(95 * wind - 65 * strike), 0, math.rad(15 * wind))
	end
	-- a chop: raise the axe back over the shoulder, then strike forward and down
	return CFrame.new(0.04 * M * wind, 0.16 * M * wind - 0.06 * M * strike, 0.06 * M * wind - 0.14 * M * strike)
		* CFrame.Angles(math.rad(70 * wind - 50 * strike), math.rad(-8 * wind), math.rad(-10 * wind))
end

function ViewModel.start()
	build()
	local camera = workspace.CurrentCamera
	local player = Players.LocalPlayer
	RunService:BindToRenderStep("TimberViewModel", Enum.RenderPriority.Camera.Value + 1, function(dt)
		camera = workspace.CurrentCamera
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local show = camera ~= nil and hum ~= nil and hum.Health > 0 and not State.uiOpen and not State.fainted
		if not show then
			model.Parent = nil
			return
		end
		model.Parent = camera
		if State.tool ~= shownTool then
			setTool(State.tool)
		end
		local def = (Config.Tools :: any)[State.tool] or Config.Tools.hands
		local pose = CFrame.new()
		if State.swing >= 0 then
			local hits = def.impacts or { def.impact }
			pose = swingPose(def.anim or "chop", State.swing, hits[1], State.backhand)
		end
		-- sway as you walk (Godot's _bob), rise into view after an equip, and a jolt on impact
		local sway = CFrame.new(math.sin(State.bob) * 0.012 * M, -math.abs(math.cos(State.bob)) * 0.01 * M, 0)
		local rise = CFrame.new(0, -0.25 * M * (1 - State.equipT) ^ 2, 0) * CFrame.Angles(math.rad(-40 * (1 - State.equipT) ^ 2), 0, 0)
		local jolt = CFrame.new(0, 0, State.kick * M * 0.5)
		State.kick = math.max(0, State.kick - dt * 0.6)
		local armCf = camera.CFrame * ARM_BASE * sway * rise * pose * jolt
		model:PivotTo(armCf)
		if toolModel then
			-- in the fist, tilted forward like Godot's (-35 degrees)
			toolModel:PivotTo(armCf * CFrame.new(0, -0.01 * M, -0.13 * M) * CFrame.Angles(math.rad(-35), 0, 0))
		end
	end)
end

return ViewModel
