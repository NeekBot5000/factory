--!strict
-- Mining, the Godot game's way (Mining.gd, Shaft.gd, Rock.gd, Ore.gd):
--   * a pickaxe (or a rock drill held on it) on the ground digs a shaft straight down: every hit takes it 0.2 m deeper
--     a point of power and throws out a chunk of whatever's at that depth - stone, then copper, then iron (which only
--     a steel pick or the core drill gets out); the hole looks darker the deeper it goes
--   * on a rock, a pickaxe knocks chunks off until it crumbles away; a sledgehammer bursts a small rock in one blow
--   * a chunk is a real thing: carry it, sell it in the truck (stone 0.40, copper ore 3, iron ore 6, by size), or
--     drop it into a build
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Mining = require(ReplicatedStorage.Shared.Mining)
local W = require(ReplicatedStorage.Shared.GodotWorld) :: any
local ToolService = require(script.Parent.ToolService)
local WorldService = require(script.Parent.WorldService)

local MiningService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local lastHit: { [Player]: number } = {}
type Rock = { at: Vector3, s: number, ore: string, hidden: string, hp: number, max: number }
local rocks: { [number]: Rock } = {}

local function loose(): Instance
	local f = workspace:FindFirstChild("Loose")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Loose"
		f.Parent = workspace
	end
	return f :: Instance
end

-- a chunk of ore (Ore.setup): Godot's mesh for its kind, scaled to its size; stone flecked with copper or iron
function MiningService.chunk(kind: string, size: number, at: Vector3, vel: Vector3, owner: number?): BasePart
	local d = Mining.KINDS[kind] or Mining.KINDS.stone
	local root = Instance.new("Part")
	root.Name = "Ore"
	root.Size = Vector3.new(size * 1.9, size * 1.4, size * 1.7) * M
	root.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6.3, math.random() * 6.3, 0)
	root.Color = Color3.fromHex(d.color)
	root.Material = Enum.Material.SmoothPlastic
	root.CustomPhysicalProperties = PhysicalProperties.new(2.7, 0.9, 0.05)       -- (stone: grippy, hardly bounces)
	root:SetAttribute("Kind", "ore")
	root:SetAttribute("Ore", kind)
	root:SetAttribute("Value", math.floor(d.value * (size / 0.14) * 100 + 0.5) / 100)
	if owner then
		root:SetAttribute("Owner", owner)
	end
	local props = ReplicatedStorage:FindFirstChild("Props")
	local src = props and props:FindFirstChild("ore_" .. kind)
	if src then
		-- Godot's lumpy chunk on show; the box is what it rests on
		root.Transparency = 1
		local m = (src :: Model):Clone()
		m:ScaleTo(size / 0.14)
		m:PivotTo(root.CFrame)
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.CanCollide = false
				p.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = p
				w.Parent = p
				p.Parent = root
			end
		end
		m:Destroy()
	end
	root.Parent = loose()
	root.AssemblyLinearVelocity = vel
	root.AssemblyAngularVelocity = Vector3.new(math.random() * 12 - 6, math.random() * 12 - 6, math.random() * 12 - 6)
	return root
end

-- ------------------------------------------------------------------ shafts
local function shaftAt(cell: Vector3): Model?
	local f = workspace:FindFirstChild("Shafts")
	for _, s in if f then f:GetChildren() else {} do
		local p = (s :: Model):GetPivot().Position
		if Vector2.new(p.X - cell.X, p.Z - cell.Z).Magnitude < 0.5 * M then
			return s :: Model
		end
	end
	return nil
end

local function newShaft(cell: Vector3): Model
	local f = workspace:FindFirstChild("Shafts") or Instance.new("Folder")
	f.Name = "Shafts"
	f.Parent = workspace
	local props = ReplicatedStorage:FindFirstChild("Props")
	local src = props and props:FindFirstChild("shaft")
	local m: Model
	if src then
		m = (src :: Model):Clone()
	else
		m = Instance.new("Model")
		for k = 1, 4 do
			local side = ({ Vector3.new(0, 0, 0.45), Vector3.new(0, 0, -0.45), Vector3.new(0.45, 0, 0), Vector3.new(-0.45, 0, 0) })[k]
			local sz = if k <= 2 then Vector3.new(1.0, 0.16, 0.12) else Vector3.new(0.12, 0.16, 0.78)
			local p = Instance.new("Part")
			p.Size = sz * M
			p.CFrame = CFrame.new((side + Vector3.new(0, 0.06, 0)) * M)
			p.Color = Color3.fromHex("7d7a73")
			p.Parent = m
		end
		local pit = Instance.new("Part")
		pit.Size = Vector3.new(0.78, 0.02, 0.78) * M
		pit.CFrame = CFrame.new(0, 0.02 * M, 0)
		pit.Color = Color3.fromHex("3a2c20")
		pit.Parent = m
	end
	m.Name = "Shaft"
	m.WorldPivot = CFrame.new()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.Material = Enum.Material.SmoothPlastic
			if p.Color:ToHex() == "3a2c20" or p.Size.Y < 0.1 * M then
				p.Name = "Pit"
			end
		end
	end
	m:SetAttribute("Kind", "shaft")
	m:SetAttribute("Depth", 0)
	m:PivotTo(CFrame.new(cell))
	m.Parent = f
	return m
end

function MiningService.dig(player: Player?, at: Vector3, power: number, tier: number): string?
	-- (a 1 m grid square, on the ground)
	local cell = Vector3.new(math.round(at.X / M) * M, 0, math.round(at.Z / M) * M)
	cell = Vector3.new(cell.X, WorldService.heightAt(cell.X, cell.Z), cell.Z)
	local shaft = shaftAt(cell) or newShaft(cell)
	local depth = shaft:GetAttribute("Depth") :: number
	if depth >= Mining.MAX_DEPTH then
		remotes.Fx:FireAllClients("clink", cell, 0.8, -4)
		return nil
	end
	depth = math.min(Mining.MAX_DEPTH, depth + 0.2 * power)
	shaft:SetAttribute("Depth", depth)
	local kind = Mining.roll(cell.X, cell.Z, depth, tier)
	MiningService.chunk(kind, 0.11 + math.random() * 0.05, cell + Vector3.new(math.random() * 0.4 - 0.2, 0.45, math.random() * 0.4 - 0.2) * M,
		Vector3.new(math.random() * 3 - 1.5, 3, math.random() * 3 - 1.5) * M, player and player.UserId)
	remotes.Fx:FireAllClients(if kind ~= "stone" then "crack" else "gravel", cell, 0.85 + math.random() * 0.25, 0)
	-- the deeper it is, the darker the hole looks
	local pit = shaft:FindFirstChild("Pit", true) :: BasePart?
	if pit then
		pit.Color = Color3.fromHex("3a2c20"):Lerp(Color3.fromHex("080604"), math.clamp(depth / 6, 0, 1))
	end
	return kind
end

-- ------------------------------------------------------------------ rocks
local function rockMeshes(i: number): { BasePart }
	local out = {}
	local world = workspace:FindFirstChild("GodotWorld")
	for _, p in if world then world:GetChildren() else {} do
		if p:IsA("BasePart") and (string.match(p.Name, "^rock_(%d+)_") == tostring(i)) then
			table.insert(out, p)
		end
	end
	return out
end

local function chunkKind(r: Rock, tier: number): string
	if r.hidden ~= "" then
		if r.hidden == "iron" and tier < 2 then
			return "stone"
		end
		return if math.random() < 0.5 then r.hidden else "stone"
	end
	return if r.ore == "stone" or math.random() < 0.7 then r.ore else "stone"
end

local function shrink(i: number, r: Rock)
	local k = math.clamp(r.hp / r.max, 0, 1)
	local f = 0.45 + 0.55 * k
	for _, p in rockMeshes(i) do
		local home = p:GetAttribute("HomeCF") :: CFrame?
		local size = p:GetAttribute("HomeSize") :: Vector3?
		if not home or not size then
			p:SetAttribute("HomeCF", p.CFrame)
			p:SetAttribute("HomeSize", p.Size)
			home, size = p.CFrame, p.Size
		end
		local rel = (home :: CFrame).Position - r.at
		p.Size = (size :: Vector3) * f
		p.CFrame = CFrame.new(r.at + rel * f) * ((home :: CFrame) - (home :: CFrame).Position)
	end
end

local function crumble(i: number, r: Rock)
	for _, p in rockMeshes(i) do
		p:Destroy()
	end
	local solids = workspace:FindFirstChild("Solids")
	local box = solids and solids:FindFirstChild("Rock_" .. i)
	if box then
		box:Destroy()
	end
	rocks[i] = nil
	remotes.Fx:FireAllClients("crumble", r.at, 1.0, 2)
end

function MiningService.hitRock(player: Player?, i: number, pos: Vector3, normal: Vector3, tool: any): boolean
	local r = rocks[i]
	if not r then
		return false
	end
	local power, tier = tool.mine or 0, tool.tier or 1
	if power <= 0 then
		return false
	end
	remotes.Fx:FireAllClients("crack", pos, 0.85 + math.random() * 0.25)
	if r.ore == "iron" and tier < 2 then
		if player then
			remotes.Notify:FireClient(player, "Too hard - needs a steel pickaxe or core drill", "ffd27a")
		end
		return false
	end
	local owner = player and player.UserId
	-- a sledgehammer bursts a small rock in one blow: every chunk left in it flies out
	if (tool.smash or 0) >= r.s then
		local n = math.clamp(r.hp + 1, 2, 10)
		for k = 0, n - 1 do
			local a = 2 * math.pi * k / n + math.random() * 0.5
			local dir = Vector3.new(math.cos(a), 0.4 + math.random() * 0.6, math.sin(a)).Unit
			MiningService.chunk(chunkKind(r, tier), 0.11 + math.random() * 0.06, r.at + (dir * r.s * 0.5 + Vector3.new(0, r.s * 0.2, 0)) * M,
				(dir * (1.5 + math.random()) + Vector3.new(0, 1.5, 0)) * M, owner)
		end
		crumble(i, r)
		return true
	end
	r.hp -= power
	MiningService.chunk(chunkKind(r, tier), 0.11 + math.random() * 0.06, pos + normal * 0.2 * M,
		(normal * (1.5 + math.random()) + Vector3.new(math.random() * 1.2 - 0.6, 1.5, math.random() * 1.2 - 0.6)) * M, owner)
	if r.hp <= 0 then
		for k = 0, 1 do
			MiningService.chunk(if k == 0 then chunkKind(r, tier) else "stone", 0.11 + math.random() * 0.06, r.at + Vector3.new(0, r.s * 0.3 * M, 0),
				Vector3.new(math.random() * 2 - 1, 2.5, math.random() * 2 - 1) * M, owner)
		end
		crumble(i, r)
	else
		shrink(i, r)
	end
	return true
end

local function onMine(player: Player, target: unknown, pos: unknown, normal: unknown)
	if typeof(pos) ~= "Vector3" or typeof(normal) ~= "Vector3" then
		return
	end
	local tool = (Config.Tools :: any)[ToolService.current(player)]
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not tool or (tool.mine or 0) <= 0 or not head or (head.Position - (pos :: Vector3)).Magnitude > tool.reach * M + 5 then
		return
	end
	local now = os.clock()
	if now - (lastHit[player] or 0) < tool.cooldown * 0.8 then
		return
	end
	lastHit[player] = now
	local inst = if typeof(target) == "Instance" then target :: Instance else nil
	local rockIdx = inst and inst:GetAttribute("Rock")
	if typeof(rockIdx) == "number" then
		MiningService.hitRock(player, rockIdx, pos :: Vector3, (normal :: Vector3).Unit, tool)
		return
	end
	-- the ground (or a shaft): dig. (Not on the cabin, the porch or a build.)
	local shaft = inst and inst:FindFirstAncestorWhichIsA("Model")
	local onShaft = shaft ~= nil and shaft:GetAttribute("Kind") == "shaft"
	local onGround = inst == workspace.Terrain or (inst ~= nil and inst:GetAttribute("Ground") == true)
	if onShaft or onGround then
		MiningService.dig(player, if onShaft then (shaft :: Model):GetPivot().Position else pos :: Vector3, tool.mine, tool.tier or 1)
	end
end

function MiningService.start()
	for i, r in W.rocks or {} do
		local at = Vector3.new(r.at[1], r.at[2], r.at[3])
		rocks[i - 1] = { at = at, s = r.s, ore = r.ore, hidden = r.hidden, hp = r.hp, max = r.hp }
	end
	remotes.Mine.OnServerEvent:Connect(onMine)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		lastHit[p] = nil
	end)
end

function MiningService.rock(i: number): Rock?
	return rocks[i]
end

return MiningService
