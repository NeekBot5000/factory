--!strict
-- The Godot game's look for every screen: dark see-through panels with rounded corners (Hud.gd's _flat), Nunito
-- for text and Fredoka for the money and titles, gold for "selected", green for money. The shop has its own light
-- TimberMart colours (ShopUI.gd), here too.
local TweenService = game:GetService("TweenService")
local Sfx = require(script.Parent.Parent.Sfx)

local UiKit = {}

UiKit.Colors = {
	panel = Color3.new(0.05, 0.06, 0.1),     -- Hud panels (at 0.65 alpha: BackgroundTransparency 0.35)
	gold = Color3.fromHex("ffcf6a"),
	green = Color3.fromHex("7aff9a"),
	red = Color3.fromHex("e04848"),
	warn = Color3.fromHex("ffd27a"),
	bad = Color3.fromHex("ff8a6a"),
	white = Color3.new(1, 1, 1),
	-- TimberMart
	header = Color3.fromHex("2b211b"),
	page = Color3.fromHex("f2ede4"),
	side = Color3.fromHex("ebe3d6"),
	card = Color3.fromHex("ffffff"),
	preview = Color3.fromHex("ede5da"),
	orange = Color3.fromHex("e87a2c"),
	peach = Color3.fromHex("fde0cb"),
	price = Color3.fromHex("2e7d4f"),
	owned = Color3.fromHex("d0c6b6"),
	ink = Color3.fromHex("2b211b"),
	muted = Color3.fromHex("6b5f53"),
	barBack = Color3.fromHex("e0d8cc"),
}

-- Godot uses Nunito (body, bold) and Fredoka (titles, money)
UiKit.Body = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold)
UiKit.Bold = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)
UiKit.Title = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)

function UiKit.tween(inst: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function UiKit.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

function UiKit.stroke(parent: Instance, thickness: number, color: Color3, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UiKit.pad(parent: Instance, x: number, y: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, x)
	p.PaddingRight = UDim.new(0, x)
	p.PaddingTop = UDim.new(0, y)
	p.PaddingBottom = UDim.new(0, y)
	p.Parent = parent
end

-- A label: Godot's _label (size in px, colour, font). Sizes itself to its text unless given a Size.
function UiKit.label(parent: Instance?, text: string, size: number, color: Color3, font: Font?, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font or UiKit.Body
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.new()
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

-- A dark rounded panel (Godot's _flat(Color(0.05, 0.06, 0.1, alpha), radius, pad)).
function UiKit.panel(parent: Instance?, alpha: number, radius: number, padX: number, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UiKit.Colors.panel
	f.BackgroundTransparency = 1 - alpha
	f.BorderSizePixel = 0
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.Size = UDim2.new()
	UiKit.corner(f, radius)
	UiKit.pad(f, padX, math.floor(padX * 0.6))
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

-- A flat button (the shop's orange "View" / "Buy" buttons). Clicks with Godot's click sound.
function UiKit.button(parent: Instance, text: string, color: Color3, textColor: Color3, onClick: () -> (), props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.FontFace = UiKit.Bold
	b.Text = text
	b.TextSize = 17
	b.TextColor3 = textColor
	UiKit.corner(b, 8)
	b.Activated:Connect(function()
		Sfx.play("click")
		onClick()
	end)
	for k, v in props or {} do
		(b :: any)[k] = v
	end
	b.Parent = parent
	return b
end

return UiKit
