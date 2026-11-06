--!strict
-- Player saves. One DataStore key per player, session-locked so two servers can't overwrite each other
-- (a player who rejoins fast gets the save once the old server has let go). Autosaves every 60 s, and on leave
-- and server shutdown. For a bigger game, swap this for the community ProfileStore module, which does the same
-- with more edge cases handled.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local DataService = {}
-- (in a place that was never published, even asking for the store throws: then the game plays without saving)
local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore("Timber_v1")
end)
local profiles: { [Player]: any } = {}
local LOCK_SECONDS = 180

local TEMPLATE = {
	money = 0,
	owned = { hands = true },
	plot = nil,            -- which land plot this player holds on the server they last played on
	builds = {},           -- compact arrays: { id, x, y, z, yaw, extra } relative to the plot origin
	trees = {},            -- tree id -> BarkGrid string, for trees on the player's plot
	trophies = {},
	dropped = {},          -- tools you own but put down (Q): out of the tool bar until you pick them up again
	orders = {},           -- TimberMart orders: { item, status = processing / shipping / boxed / delivered }
	tutorial = 1,          -- which "Getting started" step you're on (-1 when you've finished it)
	peeled = 0,            -- bark sheets peeled, ever
	earned = 0,            -- money the truck has paid you, ever
	land = { "-1,-1", "-1,0", "0,-1", "0,0" },   -- the 20 m plots you own (Godot's Land.START: the four round the cabin)
	settings = { fov = 75, volume = 0.8, music = 0.5, bob = true, fps = false },
}

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepCopy(v)
	end
	return c
end

local function retry<T>(f: () -> T): (boolean, T?)
	for attempt = 1, if RunService:IsStudio() then 1 else 4 do
		local ok, res = pcall(f)
		if ok then
			return true, res
		end
		warn("DataStore attempt", attempt, "failed:", res)
		task.wait(2 ^ attempt)
	end
	return false, nil
end

local function load(player: Player)
	if not storeOk then
		warn("Timber: saving is off - publish the place and turn on Studio Access to API Services")
		profiles[player] = deepCopy(TEMPLATE)
		DataService.publish(player)
		return
	end
	local key = "p_" .. player.UserId
	local ok, data = retry(function()
		return store:UpdateAsync(key, function(old)
			old = old or deepCopy(TEMPLATE)
			local lock = old._lock
			if lock and lock.job ~= game.JobId and os.time() - lock.t < LOCK_SECONDS then
				return nil      -- another server still has it: don't touch
			end
			old._lock = { job = game.JobId, t = os.time() }
			return old
		end)
	end)
	if not ok and RunService:IsStudio() then
		-- usually "Enable Studio Access to API Services" is off: play on without saving
		warn("Timber: saving is off in this Studio session (Game Settings > Security > Enable Studio Access to API Services)")
		profiles[player] = deepCopy(TEMPLATE)
		DataService.publish(player)
		return
	end
	if not ok or data == nil or (data :: any)._lock.job ~= game.JobId then
		player:Kick("Your save is still being used by another server. Please rejoin in a minute.")
		return
	end
	-- fill in anything newer versions added
	for k, v in TEMPLATE do
		if (data :: any)[k] == nil then
			(data :: any)[k] = deepCopy(v)
		end
	end
	profiles[player] = data
	DataService.publish(player)
	for _, f in DataService.onLoaded do
		task.spawn(f, player, data)
	end
end

-- other services keep parts of the save up to date just before it's written (BuildService: your builds), and
-- put things back once it's loaded
DataService.beforeSave = {} :: { (Player, any) -> () }
DataService.onLoaded = {} :: { (Player, any) -> () }

local function save(player: Player, release: boolean)
	local data = profiles[player]
	if not data or not storeOk then
		return
	end
	for _, f in DataService.beforeSave do
		pcall(f, player, data)
	end
	retry(function()
		return store:UpdateAsync("p_" .. player.UserId, function(old)
			if old and old._lock and old._lock.job ~= game.JobId then
				return nil      -- we lost the lock: never overwrite someone else's session
			end
			data._lock = if release then nil else { job = game.JobId, t = os.time() }
			return data
		end)
	end)
end

function DataService.get(player: Player): any
	return profiles[player]
end

-- What the player's own screen needs (money, the tool bar), as attributes on their Player: only they and the
-- server read them, and they replicate by themselves when they change.
function DataService.publish(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	player:SetAttribute("Money", data.money)
	local owned, dropped = {}, {}
	for id, yes in data.owned do
		if yes then
			table.insert(owned, id)
		end
	end
	for id, yes in data.dropped or {} do
		if yes then
			table.insert(dropped, id)
		end
	end
	table.sort(owned)
	table.sort(dropped)
	player:SetAttribute("Owned", table.concat(owned, ","))
	player:SetAttribute("Dropped", table.concat(dropped, ","))
	local ordered = {}
	for _, o in data.orders or {} do
		if o.status ~= "delivered" then
			table.insert(ordered, o.item)
		end
	end
	player:SetAttribute("Ordered", table.concat(ordered, ","))
	-- nothing done yet (Godot's is_fresh): the title only offers New Game
	local onlyHands = true
	for id, yes in data.owned do
		if yes and id ~= "hands" then
			onlyHands = false
		end
	end
	player:SetAttribute("Fresh", (data.earned or 0) <= 0 and onlyHands and #(data.orders or {}) == 0 and (data.tutorial or 1) == 1)
	player:SetAttribute("Settings", HttpService:JSONEncode(data.settings or {}))
	player:SetAttribute("Land", table.concat(data.land or {}, ";"))
	player:SetAttribute("Charges", (data.charges or {}).dynamite or 0)
	-- (everyone on the server sees these: the phone's Lumberjacks list)
	player:SetAttribute("Earned", data.earned or 0)
	player:SetAttribute("Felled", data.felled or 0)
	local tro = {}
	for id, yes in data.trophies or {} do
		if yes then
			table.insert(tro, id)
		end
	end
	table.sort(tro)
	player:SetAttribute("Trophies", table.concat(tro, ","))
end

-- New Game: this player's save starts over (Godot's Game.reset), keeping only their settings
function DataService.reset(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	local fresh = deepCopy(TEMPLATE)
	fresh.settings = data.settings
	fresh._lock = data._lock
	-- (a new game keeps what belongs to the player rather than to the camp: the codes already used, so they can't be
	-- used again; the daily streak; and the best they've ever earned, for the all-time leaderboard)
	fresh.codes = data.codes
	fresh.daily = data.daily
	fresh.askedLike, fresh.groupPaid = data.askedLike, data.groupPaid
	fresh.bestEarned = math.max(data.bestEarned or 0, data.earned or 0)
	-- (and today's jobs stay done; the rest count on from the new start)
	if data.jobs then
		fresh.jobs = data.jobs
		fresh.jobs.felled, fresh.jobs.earned = 0, 0
	end
	profiles[player] = fresh
	DataService.publish(player)
end

-- the Settings page: only the known settings, of the right kinds
function DataService.setSettings(player: Player, s: unknown)
	local data = profiles[player]
	if not data or type(s) ~= "table" then
		return
	end
	local t = s :: any
	local out = data.settings or {}
	if type(t.fov) == "number" then
		out.fov = math.clamp(t.fov, 60, 100)
	end
	if type(t.volume) == "number" then
		out.volume = math.clamp(t.volume, 0, 1)
	end
	if type(t.music) == "number" then
		out.music = math.clamp(t.music, 0, 1)
	end
	if type(t.bob) == "boolean" then
		out.bob = t.bob
	end
	if type(t.fps) == "boolean" then
		out.fps = t.fps
	end
	data.settings = out
	DataService.publish(player)
end

function DataService.start()
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		profiles[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for player in profiles do
				task.spawn(save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		-- (wait for every save to finish, not a fixed time: Roblox allows up to 30 seconds)
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				pcall(save, player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return DataService
