--!strict
-- The drones' sizes and dials (Godot's Drone.gd), shared so the client's hint names the dial you're looking at.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Drones = {}
local M = Config.StudsPerMetre
Drones.SIZES = {
	drone_small = { name = "Small Drone", w = 0.6, lift = 3.5, drain = 0.002 },
	drone_medium = { name = "Medium Drone", w = 0.85, lift = 9.0, drain = 0.003 },
	drone_large = { name = "Large Drone", w = 1.15, lift = 40.0, drain = 0.0045 },
} :: { [string]: { name: string, w: number, lift: number, drain: number } }
-- Godot's Wireless channels
Drones.CHANNELS = { "e8503a", "3fa66b", "3f8ee8", "f2c12e", "9b6ad6", "f08a2e", "eeeeee", "f06fb0" }
Drones.NAMES = { "red", "green", "blue", "yellow", "purple", "orange", "white", "pink" }
Drones.DIALS = { "front", "right", "back", "left", "pad" }

function Drones.isDrone(m: Instance): boolean
	return Drones.SIZES[m:GetAttribute("Build") :: string? or ""] ~= nil
end

function Drones.dials(m: Model): { number }
	local out = {}
	for _, s in string.split(m:GetAttribute("Dials") :: string? or "0,1,2,3,4", ",") do
		table.insert(out, tonumber(s) or -1)
	end
	while #out < 5 do
		table.insert(out, -1)
	end
	return out
end

-- where each dial sits on the body (front, right, back, left, and the pad dial on top), metres
function Drones.dialPos(m: Model, i: number): Vector3
	local h = Drones.SIZES[m:GetAttribute("Build") :: string].w * 0.5
	if i == 1 then
		return Vector3.new(0, 0.18, -h - 0.02)
	elseif i == 2 then
		return Vector3.new(h + 0.02, 0.18, 0)
	elseif i == 3 then
		return Vector3.new(-0.15, 0.18, h + 0.02)
	elseif i == 4 then
		return Vector3.new(-h - 0.02, 0.18, 0)
	end
	return Vector3.new(-0.12, 0.27, -0.05)
end

-- which dial a part of the drone is, or nil (the dials are their own small parts, right where dialPos says)
function Drones.dialOf(m: Model, part: Instance): number?
	if not part:IsA("BasePart") or part.Size.Magnitude > 0.5 * M then
		return nil
	end
	local size = m:GetAttribute("Size") :: number? or 1
	local lp = m:GetPivot():PointToObjectSpace(part.CFrame.Position) / (M * size)
	for i = 1, 5 do
		if (lp - Drones.dialPos(m, i)).Magnitude < 0.12 then
			return i
		end
	end
	return nil
end

function Drones.channelName(ch: number): string
	return if ch < 0 then "off" else Drones.NAMES[ch + 1] .. " channel"
end

return Drones
