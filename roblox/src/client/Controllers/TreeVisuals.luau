--!strict
-- Draws bark on this client only. An untouched tree is one cheap MeshPart (its "Trunk"). The first time a tree
-- near you loses bark, it switches to panels: one Part per bark panel that's still there, made on this client and
-- never replicated (no network cost), and only for trees within DETAIL_RANGE. Far away, trees go back to their single
-- trunk. With StreamingEnabled, trees outside the streaming radius don't exist on the client at all.
-- (If EditableMesh is available to the experience, it can replace the panel Parts with one mesh per layer.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local BarkGrid = require(ReplicatedStorage.Shared.BarkGrid)

local TreeVisuals = {}
local DETAIL_RANGE = 120
local detailed: { [Model]: Folder } = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local LAYER_COLOR = { [0] = Color3.fromRGB(91, 64, 48), [1] = Color3.fromRGB(181, 101, 58) }

local function build(tree: Model)
	local old = detailed[tree]
	if old then
		old:Destroy()
	end
	local s = tree:GetAttribute("Bark")
	local sectors, bands = tree:GetAttribute("Sectors") :: number or 16, tree:GetAttribute("Bands") :: number or 40
	local g = if typeof(s) == "string" then BarkGrid.decode(sectors, bands, s) else nil
	if not g then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "BarkPanels"
	local base = tree:GetPivot()
	local radius = tree:GetAttribute("Radius") :: number or 1.4
	local height = tree:GetAttribute("Height") :: number or 20
	local bandH = height / bands
	-- each column round the trunk is drawn as runs of the same visible layer, one tall Part per run (a tree with a
	-- patch off is ~40 Parts, not 640). Where both layers are gone, the wooden core (the Trunk's inner cylinder) shows.
	local function visible(i: number, j: number): number
		if BarkGrid.has(g, 0, i, j) then
			return 0
		elseif BarkGrid.has(g, 1, i, j) then
			return 1
		end
		return -1
	end
	for i = 0, sectors - 1 do
		local j = 0
		while j < bands do
			local layer = visible(i, j)
			local j1 = j
			while j1 + 1 < bands and visible(i, j1 + 1) == layer do
				j1 += 1
			end
			if layer >= 0 then
				local r = radius - layer * 0.15
				local w = 2 * math.pi * r / sectors
				local a = (i + 0.5) / sectors * 2 * math.pi
				local h = (j1 - j + 1) * bandH
				local p = Instance.new("Part")
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
				p.Size = Vector3.new(w * 1.02, h, 0.15)
				p.Color = LAYER_COLOR[layer]
				p.Material = Enum.Material.Wood
				p.CFrame = base * CFrame.Angles(0, -a, 0) * CFrame.new(r, j * bandH + h / 2, 0) * CFrame.Angles(0, math.pi / 2, 0)
				p.Parent = folder
			end
			j = j1 + 1
		end
	end
	folder.Parent = tree
	detailed[tree] = folder
	local trunk = tree:FindFirstChild("Trunk") :: BasePart?
	if trunk then
		trunk.Transparency = 1
	end
end

local function drop(tree: Model)
	local f = detailed[tree]
	if f then
		f:Destroy()
		detailed[tree] = nil
	end
	local trunk = tree:FindFirstChild("Trunk") :: BasePart?
	if trunk then
		trunk.Transparency = 0
	end
end

function TreeVisuals.start()
	remotes.TreeChanged.OnClientEvent:Connect(function(tree: Model)
		-- rebuild from the Bark attribute (it has replicated by the time the event arrives, or will next frame)
		task.defer(function()
			if tree.Parent and workspace.CurrentCamera and (tree:GetPivot().Position - workspace.CurrentCamera.CFrame.Position).Magnitude < DETAIL_RANGE then
				build(tree)
			end
		end)
	end)
	-- every couple of seconds: detail for nearby stripped trees, plain trunks for far ones
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 2 then
			return
		end
		acc = 0
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		for _, inst in CollectionService:GetTagged("Tree") do
			local tree = inst :: Model
			local near = (tree:GetPivot().Position - cam.CFrame.Position).Magnitude < DETAIL_RANGE
			if near and not detailed[tree] and tree:GetAttribute("Bark") then
				build(tree)
			elseif not near and detailed[tree] then
				drop(tree)
			end
		end
	end)
end

return TreeVisuals
