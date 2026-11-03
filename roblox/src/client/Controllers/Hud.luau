--!strict
-- The Godot game's HUD (Hud.gd and Tutorial.gd), in Roblox:
--   * money, top right: "$0.00" in green, counting up to a new total with a little pop
--   * health, bottom left: only while you're hurt; a red flash at the edges when you're hit and while you're low
--   * the tool bar, bottom centre: a slot per tool with its picture and number key; the one in hand is outlined in
--     gold and shows its name
--   * the hint line above it ("[E] grab", "[E] ship  $12.40"), and messages at the top centre that fade away
--   * the crosshair: a dot and a ring the size of the tool's bark circle where you're aiming, gold on a tree
--   * "Getting started", top left, one step at a time
--   * the screen fades to black when you faint, and back when you wake up
-- Roblox's own player list, backpack and health bar are turned off; chat stays.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Config = require(ReplicatedStorage.Shared.Config)
local UiKit = require(script.Parent.Parent.Ui.UiKit)
local State = require(script.Parent.Parent.State)
local Sfx = require(script.Parent.Parent.Sfx)
local ToolController = require(script.Parent.ToolController)
local InteractController = require(script.Parent.InteractController)

local Hud = {}
local player = Players.LocalPlayer
local C = UiKit.Colors
local M = Config.StudsPerMetre
local MAX_SLOTS = 9

local function coreOff()
	for _, t in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu } do
		-- (SetCoreGuiEnabled can fail for a moment while Roblox's own scripts load)
		for _ = 1, 10 do
			if pcall(function()
				StarterGui:SetCoreGuiEnabled(t, false)
			end) then
				break
			end
			task.wait(0.5)
		end
	end
end

local function edge(gui: Instance, anchor: Vector2, pos: UDim2, size: UDim2, rotation: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = anchor
	f.Position = pos
	f.Size = size
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(0.75, 0, 0)
	f.BackgroundTransparency = 1
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
	f.Parent = gui
	return f
end

-- the flat karate-chop hand (Godot draws it with polygons): a palm and fingers held together, a red cuff
local function handIcon(parent: Instance)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(44, 44)
	holder.Rotation = -15
	holder.Parent = parent
	local function box(x: number, y: number, w: number, h: number, color: Color3, r: number)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		UiKit.corner(f, r)
		UiKit.stroke(f, 1.2, Color3.fromHex("6b4428"))
		f.Parent = holder
		return f
	end
	box(13, 3, 17, 30, Color3.fromHex("f2c9a0"), 5)         -- fingers and palm
	box(26, 16, 9, 6, Color3.fromHex("f2c9a0"), 3)          -- thumb
	box(13, 33, 17, 8, Color3.fromHex("d94a3d"), 2)         -- sleeve cuff
	return holder
end

local function toolIcon(parent: Instance, id: string)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromOffset(44, 44)
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.Parent = parent
	local models = ReplicatedStorage:FindFirstChild("ToolModels")
	local src = models and models:FindFirstChild(id)
	if src then
		local m = (src :: Model):Clone()
		m.Parent = vp
		local cf, size = m:GetBoundingBox()
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(size.Magnitude * 1.7, size.Magnitude * 0.2, 0), cf.Position) * CFrame.Angles(0, 0, math.rad(-35))
		cam.Parent = vp
		vp.CurrentCamera = cam
	end
end

function Hud.start()
	task.spawn(coreOff)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	-- hurt: red at the screen's edges (Godot's vignette shader), stronger as health gets low
	local flash = {
		edge(gui, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.35, 1), 0),
		edge(gui, Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.35, 1), 180),
		edge(gui, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.35), 90),
		edge(gui, Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.35), 270),
	}
	local flashA = 0

	-- the crosshair: a dot and the ring
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(5, 5)
	dot.BackgroundColor3 = C.white
	dot.BackgroundTransparency = 0.1
	dot.BorderSizePixel = 0
	UiKit.corner(dot, 3)
	dot.Parent = gui
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromOffset(20, 20)
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = ring
	local ringStroke = UiKit.stroke(ring, 1.6, C.white, 0.65)
	ring.Parent = gui
	local ringPx = 10

	-- money, top right
	local moneyBox = UiKit.panel(gui, 0.65, 12, 14, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 18) })
	local moneyScale = Instance.new("UIScale")
	moneyScale.Parent = moneyBox
	local moneyLbl = UiKit.label(moneyBox, "$0.00", 28, C.green, UiKit.Title)
	local shown = -1
	local target = 0
	local rollFrom, rollT, rollDur = 0, 1, 0.25

	-- health, bottom left (hidden until you're hurt)
	local hpBox = UiKit.panel(gui, 0.65, 12, 12, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -20) })
	local hpList = Instance.new("UIListLayout")
	hpList.Padding = UDim.new(0, 4)
	hpList.Parent = hpBox
	local hpLbl = UiKit.label(hpBox, "Health 100", 15, C.white)
	local hpBack = Instance.new("Frame")
	hpBack.Size = UDim2.fromOffset(240, 14)
	hpBack.BackgroundColor3 = Color3.new(0, 0, 0)
	hpBack.BackgroundTransparency = 0.5
	hpBack.BorderSizePixel = 0
	UiKit.corner(hpBack, 7)
	hpBack.Parent = hpBox
	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = C.red
	hpFill.BorderSizePixel = 0
	UiKit.corner(hpFill, 7)
	hpFill.Parent = hpBack
	local hpGroup = Instance.new("CanvasGroup")
	hpGroup.BackgroundTransparency = 1
	hpGroup.Size = UDim2.fromScale(1, 1)
	hpGroup.GroupTransparency = 1
	hpGroup.Parent = gui
	hpBox.Parent = hpGroup

	-- the tool bar, bottom centre
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -16)
	bar.AutomaticSize = Enum.AutomaticSize.XY
	bar.Size = UDim2.new()
	bar.Parent = gui
	local barList = Instance.new("UIListLayout")
	barList.FillDirection = Enum.FillDirection.Horizontal
	barList.Padding = UDim.new(0, 6)
	barList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	barList.SortOrder = Enum.SortOrder.LayoutOrder
	barList.Parent = bar
	local function rebuildBar()
		for _, c in bar:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local owned = ToolController.bar()
		local first, last = 1, #owned
		if #owned > MAX_SLOTS then
			first = math.clamp((table.find(owned, State.tool) or 1) - 4, 1, #owned - MAX_SLOTS + 1)
			last = first + MAX_SLOTS - 1
		end
		for n = first, last do
			local id = owned[n]
			local sel = State.tool == id
			local slot = UiKit.panel(bar, if sel then 0.75 else 0.5, 10, 6, { LayoutOrder = n })
			UiKit.stroke(slot, if sel then 2 else 1, if sel then C.gold else C.white, if sel then 0 else 0.85)
			local v = Instance.new("UIListLayout")
			v.HorizontalAlignment = Enum.HorizontalAlignment.Center
			v.SortOrder = Enum.SortOrder.LayoutOrder
			v.Parent = slot
			if id == "hands" then
				handIcon(slot)
			else
				toolIcon(slot, id)
			end
			local key = if n <= 9 then tostring(n) elseif n <= 18 then "S+" .. (n - 9) else ""
			local def = (Config.Tools :: any)[id]
			UiKit.label(slot, if sel then key .. "  " .. def.name else key, 11, if sel then C.gold else Color3.new(1, 1, 1), UiKit.Bold, { LayoutOrder = 2, TextTransparency = if sel then 0 else 0.2 })
		end
	end
	State.toolChanged:Connect(rebuildBar)
	rebuildBar()

	-- the hint line
	local hint = UiKit.label(gui, "", 17, C.white, UiKit.Body, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), TextStrokeTransparency = 0.3 })

	-- messages, top centre
	local toasts = Instance.new("Frame")
	toasts.BackgroundTransparency = 1
	toasts.AnchorPoint = Vector2.new(0.5, 0)
	toasts.Position = UDim2.new(0.5, 0, 0, 18)
	toasts.AutomaticSize = Enum.AutomaticSize.XY
	toasts.Size = UDim2.new()
	toasts.Parent = gui
	local tl = Instance.new("UIListLayout")
	tl.Padding = UDim.new(0, 6)
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = toasts
	local toastN = 0
	State.toasted:Connect(function(text: string, color: Color3)
		toastN += 1
		local l = UiKit.label(toasts, text, 16, color, UiKit.Bold, { BackgroundTransparency = 0.15, BackgroundColor3 = C.panel, LayoutOrder = toastN })
		UiKit.corner(l, 10)
		UiKit.pad(l, 14, 8)
		local list = {}
		for _, c in toasts:GetChildren() do
			if c:IsA("TextLabel") then
				table.insert(list, c)
			end
		end
		table.sort(list, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		while #list > 4 do
			table.remove(list, 1):Destroy()
		end
		task.delay(3.5, function()
			if l.Parent then
				UiKit.tween(l, 0.5, { TextTransparency = 1, BackgroundTransparency = 1 })
				task.delay(0.5, function()
					l:Destroy()
				end)
			end
		end)
	end)

	-- Getting started (top left)
	local tut = Instance.new("Frame")
	tut.Position = UDim2.fromOffset(20, 20)
	tut.Size = UDim2.fromOffset(380, 0)
	tut.AutomaticSize = Enum.AutomaticSize.Y
	tut.BackgroundColor3 = Color3.new(0.08, 0.09, 0.12)
	tut.BackgroundTransparency = 0.22
	tut.BorderSizePixel = 0
	tut.Visible = false
	UiKit.corner(tut, 12)
	UiKit.pad(tut, 14, 14)
	tut.Parent = gui
	local tutList = Instance.new("UIListLayout")
	tutList.Padding = UDim.new(0, 4)
	tutList.SortOrder = Enum.SortOrder.LayoutOrder
	tutList.Parent = tut
	local tutCount = UiKit.label(tut, "", 13, C.gold, UiKit.Bold, { LayoutOrder = 1 })
	local tutText = UiKit.label(tut, "", 16, C.white, UiKit.Body, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })

	-- fainting: fade to black and back
	local fade = Instance.new("Frame")
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.ZIndex = 10
	fade.Parent = gui

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text: string, hex: string?, sound: string?)
		State.toast(text, if hex then Color3.fromHex(hex) else C.white)
		if sound then
			Sfx.play(sound)
		end
	end)
	-- paid by the mill: "+$12.40" and the till
	remotes:WaitForChild("Sold").OnClientEvent:Connect(function(amount: number)
		State.toast(string.format("+$%.2f", amount), C.green)
		Sfx.play("buy")
	end)
	local tutShown = false
	remotes:WaitForChild("Tutorial").OnClientEvent:Connect(function(t: any)
		tutShown = t ~= nil
		if t then
			tutCount.Text = string.format("Getting started  ·  %d of %d", t.i, t.of)
			tutText.Text = t.text
		end
	end)

	local function onCharacter(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		local last = hum.Health
		hum.HealthChanged:Connect(function(h)
			if h < last - 0.01 then
				flashA = 0.85
			end
			last = h
			hpLbl.Text = string.format("Health %d", math.ceil(h))
			hpFill.Size = UDim2.fromScale(math.clamp(h / hum.MaxHealth, 0, 1), 1)
		end)
		hum.Died:Connect(function()
			hint.Text = ""
			UiKit.tween(fade, 1, { BackgroundTransparency = 0 })
		end)
		-- waking up
		UiKit.tween(fade, 1.2, { BackgroundTransparency = 1 })
	end
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	RunService.RenderStepped:Connect(function(dt)
		-- money rolls up to a new total (a quick roll, so a big sale feels big), and the counter pops
		local m = player:GetAttribute("Money")
		m = if typeof(m) == "number" then m else 0
		if m ~= target then
			local gain = m - (if shown < 0 then m else shown)
			target = m
			if shown < 0 or gain <= 0 then
				shown = m
				rollT = 1
			else
				rollFrom, rollT, rollDur = shown, 0, math.clamp(0.25 + gain / 400, 0.25, 1.4)
				moneyScale.Scale = 1.06 + math.min(gain / 1500, 0.14)
				UiKit.tween(moneyScale, 0.33, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		if rollT < 1 then
			rollT = math.min(1, rollT + dt / rollDur)
			local k = 1 - (1 - rollT) ^ 3
			shown = rollFrom + (target - rollFrom) * k
		else
			shown = target
		end
		moneyLbl.Text = string.format("$%.2f", shown)

		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local health = if hum then hum.Health else 100
		local maxHealth = if hum then hum.MaxHealth else 100
		-- red edges: a flash when hit, and a steady glow when low
		flashA = math.max(0, flashA - dt * 2.5)
		local low = math.clamp(1 - health / 40, 0, 1) * 0.45
		local strength = math.max(flashA, if health > 0 then low else 0)
		for _, f in flash do
			f.BackgroundTransparency = 1 - strength
		end
		-- health shows only while you're hurt
		local hurt = health < maxHealth - 0.5
		hpGroup.GroupTransparency = math.clamp(hpGroup.GroupTransparency + (if hurt then -dt * 4 else dt), 0, 1)

		local open = State.uiOpen
		dot.Visible = not open
		ring.Visible = not open
		bar.Visible = not open
		moneyBox.Visible = not open
		tut.Visible = tutShown and not open
		if open then
			hint.Text = ""
		else
			-- the ring: the tool's bark circle as it would look where you're aiming (Godot's aim_ring_px)
			local def = (Config.Tools :: any)[State.tool] or Config.Tools.hands
			local onTree, dist = ToolController.aimingAtTree()
			local cam = workspace.CurrentCamera
			local vh = cam.ViewportSize.Y
			local r = math.max(ToolController.stripRadius(), 0.04)
			local want = math.clamp(r / (math.max(dist / M, 0.3) * math.tan(math.rad(cam.FieldOfView / 2))) * vh * 0.5, 5, 400)
			ringPx += (want - ringPx) * 0.35
			ring.Size = UDim2.fromOffset(ringPx * 2, ringPx * 2)
			ringStroke.Color = if onTree then Color3.new(1, 0.85, 0.4) else C.white
			ringStroke.Transparency = if onTree then 0.2 else 0.65
			hint.Text = (InteractController.target())
		end
	end)
end

return Hud
