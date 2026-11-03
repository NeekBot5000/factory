-- A pretend Roblox client in Lune, joined to a pretend server (harness.luau) in the same process. It runs the
-- real client scripts (StarterPlayerScripts.Client) for one player, with:
--   * remotes wired both ways: FireServer reaches the server's handlers, FireClient reaches OnClientEvent
--   * key presses and clicks through a UserInputService stand-in
--   * frames: RenderStepped / Heartbeat / BindToRenderStep run when the test calls client.frame()
--   * the Roblox methods Lune doesn't have (PivotTo, WaitForChild, Raycast, events...) added with implementMethod
-- so a test can press E, look at things, click, and check what the screen says and what the server did.
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local ClientHarness = {}

-- (Lune's CFrame.lookAt points away from the target; this one points at it, like Roblox's)
local function lookAt(from, to, up)
	local look = (to - from).Unit
	local right = look:Cross(up or roblox.Vector3.new(0, 1, 0))
	if right.Magnitude < 1e-6 then
		right = look:Cross(roblox.Vector3.new(1, 0, 0))
	end
	right = right.Unit
	return roblox.CFrame.fromMatrix(from, right, right:Cross(look), -look)
end
ClientHarness.CFrame = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame })

-- ------------------------------------------------------------------ events for any instance
local function newSignal()
	local s = { handlers = {} :: { any }, errors = {} :: { string } }
	function s:Connect(f)
		local h = { f = f, on = true }
		table.insert(self.handlers, h)
		return {
			Disconnect = function()
				h.on = false
			end,
			Connected = true,
		}
	end
	function s:Once(f)
		local c
		c = self:Connect(function(...)
			c.Disconnect()
			f(...)
		end)
		return c
	end
	function s:Fire(...)
		for _, h in table.clone(self.handlers) do
			if h.on then
				local ok, err = xpcall(h.f, function(e)
					return tostring(e) .. "\n" .. debug.traceback()
				end, ...)
				if not ok then
					print("CLIENT ERROR: " .. tostring(err))
					table.insert(ClientHarness.errors, tostring(err))
				end
			end
		end
	end
	function s:Wait()
		task.wait(0.02)
		return 0.016
	end
	return s
end
ClientHarness.newSignal = newSignal
ClientHarness.errors = {} :: { string }

-- one signal per (instance, event): instances get a hidden id attribute so the same instance finds its signals
local signals: { [string]: any } = {}
local nextId = 0
local function idOf(inst: any): string
	local id = inst:GetAttribute("__hid")
	if not id then
		nextId += 1
		id = "i" .. nextId
		inst:SetAttribute("__hid", id)
	end
	return id
end
function ClientHarness.signal(inst: any, name: string)
	local key = idOf(inst) .. "." .. name
	signals[key] = signals[key] or newSignal()
	return signals[key]
end
local attrWatch: { { inst: any, name: string, last: any } } = {}

local installed = false
local function install()
	-- (also used by the server harness: the Roblox methods Lune lacks)
	if installed then
		return
	end
	installed = true
	for _, ev in { "CharacterAdded", "HealthChanged", "Died", "Activated", "MouseEnter", "MouseLeave", "MouseButton1Down",
		"Changed", "Completed", "ChildAdded", "ChildRemoved", "AncestryChanged", "OnClientEvent", "Event", "Ended", "Touched" } do
		roblox.implementProperty("Instance", ev, function(self)
			return ClientHarness.signal(self, ev)
		end)
	end
	roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(self, name)
		local s = ClientHarness.signal(self, "attr:" .. name)
		table.insert(attrWatch, { inst = self, name = name, last = self:GetAttribute(name) })
		return s
	end)
	roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(self, name)
		return ClientHarness.signal(self, "prop:" .. name)
	end)
	roblox.implementMethod("Instance", "WaitForChild", function(self, name)
		for _ = 1, 50 do
			local c = self:FindFirstChild(name)
			if c then
				return c
			end
			task.wait(0.02)
		end
		error("WaitForChild timed out: " .. self:GetFullName() .. "." .. name)
	end)
	roblox.implementMethod("BindableEvent", "Fire", function(self, ...)
		ClientHarness.signal(self, "Event"):Fire(...)
	end)
	roblox.implementMethod("Sound", "Play", function(self)
		ClientHarness.played = ClientHarness.played or {}
		table.insert(ClientHarness.played, self)
	end)
	roblox.implementMethod("Sound", "Stop", function() end)
	local function pivotOf(self)
		if self:IsA("BasePart") then
			return self.CFrame
		end
		-- (like Roblox: a model with a PrimaryPart pivots with it, offset by its PivotOffset)
		local pp = self.PrimaryPart
		if pp then
			local ok, off = pcall(function()
				return pp.PivotOffset
			end)
			return pp.CFrame * (if ok and off then off else roblox.CFrame.new())
		end
		local ok, wp = pcall(function()
			return self.WorldPivot
		end)
		if ok and wp then
			return wp
		end
		return roblox.CFrame.new()
	end
	roblox.implementMethod("PVInstance", "GetPivot", pivotOf)
	roblox.implementMethod("PVInstance", "PivotTo", function(self, target)
		if self:IsA("BasePart") then
			self.CFrame = target
			return
		end
		local delta = target * pivotOf(self):Inverse()
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
		self.WorldPivot = target
	end)
	roblox.implementMethod("Model", "ScaleTo", function(self, k)
		local pivot = pivotOf(self)
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then
				local rel = pivot:ToObjectSpace(d.CFrame)
				d.Size = d.Size * k
				d.CFrame = pivot * (rel - rel.Position + rel.Position * k)
			end
		end
	end)
	roblox.implementMethod("Model", "GetBoundingBox", function(self)
		local lo, hi = nil, nil
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then
				local p, h = d.CFrame.Position, d.Size / 2
				local a, b = p - h, p + h
				lo = if lo then roblox.Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) else a
				hi = if hi then roblox.Vector3.new(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) else b
			end
		end
		lo = lo or roblox.Vector3.new()
		hi = hi or roblox.Vector3.new()
		return roblox.CFrame.new((lo + hi) / 2), hi - lo
	end)
	-- a raycast against every part's box (cylinders and balls count as their box: close enough for aiming tests)
	roblox.implementMethod("WorldRoot", "Raycast", function(self, origin, dir, params)
		local excl = {}
		for _, inst in (params and params.FilterDescendantsInstances) or {} do
			table.insert(excl, inst)
		end
		local best, bestT, bestN = nil, math.huge, nil
		local len = dir.Magnitude
		local unit = dir.Unit
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") and d.CanQuery and d.Transparency < 1 then
				local skip = false
				for _, e in excl do
					if d == e or d:IsDescendantOf(e) then
						skip = true
						break
					end
				end
				if not skip then
					local o = d.CFrame:PointToObjectSpace(origin)
					local v = d.CFrame:VectorToObjectSpace(unit)
					local h = d.Size / 2
					local tmin, tmax, nAxis = -math.huge, math.huge, nil
					local okHit = true
					for _, ax in { "X", "Y", "Z" } do
						local oo, vv, hh = (o :: any)[ax], (v :: any)[ax], (h :: any)[ax]
						if math.abs(vv) < 1e-9 then
							if oo < -hh or oo > hh then
								okHit = false
								break
							end
						else
							local t1, t2 = (-hh - oo) / vv, (hh - oo) / vv
							local sgn = -1
							if t1 > t2 then
								t1, t2 = t2, t1
								sgn = 1
							end
							if t1 > tmin then
								tmin = t1
								nAxis = { ax, sgn }
							end
							tmax = math.min(tmax, t2)
						end
					end
					if okHit and tmin <= tmax and tmin >= 0 and tmin <= len and tmin < bestT then
						best, bestT = d, tmin
						local n = roblox.Vector3.new(if nAxis and nAxis[1] == "X" then nAxis[2] else 0, if nAxis and nAxis[1] == "Y" then nAxis[2] else 0, if nAxis and nAxis[1] == "Z" then nAxis[2] else 0)
						bestN = d.CFrame:VectorToWorldSpace(n)
					end
				end
			end
		end
		if not best then
			return nil
		end
		return { Instance = best, Position = origin + unit * bestT, Normal = bestN, Material = best.Material, Distance = bestT }
	end)
	roblox.implementMethod("ParticleEmitter", "Emit", function() end)
	local serde = require("@lune/serde")
	roblox.implementMethod("HttpService", "JSONEncode", function(_, v)
		return serde.encode("json", v)
	end)
	roblox.implementMethod("HttpService", "JSONDecode", function(_, s)
		return serde.decode("json", s)
	end)
	roblox.implementMethod("Instance", "GetDebugId", function(self)
		return idOf(self)
	end)
end

ClientHarness.install = install

-- Starts a client for `player` (already joined on `server`). Returns the client: press/click/look/frame helpers.
function ClientHarness.start(server: any, player: any)
	install()
	local game = server.game
	local workspace = server.workspace
	local client = { player = player, sent = {} :: { any }, coreOff = {} :: { [string]: boolean } }

	-- remotes on the client: real RemoteEvent instances, wired to the server's handlers
	local RS = game:GetService("ReplicatedStorage")
	local folder = RS:FindFirstChild("Remotes")
	if not folder then
		folder = roblox.Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = RS
		for name in server.remotes do
			local e = roblox.Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = folder
		end
	end
	roblox.implementMethod("RemoteEvent", "FireServer", function(self, ...)
		table.insert(client.sent, { remote = self.Name, args = { ... } })
		server.remotes[self.Name].OnServerEvent:Fire(player, ...)
	end)
	-- (Roblox holds a remote's messages until the client connects a listener: so does this)
	local queued: { [string]: { any } } = {}
	server.toClient = function(name, to, ...)
		if to == nil or to == player then
			local args = { ... }
			task.defer(function()
				local sig = ClientHarness.signal(folder:FindFirstChild(name), "OnClientEvent")
				if #sig.handlers == 0 then
					queued[name] = queued[name] or {}
					table.insert(queued[name], args)
				else
					sig:Fire(table.unpack(args))
				end
			end)
		end
	end
	-- what the server sent before this client was listening
	for _, e in server.clientLog do
		if e.player == player or e.all then
			queued[e.remote] = queued[e.remote] or {}
			table.insert(queued[e.remote], e.args)
		end
	end
	client.flushQueued = function()
		for name, list in queued do
			local sig = ClientHarness.signal(folder:FindFirstChild(name), "OnClientEvent")
			if #sig.handlers > 0 then
				queued[name] = nil
				for _, args in list do
					sig:Fire(table.unpack(args))
				end
			end
		end
	end

	-- services the client uses
	local UIS = {
		InputBegan = newSignal(), InputEnded = newSignal(), InputChanged = newSignal(),
		MouseIconEnabled = true, TouchEnabled = false, KeyboardEnabled = true, GamepadEnabled = false,
		MouseBehavior = nil, down = {} :: { [any]: boolean },
	}
	function UIS:IsKeyDown(k)
		return self.down[k] == true
	end
	function UIS:GetLastInputType()
		return roblox.Enum.UserInputType.Keyboard
	end
	client.UIS = UIS
	local renderSteps: { { prio: number, f: (number) -> () } } = {}
	local RunService = { RenderStepped = newSignal(), Heartbeat = newSignal(), Stepped = newSignal() }
	function RunService:BindToRenderStep(_name, prio, f)
		table.insert(renderSteps, { prio = prio, f = f })
		table.sort(renderSteps, function(a, b)
			return a.prio < b.prio
		end)
	end
	function RunService:IsStudio()
		return false
	end
	function RunService:IsClient()
		return true
	end
	local TweenService = {}
	function TweenService:Create(inst, _info, props)
		local t = { Completed = newSignal() }
		function t:Play()
			for k, v in props do
				pcall(function()
					inst[k] = v
				end)
			end
			task.defer(function()
				t.Completed:Fire(roblox.Enum.PlaybackState.Completed)
			end)
		end
		function t:Cancel() end
		return t
	end
	local StarterGui = {}
	function StarterGui:SetCoreGuiEnabled(t, on)
		client.coreOff[t.Name] = not on
	end
	function StarterGui:SetCore() end
	local CAS = {}
	function CAS:BindAction() end
	function CAS:SetTitle() end
	function CAS:SetPosition() end
	function CAS:UnbindAction() end
	local ContentProvider = {}
	function ContentProvider:PreloadAsync() end
	local CollectionService = {}
	function CollectionService:GetTagged(tag)
		local out = {}
		for _, d in workspace:GetDescendants() do
			if d:HasTag(tag) then
				table.insert(out, d)
			end
		end
		return out
	end
	function CollectionService:HasTag(inst, tag)
		return typeof(inst) == "Instance" and inst:HasTag(tag)
	end
	function CollectionService:GetInstanceAddedSignal()
		return newSignal()
	end
	function CollectionService:GetInstanceRemovedSignal()
		return newSignal()
	end
	local Players = { LocalPlayer = player, PlayerAdded = newSignal(), PlayerRemoving = newSignal() }
	function Players:GetPlayers()
		return { player }
	end
	local GuiService = { SelectedObject = nil }
	local fakeGame = setmetatable({}, {
		__index = function(_, k)
			if k == "GetService" then
				return function(_, name)
					local svc = ({
						UserInputService = UIS, RunService = RunService, TweenService = TweenService, StarterGui = StarterGui,
						ContextActionService = CAS, ContentProvider = ContentProvider, CollectionService = CollectionService,
						Players = Players, GuiService = GuiService,
					} :: any)[name]
					return svc or game:GetService(name)
				end
			end
			local v = game[k]
			if type(v) == "function" then
				return function(_, ...)
					return v(game, ...)
				end
			end
			return v
		end,
	})

	-- the camera, at the player's head
	local cam = roblox.Instance.new("Camera")
	cam.Name = "Camera"
	cam.Parent = workspace
	cam.FieldOfView = 70
	workspace.CurrentCamera = cam
	cam.ViewportSize = roblox.Vector2.new(1280, 720)
	-- parts placed by Position in the project file (the Baseplate) have their CFrame at the origin in Lune
	for _, p in workspace:GetDescendants() do
		if p:IsA("BasePart") then
			local ok, pos = pcall(function()
				return p.Position
			end)
			if ok and pos and (p.CFrame.Position - pos).Magnitude > 0.01 and p.CFrame.Position.Magnitude < 0.01 then
				p.CFrame = roblox.CFrame.new(pos) * p.CFrame.Rotation
			end
		end
	end
	-- (properties Lune knows but has no value for yet)
	local char = player.Character
	if char then
		for _, p in char:GetDescendants() do
			if p:IsA("BasePart") then
				p.AssemblyLinearVelocity = roblox.Vector3.new()
			end
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.FloorMaterial = roblox.Enum.Material.Grass
		end
	end
	client.camera = cam

	local playerGui = player:FindFirstChild("PlayerGui") or roblox.Instance.new("PlayerGui")
	playerGui.Name = "PlayerGui"
	playerGui.Parent = player

	-- load the client's modules, each with its own `script`
	local modules: { [string]: any } = {}
	local function loadModule(inst)
		local key = inst:GetFullName()
		if modules[key] ~= nil then
			return modules[key]
		end
		local env = setmetatable({
			game = fakeGame,
			workspace = workspace,
			script = inst,
			require = nil,
			Instance = roblox.Instance, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = ClientHarness.CFrame,
			Color3 = roblox.Color3, Enum = roblox.Enum, UDim = roblox.UDim, UDim2 = roblox.UDim2, Font = roblox.Font,
			NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, Rect = roblox.Rect,
			PhysicalProperties = roblox.PhysicalProperties,
			TweenInfo = { new = function(...) return { ... } end },
			RaycastParams = { new = function() return { FilterDescendantsInstances = {}, FilterType = nil } end },
			OverlapParams = { new = function() return { FilterDescendantsInstances = {}, FilterType = nil } end },
			Random = { new = function() return { NextNumber = function(_, a, b) return a + (b - a) * math.random() end, NextInteger = function(_, a, b) return math.random(a, b) end } end },
			task = task,
			typeof = function(v)
				local t = typeof(v)
				return t
			end,
			warn = function(...)
				local msg = table.concat({ tostring((...)) }, " ")
				print("CLIENT WARN: " .. msg)
				table.insert(ClientHarness.errors, "warn: " .. msg)
			end,
		}, { __index = _G })
		env.require = loadModule
		local fn = luau.load(inst.Source, { debugName = inst.Name, environment = env })
		modules[key] = fn()
		return modules[key]
	end
	client.require = loadModule
	local clientFolder = game:GetService("StarterPlayer").StarterPlayerScripts.Client
	client.folder = clientFolder

	-- runs init.client.luau (it requires and starts every controller)
	function client.boot()
		local env = setmetatable({}, { __index = function(_, k)
			if k == "script" then
				return clientFolder
			elseif k == "require" then
				return loadModule
			end
			return nil
		end })
		local src = clientFolder.Source
		local fn = luau.load(src, { debugName = "init.client", environment = setmetatable({
			script = clientFolder, require = loadModule, game = fakeGame, workspace = workspace, task = task,
			warn = function(...)
				print("CLIENT WARN: " .. tostring((...)))
				table.insert(ClientHarness.errors, "warn: " .. tostring((...)))
			end,
		}, { __index = _G }) })
		local _ = env
		fn()
	end

	-- one frame: the camera follows the head, then render steps, RenderStepped and Heartbeat, then attribute
	-- changes are delivered (Lune has no change events, so they're noticed here)
	function client.frame(dt: number?)
		local d = dt or 1 / 60
		client.flushQueued()
		-- (Lune keeps Position apart from CFrame: bring every part's Position up to date, as Roblox always has it)
		for _, p in workspace:GetDescendants() do
			if p:IsA("BasePart") then
				p.Position = p.CFrame.Position
			end
		end
		local head = player.Character and player.Character:FindFirstChild("Head")
		if head and not client.lookAt then
			cam.CFrame = roblox.CFrame.new(head.CFrame.Position)
		elseif head and client.lookAt then
			cam.CFrame = lookAt(head.CFrame.Position + roblox.Vector3.new(0, 1.5, 0), client.lookAt)
		end
		for _, r in table.clone(renderSteps) do
			local ok, err = pcall(r.f, d)
			if not ok then
				print("CLIENT ERROR (render step): " .. tostring(err))
				table.insert(ClientHarness.errors, tostring(err))
			end
		end
		RunService.RenderStepped:Fire(d)
		RunService.Heartbeat:Fire(d)
		for _, w in attrWatch do
			local now = w.inst:GetAttribute(w.name)
			if now ~= w.last then
				w.last = now
				ClientHarness.signal(w.inst, "attr:" .. w.name):Fire()
			end
		end
	end
	function client.frames(n: number, dt: number?)
		for _ = 1, n do
			client.frame(dt)
			task.wait()
		end
	end

	local function input(kind: string, key: any)
		local o = {
			KeyCode = if kind == "key" then key else roblox.Enum.KeyCode.Unknown,
			UserInputType = if kind == "key" then roblox.Enum.UserInputType.Keyboard else key,
			Position = roblox.Vector3.new(),
		}
		return o
	end
	function client.press(key)
		UIS.down[key] = true
		UIS.InputBegan:Fire(input("key", key), false)
		task.wait(0.02)
		UIS.down[key] = nil
		UIS.InputEnded:Fire(input("key", key), false)
	end
	function client.hold(key, on: boolean)
		UIS.down[key] = on or nil
		if on then
			UIS.InputBegan:Fire(input("key", key), false)
		else
			UIS.InputEnded:Fire(input("key", key), false)
		end
	end
	function client.click()
		UIS.InputBegan:Fire(input("mouse", roblox.Enum.UserInputType.MouseButton1), false)
		UIS.InputEnded:Fire(input("mouse", roblox.Enum.UserInputType.MouseButton1), false)
	end
	-- point the camera at a spot (the head stays where it is)
	function client.look(at)
		client.lookAt = at
	end
	-- what the HUD's hint line says right now
	function client.gui(name: string)
		return playerGui:FindFirstChild(name)
	end
	function client.find(root: any, pred: (any) -> boolean)
		for _, d in root:GetDescendants() do
			if pred(d) then
				return d
			end
		end
		return nil
	end
	return client
end

return ClientHarness
