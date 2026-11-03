--!strict
-- One look for every screen: Fredoka One, thick dark outlines, rounded corners, warm wood and cream with a green
-- accent, buttons that squash when pressed. Sizes are scale-based (with min/max limits) so phones and monitors both
-- work, and touch targets are never smaller than 48 px.
local TweenService = game:GetService("TweenService")
local Sfx = require(script.Parent.Parent.Sfx)

local UiKit = {}

UiKit.Colors = {
	cream = Color3.fromRGB(250, 241, 222),
	paper = Color3.fromRGB(255, 249, 236),
	wood = Color3.fromRGB(122, 84, 52),
	dark = Color3.fromRGB(43, 33, 24),
	green = Color3.fromRGB(76, 186, 96),
	gold = Color3.fromRGB(255, 200, 70),
	red = Color3.fromRGB(226, 84, 64),
	grey = Color3.fromRGB(150, 146, 140),
	sky = Color3.fromRGB(110, 180, 230),
}
UiKit.Font = Enum.Font.FredokaOne

function UiKit.tween(inst: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function UiKit.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

function UiKit.stroke(parent: Instance, thickness: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or UiKit.Colors.dark
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border     -- the outline of the box (text gets its own TextStroke)
	s.Parent = parent
	return s
end

-- a soft top-light on any coloured surface (the "plastic toy" look most popular games use)
function UiKit.shine(parent: Instance)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215))
	g.Parent = parent
end

-- outlined text: a TextLabel with a dark text stroke, scaled to fit
function UiKit.text(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = UiKit.Font
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeColor3 = UiKit.Colors.dark
	l.TextStrokeTransparency = 0
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 14
	limit.MaxTextSize = 40
	limit.Parent = l
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

function UiKit.panel(parent: Instance, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UiKit.Colors.cream
	f.BorderSizePixel = 0
	UiKit.corner(f, 16)
	UiKit.stroke(f, 4)
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

-- a chunky button: colour, outline, shine, squashes when pressed, pops when hovered (not on touch)
function UiKit.button(parent: Instance, text: string, color: Color3, onClick: () -> (), props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.Font = UiKit.Font
	b.Text = text
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeColor3 = UiKit.Colors.dark
	b.TextStrokeTransparency = 0
	UiKit.corner(b, 12)
	UiKit.stroke(b, 3)
	UiKit.shine(b)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = b
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 30
	limit.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseEnter:Connect(function()
		UiKit.tween(scale, 0.12, { Scale = 1.05 })
	end)
	b.MouseLeave:Connect(function()
		UiKit.tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		UiKit.tween(scale, 0.06, { Scale = 0.9 })
	end)
	b.Activated:Connect(function()
		UiKit.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		Sfx.play("click")
		onClick()
	end)
	for k, v in props or {} do
		(b :: any)[k] = v
	end
	b.Parent = parent
	return b
end

-- a quick bounce, for things that just changed (the money counter, a new quest)
function UiKit.pop(inst: GuiObject)
	local scale = inst:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = inst
	scale.Scale = 1.18
	UiKit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

return UiKit
