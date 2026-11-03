--!strict
-- The finished builds' looks that move, on each client: the campfire's flames flicker and its light wavers (Godot's
-- Campfire._physics_process), a compost pile's mound rises with what's in it, and a drone's rotors spin while it
-- has power (Drone._physics_process: up to 40 rad/s).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builds = require(ReplicatedStorage.Shared.Builds)

local BuildFx = {}

function BuildFx.start()
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local f = workspace:FindFirstChild("Builds")
		if not f then
			return
		end
		for _, m in f:GetChildren() do
			local spin = m:GetAttribute("Spin") :: number?
			if spin and spin > 0 and m:IsA("Model") then
				local def = Builds.def(m:GetAttribute("Build") :: string)
				local size = m:GetAttribute("Size") :: number? or 1
				for _, p in m:GetDescendants() do
					local g = p:IsA("BasePart") and p:GetAttribute("Group") :: string?
					local at = g and def and (def :: any).groups and (def :: any).groups[g]
					if at then
						local hub = m:GetPivot() * CFrame.new(at[1] * size, at[2] * size, at[3] * size)
						;(p :: BasePart).CFrame = hub * CFrame.Angles(0, spin * 40 * dt, 0) * hub:ToObjectSpace((p :: BasePart).CFrame)
					end
				end
			end
			if m:GetAttribute("Build") == "campfire" then
				local flames = m:FindFirstChild("Flames")
				local size = m:GetAttribute("Size") :: number? or 1
				if flames then
					for i, p in flames:GetChildren() do
						local part = p :: BasePart
						local home = part:GetAttribute("Home") :: CFrame?
						local h = part:GetAttribute("H") :: number?
						if not home then
							part:SetAttribute("Home", part.CFrame)
							part:SetAttribute("H", part.Size.Y)
							home, h = part.CFrame, part.Size.Y
						end
						local k = 0.8 + 0.35 * math.sin(t * (9 + i) + i * 1.7) + math.random() * 0.15
						part.Size = Vector3.new(part.Size.X, (h :: number) * k, part.Size.Z)
						part.CFrame = (home :: CFrame) * CFrame.new(0, ((h :: number) * k - (h :: number)) / 2, 0)
					end
				end
				local light = m:FindFirstChild("FireLight")
				local pl = light and light:FindFirstChildOfClass("PointLight")
				if pl then
					pl.Brightness = 1.4 + math.sin(t * 13) * 0.2 + math.random() * 0.25
				end
				local _ = size
			end
		end
	end)
end

return BuildFx
