--!strict
-- TimberMart. Hold the stall's prompt and the shop opens: a card per tool with its model turning in a 3D preview,
-- its tag, a line about it, bars for peel size and speed, and a Buy button (green if you can afford it). Owned tools
-- say so. Works with the mouse, touch, and a gamepad (the first Buy button is selected; B closes).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Config = require(ReplicatedStorage.Shared.Config)
local UiKit = require(script.Parent.Parent.Ui.UiKit)

local ShopController = {}
local player = Players.LocalPlayer
local C = UiKit.Colors
local gui: ScreenGui? = nil
local spinning: { { cam: Camera, center: Vector3, dist: number } } = {}

local function owns(id: string): boolean
	for _, container in { player:FindFirstChildOfClass("Backpack"), player:FindFirstChild("StarterGear"), player.Character } do
		if container then
			for _, t in (container :: Instance):GetChildren() do
				if t:GetAttribute("ToolId") == id then
					return true
				end
			end
		end
	end
	return false
end

local function money(): number
	local ls = player:FindFirstChild("leaderstats")
	local m = ls and ls:FindFirstChild("Money") :: NumberValue?
	return if m then m.Value else 0
end

local function bar(parent: Instance, label: string, frac: number, y: number, color: Color3)
	UiKit.text(parent, label, { Size = UDim2.new(0.34, 0, 0, 16), Position = UDim2.new(0.05, 0, 0, y), TextColor3 = C.wood,
		TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left })
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(225, 212, 190)
	back.Size = UDim2.new(0.56, 0, 0, 12)
	back.Position = UDim2.new(0.39, 0, 0, y + 2)
	UiKit.corner(back, 6)
	back.Parent = parent
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.Size = UDim2.fromScale(math.clamp(frac, 0.06, 1), 1)
	UiKit.corner(f, 6)
	f.Parent = back
end

local function close()
	if gui then
		gui:Destroy()
		gui = nil
	end
	table.clear(spinning)
	ContextActionService:UnbindAction("CloseShop")
	GuiService.SelectedObject = nil
end

local function card(grid: Instance, id: string, order: number): TextButton?
	local def = (Config.Tools :: any)[id]
	local c = UiKit.panel(grid, { Name = id, BackgroundColor3 = C.paper, LayoutOrder = order })
	-- 3D preview of the tool, turning
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(0.9, 0, 0.42, 0)
	vp.Position = UDim2.new(0.05, 0, 0.03, 0)
	vp.BackgroundColor3 = Color3.fromRGB(205, 228, 240)
	vp.LightDirection = Vector3.new(-1, -1, -0.5)
	vp.Ambient = Color3.fromRGB(170, 170, 170)
	UiKit.corner(vp, 10)
	vp.Parent = c
	local models = ReplicatedStorage:FindFirstChild("ToolModels")
	local src = models and models:FindFirstChild(id) :: Model?
	if src then
		local m = src:Clone()
		m.Parent = vp
		local cf, size = m:GetBoundingBox()
		local cam = Instance.new("Camera")
		cam.FieldOfView = 40
		cam.Parent = vp
		vp.CurrentCamera = cam
		table.insert(spinning, { cam = cam, center = cf.Position, dist = size.Magnitude * 1.25 })
	end
	UiKit.text(c, def.name, { Size = UDim2.new(0.9, 0, 0.09, 0), Position = UDim2.new(0.05, 0, 0.46, 0), TextColor3 = C.dark, TextStrokeTransparency = 1 })
	local tag = UiKit.panel(c, { Size = UDim2.new(0.42, 0, 0.06, 0), Position = UDim2.new(0.05, 0, 0.56, 0), BackgroundColor3 = C.sky })
	UiKit.stroke(tag, 2)
	UiKit.text(tag, string.upper(def.tag or ""), { Size = UDim2.fromScale(1, 1) })
	UiKit.text(c, def.desc or "", { Size = UDim2.new(0.9, 0, 0.1, 0), Position = UDim2.new(0.05, 0, 0.63, 0), TextColor3 = C.wood,
		TextStrokeTransparency = 1, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	-- bars: peel size (radius 0-3) and speed (cooldown 1.2 slow .. 0.34 fast)
	local stats = Instance.new("Frame")
	stats.BackgroundTransparency = 1
	stats.Size = UDim2.new(1, 0, 0.1, 0)
	stats.Position = UDim2.new(0, 0, 0.74, 0)
	stats.Parent = c
	bar(stats, "Peel", (def.radius + 1) / 4, 0, C.gold)
	bar(stats, "Speed", (1.3 - def.cooldown) / 1.0, 18, C.sky)
	local have = owns(id)
	local afford = money() >= def.price
	local buyBtn: TextButton
	buyBtn = UiKit.button(c, if have then "Owned" else string.format("Buy  $%d", def.price), if have then C.grey elseif afford then C.green else C.red, function()
		if owns(id) then
			return
		end
		if money() < def.price then
			UiKit.pop(buyBtn)
			return
		end
		(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Buy") :: RemoteEvent):FireServer(id)
		buyBtn.Text = "Owned"
		buyBtn.BackgroundColor3 = C.grey
	end, { Size = UDim2.new(0.9, 0, 0.12, 0), Position = UDim2.new(0.05, 0, 0.86, 0) })
	return if have then nil else buyBtn
end

local function open()
	if gui then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "TimberMartShop"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 10
	gui = g
	-- dim the world behind
	local dim = Instance.new("TextButton")      -- (a button, so clicks behind the shop don't swing your axe)
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Modal = true                             -- frees the mouse in first person while the shop is open
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = g
	local panel = UiKit.panel(g, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.86, 0.8) })
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(1100, 720)
	limit.Parent = panel
	local header = UiKit.panel(panel, { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = C.wood })
	UiKit.text(header, "TimberMart", { Size = UDim2.new(0.6, 0, 0.8, 0), Position = UDim2.new(0.03, 0, 0.1, 0), TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left })
	UiKit.button(header, "X", C.red, close, { Size = UDim2.fromOffset(52, 52), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0) })
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.Size = UDim2.new(1, -24, 1, -84)
	scroll.Position = UDim2.new(0, 12, 0, 74)
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.31, 0, 0, 330)
	grid.CellPadding = UDim2.new(0.02, 0, 0, 14)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll
	-- phones: two cards a row
	if workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X < 900 then
		grid.CellSize = UDim2.new(0.47, 0, 0, 300)
	end
	local first: TextButton? = nil
	for i, id in Config.ShopOrder do
		local b = card(scroll, id, i)
		first = first or b
	end
	UiKit.pop(panel)
	g.Parent = player:WaitForChild("PlayerGui")
	-- gamepad: start on the first thing you can buy; B closes
	GuiService.SelectedObject = first
	ContextActionService:BindAction("CloseShop", function(_, state)
		if state == Enum.UserInputState.Begin then
			close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Escape)
end

function ShopController.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.ActionText == "Browse tools" then
			open()
		end
	end)
	RunService.RenderStepped:Connect(function()
		local a = os.clock() * 0.8
		for _, s in spinning do
			s.cam.CFrame = CFrame.lookAt(s.center + Vector3.new(math.cos(a) * s.dist, s.dist * 0.25, math.sin(a) * s.dist), s.center)
		end
	end)
end

ShopController.open = open
ShopController.close = close
return ShopController
