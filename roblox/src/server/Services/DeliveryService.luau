--!strict
-- TimberMart delivery, the Godot game's way (Main dispatch / Truck.deliver / DeliveryBox / ItemPickup):
-- buying puts an order in. A few seconds later the orange van comes over the crest, U-turns in the clearing and
-- backs onto the loading dock, beeping. It opens up and drops a cardboard box for every order on board, then drives
-- off. Click a box to open it: the tape rips, the flaps open, and the tool rises out of it, turning and glowing.
-- Look at it and press E to take it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local ToolService = require(script.Parent.ToolService)
local TutorialService = require(script.Parent.TutorialService)
local W = require(ReplicatedStorage.Shared.GodotWorld) :: any

local DeliveryService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local AWAY = CFrame.new(0, -400, 0)          -- where the van waits, out of the world, between deliveries
local BOX = Vector3.new(0.7, 0.5, 0.7) * M
local van: Model
local state = "away"
local REACH = Config.Player.grabReach * M + 6

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function route(list: { { number } }): { Vector3 }
	local out = {}
	for _, p in list do
		table.insert(out, v3(p))
	end
	return out
end

-- Drives the van along waypoints. Backwards (reverse) it faces the other way and beeps every half second.
local function drive(points: { Vector3 }, reverse: boolean?)
	local speed = (if reverse then 2.2 else Config.Truck.speed) * M
	local total, seg = 0, {}
	for k = 1, #points - 1 do
		local d = (points[k + 1] - points[k]).Magnitude
		table.insert(seg, d)
		total += d
	end
	local s, v, beep = 0, 0, 0
	local heading = van:GetPivot().LookVector
	while s < total do
		local dt = RunService.Heartbeat:Wait()
		local want = math.min(speed, math.max(3, (total - s) * 0.9))
		v += math.clamp(want - v, -dt * 12, dt * 12)
		s = math.min(total, s + v * dt)
		local k, left = 1, s
		while k < #seg and left > seg[k] do
			left -= seg[k]
			k += 1
		end
		local a, b = points[k], points[k + 1]
		local pos = a + (b - a) * math.clamp(left / math.max(seg[k], 0.001), 0, 1)
		local dir = (b - a) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 0.01 then
			local face = if reverse then -dir.Unit else dir.Unit
			heading = heading:Lerp(face, math.min(1, dt * 6))
		end
		if heading.Magnitude > 0.01 then
			van:PivotTo(CFrame.lookAt(pos, pos + heading.Unit))
		end
		if reverse then
			beep -= dt
			if beep <= 0 then
				beep = 0.5
				remotes.Fx:FireAllClients("click", van:GetPivot().Position + Vector3.new(0, 4, 0), 1.6, 2)
			end
		end
	end
end

-- a TimberMart cardboard box (0.7 x 0.5 x 0.7 m), taped across the top
local function makeBox(item: string, owner: number): Part
	local box = Instance.new("Part")
	box.Name = "Box_" .. item
	box.Size = BOX
	box.Color = Color3.fromHex("c79a62")
	box.Material = Enum.Material.SmoothPlastic
	box.TopSurface = Enum.SurfaceType.Smooth
	box.BottomSurface = Enum.SurfaceType.Smooth
	local tape = Instance.new("Part")
	tape.Name = "Tape"
	tape.Size = Vector3.new(0.1 * M, 0.025 * M, BOX.Z + 0.02 * M)
	tape.Color = Color3.fromHex("d9c48f")
	tape.Material = Enum.Material.SmoothPlastic
	tape.CanQuery = false
	tape.CanCollide = false
	tape.Massless = true
	tape.CFrame = box.CFrame * CFrame.new(0, BOX.Y / 2 + 0.004 * M, 0)
	local w = Instance.new("WeldConstraint")
	w.Part0 = box
	w.Part1 = tape
	w.Parent = tape
	tape.Parent = box
	box:SetAttribute("Kind", "box")
	box:SetAttribute("Item", item)
	box:SetAttribute("Owner", owner)
	return box
end

-- every order on the van comes out the back, one box each
local function unload()
	remotes.Fx:FireAllClients("drop", van:GetPivot().Position, 0.7)
	local loose = workspace:FindFirstChild("Loose") :: Instance
	local pivot = van:GetPivot()
	local k = 0
	for _, p in Players:GetPlayers() do
		local data = DataService.get(p)
		for _, o in (data and data.orders) or {} do
			if o.status == "shipping" then
				local box = makeBox(o.item, p.UserId)
				local rear = pivot * CFrame.new(Vector3.new(0, 1.4, 3.6) * M)
				box.CFrame = rear * CFrame.new(Vector3.new((k - 0.5) * 0.6, k * 0.1, 0) * M) * CFrame.Angles(0, math.random() * 6.28, 0)
				box.Parent = loose
				box.AssemblyLinearVelocity = pivot.LookVector * -2.2 * M + Vector3.new(0, M, 0)
				pcall(function()
					box:SetNetworkOwner(p)
				end)
				o.status = "boxed"          -- in its box on the dock now (it's yours once you take it out)
				DataService.publish(p)
				k += 1
			end
		end
	end
end

local function waiting(): boolean
	for _, p in Players:GetPlayers() do
		local data = DataService.get(p)
		for _, o in (data and data.orders) or {} do
			if o.status == "processing" then
				return true
			end
		end
	end
	return false
end

local function deliver()
	state = "arriving"
	for _, p in Players:GetPlayers() do
		local data = DataService.get(p)
		for _, o in (data and data.orders) or {} do
			if o.status == "processing" then
				o.status = "shipping"
			end
		end
	end
	local inn = route(W.van_inn)
	van:PivotTo(CFrame.lookAt(inn[1], inn[2]))
	van:SetAttribute("State", "arriving")
	drive(inn)
	van:SetAttribute("State", "docking")
	drive(route(W.van_dock), true)
	state = "unloading"
	van:SetAttribute("State", "unloading")
	unload()
	task.wait(2)
	state = "leaving"
	van:SetAttribute("State", "leaving")
	drive(route(W.van_out))
	van:PivotTo(AWAY)
	van:SetAttribute("State", "away")
	state = "away"
end

-- Click on a box: it opens and the tool rises out of it.
local function open(player: Player, box: unknown)
	if typeof(box) ~= "Instance" or not (box :: Instance):IsA("BasePart") then
		return
	end
	local b = box :: BasePart
	if b:GetAttribute("Kind") ~= "box" or b:GetAttribute("Owner") ~= player.UserId or b:GetAttribute("Opened") then
		return
	end
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not head or (head.Position - b.Position).Magnitude > REACH then
		return
	end
	b:SetAttribute("Opened", true)
	-- settle upright, the tape tears, the flaps open...
	local _, yaw, _ = b.CFrame:ToOrientation()
	b.Anchored = true
	b.CFrame = CFrame.new(b.Position) * CFrame.Angles(0, yaw, 0)
	remotes.Fx:FireAllClients("rip", b.Position)
	local tape = b:FindFirstChild("Tape")
	if tape then
		tape:Destroy()
	end
	task.wait(0.5)
	-- ...and up comes the tool, turning, with a warm glow
	local item = b:GetAttribute("Item") :: string
	local m = ToolService.build(item)
	if not m then
		-- (the phone has no tool model until the Godot meshes load: a plain one stands in)
		m = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name = "Handle"
		body.Size = Vector3.new(0.08, 0.15, 0.01) * M * 2.2
		body.Color = Color3.fromHex("2a2c31")
		body.Anchored = true
		body.CanCollide = false
		body.Parent = m
		;(m :: Model).PrimaryPart = body
	end
	if m then
		m.Name = "Pickup_" .. item
		local glowAt = Instance.new("Part")
		glowAt.Name = "Glow"
		glowAt.Size = Vector3.one * 0.7 * M
		glowAt.Transparency = 1
		glowAt.Anchored = true
		glowAt.CanCollide = false
		glowAt.CFrame = CFrame.new(b.Position)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromHex("ffe08a")
		light.Brightness = 0.8
		light.Range = 1.6 * M
		light.Parent = glowAt
		glowAt.Parent = m
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanQuery = true
			end
		end
		m:SetAttribute("Kind", "pickup")
		m:SetAttribute("Item", item)
		m:SetAttribute("Owner", player.UserId)
		m.Parent = workspace:FindFirstChild("Loose")
		local from = b.Position - Vector3.new(0, 0.1 * M, 0)
		local to = b.Position + Vector3.new(0, 0.75 * M, 0)
		remotes.Fx:FireAllClients("reveal", b.Position)
		task.spawn(function()
			local t = 0
			local function alive(): boolean
				local ok, inWorld = pcall(function()
					return m.Parent ~= nil and m:IsDescendantOf(workspace)
				end)
				return ok and inWorld
			end
			while alive() do
				local dt = RunService.Heartbeat:Wait()
				if not alive() then
					break     -- (taken while we waited)
				end
				t += dt
				local rise = math.min(1, t / 0.8)
				local k = 1 + 2.70158 * (rise - 1) ^ 3 + 1.70158 * (rise - 1) ^ 2      -- (Godot's back ease-out)
				local y = if rise < 1 then 0 else math.sin(t * 2) * 0.05 * M
				m:PivotTo(CFrame.new(from:Lerp(to, k) + Vector3.new(0, y, 0)) * CFrame.Angles(0, t * 1.4, 0))
			end
		end)
	end
	task.wait(0.6)
	b:Destroy()
end

-- E on the tool rising out of a box: it's yours, in your hand
function DeliveryService.take(player: Player, pickup: Model): boolean
	local item = pickup:GetAttribute("Item")
	if typeof(item) ~= "string" or pickup:GetAttribute("Owner") ~= player.UserId then
		return false
	end
	pickup:Destroy()
	local data = DataService.get(player)
	for _, o in (data and data.orders) or {} do
		if o.item == item and o.status ~= "delivered" then
			o.status = "delivered"
		end
	end
	ToolService.grant(player, item)
	local def = (Config.Tools :: any)[item]
	if item == "phone" then
		remotes.Notify:FireClient(player, "TimberPhone  [Tab]", "7aff9a")
	else
		remotes.Notify:FireClient(player, string.format("%s  [%d]", def and def.name or item, (table.find(Config.GodotToolOrder, item) or 0)), "7aff9a")
	end
	TutorialService.check(player)
	return true
end

-- the van: Godot's delivery van (its mesh comes from the Godot meshes; a plain box stands in until then)
local function makeVan()
	van = Instance.new("Model")
	van.Name = "Van"
	local function body(name: string, size: Vector3, at: Vector3, color: string)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * M
		p.CFrame = CFrame.new(at * M)
		p.Color = Color3.fromHex(color)
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p:SetAttribute("Standin", true)
		p.Parent = van
	end
	body("Cab", Vector3.new(2.1, 2.2, 2.9), Vector3.new(0, 1.4, -2.6), "e8792b")
	body("Back", Vector3.new(2.3, 2.3, 4.3), Vector3.new(0, 2.05, 0.95), "f2efe6")
	body("Chassis", Vector3.new(2.0, 0.6, 6.2), Vector3.new(0, 0.75, 0), "2a2c31")
	van.WorldPivot = CFrame.new()
	van:PivotTo(AWAY)
	van:SetAttribute("State", "away")
	van.Parent = workspace
end

function DeliveryService.start()
	makeVan()
	remotes.Open.OnServerEvent:Connect(open)
	-- the dispatcher: when orders are in and the van is free, it sets off a few seconds later
	task.spawn(function()
		while true do
			task.wait(0.5)
			if state == "away" and waiting() then
				task.wait(3)
				if state == "away" then
					deliver()
				end
			end
		end
	end)
	-- your boxes and unopened tools go with you when you leave (the order comes again next time)
	Players.PlayerRemoving:Connect(function(p)
		local loose = workspace:FindFirstChild("Loose")
		for _, c in if loose then loose:GetChildren() else {} do
			local kind = c:GetAttribute("Kind")
			if (kind == "box" or kind == "pickup") and c:GetAttribute("Owner") == p.UserId then
				c:Destroy()
			end
		end
	end)
	-- an order still on the way when you left comes again
	Players.PlayerAdded:Connect(function(p)
		for _ = 1, 60 do
			local data = DataService.get(p)
			if data then
				for _, o in data.orders or {} do
					if o.status == "shipping" or o.status == "boxed" then
						o.status = "processing"
					end
				end
				return
			end
			task.wait(0.5)
		end
	end)
end

return DeliveryService
