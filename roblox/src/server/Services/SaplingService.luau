--!strict
-- Saplings, the Godot game's way (Sapling.gd): put one down on open ground and leave it. Once it has lain still on
-- the ground for 1.5 s it takes root (it stands up and can't be picked up any more), then grows, six times its size,
-- and after five minutes it's a full-size tree you can strip and saw like any other.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local LogService = require(script.Parent.LogService)
local WorldService = require(script.Parent.WorldService)

local SaplingService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local S = Config.Sapling
local rest: { [string]: number } = {}

local function key(p: BasePart): string
	local k = p:GetAttribute("Id")
	if not k then
		k = tostring(math.random(1, 2 ^ 30))
		p:SetAttribute("Id", k)
	end
	return k :: string
end

-- on open ground (Godot: the terrain, not the porch or a rock)
local function onGround(p: BasePart): boolean
	local at = p.Position
	return at.Y - WorldService.heightAt(at.X, at.Z) < 0.5 * M
end

local function root(p: BasePart)
	p.Anchored = true
	local at = p.Position
	p.CFrame = CFrame.new(at.X, WorldService.heightAt(at.X, at.Z) + 0.04 * M, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	p:SetAttribute("Rooted", true)
	LogService.buildSprout(p, p:GetAttribute("Species") :: string or "oak", 1)
	remotes.Fx:FireAllClients("pickup", p.Position, 0.6)
end

function SaplingService.step(dt: number)
	local loose = workspace:FindFirstChild("Loose")
	if not loose then
		return
	end
	for _, c in loose:GetChildren() do
		if not c:IsA("BasePart") or c:GetAttribute("Kind") ~= "sapling" then
			continue
		end
		local p = c :: BasePart
		if not p:GetAttribute("Rooted") then
			local k = key(p)
			if not p:GetAttribute("HeldBy") and p.AssemblyLinearVelocity.Magnitude < 0.15 * M and onGround(p) then
				rest[k] = (rest[k] or 0) + dt
				if rest[k] > S.rest then
					rest[k] = nil
					root(p)
				end
			else
				rest[k] = 0
			end
			continue
		end
		-- (watered: twice as fast while the boost lasts)
		local boost = p:GetAttribute("Boost") :: number? or 0
		local grow = (p:GetAttribute("Grow") :: number? or 0) + dt * (if boost > 0 then 2 else 1)
		if boost > 0 then
			p:SetAttribute("Boost", math.max(0, boost - dt))
		end
		p:SetAttribute("Grow", grow)
		local k = math.clamp(grow / S.growTime, 0, 1)
		-- the sprout gets bigger as it grows (redrawn a step at a time, not every frame)
		local shown = p:GetAttribute("Shown") :: number? or 1
		local scale = 1 + 5 * k
		if scale - shown > 0.25 then
			p:SetAttribute("Shown", scale)
			LogService.buildSprout(p, p:GetAttribute("Species") :: string or "oak", scale)
		end
		if k >= 1 then
			local at = p.Position
			local species = p:GetAttribute("Species") :: string or "oak"
			p:Destroy()
			WorldService.grow(species, Vector3.new(at.X, WorldService.heightAt(at.X, at.Z) - 0.05 * M, at.Z))
			remotes.Fx:FireAllClients("reveal", at)
		end
	end
end

function SaplingService.start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.25)
			local now = os.clock()
			local ok, err = pcall(SaplingService.step, now - last)
			if not ok then
				warn("[Timber] saplings: " .. tostring(err))
			end
			last = now
		end
	end)
end

return SaplingService
