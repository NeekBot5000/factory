--!strict
-- Swinging. Aims from the centre of the screen (a crosshair), which works the same in first person, third person,
-- on touch and on a gamepad. The swing's feel (sound, particles, camera kick) happens on this client straight away;
-- the server decides what actually comes off and tells everyone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage.Shared.Config)
local InputController = require(script.Parent.InputController)

local ToolController = {}
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local current = "hands"
local last = 0

local function treeOf(inst: Instance?): Model?
	while inst and inst ~= workspace do
		if inst:IsA("Model") and CollectionService:HasTag(inst, "Tree") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

local function swing()
	local tool = Config.Tools[current]
	if not tool or os.clock() - last < tool.cooldown then
		return
	end
	last = os.clock()
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character :: Instance }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 40, params)
	if not hit then
		return
	end
	local tree = treeOf(hit.Instance)
	if tree then
		remotes.StripRequest:FireServer(tree, hit.Position, current)
	end
end

function ToolController.equip(id: string)
	current = id
end

function ToolController.start()
	InputController.on("Swing", function(state)
		if state == Enum.UserInputState.Begin then
			swing()
		end
	end)
end

return ToolController
