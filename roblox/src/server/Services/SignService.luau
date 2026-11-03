--!strict
-- The company sign by the road, the Godot game's way (CompanySign.gd): it starts as a scrap of board on a stake and
-- gets bigger and grander as the business earns more (tiers at 0, 500, 2,500, 10,000, 50,000 and 200,000 earned),
-- with no words, just the axe-and-tree emblem. On a server with several players it shows the best earner's.
-- The tiers are Godot's own meshes (ReplicatedStorage.Props.sign_0 .. sign_5, from props.glb); until they've loaded,
-- simple boards stand in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local W = require(ReplicatedStorage.Shared.GodotWorld) :: any
local DataService = require(script.Parent.DataService)

local SignService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
SignService.TIERS = { 0, 500, 2500, 10000, 50000, 200000 }

local tier = -1
local real = false          -- the shown sign is Godot's mesh (not a stand-in)

function SignService.tierFor(earned: number): number
	local t = 0
	for i, need in SignService.TIERS do
		if earned >= need then
			t = i - 1
		end
	end
	return t
end

local function where(): CFrame
	local s = W.sign or { at = { -11.4, 0, 20.4 }, yaw = math.pi / 2 }
	return CFrame.new(s.at[1], s.at[2], s.at[3]) * CFrame.Angles(0, s.yaw, 0)
end

-- a stand-in for tier t: the post(s) and the board, at Godot's sizes
local function standin(t: number, model: Model)
	local w = ({ 0.6, 1.0, 1.4, 1.6, 1.9, 2.2 })[t + 1] * M
	local h = ({ 0.4, 0.6, 0.8, 0.9, 1.0, 1.1 })[t + 1] * M
	local y = 1.0 * M + h * 0.5
	local base = where()
	local function box(size: Vector3, at: Vector3, hex: string)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = base * CFrame.new(at)
		p.Color = Color3.fromHex(hex)
		p.Material = Enum.Material.SmoothPlastic
		p:SetAttribute("Standin", true)
		p.Parent = model
	end
	for _, sx in (if t == 0 then { 0 } else { -w * 0.45, w * 0.45 }) do
		box(Vector3.new(0.12 * M, y + h * 0.5, 0.12 * M), Vector3.new(sx, (y + h * 0.5) * 0.5, 0), "6b4a32")
	end
	box(Vector3.new(w, h, 0.08 * M), Vector3.new(0, y, 0), if t < 3 then "a0703c" else "c69a62")
end

function SignService.show(t: number)
	local model = workspace:FindFirstChild("CompanySign") :: Model?
	if not model then
		model = Instance.new("Model")
		model.Name = "CompanySign"
		model.Parent = workspace
	end
	local m = model :: Model
	m:ClearAllChildren()
	local props = ReplicatedStorage:FindFirstChild("Props")
	local src = props and props:FindFirstChild("sign_" .. t)
	if src then
		local copy = (src :: Model):Clone()
		copy:PivotTo(where())
		for _, p in copy:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		copy.Parent = m
		real = true
	else
		standin(t, m)
		real = false
	end
	tier = t
end

function SignService.step()
	local best = 0
	for _, p in Players:GetPlayers() do
		local d = DataService.get(p)
		if d then
			best = math.max(best, d.earned or 0)
		end
	end
	local want = SignService.tierFor(best)
	local grew = tier >= 0 and want > tier
	if want ~= tier or (not real and ReplicatedStorage:FindFirstChild("Props")) then
		SignService.show(want)
	end
	if grew then
		remotes.Notify:FireAllClients("Your company sign got an upgrade", "ffd27a")
		remotes.Fx:FireAllClients("reveal", where().Position, 1.0, 0)
	end
end

function SignService.start()
	SignService.show(0)
	task.spawn(function()
		while true do
			task.wait(2)      -- (Godot looks every 2 s)
			local ok, err = pcall(SignService.step)
			if not ok then
				warn("[Timber] company sign: " .. tostring(err))
			end
		end
	end)
end

return SignService
