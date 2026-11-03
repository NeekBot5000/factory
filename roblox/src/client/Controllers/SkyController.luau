--!strict
-- The clouds drift slowly across the sky, like the Godot game's (Main._drift_clouds: 1.2 m a second along X, and
-- round again past the edge). Each cloud is one of the Godot meshes ("cloud_3_c..."): moved on this client only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)

local SkyController = {}
local M = Config.StudsPerMetre
local SPEED = 1.2 * M
local EDGE, SPAN = 190 * M, 380 * M

function SkyController.start()
	local clouds: { BasePart } = {}
	local acc = 10
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc > 5 then
			-- (look for the clouds now and then: the Godot meshes load a few seconds after you join)
			acc = 0
			local world = workspace:FindFirstChild("GodotWorld")
			table.clear(clouds)
			for _, p in if world then world:GetChildren() else {} do
				local name = p:GetAttribute("GodotName")
				if p:IsA("BasePart") and typeof(name) == "string" and string.find(name, "^cloud") then
					table.insert(clouds, p)
				end
			end
		end
		for _, p in clouds do
			local x = p.Position.X + SPEED * dt
			if x > EDGE then
				x -= SPAN
			end
			p.CFrame = CFrame.new(x, p.Position.Y, p.Position.Z) * p.CFrame.Rotation
		end
	end)
end

return SkyController
