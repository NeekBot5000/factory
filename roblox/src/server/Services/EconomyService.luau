--!strict
-- Money, the shop and the truck. Everything that changes money happens here, on the server: the client only
-- asks ("buy the hatchet", "ship the truck") and is told the result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local EconomyService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")

function EconomyService.addMoney(player: Player, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.money = math.floor((data.money + amount) * 100 + 0.5) / 100
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		(ls:FindFirstChild("Money") :: NumberValue).Value = data.money
	end
end

local function setupLeaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local money = Instance.new("NumberValue")
	money.Name = "Money"
	money.Parent = ls
	ls.Parent = player
	task.spawn(function()
		while player.Parent and not DataService.get(player) do
			task.wait(0.5)
		end
		local data = DataService.get(player)
		if data then
			money.Value = data.money
		end
	end)
end

-- Ship: sells every loose thing in the truck bed that belongs to this player (the value lives in an attribute
-- the server set when it made the part, so a client can't change it).
local function ship(player: Player)
	local truck = workspace:FindFirstChild("Truck_" .. player.UserId)
	if not truck then
		return
	end
	local bed = (truck :: Model):FindFirstChild("Bed") :: BasePart
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace:FindFirstChild("Loose") :: Instance }
	local total = 0
	for _, part in workspace:GetPartBoundsInBox(bed.CFrame * CFrame.new(0, 2, 0), bed.Size + Vector3.new(0, 4, 0), params) do
		local v = part:GetAttribute("Value")
		if typeof(v) == "number" and part:GetAttribute("Owner") == player.UserId then
			total += v
			part:Destroy()
		end
	end
	if total > 0 then
		EconomyService.addMoney(player, total)
		remotes.Notify:FireClient(player, string.format("Sold for $%.2f", total))
	end
end

local function buy(player: Player, item: unknown)
	if typeof(item) ~= "string" then
		return
	end
	local def = Config.Tools[item :: string]
	local data = DataService.get(player)
	if not def or not data or data.owned[item] or data.money < def.price then
		return
	end
	EconomyService.addMoney(player, -def.price)
	data.owned[item] = true
	remotes.Notify:FireClient(player, "Bought the " .. def.name)
end

function EconomyService.start()
	Players.PlayerAdded:Connect(setupLeaderstats)
	for _, p in Players:GetPlayers() do
		setupLeaderstats(p)
	end
	remotes.Ship.OnServerEvent:Connect(ship)
	remotes.Buy.OnServerEvent:Connect(buy)
end

return EconomyService
