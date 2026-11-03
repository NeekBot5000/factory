--!strict
-- The hammer's build mode, the Godot game's way (Builder.gd, BuildMenu.gd). Click with the hammer to open the build
-- menu (categories down the side, cards with a turning preview, the name and what it needs; the machines need their
-- blueprint from TimberMart). Pick something and its hologram follows your aim: R turns it (45 degrees; machines 90,
-- on a 1 m grid), the mouse wheel makes it bigger or smaller (bigger costs more), a click sets it down, E cancels.
-- It's blue where it can go and red where it can't (not on a trunk or the truck, not on a slope, not off your land).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage.Shared.Config)
local Builds = require(ReplicatedStorage.Shared.Builds)
local Land = require(ReplicatedStorage.Shared.Land)
local Rail = require(ReplicatedStorage.Shared.Rail)
local W = require(ReplicatedStorage.Shared.GodotWorld) :: any
local InputController = require(script.Parent.InputController)
local UiKit = require(script.Parent.Parent.Ui.UiKit)
local State = require(script.Parent.Parent.State)
local Sfx = require(script.Parent.Parent.Sfx)

local BuildController = {}
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local GB = Builds.data
local OK_COLOR, BAD_COLOR = Color3.new(0.45, 0.85, 1.0), Color3.new(1.0, 0.35, 0.3)

local mode = "idle"            -- idle | place
local buildId = "basket"
local sizeI = 3                -- index into Godot's SIZES (1.0x)
local turn = 0
local holo: Model? = nil
local valid = false
local offLand = false
local onRails = true
local menu: ScreenGui? = nil
local spinning: { { cam: Camera, center: Vector3, dist: number } } = {}
local rotatorAimed: () -> BasePart?
local railAimed: () -> BasePart?

local function size(): number
	return GB.sizes[sizeI]
end

local function owned(): { [string]: boolean }
	local out = {}
	for _, id in string.split(player:GetAttribute("Owned") :: string? or "", ",") do
		out[id] = true
	end
	return out
end

local function hint(): string
	if mode ~= "place" then
		return ""
	end
	if offLand then
		return "This isn't your land - buy it at a for-sale sign    [E] cancel"
	end
	if not onRails then
		return "A minecart goes on rails, along the track, with rail under every square of it    [R] turn    [E] cancel"
	end
	local def = Builds.def(buildId)
	if def and def.fixed then
		return "[R] turn    [Click] place    [E] cancel"
	end
	return string.format("[R] turn    [Scroll] size %sx    [Click] place    [E] cancel", tostring(size()))
end

function BuildController.cancel()
	if holo then
		holo:Destroy()
		holo = nil
	end
	mode = "idle"
	State.placing = false
	State.buildHint = nil
end

local function paint(ok: boolean)
	if not holo then
		return
	end
	for _, p in holo:GetDescendants() do
		if p:IsA("BasePart") then
			p.Color = if ok then OK_COLOR else BAD_COLOR
		end
	end
end

local function makeHolo()
	if holo then
		holo:Destroy()
	end
	local m = Builds.model(buildId)
	if not m then
		return
	end
	m:ScaleTo(size())
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 0.68
			p.CastShadow = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	-- the counter over it: what it will need at this size
	local def = Builds.def(buildId) :: Builds.Def
	local anchor = Instance.new("Part")
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(0, def.top * size() + 0.35 * M, 0)
	anchor.Parent = m
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(420, 40)
	bb.AlwaysOnTop = true
	bb.Adornee = anchor
	bb.Parent = anchor
	UiKit.label(bb, Builds.needsText(Builds.needsFor(buildId, size()), buildId), 22, Color3.fromHex("bfeaff"), UiKit.Title,
		{ Size = UDim2.fromScale(1, 1), TextScaled = true, TextStrokeTransparency = 0.15, TextStrokeColor3 = Color3.new(0.05, 0.08, 0.12) })
	m.Name = "Hologram"
	m.Parent = workspace.CurrentCamera
	holo = m
	paint(true)
end

function BuildController.start_(id: string)
	buildId = id
	sizeI = table.find(GB.sizes, 1) or 3
	turn = 0
	mode = "place"
	State.placing = true
	makeHolo()
	Sfx.play("click")
end

-- ------------------------------------------------------------------ the menu
function BuildController.closeMenu()
	if menu then
		menu:Destroy()
		menu = nil
		State.uiOpen = false
		table.clear(spinning)
	end
end

local RES_COLOR = { bark = "a0703c", log = "6b4a32", leaf = "4f9a3c", stone = "7d7a73", copper = "c8703a", iron = "6d7180",
	plank = "c69a62", copper_bar = "d9783a", iron_bar = "8d949e" }

local function openMenu()
	BuildController.closeMenu()
	State.uiOpen = true
	Sfx.play("click")
	local gui = Instance.new("ScreenGui")
	gui.Name = "BuildMenu"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ResetOnSpawn = false
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.65
	dim.BorderSizePixel = 0
	dim.Parent = gui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(1120, 640)
	panel.BackgroundColor3 = Color3.new(0.08, 0.09, 0.12)
	panel.BackgroundTransparency = 0.06
	panel.BorderSizePixel = 0
	panel.Parent = gui
	UiKit.corner(panel, 18)
	UiKit.pad(panel, 22, 22)
	local accent = Color3.fromHex("ffcf6a")
	UiKit.label(panel, "Build", 34, accent, UiKit.Title, { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0.4, 0, 0, 40) })
	UiKit.label(panel, "Pick a plan, then drop the materials into its hologram.   [E] close", 14, Color3.new(0.55, 0.55, 0.55), UiKit.Body,
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 10), Size = UDim2.new(0.6, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Right })
	local side = Instance.new("ScrollingFrame")
	side.Position = UDim2.fromOffset(0, 56)
	side.Size = UDim2.new(0, 190, 1, -56)
	side.BackgroundTransparency = 1
	side.BorderSizePixel = 0
	side.ScrollBarThickness = 4
	side.AutomaticCanvasSize = Enum.AutomaticSize.Y
	side.CanvasSize = UDim2.new()
	side.Parent = panel
	local sl = Instance.new("UIListLayout")
	sl.Padding = UDim.new(0, 8)
	sl.SortOrder = Enum.SortOrder.LayoutOrder
	sl.Parent = side
	local grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(208, 56)
	grid.Size = UDim2.new(1, -208, 1, -56)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(275, 250)
	gl.CellPadding = UDim2.fromOffset(14, 14)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	local cat = 0
	local mine = owned()
	local render: () -> ()
	local function sideButton(text: string, on: boolean, order: number, cb: () -> ())
		local b = UiKit.button(side, text, if on then accent else Color3.new(1, 1, 1), if on then Color3.fromHex("2b2118") else Color3.new(1, 1, 1), function()
			Sfx.play("click")
			cb()
		end, { Size = UDim2.new(1, -6, 0, 38), LayoutOrder = order, BackgroundTransparency = if on then 0 else 0.94, TextXAlignment = Enum.TextXAlignment.Left })
		UiKit.pad(b, 12, 0)
	end
	local function card(id: string, order: number)
		local def = Builds.def(id) :: Builds.Def
		local open = Builds.unlocked(id, mine)
		local c = Instance.new("TextButton")
		c.Text = ""
		c.AutoButtonColor = false
		c.BackgroundColor3 = Color3.new(1, 1, 1)
		c.BackgroundTransparency = 0.94
		c.LayoutOrder = order
		c.Parent = grid
		UiKit.corner(c, 14)
		UiKit.pad(c, 12, 12)
		c.MouseEnter:Connect(function()
			c.BackgroundColor3 = Color3.new(1, 0.81, 0.42)
			c.BackgroundTransparency = 0.78
		end)
		c.MouseLeave:Connect(function()
			c.BackgroundColor3 = Color3.new(1, 1, 1)
			c.BackgroundTransparency = 0.94
		end)
		c.Activated:Connect(function()
			if open then
				BuildController.closeMenu()
				BuildController.start_(id)
			else
				Sfx.play("thud", 1.4, -6)
			end
		end)
		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.new(1, 0, 1, -64)
		vp.BackgroundColor3 = Color3.new(1, 1, 1)
		vp.BackgroundTransparency = 0.95
		vp.Ambient = Color3.fromRGB(190, 190, 190)
		vp.LightDirection = Vector3.new(-1, -1, -1)
		vp.ImageTransparency = if open then 0 else 0.55
		vp.Parent = c
		UiKit.corner(vp, 10)
		local m = Builds.model(id)
		if m then
			m.Parent = vp
			local cf, sz = m:GetBoundingBox()
			local cam = Instance.new("Camera")
			cam.FieldOfView = 30
			cam.Parent = vp
			vp.CurrentCamera = cam
			table.insert(spinning, { cam = cam, center = cf.Position, dist = sz.Magnitude * 1.9 })
		end
		UiKit.label(c, def.name, 19, Color3.new(1, 1, 1), UiKit.Bold, { Position = UDim2.new(0, 0, 1, -58), Size = UDim2.new(1, 0, 0, 24), TextTransparency = if open then 0 else 0.55 })
		if not open then
			UiKit.label(c, "Blueprint at TimberMart", 13, accent, UiKit.Bold, { Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 20) })
			return
		end
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.new(0, 0, 1, -28)
		row.Size = UDim2.new(1, 0, 0, 24)
		row.Parent = c
		local rl = Instance.new("UIListLayout")
		rl.FillDirection = Enum.FillDirection.Horizontal
		rl.Padding = UDim.new(0, 6)
		rl.SortOrder = Enum.SortOrder.LayoutOrder
		rl.Parent = row
		local k = 0
		for _, r in (def :: any).needsOrder or Builds.RES_ORDER do
			local n = def.needs[r]
			if n then
				k += 1
				local pill = UiKit.label(row, string.format("%d %s", n, GB.resName[r] or r), 13, Color3.new(1, 1, 1), UiKit.Bold,
					{ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex(RES_COLOR[r] or "888888"), LayoutOrder = k })
				UiKit.corner(pill, 8)
				UiKit.pad(pill, 6, 0)
			end
		end
	end
	render = function()
		for _, c in side:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, c in grid:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		table.clear(spinning)
		sideButton(string.format("All  (%d)", #GB.order), cat == 0, 0, function()
			cat = 0
			render()
		end)
		for i, c in GB.categories do
			sideButton(string.format("%s  (%d)", c.name, #c.items), cat == i, i, function()
				cat = i
				render()
			end)
		end
		local items = if cat == 0 then GB.order else GB.categories[cat].items
		for k, id in items do
			card(id, k)
		end
	end
	render()
	gui.Parent = player:WaitForChild("PlayerGui")
	menu = gui
end

-- ------------------------------------------------------------------ placing
local function treeOf(inst: Instance?): boolean
	while inst and inst ~= workspace do
		if CollectionService:HasTag(inst, "Tree") or inst.Name == "Truck" or inst.Name == "Van" then
			return true
		end
		inst = inst.Parent
	end
	return false
end

local function heightAt(x: number, z: number): number
	local g = W.ground
	local fx = math.clamp((x - g.origin) / g.step, 0, g.n - 1.001)
	local fz = math.clamp((z - g.origin) / g.step, 0, g.n - 1.001)
	local ix, iz = math.floor(fx), math.floor(fz)
	local tx, tz = fx - ix, fz - iz
	local function h(i: number, k: number): number
		return g.heights[k * g.n + i + 1]
	end
	local a = h(ix, iz) + (h(ix + 1, iz) - h(ix, iz)) * tx
	local b = h(ix, iz + 1) + (h(ix + 1, iz + 1) - h(ix, iz + 1)) * tx
	return a + (b - a) * tz
end

function BuildController.update()
	if mode ~= "place" or not holo then
		return
	end
	local cam = workspace.CurrentCamera
	local fwd = cam.CFrame.LookVector
	local flat = Vector3.new(fwd.X, 0, fwd.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local params = RaycastParams.new()
	local ignore: { Instance } = { cam }
	for _, name in { "Loose", "Logs", "MyLand" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(cam.CFrame.Position, fwd * Builds.REACH * math.max(1, size()) * M, params)
	local pos = cam.CFrame.Position + fwd * 4 * M
	valid = false
	if hit then
		pos = hit.Position
		valid = hit.Normal.Y > 0.75 and not treeOf(hit.Instance)
	else
		pos = Vector3.new(pos.X, heightAt(pos.X, pos.Z), pos.Z)
	end
	local def = Builds.def(buildId) :: Builds.Def
	if def.fixed then
		-- machines sit on a 1 m grid and face one of the four directions, so belts line up end to end
		pos = Vector3.new(math.round(pos.X / M) * M, pos.Y, math.round(pos.Z / M) * M)
		local a = math.round(math.atan2(flat.X, flat.Z) / (math.pi / 2)) * (math.pi / 2)
		flat = Vector3.new(math.sin(a), 0, math.cos(a))
	end
	local land = string.split(player:GetAttribute("Land") :: string? or table.concat(Land.START, ";"), ";")
	offLand = not Land.owns(land, pos)
	if offLand then
		valid = false
	end
	local cf = CFrame.lookAt(pos, pos + flat) * CFrame.Angles(0, turn, 0)
	onRails = true
	if string.sub(buildId, 1, 9) == "minecart_" then
		-- a cart goes on rails that run its way, under every square of it
		local c = Rail.cellOf(pos)
		onRails = Rail.fits(c, Rail.dirOf(cf), tonumber(string.sub(buildId, 10)) or 1)
		if onRails then
			cf = cf.Rotation + Rail.centre(c, Rail.top(Rail.at(c) :: Model))
		else
			valid = false
		end
	end
	holo:PivotTo(cf)
	paint(valid)
	State.buildHint = hint()
end

function rotatorAimed(): BasePart?
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character :: Instance, cam }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 3 * M, params)
	if not hit then
		return nil
	end
	local part = hit.Instance
	local m = part:FindFirstAncestorWhichIsA("Model")
	while m and m:GetAttribute("Kind") ~= "build" do
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	if m and m:GetAttribute("Build") == "rotator" then
		return part
	end
	local item = if part.Parent and part.Parent:IsA("BasePart") then part.Parent :: BasePart else part
	if item:GetAttribute("Stuck") ~= nil then
		return item
	end
	-- something loose resting on a rotator's table
	local loose = workspace:FindFirstChild("Loose")
	local builds = workspace:FindFirstChild("Builds")
	if loose and builds and item.Parent == loose then
		for _, r in builds:GetChildren() do
			if r:IsA("Model") and r:GetAttribute("Build") == "rotator" then
				local lp = r:GetPivot():PointToObjectSpace(item.Position) / (M * (r:GetAttribute("Size") :: number? or 1))
				if Vector2.new(lp.X, lp.Z).Magnitude < 0.62 and lp.Y > 0.3 and lp.Y < 1.5 then
					return item
				end
			end
		end
	end
	return nil
end

-- a laid rail, or a loose rail item, under the crosshair (the hammer lays / picks up / turns it)
function railAimed(): BasePart?
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character :: Instance, cam }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * (Config.Player.grabReach + 1) * M, params)
	if not hit then
		return nil
	end
	local part = hit.Instance
	local m = part:FindFirstAncestorWhichIsA("Model")
	if m and m:GetAttribute("Kind") == "rail" then
		return part
	end
	local item = if part.Parent and part.Parent:IsA("BasePart") then part.Parent :: BasePart else part
	local kind = item:GetAttribute("Product")
	if kind == "rail" or kind == "curved_rail" then
		return item
	end
	return nil
end

function BuildController.click(): boolean
	if (Config.Tools :: any)[State.tool] == nil or not (Config.Tools :: any)[State.tool].build or State.uiOpen then
		return false
	end
	if mode == "idle" then
		-- the hammer on a rotator, or on something sitting on (or stuck to) one: stick it on / let go (Godot's Player)
		local rot = rotatorAimed() or railAimed()
		if rot then
			remotes.Hammer:FireServer(rot)
			State.swing = 0
			return true
		end
		openMenu()
		return true
	end
	if not valid or not holo then
		Sfx.play("thud", 1.4, -6)
		return true
	end
	remotes.Build:FireServer(buildId, (holo :: Model):GetPivot(), size())
	BuildController.cancel()
	State.swing = 0          -- (a swing of the hammer as it goes down)
	Sfx.play("thud", 1.6)
	return true
end

function BuildController.start()
	State.placing = false
	InputController.on("Swing", function(state)
		if state == Enum.UserInputState.Begin then
			BuildController.click()
		end
	end)
	InputController.on("Turn", function(state)
		if state == Enum.UserInputState.Begin and mode == "idle" and (Config.Tools :: any)[State.tool] and (Config.Tools :: any)[State.tool].build then
			-- R with the hammer on a laid rail turns it
			local r = railAimed()
			if r and r:FindFirstAncestorWhichIsA("Model") and (r:FindFirstAncestorWhichIsA("Model") :: Model):GetAttribute("Kind") == "rail" then
				remotes.Hammer:FireServer(r, "turn")
				Sfx.play("click", 1.1, -4)
			end
		end
		if state == Enum.UserInputState.Begin and mode == "place" then
			local def = Builds.def(buildId) :: Builds.Def
			turn += math.rad(if def.fixed then 90 else 45)
			Sfx.play("click", 1.2, -6)
		end
	end)
	local function scroll(step: number)
		local def = Builds.def(buildId)
		if mode ~= "place" or not def or def.fixed then
			return
		end
		local ni = math.clamp(sizeI - step, 1, #GB.sizes)
		if ni ~= sizeI then
			sizeI = ni
			Sfx.play("click", 0.8 + size() * 0.15)
			local keep = holo and holo:GetPivot()
			makeHolo()
			if holo and keep then
				holo:PivotTo(keep)
			end
		end
	end
	InputController.on("NextTool", function(state)
		if state == Enum.UserInputState.Begin then
			scroll(1)
		end
	end)
	InputController.on("PrevTool", function(state)
		if state == Enum.UserInputState.Begin then
			scroll(-1)
		end
	end)
	State.toolChanged:Connect(function()
		if (Config.Tools :: any)[State.tool] == nil or not (Config.Tools :: any)[State.tool].build then
			BuildController.cancel()
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		BuildController.update()
		for _, s in spinning do
			local a = os.clock() * 0.6
			s.cam.CFrame = CFrame.lookAt(s.center + Vector3.new(math.cos(a), 0.55, math.sin(a)) * s.dist, s.center)
		end
	end)
end

return BuildController
