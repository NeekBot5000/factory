-- Runs inside a real Roblox server (Open Cloud Luau Execution, started by tools/roblox_engine.py), against a saved
-- version of the place: Roblox's own physics, mesh loading and asset delivery, which the Lune playtests can't do.
-- No players can join a cloud session, so it drives the server services directly. It returns one JSON string:
-- every check with its numbers, and every warning or error the game printed.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")

local out = { checks = {}, info = {}, logs = {} }
local function check(name: string, ok: boolean, detail: any?)
	table.insert(out.checks, { name = name, ok = ok, detail = detail })
end
local function info(k: string, v: any)
	out.info[k] = v
end
local function try(name: string, f: () -> ())
	local ok, err = pcall(f)
	if not ok then
		check(name .. " (crashed)", false, tostring(err))
	end
end
local function r2(v: number): number
	return math.floor(v * 100 + 0.5) / 100
end

local t0 = os.clock()
-- 1. start the game's server, as its Script does (Roblox doesn't run a place's scripts in a Luau execution session)
local booted, bootErr = pcall(function()
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Boot") :: ModuleScript).start()
end)
local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
check("the game's server starts in a real Roblox server", booted and remotes ~= nil, { waited = r2(os.clock() - t0), err = if booted then nil else tostring(bootErr) })
if not remotes then
	return HttpService:JSONEncode(out)
end
local services = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
local function svc(name: string): any
	return require(services:WaitForChild(name) :: ModuleScript)
end
local Config = require(ReplicatedStorage.Shared.Config) :: any
local M = Config.StudsPerMetre

-- 2. the Godot meshes: loaded from the uploaded assets, as players would see them
try("meshes", function()
	local deadline = os.clock() + 60
	local meshParts = 0
	repeat
		task.wait(1)
		meshParts = 0
		for _, d in workspace:GetDescendants() do
			if d:IsA("MeshPart") then
				meshParts += 1
			end
		end
	until meshParts > 200 or os.clock() > deadline
	info("meshParts", meshParts)
	check("the Godot meshes load into the world (InsertService, the uploaded models)", meshParts > 200, { meshParts = meshParts, seconds = r2(os.clock() - t0) })
	local textured, chunks = 0, 0
	local sample = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and string.find(d.Name, "^ground") then
			chunks += 1
			if d.TextureID ~= "" then
				textured += 1
			end
			if #sample < 3 then
				table.insert(sample, { name = d.Name, size = { r2(d.Size.X), r2(d.Size.Y), r2(d.Size.Z) }, meshSize = { r2(d.MeshSize.X), r2(d.MeshSize.Y), r2(d.MeshSize.Z) },
					pos = { r2(d.Position.X), r2(d.Position.Y), r2(d.Position.Z) }, texture = d.TextureID, collision = tostring(d.CollisionFidelity), canCollide = d.CanCollide })
			end
		end
	end
	info("groundSample", sample)
	check("the ground chunks have Godot's baked ground textures", chunks > 0 and textured == chunks, { chunks = chunks, textured = textured })
	local props = ReplicatedStorage:FindFirstChild("Props")
	info("props", props and #props:GetChildren() or 0)
	check("the build and product meshes are ready (ReplicatedStorage.Props)", props ~= nil and #props:GetChildren() > 50, { props = props and #props:GetChildren() or 0 })
end)

local WorldService = svc("WorldService")
local BuildService = svc("BuildService")
local CircuitService = svc("CircuitService")
local function ground(x: number, z: number): number
	local params = RaycastParams.new()
	local skip = {}
	for _, n in { "Loose", "Logs", "Builds", "Plans", "Rails" } do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(skip, f)
		end
	end
	params.FilterDescendantsInstances = skip
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
	return if hit then hit.Position.Y else WorldService.heightAt(x, z)
end
local function loose(): Instance
	local f = workspace:FindFirstChild("Loose")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Loose"
		f.Parent = workspace
	end
	return f :: Instance
end
local function box(at: Vector3, size: number, kind: string?): Part
	local p = Instance.new("Part")
	p.Size = Vector3.one * size
	p.CFrame = CFrame.new(at)
	p:SetAttribute("Kind", kind or "product")
	p:SetAttribute("Product", "chair")
	p.Parent = loose()
	return p
end

-- 3. the ground is solid where Godot's is: a crate dropped from 10 m comes to rest on it
try("ground", function()
	local spots = { { 0, 30 }, { 40, -40 }, { -60, 15 }, { 90, 90 } }
	local res = {}
	local allOk = true
	for _, s in spots do
		local x, z = s[1], s[2]
		local g = ground(x, z)
		local godot = WorldService.heightAt(x, z)
		local p = box(Vector3.new(x, g + 10 * M, z), 1.5)
		task.wait(3)
		local rest = p.Position.Y - 0.75
		local ok = math.abs(rest - g) < 0.6 and p.AssemblyLinearVelocity.Magnitude < 1
		allOk = allOk and ok
		table.insert(res, { at = { x, z }, ground = r2(g), godotHeight = r2(godot), restsAt = r2(rest), speed = r2(p.AssemblyLinearVelocity.Magnitude) })
		p:Destroy()
	end
	check("things dropped on the ground land on it and stay (the world meshes collide)", allOk, res)
end)

-- 4. the chute: slippery, so a crate slides down it
try("chute", function()
	local at = Vector3.new(-30, ground(-30, 40), 40)
	local m = BuildService.make("chute", CFrame.new(at), 1, 1, true, {})
	svc("BuildBehaviors").activate(m)
	task.wait(0.5)
	local top = m:GetPivot():PointToWorldSpace(Vector3.new(0, 1.6 * M, 1.3 * M))
	local p = box(top + Vector3.new(0, 0.5 * M, 0), 0.9)
	local start = p.Position
	task.wait(3)
	local moved = (p.Position - start) * Vector3.new(1, 0, 1)
	check("a crate slides down the chute", moved.Magnitude > 1 * M, { slid = r2(moved.Magnitude / M), fromY = r2(start.Y), toY = r2(p.Position.Y) })
	p:Destroy()
	m:Destroy()
end)

-- 5. dynamite: the blast throws loose things
try("dynamite", function()
	local MS = svc("MiningService")
	local at = Vector3.new(30, ground(30, 60), 60)
	local p = box(at + Vector3.new(0.9 * M, 0.5 * M, 0), 0.6)
	task.wait(1)
	local before = p.Position
	local charge = MS.plant({ UserId = 1 } :: any, at, Vector3.yAxis)
	MS.explode(charge)
	task.wait(0.4)
	local flew = (p.Position - before).Magnitude / M
	check("dynamite throws what's close by", flew > 0.5, { metres = r2(flew), speed = r2(p.AssemblyLinearVelocity.Magnitude / M) })
	p:Destroy()
end)

-- 6. a minecart rolls along the track at Godot's 1.6 m/s, smoothly
try("cart", function()
	local RS = svc("RailService")
	local Rail = require(ReplicatedStorage.Shared.Rail) :: any
	local cx, cz = 20, 25
	for z = cz - 6, cz do
		RS.lay({ x = cx, z = z }, false, ground(cx * M, z * M) + 1, nil)
	end
	local front = { x = cx, z = cz }
	local cart = BuildService.make("minecart_1", CFrame.new(Rail.centre(front, Rail.top(Rail.at(front)))), 1, 1, true, {})
	local go = BuildService.make("cart_go", cart:GetPivot() * CFrame.new(0, RS.DECK_Y * M, 0), 1, 1, true, {})
	local crank = BuildService.make("crank", CFrame.new(Rail.centre(front, ground(cx * M, cz * M)) + Vector3.new(3 * M, 0, 0)), 1, 1, true, {})
	for _ = 1, 8 do
		CircuitService.use(crank)
	end
	CircuitService.toggle(crank, go)
	cart:SetAttribute("Cell", 1)
	local samples = {}
	local conn = RunService.Heartbeat:Connect(function()
		table.insert(samples, { t = os.clock(), z = cart:GetPivot().Position.Z, y = cart:GetPivot().Position.Y })
	end)
	task.wait(5)
	conn:Disconnect()
	local dist = math.abs(samples[#samples].z - samples[1].z) / M
	local maxJump, still = 0, 0
	for i = 2, #samples do
		local d = math.abs(samples[i].z - samples[i - 1].z) / M
		maxJump = math.max(maxJump, d)
		if d == 0 then
			still += 1
		end
	end
	check("a minecart rolls along the track", dist > 2, { metres = r2(dist), frames = #samples, maxStepPerFrame = r2(maxJump), framesStill = still,
		deckRides = r2((go:GetPivot().Position - cart:GetPivot().Position).Magnitude / M) })
	info("cartNote", "the server moves the cart 20 times a second; maxStepPerFrame over about 0.1 m shows as a stutter")
	for _, m in { cart, go, crank } do
		m:Destroy()
	end
end)

-- 7. a drone rises to cruise 3 m up
try("drone", function()
	local at = Vector3.new(-50, ground(-50, -30), -30)
	local d = BuildService.make("drone_small", CFrame.new(at), 1, 1, true, {})
	d:SetAttribute("Cell", 1)
	task.wait(4)
	local h = (d:GetPivot().Position.Y - at.Y) / M
	check("a drone with a charged cell rises to about 3 m", h > 2.5 and h < 3.5, { metres = r2(h) })
	d:Destroy()
end)

-- 8. the catapult throws its ball
try("catapult", function()
	local BB = svc("BuildBehaviors")
	local at = Vector3.new(60, ground(60, 20), 20)
	local m = BuildService.make("catapult", CFrame.new(at), 1, 1, true, {})
	BB.activate(m)
	task.wait(0.5)
	local cup = m:GetPivot():PointToWorldSpace(Vector3.new(0, 1.0 * M, 0.9 * M))
	local p = box(cup + Vector3.new(0, 0.4 * M, 0), 0.6)
	task.wait(1)
	local before = p.Position
	if BB.fire then
		BB.fire(m)
	end
	task.wait(1.2)
	check("the catapult throws what's in its cup", (p.Position - before).Magnitude > 2 * M, { metres = r2((p.Position - before).Magnitude / M), hasFire = BB.fire ~= nil })
	p:Destroy()
	m:Destroy()
end)

-- 9. everything the game printed: warnings and errors are bugs to fix
for _, l in LogService:GetLogHistory() do
	if l.messageType == Enum.MessageType.MessageWarning or l.messageType == Enum.MessageType.MessageError then
		table.insert(out.logs, string.sub(l.message, 1, 400))
	end
end
info("seconds", r2(os.clock() - t0))
return HttpService:JSONEncode(out)
