--!strict
-- TimberMart, laid out like the Godot game's computer shop (ShopUI.gd): a dark header with the name, the tagline,
-- your money and a close button; a light sidebar of departments and what you own; and a page of product cards,
-- each with its tag, a turning 3D preview of the tool, its price, bars for strip size and speed, and a button
-- (Owned, Buy, or greyed out when you can't afford it). E or the close button shuts it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Config = require(ReplicatedStorage.Shared.Config)
local UiKit = require(script.Parent.Parent.Ui.UiKit)
local State = require(script.Parent.Parent.State)
local Sfx = require(script.Parent.Parent.Sfx)

local ShopController = {}
local player = Players.LocalPlayer
local C = UiKit.Colors
local gui: ScreenGui? = nil
local spinning: { { cam: Camera, center: Vector3, dist: number } } = {}
local spinConn: RBXScriptConnection? = nil

local function owns(id: string): boolean
	local s = player:GetAttribute("Owned")
	return typeof(s) == "string" and table.find(string.split(s, ","), id) ~= nil
end

local function ordered(id: string): boolean
	local s = player:GetAttribute("Ordered")
	return typeof(s) == "string" and table.find(string.split(s, ","), id) ~= nil
end

local function money(): number
	local m = player:GetAttribute("Money")
	return if typeof(m) == "number" then m else 0
end

local function frame(parent: Instance, color: Color3, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

local function statBar(parent: Instance, label: string, frac: number, order: number)
	local row = frame(parent, C.card, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order })
	UiKit.label(row, label, 13, C.muted, UiKit.Body, { Position = UDim2.fromOffset(0, 3) })
	local back = frame(row, C.barBack, { Size = UDim2.new(0.5, 0, 0, 7), Position = UDim2.new(0.4, 0, 0, 8) })
	UiKit.corner(back, 4)
	local fill = frame(back, C.price, { Size = UDim2.fromScale(math.clamp(frac, 0.06, 1), 1) })
	UiKit.corner(fill, 4)
end

function ShopController.close()
	if gui then
		gui:Destroy()
		gui = nil
		Sfx.play("click")
	end
	table.clear(spinning)
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
	State.uiOpen = false
end

local function card(grid: Instance, id: string, order: number): GuiObject?
	local def = (Config.Tools :: any)[id] or (Config.Items :: any)[id]
	local c = frame(grid, C.card, { LayoutOrder = order, Name = id })
	UiKit.corner(c, 14)
	UiKit.stroke(c, 1, Color3.fromHex("e2d9cc"))
	UiKit.pad(c, 14, 14)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = c
	-- the tag pill
	local pill = UiKit.label(c, string.upper(def.tag or ""), 12, C.orange, UiKit.Bold, { BackgroundTransparency = 0, BackgroundColor3 = C.peach, LayoutOrder = 1 })
	UiKit.corner(pill, 8)
	UiKit.pad(pill, 7, 3)
	-- the turning 3D preview
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundColor3 = C.preview
	vp.BorderSizePixel = 0
	vp.Size = UDim2.new(1, 0, 0, 150)
	vp.LayoutOrder = 2
	vp.Ambient = Color3.fromRGB(190, 190, 190)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	UiKit.corner(vp, 10)
	vp.Parent = c
	local models = ReplicatedStorage:FindFirstChild("ToolModels")
	local src = models and models:FindFirstChild(id)
	if src then
		local m = (src :: Model):Clone()
		m.Parent = vp
		local cf, size = m:GetBoundingBox()
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		cam.Parent = vp
		vp.CurrentCamera = cam
		table.insert(spinning, { cam = cam, center = cf.Position, dist = size.Magnitude * 1.9 })
	end
	UiKit.label(c, def.name, 19, C.ink, UiKit.Bold, { LayoutOrder = 3 })
	UiKit.label(c, string.format("$%d", def.price), 20, C.price, UiKit.Title, { LayoutOrder = 4 })
	if def.stripRadius and def.stripRadius > 0 then
		statBar(c, "Strip size", def.stripRadius / 0.6, 5)
		statBar(c, "Speed", (1.25 - def.cooldown) / 1.0, 6)
	end
	local have = owns(id) and not def.consumable     -- (boxes of dynamite: buy as many as you like)
	local ordered = ordered(id)
	local afford = money() >= def.price
	if ordered then
		UiKit.label(c, "Ordered - the delivery van is bringing it.", 14, Color3.fromHex("2e6da4"), UiKit.Bold, { LayoutOrder = 7, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
		return nil
	end
	local text = if have then "Owned" elseif afford then "Buy" else "Not enough money"
	local b = UiKit.button(c, text, if have or not afford then C.owned else C.orange, if have or not afford then C.ink else C.white, function()
		if not have and afford then
			(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Buy") :: RemoteEvent):FireServer(id)
			ShopController.close()
		end
	end, { Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 7, AutoButtonColor = not have and afford })
	return b
end

function ShopController.open(fromPhone: boolean?)
	if gui then
		return
	end
	State.uiOpen = true
	Sfx.play("boot", 1, -6)
	local g = Instance.new("ScreenGui")
	g.Name = "TimberMart"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 10
	gui = g
	-- the page behind: a modal button, which also frees the mouse from first person while the shop is open
	local back = Instance.new("TextButton")
	back.Text = ""
	back.AutoButtonColor = false
	back.Modal = true
	back.BackgroundColor3 = Color3.fromHex("d9d1c2")
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = g
	local win = frame(g, C.page, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.96, 0, 0.92, 0) })
	-- header
	local header = frame(win, C.header, { Size = UDim2.new(1, 0, 0, 66) })
	UiKit.label(header, "TimberMart", 30, Color3.fromHex("f5a35c"), UiKit.Title, { Position = UDim2.fromOffset(16, 14) })
	local narrowScreen = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X < 1100
	if not narrowScreen then
		-- (on a phone the header's buttons need the room)
		UiKit.label(header, "Tools & gear for the working lumberjack", 15, Color3.fromHex("cfc5b8"), UiKit.Body, { Position = UDim2.fromOffset(196, 24) })
	end
	local right = frame(header, C.header, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 13), Size = UDim2.fromOffset(330, 40) })
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Right
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 14)
	row.Parent = right
	UiKit.label(right, string.format("$%.2f", money()), 22, C.green, UiKit.Title, { LayoutOrder = 1 })
	local closeBtn = UiKit.button(right, if narrowScreen then "Close" else "Close  [E]", Color3.fromHex("8a3a1c"), C.white, ShopController.close,
		{ Size = UDim2.fromOffset(if narrowScreen then 84 else 120, 38), LayoutOrder = 2 })
	if fromPhone then
		-- the TimberPhone also sends the log truck off, from anywhere
		-- (on a phone, shorter labels, so the header's buttons don't run over the title)
		local btnW = if narrowScreen then 104 else 150
		UiKit.button(right, if narrowScreen then "Send truck" else "Send the truck", Color3.fromHex("2f7d4a"), C.white, function()
			(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PhoneShip") :: RemoteEvent):FireServer()
			ShopController.close()
		end, { Size = UDim2.fromOffset(btnW, 38), LayoutOrder = 0 })
		right.Size = UDim2.fromOffset(if narrowScreen then 440 else 500, 40)
		-- and invites friends (Roblox's own invite window), when Roblox lets this player send invites
		task.spawn(function()
			local SocialService = game:GetService("SocialService")
			local ok, can = pcall(function()
				return SocialService:CanSendGameInviteAsync(player)
			end)
			if ok and can and right.Parent then
				UiKit.button(right, if narrowScreen then "Invite" else "Invite friends", Color3.fromHex("2e6da4"), C.white, function()
					pcall(function()
						SocialService:PromptGameInvite(player)
					end)
				end, { Size = UDim2.fromOffset(btnW, 38), LayoutOrder = -1 })
				right.Size = UDim2.fromOffset(if narrowScreen then 560 else 664, 40)
			end
		end)
	end
	-- sidebar
	-- (it scrolls: on a phone, the departments, codes and lists don't all fit)
	local side = Instance.new("ScrollingFrame")
	side.BackgroundColor3 = C.side
	side.BorderSizePixel = 0
	side.Position = UDim2.fromOffset(0, 66)
	side.Size = UDim2.new(0, 230, 1, -100)
	side.AutomaticCanvasSize = Enum.AutomaticSize.Y
	side.CanvasSize = UDim2.new()
	side.ScrollBarThickness = 6
	side.Parent = win
	UiKit.pad(side, 16, 16)
	local sl = Instance.new("UIListLayout")
	sl.Padding = UDim.new(0, 8)
	sl.SortOrder = Enum.SortOrder.LayoutOrder
	sl.Parent = side
	UiKit.label(side, "DEPARTMENTS", 12, C.muted, UiKit.Bold, { LayoutOrder = 1 })
	local n = #Config.ShopOrder
	-- Godot's departments, with how many each has; click one to show only those
	local grid: Frame
	local function dept(id: string): string
		return (Config.ShopCat :: any)[id] or "other"
	end
	-- (Godot's departments that have something in them)
	local depts = {}
	for _, d in Config.ShopDepts do
		local any = d[1] == "all"
		for _, id in Config.ShopOrder do
			any = any or dept(id) == d[1]
		end
		if any then
			table.insert(depts, d)
		end
	end
	local deptLabels: { [string]: TextButton } = {}
	local function show(which: string)
		for key, b in deptLabels do
			b.BackgroundColor3 = if key == which then C.orange else Color3.fromHex("f6f1e9")
			b.TextColor3 = if key == which then C.white else C.ink
		end
		for _, c in grid:GetChildren() do
			if c:IsA("GuiObject") then
				c.Visible = which == "all" or dept(c.Name) == which
			end
		end
	end
	for k, d in depts do
		local count = 0
		for _, id in Config.ShopOrder do
			if d[1] == "all" or dept(id) == d[1] then
				count += 1
			end
		end
		local b = UiKit.button(side, string.format("%s  (%d)", d[2], count), Color3.fromHex("f6f1e9"), C.ink, function()
			show(d[1])
		end, { Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 1 + k, TextXAlignment = Enum.TextXAlignment.Left })
		UiKit.pad(b, 10, 0)
		deptLabels[d[1]] = b
	end
	local have = 0
	for _, id in Config.ShopOrder do
		if owns(id) then
			have += 1
		end
	end
	UiKit.label(side, "YOUR CABIN", 12, C.muted, UiKit.Bold, { LayoutOrder = 10 })
	UiKit.label(side, string.format("Owned: %d of %d items", have, n), 14, C.ink, UiKit.Body, { LayoutOrder = 11 })
	if fromPhone then
		-- the TimberPhone: the wood of the day (EconomyService.woodOfTheDay), which pays more at the mill
		local wood = ReplicatedStorage:GetAttribute("WoodOfTheDay")
		local woodDef = typeof(wood) == "string" and (Config.Species :: any)[wood]
		if woodDef then
			UiKit.label(side, string.format("At the mill today: %s pays 1.5x", woodDef.name), 13, C.price, UiKit.Bold,
				{ LayoutOrder = 15, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
		end
		-- the golden tree (EventService): where it is now, or how long until the next one
		local where = ReplicatedStorage:GetAttribute("GoldenWhere")
		local nextAt = ReplicatedStorage:GetAttribute("GoldenNext")
		local goldText = if typeof(where) == "string" then string.format("Golden tree now: %s of the cabin!", where)
			elseif typeof(nextAt) == "number" then string.format("Next golden tree in %d min", math.max(1, math.ceil((nextAt - os.time()) / 60)))
			else nil
		if goldText then
			UiKit.label(side, goldText, 13, if typeof(where) == "string" then C.price else C.ink, if typeof(where) == "string" then UiKit.Bold else UiKit.Body,
				{ LayoutOrder = 15, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
		end
		-- the daily streak (EconomyService.daily)
		local streak = player:GetAttribute("Streak")
		if typeof(streak) == "number" and streak > 1 then
			UiKit.label(side, string.format("Daily streak: %d days", streak), 13, C.ink, UiKit.Body, { LayoutOrder = 15 })
		end
		-- today's jobs (JobsService), with how far along each is
		local okJobs, jobs = pcall(function()
			return game:GetService("HttpService"):JSONDecode(player:GetAttribute("Jobs") :: string)
		end)
		if okJobs and typeof(jobs) == "table" and #jobs > 0 then
			UiKit.label(side, string.format("TODAY'S JOBS  (all three: +$%d more)", Config.JobsAllBonus), 12, C.muted, UiKit.Bold, { LayoutOrder = 16 })
			for k, j in jobs do
				local text = if j.done then string.format("Done: %s", tostring(j.text))
					else string.format("%s  %d/%d  +$%d", tostring(j.text), tonumber(j.have) or 0, tonumber(j.need) or 0, tonumber(j.pay) or 0)
				UiKit.label(side, text, 13, if j.done then C.green else C.ink, if j.done then UiKit.Bold else UiKit.Body,
					{ LayoutOrder = 16 + k, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
			end
		end
		-- codes (type one in, the server checks it), below the jobs and who's here
		UiKit.label(side, "CODES", 12, C.muted, UiKit.Bold, { LayoutOrder = 30 })
		local codeBox = Instance.new("TextBox")
		codeBox.Name = "CodeBox"
		codeBox.PlaceholderText = "Type a code"
		codeBox.Text = ""
		codeBox.ClearTextOnFocus = false
		codeBox.FontFace = UiKit.Body
		codeBox.TextSize = 15
		codeBox.TextColor3 = C.ink
		codeBox.BackgroundColor3 = Color3.fromHex("f6f1e9")
		codeBox.BorderSizePixel = 0
		codeBox.Size = UDim2.new(1, 0, 0, 34)
		codeBox.LayoutOrder = 31
		UiKit.corner(codeBox, 8)
		codeBox.Parent = side
		UiKit.button(side, "Redeem", C.orange, C.white, function()
			if codeBox.Text ~= "" then
				(ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Redeem") :: RemoteEvent):FireServer(codeBox.Text)
				codeBox.Text = ""
			end
		end, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 32 })
		-- the best of all time, across every server (LeaderboardService)
		local okTop, top = pcall(function()
			return game:GetService("HttpService"):JSONDecode(ReplicatedStorage:GetAttribute("AllTime") :: string)
		end)
		if okTop and typeof(top) == "table" and #top > 0 then
			UiKit.label(side, "ALL-TIME BEST", 12, C.muted, UiKit.Bold, { LayoutOrder = 40 })
			for k, e in top do
				UiKit.label(side, string.format("%d. %s   $%d", k, tostring(e.name), math.floor(tonumber(e.earned) or 0)), 14,
					if e.name == player.Name then C.price else C.ink, UiKit.Body,
					{ LayoutOrder = 40 + k, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None })
			end
		end
		-- who's on this server, by what they've earned at the mill, and the trees they've felled
		UiKit.label(side, "LUMBERJACKS HERE", 12, C.muted, UiKit.Bold, { LayoutOrder = 20 })
		local everyone = Players:GetPlayers()
		table.sort(everyone, function(a, b)
			return (a:GetAttribute("Earned") :: number? or 0) > (b:GetAttribute("Earned") :: number? or 0)
		end)
		for k, p in everyone do
			if k > 5 then
				break
			end
			local felled = p:GetAttribute("Felled") :: number? or 0
			local okName, display = pcall(function()
				return p.DisplayName
			end)
			local name = if okName and typeof(display) == "string" and display ~= "" then display else p.Name
			UiKit.label(side, string.format("%d. %s   $%d   %d tree%s", k, name, math.floor(p:GetAttribute("Earned") :: number? or 0),
				felled, if felled == 1 then "" else "s"), 14, if p == player then C.price else C.ink, if p == player then UiKit.Bold else UiKit.Body,
				{ LayoutOrder = 20 + k, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None })
		end
	end
	-- the page of products
	local page = Instance.new("ScrollingFrame")
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Position = UDim2.fromOffset(230, 66)
	page.Size = UDim2.new(1, -230, 1, -100)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.ScrollBarThickness = 8
	page.Parent = win
	UiKit.pad(page, 22, 18)
	local pl = Instance.new("UIListLayout")
	pl.Padding = UDim.new(0, 16)
	pl.SortOrder = Enum.SortOrder.LayoutOrder
	pl.Parent = page
	UiKit.label(page, "All products", 24, C.ink, UiKit.Bold, { LayoutOrder = 1 })
	if not owns("hatchet") then
		local banner = UiKit.label(page, "Tired of bruised knuckles?  The Trusty Hatchet is only $30 - no more pain, bigger bark sheets.", 16, C.white, UiKit.Bold,
			{ BackgroundTransparency = 0, BackgroundColor3 = C.price, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2 })
		UiKit.corner(banner, 12)
		UiKit.pad(banner, 18, 16)
	end
	grid = frame(page, C.page, { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 3 })
	local gl = Instance.new("UIGridLayout")
	gl.CellPadding = UDim2.fromOffset(16, 16)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	local cam = workspace.CurrentCamera
	local narrow = cam and cam.ViewportSize.X < 1000
	gl.CellSize = UDim2.new(if narrow then 0.5 else 1 / 3, -12, 0, 360)
	local first: GuiObject? = nil
	for k, id in Config.ShopOrder do
		local b = card(grid, id, k)
		first = first or b
	end
	show("all")
	-- the footer
	local foot = frame(win, Color3.fromHex("e8e0d2"), { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 34) })
	UiKit.label(foot, "Orders ship immediately. The orange delivery van drops your boxes at the loading dock by the cabin.", 14, C.muted, UiKit.Body, { Position = UDim2.fromOffset(12, 8) })
	g.Parent = player:WaitForChild("PlayerGui")
	-- gamepads: start on the first button
	GuiService.SelectedObject = first or closeBtn
	spinConn = RunService.RenderStepped:Connect(function()
		local a = os.clock() * 0.8
		for _, s in spinning do
			s.cam.CFrame = CFrame.lookAt(s.center + Vector3.new(math.sin(a) * s.dist, s.dist * 0.15, math.cos(a) * s.dist), s.center)
		end
	end)
end

function ShopController.start()
	-- Tab: the TimberPhone (Godot: "No phone" until you have one)
	local InputController = require(script.Parent.InputController)
	InputController.on("Phone", function(state)
		if state ~= Enum.UserInputState.Begin then
			return
		end
		if gui then
			ShopController.close()
		elseif State.uiOpen then
			return
		elseif owns("phone") then
			ShopController.open(true)
		else
			State.toast("No phone", Color3.fromHex("ffd27a"))
		end
	end)
	-- the shop closes itself if you faint or wander off (E closes it too: see InteractController)
	RunService.Heartbeat:Connect(function()
		if gui and State.fainted then
			ShopController.close()
		end
	end)
end

return ShopController
