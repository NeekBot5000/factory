--!strict
-- The all-time leaderboard: the most money earned at the mill, across every server (a Roblox OrderedDataStore).
-- Each player's total goes in when their data is saved; every few minutes the server reads the top ten and puts
-- them, with their names, on ReplicatedStorage as the "AllTime" attribute (JSON) for the TimberPhone to show.
-- Without DataStores (Studio without API access, the Lune tests) it does nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}
LeaderboardService.REFRESH = 300
local names: { [number]: string } = {}
local written: { [number]: number } = {} -- (what each player last sent, so an unchanged total isn't sent again)

local function board(): OrderedDataStore?
	local ok, s = pcall(function()
		return game:GetService("DataStoreService"):GetOrderedDataStore("Timber_earned_v1")
	end)
	return if ok then s else nil
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok and typeof(n) == "string" then n else "Lumberjack"
	names[userId] = name
	return name
end

function LeaderboardService.refresh()
	local b = board()
	if not b then
		return
	end
	local ok, pages = pcall(function()
		return (b :: any):GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		return
	end
	local top = {}
	for _, e in (pages :: any):GetCurrentPage() do
		table.insert(top, { name = nameOf(tonumber(e.key) or 0), earned = e.value })
	end
	ReplicatedStorage:SetAttribute("AllTime", HttpService:JSONEncode(top))
end

function LeaderboardService.start()
	-- (saved with the player's data: whole dollars)
	table.insert(DataService.beforeSave, function(player, data)
		local b = board()
		local earned = math.floor(math.max(data.earned or 0, data.bestEarned or 0))   -- (a new game doesn't lower it)
		if b and earned > 0 and written[player.UserId] ~= earned then
			written[player.UserId] = earned
			task.spawn(pcall, function()
				(b :: any):SetAsync(tostring(player.UserId), earned)
			end)
		end
	end)
	task.spawn(function()
		task.wait(10)
		while true do
			pcall(LeaderboardService.refresh)
			task.wait(LeaderboardService.REFRESH)
		end
	end)
end

return LeaderboardService
