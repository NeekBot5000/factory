--!strict
-- The trophy wall, the Godot game's way (Trophies.gd): a plaque for each milestone, with a keepsake on it once you've
-- earned it ("Trophy: your first tree felled"). Each player has their own; their client puts up their wall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataService = require(script.Parent.DataService)

local TrophyService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
TrophyService.LIST = {
	{ "first_tree", "your first tree felled" }, { "first_machine", "your first machine" }, { "thousand", "$1,000 earned" },
	{ "first_plank", "your first planks" }, { "first_iron", "your first iron bar" }, { "first_furniture", "your first furniture" },
	{ "giant", "an ancient giant felled" }, { "legend", "the Legendary Tree felled" }, { "first_oil", "your first barrel of oil" },
}

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
end

function TrophyService.start()
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
