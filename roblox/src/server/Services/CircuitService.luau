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
	windmill = { 0.3, 0.35, 0.3 }, generator = { 0.36, 0.45, 0.3 }, battery = { 0, 0.82, 0 }, truck_caller = { 0, 0.3, 0.2 },
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
		if def and def.machine then
			table.insert(out, m :: Model)
		end
	end
	return out
end

function CircuitService.terminal(m: Model): Vector3
	local t = TERMINAL[m:GetAttribute("Build") :: string] or { 0, 0.4, 0 }
	local size = m:GetAttribute("Size") :: number? or 1
	return m:GetPivot():PointToWorldSpace(Vector3.new(t[1], t[2], t[3]) * M * size)
end

local function isSource(m: Model): boolean
	local id = m:GetAttribute("Build")
	if id == "crank" then
		return (m:GetAttribute("Charge") :: number? or 0) > 0
	elseif id == "windmill" then
		return CircuitService.wind() >= CircuitService.MIN_WIND
	elseif id == "generator" then
		return (m:GetAttribute("Fuel") :: number? or 0) > 0
	elseif id == "battery" then
		return m:GetAttribute("Feeding") == true and (m:GetAttribute("Charge") :: number? or 0) > 0
	end
	return false
end

local function conducts(m: Model): boolean
	local id = m:GetAttribute("Build")
	if id == "lever" then
		return m:GetAttribute("On") == true
	elseif id == "button" then
		return (m:GetAttribute("Pressed") :: number? or 0) > 0
	end
	return true
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
	return id == "conveyor" or id == "ramp"
end

-- ------------------------------------------------------------------ the tick
local function solve(list: { Model }, links: { [Model]: { Model } }): { [Model]: boolean }
	local live: { [Model]: boolean } = {}
	local queue = {}
	for _, m in list do
		if isSource(m) then
			live[m] = true
			table.insert(queue, m)
		end
	end
	while #queue > 0 do
		local m = table.remove(queue) :: Model
		if not (isSource(m) or conducts(m)) then
			continue      -- it gets power itself, but doesn't pass it on
		end
		for _, n in links[m] or {} do
			if not live[n] then
				live[n] = true
				table.insert(queue, n)
			end
		end
	end
	return live
end

local function powerOn(m: Model)
	local id = m:GetAttribute("Build")
	if id == "bell" then
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
	-- batteries charge from a network that has other power; if it has none, they power it themselves
	for _, m in list do
		if m:GetAttribute("Build") == "battery" then
			m:SetAttribute("Feeding", false)
		end
	end
	local live = solve(list, links)
	local any = false
	for _, m in list do
		if m:GetAttribute("Build") == "battery" and not live[m] and (m:GetAttribute("Charge") :: number? or 0) > 0 then
			m:SetAttribute("Feeding", true)
			any = true
		end
	end
	if any then
		live = solve(list, links)
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
		local flows = a ~= nil and b ~= nil and live[a] == true and live[b] == true and (isSource(a) or conducts(a) or isSource(b) or conducts(b))
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
	return if def and def.machine then m else nil
end

local function near(player: Player, m: Model, reach: number): boolean
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	return head ~= nil and (head.CFrame.Position - m:GetPivot().Position).Magnitude < reach
end

function CircuitService.start()
	remotes.UseMachine.OnServerEvent:Connect(function(player, target)
		local m = machineOf(target)
		if m and near(player, m, 6 * M) then
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
