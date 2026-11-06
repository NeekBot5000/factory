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
local STUDS = Config.StudsPerMetre

-- The friends boost (a common Roblox trend that makes inviting friends worth it): while a Roblox friend of yours is
-- on the same server, the mill pays you FRIEND_BOOST times as much. Friendships are looked up once, when someone
-- joins (Player:IsFriendsWith asks Roblox's web service, so it can fail; then there's no boost).
EconomyService.FRIEND_BOOST = 1.1
EconomyService.friends = {} :: { [number]: { [number]: boolean } }
function EconomyService.friendBoost(player: Player): number
	local mine = EconomyService.friends[player.UserId]
	if mine then
		for _, p in Players:GetPlayers() do
			if p ~= player and mine[p.UserId] then
				return EconomyService.FRIEND_BOOST
			end
		end
	end
	return 1
end
local function shownName(p: Player): string
	local ok, display = pcall(function()
		return p.DisplayName
	end)
	return if ok and typeof(display) == "string" and display ~= "" then display else p.Name
end
local function lookUpFriends(newcomer: Player)
	for _, p in Players:GetPlayers() do
		if p ~= newcomer then
			task.spawn(function()
				local ok, yes = pcall(function()
					return newcomer:IsFriendsWith(p.UserId)
				end)
				if ok and yes == true and newcomer.Parent and p.Parent then
					local f = EconomyService.friends
					f[newcomer.UserId] = f[newcomer.UserId] or {}
					f[p.UserId] = f[p.UserId] or {}
					f[newcomer.UserId][p.UserId] = true
					f[p.UserId][newcomer.UserId] = true
					local pct = math.floor((EconomyService.FRIEND_BOOST - 1) * 100 + 0.5)
					remotes.Notify:FireClient(newcomer, string.format("Your friend %s is here: +%d%% at the mill", shownName(p), pct), "8fd0ff", "reveal")
					remotes.Notify:FireClient(p, string.format("Your friend %s is here: +%d%% at the mill", shownName(newcomer), pct), "8fd0ff", "reveal")
				end
			end)
		end
	end
end

-- the CarryService lets go of anything that drives off in the truck (set by CarryService)
EconomyService.release = function(_part: BasePart) end

-- kind (optional): what it was, for Roblox's analytics ("Gameplay", "Shop", "TimedReward"), and sku what for
function EconomyService.addMoney(player: Player, amount: number, kind: string?, sku: string?)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.money = math.floor((data.money + amount) * 100 + 0.5) / 100
	player:SetAttribute("Money", data.money)
	if kind then
		(require(script.Parent.Analytics) :: any).money(player, amount, data.money, kind, sku)
	end
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
-- Wood of the day (the user's growth idea #9, prices that move; a daily boosted item, as many Roblox games have):
-- each UTC day one species pays WOOD_BONUS times as much at the mill, bark and logs alike. The phone says which.
EconomyService.WOOD_BONUS = Config.WoodBonus
function EconomyService.woodOfTheDay(today: number?): string
	local names = {}
	for id in Config.Species :: any do
		table.insert(names, id)
	end
	table.sort(names)
	local day = today or math.floor(os.time() / 86400)
	return names[day % #names + 1]
end

-- Rush hour (a timed double-money window, as popular Roblox games have, and on the clock so players learn when to
-- come): the first Config.RushHour.minutes of every hour, UTC, the mill pays Config.RushHour.mult times as much.
function EconomyService.rushActive(now: number?): boolean
	return ((now or os.time()) % 3600) < Config.RushHour.minutes * 60
end

local function worth(p: BasePart): number
	local species, v
	if p.Name == "Trunk" and p.Parent and p.Parent:GetAttribute("Kind") == "log" then
		local LogService = require(script.Parent.LogService) :: any
		v = LogService.value(p.Parent)
		species = p.Parent:GetAttribute("Species")
	else
		v = p:GetAttribute("Value") :: number? or 0
		species = p:GetAttribute("Species")
	end
	if species ~= nil and species == EconomyService.woodOfTheDay() then
		v *= EconomyService.WOOD_BONUS
	end
	if EconomyService.rushActive() then
		v *= Config.RushHour.mult
	end
	return v
end
EconomyService.worth = worth

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

-- (a bigger truck was bought: the one driving off comes back as it; EconomyService.upgradeTruck sets it)
local upgrading = false
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
				amount = math.floor(amount * EconomyService.friendBoost(who) * 100 + 0.5) / 100
				EconomyService.addMoney(who, amount, "Gameplay", "mill")
				data.earned = (data.earned or 0) + amount
				who:SetAttribute("Earned", data.earned)
				remotes.Sold:FireClient(who, amount)
				-- (today's jobs: the truckload, and what's been earned)
				local JobsService = require(script.Parent.JobsService) :: any
				JobsService.load(who, amount)
				JobsService.check(who)
				TutorialService.check(who)
				;(require(script.Parent.CommunityService) :: any).sold(who)
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
		EconomyService.addMoney(player, -def.price, "Shop", item)
		data.owned[item] = true
		DataService.publish(player)
		remotes.Notify:FireClient(player, "Bought the " .. def.name, "8fd0ff")
		EconomyService.upgradeTruck(player)
		return
	end
	EconomyService.addMoney(player, -def.price, "Shop", item)
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
		-- (already paid today, e.g. a second visit: the phone still shows the streak)
		player:SetAttribute("Streak", d.streak)
		return 0
	end
	d.streak = if d.last == day - 1 then d.streak + 1 else 1
	d.last = day
	local amount = EconomyService.DAILY.per * math.min(d.streak, EconomyService.DAILY.maxDays)
	EconomyService.addMoney(player, amount, "TimedReward", "daily")
	player:SetAttribute("Streak", d.streak)
	if d.streak >= EconomyService.DAILY.maxDays then
		(require(script.Parent.TrophyService) :: any).badge(player, "week")
	end
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
	EconomyService.addMoney(player, amount, "Gameplay", "code")
	return amount, string.format("Code %s: +$%d", key, amount)
end

function EconomyService.start()
	-- (the wood of the day, for the phone, refreshed once a minute so it never shows yesterday's wood while the mill
	-- pays today's; and when the UTC day changes, the daily reward for anyone playing through midnight)
	task.spawn(function()
		local seen = math.floor(os.time() / 86400)
		local wasRush = false
		while true do
			ReplicatedStorage:SetAttribute("WoodOfTheDay", EconomyService.woodOfTheDay())
			-- rush hour: told when it starts, and five minutes before; the phone shows it
			local rush = EconomyService.rushActive()
			ReplicatedStorage:SetAttribute("Rush", rush)
			if rush and not wasRush and #Players:GetPlayers() > 0 then
				remotes.Notify:FireAllClients(string.format("Rush hour at the mill: %dx pay for %d minutes!", Config.RushHour.mult, Config.RushHour.minutes), "ffd27a", "reveal")
			elseif not rush and os.time() % 3600 >= 3300 and os.time() % 3600 < 3360 and #Players:GetPlayers() > 0 then
				remotes.Notify:FireAllClients("Rush hour at the mill in 5 minutes!", "ffd27a")
			end
			wasRush = rush
			task.wait(60)
			local day = math.floor(os.time() / 86400)
			if day ~= seen then
				seen = day
				for _, p in Players:GetPlayers() do
					pcall(EconomyService.daily, p)
				end
			end
		end
	end)
	remotes.PhoneShip.OnServerEvent:Connect(phoneShip)
	Players.PlayerAdded:Connect(lookUpFriends)
	Players.PlayerRemoving:Connect(function(p)
		EconomyService.friends[p.UserId] = nil
	end)
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
