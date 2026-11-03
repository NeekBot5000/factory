--!strict
-- Drones, the Godot game's way (Drone.gd): a flying platform in three sizes. It runs on a battery cell (drop one into
-- the cradle on its back; E takes it out) and, while it has charge, hovers 3 m over whatever is below it. It has no
-- wires: its five dials are wireless receivers. While the channel on its front dial is on (a powered transmitter on
-- that channel anywhere) it flies forward; the same for its right, back and left dials - two at once flies
-- diagonally. The dial on top works its pad: on, it goes down and picks up the thing under it; off, it lets go. It
-- carries one thing, only as heavy as its size can lift. E on a dial changes its channel.
-- State on the drone's Model: Cell (charge, nil without one), Dials ("f,r,b,l,p", -1 = off), Carries (the carried
-- part's name, for the hint), Heavy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Weight = require(ReplicatedStorage.Shared.Weight)

local DroneService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local Drones = require(ReplicatedStorage.Shared.Drones)
DroneService.SIZES = Drones.SIZES
DroneService.CHANNELS = Drones.CHANNELS
local DIR = { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) }
DroneService.CRUISE = 3.0     -- metres above whatever is under it
DroneService.SPEED = 3.0
DroneService.CLIMB = 1.6
local MOVE_DRAIN = 1.6

type Carry = { p: BasePart, off: CFrame }
local carrying: { [string]: Carry } = {}      -- (by the drone's Uid)

DroneService.isDrone = Drones.isDrone
DroneService.dials = Drones.dials
DroneService.dialOf = Drones.dialOf

local function sizeOf(m: Model): any
	return DroneService.SIZES[m:GetAttribute("Build") :: string]
end

local function paint(m: Model)
	local dl = DroneService.dials(m)
	for _, p in m:GetChildren() do
		local i = DroneService.dialOf(m, p)
		if i then
			local ch = dl[i]
			;(p :: BasePart).Color = Color3.fromHex(if ch >= 0 then DroneService.CHANNELS[ch + 1] else "2b2d33")
			;(p :: BasePart).Material = if ch >= 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

local function channelOn(ch: number): boolean
	if ch < 0 then
		return false
	end
	local f = workspace:FindFirstChild("Builds")
	for _, t in if f then f:GetChildren() else {} do
		if t:GetAttribute("Build") == "transmitter" and (t:GetAttribute("Channel") or 0) == ch and t:GetAttribute("Powered") == true then
			return true
		end
	end
	return false
end

local function cradle(m: Model): CFrame
	return m:GetPivot() * CFrame.new(Vector3.new(0, 0.42, sizeOf(m).w * 0.5 - 0.12) * M)
end

local function showCell(m: Model)
	local c = m:FindFirstChild("Cell")
	local charge = m:GetAttribute("Cell") :: number?
	if charge and not c then
		local p = Instance.new("Part")
		p.Name = "Cell"
		p.Size = Vector3.new(0.18, 0.32, 0.18) * M
		p.Color = Color3.fromHex("e8e8e8")
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CFrame = cradle(m)
		p.Parent = m
	elseif not charge and c then
		c:Destroy()
	end
end

-- E on a drone: on a dial, change its channel (red, green ... pink, off); anywhere else, take the cell out
function DroneService.use(m: Model, part: Instance?): boolean
	local i = part and DroneService.dialOf(m, part)
	if i then
		local dl = DroneService.dials(m)
		dl[i] += 1
		if dl[i] >= #DroneService.CHANNELS then
			dl[i] = -1
		end
		local parts = {}
		for _, v in dl do
			table.insert(parts, tostring(v))
		end
		m:SetAttribute("Dials", table.concat(parts, ","))
		paint(m)
		remotes.Fx:FireAllClients("click", m:GetPivot().Position, 0.9 + (dl[i] + 1) * 0.06, -4)
		return true
	end
	local charge = m:GetAttribute("Cell") :: number?
	if not charge then
		return false
	end
	m:SetAttribute("Cell", nil)
	showCell(m)
	local PS = require(script.Parent.ProductionService) :: any
	local cell = PS.product("battery_cell", 1.2, Color3.fromHex("e8e8e8"), cradle(m) * CFrame.new(0, 0.3 * M, 0),
		(m:GetPivot().LookVector * -1.5 + Vector3.new(0, 1, 0)) * M, m:GetAttribute("Owner"))
	cell:SetAttribute("Charge", charge)
	remotes.Fx:FireAllClients("pickup", m:GetPivot().Position, 0.9, -4)
	return true
end

local function skipList(m: Model): { Instance }
	local skip: { Instance } = { m }
	for _, n in { "Loose", "Logs", "Plans" } do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(skip, f)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	local f = workspace:FindFirstChild("Builds")
	for _, d in if f then f:GetChildren() else {} do
		if DroneService.isDrone(d) then
			table.insert(skip, d)
		end
	end
	return skip
end

-- what's under it: the ground, a roof, a belt... (not the thing it carries, loose items or other drones)
local function floorBelow(m: Model): number
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = skipList(m)
	params.FilterType = Enum.RaycastFilterType.Exclude
	local from = m:GetPivot().Position + Vector3.new(0, 0.05 * M, 0)
	local hit = workspace:Raycast(from, Vector3.new(0, -30 * M, 0), params)
	if hit then
		return hit.Position.Y
	end
	local WorldService = require(script.Parent.WorldService) :: any
	return WorldService.heightAt(from.X, from.Z)
end

-- the loose thing right under the pad, if any
local function underPad(m: Model, ground: number): BasePart?
	local FS = require(script.Parent.FactoryService) :: any
	local bottom = (m:GetPivot().Position.Y - ground) / M
	for _, b in FS.within(m, Vector3.new(0, -bottom * 0.5, 0), Vector3.new(sizeOf(m).w * 0.9, bottom + 0.1, sizeOf(m).w * 0.9)) do
		if b:GetAttribute("Kind") ~= nil and not b:GetAttribute("Stuck") then
			return b
		end
	end
	return nil
end

local function release(m: Model)
	local uid = m:GetAttribute("Uid") :: string? or "?"
	local c = carrying[uid]
	if c and c.p.Parent then
		c.p.Anchored = false
		c.p:SetAttribute("Drone", nil)
		c.p.AssemblyLinearVelocity = Vector3.zero
	end
	carrying[uid] = nil
	m:SetAttribute("Carries", nil)
	m:SetAttribute("Heavy", nil)
end

local function grab(m: Model, p: BasePart)
	local uid = m:GetAttribute("Uid") :: string? or "?"
	p.Anchored = true
	p:SetAttribute("Drone", uid)
	carrying[uid] = { p = p, off = CFrame.new(0, -0.05 * M - p.Size.Y * 0.5, 0) }
	m:SetAttribute("Carries", p.Name)
	m:SetAttribute("Heavy", Weight.of(p) > sizeOf(m).lift)
	remotes.Fx:FireAllClients("clink", m:GetPivot().Position, 1.1, -6)
end

local function fly(m: Model, dt: number)
	local uid = m:GetAttribute("Uid") :: string? or "?"
	local s = sizeOf(m)
	-- a battery cell dropped in the cradle snaps in
	local charge = m:GetAttribute("Cell") :: number?
	if not charge then
		local FS = require(script.Parent.FactoryService) :: any
		for _, b in FS.within(m, Vector3.new(0, 0.42, s.w * 0.5 - 0.12), Vector3.new(0.4, 0.45, 0.36)) do
			if b:GetAttribute("Product") == "battery_cell" then
				charge = b:GetAttribute("Charge") :: number? or 0
				m:SetAttribute("Cell", charge)
				b:Destroy()
				remotes.Fx:FireAllClients("clink", m:GetPivot().Position, 1.3, -4)
				break
			end
		end
	end
	showCell(m)
	if m:GetAttribute("Dials") == nil then
		m:SetAttribute("Dials", "0,1,2,3,4")
	end
	if not m:GetAttribute("Painted") then
		m:SetAttribute("Painted", true)
		paint(m)
	end
	local dl = DroneService.dials(m)
	local ground = floorBelow(m)
	local up = charge ~= nil and charge > 0
	local pad = up and channelOn(dl[5])
	local c = carrying[uid]
	if c and not c.p.Parent then
		release(m)
		c = nil
	end
	local heavy = c ~= nil and m:GetAttribute("Heavy") == true
	local target = ground
	local move = Vector3.zero
	if up then
		target = ground + DroneService.CRUISE * M
		for i = 1, 4 do
			if channelOn(dl[i]) then
				move += DIR[i]
			end
		end
		if pad and not c then
			target = ground + 0.35 * M        -- (go down for it)
		end
		if heavy then
			target = ground + (0.05 + math.abs(math.sin(os.clock() * 6)) * 0.15) * M    -- straining, bobbing
			move = Vector3.zero
		end
	end
	-- let go when the pad switches off (or the battery dies)
	if c and not pad then
		release(m)
		c = nil
	end
	local y = m:GetPivot().Position.Y
	-- pick up
	if pad and not c and y - ground < 0.9 * M then
		local p = underPad(m, ground)
		if p then
			grab(m, p)
			c = carrying[uid]
		end
	end
	local dy = math.clamp(target - y, -DroneService.CLIMB * M * dt, DroneService.CLIMB * M * dt)
	local step = Vector3.zero
	if move.Magnitude > 0 and y - ground > DroneService.CRUISE * 0.6 * M then
		step = m:GetPivot():VectorToWorldSpace(move.Unit) * DroneService.SPEED * M * dt
	end
	if step.Magnitude > 0 or math.abs(dy) > 0.001 then
		local cf = m:GetPivot() + step + Vector3.new(0, dy, 0)
		-- never through the ground
		if cf.Position.Y < ground then
			cf = cf + Vector3.new(0, ground - cf.Position.Y, 0)
		end
		m:PivotTo(cf)
	end
	if c then
		c.p.CFrame = m:GetPivot() * c.off
	end
	if up and charge then
		local flying = m:GetPivot().Position.Y - ground > 0.1 * M
		if flying or pad then
			m:SetAttribute("Cell", math.max(0, charge - s.drain * (if step.Magnitude > 0 then MOVE_DRAIN else 1) * dt))
		end
	end
	-- the rotors spin while it has power
	local spin = (m:GetAttribute("Spin") :: number? or 0)
	spin = if up then math.min(1, spin + dt * 2) else math.max(0, spin - dt * 0.7)
	m:SetAttribute("Spin", spin)
end

function DroneService.step(dt: number)
	local f = workspace:FindFirstChild("Builds")
	local alive: { [string]: boolean } = {}
	for _, m in if f then f:GetChildren() else {} do
		if m:IsA("Model") and DroneService.isDrone(m) then
			alive[m:GetAttribute("Uid") :: string? or "?"] = true
			fly(m, dt)
		end
	end
	-- a drone that was taken down lets go of what it carried
	for uid, c in carrying do
		if not alive[uid] then
			if c.p.Parent then
				c.p.Anchored = false
				c.p:SetAttribute("Drone", nil)
			end
			carrying[uid] = nil
		end
	end
end

function DroneService.start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.05)
			local now = os.clock()
			local ok, err = pcall(DroneService.step, now - last)
			if not ok then
				warn("[Timber] drones: " .. tostring(err))
			end
			last = now
		end
	end)
end

return DroneService
