--!strict
-- Picking things up and putting them down. A held part is pulled towards a point in front of the player's camera by
-- an AlignPosition, simulated on the holder's own machine (network ownership), so it feels instant there while the
-- server still decides who may hold what.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local holding: { [Player]: BasePart } = {}
local REACH = 14

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
	p:SetNetworkOwner(player)
	holding[player] = p
end

function CarryService.start()
	local grabRemote = Instance.new("RemoteEvent")
	grabRemote.Name = "Grab"
	grabRemote.Parent = remotes
	grabRemote.OnServerEvent:Connect(grab)
	Players.PlayerRemoving:Connect(drop)
end

return CarryService
