--!strict
-- Grab / drop (E, X on a gamepad, or the Grab button on touch). Aims from the screen centre like the tools.
-- While holding, it keeps moving the carry point in front of the camera; the held part is simulated on this
-- machine (the server gave us network ownership), so it follows with no lag.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local InputController = require(script.Parent.InputController)

local CarryController = {}
local player = Players.LocalPlayer
local HOLD_DIST = 7

local function held(): BasePart?
	local loose = workspace:FindFirstChild("Loose")
	if not loose then
		return nil
	end
	for _, p in loose:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("HeldBy") == player.UserId then
			return p
		end
	end
	return nil
end

local function aimed(): BasePart?
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character :: Instance }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 30, params)
	return if hit and hit.Instance:IsA("BasePart") then hit.Instance :: BasePart else nil
end

function CarryController.start()
	local grab = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Grab") :: RemoteEvent
	InputController.on("Grab", function(state)
		if state ~= Enum.UserInputState.Begin then
			return
		end
		if held() then
			grab:FireServer(nil)       -- drop
		else
			grab:FireServer(aimed())
		end
	end)
	RunService.RenderStepped:Connect(function()
		local p = held()
		if not p then
			return
		end
		local align = p:FindFirstChildOfClass("AlignPosition")
		local cam = workspace.CurrentCamera
		if align and cam then
			align.Position = cam.CFrame.Position + cam.CFrame.LookVector * HOLD_DIST
		end
	end)
end

return CarryController
