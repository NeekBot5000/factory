--!strict
-- The cabin chimney's smoke, the Godot game's way (Nature.Smoke): twelve grey puffs that rise and drift with the
-- breeze, growing and then fading, one after another over 4.5 seconds, round and round. Purely a look, so each
-- client draws its own. The puff is Godot's blob (ReplicatedStorage.Props.puff); a grey ball stands in until then.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local W = require(ReplicatedStorage.Shared.GodotWorld) :: any

local SmokeController = {}
local M = Config.StudsPerMetre
local PUFFS, LIFE = 12, 4.5

local function newPuff(): Model
	local props = ReplicatedStorage:FindFirstChild("Props")
	local src = props and props:FindFirstChild("puff")
	local m: Model
	if src then
		m = (src :: Model):Clone()
	else
		m = Instance.new("Model")
		local b = Instance.new("Part")
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.one * 0.36 * M
		b.Color = Color3.new(0.84, 0.84, 0.87)
		b.Material = Enum.Material.SmoothPlastic
		b.Parent = m
		m:SetAttribute("Standin", true)
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	m.Name = "Puff"
	return m
end

function SmokeController.start()
	if not W.smoke then
		return
	end
	local at = Vector3.new(W.smoke.at[1], W.smoke.at[2], W.smoke.at[3])
	local folder = Instance.new("Folder")
	folder.Name = "ChimneySmoke"
	folder.Parent = workspace
	local puffs: { Model } = {}
	local seeds: { number } = {}
	for i = 1, PUFFS do
		puffs[i] = newPuff()
		puffs[i].Parent = folder
		seeds[i] = math.random() * 2 * math.pi
	end
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - at).Magnitude > 160 * M then
			return
		end
		for i = 1, PUFFS do
			-- (Godot's Puff loop, in metres, then studs)
			local p = puffs[i]
			if p:GetAttribute("Standin") and ReplicatedStorage:FindFirstChild("Props") then
				p:Destroy()
				p = newPuff()
				p.Parent = folder
				puffs[i] = p
			end
			local age = (t + (i - 1) / PUFFS * LIFE) % LIFE
			local k = age / LIFE
			local sd = seeds[i]
			local wob = Vector3.new(math.sin(age * 1.3 + sd) * 0.15, 0, math.cos(age * 1.1 + sd) * 0.15)
			local pos = Vector3.new(0.35, 1.0, 0.1) * age * 0.55 + Vector3.new(0.12, 0, 0) * age * age * 0.2 + wob * k
			local sc = (0.5 + (2.2 - 0.5) * math.sqrt(k))
			local fade = if k < 0.75 then 0 else math.clamp((k - 0.75) / 0.25, 0, 1)
			fade = fade * fade * (3 - 2 * fade)
			sc *= 1 - fade
			sc = math.max(sc, 0.001)
			if p:GetScale() ~= sc then
				p:ScaleTo(sc)
			end
			p:PivotTo(CFrame.new(at + pos * M) * CFrame.Angles(sd, age * 0.4 + sd, 0))
		end
	end)
end

return SmokeController
