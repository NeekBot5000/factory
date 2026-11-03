--!strict
-- Your trophy wall in the cabin (Trophies._build): nine plaques, three rows of four, each empty until you've earned
-- it and then with its keepsake on it. Godot's meshes (Props.plaque, Props.trophy_<id>); boards stand in until then.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local W = require(ReplicatedStorage.Shared.GodotWorld) :: any

local TrophyController = {}
local player = Players.LocalPlayer
local M = Config.StudsPerMetre
local IDS = { "first_tree", "first_machine", "thousand", "first_plank", "first_iron", "first_furniture", "giant", "legend", "first_oil" }

local function plaque(name: string): Model
	local props = ReplicatedStorage:FindFirstChild("Props")
	local src = props and props:FindFirstChild(name)
	local m: Model
	if src then
		m = (src :: Model):Clone()
	else
		m = Instance.new("Model")
		local b = Instance.new("Part")
		b.Size = Vector3.new(0.03, 0.4, 0.4) * M
		b.Color = Color3.fromHex("6b4a32")
		b.Parent = m
	end
	m.WorldPivot = CFrame.new()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
	return m
end

function TrophyController.draw()
	if not W.trophies then
		return
	end
	local old = workspace:FindFirstChild("MyTrophies")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "MyTrophies"
	local have = {}
	for _, id in string.split(player:GetAttribute("Trophies") :: string? or "", ",") do
		have[id] = true
	end
	local wall = Vector3.new(W.trophies.at[1], W.trophies.at[2], W.trophies.at[3])
	for i, id in IDS do
		local k = i - 1
		local at = wall + Vector3.new(0, 1.75 - (k // 4) * 0.55, -1.2 + (k % 4) * 0.6) * M
		local m = plaque(if have[id] then "trophy_" .. id else "plaque")
		m:PivotTo(CFrame.new(at))
		m.Parent = f
	end
	f.Parent = workspace
end

function TrophyController.start()
	TrophyController.draw()
	player:GetAttributeChangedSignal("Trophies"):Connect(TrophyController.draw)
	task.spawn(function()
		if ReplicatedStorage:WaitForChild("Props", 120) then
			TrophyController.draw()
		end
	end)
end

return TrophyController
