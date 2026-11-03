--!strict
-- Picking things up and putting them down. A held part is pulled towards a point in front of the player's camera by
-- an AlignPosition, simulated on the holder's own machine (network ownership), so it feels instant there while the
-- server still decides who may hold what.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EconomyService = require(script.Parent.EconomyService)
local TutorialService = require(script.Parent.TutorialService)

local CarryService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local holding: { [Player]: BasePart } = {}
CarryService.holding = holding
local REACH = Config.Player.grabReach * Config.StudsPerMetre + 6   -- Godot's grab reach, plus slack for lag

local function drop(player: Player)
	local p = holding[player]
	holding[player] = nil
	if p and p.Parent then
		for _, c in p:GetChildren() do
			if c.Name == "Carry" then
				c:Destroy()
			end
		end
		p:SetAttribute("HeldBy", nil)
	end
	-- (it may have landed in the truck: the tutorial checks in a moment, once it has settled)
	task.delay(1, TutorialService.check, player)
end

-- lets go of a part whoever is holding it (the truck drives off with it)
function CarryService.release(part: BasePart)
	for player, p in holding do
		if p == part then
			drop(player)
		end
	end
end

local function grab(player: Player, target: unknown)
	if holding[player] then
		drop(player)
		return
	end
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("BasePart") then
		return
	end
	local p = target :: BasePart
	local loose = workspace:FindFirstChild("Loose")
	-- (a sheet of several panels: the panels ride on the first one, which is the sheet)
	if loose and p.Parent and p.Parent:IsA("BasePart") and p.Parent.Parent == loose then
		p = p.Parent :: BasePart
	end
	-- a log you can lift (3 m or shorter, without its crown: Godot's Log.CARRY_MAX)
	local log = p.Parent
	local liftable = log and log:GetAttribute("Kind") == "log" and p.Name == "Trunk" and not log:GetAttribute("HasCrown")
		and (log:GetAttribute("Bands") :: number) * Config.Tree.bandH <= Config.Saw.carryMax
	local logs = workspace:FindFirstChild("Logs")
	local inLoose = loose ~= nil and p:IsDescendantOf(loose) and p.Parent == loose
	local inLogs = logs ~= nil and p:IsDescendantOf(logs) and liftable
	if not (inLoose or inLogs) or p.Anchored or p:GetAttribute("HeldBy") then
		return
	end
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not head or (head.Position - p.Position).Magnitude > REACH then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "Carry"
	att.Parent = p
	local align = Instance.new("AlignPosition")
	align.Name = "Carry"
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.MaxForce = 20000
	align.Responsiveness = 40
	align.Position = head.Position
	align.Parent = p
	p:SetAttribute("HeldBy", player.UserId)
	pcall(function()
		p:SetNetworkOwner(player)
	end)
	holding[player] = p
end

function CarryService.start()
	EconomyService.release = CarryService.release
	remotes.Grab.OnServerEvent:Connect(grab)
	Players.PlayerRemoving:Connect(drop)
end

return CarryService
