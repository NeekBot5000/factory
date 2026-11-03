--!strict
-- Machines and power, the Godot game's way (Circuit.gd, Machine.gd, Wire.gd and the machines):
--   * power starts at every live source - a crank you've wound (15 s a wind, up to 2 minutes), a windmill while the
--     wind blows, a generator with fuel in it (drop bark, leaves or wood in its hopper), a battery that has charge
--     when nothing else powers its network - and flows along wires and between belts that touch, through any machine
--     that conducts (a lever that's off, or a button that isn't pressed, stops it there)
--   * a lamp lights, a bell rings, a belt carries what's on it (1.3 m/s), a truck caller sends the log truck
--   * the Wire Spool: click one machine, then another, to run a wire between them (up to 14 m); again to take it down.
--     A wire glows while power flows through it.
-- State lives in attributes on each build, so it's saved with it (BuildService) and clients can show it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Builds = require(ReplicatedStorage.Shared.Builds)
local ToolService = require(script.Parent.ToolService)

local CircuitService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local TICK = 0.05
local WIRE_MAX = 14 * M
CircuitService.CRANK = { per = 15, max = 120 }
CircuitService.GEN_MAX = 600
CircuitService.BATTERY_MAX = 180
CircuitService.BUTTON_HOLD = 1.5
CircuitService.BELT_SPEED = 1.3
CircuitService.MIN_WIND = 0.35

-- where a wire plugs into each machine (Godot's terminal(), metres, around the machine's origin)
local TERMINAL = {
	crank = { 0, 0.98, 0 }, lever = { -0.18, 0.2, 0 }, button = { 0, 0.6, -0.08 }, lamp = { 0, 0.35, 0.12 }, bell = { 0, 0.35, 0.12 },
	windmill = { 0.3, 0.35, 0.3 }, gate_diode = { 0, 0.22, 0 }, gate_and = { 0, 0.22, 0 }, gate_not = { 0, 0.22, 0 },
	gate_timer = { 0, 0.22, 0 }, gate_delay = { 0, 0.22, 0 }, gate_latch = { 0, 0.22, 0 }, gate_counter = { 0, 0.22, 0 }, charge = { 0, 0.15, -0.14 }, generator = { 0.36, 0.45, 0.3 }, battery = { 0, 0.82, 0 }, truck_caller = { 0, 0.3, 0.2 },
}

function CircuitService.wind(): number
	local t = os.clock()
	return math.clamp(0.55 + 0.3 * math.sin(t / 37) + 0.2 * math.sin(t / 11 + 1) + 0.08 * math.sin(t / 3.1), 0, 1)
end

local function machines(): { Model }
	local out = {}
	local f = workspace:FindFirstChild("Builds")
	for _, m in if f then f:GetChildren() else {} do
		local def = m:IsA("Model") and Builds.def(m:GetAttribute("Build") :: string)
		if (def and def.machine) or m:GetAttribute("Build") == "charge" then
			table.insert(out, m :: Model)
		end
	end
	return out
end

local function isCart(m: Model): boolean
	return string.sub(m:GetAttribute("Build") :: string? or "", 1, 9) == "minecart_"
end

function CircuitService.terminal(m: Model): Vector3
	local id = m:GetAttribute("Build") :: string
	local t = TERMINAL[id] or { 0, 0.4, 0 }
	if isCart(m) then
		t = { 0.3, 0.5, (tonumber(string.sub(id, 10)) or 1) - 0.45 }
	end
	local size = m:GetAttribute("Size") :: number? or 1
	return m:GetPivot():PointToWorldSpace(Vector3.new(t[1], t[2], t[3]) * M * size)
end

local function isSource(m: Model): boolean
	local id = m:GetAttribute("Build")
	if isCart(m) then
		-- (Godot's Minecart.is_source: a charged battery cell in its cradle)
		return (m:GetAttribute("Cell") :: number? or 0) > 0
	elseif id == "crank" then
		return (m:GetAttribute("Charge") :: number? or 0) > 0
	elseif id == "windmill" then
		return CircuitService.wind() >= CircuitService.MIN_WIND
	elseif id == "generator" then
		return (m:GetAttribute("Fuel") :: number? or 0) > 0
	elseif id == "battery" then
		return m:GetAttribute("Feeding") == true and (m:GetAttribute("Charge") :: number? or 0) > 0
	elseif id == "receiver" then
		-- (Godot's Wireless: a receiver gives power while a powered transmitter is on its channel)
		local ch = m:GetAttribute("Channel") or 0
		local f = workspace:FindFirstChild("Builds")
		for _, t in if f then f:GetChildren() else {} do
			if t:GetAttribute("Build") == "transmitter" and (t:GetAttribute("Channel") or 0) == ch and t:GetAttribute("Powered") == true then
				return true
			end
		end
	end
	return false
end

local function isGate(m: Model): boolean
	return string.sub(m:GetAttribute("Build") :: string? or "", 1, 5) == "gate_"
end

local function conducts(m: Model): boolean
	local id = m:GetAttribute("Build")
	if isGate(m) or id == "transmitter" or id == "receiver" or isCart(m) or string.sub(id :: string? or "", 1, 6) == "drone_" and id ~= "drone_pad" then
		return false          -- (a logic block only lets power out of its front, and only when its logic says so)
	end
	if id == "lever" then
		return m:GetAttribute("On") == true
	elseif id == "button" then
		return (m:GetAttribute("Pressed") :: number? or 0) > 0
	elseif id == "drill_rig" then
		local tool = m:GetAttribute("Holds") :: string?
		local max = if tool == "rock_drill" then 12 elseif tool == "core_drill" then 30 else 0
		return tool ~= nil and (m:GetAttribute("Depth") :: number? or 0) >= max
	elseif id == "pressure_plate" or id == "item_sensor" or id == "level_sensor" or id == "cart_sensor" then
		return m:GetAttribute("Sensing") == true
	end
	return true
end

-- the sensors (Godot's Sensor): a pressure plate with something heavy (or someone) on it, an item sensor with
-- something loose in the grid square in front of it
CircuitService.LEVELS = { 5, 10, 20, 30 }
local function sense(m: Model)
	local id = m:GetAttribute("Build")
	if id == "cart_sensor" then
		-- a minecart on the rail in front of it (a station)
		local Rail = require(ReplicatedStorage.Shared.Rail) :: any
		local on = (require(script.Parent.RailService) :: any).cartAt(Rail.cellOf(m:GetPivot():PointToWorldSpace(Vector3.new(0, 0, -1) * M))) ~= nil
		if m:GetAttribute("Sensing") ~= on then
			m:SetAttribute("Sensing", on)
			remotes.Fx:FireAllClients("click", m:GetPivot().Position, if on then 1.2 else 0.8, -8)
		end
		return
	end
	if id == "level_sensor" then
		-- the storage crate in front of it holds at least N things (Godot: a ray 0.1-1.1 m out at 0.4 m up)
		local n = -1
		local f = workspace:FindFirstChild("Builds")
		for _, c in if f then f:GetChildren() else {} do
			if c:IsA("Model") and c:GetAttribute("Build") == "crate" then
				local lp = m:GetPivot():PointToObjectSpace(c:GetPivot().Position) / M
				if lp.Z < -0.1 and lp.Z > -1.5 and math.abs(lp.X) < 0.45 and math.abs(lp.Y) < 0.6 then
					n = #(require(script.Parent.FactoryService) :: any).contents(c)
					break
				end
			end
		end
		if m:GetAttribute("Has") ~= n then
			m:SetAttribute("Has", n)
		end
		local on = n >= CircuitService.LEVELS[(m:GetAttribute("Setting") :: number? or 1) + 1]
		if m:GetAttribute("Sensing") ~= on then
			m:SetAttribute("Sensing", on)
			remotes.Fx:FireAllClients("click", m:GetPivot().Position, if on then 1.2 else 0.8, -8)
		end
		return
	end
	if id ~= "pressure_plate" and id ~= "item_sensor" then
		return
	end
	local size = m:GetAttribute("Size") :: number? or 1
	local off, box = if id == "pressure_plate" then Vector3.new(0, 0.2, 0) else Vector3.new(0, 0.5, -0.9), if id == "pressure_plate" then Vector3.new(0.8, 0.3, 0.8) else Vector3.new(0.9, 1.0, 0.8)
	local cf = m:GetPivot() * CFrame.new(off * M * size)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local roots = {}
	for _, name in { "Loose", "Logs" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(roots, f)
		end
	end
	if id == "pressure_plate" then
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(roots, p.Character)
			end
		end
	end
	params.FilterDescendantsInstances = roots
	local on = #workspace:GetPartBoundsInBox(cf, box * M * size, params) > 0
	if m:GetAttribute("Sensing") ~= on then
		m:SetAttribute("Sensing", on)
	end
end

-- ------------------------------------------------------------------ wires
local function wireFolder(): Instance
	local f = workspace:FindFirstChild("Wires")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Wires"
		f.Parent = workspace
	end
	return f :: Instance
end

local function byUid(uid: string): Model?
	local f = workspace:FindFirstChild("Builds")
	for _, m in if f then f:GetChildren() else {} do
		if m:GetAttribute("Uid") == uid then
			return m :: Model
		end
	end
	return nil
end

-- the cable: a copper beam between the two terminals, sagging a little (Godot's Wire), glowing when live
local function drawWire(w: Instance, a: Model, b: Model)
	for _, c in w:GetChildren() do
		c:Destroy()
	end
	local holder = Instance.new("Part")
	holder.Name = "Ends"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.1
	holder.CFrame = CFrame.new(CircuitService.terminal(a))
	holder.Parent = w
	local a0 = Instance.new("Attachment")
	a0.WorldPosition = CircuitService.terminal(a)
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.WorldPosition = CircuitService.terminal(b)
	a1.Parent = holder
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.04 * M
	beam.Width1 = 0.04 * M
	beam.Color = ColorSequence.new(Color3.fromHex("b8622c"))
	beam.LightEmission = 0
	beam.FaceCamera = true
	beam.Segments = 10
	beam.CurveSize0 = -0.4 * M
	beam.CurveSize1 = 0.4 * M
	beam.Parent = holder
end

function CircuitService.wired(a: Model, b: Model): Instance?
	local ua, ub = a:GetAttribute("Uid"), b:GetAttribute("Uid")
	for _, w in wireFolder():GetChildren() do
		local x, y = w:GetAttribute("A"), w:GetAttribute("B")
		if (x == ua and y == ub) or (x == ub and y == ua) then
			return w
		end
	end
	return nil
end

-- connects two machines, or takes the wire down if they're already connected: "added", "removed" or a reason
function CircuitService.toggle(a: Model, b: Model): string
	if a == b then
		return ""
	end
	local old = CircuitService.wired(a, b)
	if old then
		old:Destroy()
		return "removed"
	end
	if (CircuitService.terminal(a) - CircuitService.terminal(b)).Magnitude > WIRE_MAX then
		return "far"
	end
	local w = Instance.new("Folder")
	w.Name = "Wire"
	w:SetAttribute("A", a:GetAttribute("Uid"))
	w:SetAttribute("B", b:GetAttribute("Uid"))
	w:SetAttribute("Owner", a:GetAttribute("Owner"))
	drawWire(w, a, b)
	w.Parent = wireFolder()
	return "added"
end

-- ------------------------------------------------------------------ belts
local function beltEnds(m: Model): (Vector3, Vector3)
	local cf, size = m:GetBoundingBox()
	local fwd = m:GetPivot().LookVector
	local run = math.max(size.X, size.Z) * 0.5
	return cf.Position - fwd * run, cf.Position + fwd * run
end

local function segDist(p: Vector3, s0: Vector3, s1: Vector3): number
	local d = s1 - s0
	local t = math.clamp((p - s0):Dot(d) / math.max(d:Dot(d), 0.0001), 0, 1)
	return (p - (s0 + d * t)).Magnitude
end

local function touches(a: Model, b: Model): boolean
	local a0, a1 = beltEnds(a)
	local b0, b1 = beltEnds(b)
	local lim = 0.56 * M
	return segDist(a0, b0, b1) < lim or segDist(a1, b0, b1) < lim or segDist(b0, a0, a1) < lim or segDist(b1, a0, a1) < lim
end

local function isBelt(m: Model): boolean
	local id = m:GetAttribute("Build")
	return id == "conveyor" or id == "ramp" or id == "sorter" or id == "splitter"
end

-- ------------------------------------------------------------------ logic blocks (Godot's Gate)
-- back: the power it passes on; sides: control (relays) or supply (latch, counter); front: the only way out
local PULSE = 0.5
local TIMER_STEPS, DELAY_STEPS, COUNT_STEPS = { 1, 2, 4, 8 }, { 0.5, 1, 2, 4 }, { 2, 3, 5, 10 }

function CircuitService.sideOf(g: Model, other: Model): string
	local lp = g:GetPivot():PointToObjectSpace(CircuitService.terminal(other)) / M
	if lp.Z < -0.3 and math.abs(lp.Z) >= math.abs(lp.X) * 0.7 then
		return "front"
	end
	if math.abs(lp.X) > math.abs(lp.Z) then
		return "side"
	end
	return if lp.Z >= 0 then "back" else "front"
end

local function gateMode(g: Model): string
	return string.sub(g:GetAttribute("Build") :: string, 6)
end

local function num(m: Model, k: string): number
	return m:GetAttribute(k) :: number? or 0
end

local function wouldPass(g: Model, fed: { back: boolean, side: boolean }): boolean
	local mode, back, side = gateMode(g), fed.back, fed.side
	local setting = num(g, "Setting") + 1
	if mode == "diode" then
		return back
	elseif mode == "and" then
		return back and side
	elseif mode == "not" then
		return back and not side
	elseif mode == "timer" then
		return back and num(g, "Clock") < PULSE
	elseif mode == "delay" then
		local d = DELAY_STEPS[setting]
		return (back and num(g, "Held") >= d) or (not back and num(g, "Held") >= d and num(g, "Released") < d)
	elseif mode == "latch" then
		return side and g:GetAttribute("LatchOn") == true
	elseif mode == "counter" then
		return side and num(g, "Pulse") > 0
	end
	return false
end

local function gateStep(g: Model, fed: { back: boolean, side: boolean }, dt: number)
	local mode, back = gateMode(g), fed.back
	local setting = num(g, "Setting") + 1
	if mode == "timer" then
		g:SetAttribute("Clock", (num(g, "Clock") + dt) % TIMER_STEPS[setting])
	elseif mode == "delay" then
		if back then
			g:SetAttribute("Held", num(g, "Held") + dt)
			g:SetAttribute("Released", 0)
		else
			g:SetAttribute("Released", num(g, "Released") + dt)
			if num(g, "Released") >= DELAY_STEPS[setting] then
				g:SetAttribute("Held", 0)
			end
		end
	elseif mode == "latch" then
		if back and not g:GetAttribute("BackWas") then
			g:SetAttribute("LatchOn", not g:GetAttribute("LatchOn"))
			remotes.Fx:FireAllClients("click", g:GetPivot().Position, if g:GetAttribute("LatchOn") then 1.3 else 0.9, -6)
		end
	elseif mode == "counter" then
		g:SetAttribute("Pulse", math.max(0, num(g, "Pulse") - dt))
		if back and not g:GetAttribute("BackWas") then
			local c = num(g, "Count") + 1
			if c >= COUNT_STEPS[setting] then
				c = 0
				g:SetAttribute("Pulse", 1.0)
			end
			g:SetAttribute("Count", c)
		end
	end
	g:SetAttribute("BackWas", back)
end

-- ------------------------------------------------------------------ the tick
-- Spreads power from every source (Godot's _solve). Logic blocks only let it out of their front, and only when their
-- logic says so; since that depends on what reaches their inputs, it settles over a few rounds.
local function solve(list: { Model }, links: { [Model]: { Model } }): ({ [Model]: boolean }, { [Model]: { back: boolean, side: boolean } })
	local gates = {}
	for _, m in list do
		if isGate(m) then
			table.insert(gates, m)
		end
	end
	local live: { [Model]: boolean } = {}
	local fed: { [Model]: { back: boolean, side: boolean } } = {}
	for _ = 1, 8 do
		live, fed = {}, {}
		for _, g in gates do
			fed[g] = { back = false, side = false }
		end
		local queue = {}
		for _, m in list do
			if isSource(m) or (isGate(m) and m:GetAttribute("Passing") == true) then
				live[m] = true
				table.insert(queue, m)
			end
		end
		while #queue > 0 do
			local m = table.remove(queue) :: Model
			local passing = isGate(m) and m:GetAttribute("Passing") == true
			if not (isSource(m) or conducts(m) or passing) then
				continue      -- it gets power itself, but doesn't pass it on
			end
			for _, n in links[m] or {} do
				if isGate(m) and CircuitService.sideOf(m, n) ~= "front" then
					continue
				end
				if isGate(n) then
					local side = CircuitService.sideOf(n, m)
					if side ~= "front" then
						(fed[n] :: any)[side] = true
					end
					continue
				end
				if not live[n] then
					live[n] = true
					table.insert(queue, n)
				end
			end
		end
		local changed = false
		for _, g in gates do
			local want = wouldPass(g, fed[g])
			if want ~= (g:GetAttribute("Passing") == true) then
				g:SetAttribute("Passing", want)
				changed = true
			end
		end
		if not changed then
			break
		end
	end
	for _, g in gates do
		if g:GetAttribute("Passing") then
			live[g] = true
		end
	end
	return live, fed
end

local function powerOn(m: Model)
	local id = m:GetAttribute("Build")
	if id == "charge" then
		(require(script.Parent.MiningService) :: any).light(m)
	elseif id == "bell" then
		remotes.Fx:FireAllClients("clink", m:GetPivot().Position, 0.7, 4)
		remotes.Fx:FireAllClients("clink", m:GetPivot().Position, 0.52, 2)
	elseif id == "truck_caller" then
		-- whenever it gets power, it sends the log truck off with whatever is on it
		local owner = Players:GetPlayerByUserId(m:GetAttribute("Owner") :: number)
		local EconomyService = require(script.Parent.EconomyService) :: any
		local sent = owner ~= nil and EconomyService.ship(owner)
		remotes.Fx:FireAllClients(if sent then "clink" else "click", m:GetPivot().Position, if sent then 1.4 else 0.5)
	end
end

local function show(m: Model, on: boolean)
	local id = m:GetAttribute("Build")
	if id == "lamp" then
		local holder = m:FindFirstChild("LampLight") :: BasePart?
		if not holder then
			local size = m:GetAttribute("Size") :: number? or 1
			local h = Instance.new("Part")
			h.Name = "LampLight"
			h.Anchored = true
			h.CanCollide = false
			h.CanQuery = false
			h.Transparency = 1
			h.Size = Vector3.one * 0.2
			h.CFrame = m:GetPivot() * CFrame.new(0, 1.25 * M * size, 0)
			h.Parent = m
			local l = Instance.new("PointLight")
			l.Color = Color3.fromHex("ffcf8a")
			l.Range = math.min(7 * M * size, 60)
			l.Brightness = 0
			l.Parent = h
			holder = h
		end
		local l = (holder :: BasePart):FindFirstChildOfClass("PointLight")
		if l then
			l.Brightness = if on then 2.5 else 0
		end
		local def = Builds.def("lamp") :: any
		for _, p in m:GetChildren() do
			local pd = p:IsA("BasePart") and def.parts[(p:GetAttribute("Index") :: number? or -1) + 1]
			if pd and pd.color == "6b6458" then     -- (the bulb: Godot's Model/Bulb)
				p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
				p.Color = if on then Color3.fromHex("ffcf8a") else Color3.fromHex("6b6458")
			end
		end
	elseif isBelt(m) then
		-- the belt carries what sits on it toward its front (Roblox's own belt trick: a moving anchored surface)
		local v = if on then m:GetPivot().LookVector * CircuitService.BELT_SPEED * M else Vector3.zero
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and (p:GetAttribute("Group") == "Slats" or p:GetAttribute("Res") == "bark") then
				p.AssemblyLinearVelocity = v
			end
		end
	end
end

function CircuitService.step(dt: number)
	local list = machines()
	local links: { [Model]: { Model } } = {}
	for _, m in list do
		links[m] = {}
	end
	local uids: { [string]: Model } = {}
	for _, m in list do
		uids[m:GetAttribute("Uid") :: string] = m
	end
	for _, w in wireFolder():GetChildren() do
		local a, b = uids[w:GetAttribute("A") :: string], uids[w:GetAttribute("B") :: string]
		if a and b then
			table.insert(links[a], b)
			table.insert(links[b], a)
		elseif not byUid(w:GetAttribute("A") :: string) or not byUid(w:GetAttribute("B") :: string) then
			w:Destroy()      -- (a machine it was on has gone)
		end
	end
	-- belts that touch pass power along to each other, as if wired
	local belts = {}
	for _, m in list do
		if isBelt(m) then
			table.insert(belts, m)
		end
	end
	for i = 1, #belts do
		for j = i + 1, #belts do
			if (belts[i]:GetPivot().Position - belts[j]:GetPivot().Position).Magnitude < 3.2 * M and touches(belts[i], belts[j]) then
				table.insert(links[belts[i]], belts[j])
				table.insert(links[belts[j]], belts[i])
			end
		end
	end
	-- a minecart's battery powers the machines on its deck, no wire needed (Minecart.auto_linked)
	local RailService = require(script.Parent.RailService) :: any
	for _, m in list do
		if isCart(m) then
			for _, d in RailService.deck(m) do
				local b = uids[d:GetAttribute("Uid") :: string]      -- (the same Model as in the list)
				if b and RailService.autoLinked(b) then
					table.insert(links[m], b)
					table.insert(links[b], m)
				end
			end
		end
	end
	for _, m in list do
		sense(m)
	end
	-- batteries charge from a network that has other power; if it has none, they power it themselves
	for _, m in list do
		if m:GetAttribute("Build") == "battery" then
			m:SetAttribute("Feeding", false)
		end
	end
	local live, fed = solve(list, links)
	local any = false
	for _, m in list do
		if m:GetAttribute("Build") == "battery" and not live[m] and (m:GetAttribute("Charge") :: number? or 0) > 0 then
			m:SetAttribute("Feeding", true)
			any = true
		end
	end
	if any then
		live, fed = solve(list, links)
	end
	for _, m in list do
		if isGate(m) then
			gateStep(m, fed[m] or { back = false, side = false }, dt)
		end
	end
	for _, m in list do
		local on = live[m] == true
		local was = m:GetAttribute("Powered") == true
		if on ~= was then
			m:SetAttribute("Powered", on)
			if on then
				powerOn(m)
			end
			show(m, on)
		end
		-- the sources run down / fill up
		local id = m:GetAttribute("Build")
		if id == "crank" then
			local c = m:GetAttribute("Charge") :: number? or 0
			if c > 0 then
				m:SetAttribute("Charge", math.max(0, c - dt))
			end
		elseif id == "button" then
			local t = m:GetAttribute("Pressed") :: number? or 0
			if t > 0 then
				m:SetAttribute("Pressed", math.max(0, t - dt))
				if t - dt <= 0 then
					remotes.Fx:FireAllClients("click", m:GetPivot().Position, 0.9, -6)
				end
			end
		elseif id == "generator" then
			local f = m:GetAttribute("Fuel") :: number? or 0
			if f > 0 then
				m:SetAttribute("Fuel", math.max(0, f - dt))
			end
		elseif id == "battery" then
			local c = m:GetAttribute("Charge") :: number? or 0
			if m:GetAttribute("Feeding") then
				m:SetAttribute("Charge", math.max(0, c - dt))
			elseif on then
				m:SetAttribute("Charge", math.min(CircuitService.BATTERY_MAX, c + dt))
			end
		end
	end
	-- wires glow when power flows through them
	for _, w in wireFolder():GetChildren() do
		local a, b = uids[w:GetAttribute("A") :: string], uids[w:GetAttribute("B") :: string]
		local function feeds(x: Model): boolean
			return isSource(x) or conducts(x) or (isGate(x) and x:GetAttribute("Passing") == true)
		end
		local flows = a ~= nil and b ~= nil and live[a] == true and live[b] == true and (feeds(a) or feeds(b))
		if w:GetAttribute("Live") ~= flows then
			w:SetAttribute("Live", flows)
			local beam = w:FindFirstChild("Beam", true) :: Beam?
			if beam then
				beam.Color = ColorSequence.new(if flows then Color3.fromHex("ffb347") else Color3.fromHex("b8622c"))
				beam.LightEmission = if flows then 0.45 else 0
			end
		end
	end
end

-- the generator's hopper: bark, leaves, wood and saplings burn as fuel (Generator.burn_time)
local function feedGenerators()
	for _, m in machines() do
		if m:GetAttribute("Build") ~= "generator" then
			continue
		end
		local fuel = m:GetAttribute("Fuel") :: number? or 0
		if fuel >= CircuitService.GEN_MAX then
			continue
		end
		local size = m:GetAttribute("Size") :: number? or 1
		local hopper = m:GetPivot() * CFrame.new(Vector3.new(0.1, 1.05, -0.05) * M * size)
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
		for _, p in workspace:GetPartBoundsInBox(hopper, Vector3.new(0.6, 0.5, 0.6) * M * size, params) do
			local item: BasePart = if p.Parent and p.Parent:IsA("BasePart") then p.Parent :: BasePart else p
			if item.Parent == nil or item:GetAttribute("HeldBy") then
				continue
			end
			local kind = item:GetAttribute("Kind")
			local t = 0
			if kind == "bark" then
				t = 2 * (item:GetAttribute("Panels") :: number? or 1)
			elseif kind == "leaf" then
				t = 1
			elseif kind == "sapling" then
				t = 3
			elseif kind == "product" then
				t = item:GetAttribute("Fuel") :: number? or 0
			elseif item.Name == "Trunk" and item.Parent and item.Parent:GetAttribute("Kind") == "log" then
				t = 25 * (item.Parent:GetAttribute("Bands") :: number? or 1) * Config.Tree.bandH
			end
			if t > 0 then
				fuel = math.min(CircuitService.GEN_MAX, fuel + t)
				m:SetAttribute("Fuel", fuel)
				remotes.Fx:FireAllClients("crumble", item.Position, 1.6, -8)
				if item.Name == "Trunk" and item.Parent and item.Parent:GetAttribute("Kind") == "log" then
					item.Parent:Destroy()
				else
					item:Destroy()
				end
			end
		end
	end
end

-- E on a machine: wind the crank, flip the lever, press the button
function CircuitService.use(m: Model): boolean
	local id = m:GetAttribute("Build")
	local at = m:GetPivot().Position
	if id == "crank" then
		m:SetAttribute("Charge", math.min(CircuitService.CRANK.max, (m:GetAttribute("Charge") :: number? or 0) + CircuitService.CRANK.per))
		remotes.Fx:FireAllClients("click", at, 0.7, -2)
		remotes.Fx:FireAllClients("clink", at, 0.6, -8)
		return true
	elseif id == "lever" then
		local on = not (m:GetAttribute("On") == true)
		m:SetAttribute("On", on)
		remotes.Fx:FireAllClients("clink", at, if on then 0.9 else 0.75, -2)
		remotes.Fx:FireAllClients("thud", at, 1.6, -8)
		return true
	elseif id == "button" then
		m:SetAttribute("Pressed", CircuitService.BUTTON_HOLD)
		remotes.Fx:FireAllClients("click", at, 0.6, 0)
		return true
	elseif id == "assembler" then
		(require(script.Parent.ProductionService) :: any).cycle(m)
		return true
	elseif isCart(m) then
		return (require(script.Parent.RailService) :: any).takeCell(m)
	elseif string.sub(id :: string? or "", 1, 6) == "drone_" and id ~= "drone_pad" then
		return (require(script.Parent.DroneService) :: any).use(m, nil)
	elseif id == "level_sensor" then
		local s = ((m:GetAttribute("Setting") :: number? or 1) + 1) % #CircuitService.LEVELS
		m:SetAttribute("Setting", s)
		remotes.Fx:FireAllClients("click", at, 0.9 + s * 0.1, -4)
		return true
	elseif id == "transmitter" or id == "receiver" then
		local ch = ((m:GetAttribute("Channel") :: number? or 0) + 1) % 8
		m:SetAttribute("Channel", ch)
		remotes.Fx:FireAllClients("click", at, 0.9 + ch * 0.1, -4)
		return true
	elseif isGate(m) then
		local mode = gateMode(m)
		if mode == "timer" or mode == "delay" or mode == "counter" then
			local s = (num(m, "Setting") + 1) % 4
			m:SetAttribute("Setting", s)
			m:SetAttribute("Count", 0)
			remotes.Fx:FireAllClients("click", at, 0.8 + s * 0.15, -4)
			return true
		elseif mode == "latch" then
			m:SetAttribute("LatchOn", not m:GetAttribute("LatchOn"))
			remotes.Fx:FireAllClients("click", at, if m:GetAttribute("LatchOn") then 1.3 else 0.9, -4)
			return true
		end
	end
	return false
end

local function machineOf(target: unknown): Model?
	if typeof(target) ~= "Instance" then
		return nil
	end
	local m = (target :: Instance):FindFirstAncestorWhichIsA("Model")
	while m and m:GetAttribute("Kind") ~= "build" do
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	local def = m and Builds.def(m:GetAttribute("Build") :: string)
	return if (def and def.machine) or (m and m:GetAttribute("Build") == "charge") then m else nil
end

local function near(player: Player, m: Model, reach: number): boolean
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	return head ~= nil and (head.CFrame.Position - m:GetPivot().Position).Magnitude < reach
end

function CircuitService.start()
	remotes.UseMachine.OnServerEvent:Connect(function(player, target)
		local m = machineOf(target)
		if m and near(player, m, 6 * M) then
			if m:GetAttribute("Build") == "feller" or m:GetAttribute("Build") == "drill_rig" then
				(require(script.Parent.FactoryService) :: any).handOver(player, m)
				return
			end
			if string.sub(m:GetAttribute("Build") :: string? or "", 1, 6) == "drone_" and m:GetAttribute("Build") ~= "drone_pad" then
				(require(script.Parent.DroneService) :: any).use(m, target)
				return
			end
			if m:GetAttribute("Build") == "sorter" then
				-- (E while holding something: sort that kind out to the left)
				local held: BasePart? = nil
				local loose = workspace:FindFirstChild("Loose")
				for _, p in if loose then loose:GetChildren() else {} do
					if p:IsA("BasePart") and p:GetAttribute("HeldBy") == player.UserId then
						held = p
					end
				end
				(require(script.Parent.FactoryService) :: any).setFilter(m, held)
				return
			end
			CircuitService.use(m)
		end
	end)
	remotes.Wire.OnServerEvent:Connect(function(player, a, b)
		local tool = (Config.Tools :: any)[ToolService.current(player)]
		local ma, mb = machineOf(a), machineOf(b)
		if not tool or not tool.wire or not ma or not mb or not near(player, mb, 8 * M) then
			return
		end
		local r = CircuitService.toggle(ma, mb)
		if r == "added" then
			remotes.Fx:FireClient(player, "snip", nil, 1)
			remotes.Fx:FireClient(player, "pickup", nil, 1.4, -8)
		elseif r == "removed" then
			remotes.Fx:FireClient(player, "snip", nil, 0.7)
		elseif r == "far" then
			remotes.Notify:FireClient(player, "Too far for a wire (14m max)", "ffd27a")
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			local ok, err = pcall(function()
				CircuitService.step(now - last)
				feedGenerators()
			end)
			if not ok then
				warn("[Timber] circuit: " .. tostring(err))
			end
			last = now
		end
	end)
end

return CircuitService
