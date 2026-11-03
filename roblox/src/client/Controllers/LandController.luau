--!strict
-- Your land, the Godot game's way (Land.rebuild): corner stakes round everything you own, and a "for sale" sign on
-- every plot next to yours (E on it buys that plot). Each player owns their own land, so each client draws its own.
-- Godot's meshes (ReplicatedStorage.Props.forsale / stake); a post and a board stand in until they've loaded.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Land = require(ReplicatedStorage.Shared.Land)
local W = require(ReplicatedStorage.Shared.GodotWorld) :: any

local LandController = {}
local player = Players.LocalPlayer
local M = Config.StudsPerMetre

local function heightAt(x: number, z: number): number
	local g = W.ground
	local fx = math.clamp((x - g.origin) / g.step, 0, g.n - 1.001)
	local fz = math.clamp((z - g.origin) / g.step, 0, g.n - 1.001)
	local ix, iz = math.floor(fx), math.floor(fz)
	local tx, tz = fx - ix, fz - iz
	local function h(i: number, k: number): number
		return g.heights[k * g.n + i + 1]
	end
	local a = h(ix, iz) + (h(ix + 1, iz) - h(ix, iz)) * tx
	local b = h(ix, iz + 1) + (h(ix + 1, iz + 1) - h(ix, iz + 1)) * tx
	return a + (b - a) * tz
end

local function prop(name: string): Model
	local props = ReplicatedStorage:FindFirstChild("Props")
	local src = props and props:FindFirstChild(name)
	local m: Model
	if src then
		m = (src :: Model):Clone()
	else
		m = Instance.new("Model")
		local post = Instance.new("Part")
		post.Size = Vector3.new(0.1, if name == "stake" then 0.8 else 1.3, 0.1) * M
		post.CFrame = CFrame.new(0, post.Size.Y / 2, 0)
		post.Color = Color3.fromHex("a0703c")
		post.Parent = m
		if name == "forsale" then
			local board = Instance.new("Part")
			board.Size = Vector3.new(0.8, 0.5, 0.05) * M
			board.CFrame = CFrame.new(0, 1.25 * M, 0)
			board.Color = Color3.fromHex("f2ede0")
			board.Parent = m
		end
		m:SetAttribute("Standin", true)
	end
	m.WorldPivot = CFrame.new()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = name == "forsale"
		end
	end
	return m
end

function LandController.draw()
	local old = workspace:FindFirstChild("MyLand")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "MyLand"
	local land = string.split(player:GetAttribute("Land") :: string? or table.concat(Land.START, ";"), ";")
	local signs, corners = Land.signs(land)
	for _, s in signs do
		local m = prop("forsale")
		m.Name = "ForSale"
		m:SetAttribute("Kind", "forsale")
		m:SetAttribute("Plot", s.key)
		m:PivotTo(CFrame.new(s.x, heightAt(s.x, s.z), s.z))
		m.Parent = f
	end
	for _, c in corners do
		local m = prop("stake")
		m:PivotTo(CFrame.new(c.x, heightAt(c.x, c.z), c.z))
		m.Parent = f
	end
	f.Parent = workspace
end

function LandController.start()
	LandController.draw()
	player:GetAttributeChangedSignal("Land"):Connect(LandController.draw)
	-- (Godot's meshes arrive a little after the start: draw again with them)
	task.spawn(function()
		local props = ReplicatedStorage:WaitForChild("Props", 120)
		if props then
			LandController.draw()
		end
	end)
end

return LandController
