--!strict
-- Money, the shop and the log truck. Everything that changes money happens here, on the server.
-- The truck works like the Godot game's: drop bark in the back, look at the truck and press E. It sounds its horn,
-- drives off down the road to the mill, and you're paid when it gets there (a few seconds later); then it comes
-- back and parks. Everyone's bark in the bed goes, and each player is paid for their own.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local ToolService = require(script.Parent.ToolService)
local TutorialService = require(script.Parent.TutorialService)

local EconomyService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local GREEN = "7aff9a"
local STUDS = Config.StudsPerMetre
local ROAD = 150          -- studs the truck drives before it's out of sight

-- the CarryService lets go of anything that drives off in the truck (set by CarryService)
EconomyService.release = function(_part: BasePart) end

function EconomyService.addMoney(player: Player, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.money = math.floor((data.money + amount) * 100 + 0.5) / 100
	player:SetAttribute("Money", data.money)
end

local function truck(): Model?
	return workspace:FindFirstChild("Truck") :: Model?
end

-- the loose things in the truck bed that are worth something
local function inBed(t: Model): { BasePart }
	local bed = t:FindFirstChild("Bed") :: BasePart
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace:FindFirstChild("Loose") :: Instance }
	local out = {}
	for _, part in workspace:GetPartBoundsInBox(bed.CFrame * CFrame.new(0, 2.5, 0), bed.Size + Vector3.new(0, 5, 0), params) do
		if typeof(part:GetAttribute("Value")) == "number" and typeof(part:GetAttribute("Owner")) == "number" then
			table.insert(out, part)
		end
	end
	return out
end

function EconomyService.bedValue(player: Player?): number
	local t = truck()
	if not t or t:GetAttribute("State") ~= "parked" then
		return 0
	end
	local v = 0
	for _, p in inBed(t) do
		if not player or p:GetAttribute("Owner") == player.UserId then
			v += p:GetAttribute("Value") :: number
		end
	end
	return v
end

-- drives the truck `dist` studs along its forward direction, easing in and out
local function drive(t: Model, from: CFrame, dist: number)
	local speed = Config.Truck.speed * STUDS
	local s, v = 0, 0
	while s < dist do
		local dt = RunService.Heartbeat:Wait()
		local want = math.min(speed, math.max(3, (dist - s) * 0.9))
		if s < 18 then
			want = math.min(want, 6 + s * 1.2)          -- pull away gently
		end
		v += math.clamp(want - v, -dt * 12, dt * 12)
		s = math.min(dist, s + v * dt)
		t:PivotTo(from * CFrame.new(0, 0, -s))
	end
end

function EconomyService.ship(player: Player): boolean
	local t = truck()
	if not t or t:GetAttribute("State") ~= "parked" then
		return false
	end
	local cargo = inBed(t)
	if #cargo == 0 then
		return false
	end
	local owed: { [number]: number } = {}
	for _, p in cargo do
		local owner = p:GetAttribute("Owner") :: number
		owed[owner] = (owed[owner] or 0) + (p:GetAttribute("Value") :: number)
		EconomyService.release(p)
		p.Anchored = true
		p.CanCollide = false
		p:SetAttribute("Value", nil)        -- it's sold: nobody can sell it twice
		p.Parent = t
	end
	local park = t:GetPivot()
	t:SetAttribute("State", "leaving")
	remotes.Fx:FireAllClients("horn", t:GetPivot().Position + Vector3.new(0, 4.5, 0), 1, 4)
	task.spawn(function()
		drive(t, park, ROAD)
		t:SetAttribute("State", "away")
		task.wait(Config.Truck.awaySeconds)
		for _, p in cargo do
			p:Destroy()
		end
		for userId, amount in owed do
			local who = Players:GetPlayerByUserId(userId)
			local data = who and DataService.get(who)
			if who and data then
				amount = math.floor(amount * 100 + 0.5) / 100
				EconomyService.addMoney(who, amount)
				data.earned = (data.earned or 0) + amount
				remotes.Sold:FireClient(who, amount)
				TutorialService.check(who)
			end
		end
		-- back it comes: in from the other end of the road, and parks where it was
		t:SetAttribute("State", "returning")
		drive(t, park * CFrame.new(0, 0, ROAD), ROAD)
		t:PivotTo(park)
		t:SetAttribute("State", "parked")
	end)
	return true
end

local function buy(player: Player, item: unknown)
	if typeof(item) ~= "string" then
		return
	end
	local def = (Config.Tools :: any)[item]
	local data = DataService.get(player)
	if not def or def.price <= 0 or not data or data.owned[item] or data.money < def.price then
		return
	end
	EconomyService.addMoney(player, -def.price)
	ToolService.grant(player, item :: string)
	remotes.Notify:FireClient(player, "Bought the " .. def.name, GREEN, "buy")
	TutorialService.check(player)
end

function EconomyService.start()
	TutorialService.loaded = function(player)
		return EconomyService.bedValue(player) > 0
	end
	remotes.Buy.OnServerEvent:Connect(buy)
end

return EconomyService
