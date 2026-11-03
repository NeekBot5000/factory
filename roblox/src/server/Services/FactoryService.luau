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

-- ------------------------------------------------------------------ machines you put a tool in
-- the tree feller takes a saw, the drill rig a drill (Godot's hand_over_tool: it leaves your tool bar until you take
-- it back out with empty hands)
local SAWS = { saw = true, chainsaw = true, crosscut = true }
local DRILLS = { rock_drill = { max = 12, tier = 1, rate = 0.12 }, core_drill = { max = 30, tier = 2, rate = 0.2 } }
FactoryService.DRILLS = DRILLS
local drilled: { [string]: number } = {}        -- (Godot's Mining.drilled: a spot stays drilled out)

function FactoryService.handOver(player: Player, m: Model): boolean
	local ToolService = require(script.Parent.ToolService) :: any
	local DataService = require(script.Parent.DataService) :: any
	local id = m:GetAttribute("Build")
	local held = m:GetAttribute("Holds") :: string?
	local tool = ToolService.current(player)
	local fits = if id == "feller" then SAWS[tool] ~= nil else DRILLS[tool] ~= nil
	local data = DataService.get(player)
	if not data then
		return false
	end
	if not held and fits then
		m:SetAttribute("Holds", tool)
		data.dropped = data.dropped or {}
		data.dropped[tool] = true
		ToolService.equip(player, "hands")
		DataService.publish(player)
		remotes.Fx:FireAllClients("clink", m:GetPivot().Position, 0.8, -2)
		return true
	elseif held and tool == "hands" then
		m:SetAttribute("Holds", nil)
		if data.dropped then
			data.dropped[held] = nil
		end
		DataService.publish(player)
		ToolService.equip(player, held)
		remotes.Fx:FireAllClients("pickup", m:GetPivot().Position, 1.0, -2)
		return true
	end
	return false
end

local function feller(m: Model, dt: number)
	local saw = m:GetAttribute("Holds") :: string?
	if not saw then
		return
	end
	-- the nearest standing tree in front of it (Godot's _target: 0.3-2.6 m out, within 0.9 m to the side)
	local CollectionService = game:GetService("CollectionService")
	local best, bd = nil, math.huge
	for _, t in CollectionService:GetTagged("Tree") do
		local tr = t :: Model
		if tr:GetAttribute("Log") or tr:GetAttribute("Felled") or (tr:GetAttribute("Bands") :: number? or 0) < 4 then
			continue
		end
		local lp = m:GetPivot():PointToObjectSpace(tr:GetPivot().Position) / M
		if lp.Z < -2.6 or lp.Z > -0.3 or math.abs(lp.X) > 0.9 then
			continue
		end
		if -lp.Z < bd then
			bd = -lp.Z
			best = tr
		end
	end
	if not best then
		m:SetAttribute("Progress", 0)
		return
	end
	local d = (Config.Tools :: any)[saw]
	if best:GetAttribute("Giant") and not d.big and saw ~= "chainsaw" then
		return
	end
	local radius = (best:GetAttribute("Radius") :: number? or 1.14) / M
	local p = (m:GetAttribute("Progress") :: number? or 0) + dt / (Config.Saw.treeTime * 1.5 * (radius / 0.38)) * (d.speed or 1)
	if math.random() < dt * 8 then
		remotes.Fx:FireAllClients("saw", best:GetPivot().Position, 1.1, -4)
	end
	if p >= 1 then
		p = 0
		local LogService = require(script.Parent.LogService) :: any
		local owner = game:GetService("Players"):GetPlayerByUserId(m:GetAttribute("Owner") :: number)
		local log = LogService.fell(best, 2, m:GetPivot().LookVector, owner)
		if log and d.clean then
			log:SetAttribute("Clean", true)
		end
		remotes.Fx:FireAllClients("timber", best:GetPivot().Position, 1.0, 2)
	end
	m:SetAttribute("Progress", p)
end

local function drillRig(m: Model, dt: number)
	local tool = m:GetAttribute("Holds") :: string?
	local d = tool and DRILLS[tool]
	if not d then
		return
	end
	local at = m:GetPivot().Position
	local key = string.format("%d,%d", math.round(at.X / M), math.round(at.Z / M))
	local depth = math.max(m:GetAttribute("Depth") :: number? or 0, drilled[key] or 0)
	if depth >= d.max then
		m:SetAttribute("Depth", depth)
		return
	end
	local nextAt = (math.floor(depth / 0.25) + 1) * 0.25
	depth = math.min(d.max, depth + d.rate * dt)
	drilled[key] = math.max(depth, drilled[key] or 0)
	m:SetAttribute("Depth", depth)
	if depth >= nextAt then
		local Mining = require(ReplicatedStorage.Shared.Mining) :: any
		local MiningService = require(script.Parent.MiningService) :: any
		local kind = Mining.roll(at.X, at.Z, depth, d.tier)
		MiningService.chunk(kind, 0.11 + math.random() * 0.04, m:GetPivot():PointToWorldSpace(Vector3.new(math.random() * 0.2 - 0.1, 0.75, -0.75) * M),
			(m:GetPivot().LookVector * 1.4 + Vector3.new(0, 0.6, 0)) * M, m:GetAttribute("Owner") :: number)
	end
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
		elseif id == "feller" then
			feller(m, dt)
		elseif id == "drill_rig" then
			drillRig(m, dt)
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
