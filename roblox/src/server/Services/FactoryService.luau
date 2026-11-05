--!strict
-- The logistics and tree-farm machines, the Godot game's way. While powered:
--   crate     (Crate.gd) empties itself out of the front, the lowest thing first, one every 0.45 s
--   sprinkler (Sprinkler.gd) waters every rooted sapling within 5 m (they grow twice as fast)
--   planter   (Planter.gd) plants a sapling from its hopper in a row in front of it (2 m to 10 m out), every 2 s
--   grabber   (Grabber.gd) lifts what's in front of it (the arrow's tail) over to behind it, every 1.1 s
--   piston    (Piston.gd) pushes its plate out 1 m, shoving what's in front
--   sorter    (Sorter.gd) sends one kind of thing (E while holding it) off to the left; splitter: every other thing
--   feller    (Machines.gd) fells the tree in front of it with the saw handed to it
--   drill_rig (Machines.gd) bores down with the drill handed to it, throwing out what it digs
--   rotator   (Rotator.gd) spins what's stuck on it (the hammer sticks it on and lets go)
--   charger   (Charger.gd) charges the battery cells dropped into it
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Physics = require(script.Parent.Physics)
local RunService = game:GetService("RunService")
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

FactoryService.within = within

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

-- what's in a storage crate (Godot's Crate.contents)
function FactoryService.contents(m: Model): { BasePart }
	return within(m, Vector3.new(0, 0.55, 0.04), Vector3.new(0.8, 0.9, 0.74))
end

-- the charger (Charger.gd): battery cells in its cradle charge up, a tenth of a full charge a second
local function charger(m: Model, dt: number)
	local n = 0
	for _, b in within(m, Vector3.new(0, 0.75, 0), Vector3.new(0.7, 0.5, 0.7)) do
		if b:GetAttribute("Product") == "battery_cell" then
			n += 1
			b:SetAttribute("Charge", math.min(1, (b:GetAttribute("Charge") :: number? or 0) + 0.1 * dt))
		end
	end
	if m:GetAttribute("Cells") ~= n then
		m:SetAttribute("Cells", n)
	end
end

local function crate(m: Model, dt: number)
	if not cd(m, dt) then
		return
	end
	local low: BasePart? = nil
	for _, b in FactoryService.contents(m) do
		if not low or b.Position.Y < low.Position.Y then
			low = b
		end
	end
	if low then
		m:SetAttribute("Cd", 0.45)
		local lp = m:GetPivot():PointToObjectSpace(low.Position) / M
		Physics.take(low :: any)
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
			Physics.take(b :: any)
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
		Physics.take(b)      -- (and the server keeps it once it's put down behind)
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
			Physics.take(b :: any)
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
			Physics.take(b :: any)
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

-- the rotator (Rotator.gd): a powered turntable. Hammer it (or what's on it) to stick everything on the table to it;
-- hammer it again to let go. While powered it spins (1.2 rad/s), carrying what's stuck round with it.
FactoryService.SPIN = 1.2
-- (kept by the rotator's Uid, and what's stuck as a list: the same part or model reached two ways isn't always the
-- same table key in the test harness)
-- (a stuck thing's clamp is the Uid of the piston pinning it to the table, or nil if the hammer stuck it on)
type Stuck = { p: BasePart, off: CFrame, clamp: string? }
type Table = { m: Model, parts: { { p: BasePart, off: CFrame } }, stuck: { Stuck }, speed: number }
local tables: { [string]: Table } = {}      -- (taken-down rotators are dropped in step)

local function hub(m: Model, angle: number): CFrame
	local size = m:GetAttribute("Size") :: number? or 1
	return m:GetPivot() * CFrame.new(0, 0.33 * M * size, 0) * CFrame.Angles(0, angle, 0)
end

local function tableOf(m: Model): Table
	local uid = m:GetAttribute("Uid") :: string? or "?"
	local t = tables[uid]
	if not t then
		-- (the table's parts are where the model was built, at angle 0, until it first turns)
		local h = hub(m, 0)
		local nt: Table = { m = m, parts = {}, stuck = {}, speed = 0 }
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p:GetAttribute("Group") == "Table" then
				table.insert(nt.parts, { p = p, off = h:ToObjectSpace(p.CFrame) })
			end
		end
		tables[uid] = nt
		t = nt
	end
	return t :: Table
end

-- loose things resting on the table
local function onTable(m: Model): { BasePart }
	return within(m, Vector3.new(0, 0.93, 0), Vector3.new(1.24, 1.2, 1.24))
end

-- the rotator something is sitting on or stuck to, if any
function FactoryService.rotatorOf(p: BasePart): Model?
	local f = workspace:FindFirstChild("Builds")
	local stuckTo = p:GetAttribute("Stuck")
	for _, m in if f then f:GetChildren() else {} do
		if m:IsA("Model") and m:GetAttribute("Build") == "rotator" then
			if stuckTo and stuckTo == m:GetAttribute("Uid") then
				return m
			end
			for _, q in onTable(m) do
				if q == p then
					return m
				end
			end
		end
	end
	return nil
end

local function letGo(p: BasePart)
	if p.Parent then
		p.Anchored = false
		p:SetAttribute("Stuck", nil)
	end
end

-- the hammer on a rotator: stick what's on it, or let go (things a piston is clamping stay clamped either way).
-- Returns how many are stuck now.
local function stick(m: Model, t: Table, p: BasePart, clamp: string?)
	local h = hub(m, m:GetAttribute("Angle") :: number? or 0)
	p.Anchored = true
	p.AssemblyLinearVelocity = Vector3.zero
	p:SetAttribute("Stuck", m:GetAttribute("Uid"))
	table.insert(t.stuck, { p = p, off = h:ToObjectSpace(p.CFrame), clamp = clamp })
end

local function hammered(t: Table): number
	local n = 0
	for _, s in t.stuck do
		if not s.clamp then
			n += 1
		end
	end
	return n
end

function FactoryService.hammer(m: Model): number
	local t = tableOf(m)
	local at = m:GetPivot().Position
	if hammered(t) > 0 then
		for i = #t.stuck, 1, -1 do
			if not t.stuck[i].clamp then
				letGo(t.stuck[i].p)
				table.remove(t.stuck, i)
			end
		end
		m:SetAttribute("Stuck", false)
		remotes.Fx:FireAllClients("clink", at, 1.2, 0)
		return 0
	end
	for _, p in onTable(m) do
		stick(m, t, p, nil)
	end
	if hammered(t) > 0 then
		m:SetAttribute("Stuck", true)
		remotes.Fx:FireAllClients("clink", at, 0.8, 0)
	else
		remotes.Fx:FireAllClients("thud", at, 1.4, -6)
	end
	return #t.stuck
end

-- pistons pushed out against the table pin what's between them to it; when a piston pulls back, it lets go
local function checkClamps(m: Model, t: Table)
	local f = workspace:FindFirstChild("Builds")
	local pistons: { [string]: Model } = {}
	for _, ps in if f then f:GetChildren() else {} do
		if ps:IsA("Model") and ps:GetAttribute("Build") == "piston" and ps:GetAttribute("Powered") == true and (ps:GetAttribute("Ext") :: number? or 0) > 0.05 then
			pistons[ps:GetAttribute("Uid") :: string? or "?"] = ps
		end
	end
	for i = #t.stuck, 1, -1 do
		local c = t.stuck[i].clamp
		if c and not pistons[c] then
			letGo(t.stuck[i].p)
			table.remove(t.stuck, i)
		end
	end
	local h = hub(m, m:GetAttribute("Angle") :: number? or 0)
	local on: { BasePart }? = nil
	for uid, ps in pistons do
		if (ps:GetPivot().Position - h.Position).Magnitude > 3.5 * M then
			continue
		end
		on = on or onTable(m)
		local ext = ps:GetAttribute("Ext") :: number? or 0
		for _, b in within(ps, Vector3.new(0, 0.4, -0.55 - ext), Vector3.new(0.9, 0.9, 0.25)) do
			-- pinned: right up against the table (not just somewhere in front of it)
			local onIt = false
			for _, q in on :: { BasePart } do
				if q == b then
					onIt = true
				end
			end
			if onIt and not b:GetAttribute("Stuck") and h:PointToObjectSpace(b.CFrame.Position).Y < 0.4 * M then
				stick(m, t, b, uid)
				remotes.Fx:FireAllClients("clink", b.CFrame.Position, 0.7, -6)
			end
		end
	end
end

local function rotator(m: Model, dt: number, on: boolean)
	local t = tableOf(m)
	checkClamps(m, t)      -- (every tick: a piston closes fast, and has to catch what it's pinning)
	local re = m:GetAttribute("Restick") :: any
	if re then
		-- after loading: what was stuck is back on the table - stick it again, once it has had a moment to land
		re = if typeof(re) == "number" then re - dt else 1.0
		if re <= 0 then
			m:SetAttribute("Restick", nil)
			if #onTable(m) > 0 then
				FactoryService.hammer(m)
			end
		else
			m:SetAttribute("Restick", re)
		end
	end
	t.speed = if on then math.min(FactoryService.SPIN, t.speed + dt * 1.5) else math.max(0, t.speed - dt * 1.5)
	if t.speed <= 0 then
		return
	end
	local angle = ((m:GetAttribute("Angle") :: number? or 0) + t.speed * dt) % (2 * math.pi)
	m:SetAttribute("Angle", angle)
	local h = hub(m, angle)
	for _, s in t.parts do
		s.p.CFrame = h * s.off
	end
	for i = #t.stuck, 1, -1 do
		local s = t.stuck[i]
		-- gone: sold, or picked up
		if not s.p.Parent or s.p:GetAttribute("HeldBy") or not s.p:GetAttribute("Stuck") then
			table.remove(t.stuck, i)
			if hammered(t) == 0 then
				m:SetAttribute("Stuck", false)
			end
			continue
		end
		s.p.CFrame = h * s.off
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
		elseif id == "rotator" then
			rotator(m, dt, on)
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
		elseif id == "charger" then
			charger(m, dt)
		end
	end
	-- a rotator that was taken down lets go of what was stuck to it
	for uid, t in tables do
		if not t.m.Parent then
			for _, s in t.stuck do
				letGo(s.p)
			end
			tables[uid] = nil
		end
	end
	local _ = Builds
end

-- the hammer swung at a rotator, or at something sitting on (or stuck to) one (RailService's Hammer handler asks
-- here first). True if it was one.
function FactoryService.onHammer(player: Player, target: BasePart): boolean
	local m = target:FindFirstAncestorWhichIsA("Model")
	while m and m:GetAttribute("Kind") ~= "build" do
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	if not (m and m:GetAttribute("Build") == "rotator") then
		local item: BasePart = if target.Parent and target.Parent:IsA("BasePart") then target.Parent :: BasePart else target
		m = FactoryService.rotatorOf(item)
	end
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if m and head and (head.CFrame.Position - m:GetPivot().Position).Magnitude < 6 * M then
		local n = FactoryService.hammer(m)
		if n > 0 then
			remotes.Notify:FireClient(player, string.format("Stuck %d to the rotator", n), "bfeaff")
		end
		return true
	end
	return false
end

function FactoryService.start()
	task.spawn(function()
		local last = os.clock()
		while true do
			RunService.Heartbeat:Wait()      -- (every frame: carts, drones and turntables move smoothly)
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
