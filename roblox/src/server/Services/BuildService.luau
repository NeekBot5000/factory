--!strict
-- Building with the hammer, the Godot game's way (Builder.gd, Blueprint.gd, Builds.finish):
--   * pick a build in the menu and set its hologram down on your own land: it becomes a plan (a see-through
--     hologram of the finished thing, with a counter over it of what it still needs)
--   * drop bark, logs, leaves (and later stone and ore) into it: each flies in and a part turns solid in that
--     material's own colour - parts fill in proportion (with 50 bark and 16 bark parts, one every ~3 bark)
--   * when it has everything, it's built (Godot's toast with its name); E on a plan cancels it and everything that
--     went in tumbles back out; X with the hammer takes a build down and pays what it would have sold for
--     (decorations far more than their materials, machines a bit less)
-- The client shows the hologram while you place it; the server checks the plan, owns the plans and fills them.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Builds = require(ReplicatedStorage.Shared.Builds)
local Land = require(ReplicatedStorage.Shared.Land)
local DataService = require(script.Parent.DataService)
local ToolService = require(script.Parent.ToolService)

local BuildService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local GHOST = Color3.new(0.45, 0.85, 1.0)
local GHOST_T = 0.68
local nextId = 0

local function folder(name: string, parent: Instance): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Instance
end

local function decode(s: unknown): { [string]: any }
	if typeof(s) ~= "string" then
		return {}
	end
	local ok, t = pcall(function()
		return HttpService:JSONDecode(s :: string)
	end)
	return if ok and type(t) == "table" then t else {}
end

local function ghost(p: BasePart)
	p.Color = GHOST
	p.Transparency = GHOST_T
	p.CastShadow = false
	p.CanCollide = false
	p.Material = Enum.Material.SmoothPlastic
end

-- the counter over a plan: what it still needs (Godot's floating label: one of the 3D texts the game keeps)
local function updateLabel(plan: Model)
	local needs = decode(plan:GetAttribute("Needs"))
	local have = decode(plan:GetAttribute("Have"))
	local left = {}
	for r, n in needs do
		left[r] = n - (have[r] or 0)
	end
	local text = Builds.needsText(left, plan:GetAttribute("Build") :: string)
	plan:SetAttribute("Left", text)
	local bb = plan:FindFirstChild("Counter", true) :: BillboardGui?
	local lbl = bb and bb:FindFirstChildOfClass("TextLabel")
	if lbl then
		lbl.Text = text
	end
end

local function counter(plan: Model, top: number)
	local anchor = Instance.new("Part")
	anchor.Name = "CounterAnchor"
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = plan:GetPivot() * CFrame.new(0, top + 0.35 * M, 0)
	anchor.Parent = plan
	local bb = Instance.new("BillboardGui")
	bb.Name = "Counter"
	bb.Size = UDim2.fromOffset(420, 40)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 60
	bb.Adornee = anchor
	bb.Parent = anchor
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.TextColor3 = Color3.fromHex("bfeaff")
	l.TextStrokeColor3 = Color3.new(0.05, 0.08, 0.12)
	l.TextStrokeTransparency = 0.15
	l.TextScaled = true
	l.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	l.Parent = bb
end

-- Places a plan (or, with `done`, a finished build) of `id` at `cf` and `size`. Returns the Model.
function BuildService.make(id: string, cf: CFrame, size: number, owner: number, done: boolean?, colors: { [string]: string }?): Model?
	local def = Builds.def(id)
	local m = Builds.model(id)
	if not def or not m then
		return nil
	end
	nextId += 1
	m:ScaleTo(size)
	m:PivotTo(cf)
	m:SetAttribute("Build", id)
	m:SetAttribute("Size", size)
	m:SetAttribute("Owner", owner)
	m:SetAttribute("Uid", string.format("%d_%d", owner, nextId))
	if done then
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				local c = colors and colors[tostring(p:GetAttribute("Index"))]
				if c then
					p.Color = Color3.fromHex(c)
				end
				p.CanCollide = true
			end
		end
		m:SetAttribute("Kind", "build")
		m.Parent = folder("Builds", workspace)
	else
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				ghost(p)
			end
		end
		m:SetAttribute("Kind", "plan")
		m:SetAttribute("Needs", HttpService:JSONEncode(Builds.needsFor(id, size)))
		m:SetAttribute("Have", "{}")
		m:SetAttribute("Filled", "{}")
		m:SetAttribute("Worth", 0)
		counter(m, def.top * size)
		updateLabel(m)
		m.Parent = folder("Plans", workspace)
	end
	return m
end

local function place(player: Player, id: unknown, cf: unknown, size: unknown)
	if typeof(id) ~= "string" or typeof(cf) ~= "CFrame" or typeof(size) ~= "number" then
		return
	end
	local data = DataService.get(player)
	local def = Builds.def(id :: string)
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not data or not def or not head or ToolService.current(player) ~= "hammer" then
		return
	end
	if not Builds.unlocked(id :: string, data.owned) or not Builds.sizeOk(id :: string, size :: number) then
		return
	end
	local at = (cf :: CFrame).Position
	if (at - head.Position).Magnitude > (Builds.REACH * math.max(1, size :: number) + 2) * M then
		return
	end
	if not Land.owns(data.land or {}, at) then
		remotes.Notify:FireClient(player, "This isn't your land - buy it at a for-sale sign", "ffd27a")
		return
	end
	-- (upright: only turned about the vertical)
	local look = (cf :: CFrame).LookVector * Vector3.new(1, 0, 1)
	local flat = if look.Magnitude > 0.01 then CFrame.lookAt(at, at + look.Unit) else CFrame.new(at)
	BuildService.make(id :: string, flat, size :: number, player.UserId)
	remotes.Fx:FireAllClients("thud", at, 1.6)
end

-- The materials that went into a plan wait here (Godot keeps them, frozen and hidden), so a cancel gives them back.
local function store(plan: Model): Instance
	return folder(plan:GetAttribute("Uid") :: string, folder("PlanStore", ServerStorage))
end

local function complete(plan: Model)
	local id = plan:GetAttribute("Build") :: string
	local def = Builds.def(id) :: Builds.Def
	local filled = decode(plan:GetAttribute("Filled"))
	local colors = {}
	for _, p in plan:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Index") ~= nil then
			local k = tostring(p:GetAttribute("Index"))
			local res = p:GetAttribute("Res")
			local partDef = def.parts[(p:GetAttribute("Index") :: number) + 1]
			colors[k] = if res ~= "" and filled[k] then filled[k] else (partDef and partDef.color or "999999")
		end
	end
	local owner = plan:GetAttribute("Owner") :: number
	local b = BuildService.make(id, plan:GetPivot(), plan:GetAttribute("Size") :: number, owner, true, colors)
	if b then
		b:SetAttribute("SaleValue", 0)
		-- machines sell back for a bit less than their materials, decorations for far more (the work adds value)
		b:SetAttribute("SaleValue", math.floor((plan:GetAttribute("Worth") :: number) * def.sell * 100 + 0.5) / 100)
		require(script.Parent.BuildBehaviors).activate(b)
	end
	local s = store(plan)
	s:Destroy()
	local at = plan:GetPivot().Position
	plan:Destroy()
	remotes.Fx:FireAllClients("reveal", at)
	local p = Players:GetPlayerByUserId(owner)
	if p then
		remotes.Notify:FireClient(p, def.name, "7aff9a")
		local TrophyService = require(script.Parent.TrophyService) :: any
		if def.machine then
			TrophyService.award(p, "first_machine")
		end
	end
end

-- One dropped thing goes into the plan (Godot's _absorb).
local function absorb(plan: Model, item: BasePart, res: string, amount: number, color: Color3)
	local id = plan:GetAttribute("Build") :: string
	local needs = decode(plan:GetAttribute("Needs"))
	local have = decode(plan:GetAttribute("Have"))
	local filled = decode(plan:GetAttribute("Filled"))
	local take = math.min(amount, needs[res] - (have[res] or 0))
	have[res] = (have[res] or 0) + take
	-- parts fill in proportion
	local parts = Builds.partsFor(plan, res)
	local done = 0
	for _, p in parts do
		if filled[tostring(p:GetAttribute("Index"))] then
			done += 1
		end
	end
	local should = if have[res] >= needs[res] then #parts else math.floor(have[res] * #parts / needs[res])
	local hex = color:ToHex()
	for _, p in parts do
		if done >= should then
			break
		end
		local k = tostring(p:GetAttribute("Index"))
		if not filled[k] then
			filled[k] = hex
			p.Color = color
			p.Transparency = 0
			p.CastShadow = true
			done += 1
		end
	end
	-- what it would have sold for (a log's worth depends on its bark)
	local value = item:GetAttribute("Value") :: number? or 0
	if item.Name == "Trunk" and item.Parent and item.Parent:GetAttribute("Kind") == "log" then
		local ok, LogService = pcall(require, script.Parent.LogService)
		if ok then
			value = (LogService :: any).value(item.Parent)
		end
	end
	plan:SetAttribute("Worth", (plan:GetAttribute("Worth") :: number) + value)
	plan:SetAttribute("Have", HttpService:JSONEncode(have))
	plan:SetAttribute("Filled", HttpService:JSONEncode(filled))
	updateLabel(plan)
	-- the material disappears into the build (kept, for a cancel)
	local whole: Instance = if item.Name == "Trunk" and item.Parent and item.Parent:GetAttribute("Kind") == "log" then item.Parent else item
	whole.Parent = store(plan)
	remotes.Fx:FireAllClients("pickup", item.Position, 0.8)
	for r, n in needs do
		if (have[r] or 0) < n then
			return
		end
	end
	complete(plan)
	local _ = id
end

function BuildService.step()
	local plans = workspace:FindFirstChild("Plans")
	if not plans then
		return
	end
	for _, plan in plans:GetChildren() do
		if not plan:IsA("Model") then
			continue
		end
		local cf, size = plan:GetBoundingBox()
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		local roots = {}
		for _, name in { "Loose", "Logs" } do
			local f = workspace:FindFirstChild(name)
			if f then
				table.insert(roots, f)
			end
		end
		params.FilterDescendantsInstances = roots
		local seen = {}
		for _, part in workspace:GetPartBoundsInBox(cf, size + Vector3.new(0.5, 0.4, 0.5) * M, params) do
			if seen[part] or part.Anchored or part:GetAttribute("HeldBy") or part.Parent == nil then
				continue
			end
			seen[part] = true
			local item = part
			-- (a sheet's panels ride on the first one, which is the sheet)
			if part.Parent and part.Parent:IsA("BasePart") then
				item = part.Parent :: BasePart
			end
			local res, amount, color = Builds.resourceOf(item)
			local needs = decode(plan:GetAttribute("Needs"))
			local have = decode(plan:GetAttribute("Have"))
			if res and needs[res] and (have[res] or 0) < needs[res] and color then
				absorb(plan, item, res, amount, color)
				if plan.Parent == nil then
					break
				end
			end
		end
	end
end

-- E on a plan: it's cancelled and everything that went in tumbles out (Godot's Blueprint.cancel)
function BuildService.cancel(player: Player, plan: Model): boolean
	if plan:GetAttribute("Kind") ~= "plan" or plan:GetAttribute("Owner") ~= player.UserId then
		return false
	end
	local c = plan:GetPivot().Position + Vector3.new(0, 0.6 * M, 0)
	local loose = folder("Loose", workspace)
	for _, thing in store(plan):GetChildren() do
		local root: BasePart? = if thing:IsA("BasePart") then thing else (thing:FindFirstChild("Trunk") :: BasePart?)
		thing.Parent = if thing:IsA("Model") then folder("Logs", workspace) else loose
		if root then
			local at = c + Vector3.new(math.random() * 0.8 - 0.4, math.random() * 0.5, math.random() * 0.8 - 0.4) * M
			if thing:IsA("Model") then
				(thing :: Model):PivotTo(CFrame.new(at) * ((thing :: Model):GetPivot() - (thing :: Model):GetPivot().Position))
			else
				root.CFrame = CFrame.new(at) * (root.CFrame - root.Position)
			end
			root.AssemblyLinearVelocity = Vector3.new(math.random() * 3 - 1.5, 1.5 + math.random() * 1.5, math.random() * 3 - 1.5) * M
		end
	end
	store(plan):Destroy()
	plan:Destroy()
	remotes.Fx:FireAllClients("drop", c, 0.8)
	return true
end

-- X with the hammer on a build: it's gone, and you get back what it would have sold for (Godot's take_down)
function BuildService.takeDown(player: Player, build: Model): boolean
	if build:GetAttribute("Kind") ~= "build" or build:GetAttribute("Owner") ~= player.UserId then
		return false
	end
	local value = build:GetAttribute("SaleValue") :: number? or 0
	local at = build:GetPivot().Position
	build:Destroy()
	local ok, EconomyService = pcall(require, script.Parent.EconomyService)
	if ok and value > 0 then
		(EconomyService :: any).addMoney(player, value)
	end
	remotes.Fx:FireAllClients("drop", at, 0.7)
	return true
end

local function buildOf(target: unknown): Model?
	if typeof(target) ~= "Instance" then
		return nil
	end
	local m = (target :: Instance):FindFirstAncestorWhichIsA("Model")
	while m and m:GetAttribute("Kind") ~= "plan" and m:GetAttribute("Kind") ~= "build" do
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	return m
end

local function near(player: Player, m: Model): boolean
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	return head ~= nil and (m:GetPivot().Position - head.Position).Magnitude < 6 * M * math.max(1, m:GetAttribute("Size") :: number? or 1)
end

-- ------------------------------------------------------------------ saving (Godot's Builds.save_world / load_world)
-- Your builds and plans are saved with you: where they are, how big, and (builds) the colours of what went in or
-- (plans) what's in them so far. They come back when you play again, and go with you when you leave.
local function cfArr(cf: CFrame): { number }
	return { cf:GetComponents() }
end

function BuildService.serialize(userId: number): { any }
	local out = {}
	for _, name in { "Builds", "Plans" } do
		local f = workspace:FindFirstChild(name)
		for _, m in if f then f:GetChildren() else {} do
			if m:IsA("Model") and m:GetAttribute("Owner") == userId then
				local e: any = { id = m:GetAttribute("Build"), cf = cfArr(m:GetPivot()), size = m:GetAttribute("Size"), kind = m:GetAttribute("Kind") }
				if e.kind == "build" then
					local colors = {}
					for _, p in m:GetChildren() do
						if p:IsA("BasePart") and p:GetAttribute("Index") ~= nil then
							colors[tostring(p:GetAttribute("Index"))] = p.Color:ToHex()
						end
					end
					e.colors = colors
					e.sale = m:GetAttribute("SaleValue")
					e.stock = m:GetAttribute("Stock")
					-- a machine's state: a wound crank, a lever that's on, a generator's fuel, a battery's charge
					e.state = { charge = m:GetAttribute("Charge"), on = m:GetAttribute("On"), fuel = m:GetAttribute("Fuel"),
						setting = m:GetAttribute("Setting"), latch = m:GetAttribute("LatchOn"), count = m:GetAttribute("Count"), recipe = m:GetAttribute("Recipe"),
						channel = m:GetAttribute("Channel"), filter = m:GetAttribute("Filter") }
					e.uid = m:GetAttribute("Uid")
				else
					e.have = m:GetAttribute("Have")
					e.filled = m:GetAttribute("Filled")
					e.worth = m:GetAttribute("Worth")
				end
				table.insert(out, e)
			end
		end
	end
	-- wires between your machines: by where their ends are in this list
	local at = {}
	for k, e in out do
		if e.uid then
			at[e.uid] = k
		end
	end
	local wires = workspace:FindFirstChild("Wires")
	for _, w in if wires then wires:GetChildren() else {} do
		local a, b = at[w:GetAttribute("A")], at[w:GetAttribute("B")]
		if a and b then
			table.insert(out, { kind = "wire", a = a, b = b })
		end
	end
	for _, e in out do
		e.uid = nil
	end
	-- baskets and wheelbarrows you carry about: a build too
	local loose = workspace:FindFirstChild("Loose")
	for _, p in if loose then loose:GetChildren() else {} do
		if p:IsA("BasePart") and p:GetAttribute("Kind") == "basket" and p:GetAttribute("Owner") == userId then
			table.insert(out, { id = p:GetAttribute("Build"), cf = cfArr(p.CFrame), size = 1, kind = "carry", sale = p:GetAttribute("SaleValue") })
		end
	end
	return out
end

function BuildService.restore(player: Player, list: { any })
	local made: { [number]: Model } = {}
	for k, e in list or {} do
		if typeof(e) == "table" and e.kind == "wire" then
			continue
		end
		if typeof(e) ~= "table" or not Builds.def(e.id) then
			continue
		end
		local c = e.cf
		local cf = CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
		if e.kind == "plan" then
			local m = BuildService.make(e.id, cf, e.size or 1, player.UserId)
			if m then
				m:SetAttribute("Have", e.have or "{}")
				m:SetAttribute("Filled", e.filled or "{}")
				m:SetAttribute("Worth", e.worth or 0)
				for k, hex in decode(e.filled) do
					local p = m:FindFirstChild(k) :: BasePart?
					if p then
						p.Color = Color3.fromHex(hex)
						p.Transparency = 0
						p.CastShadow = true
					end
				end
				updateLabel(m)
			end
		elseif e.kind == "carry" then
			local m = BuildService.make(e.id, cf, e.size or 1, player.UserId, true, {})
			if m then
				m:SetAttribute("SaleValue", e.sale or 0)
				require(script.Parent.BuildBehaviors).activate(m)
			end
		else
			local m = BuildService.make(e.id, cf, e.size or 1, player.UserId, true, e.colors or {})
			if m then
				m:SetAttribute("SaleValue", e.sale or 0)
				if e.stock then
					m:SetAttribute("Stock", e.stock)
				end
				if typeof(e.state) == "table" then
					m:SetAttribute("Charge", e.state.charge)
					m:SetAttribute("On", e.state.on)
					m:SetAttribute("Fuel", e.state.fuel)
					m:SetAttribute("Setting", e.state.setting)
					m:SetAttribute("LatchOn", e.state.latch)
					m:SetAttribute("Count", e.state.count)
					m:SetAttribute("Recipe", e.state.recipe)
					m:SetAttribute("Channel", e.state.channel)
					m:SetAttribute("Filter", e.state.filter)
				end
				require(script.Parent.BuildBehaviors).activate(m)
				made[k] = m
			end
		end
	end
	for _, e in list or {} do
		if typeof(e) == "table" and e.kind == "wire" and made[e.a] and made[e.b] then
			require(script.Parent.CircuitService).toggle(made[e.a], made[e.b])
		end
	end
end

function BuildService.start()
	table.insert(DataService.beforeSave, function(player, data)
		data.builds = BuildService.serialize(player.UserId)
	end)
	table.insert(DataService.onLoaded, function(player, data)
		-- (old saves kept other things in "builds")
		if typeof(data.builds) == "table" and (data.builds[1] == nil or typeof(data.builds[1]) == "table") then
			BuildService.restore(player, data.builds)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- (saved just now: their builds go with them)
		task.defer(function()
			for _, name in { "Builds", "Plans" } do
				local f = workspace:FindFirstChild(name)
				for _, m in if f then f:GetChildren() else {} do
					if m:GetAttribute("Owner") == player.UserId then
						m:Destroy()
					end
				end
			end
		end)
	end)
	remotes.Build.OnServerEvent:Connect(place)
	remotes.PlanCancel.OnServerEvent:Connect(function(player, target)
		local m = buildOf(target)
		if m and near(player, m) then
			BuildService.cancel(player, m)
		end
	end)
	remotes.TakeDown.OnServerEvent:Connect(function(player, target)
		local m = buildOf(target)
		if m and near(player, m) and ToolService.current(player) == "hammer" then
			if m:GetAttribute("Kind") == "plan" then
				BuildService.cancel(player, m)
			else
				BuildService.takeDown(player, m)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.15)
			local ok, err = pcall(BuildService.step)
			if not ok then
				warn("[Timber] building: " .. tostring(err))
			end
		end
	end)
end

return BuildService
