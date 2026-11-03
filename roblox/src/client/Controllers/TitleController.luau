--!strict
-- The Godot game's title screen (TitleMenu.gd), settings (SettingsMenu.gd) and credits (Credits.gd).
-- When you join: "Timber" in gold over the forest, "Peel it. Fell it. Build something bigger.", and Continue /
-- New Game / Settings / Credits (no Quit: like Godot's web build). A brand-new player only gets New Game. New Game
-- on a save asks first ("Start over? Your saved world will be lost"). Settings has Godot's field of view, volume,
-- music, head bob and FPS (mouse sensitivity and invert are in Roblox's own settings menu).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiKit = require(script.Parent.Parent.Ui.UiKit)
local State = require(script.Parent.Parent.State)
local Sfx = require(script.Parent.Parent.Sfx)

local TitleController = {}
local player = Players.LocalPlayer
local ACCENT = Color3.fromHex("ffcf6a")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local gui: ScreenGui? = nil
local VERSION = "1.0.0"

-- the player's settings (saved on the server, in their save)
State.settings = { fov = 75, volume = 0.8, music = 0.5, bob = true, fps = false }

local function readSettings()
	local s = player:GetAttribute("Settings")
	if typeof(s) == "string" and s ~= "" then
		local ok, t = pcall(function()
			return HttpService:JSONDecode(s)
		end)
		if ok and type(t) == "table" then
			for k, v in t do
				(State.settings :: any)[k] = v
			end
		end
	end
	Sfx.musicVolume = State.settings.music
	Sfx.volume = State.settings.volume
end

local function saveSettings()
	remotes.Settings:FireServer(State.settings)
	Sfx.musicVolume = State.settings.music
	Sfx.volume = State.settings.volume
end

local function button(parent: Instance, text: string, primary: boolean, order: number, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = if primary then ACCENT else Color3.new(1, 1, 1)
	b.BackgroundTransparency = if primary then 0 else 0.9
	b.BorderSizePixel = 0
	b.Size = UDim2.new(1, 0, 0, 54)
	b.FontFace = UiKit.Bold
	b.TextSize = 22
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextColor3 = if primary then Color3.fromHex("2b2118") else Color3.new(1, 1, 1)
	b.Text = text
	b.LayoutOrder = order
	UiKit.corner(b, 14)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 22)
	pad.Parent = b
	b.Activated:Connect(function()
		Sfx.play("click")
		onClick()
	end)
	b.Parent = parent
	return b
end

local function close()
	if gui then
		gui:Destroy()
		gui = nil
	end
	State.uiOpen = false
end

local open: () -> ()

-- a dark panel in the middle (settings, credits), with a Back button
local function page(title: string, build: (Frame) -> ())
	if gui then
		gui:Destroy()
	end
	local g = Instance.new("ScreenGui")
	g.Name = "TitleMenu"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 20
	gui = g
	local back = Instance.new("TextButton")
	back.Text = ""
	back.Modal = true
	back.AutoButtonColor = false
	back.BackgroundColor3 = Color3.new(0.05, 0.06, 0.05)
	back.BackgroundTransparency = 0.45
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = g
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(560, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.new(0.08, 0.09, 0.12)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	UiKit.corner(panel, 16)
	UiKit.pad(panel, 26, 26)
	panel.Parent = g
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel
	UiKit.label(panel, title, 34, ACCENT, UiKit.Title, { LayoutOrder = 1 })
	build(panel)
	button(panel, "Back", true, 1000, function()
		open()
	end)
	g.Parent = player:WaitForChild("PlayerGui")
end

local function slider(parent: Instance, order: number, title: string, lo: number, hi: number, value: number, fmt: string, scale: number, onChange: (number) -> ())
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 46)
	row.LayoutOrder = order
	row.Parent = parent
	local lbl = UiKit.label(row, "", 16, Color3.new(1, 1, 1), UiKit.Bold)
	local track = Instance.new("TextButton")
	track.Text = ""
	track.AutoButtonColor = false
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	track.BackgroundTransparency = 0.85
	track.Position = UDim2.fromOffset(0, 26)
	track.Size = UDim2.new(1, 0, 0, 12)
	UiKit.corner(track, 6)
	track.Parent = row
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	UiKit.corner(fill, 6)
	fill.Parent = track
	local function show(v: number)
		fill.Size = UDim2.fromScale(math.clamp((v - lo) / (hi - lo), 0, 1), 1)
		lbl.Text = title .. "   " .. string.format(fmt, v * scale)
	end
	show(value)
	track.Activated:Connect(function(input: InputObject)
		local x = (input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		local v = lo + (hi - lo) * math.clamp(x, 0, 1)
		show(v)
		onChange(v)
	end)
end

local function toggle(parent: Instance, order: number, title: string, key: string)
	local b: TextButton
	b = button(parent, "", false, order, function()
		(State.settings :: any)[key] = not (State.settings :: any)[key]
		b.Text = title .. ":  " .. (if (State.settings :: any)[key] then "On" else "Off")
		saveSettings()
	end)
	b.Text = title .. ":  " .. (if (State.settings :: any)[key] then "On" else "Off")
	b.Size = UDim2.new(1, 0, 0, 44)
	b.TextSize = 18
end

local function settings()
	page("Settings", function(panel)
		slider(panel, 2, "Field of view", 60, 100, State.settings.fov, "%d°", 1, function(v)
			State.settings.fov = math.floor(v + 0.5)
			saveSettings()
		end)
		slider(panel, 3, "Volume", 0, 1, State.settings.volume, "%d%%", 100, function(v)
			State.settings.volume = v
			saveSettings()
		end)
		slider(panel, 4, "Music", 0, 1, State.settings.music, "%d%%", 100, function(v)
			State.settings.music = v
			saveSettings()
		end)
		toggle(panel, 5, "Head bob", "bob")
		toggle(panel, 6, "Show FPS", "fps")
		UiKit.label(panel, "Mouse sensitivity and invert are in Roblox's own settings (Esc).", 14, Color3.new(1, 1, 1), UiKit.Body, { LayoutOrder = 7, TextTransparency = 0.35 })
	end)
end

local function credits()
	page("Credits", function(panel)
		UiKit.label(panel, "Timber  v" .. VERSION, 15, Color3.new(1, 1, 1), UiKit.Bold, { LayoutOrder = 2, TextTransparency = 0.45 })
		UiKit.label(panel, "Made by NeekBot5000, with Claude.", 17, Color3.new(1, 1, 1), UiKit.Bold, { LayoutOrder = 3 })
		UiKit.label(panel, "Every model, sound and song in the game is made from code inside the game itself.", 15, Color3.new(1, 1, 1), UiKit.Body,
			{ LayoutOrder = 4, TextTransparency = 0.25, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
		UiKit.label(panel, "First made with the Godot Engine (godotengine.org); this is its Roblox version.", 15, ACCENT, UiKit.Bold,
			{ LayoutOrder = 5, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
		UiKit.label(panel, "Fonts: Nunito (The Nunito Project Authors) and Fredoka (The Fredoka Project Authors), SIL Open Font License 1.1.", 13, Color3.new(1, 1, 1), UiKit.Body,
			{ LayoutOrder = 6, TextTransparency = 0.35, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	end)
end

-- the title screen itself
open = function()
	if gui then
		gui:Destroy()
	end
	State.uiOpen = true
	local g = Instance.new("ScreenGui")
	g.Name = "TitleMenu"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 20
	gui = g
	-- the forest shows on the right; a soft dark band on the left (and a modal button frees the mouse)
	local shade = Instance.new("TextButton")
	shade.Text = ""
	shade.Modal = true
	shade.AutoButtonColor = false
	shade.BackgroundColor3 = Color3.new(0.05, 0.06, 0.05)
	shade.BackgroundTransparency = 0.45
	shade.Size = UDim2.new(0, 470, 1, 0)
	shade.Parent = g
	local v = Instance.new("Frame")
	v.BackgroundTransparency = 1
	v.AnchorPoint = Vector2.new(0, 0.5)
	v.Position = UDim2.new(0, 64, 0.5, 0)
	v.Size = UDim2.fromOffset(356, 500)
	v.Parent = g
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 14)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = v
	UiKit.label(v, "Timber", 86, ACCENT, UiKit.Title, { LayoutOrder = 1, TextStrokeColor3 = Color3.new(0.12, 0.08, 0.04), TextStrokeTransparency = 0.2 })
	UiKit.label(v, "Peel it. Fell it. Build something bigger.", 18, Color3.new(1, 1, 1), UiKit.Bold, { LayoutOrder = 2, TextTransparency = 0.2 })
	local gap = Instance.new("Frame")
	gap.BackgroundTransparency = 1
	gap.Size = UDim2.fromOffset(1, 24)
	gap.LayoutOrder = 3
	gap.Parent = v
	local fresh = player:GetAttribute("Fresh") ~= false
	if not fresh then
		button(v, "Continue", true, 4, function()
			close()
		end)
	end
	local confirm: TextButton
	confirm = button(v, "New Game", fresh, 5, function()
		if not fresh and confirm.Text == "New Game" then
			confirm.Text = "Start over? Your saved world will be lost"
			confirm.TextSize = 16
			return
		end
		if not fresh then
			remotes.NewGame:FireServer()
		end
		close()
	end)
	button(v, "Settings", false, 6, settings)
	button(v, "Credits", false, 7, credits)
	local ver = UiKit.label(g, "v" .. VERSION, 14, Color3.new(1, 1, 1), UiKit.Bold, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 64, 1, -26), TextTransparency = 0.55 })
	local _ = ver
	g.Parent = player:WaitForChild("PlayerGui")
end

TitleController.open = open
TitleController.isOpen = function(): boolean
	return gui ~= nil
end

function TitleController.start()
	State.uiOpen = true          -- (nothing to do behind the title until it closes)
	task.spawn(function()
		-- wait for the save (it says whether there's anything to continue), then show the title
		for _ = 1, 40 do
			if player:GetAttribute("Owned") ~= nil then
				break
			end
			task.wait(0.25)
		end
		readSettings()
		player:GetAttributeChangedSignal("Settings"):Connect(readSettings)
		open()
	end)
end

return TitleController
