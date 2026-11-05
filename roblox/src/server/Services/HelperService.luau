--!strict
-- The little helpers, the Godot game's way:
--   rake  (Player.rake) every pull drags the bark, leaves and bits in front of you (a 1.25 m ball, 1.9 m ahead) a
--         step closer; logs longer than 1.2 m and baskets stay put
--   can   (Player.water / Sapling.water) water a sapling that has taken root: it grows twice as fast for a minute
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Physics = require(script.Parent.Physics)
local Config = require(ReplicatedStorage.Shared.Config)
local ToolService = require(script.Parent.ToolService)

local HelperService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local last: { [Player]: number } = {}
HelperService.WATER_TIME = 60

local function paced(player: Player, tool: any): boolean
	local now = os.clock()
	if now - (last[player] or 0) < tool.cooldown * 0.8 then
		return false
	end
	last[player] = now
	return true
end

function HelperService.rake(player: Player): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return 0
	end
	local fwd = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	fwd = if fwd.Magnitude > 0.01 then fwd.Unit else Vector3.new(0, 0, -1)
	local feet = root.CFrame.Position - Vector3.new(0, 2.5, 0)
	local centre = feet + fwd * 1.9 * M + Vector3.new(0, 0.3 * M, 0)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local roots = {}
	for _, name in { "Loose", "Logs" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(roots, f)
		end
	end
	params.FilterDescendantsInstances = roots
	local n, seen = 0, {}
	for _, p in workspace:GetPartBoundsInRadius(centre, 1.25 * M, params) do
		local b: BasePart = if p.Parent and p.Parent:IsA("BasePart") then p.Parent :: BasePart else p
		if seen[b] or b.Anchored or b:GetAttribute("HeldBy") or b:GetAttribute("Kind") == "basket" then
			continue
		end
		seen[b] = true
		local log = b.Parent
		if b.Name == "Trunk" and log and log:GetAttribute("Kind") == "log" and ((log:GetAttribute("Bands") :: number? or 99) * Config.Tree.bandH > 1.2) then
			continue
		end
		local to = (feet - b.Position) * Vector3.new(1, 0, 1)
		if to.Magnitude < 0.7 * M then
			continue        -- already at your feet
		end
		Physics.take(b :: any)
		b.AssemblyLinearVelocity = to.Unit * math.clamp(to.Magnitude / M * 1.3, 1.2, 2.8) * M + Vector3.new(0, 0.9 * M, 0)
		n += 1
	end
	remotes.Fx:FireAllClients("rake", feet + fwd * 2.2 * M, 0.9 + math.random() * 0.2, -3)
	return n
end

function HelperService.water(player: Player, sapling: BasePart): boolean
	if not sapling:GetAttribute("Rooted") then
		remotes.Notify:FireClient(player, "It has to take root first - leave it on the ground for a moment", "ffd27a")
		return false
	end
	sapling:SetAttribute("Boost", HelperService.WATER_TIME)
	return true
end

function HelperService.start()
	remotes.Rake.OnServerEvent:Connect(function(player)
		local tool = (Config.Tools :: any)[ToolService.current(player)]
		if tool and tool.rake and paced(player, tool) then
			HelperService.rake(player)
		end
	end)
	remotes.Water.OnServerEvent:Connect(function(player, target)
		local tool = (Config.Tools :: any)[ToolService.current(player)]
		if not tool or not tool.water or not paced(player, tool) then
			return
		end
		remotes.Fx:FireAllClients("pour", nil, 1.0, -4)
		if typeof(target) ~= "Instance" then
			return
		end
		local p = target :: Instance
		while p and p.Parent and not (p:IsA("BasePart") and p:GetAttribute("Kind") == "sapling") do
			p = p.Parent :: Instance
		end
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		if p and p:IsA("BasePart") and head and (head.CFrame.Position - p.CFrame.Position).Magnitude < tool.reach * M + 6 then
			HelperService.water(player, p)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		last[p] = nil
	end)
end

return HelperService
