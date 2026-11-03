--!strict
-- Picking things up and putting them down. A held part is pulled towards a point in front of the player's camera by
-- an AlignPosition, simulated on the holder's own machine (network ownership), so it feels instant there while the
-- server still decides who may hold what.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestService = require(script.Parent.QuestService)

local CarryService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local holding: { [Player]: BasePart } = {}
CarryService.holding = holding
local REACH = 14

local function drop(player: Player)
	local p = holding[player]
	holding[player] = nil
	-- dropped into the truck bed? (counts for the "carry" quest)
	local truck = workspace:FindFirstChild("Truck_" .. player.UserId) or workspace:FindFirstChild("Truck")
	local bed = truck and truck:FindFirstChild("Bed") :: BasePart?
	if p and bed then
		local lp = bed.CFrame:PointToObjectSpace(p.Position)
		if math.abs(lp.X) < bed.Size.X / 2 + 1 and math.abs(lp.Z) < bed.Size.Z / 2 + 1 and lp.Y > -1 and lp.Y < 8 then
			QuestService.progress(player, "carry", 1)
		end
	end
	if p and p.Parent then
		for _, c in p:GetChildren() do
			if c.Name == "Carry" then
				c:Destroy()
			end
		end
		p:SetAttribute("HeldBy", nil)
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
	if not loose or not p:IsDescendantOf(loose) or p.Anchored or p:GetAttribute("HeldBy") then
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
	remotes.Grab.OnServerEvent:Connect(grab)
	Players.PlayerRemoving:Connect(drop)
end

return CarryService
