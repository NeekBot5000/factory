--!strict
-- What finished builds do, the Godot game's way:
--   campfire  (Campfire.gd) a crackling fire with a warm light; anything dropped on it burns away (a log takes 7 s, a
--             sheet of bark 1.8, leaves 0.9, anything else 3) and its value goes up in smoke
--   compost   (Compost.gd) drop leaves in and it rots them down: every 8 leaves, 8 s later, a sapling pops out
--   catapult  (Catapult.gd) a click whips the arm over and launches whatever's in the cup, forwards
--   hoop/ball (Hoop.gd, Basketball.gd) a bouncy ball wound from leaves; drop it through the rim: "Swish!"
--   hammock   (Hammock.gd) E to lie in it
--   basket, wheelbarrow: you can pick them up and carry them, with whatever's in them
-- BuildService calls activate() on each finished build.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Physics = require(script.Parent.Physics)
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local Builds = require(ReplicatedStorage.Shared.Builds)
local LogService = require(script.Parent.LogService)

local BuildBehaviors = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local BURN = { log = 7.0, bark = 1.8, leaf = 0.9, other = 3.0 }
local LEAVES_PER_SAPLING, ROT_TIME = 8, 8.0
local LAUNCH = Vector3.new(0, 7.5, -11.0)          -- the catapult's launch velocity, in its own frame (m/s)
local HOOP_HEIGHT = 3.05                           -- the rim's height (Godot's HOOP_DEFAULT), metres

local function looseIn(cf: CFrame, size: Vector3): { BasePart }
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
	local out, seen = {}, {}
	for _, p in workspace:GetPartBoundsInBox(cf, size, params) do
		local item: BasePart = p
		if p.Parent and p.Parent:IsA("BasePart") then
			item = p.Parent :: BasePart
		end
		if not seen[item] and not item.Anchored and not item:GetAttribute("HeldBy") then
			seen[item] = true
			table.insert(out, item)
		end
	end
	return out
end

local function wholeOf(item: BasePart): Instance
	if item.Name == "Trunk" and item.Parent and item.Parent:GetAttribute("Kind") == "log" then
		return item.Parent
	end
	return item
end

-- ------------------------------------------------------------------ the campfire
local burning: { [Instance]: { left: number, total: number } } = {}

local function lightUp(m: Model, size: number)
	local base = m:GetPivot()
	local flames = Instance.new("Folder")
	flames.Name = "Flames"
	flames.Parent = m
	for k = 0, 5 do
		local a = 2 * math.pi * k / 5
		local f = Instance.new("Part")
		f.Name = if k == 5 then "Core" else "Flame"
		f.Material = Enum.Material.Neon
		f.Color = Color3.fromHex(if k == 5 then "ffd36a" else "ff8a2b")
		f.Size = Vector3.new(0.12, 0.42, 0.12) * M * size
		local off = if k == 5 then Vector3.new(0, 0.3, 0) else Vector3.new(math.cos(a) * 0.1, 0.35, math.sin(a) * 0.1)
		f.CFrame = base * CFrame.new(off * M * size) * CFrame.Angles(0, a, math.rad(8))
		f.Anchored = true
		f.CanCollide = false
		f.CanQuery = false
		f.CastShadow = false
		f.Parent = flames
	end
	local holder = Instance.new("Part")
	holder.Name = "FireLight"
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Size = Vector3.one * 0.2
	holder.CFrame = base * CFrame.new(0, 0.6 * M * size, 0)
	holder.Parent = m
	local l = Instance.new("PointLight")
	l.Color = Color3.fromHex("ffa04a")
	l.Brightness = 1.6
	l.Range = math.min(5 * M * size, 60)
	l.Parent = holder
end

local function campfireStep(m: Model, dt: number)
	local size = m:GetAttribute("Size") :: number? or 1
	local c = m:GetPivot() * CFrame.new(0, 0.45 * M * size, 0)
	for _, item in looseIn(c, Vector3.new(0.9, 0.7, 0.9) * M * size) do
		local whole = wholeOf(item)
		if not burning[whole] then
			local res = Builds.resourceOf(item)
			local t = if res == "log" then BURN.log elseif res == "bark" then BURN.bark elseif res == "leaf" then BURN.leaf else BURN.other
			if item:GetAttribute("Kind") ~= "tool" then
				burning[whole] = { left = t, total = t }
				whole:SetAttribute("Burning", true)
			end
		end
	end
	for whole, st in burning do
		if whole.Parent == nil then
			burning[whole] = nil
			continue
		end
		local root = if whole:IsA("BasePart") then whole else (whole:FindFirstChild("Trunk") :: BasePart?)
		if not root or (root.Position - c.Position).Magnitude > 1.2 * M * size + root.Size.Magnitude * 0.5 then
			burning[whole] = nil          -- pulled out of the fire in time
			whole:SetAttribute("Burning", nil)
			continue
		end
		st.left -= dt
		if st.left <= 0 then
			remotes.Fx:FireAllClients("rustle", root.Position, 0.5, -6)
			whole:Destroy()
			burning[whole] = nil
		end
	end
end

-- ------------------------------------------------------------------ the compost pile
local function compostStep(m: Model, dt: number)
	local size = m:GetAttribute("Size") :: number? or 1
	local c = m:GetPivot() * CFrame.new(0, 0.5 * M * size, 0)
	local stock = m:GetAttribute("Stock") :: number? or 0
	for _, item in looseIn(c, Vector3.new(1.3, 0.9, 1.3) * M * size) do
		if item:GetAttribute("Kind") == "leaf" then
			stock += 1
			remotes.Fx:FireAllClients("rustle", item.Position, 0.7, -8)
			item:Destroy()
		end
	end
	if stock >= LEAVES_PER_SAPLING then
		local rot = (m:GetAttribute("Rot") :: number? or 0) + dt
		if rot >= ROT_TIME then
			rot = 0
			stock -= LEAVES_PER_SAPLING
			local kinds = { "oak", "birch", "pine" }
			local s = LogService.sapling((m:GetPivot() * CFrame.new(0, 1.0 * M * size, 0)).Position, kinds[math.random(1, 3)])
			Physics.take(s :: any)
			s.AssemblyLinearVelocity = Vector3.new(math.random() * 2.4 - 1.2, 3.0, math.random() * 2.4 - 1.2) * M
			remotes.Fx:FireAllClients("reveal", m:GetPivot().Position, 1.2, -4)
		end
		m:SetAttribute("Rot", rot)
	end
	m:SetAttribute("Stock", stock)
	-- the mound rises a little with what's in it
	local k = 1.0 + math.min(stock, 24) * 0.02
	m:SetAttribute("Mound", k)
end

-- ------------------------------------------------------------------ the catapult
function BuildBehaviors.fire(m: Model)
	if m:GetAttribute("Busy") then
		return
	end
	local size = m:GetAttribute("Size") :: number? or 1
	local def = Builds.def("catapult") :: any
	local pivot = def.groups and def.groups.Arm
	if not pivot then
		return
	end
	m:SetAttribute("Busy", true)
	-- the cup: at the end of the arm
	local cup = m:GetPivot() * CFrame.new(Vector3.new(pivot[1], pivot[2], pivot[3]) * size + Vector3.new(0, 0.2, 1.1) * M * size)
	local load = looseIn(cup, Vector3.new(0.6, 0.5, 0.6) * M * size)
	remotes.Fx:FireAllClients("whoosh", cup.Position, 0.6, 2)
	-- the arm whips over (Godot: -105 degrees in 0.16 s), then comes back down (1.1 s)
	local arm = {}
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Group") == "Arm" then
			table.insert(arm, p)
		end
	end
	local axle = m:GetPivot() * CFrame.new(pivot[1] * size, pivot[2] * size, pivot[3] * size)
	local rel = {}
	for _, p in arm do
		rel[p] = axle:ToObjectSpace(p.CFrame)
	end
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a)
		for _, p in arm do
			p.CFrame = axle * CFrame.Angles(math.rad(a), 0, 0) * rel[p]
		end
	end)
	local up = TweenService:Create(v, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = -105 })
	up:Play()
	task.delay(0.16, function()
		local vel = m:GetPivot():VectorToWorldSpace(LAUNCH) * math.sqrt(size) * M
		for _, item in load do
			if item.Parent and not item:GetAttribute("HeldBy") then
				Physics.take(item :: any)
				item.AssemblyLinearVelocity = vel + Vector3.new(math.random() * 1.2 - 0.6, math.random() - 0.5, math.random() * 1.2 - 0.6) * M
				item.AssemblyAngularVelocity = Vector3.new(math.random() * 12 - 6, math.random() * 12 - 6, math.random() * 12 - 6)
			end
		end
		remotes.Fx:FireAllClients("thud", cup.Position, 0.8, 2)
		task.wait(0.4)
		local down = TweenService:Create(v, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Value = 0 })
		down:Play()
		task.wait(1.1)
		v:Destroy()
		m:SetAttribute("Busy", nil)
	end)
end

-- ------------------------------------------------------------------ the hoop and the ball
local function hoopStep(m: Model)
	local size = m:GetAttribute("Size") :: number? or 1
	-- the rim: Godot's (0, height, 0.1) in the hoop's frame (its height stays 3.05 m whatever the size)
	local rim = m:GetPivot() * CFrame.new(0, HOOP_HEIGHT * M - 0.12 * M * size, 0.1 * M * size)
	for _, item in looseIn(rim, Vector3.new(0.32, 0.12, 0.32) * M * size) do
		if item:GetAttribute("Kind") == "ball" and item.AssemblyLinearVelocity.Y < 0 then
			local now = os.clock()
			local last = m:GetAttribute("LastScore") :: number? or -100
			if now - last < 0.6 then
				continue
			end
			local streak = if now - last < 12 then (m:GetAttribute("Streak") :: number? or 0) + 1 else 1
			m:SetAttribute("LastScore", now)
			m:SetAttribute("Streak", streak)
			remotes.Fx:FireAllClients("reveal", rim.Position, 1.0 + math.min(streak, 6) * 0.08)
			task.delay(0.12, function()
				remotes.Fx:FireAllClients("buy", rim.Position, 1.2, -4)
			end)
			remotes.Notify:FireAllClients(if streak < 2 then "Swish!" else string.format("Swish!  x%d", streak), "ffcf6a")
		end
	end
end

-- a finished ball: a bouncy leaf ball you can pick up and throw (in Loose, so it's carried like a sheet)
local function makeBall(m: Model, size: number)
	local col = Color3.fromHex("6aa846")
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Res") == "leaf" then
			col = p.Color
			break
		end
	end
	local at = m:GetPivot().Position + Vector3.new(0, (0.12 * size + 0.02) * M, 0)
	local value, owner = m:GetAttribute("SaleValue"), m:GetAttribute("Owner")
	m:Destroy()
	local b = Instance.new("Part")
	b.Name = "Basketball"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.one * 0.24 * M * size
	b.Color = col
	b.Material = Enum.Material.SmoothPlastic
	b.CFrame = CFrame.new(at)
	b.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.6, 0.75, 1, 1)
	b:SetAttribute("Kind", "ball")
	b:SetAttribute("Value", value)          -- (the truck sells builds for what they'd sell for)
	b:SetAttribute("Owner", owner)
	local loose = workspace:FindFirstChild("Loose") or Instance.new("Folder")
	loose.Name = "Loose"
	loose.Parent = workspace
	b.Parent = loose
end

-- a basket or a wheelbarrow: one welded body you can carry (its first part is what you grab), in Loose
local function makeCarryable(m: Model)
	local root: BasePart? = nil
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			if not root then
				root = p
			else
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	if not root then
		return
	end
	local r = root :: BasePart
	r:SetAttribute("Kind", "basket")
	r:SetAttribute("Build", m:GetAttribute("Build"))
	r:SetAttribute("Owner", m:GetAttribute("Owner"))
	r:SetAttribute("SaleValue", m:GetAttribute("SaleValue"))
	r:SetAttribute("Value", m:GetAttribute("SaleValue"))
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			if p ~= r then
				p.Parent = r
			end
		end
	end
	local loose = workspace:FindFirstChild("Loose") or Instance.new("Folder")
	loose.Name = "Loose"
	loose.Parent = workspace
	r.Parent = loose
	m:Destroy()
end

function BuildBehaviors.activate(m: Model)
	local id = m:GetAttribute("Build")
	local size = m:GetAttribute("Size") :: number? or 1
	if id == "campfire" then
		lightUp(m, size)
	elseif id == "ball" then
		makeBall(m, size)
	elseif id == "basket" or id == "wheelbarrow" then
		makeCarryable(m)
	elseif id == "chute" then
		-- (Godot's chute: a slippery board, friction 0.04, so things slide down it)
		pcall(function()
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					p.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.04, 0.5, 100, 1)
				end
			end
		end)
	end
end

function BuildBehaviors.start()
	remotes.Click.OnServerEvent:Connect(function(player, target)
		if typeof(target) ~= "Instance" then
			return
		end
		local m = (target :: Instance):FindFirstAncestorWhichIsA("Model")
		while m and m:GetAttribute("Kind") ~= "build" do
			m = m:FindFirstAncestorWhichIsA("Model")
		end
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		if m and head and m:GetAttribute("Build") == "catapult" and (m:GetPivot().Position - head.Position).Magnitude < 8 * M then
			BuildBehaviors.fire(m)
		end
	end)
	remotes.Lie.OnServerEvent:Connect(function(player, target)
		-- the hammock: lie in it (Godot sways you in it; here you settle into its seat)
		if typeof(target) ~= "Instance" then
			return
		end
		local m = (target :: Instance):FindFirstAncestorWhichIsA("Model")
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if m and hum and m:GetAttribute("Build") == "hammock" then
			local seat = m:FindFirstChild("Bed") :: Seat?
			if not seat then
				local size = m:GetAttribute("Size") :: number? or 1
				local s = Instance.new("Seat")
				s.Name = "Bed"
				s.Transparency = 1
				s.Size = Vector3.new(0.6, 0.1, 1.6) * M * size
				Physics.take(s :: any)
				s.CFrame = m:GetPivot() * CFrame.new(0, 0.55 * M * size, 0) * CFrame.Angles(0, math.rad(90), 0)
				s.Anchored = true
				s.CanCollide = false
				s.Parent = m
				seat = s
			end
			if (seat :: Seat).Occupant == hum then
				hum.Sit = false
			else
				(seat :: Seat):Sit(hum)
			end
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = now - last
			last = now
			local f = workspace:FindFirstChild("Builds")
			for _, m in if f then f:GetChildren() else {} do
				local id = m:GetAttribute("Build")
				local ok, err = pcall(function()
					if id == "campfire" then
						campfireStep(m :: Model, dt)
					elseif id == "compost" then
						compostStep(m :: Model, dt)
					elseif id == "hoop" then
						hoopStep(m :: Model)
					end
				end)
				if not ok then
					warn("[Timber] " .. tostring(id) .. ": " .. tostring(err))
				end
			end
		end
	end)
	local _ = Players
end

return BuildBehaviors
