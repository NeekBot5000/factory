--!strict
-- How heavy a thing is, in Godot's kilograms (Player._weight and the bodies' masses): a log by its wood (600 kg a
-- cubic metre), a sheet of bark 0.25 kg a panel, the rest as Godot weighs them. The scale shows it; the leaf
-- blower pushes light things far and heavy ones barely.
local Weight = {}

function Weight.of(p: Instance): number
	if not p:IsA("BasePart") then
		return 0
	end
	local kind = p:GetAttribute("Kind")
	local log = p.Parent
	if p.Name == "Trunk" and log and log:GetAttribute("Kind") == "log" then
		local r = (log:GetAttribute("Radius") :: number? or 1.2) / 3
		local len = (log:GetAttribute("Bands") :: number? or 10) * 0.18
		return math.pi * r * r * len * 600
	elseif kind == "bark" then
		return 0.25 * (p:GetAttribute("Panels") :: number? or 1)
	elseif kind == "leaf" then
		return math.clamp(p.Size.X / 3 / 1.6 * 0.6, 0.05, 0.4)
	elseif kind == "ore" then
		return math.clamp(p.Size.X / 3 / 1.9 * 8, 0.4, 3)
	elseif kind == "sapling" then
		return 0.4
	elseif kind == "ball" then
		return 0.6
	elseif kind == "basket" then
		return 4
	elseif kind == "box" then
		return 3
	end
	return 1
end

return Weight
