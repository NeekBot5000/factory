--!strict
-- Machines and power. Machines are Models tagged "Machine" with a Kind attribute; wires are kept here as pairs of
-- machine ids. Power is worked out 10 times a second (PowerGrid), not every frame, and each machine gets a
-- Powered attribute that replicates to clients for lamps and animations. Conveyor belts use Roblox's built-in
-- trick: an anchored part with AssemblyLinearVelocity carries whatever sits on it, with no scripts per item.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PowerGrid = require(ReplicatedStorage.Shared.PowerGrid)

local MachineService = {}
MachineService.wires = {} :: { { string } }
local TICK = 0.1
local BELT_SPEED = 4           -- studs a second

local function isSource(m: Model): boolean
	local kind = m:GetAttribute("Kind")
	if kind == "crank" then
		return (m:GetAttribute("Charge") :: number? or 0) > 0
	elseif kind == "generator" then
		return (m:GetAttribute("Fuel") :: number? or 0) > 0
	elseif kind == "windmill" then
		return workspace:GetAttribute("Wind") ~= nil and (workspace:GetAttribute("Wind") :: number) > 0.3
	end
	return false
end

local function conducts(m: Model): boolean
	local kind = m:GetAttribute("Kind")
	if kind == "lever" then
		return m:GetAttribute("On") == true
	end
	return true
end

local function step()
	local nodes = {}
	local byId: { [string]: Model } = {}
	for _, inst in CollectionService:GetTagged("Machine") do
		local m = inst :: Model
		local id = m:GetAttribute("Id") :: string?
		if id then
			byId[id] = m
			nodes[id] = { id = id, source = isSource(m), conducts = conducts(m), battery = m:GetAttribute("Battery") :: number? }
		end
	end
	local live = PowerGrid.solve(nodes, MachineService.wires)
	for id, m in byId do
		local on = live[id] == true
		if m:GetAttribute("Powered") ~= on then
			m:SetAttribute("Powered", on)     -- only write when it changes: every write is network traffic
			if m:GetAttribute("Kind") == "conveyor" then
				local belt = m:FindFirstChild("Belt") :: BasePart?
				if belt then
					belt.AssemblyLinearVelocity = if on then belt.CFrame.LookVector * BELT_SPEED else Vector3.zero
				end
			end
		end
	end
	-- cranks and generators run down
	for _, m in byId do
		for _, attr in { "Charge", "Fuel" } do
			local v = m:GetAttribute(attr)
			if typeof(v) == "number" and v > 0 then
				m:SetAttribute(attr, math.max(0, v - TICK))
			end
		end
	end
end

function MachineService.start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			debug.profilebegin("Timber.Power")
			step()
			debug.profileend()
		end
	end)
end

return MachineService
