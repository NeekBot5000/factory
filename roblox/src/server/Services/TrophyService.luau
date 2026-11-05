--!strict
-- The trophy wall, the Godot game's way (Trophies.gd): a plaque for each milestone, with a keepsake on it once you've
-- earned it ("Trophy: your first tree felled"). Each player has their own; their client puts up their wall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataService = require(script.Parent.DataService)
local Config = require(ReplicatedStorage.Shared.Config)

local TrophyService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
TrophyService.LIST = {
	{ "first_tree", "your first tree felled" }, { "first_machine", "your first machine" }, { "thousand", "$1,000 earned" },
	{ "first_plank", "your first planks" }, { "first_iron", "your first iron bar" }, { "first_furniture", "your first furniture" },
	{ "giant", "an ancient giant felled" }, { "legend", "the Legendary Tree felled" }, { "first_oil", "your first barrel of oil" },
}

-- the Roblox badge for a trophy, if it has one (Config.Badges); Roblox ignores a badge you already have
function TrophyService.badge(player: Player, id: string)
	local badgeId = (Config.Badges :: any)[id]
	if typeof(badgeId) ~= "number" or badgeId <= 0 then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			game:GetService("BadgeService"):AwardBadge(player.UserId, badgeId)
		end)
		if not ok then
			warn("[Timber] badge " .. id .. ": " .. tostring(err))
		end
	end)
end

function TrophyService.award(player: Player?, id: string)
	if not player then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	data.trophies = data.trophies or {}
	if data.trophies[id] then
		return
	end
	data.trophies[id] = true
	for _, e in TrophyService.LIST do
		if e[1] == id then
			remotes.Notify:FireClient(player, "Trophy: " .. e[2], "ffd27a")
		end
	end
	remotes.Fx:FireClient(player, "reveal", nil, 1.2, -2)
	DataService.publish(player)
	TrophyService.badge(player, id)
end

function TrophyService.start()
	-- joining: the badge for playing, and any for trophies earned before their badges existed
	table.insert(DataService.onLoaded, function(player, data)
		TrophyService.badge(player, "welcome")
		for id, yes in data.trophies or {} do
			if yes then
				TrophyService.badge(player, id)
			end
		end
	end)
	-- ($1,000 earned: Godot checks as the money comes in)
	task.spawn(function()
		while true do
			task.wait(2)
			for _, p in Players:GetPlayers() do
				local d = DataService.get(p)
				if d and (d.earned or 0) >= 1000 then
					TrophyService.award(p, "thousand")
				end
			end
		end
	end)
end

return TrophyService
