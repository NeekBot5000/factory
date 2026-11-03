--!strict
-- E on things (Godot's on_use): the client says what it's looking at, the server checks it's close enough and
-- does it. The truck ships, the chopping block gives you its hatchet, a tool you put down comes back to your hand.
-- (Bark and other loose things are picked up through CarryService's Grab instead.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local ToolService = require(script.Parent.ToolService)
local EconomyService = require(script.Parent.EconomyService)
local TutorialService = require(script.Parent.TutorialService)

local InteractService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local REACH = Config.Player.grabReach * Config.StudsPerMetre + 6     -- a little slack for lag

local function near(player: Player, part: BasePart): boolean
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not head then
		return false
	end
	-- distance to the closest point of the part's box, so big things (the truck) work from any side
	local lp = part.CFrame:PointToObjectSpace(head.Position)
	local half = part.Size / 2
	local closest = Vector3.new(math.clamp(lp.X, -half.X, half.X), math.clamp(lp.Y, -half.Y, half.Y), math.clamp(lp.Z, -half.Z, half.Z))
	return (lp - closest).Magnitude <= REACH
end

local function use(player: Player, target: unknown)
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("BasePart") then
		return
	end
	local part = target :: BasePart
	if not near(player, part) then
		return
	end
	-- a tool you put down
	local item = part:FindFirstAncestorWhichIsA("Model")
	while item and item:GetAttribute("Kind") ~= "tool" do
		item = item:FindFirstAncestorWhichIsA("Model")
	end
	if item then
		if ToolService.pickUp(player, item) then
			remotes.Fx:FireClient(player, "pickup")
		end
		return
	end
	-- the tool rising out of an opened box
	local pickup = part:FindFirstAncestorWhichIsA("Model")
	while pickup and pickup:GetAttribute("Kind") ~= "pickup" do
		pickup = pickup:FindFirstAncestorWhichIsA("Model")
	end
	if pickup then
		local Delivery = require(script.Parent.DeliveryService) :: any
		Delivery.take(player, pickup)
		return
	end
	local truck = workspace:FindFirstChild("Truck")
	if truck and part:IsDescendantOf(truck) then
		EconomyService.ship(player)
		return
	end
	-- the block, or the hatchet stuck in it
	if part:FindFirstAncestor("ChoppingBlock") then
		local data = DataService.get(player)
		if data and not data.owned.hatchet then
			ToolService.grant(player, "hatchet")
			remotes.Fx:FireClient(player, "pickup")
			TutorialService.check(player)
		end
	end
end

function InteractService.start()
	remotes.Use.OnServerEvent:Connect(use)
end

return InteractService
