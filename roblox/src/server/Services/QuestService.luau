--!strict
-- The first few minutes, as a short chain of goals (Config.Quests): peel, carry, ship, buy a hatchet, earn $150.
-- Each step teaches one thing by doing it, shows on screen as a pill with progress, and points at where to go.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local QuestService = {}
QuestService.onReward = nil :: ((Player, number) -> ())?
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local TARGET = { peel = "tree", carry = "truck", ship = "truck", buy = "shop", earn = "" }

local function send(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local q = data.quest or { i = 1, n = 0 }
	local step = Config.Quests[q.i]
	if step then
		remotes.Quest:FireClient(player, { text = step.text, n = q.n, goal = step.goal, target = TARGET[step.id] or "", i = q.i, of = #Config.Quests })
	else
		remotes.Quest:FireClient(player, nil)
	end
end

-- something happened that a quest might count ("peel", "carry", "ship", "buy", "earn")
function QuestService.progress(player: Player, id: string, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.quest = data.quest or { i = 1, n = 0 }
	local step = Config.Quests[data.quest.i]
	if not step or step.id ~= id then
		return
	end
	data.quest.n = math.min(step.goal, data.quest.n + amount)
	if data.quest.n >= step.goal then
		data.quest = { i = data.quest.i + 1, n = 0 }
		remotes.Notify:FireClient(player, "Done: " .. step.text .. (if step.reward > 0 then string.format("  +$%d", step.reward) else ""))
		if step.reward > 0 and QuestService.onReward then
			(QuestService.onReward :: any)(player, step.reward)
		end
	end
	send(player)
end

function QuestService.start()
	Players.PlayerAdded:Connect(function(p)
		task.wait(2)
		send(p)
	end)
end

return QuestService
