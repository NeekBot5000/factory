--!strict
-- Oil pumps: Models tagged "OilPump". While powered, a pump fills a barrel at a rate set by how rich the ground
-- under it is (OilField), and pushes each full barrel out of its front. Runs once a second, not every frame.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local OilField = require(ReplicatedStorage.Shared.OilField)

local OilService = {}

local function spawnBarrel(pump: Model)
	local b = Instance.new("Part")
	b.Shape = Enum.PartType.Cylinder
	b.Size = Vector3.new(3, 2, 2)
	b.Color = Color3.fromRGB(47, 58, 72)
	b.CFrame = pump:GetPivot() * CFrame.new(0, 2, -5) * CFrame.Angles(0, 0, math.rad(90))
	b:SetAttribute("Kind", "oil_barrel")
	b:SetAttribute("Value", Config.Products.oil_barrel.value)
	b:SetAttribute("Owner", pump:GetAttribute("Owner"))
	b:SetAttribute("Fuel", Config.Products.oil_barrel.fuel)
	b.Parent = workspace:FindFirstChild("Loose")
end

function OilService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, inst in CollectionService:GetTagged("OilPump") do
				local pump = inst :: Model
				if pump:GetAttribute("Powered") then
					local p = pump:GetPivot().Position
					local fill = (pump:GetAttribute("Fill") :: number? or 0) + OilField.pumpRate(p.X, p.Z, Config.Oil)
					if fill >= 1 then
						fill -= 1
						spawnBarrel(pump)
					end
					pump:SetAttribute("Fill", fill)
				end
			end
		end
	end)
end

return OilService
