--!strict
-- Starts the server: makes the remote events, then starts each service in order. The server Script runs it; so
-- does the engine check (tests/engine/run.luau), since Roblox doesn't run a place's scripts in an Open Cloud Luau
-- execution session. Starting twice does nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boot = {}
local started = false

function Boot.start()
	if started or ReplicatedStorage:FindFirstChild("Remotes") then
		return
	end
	started = true

	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	for _, name in { "StripRequest", "TreeChanged", "Buy", "Fx", "Notify", "Tutorial", "Sold", "Grab", "Equip", "DropTool", "Use", "Open", "NewGame", "Settings", "SawStart", "Sawn", "PhoneShip", "Snip", "Vacuum", "Build", "PlanCancel", "TakeDown", "BuyLand", "Click", "Lie", "Mine", "Rake", "Water", "UseMachine", "Wire", "Hammer", "Plant", "Redeem" } do
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = remotes
	end
	remotes.Parent = ReplicatedStorage

	local services = script.Parent:WaitForChild("Services")
	local order = { "DataService", "ToolService", "TutorialService", "EconomyService", "InteractService", "TreeService", "LogService", "CarryService", "MachineService", "OilService", "WorldService", "SaplingService", "VacuumService", "SignService", "LandService", "BuildService", "BuildBehaviors", "CircuitService", "ProductionService", "FactoryService", "RailService", "DroneService", "MiningService", "HelperService", "TrophyService", "EventService", "LeaderboardService", "DeliveryService", "WorldMeshes" }
	for _, name in order do
		local svc = require(services:WaitForChild(name)) :: any
		svc.start()
	end
end

return Boot
