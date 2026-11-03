--!strict
-- Moving like the Godot player (Player.gd): walk 4.2 m/s, sprint 6.8 with Shift, slower with heavy tools; a
-- footstep every 0.7 m (0.9 sprinting), soft on grass, hollow on wood, gritty on stone. Also the first-person
-- camera's field of view (75), no mouse pointer (the crosshair is the HUD's), the "ouch" when you're hurt and low,
-- and fainting: at 0 health the screen goes dark and you wake up at the start.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local InputController = require(script.Parent.InputController)
local State = require(script.Parent.Parent.State)
local Sfx = require(script.Parent.Parent.Sfx)

local MoveController = {}
local player = Players.LocalPlayer
local M = Config.StudsPerMetre
local P = Config.Player

local WOOD = { [Enum.Material.Wood] = true, [Enum.Material.WoodPlanks] = true }
local STONE = { [Enum.Material.Slate] = true, [Enum.Material.Rock] = true, [Enum.Material.Concrete] = true,
	[Enum.Material.Cobblestone] = true, [Enum.Material.Brick] = true, [Enum.Material.Granite] = true, [Enum.Material.Basalt] = true }

local function stepSound(m: Enum.Material): string
	if WOOD[m] then
		return "step_wood"
	elseif STONE[m] then
		return "step_stone"
	end
	return "step"
end

local function onCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	State.fainted = false
	local last = hum.Health
	hum.HealthChanged:Connect(function(h)
		-- Godot: "ouch" only once you're getting low (under 40)
		if h < last - 0.01 and h > 0 and h < 40 then
			Sfx.play("ouch", 1, -4)
		end
		last = h
	end)
	hum.Died:Connect(function()
		State.fainted = true
		Sfx.play("faint")
	end)
end

function MoveController.start()
	UserInputService.MouseIconEnabled = false
	InputController.on("Sprint", function(state)
		State.sprinting = state == Enum.UserInputState.Begin
	end)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	local stepAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if cam then
			cam.FieldOfView = P.fov
		end
		-- the pointer only shows while a screen like the shop is open
		UserInputService.MouseIconEnabled = State.uiOpen
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hum or not root or hum.Health <= 0 then
			return
		end
		local def = (Config.Tools :: any)[State.tool] or Config.Tools.hands
		hum.WalkSpeed = (if State.sprinting then P.sprint else P.walk) * M * (def.move or 1)
		local v = root.AssemblyLinearVelocity
		local speed = Vector2.new(v.X, v.Z).Magnitude / M          -- metres a second, like Godot's
		if hum.FloorMaterial ~= Enum.Material.Air and speed > 0.5 then
			State.bob += dt * speed * 2.2
			stepAcc += speed * dt
			if stepAcc > (if State.sprinting then 0.9 else 0.7) then
				stepAcc = 0
				Sfx.play(stepSound(hum.FloorMaterial), 0.85 + math.random() * 0.25, -8)
			end
		else
			State.bob += (math.round(State.bob / math.pi) * math.pi - State.bob) * math.min(1, dt * 6)
		end
	end)
end

return MoveController
