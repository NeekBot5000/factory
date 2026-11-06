--!strict
-- Buying land, the Godot game's way (Land.buy): E on a for-sale sign buys that plot if it's next to yours and you can
-- afford it (400, then 1.7 times as much for each plot after). Each player has their own land; their client draws
-- their signs and corner stakes (LandController).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Land = require(ReplicatedStorage.Shared.Land)
local DataService = require(script.Parent.DataService)

local LandService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")

function LandService.buy(player: Player, key: string): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	data.land = data.land or table.clone(Land.START)
	local ok = false
	for _, s in (Land.signs(data.land)) do
		if s.key == key then
			ok = true
		end
	end
	if not ok then
		return false
	end
	local price = Land.nextPrice(data.land)
	if data.money < price then
		remotes.Notify:FireClient(player, "Not enough money", "ff7a7a")
		return false
	end
	data.money -= price
	table.insert(data.land, key)
	;(require(script.Parent.Analytics) :: any).money(player, -price, data.money, "Shop", "land")
	DataService.publish(player)
	remotes.Notify:FireClient(player, "Bought a new plot of land", "7aff9a", "buy")
	return true
end

function LandService.start()
	remotes.BuyLand.OnServerEvent:Connect(function(player, key, at)
		if typeof(key) ~= "string" or typeof(at) ~= "Vector3" then
			return
		end
		-- (standing near that sign: it's on the plot, 2 m in from the edge)
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		if not head or (head.Position - at).Magnitude > 20 or Land.keyAt(at) ~= key then
			return
		end
		LandService.buy(player, key)
	end)
end

return LandService
