--!strict
-- The finished builds' looks that move, on each client: the campfire's flames flicker and its light wavers (Godot's
-- Campfire._physics_process), and a compost pile's mound rises with what's in it.
local RunService = game:GetService("RunService")

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
