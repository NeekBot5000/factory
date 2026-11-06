--!strict
-- Today's jobs, on the TimberPhone (the user's growth ideas #7 "contracts on the phone" and #10 "a truckload
-- bonus"; daily jobs are also one of the most common reasons players come back to a Roblox game). Each UTC day
-- brings three jobs: fell some trees, earn some money at the mill, and send one big truckload. Finishing one pays
-- its bonus straight away. The amounts change from day to day. Progress is counted from the day's start
-- (data.felled and data.earned, which the game already keeps), and the best truckload of the day.
-- The phone reads the "Jobs" attribute on the player (JSON).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataService = require(script.Parent.DataService)

local JobsService = {}
JobsService.ALL_BONUS = 50
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- the day's three jobs (what each asks, and its bonus), varying with the day
function JobsService.forDay(day: number): { { id: string, text: string, need: number, pay: number } }
	local k = day % 3
	local trees = ({ 2, 3, 5 })[k + 1]
	local earn = ({ 40, 75, 120 })[k + 1]
	local load = ({ 20, 35, 60 })[k + 1]
	return {
		{ id = "fell", text = string.format("Fell %d trees", trees), need = trees, pay = 10 * trees },
		{ id = "earn", text = string.format("Earn $%d at the mill", earn), need = earn, pay = math.floor(earn * 0.5) },
		{ id = "load", text = string.format("Send a $%d truckload", load), need = load, pay = math.floor(load * 0.8) },
	}
end

local function state(data: any, day: number): any
	local j = data.jobs
	if not j or j.day ~= day then
		j = { day = day, felled = data.felled or 0, earned = data.earned or 0, best = 0, done = {} }
		data.jobs = j
	end
	return j
end

local function progress(data: any, j: any, id: string): number
	if id == "fell" then
		return (data.felled or 0) - j.felled
	elseif id == "earn" then
		return (data.earned or 0) - j.earned
	end
	return j.best
end

-- looks at a player's jobs: pays for any just finished, and publishes them for the phone
function JobsService.check(player: Player, today: number?): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local day = today or math.floor(os.time() / 86400)
	local j = state(data, day)
	local paid = 0
	local shown = {}
	for _, job in JobsService.forDay(day) do
		local have = math.min(progress(data, j, job.id), job.need)
		if have >= job.need and not j.done[job.id] then
			j.done[job.id] = true
			paid += job.pay
			local EconomyService = require(script.Parent.EconomyService) :: any
			EconomyService.addMoney(player, job.pay)
			remotes.Notify:FireClient(player, string.format("Job done: %s  +$%d", job.text, job.pay), "7aff9a", "buy")
		end
		table.insert(shown, { text = job.text, have = math.floor(have), need = job.need, pay = job.pay, done = j.done[job.id] == true })
	end
	-- all three done: a bonus on top, once a day, and a badge
	if not j.allDone and j.done.fell and j.done.earn and j.done.load then
		j.allDone = true
		paid += JobsService.ALL_BONUS
		local EconomyService = require(script.Parent.EconomyService) :: any
		EconomyService.addMoney(player, JobsService.ALL_BONUS)
		remotes.Notify:FireClient(player, string.format("All of today's jobs done!  +$%d", JobsService.ALL_BONUS), "ffd27a", "reveal")
		;(require(script.Parent.TrophyService) :: any).badge(player, "jobs")
	end
	player:SetAttribute("Jobs", HttpService:JSONEncode(shown))
	return paid
end

-- one truckload sold for this player (EconomyService): the day's best counts for the truckload job
function JobsService.load(player: Player, amount: number, today: number?)
	local data = DataService.get(player)
	if not data then
		return
	end
	local j = state(data, today or math.floor(os.time() / 86400))
	j.best = math.max(j.best, amount)
end

function JobsService.start()
	table.insert(DataService.onLoaded, function(player)
		JobsService.check(player)
	end)
	-- (when the UTC day changes, for everyone: a new day's jobs show up even if you play through midnight)
	task.spawn(function()
		local seen = math.floor(os.time() / 86400)
		while true do
			task.wait(60)
			local day = math.floor(os.time() / 86400)
			if day ~= seen then
				seen = day
				for _, p in game:GetService("Players"):GetPlayers() do
					pcall(JobsService.check, p)
				end
			end
		end
	end)
end

return JobsService
