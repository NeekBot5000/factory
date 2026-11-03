-- A pretend Roblox server for playtests in Lune (no Studio needed). It loads the place Rojo built, runs the real
-- server scripts against Lune's Roblox objects (which know every real class and property), and supplies only what
-- Lune doesn't have: remote events, the Players list, a DataStore, ProximityPrompts and spatial queries.
-- Small source rewrites stand in for engine methods Lune lacks (GetPivot, GetPartBoundsInBox, Kick).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Harness = {}

-- one DataStore shared by every pretend server (so a rejoin on another server finds the save)
local stores: { [string]: { [string]: any } } = {}

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepCopy(v)
	end
	return c
end

local function signal()
	local s = { handlers = {} }
	function s:Connect(f)
		table.insert(self.handlers, f)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, f in self.handlers do
			task.spawn(function(...)
				local ok, err = xpcall(f, function(e) return tostring(e) .. "\n" .. debug.traceback() end, ...)
				if not ok then
					print("ERROR in handler: " .. tostring(err))
				end
			end, ...)
		end
	end
	-- (frame-by-frame loops run in big steps here, so a 20-second truck trip takes a few seconds of test time)
	function s:Wait()
		task.wait(0.02)
		return 0.5
	end
	return s
end

-- Boots one server. Returns a table with the place, fake services, remote logs and helpers.
function Harness.boot(placePath: string, jobId: string)
	local game = roblox.deserializePlace(fs.readFile(placePath))
	local workspace = game:GetService("Workspace")
	local RS = game:GetService("ReplicatedStorage")
	local server = { game = game, workspace = workspace, jobId = jobId, clientLog = {}, kicked = {} }

	-- remotes: OnServerEvent handlers we can call as a client would, and a log of what the server sent to clients
	local remotes = {}
	for _, name in { "StripRequest", "TreeChanged", "Buy", "Fx", "Notify", "Tutorial", "Sold", "Grab", "Equip", "DropTool", "Use" } do
		local ev = { name = name, OnServerEvent = signal() }
		function ev:FireClient(player, ...)
			table.insert(server.clientLog, { remote = name, player = player, args = { ... } })
			if server.toClient then
				server.toClient(name, player, ...)
			end
		end
		function ev:FireAllClients(...)
			table.insert(server.clientLog, { remote = name, all = true, args = { ... } })
			if server.toClient then
				server.toClient(name, nil, ...)
			end
		end
		remotes[name] = ev
	end
	server.remotes = remotes

	local players = {}
	local Players = { PlayerAdded = signal(), PlayerRemoving = signal() }
	function Players:GetPlayers()
		return table.clone(players)
	end
	function Players:GetPlayerByUserId(id)
		for _, p in players do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end
	server.Players = Players

	local DataStoreService = {}
	function DataStoreService:GetDataStore(name)
		stores[name] = stores[name] or {}
		local data = stores[name]
		return {
			UpdateAsync = function(_, key, transform)
				local out = transform(deepCopy(data[key]))
				if out == nil then
					return nil
				end
				data[key] = deepCopy(out)
				return deepCopy(out)
			end,
			GetAsync = function(_, key)
				return deepCopy(data[key])
			end,
		}
	end
	server.stores = stores

	local ProximityPromptService = { PromptTriggered = signal() }
	server.ProximityPromptService = ProximityPromptService
	local RunService = { Heartbeat = signal() }
	function RunService:IsStudio()
		return false
	end
	local CollectionService = {}
	function CollectionService:AddTag(inst, tag)
		inst:AddTag(tag)
	end
	function CollectionService:HasTag(inst, tag)
		return typeof(inst) == "Instance" and inst:HasTag(tag)
	end
	function CollectionService:GetTagged(tag)
		local out = {}
		for _, d in workspace:GetDescendants() do
			if d:HasTag(tag) then
				table.insert(out, d)
			end
		end
		return out
	end

	local fakeGame = setmetatable({}, {
		__index = function(_, k)
			if k == "GetService" then
				return function(_, name)
					if name == "Players" then return Players end
					if name == "DataStoreService" then return DataStoreService end
					if name == "ProximityPromptService" then return ProximityPromptService end
					if name == "RunService" then return RunService end
					if name == "CollectionService" then return CollectionService end
					return game:GetService(name)
				end
			end
			if k == "JobId" then return jobId end
			if k == "BindToClose" then return function() end end
			local v = game[k]
			if type(v) == "function" then
				return function(_, ...)
					return v(game, ...)
				end
			end
			return v
		end,
	})

	-- spatial query: every part whose centre is inside the box (good enough for the truck bed)
	local function bounds(cf, size, params)
		local out = {}
		local roots = params and params.FilterDescendantsInstances or { workspace }
		for _, root in roots do
			for _, p in root:GetDescendants() do
				if p:IsA("BasePart") then
					local lp = cf:PointToObjectSpace(p.CFrame.Position)
					if math.abs(lp.X) <= size.X / 2 and math.abs(lp.Y) <= size.Y / 2 and math.abs(lp.Z) <= size.Z / 2 then
						table.insert(out, p)
					end
				end
			end
		end
		return out
	end

	local modules = {}
	local env
	local function loadModule(inst)
		-- (Lune hands out a new wrapper for the same instance each time, so key the cache by its path)
		local key = inst:GetFullName()
		if modules[key] ~= nil then
			return modules[key]
		end
		local src = inst.Source
		src = string.gsub(src, ":GetPivot%(%)", ".WorldPivot")
		src = string.gsub(src, "workspace:GetPartBoundsInBox%(", "__bounds(")
		src = string.gsub(src, "player:Kick%(", "__kick(player, ")
		src = string.gsub(src, "(%w+):TakeDamage%(", "__damage(%1, ")
		src = string.gsub(src, "([%w_%.]+):PivotTo%(", "__pivotTo(%1, ")
		src = string.gsub(src, "player%.CharacterAdded:Connect%(", "__noop(")
		src = string.gsub(src, "handle%.AssemblyLinearVelocity = ", "local _ = ")
		-- Lune keeps Position and CFrame apart (setting one doesn't move the other), so read parts' CFrame
		for _, name in { "p", "head", "bed" } do
			src = string.gsub(src, "%f[%w]" .. name .. "%.Position", name .. ".CFrame.Position")
		end
		src = string.gsub(src, "ReplicatedStorage:WaitForChild%(\"Remotes\"%)", "__REMOTES")
		local fn = luau.load(src, { debugName = inst.Name, environment = env })
		modules[key] = fn()
		return modules[key]
	end
	local servicesFolder = game:GetService("ServerScriptService").Server.Services
	env = setmetatable({
		game = fakeGame,
		workspace = workspace,
		script = { Parent = servicesFolder },
		require = loadModule,
		Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
		Enum = roblox.Enum, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2, NumberRange = roblox.NumberRange,
		OverlapParams = { new = function() return { FilterDescendantsInstances = {}, FilterType = nil } end },
		RaycastParams = { new = function() return {} end },
		Random = {
			new = function(seed)
				local s = seed
				local function nxt()
					s = (s * 1103515245 + 12345) % 2147483648
					return s / 2147483648
				end
				return {
					NextNumber = function(_, a, b) return a + (b - a) * nxt() end,
					NextInteger = function(_, a, b) return a + math.floor((b - a + 1) * nxt()) end,
				}
			end,
		},
		task = task,
		debug = { profilebegin = function() end, profileend = function() end },
		__REMOTES = remotes,
		__bounds = bounds,
		-- Model:PivotTo: move every part by the same offset as the pivot
		__pivotTo = function(inst, target)
			if inst:IsA("BasePart") then
				inst.CFrame = target
				return
			end
			local delta = target * inst.WorldPivot:Inverse()
			for _, d in inst:GetDescendants() do
				if d:IsA("BasePart") then
					d.CFrame = delta * d.CFrame
				end
			end
			inst.WorldPivot = target
		end,
		__noop = function() end,
		__damage = function(hum, amount)
			hum.Health = math.max(0, hum.Health - amount)
			server.damage = (server.damage or 0) + amount
		end,
		__kick = function(p, reason)
			table.insert(server.kicked, { player = p, reason = reason })
		end,
		warn = function() end,
	}, { __index = _G })

	function server.service(name: string)
		return loadModule(servicesFolder[name])
	end

	-- starts the services in the same order as init.server.luau
	function server.start()
		local src = game:GetService("ServerScriptService").Server.Source
		local order = string.match(src, "local order = (%b{})")
		for name in string.gmatch(order, "\"(%w+)\"") do
			server.service(name).start()
		end
	end

	-- a player joins: a real Player with a Backpack, StarterGear and a character standing at `at`
	function server.join(userId: number, name: string, at)
		local p = roblox.Instance.new("Player")
		p.Name = name
		p.UserId = userId
		roblox.Instance.new("Backpack").Parent = p
		local gear = roblox.Instance.new("StarterGear")
		gear.Parent = p
		local char = roblox.Instance.new("Model")
		char.Name = name
		local head = roblox.Instance.new("Part")
		head.Name = "Head"
		head.CFrame = roblox.CFrame.new(at or roblox.Vector3.new(0, 5, 14))
		head.Parent = char
		local root = roblox.Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = head.CFrame * roblox.CFrame.new(0, -1.5, 0)
		root.Parent = char
		local hum = roblox.Instance.new("Humanoid")
		hum.MaxHealth = 100
		hum.Health = 100
		hum.Parent = char
		char.Parent = workspace
		p.Character = char
		p.Parent = game:GetService("Players")
		table.insert(players, p)
		Players.PlayerAdded:Fire(p)
		return p
	end

	function server.leave(p)
		table.remove(players, table.find(players, p))
		Players.PlayerRemoving:Fire(p)
	end

	-- move a player's head (their reach is measured from it)
	function server.stand(p, at)
		p.Character.Head.CFrame = roblox.CFrame.new(at)
	end

	-- what the server last sent this player on a remote
	function server.last(p, remote)
		for i = #server.clientLog, 1, -1 do
			local e = server.clientLog[i]
			if e.remote == remote and (e.player == p or e.all) then
				return table.unpack(e.args)
			end
		end
		return nil
	end

	return server
end

return Harness
