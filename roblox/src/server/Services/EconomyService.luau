--!strict
-- Money, the shop and the log truck. Everything that changes money happens here, on the server.
-- The truck works like the Godot game's: drop bark in the back, look at the truck and press E. It sounds its horn,
-- drives off down the road to the mill, and you're paid when it gets there (a few seconds later); then it comes
-- back and parks. Everyone's bark in the bed goes, and each player is paid for their own.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local W = require(ReplicatedStorage.Shared.GodotWorld) :: any
local DataService = require(script.Parent.DataService)
local TutorialService = require(script.Parent.TutorialService)

local EconomyService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local GREEN = "7aff9a"
local STUDS = Config.StudsPerMetre

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
	local roots: { Instance } = {}
	for _, name in { "Loose", "Logs" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(roots, f)
		end
	end
	params.FilterDescendantsInstances = roots
	local out = {}
	local seen = {}
	for _, part in workspace:GetPartBoundsInBox(bed.CFrame * CFrame.new(0, 2.5, 0), bed.Size + Vector3.new(0, 5, 0), params) do
		if seen[part] then
			continue
		end
		seen[part] = true
		if typeof(part:GetAttribute("Value")) == "number" and typeof(part:GetAttribute("Owner")) == "number" then
			table.insert(out, part)
		elseif part.Name == "Trunk" and part.Parent and part.Parent:GetAttribute("Kind") == "log" and not seen[part.Parent] then
			-- a log (its worth depends on how much bark is still on it)
			seen[part.Parent] = true
			table.insert(out, part)
		end
	end
	return out
end

-- what one thing in the bed is worth
local function worth(p: BasePart): number
	if p.Name == "Trunk" and p.Parent and p.Parent:GetAttribute("Kind") == "log" then
		local LogService = require(script.Parent.LogService) :: any
		return LogService.value(p.Parent)
	end
	return p:GetAttribute("Value") :: number
end

function EconomyService.bedValue(player: Player?): number
	local t = truck()
	if not t or t:GetAttribute("State") ~= "parked" then
		return 0
	end
	local v = 0
	for _, p in inBed(t) do
		local owner = p:GetAttribute("Owner")
		if not player or owner == player.UserId or owner == nil then
			v += worth(p)
		end
	end
	return v
end

-- Drives the truck along a road (Godot's waypoints, in studs), facing the way it goes: it pulls away gently, keeps to
-- its speed and slows for the end, like Godot's Truck._drive.
local function drive(t: Model, points: { Vector3 })
	local speed = Config.Truck.speed * STUDS
	local total = 0
	local seg = {}
	for k = 1, #points - 1 do
		local d = (points[k + 1] - points[k]).Magnitude
		table.insert(seg, d)
		total += d
	end
	local s, v = 0, 0
	local heading = t:GetPivot().LookVector
	while s < total do
		local dt = RunService.Heartbeat:Wait()
		local want = math.min(speed, math.max(3, (total - s) * 0.9))
		if s < 18 then
			want = math.min(want, 6 + s * 1.2)
		end
		v += math.clamp(want - v, -dt * 12, dt * 12)
		s = math.min(total, s + v * dt)
		-- where along the road that is
		local k, left = 1, s
		while k < #seg and left > seg[k] do
			left -= seg[k]
			k += 1
		end
		local a, b = points[k], points[k + 1]
		local pos = a + (b - a) * math.clamp(left / math.max(seg[k], 0.001), 0, 1)
		local dir = (b - a) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 0.01 then
			heading = heading:Lerp(dir.Unit, math.min(1, dt * 6))
		end
		if heading.Magnitude > 0.01 then
			t:PivotTo(CFrame.lookAt(pos, pos + heading.Unit))
		end
	end
end

local function route(list: { { number } }): { Vector3 }
	local out = {}
	for _, p in list do
		table.insert(out, Vector3.new(p[1], p[2], p[3]))
	end
	return out
end

function EconomyService.ship(player: Player, force: boolean?): boolean
	local t = truck()
	if not t or t:GetAttribute("State") ~= "parked" then
		return false
	end
	local cargo = inBed(t)
	if #cargo == 0 and not force then
		return false         -- (an empty truck stays put; it only drives off empty to be swapped for a bigger one)
	end
	local owed: { [number]: number } = {}
	for _, p in cargo do
		-- (bark is paid to whoever peeled it; a log to whoever ships it)
		local owner = p:GetAttribute("Owner") :: number? or player.UserId
		owed[owner] = (owed[owner] or 0) + worth(p)
		EconomyService.release(p)
		if p.Name == "Trunk" and p.Parent and p.Parent:GetAttribute("Kind") == "log" then
			local log = p.Parent :: Model
			for _, d in log:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			log:SetAttribute("Kind", "sold")
			log:RemoveTag("Tree")
			log.Parent = t
		else
			p.Anchored = true
			p.CanCollide = false
			p:SetAttribute("Value", nil)        -- it's sold: nobody can sell it twice
			p.Parent = t
		end
	end
	local park = t:GetPivot()
	t:SetAttribute("State", "leaving")
	remotes.Fx:FireAllClients("horn", t:GetPivot().Position + Vector3.new(0, 4.5, 0), 1, 4)
	task.spawn(function()
		drive(t, route(W.truck.out))
		t:SetAttribute("State", "away")
		task.wait(Config.Truck.awaySeconds)
		for _, p in cargo do
			if p.Parent and p.Parent:GetAttribute("Kind") == "sold" then
				p.Parent:Destroy()       -- the whole log
			else
				p:Destroy()
			end
		end
		for userId, amount in owed do
			local who = Players:GetPlayerByUserId(userId)
			local data = who and DataService.get(who)
			if who and data then
				amount = math.floor(amount * 100 + 0.5) / 100
				EconomyService.addMoney(who, amount)
				data.earned = (data.earned or 0) + amount
				who:SetAttribute("Earned", data.earned)
				remotes.Sold:FireClient(who, amount)
				-- (today's jobs: the truckload, and what's been earned)
				local JobsService = require(script.Parent.JobsService) :: any
				JobsService.load(who, amount)
				JobsService.check(who)
				TutorialService.check(who)
			end
		end
		-- back it comes, round the clearing and into its spot (a bigger one, if one's been bought)
		t:SetAttribute("State", "returning")
		local want = EconomyService.truckLevel()
		if upgrading or want ~= (t:GetAttribute("Level") or 0) then
			upgrading = false
			if want ~= (t:GetAttribute("Level") or 0) then
				local WorldService = require(script.Parent.WorldService) :: any
				WorldService.setTruckLevel(want)
				remotes.Notify:FireAllClients("Your new truck is on its way", "8fd0ff")
			end
		end
		local back = route(W.truck.back)
		t:PivotTo(CFrame.lookAt(back[1], back[2]))
		drive(t, back)
		t:PivotTo(park)
		t:SetAttribute("State", "parked")
	end)
	return true
end

-- Buying puts in an order (Godot's Game.buy): the money goes now, the van brings it (DeliveryService).
local function buy(player: Player, item: unknown)
	if typeof(item) ~= "string" then
		return
	end
	local def = (Config.Tools :: any)[item] or (Config.Items :: any)[item]
	local data = DataService.get(player)
	if not def or def.price <= 0 or not data or (data.owned[item] and not def.consumable) then
		return
	end
	data.orders = data.orders or {}
	for _, o in data.orders do
		if o.item == item and o.status ~= "delivered" then
			return        -- already on its way
		end
	end
	if data.money < def.price then
		remotes.Notify:FireClient(player, "Not enough money", "ff7a7a")
		return
	end
	if def.vehicle then
		-- trucks don't come in a box: the old one drives off (selling what's on it) and the new one comes back
		EconomyService.addMoney(player, -def.price)
		data.owned[item] = true
		DataService.publish(player)
		remotes.Notify:FireClient(player, "Bought the " .. def.name, "8fd0ff")
		EconomyService.upgradeTruck(player)
		return
	end
	EconomyService.addMoney(player, -def.price)
	table.insert(data.orders, { item = item, status = "processing" })
	DataService.publish(player)
	remotes.Notify:FireClient(player, "Ordered " .. def.name, "8fd0ff")
	TutorialService.check(player)
end

-- the truck that comes back is the best one anyone here owns (Godot's Game.truck_level)
function EconomyService.truckLevel(): number
	local best = 0
	for _, p in game:GetService("Players"):GetPlayers() do
		local d = DataService.get(p)
		if d then
			best = math.max(best, if d.owned.truck_hauler then 2 elseif d.owned.truck_big then 1 else 0)
		end
	end
	return best
end

local upgrading = false
function EconomyService.upgradeTruck(player: Player)
	local t = workspace:FindFirstChild("Truck") :: Model?
	if not t then
		return
	end
	upgrading = true
	if t:GetAttribute("State") == "parked" then
		EconomyService.ship(player, true)
	end
end

-- the TimberPhone: send the truck off from anywhere
local function phoneShip(player: Player)
	local data = DataService.get(player)
	if data and data.owned.phone then
		EconomyService.ship(player)
	end
end

-- The daily reward (a Roblox staple: a reason to come back tomorrow). From the day after you first play, the first
-- time you play each day you get money, more for each day in a row, up to a week: $15, then $30 ... $105 from the
-- 7th day on. Miss a day and the streak starts again. Days are UTC days. Returns what was paid (0 if none today).
EconomyService.DAILY = { per = 15, maxDays = 7 }
function EconomyService.daily(player: Player, today: number?): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local day = today or math.floor(os.time() / 86400)
	if not data.daily then
		-- your very first day: you start with nothing, as in Godot; the rewards start tomorrow
		data.daily = { last = day, streak = 0 }
		return 0
	end
	local d = data.daily
	if d.last == day then
		return 0
	end
	d.streak = if d.last == day - 1 then d.streak + 1 else 1
	d.last = day
	local amount = EconomyService.DAILY.per * math.min(d.streak, EconomyService.DAILY.maxDays)
	EconomyService.addMoney(player, amount)
	player:SetAttribute("Streak", d.streak)
	local nextAmount = EconomyService.DAILY.per * math.min(d.streak + 1, EconomyService.DAILY.maxDays)
	local text = if d.streak == 1 then string.format("Daily reward: +$%d    come back tomorrow for $%d", amount, nextAmount)
		else string.format("Day %d in a row: +$%d    come back tomorrow for $%d", d.streak, amount, nextAmount)
	-- (after the title screen: a few seconds in)
	task.delay(8, function()
		if player.Parent then
			remotes.Notify:FireClient(player, text, "ffd27a", "buy")
		end
	end)
	return amount
end

-- a code typed into the phone: pays once per player; returns what it paid and why not (for the toast)
function EconomyService.redeem(player: Player, code: unknown): (number, string)
	local data = DataService.get(player)
	if not data or typeof(code) ~= "string" or #code > 40 then
		return 0, "That code doesn't work"
	end
	local key = string.upper((string.gsub(code, "%s", "")))
	local amount = (Config.Codes :: any)[key]
	if typeof(amount) ~= "number" then
		return 0, "That code doesn't work"
	end
	data.codes = data.codes or {}
	if data.codes[key] then
		return 0, "You've already used that code"
	end
	data.codes[key] = true
	EconomyService.addMoney(player, amount)
	return amount, string.format("Code %s: +$%d", key, amount)
end

function EconomyService.start()
	remotes.PhoneShip.OnServerEvent:Connect(phoneShip)
	TutorialService.loaded = function(player)
		return EconomyService.bedValue(player) > 0
	end
	remotes.Buy.OnServerEvent:Connect(buy)
	remotes.Redeem.OnServerEvent:Connect(function(player, code)
		local paid, text = EconomyService.redeem(player, code)
		remotes.Notify:FireClient(player, text, if paid > 0 then "7aff9a" else "ff8a6a", if paid > 0 then "buy" else nil)
	end)
	-- someone who owns a bigger truck joins: it's the one that's parked (or comes back next)
	table.insert(DataService.onLoaded, function(player)
		EconomyService.daily(player)
	end)
	table.insert(DataService.onLoaded, function()
		local t = workspace:FindFirstChild("Truck") :: Model?
		local want = EconomyService.truckLevel()
		if t and t:GetAttribute("State") == "parked" and want ~= (t:GetAttribute("Level") or 0) then
			(require(script.Parent.WorldService) :: any).setTruckLevel(want)
		end
	end)
end

return EconomyService
