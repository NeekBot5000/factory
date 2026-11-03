--!strict
-- Server entry point: makes the remote events, then starts each service in order.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "StripRequest", "TreeChanged", "Buy", "Fx", "Notify", "Tutorial", "Sold", "Grab", "Equip", "DropTool", "Use", "Open", "NewGame", "Settings", "SawStart", "Sawn", "PhoneShip" } do
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = remotes
end
remotes.Parent = ReplicatedStorage

local services = script:WaitForChild("Services")
local order = { "DataService", "ToolService", "TutorialService", "EconomyService", "InteractService", "TreeService", "LogService", "CarryService", "MachineService", "OilService", "WorldService", "SaplingService", "DeliveryService", "WorldMeshes" }
for _, name in order do
	local svc = require(services:WaitForChild(name)) :: any
	svc.start()
end
