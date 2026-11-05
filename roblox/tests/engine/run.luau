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
	-- (the textures and the props come after the world meshes: wait for them too)
	local props = ReplicatedStorage:FindFirstChild("Props")
	local until_ = os.clock() + 60
	while os.clock() < until_ and not (props and #props:GetChildren() > 50) do
		task.wait(1)
		props = ReplicatedStorage:FindFirstChild("Props")
	end
	info("props", props and #props:GetChildren() or 0)
	check("the build and product meshes are ready (ReplicatedStorage.Props)", props ~= nil and #props:GetChildren() > 50, { props = props and #props:GetChildren() or 0, seconds = r2(os.clock() - t0) })
	local textured2, chunks2 = 0, 0
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and string.find(d.Name, "^ground") then
			chunks2 += 1
			if d.TextureID ~= "" then
				textured2 += 1
			end
		end
	end
	check("the ground chunks have Godot's baked ground textures (after loading)", chunks2 > 0 and textured2 == chunks2, { chunks = chunks2, textured = textured2 })
	-- the world meshes stand where Godot has them (Roblox's import turns them round; WorldMeshes turns them back)
	local where = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and (string.find(d.Name, "^cabin_c707060") or string.find(d.Name, "^ground_1_1")) then
			where[d.Name] = { r2(d.Position.X), r2(d.Position.Z) }
		end
	end
	local chim, g11 = where["cabin_c707060"], where["ground_1_1_cffffff"]
	check("the world meshes stand where Godot has them (the chimney, the far ground chunk)",
		chim ~= nil and math.abs(chim[1] + 10.35) < 0.2 and math.abs(chim[2] + 2.4) < 0.2 and g11 ~= nil and g11[1] < 0 and g11[2] < 0, where)
end)

-- is Roblox simulating physics in this session? (a cloud session may not; then the physics checks can't say much)
info("physicsRunningAtStart", RunService:IsRunning())
if not RunService:IsRunning() then
	local okRun, errRun = pcall(function()
		(RunService :: any):Run()
	end)
	info("startedPhysics", { ok = okRun, err = if okRun then nil else tostring(errRun), running = RunService:IsRunning() })
end
local physics = RunService:IsRunning()
local function physCheck(name: string, ok: boolean, detail: any?)
	if physics then
		check(name, ok, detail)
	else
		check(name .. " - not tested: Roblox runs no physics in a cloud session", true, detail)
	end
end

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

-- 2b. the ground you walk on (Roblox terrain) stays under the ground you see (Godot's mesh): where it pokes up
-- through it, Roblox's own grass shows instead of Godot's; where it's far below, you sink into the ground
try("terrain", function()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local above, below, n, worstUp, worstDown, worstAt = 0, 0, 0, 0, 0, nil
	local W = require(ReplicatedStorage.Shared.GodotWorld) :: any
	local half = (W.ground.n - 1) * W.ground.step * 0.5 * 0.8
	for ix = -20, 20 do
		for iz = -20, 20 do
			local x, z = ix / 20 * half, iz / 20 * half
			local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
			if hit then
				n += 1
				local d = hit.Position.Y - WorldService.heightAt(x, z)
				if d > 0.05 then
					above += 1
				elseif d < -1.2 then
					below += 1
				end
				if d > worstUp then
					worstUp, worstAt = d, { r2(x), r2(z) }
				end
				worstDown = math.min(worstDown, d)
			end
		end
	end
	check("Roblox's terrain stays just under Godot's ground mesh (none pokes through)", n > 1000 and above == 0,
		{ samples = n, pokesThrough = above, deepUnder = below, worstUpStuds = r2(worstUp), worstAt = worstAt, worstDownStuds = r2(worstDown) })
end)

-- 2c. how Roblox turns voxel occupancy into a surface: flat test columns outside the map, one full voxel layer
-- and a top voxel of known occupancy (so WorldService can aim the terrain exactly under Godot's mesh)
try("terrain calibration", function()
	local res = 4
	local occs = { 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1 }
	local x0, y0, z0 = 2000, 0, 2000
	local out2 = {}
	for k, o in occs do
		-- a 3x3 patch of columns, 2 voxels high (full below, o on top), so the middle column isn't rounded off
		local mats, occ = {}, {}
		for ix = 1, 3 do
			mats[ix], occ[ix] = {}, {}
			for iy = 1, 3 do
				mats[ix][iy], occ[ix][iy] = {}, {}
				for iz = 1, 3 do
					local v = if iy == 1 then 1 elseif iy == 2 then o else 0
					mats[ix][iy][iz] = if v > 0 then Enum.Material.Grass else Enum.Material.Air
					occ[ix][iy][iz] = v
				end
			end
		end
		local bx = x0 + k * 40
		workspace.Terrain:WriteVoxels(Region3.new(Vector3.new(bx, y0, z0), Vector3.new(bx + 3 * res, y0 + 3 * res, z0 + 3 * res)), res, mats, occ)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		local hit = workspace:Raycast(Vector3.new(bx + 1.5 * res, 50, z0 + 1.5 * res), Vector3.new(0, -100, 0), params)
		table.insert(out2, { occ = o, surfaceAboveFullLayer = if hit then r2(hit.Position.Y - (y0 + res)) else "none" })
	end
	info("terrainCalibration", out2)
end)

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
	physCheck("things dropped on the ground land on it and stay (the world meshes collide)", allOk, res)
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
	physCheck("a crate slides down the chute", moved.Magnitude > 1 * M, { slid = r2(moved.Magnitude / M), fromY = r2(start.Y), toY = r2(p.Position.Y) })
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
	physCheck("dynamite throws what's close by", flew > 0.5, { metres = r2(flew), speed = r2(p.AssemblyLinearVelocity.Magnitude / M) })
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
	physCheck("the catapult throws what's in its cup", (p.Position - before).Magnitude > 2 * M, { metres = r2((p.Position - before).Magnitude / M), hasFire = BB.fire ~= nil })
	p:Destroy()
	m:Destroy()
end)

-- 8b. the server keeps up: frames over 3 s with everything running (carts, drones, trees, machines, the circuit)
try("performance", function()
	local times = {}
	local conn = RunService.Heartbeat:Connect(function(dt)
		table.insert(times, dt)
	end)
	task.wait(3)
	conn:Disconnect()
	local worst, total = 0, 0
	for _, dt in times do
		worst = math.max(worst, dt)
		total += dt
	end
	local fps = #times / math.max(total, 0.001)
	local mem = 0
	pcall(function()
		mem = game:GetService("Stats"):GetTotalMemoryUsageMb()
	end)
	check("the server keeps up (about 60 frames a second, no long stalls)", fps > 50 and worst < 0.1,
		{ fps = r2(fps), worstFrameMs = r2(worst * 1000), instances = #game:GetDescendants(), memoryMb = r2(mem) })
end)

-- 9. everything the game printed: warnings and errors are bugs to fix
for _, l in LogService:GetLogHistory() do
	if l.messageType == Enum.MessageType.MessageWarning or l.messageType == Enum.MessageType.MessageError then
		table.insert(out.logs, string.sub(l.message, 1, 400))
	end
end
info("seconds", r2(os.clock() - t0))
return HttpService:JSONEncode(out)
