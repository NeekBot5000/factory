--!strict
-- The heads-up display:
--   * a big money counter at the top that counts up, with a gold coin that pops when you earn
--   * floating "+$12.40" numbers where you sold, and a coin sound
--   * the quest pill on the left (what to do now, with a progress bar), and a bouncing marker over where to go
--   * short messages under the money ("Bought the Trusty Hatchet!")
--   * a crosshair in the middle (every device aims from there)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage.Shared.Config)
local UiKit = require(script.Parent.Parent.Ui.UiKit)
local Sfx = require(script.Parent.Parent.Sfx)

local Hud = {}
local player = Players.LocalPlayer
local C = UiKit.Colors

local function moneyText(v: number): string
	if v >= 1e6 then
		return string.format("$%.2fM", v / 1e6)
	elseif v >= 1e4 then
		return string.format("$%.1fK", v / 1e3)
	end
	return string.format("$%.2f", v)
end

local function buildMoney(gui: ScreenGui): (TextLabel, Frame)
	local pill = UiKit.panel(gui, {
		Name = "Money", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0.22, 0, 0, 52), BackgroundColor3 = C.dark,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(180, 48)
	limit.MaxSize = Vector2.new(320, 60)
	limit.Parent = pill
	local coin = UiKit.panel(pill, {
		Name = "Coin", Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, -14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C.gold,
	})
	UiKit.corner(coin, 22)
	UiKit.text(coin, "$", { Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(255, 250, 220) })
	local label = UiKit.text(pill, "$0.00", {
		Size = UDim2.new(1, -44, 1, -8), Position = UDim2.new(0, 38, 0, 4), TextColor3 = Color3.fromRGB(150, 255, 150),
	})
	return label, coin
end

local function buildQuest(gui: ScreenGui)
	local pill = UiKit.panel(gui, {
		Name = "Quest", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 14, 0.3, 0), Size = UDim2.new(0.26, 0, 0, 74),
		BackgroundColor3 = C.paper, Visible = false,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(220, 70)
	limit.MaxSize = Vector2.new(380, 90)
	limit.Parent = pill
	local step = UiKit.text(pill, "", { Name = "Step", Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 6),
		TextColor3 = C.wood, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left })
	local what = UiKit.text(pill, "", { Name = "What", Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0, 10, 0, 24),
		TextColor3 = C.dark, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left })
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Color3.fromRGB(220, 208, 186)
	bar.Size = UDim2.new(1, -20, 0, 12)
	bar.Position = UDim2.new(0, 10, 1, -20)
	UiKit.corner(bar, 6)
	bar.Parent = pill
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = C.green
	fill.Size = UDim2.fromScale(0, 1)
	UiKit.corner(fill, 6)
	fill.Parent = bar
	return pill, step, what, fill
end

-- the marker: a bouncing arrow over where the current goal is, on top of everything, with the distance
local function buildMarker(): (BillboardGui, TextLabel)
	local bb = Instance.new("BillboardGui")
	bb.Name = "GoalMarker"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(70, 80)
	bb.StudsOffset = Vector3.new(0, 6, 0)
	bb.LightInfluence = 0
	local arrow = UiKit.text(bb, "▼", { Size = UDim2.new(1, 0, 0.7, 0), TextColor3 = C.gold })
	local dist = UiKit.text(bb, "", { Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.7), TextColor3 = Color3.new(1, 1, 1) })
	RunService.RenderStepped:Connect(function()
		arrow.Position = UDim2.fromScale(0, math.abs(math.sin(os.clock() * 4)) * -0.15)
	end)
	return bb, dist
end

local function targetPart(kind: string): BasePart?
	if kind == "truck" then
		local truck = workspace:FindFirstChild("Truck_" .. player.UserId) or workspace:FindFirstChild("Truck")
		return truck and truck:FindFirstChild("Bed") :: BasePart?
	elseif kind == "shop" then
		local shop = workspace:FindFirstChild("TimberMart")
		return shop and shop:FindFirstChild("Counter") :: BasePart?
	elseif kind == "tree" then
		-- the nearest tree
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local best, bestD = nil, math.huge
		for _, t in CollectionService:GetTagged("Tree") do
			local trunk = t:FindFirstChild("Trunk") :: BasePart?
			if trunk and root then
				local d = (trunk.Position - root.Position).Magnitude
				if d < bestD then
					best, bestD = trunk, d
				end
			end
		end
		return best
	end
	return nil
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TimberHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- crosshair
	local dot = Instance.new("Frame")
	dot.Name = "Crosshair"
	dot.Size = UDim2.fromOffset(8, 8)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	UiKit.corner(dot, 4)
	UiKit.stroke(dot, 1.5)
	dot.Parent = gui

	-- money: counts up towards the real value
	local moneyLabel, coin = buildMoney(gui)
	local shown, target = 0, 0
	task.spawn(function()
		local ls = player:WaitForChild("leaderstats")
		local money = ls:WaitForChild("Money") :: NumberValue
		target = money.Value
		shown = target
		money.Changed:Connect(function(v)
			if v > target then
				UiKit.pop(coin)
			end
			target = v
		end)
	end)
	RunService.RenderStepped:Connect(function(dt)
		if shown ~= target then
			shown += (target - shown) * math.min(1, dt * 8)
			if math.abs(target - shown) < 0.01 then
				shown = target
			end
			moneyLabel.Text = moneyText(shown)
		end
	end)

	-- messages under the money
	local msg = UiKit.text(gui, "", { Name = "Message", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.new(0.5, 0, 0, 34), TextColor3 = Color3.fromRGB(255, 240, 200) })
	local n = 0
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text: string)
		n += 1
		local mine = n
		msg.Text = text
		UiKit.pop(msg)
		task.delay(3.5, function()
			if n == mine then
				msg.Text = ""
			end
		end)
	end)

	-- a sale: "+$12.40" rising out of the truck, the coin sound
	remotes:WaitForChild("Sold").OnClientEvent:Connect(function(amount: number, at: Vector3)
		Sfx.play("buy")
		Sfx.playAt("horn", at + Vector3.new(0, 4, 0), 1, -2)
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		anchor.Position = at + Vector3.new(0, 4, 0)
		anchor.Parent = workspace
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(220, 70)
		bb.AlwaysOnTop = true
		bb.Adornee = anchor
		bb.Parent = anchor
		local t = UiKit.text(bb, string.format("+$%.2f", amount), { Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(140, 255, 140) })
		UiKit.pop(t)
		UiKit.tween(anchor, 1.6, { Position = anchor.Position + Vector3.new(0, 6, 0) })
		UiKit.tween(t, 1.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
		task.delay(1.7, function()
			anchor:Destroy()
		end)
	end)

	-- quest pill and marker
	local pill, step, what, fill = buildQuest(gui)
	local marker, dist = buildMarker()
	marker.Parent = gui
	local goalKind = ""
	local lastStep = 0
	remotes:WaitForChild("Quest").OnClientEvent:Connect(function(q: any)
		if not q then
			pill.Visible = false
			goalKind = ""
			marker.Adornee = nil
			return
		end
		pill.Visible = true
		step.Text = string.format("GOAL %d OF %d", q.i, q.of)
		what.Text = if q.goal > 1 then string.format("%s  %d/%d", q.text, math.floor(q.n), q.goal) else q.text
		UiKit.tween(fill, 0.4, { Size = UDim2.fromScale(math.clamp(q.n / q.goal, 0, 1), 1) })
		UiKit.pop(pill)
		if lastStep ~= 0 and q.i ~= lastStep then
			Sfx.play("reveal")         -- a goal done
		end
		lastStep = q.i
		goalKind = q.target
	end)
	-- keep the marker on the goal (the nearest tree moves as you walk)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local p = if goalKind ~= "" then targetPart(goalKind) else nil
		marker.Adornee = p
		marker.Enabled = p ~= nil
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if p and root then
			local d = (p.Position - root.Position).Magnitude
			dist.Text = string.format("%dm", math.floor(d / 3))       -- 3 studs to a metre
			marker.Enabled = d > 10
		end
	end)
end

return Hud
