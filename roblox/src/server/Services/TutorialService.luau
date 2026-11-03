--!strict
-- "Getting started", like the Godot game's Tutorial.gd: a small panel in the corner shows one step at a time, and
-- moves on as soon as you've done it. When the last step is done it says so once and goes away for good.
-- The steps are in Config.Tutorial; each one names what the server checks (`check`).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local TutorialService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local GREEN = "7aff9a"
local lastSent: { [Player]: string } = {}

-- is anything of this player's in the truck bed? (EconomyService fills this in)
TutorialService.loaded = function(_player: Player): boolean
	return false
end

local function done(player: Player, data: any, step: any): boolean
	local c = step.check
	if c == "hatchet" then
		return data.owned.hatchet == true
	elseif c == "peeled" then
		return (data.peeled or 0) >= step.goal
	elseif c == "loaded" then
		return (data.earned or 0) > 0 or TutorialService.loaded(player)
	elseif c == "earned" then
		return (data.earned or 0) > 0
	elseif c == "money" then
		return data.money >= step.goal or data.owned[step.next or "double_bit"] == true
	elseif c == "ordered" then
		if data.owned[step.item] then
			return true
		end
		for _, o in data.orders or {} do
			if o.item == step.item then
				return true
			end
		end
		return false
	elseif c == "owns" then
		return data.owned[step.item] == true
	end
	return true
end

local function send(player: Player, data: any)
	local i = data.tutorial
	local step = Config.Tutorial[i]
	if not step then
		remotes.Tutorial:FireClient(player, nil)
		return
	end
	local text = step.text
	if step.check == "money" then
		text ..= string.format("  ($%d / $%d)", math.floor(data.money), step.goal)
	end
	remotes.Tutorial:FireClient(player, { i = i, of = #Config.Tutorial, text = text })
end

-- something happened: move on past every step that's done now
function TutorialService.check(player: Player)
	local data = DataService.get(player)
	if not data or (data.tutorial or 1) < 1 then
		return
	end
	data.tutorial = data.tutorial or 1
	local moved = false
	while Config.Tutorial[data.tutorial] and done(player, data, Config.Tutorial[data.tutorial]) do
		data.tutorial += 1
		moved = true
	end
	if not Config.Tutorial[data.tutorial] then
		data.tutorial = -1
		remotes.Tutorial:FireClient(player, nil)
		remotes.Notify:FireClient(player, Config.TutorialDone, GREEN, "reveal")
		return
	end
	if moved then
		remotes.Fx:FireClient(player, "pickup", nil, 1.4, -6)
	end
	-- re-send only when it changed (the money step's count ticks up as you earn)
	local key = data.tutorial .. ":" .. math.floor(data.money)
	if moved or lastSent[player] ~= key then
		lastSent[player] = key
		send(player, data)
	end
end

function TutorialService.start()
	local function join(p: Player)
		-- wait for the save to load, then show where they are
		for _ = 1, 120 do
			local data = DataService.get(p)
			if data then
				if (data.tutorial or 1) >= 1 then
					send(p, data)
				end
				return
			end
			if not p.Parent then
				return
			end
			task.wait(0.5)
		end
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(function(p)
		lastSent[p] = nil
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(join, p)
	end
	-- the money step counts up as you earn, like Godot's (re-checked a few times a second)
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, p in Players:GetPlayers() do
				TutorialService.check(p)
			end
		end
	end)
end

return TutorialService
