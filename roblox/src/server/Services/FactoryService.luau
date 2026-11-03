--!strict
-- The logistics and tree-farm machines, the Godot game's way. While powered:
--   crate     (Crate.gd) empties itself out of the front, the lowest thing first, one every 0.45 s
--   sprinkler (Sprinkler.gd) waters every rooted sapling within 5 m (they grow twice as fast)
--   planter   (Planter.gd) plants a sapling from its hopper in a row in front of it (2 m to 10 m out), every 2 s
--   grabber   (Grabber.gd) lifts what's in front of it (the arrow's tail) over to behind it, every 1.1 s
--   piston    (Piston.gd) pushes its plate out 1 m, shoving what's in front
--   sorter    (Sorter.gd) sends one kind of thing (E while holding it) off to the left; splitter: every other thing
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Builds = require(ReplicatedStorage.Shared.Builds)

local FactoryService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre

local function within(m: Model, off: Vector3, box: Vector3, players: boolean?): { BasePart }
	local size = m:GetAttribute("Size") :: number? or 1
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local roots = {}
	for _, name in { "Loose", "Logs" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(roots, f)
		end
	end
	params.FilterDescendantsInstances = roots
	local out, seen = {}, {}
	for _, p in workspace:GetPartBoundsInBox(m:GetPivot() * CFrame.new(off * M * size), box * M * size, params) do
		local item: BasePart = if p.Parent and p.Parent:IsA("BasePart") then p.Parent :: BasePart else p
		if not seen[item] and item.Parent and not item.Anchored and not item:GetAttribute("HeldBy") then
			seen[item] = true
			table.insert(out, item)
		end
	end
	local _ = players
	return out
end

local function cd(m: Model, dt: number): boolean
	local c = (m:GetAttribute("Cd") :: number? or 0) - dt
	m:SetAttribute("Cd", c)
	return c <= 0
end

-- what kind of thing a loose part is, for the sorter (Godot's Sorter.kind_of)
function FactoryService.kindOf(p: BasePart): string
	local kind = p:GetAttribute("Kind")
	if kind == "ore" then
		return p:GetAttribute("Ore") :: string? or "stone"
	elseif kind == "product" then
		return p:GetAttribute("Product") :: string? or "?"
	elseif p.Name == "Trunk" and p.Parent and p.Parent:GetAttribute("Kind") == "log" then
		return "log"
	end
	return if typeof(kind) == "string" then kind else "?"
end

local function crate(m: Model, dt: number)
	if not cd(m, dt) then
		return
	end
	local low: BasePart? = nil
	for _, b in within(m, Vector3.new(0, 0.55, 0.04), Vector3.new(0.8, 0.9, 0.74)) do
		if not low or b.Position.Y < low.Position.Y then
			low = b
		end
	end
	if low then
		m:SetAttribute("Cd", 0.45)
		local lp = m:GetPivot():PointToObjectSpace(low.Position) / M
		low.AssemblyLinearVelocity = (m:GetPivot().LookVector * 3.4 + Vector3.new(0, 1.1, 0) - m:GetPivot().RightVector * math.clamp(lp.X, -0.3, 0.3) * 2.5) * M
	end
end

local function sprinkler(m: Model, dt: number)
	if not cd(m, dt) then
		return
	end
	m:SetAttribute("Cd", 1.0)
	local loose = workspace:FindFirstChild("Loose")
	for _, s in if loose then loose:GetChildren() else {} do
		if s:IsA("BasePart") and s:GetAttribute("Kind") == "sapling" and s:GetAttribute("Rooted")
			and (s.Position - m:GetPivot().Position).Magnitude <= 5 * M then
			s:SetAttribute("Boost", math.max(s:GetAttribute("Boost") :: number? or 0, 2.0))
		end
	end
end

-- the nearest open patch of ground in front (no tree or sapling within 1.8 m), up to 10 m out
local function freeSpot(m: Model): Vector3?
	local WorldService = require(script.Parent.WorldService) :: any
	local CollectionService = game:GetService("CollectionService")
	for k = 0, 4 do
		local at = m:GetPivot():PointToWorldSpace(Vector3.new(0, 0, -(2 + k * 2)) * M)
		local p = Vector3.new(at.X, WorldService.heightAt(at.X, at.Z), at.Z)
		local clear = true
		for _, t in CollectionService:GetTagged("Tree") do
			local tp = (t :: Model):GetPivot().Position
			if not (t :: Model):GetAttribute("Log") and Vector2.new(tp.X - p.X, tp.Z - p.Z).Magnitude < 1.8 * M then
				clear = false
				break
			end
		end
		local loose = workspace:FindFirstChild("Loose")
		for _, s in if clear and loose then loose:GetChildren() else {} do
			if s:IsA("BasePart") and s:GetAttribute("Kind") == "sapling" and s:GetAttribute("Rooted") and Vector2.new(s.Position.X - p.X, s.Position.Z - p.Z).Magnitude < 1.8 * M then
				clear = false
				break
			end
		end
		if clear then
			return p
		end
	end
	return nil
end

local function planter(m: Model, dt: number)
	if not cd(m, dt) then
		return
	end
	for _, b in within(m, Vector3.new(0, 0.95, 0), Vector3.new(0.7, 0.5, 0.7)) do
		if b:GetAttribute("Kind") == "sapling" and not b:GetAttribute("Rooted") then
			local spot = freeSpot(m)
			if not spot then
				return
			end
			m:SetAttribute("Cd", 2.0)
			b.AssemblyLinearVelocity = Vector3.zero
			b.Anchored = true
			b.CFrame = CFrame.new(spot + Vector3.new(0, 0.04 * M, 0)) * CFrame.Angles(0, 0, math.rad(90))
			b:SetAttribute("Rooted", true)
			remotes.Fx:FireAllClients("thud", m:GetPivot().Position, 1.3, -4)
			return
		end
	end
end

local function grabber(m: Model, dt: number)
	if m:GetAttribute("Carrying") or not cd(m, dt) then
		return
	end
	for _, b in within(m, Vector3.new(0, 0.5, -1.0), Vector3.new(0.9, 1.0, 0.9)) do
		if b:GetAttribute("Kind") == "basket" then
			continue
		end
		local log = b.Parent
		if b.Name == "Trunk" and log and log:GetAttribute("Kind") == "log" and ((log:GetAttribute("Bands") :: number? or 99) * Config.Tree.bandH > 2.2) then
			continue
		end
		m:SetAttribute("Cd", 1.1)
		m:SetAttribute("Carrying", true)
		local from = b.Position
		local to = m:GetPivot():PointToWorldSpace(Vector3.new(0, 0.75, 1.0) * M)
		local top = m:GetPivot():PointToWorldSpace(Vector3.new(0, 1.6, 0) * M)
		b.Anchored = true
		task.spawn(function()
			local t = 0
			while t < 0.55 do
				t += task.wait()
				local k = math.clamp(t / 0.55, 0, 1)
				k = 0.5 - math.cos(k * math.pi) / 2
				if b.Parent then
					b.CFrame = CFrame.new(from:Lerp(top, k):Lerp(top:Lerp(to, k), k)) * (b.CFrame - b.Position)
				end
			end
			if b.Parent then
				b.Anchored = false
				b.AssemblyLinearVelocity = Vector3.zero
			end
			m:SetAttribute("Carrying", nil)
		end)
		return
	end
end

local function piston(m: Model, dt: number, on: boolean)
	local ext = m:GetAttribute("Ext") :: number? or 0
	local target = if on then 1 else 0
	if ext == target then
		return
	end
	ext = if on then math.min(1, ext + dt * 5) else math.max(0, ext - dt * 2)
	local size = m:GetAttribute("Size") :: number? or 1
	local delta = (ext - (m:GetAttribute("Ext") :: number? or 0)) * M * size
	m:SetAttribute("Ext", ext)
	local fwd = m:GetPivot().LookVector
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Group") == "Plate" then
			p.CFrame = p.CFrame + fwd * delta
		end
	end
	if on then
		-- what's in front of the plate gets shoved
		for _, b in within(m, Vector3.new(0, 0.4, -0.6 - ext), Vector3.new(0.8, 0.8, 0.5)) do
			b.AssemblyLinearVelocity = fwd * 5 * M + Vector3.new(0, b.AssemblyLinearVelocity.Y, 0)
		end
	end
end

local function sorter(m: Model, id: string)
	local left = -m:GetPivot().RightVector
	local seen = m:GetAttribute("Seen") :: string? or ""
	local now = {}
	for _, b in within(m, Vector3.new(0, 0.25, 0), Vector3.new(0.9, 0.5, 0.9)) do
		local key = b:GetAttribute("Uid") :: string? or ""
		if key == "" then
			key = tostring(math.random(1, 2 ^ 30))
			b:SetAttribute("Uid", key)
		end
		local go: boolean
		local was = string.match(seen, key .. "=(%a)")
		if was then
			go = was == "y"
		elseif id == "splitter" then
			go = m:GetAttribute("Flip") == true
			m:SetAttribute("Flip", not go)
		else
			local filter = m:GetAttribute("Filter") :: string? or ""
			go = filter ~= "" and FactoryService.kindOf(b) == filter
		end
		table.insert(now, key .. "=" .. (if go then "y" else "n"))
		if go then
			local v = b.AssemblyLinearVelocity
			b.AssemblyLinearVelocity = Vector3.new(left.X * 1.8 * M, v.Y, left.Z * 1.8 * M)
		end
	end
	m:SetAttribute("Seen", table.concat(now, ","))
end

-- E on a sorter while holding something: sort that kind off to the left; with empty hands, clear it
function FactoryService.setFilter(m: Model, held: BasePart?)
	if held then
		m:SetAttribute("Filter", FactoryService.kindOf(held))
		remotes.Fx:FireAllClients("clink", m:GetPivot().Position, 1.3, -4)
	elseif (m:GetAttribute("Filter") :: string? or "") ~= "" then
		m:SetAttribute("Filter", "")
		remotes.Fx:FireAllClients("click", m:GetPivot().Position, 0.7, -4)
	end
end

function FactoryService.step(dt: number)
	local f = workspace:FindFirstChild("Builds")
	for _, m in if f then f:GetChildren() else {} do
		if not m:IsA("Model") then
			continue
		end
		local id = m:GetAttribute("Build") :: string
		local on = m:GetAttribute("Powered") == true
		if id == "piston" then
			piston(m, dt, on)
		elseif not on then
			continue
		elseif id == "crate" then
			crate(m, dt)
		elseif id == "sprinkler" then
			sprinkler(m, dt)
		elseif id == "planter" then
			planter(m, dt)
		elseif id == "grabber" then
			grabber(m, dt)
		elseif id == "sorter" or id == "splitter" then
			sorter(m, id)
		end
	end
	local _ = Builds
end

function FactoryService.start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.05)
			local now = os.clock()
			local ok, err = pcall(FactoryService.step, now - last)
			if not ok then
				warn("[Timber] factory: " .. tostring(err))
			end
			last = now
		end
	end)
end

return FactoryService
