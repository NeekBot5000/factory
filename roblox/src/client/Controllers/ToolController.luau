--!strict
-- Swinging and the tool bar, the Godot way (Player.gd).
--   * The tool bar is every tool you own that you haven't put down. 1-9 (Shift for the next nine) or the mouse wheel
--     pick one; Q puts the one in your hand down on the ground.
--   * A click starts a swing. The blade lands partway through it (the tool's `impact`; the double-bit lands twice),
--     and only then does it look what's under the crosshair: bark comes off (chop / axe sound, higher for the inner
--     layer), bare wood just knocks (chop_wood, wood chips), the ground thuds and throws dirt, and a bare-handed
--     miss is a whoosh. Heavier tools kick the view harder. The server decides what actually comes off.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local BarkGrid = require(ReplicatedStorage.Shared.BarkGrid)
local InputController = require(script.Parent.InputController)
local State = require(script.Parent.Parent.State)
local Sfx = require(script.Parent.Parent.Sfx)

local ToolController = {}
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local crownHome: { [Model]: CFrame } = {}
local impacts = 0

local function def(): any
	return (Config.Tools :: any)[State.tool] or Config.Tools.hands
end

local function split(s: any): { [string]: boolean }
	local out = {}
	if typeof(s) == "string" then
		for id in string.gmatch(s, "[^,]+") do
			out[id] = true
		end
	end
	return out
end

-- the tool bar: what you own and haven't put down, in Godot's order
function ToolController.bar(): { string }
	local owned, dropped = split(player:GetAttribute("Owned")), split(player:GetAttribute("Dropped"))
	local out = {}
	for _, id in Config.ToolOrder do
		if (id == "hands" or owned[id]) and not dropped[id] then
			table.insert(out, id)
		end
	end
	return out
end

function ToolController.equip(id: string)
	if id == State.tool or not table.find(ToolController.bar(), id) then
		return
	end
	State.tool = id
	State.swing = -1
	State.equipT = 0
	Sfx.play("equip")
	remotes.Equip:FireServer(id)
	State.toolsChanged()
end

local function cycle(step: number)
	local bar = ToolController.bar()
	local i = table.find(bar, State.tool) or 1
	ToolController.equip(bar[(i - 1 + step) % #bar + 1])
end

local function treeOf(inst: Instance?): Model?
	while inst and inst ~= workspace do
		if inst:IsA("Model") and CollectionService:HasTag(inst, "Tree") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

-- what's under the crosshair within `reach` studs (loose bark and your own body don't stop a swing)
function ToolController.aim(reach: number): RaycastResult?
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local loose = workspace:FindFirstChild("Loose")
	if loose then
		table.insert(ignore, loose)
	end
	table.insert(ignore, cam)
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	return workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * reach, params)
end

-- the bark circle right now (the combo axe's grows with each hit in a row: Godot's strip_radius)
function ToolController.stripRadius(): number
	local d = def()
	local r = d.stripRadius
	if d.combo then
		r += 0.05 * State.combo
	end
	return r
end

function ToolController.aimingAtTree(): (boolean, number)
	local d = def()
	local hit = ToolController.aim(math.min(d.reach, 3) * M)
	if hit and treeOf(hit.Instance) then
		return true, (hit.Position - workspace.CurrentCamera.CFrame.Position).Magnitude
	end
	return false, d.reach * M
end

local function burst(at: Vector3, normal: Vector3, color: Color3, amount: number, speed: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.lookAt(at, at + normal)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.25))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.06) })
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, -9.8 * M, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-300, 300)
	e.EmissionDirection = Enum.NormalId.Front
	e.Rate = 0
	e.Parent = p
	e:Emit(amount)
	task.delay(1, function()
		p:Destroy()
	end)
end

-- the crown wobbles when you hit the trunk (Godot's shake_crown)
local function shake(tree: Model, strength: number)
	local crown = tree:FindFirstChild("Crown") :: Model?
	if not crown then
		return
	end
	local home = crownHome[crown] or crown:GetPivot()
	crownHome[crown] = home
	local v = Instance.new("CFrameValue")
	v.Value = home * CFrame.Angles(math.rad(3 * strength), 0, math.rad(2 * strength))
	v.Changed:Connect(function(cf)
		if crown.Parent then
			crown:PivotTo(cf)
		end
	end)
	crown:PivotTo(v.Value)
	local t = TweenService:Create(v, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Value = home })
	t:Play()
	t.Completed:Once(function()
		v:Destroy()
	end)
end

-- which layer the hit would take, read from the bark this client has (the server has the final say)
local function predictLayer(tree: Model, at: Vector3, d: any): number?
	local sectors = tree:GetAttribute("Sectors") :: number or 16
	local bands = tree:GetAttribute("Bands") :: number or 40
	local saved = tree:GetAttribute("Bark")
	local g = if typeof(saved) == "string" then BarkGrid.decode(sectors, bands, saved) else BarkGrid.new(sectors, bands)
	if not g then
		return nil
	end
	local loc = tree:GetPivot():PointToObjectSpace(at)
	local i = math.floor((math.atan2(loc.Z, loc.X) % (2 * math.pi)) / (2 * math.pi) * sectors)
	local j = math.clamp(math.floor(loc.Y / (tree:GetAttribute("Height") :: number or 20) * bands), 0, bands - 1)
	local species = (Config.Species :: any)[tree:GetAttribute("Species") or "oak"] or Config.Species.oak
	if d.ring or d.through or d.spiral then
		-- (these take bark wherever there's some near the hit: the outermost layer there)
		local i2, j2 = i, j
		return if BarkGrid.has(g, BarkGrid.OUTER, i2, j2) then BarkGrid.OUTER elseif BarkGrid.has(g, BarkGrid.INNER, i2, j2) then BarkGrid.INNER else nil
	end
	local r = if State.tool == "hands" and species.handsSafe then 0.17 else ToolController.stripRadius()
	local only = if d.only == "outer" then BarkGrid.OUTER elseif d.only == "inner" then BarkGrid.INNER else nil
	local R = (tree:GetAttribute("Radius") :: number or 1.2) / M
	local lm = loc / M
	local s = BarkGrid.stripCircleAt(g, i, j, { x = lm.X, y = lm.Y, z = lm.Z }, r, R, R - Config.Tree.outerT, Config.Tree.bandH, only)
	return if s then s.layer else nil
end

-- the throwing hatchet: it spins out along your aim (20 m/s), bites a patch of bark off whatever trunk it hits,
-- sticks there a moment, then flies back to your hand (Godot's ThrownHatchet)
local function throw(d: any)
	if State.thrown then
		return
	end
	local cam = workspace.CurrentCamera
	local hit = ToolController.aim(d.reach * M)
	local from = (cam.CFrame * CFrame.new(0.12 * M, 0, -0.45 * M)).Position
	local goal = if hit then hit.Position else cam.CFrame.Position + cam.CFrame.LookVector * d.reach * M
	local models = ReplicatedStorage:FindFirstChild("ToolModels")
	local src = models and models:FindFirstChild("throwing")
	local flying = if src then (src :: Model):Clone() else nil
	State.thrown = true
	Sfx.play("whoosh", 0.75, -2)
	task.spawn(function()
		local speed = 20 * M
		local dist = (goal - from).Magnitude
		local t = 0
		local dur = dist / speed
		if flying then
			for _, p in flying:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
				end
			end
			flying.Parent = workspace
		end
		-- out, end over end, falling a little on the way
		while t < dur do
			t += RunService.Heartbeat:Wait()
			local k = math.min(1, t / dur)
			local at = from:Lerp(goal, k)
			if flying then
				flying:PivotTo(CFrame.lookAt(at, goal) * CFrame.Angles(-t * 22, 0, 0))
			end
		end
		local tree = hit and treeOf(hit.Instance)
		if tree and hit then
			Sfx.playAt("axe", hit.Position, 1.05, 2)
			burst(hit.Position, hit.Normal, hit.Instance.Color, 10, 22)
			shake(tree, 0.5)
			remotes.StripRequest:FireServer(tree, hit.Position, "throwing")
		else
			Sfx.playAt("thud", goal, 1.2, -2)
		end
		task.wait(0.32)         -- stuck a moment
		-- then back to your hand
		local back = 0
		while flying and back < dur do
			back += RunService.Heartbeat:Wait()
			local hand = (workspace.CurrentCamera.CFrame * CFrame.new(0.26 * M, -0.3 * M, -0.5 * M)).Position
			local k = math.min(1, back / dur)
			flying:PivotTo(CFrame.new(goal:Lerp(hand, k)) * CFrame.Angles(back * 22, 0, 0))
		end
		if flying then
			flying:Destroy()
		end
		State.thrown = false
		State.catch = 1
		Sfx.play("catch", 1, -3)
	end)
end

-- the blade lands (Godot's _do_impact)
local function impact()
	local d = def()
	if d.throw then
		throw(d)
		return
	end
	if d.build then
		return         -- (the hammer's swing is just the swing: Godot's _do_impact)
	end
	if d.snip then
		-- the shears: a snip in the leaves of the crown you're looking at (Godot's _snip)
		Sfx.play("click", 0.6, -2)
		local tree, at = ToolController.crownAt(d.reach)
		if tree and at then
			Sfx.play("snip", 1)
			burst(at, -workspace.CurrentCamera.CFrame.LookVector, Color3.fromHex("5aab44"), 8, 3)
			remotes.Snip:FireServer(tree, at)
		end
		return
	end
	local hit = ToolController.aim(d.reach * M)
	if not hit then
		if State.tool == "hands" then
			Sfx.play("whoosh", 1.2, -6)
		end
		return
	end
	local tree = treeOf(hit.Instance)
	if tree then
		local layer = predictLayer(tree, hit.Position, d)
		if layer ~= nil and d.anim == "drill" then
			Sfx.play("drill", 1, -8)
			burst(hit.Position, hit.Normal, hit.Instance.Color, 6, 16)
		elseif layer ~= nil and State.tool == "robo" then
			Sfx.play("clink", 1.6, -8)
			Sfx.play("axe", 1.3, -4)
			burst(hit.Position, hit.Normal, hit.Instance.Color, 10, 22)
		elseif layer ~= nil then
			Sfx.play(if State.tool == "hands" then "chop" else "axe", if layer == BarkGrid.OUTER then 1 else 1.15)
			burst(hit.Position, hit.Normal, hit.Instance.Color, 10, 22)
		else
			Sfx.play("chop_wood")
			burst(hit.Position, hit.Normal, Color3.fromRGB(214, 176, 128), 8, 20)
		end
		State.kick = 0.01 + ToolController.stripRadius() * 0.09 + (if d.through then 0.03 else 0)
		shake(tree, 0.4 + ToolController.stripRadius())
		if d.combo then
			State.combo = math.min(State.combo + 1, Config.ComboMax)
			State.comboT = 0
		end
		remotes.StripRequest:FireServer(tree, hit.Position, State.tool)
	elseif hit.Instance == workspace.Terrain or hit.Material == Enum.Material.Grass or hit.Material == Enum.Material.Ground then
		-- dirt and grass fly where you hit the ground
		burst(hit.Position, hit.Normal, Color3.fromHex("7a5a3a"), 8, 14)
		burst(hit.Position, hit.Normal, Color3.fromHex("5f9a3a"), 6, 10)
		Sfx.play("thud", 1.4, -6)
	else
		Sfx.play("thud", 1, -4)
	end
end

-- A bolt from the sky onto `at`, a flash and a thunderclap (Godot's _lightning). Everyone sees it.
local function lightning(at: Vector3)
	local bolt = Instance.new("Model")
	bolt.Name = "Lightning"
	local p = at + Vector3.new((math.random() * 4 - 2) * M, 26 * M, (math.random() * 4 - 2) * M)
	local steps = 9
	for i = 0, steps - 1 do
		local k = (i + 1) / steps
		local q = p:Lerp(at, 1 / (steps - i))
		if i < steps - 1 then
			q += Vector3.new((math.random() * 1.8 - 0.9) * M, 0, (math.random() * 1.8 - 0.9) * M)
		end
		local seg = Instance.new("Part")
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CastShadow = false
		seg.Material = Enum.Material.Neon
		seg.Color = Color3.fromHex("e8f6ff")
		local w = 0.12 * (1.2 - k * 0.6) * M
		seg.Size = Vector3.new(w, w, (q - p).Magnitude)
		seg.CFrame = CFrame.lookAt((p + q) / 2, q)
		seg.Parent = bolt
		p = q
	end
	bolt.Parent = workspace
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.Position = at + Vector3.new(0, 2 * M, 0)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("cfeaff")
	light.Brightness = 10
	light.Range = 60          -- (Roblox lights reach 60 studs at most; Godot's is 30 m)
	light.Parent = holder
	holder.Parent = workspace
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	task.spawn(function()
		task.wait(0.12)
		bolt.Parent = nil
		task.wait(0.06)
		bolt.Parent = workspace
		task.wait(0.08)
		bolt:Destroy()
		task.wait(0.3)
		holder:Destroy()
	end)
	burst(at, Vector3.yAxis, Color3.fromHex("bfe9ff"), 40, 6 * M)
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - at).Magnitude < 60 * M then
		State.white = math.max(State.white, 0.75)
	end
	Sfx.play("thunder", 1, 2)
end
ToolController.lightning = lightning

-- the standing tree whose crown is along your aim within `reach` metres, and the spot (the pole saw). The leaves
-- don't stop rays, so this walks along the aim line: inside a crown means within 2 m of the trunk's line, from
-- 2.2 m below its top to 3 m above it. A trunk in the way stops it.
function ToolController.crownAt(reach: number): (Model?, Vector3?)
	local cam = workspace.CurrentCamera
	local from, dir = cam.CFrame.Position, cam.CFrame.LookVector
	local hit = ToolController.aim(reach * M)
	local stop = if hit then (hit.Position - from).Magnitude else reach * M
	local near = {}
	for _, t in CollectionService:GetTagged("Tree") do
		if t:IsA("Model") and not t:GetAttribute("Log") and not t:GetAttribute("Felled") and not t:GetAttribute("CrownCut") then
			local d = t:GetPivot().Position - from
			if Vector2.new(d.X, d.Z).Magnitude < (reach + 3) * M then
				table.insert(near, t)
			end
		end
	end
	if #near == 0 then
		return nil, nil
	end
	local dist = 0.5 * M
	while dist <= stop do
		local at = from + dir * dist
		for _, t in near do
			local loc = t:GetPivot():PointToObjectSpace(at)
			local h = t:GetAttribute("Height") :: number or 20
			if Vector2.new(loc.X, loc.Z).Magnitude < 2 * M and loc.Y > h - Config.Saw.crownReach * M and loc.Y < h + 3 * M then
				return t, at
			end
		end
		dist += 0.25 * M
	end
	return nil, nil
end

local function startSwing()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if State.swing >= 0 or State.equipT < 1 or State.uiOpen or State.fainted or not hum or hum.Health <= 0 or State.thrown then
		return
	end
	if def().hold then
		return        -- saws run while the button is held (see the Heartbeat below)
	end
	-- (holding something: the click does nothing, like Godot's)
	local loose = workspace:FindFirstChild("Loose")
	if loose then
		for _, p in loose:GetChildren() do
			if p:GetAttribute("HeldBy") == player.UserId then
				return
			end
		end
	end
	-- (a click on a TimberMart box opens it instead, like Godot's on_click)
	local d = def()
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character :: Instance, cam }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local near = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * math.min(d.reach, 3) * M, params)
	if near and near.Instance:GetAttribute("Kind") == "box" and near.Instance:GetAttribute("Owner") == player.UserId then
		remotes.Open:FireServer(near.Instance)
		return
	end
	-- (a click on a catapult fires it: Godot's Catapult.on_click)
	local b = near and near.Instance:FindFirstAncestorWhichIsA("Model")
	while b and b:GetAttribute("Kind") ~= "build" do
		b = b:FindFirstAncestorWhichIsA("Model")
	end
	if near and b and b:GetAttribute("Build") == "catapult" then
		remotes.Click:FireServer(near.Instance)
		return
	end
	State.swing = 0
	impacts = 0
	if d.anim == "double" or d.anim == "sweep" or d.anim == "twin" then
		State.backhand = not State.backhand
	end
	if State.tool ~= "hands" then
		Sfx.play("whoosh", 1.4 - d.stripRadius, -8)
	end
end

function ToolController.start()
	local pressing = false
	InputController.on("Swing", function(state)
		pressing = state == Enum.UserInputState.Begin
		if state == Enum.UserInputState.Begin and not def().charge and not def().build then
			startSwing()
		end
	end)
	local sawTarget: Model? = nil
	local drillCd = 0
	local vacSend, vacDust = 0, 0
	local vacSound: Sound? = nil
	local runCd, washFx = 0, 0
	local washSound: Sound? = nil
	local sawFx = 0
	local told: { [string]: number } = {}
	local function tell(key: string, text: string)
		local now = os.clock()
		if now - (told[key] or -100) > 6 then
			told[key] = now
			State.toast(text, Color3.fromHex("ffd27a"))
		end
	end
	local chain: Sound? = nil
	local charging = false
	RunService.Heartbeat:Connect(function(dt)
		if pressing and def().auto and State.swing < 0 then
			startSwing()
		end
		-- the Thunder Axe: hold to charge, let go on a trunk and lightning strips the whole tree. Let go early and
		-- it's an ordinary hit; after a strike it needs a few seconds to charge again (Godot's _thunder_step)
		local td = def()
		State.thunderCd = math.max(0, State.thunderCd - dt)
		if not td.charge then
			charging = false
			State.charge = 0
		else
			if pressing and not charging and State.swing < 0 and State.equipT >= 1 and not State.uiOpen then
				charging = true
			end
			if charging and pressing then
				if State.thunderCd > 0 then
					tell("thunder", "The Thunder Axe is still recharging")
				else
					local was = State.charge
					State.charge = math.min(1, State.charge + dt / td.charge)
					if was < 1 and State.charge >= 1 then
						Sfx.play("crackle", 0.8, 0)
					elseif math.random() < dt * (3 + State.charge * 12) then
						Sfx.play("crackle", 0.9 + math.random() * 0.5, -14 + 10 * State.charge)
					end
				end
			elseif charging then
				charging = false
				if State.charge >= 1 then
					State.thunderCd = td.rest
					startSwing()
					local hit = ToolController.aim((td.reach + 1) * M)
					local tree = hit and treeOf(hit.Instance)
					if hit and tree then
						shake(tree, 3)
						remotes.StripRequest:FireServer(tree, hit.Position, State.tool, true)
					else
						local cam = workspace.CurrentCamera
						lightning(if hit then hit.Position else cam.CFrame.Position + cam.CFrame.LookVector * 4 * M)
					end
					State.kick = 0.1
				else
					startSwing()
				end
				State.charge = 0
			end
		end
		-- saws: hold the button against a trunk until the ring fills (Godot's _saw_step)
		local d = def()
		State.sawing = false
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local alive = pressing and not State.uiOpen and not State.fainted and hum ~= nil and hum.Health > 0
		if d.kind == "polesaw" then
			-- the pole saw: held up in the leaves of a standing tree (or the top of its trunk) for 1.8 s, the whole
			-- crown comes off (Godot's _polesaw_step)
			local tree, at = nil, nil
			if alive then
				tree, at = ToolController.crownAt(d.reach)
			end
			if not tree or not at then
				State.sawProgress = math.max(0, State.sawProgress - dt * 2)
				if State.sawProgress <= 0 then
					sawTarget = nil
				end
			else
				State.sawing = true
				if tree ~= sawTarget then
					sawTarget = tree
					State.sawProgress = 0
					remotes.SawStart:FireServer(tree:FindFirstChild("Trunk"))
				end
				State.sawProgress += dt / Config.Saw.crownTime
				sawFx -= dt
				if sawFx <= 0 then
					sawFx = 0.12
					Sfx.play("saw", 1 + math.random() * 0.2, -8)
					burst(at, -Vector3.yAxis, Color3.fromHex("6aa846"), 5, 3)
				end
				if State.sawProgress >= 1 then
					State.sawProgress = 0
					sawTarget = nil
					remotes.Sawn:FireServer(tree:FindFirstChild("Trunk"), at)
				end
			end
		end
		-- the bark drills: a bite every `cooldown` seconds while the trigger is held on a trunk (Godot's _drilling)
		State.drilling = alive and d.kind == "drill" and State.equipT >= 1
		if State.drilling then
			drillCd -= dt
			if drillCd <= 0 then
				drillCd = d.cooldown
				if ToolController.aimingAtTree() then
					impact()
				end
			end
		end
		-- the vacuums: while the trigger is held, tell the server where the nozzle points (it moves the things)
		local vac = alive and d.kind == "vacuum" and State.equipT >= 1
		if vac then
			vacSend -= dt
			if vacSend <= 0 then
				vacSend = 0.1
				local cf = workspace.CurrentCamera.CFrame
				remotes.Vacuum:FireServer(true, cf.Position, cf.LookVector, cf.RightVector)
			end
			vacDust -= dt
			if vacDust <= 0 then
				vacDust = 0.08
				local cf = workspace.CurrentCamera.CFrame
				local nozzle = cf.Position + cf.LookVector * 1.25 * M - Vector3.new(0, 0.18 * M, 0)
				local src = nozzle + cf.LookVector * (1 + math.random() * 2) * M + Vector3.new(math.random() * 1.2 - 0.6, math.random() * 0.8 - 0.4, math.random() * 1.2 - 0.6) * M
				burst(src, (nozzle - src).Unit, Color3.new(0.8, 0.78, 0.7), 3, (nozzle - src).Magnitude * 1.2)
			end
			if not vacSound then
				vacSound = Sfx.loop("vacuum", -10)
			end
		elseif State.vacuuming then
			remotes.Vacuum:FireServer(false)
			vacSend = 0
		end
		if not vac and vacSound then
			vacSound:Destroy()
			vacSound = nil
		end
		State.vacuuming = vac
		-- the motor tools (Godot's _motor_step): the pressure washer's jet wanders a little round the aim and flakes
		-- bark off where it lands; the planer takes a strip the length of a lying log every 0.45 s
		local motor = alive and (d.kind == "washer" or d.kind == "planer") and State.equipT >= 1
		State.running = motor
		if motor then
			local cf = workspace.CurrentCamera.CFrame
			local hit: RaycastResult? = nil
			if d.kind == "washer" then
				local jet = (cf.LookVector + (cf.RightVector * (math.random() * 2 - 1) + cf.UpVector * (math.random() * 2 - 1)) * 0.022).Unit
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = { player.Character :: Instance, workspace.CurrentCamera, workspace:FindFirstChild("Loose") :: Instance }
				params.FilterType = Enum.RaycastFilterType.Exclude
				hit = workspace:Raycast(cf.Position, jet * d.reach * M, params)
				local nozzle = cf.Position + cf.LookVector * 0.9 * M - cf.UpVector * 0.16 * M + cf.RightVector * 0.08 * M
				local stop = if hit then hit.Position else cf.Position + cf.LookVector * d.reach * M
				washFx -= dt
				if washFx <= 0 then
					washFx = 0.04
					burst(nozzle, (stop - nozzle).Unit, Color3.new(0.82, 0.9, 1), 4, (stop - nozzle).Magnitude * 2.6)
					if hit then
						burst(hit.Position, hit.Normal, Color3.new(0.85, 0.92, 1), 3, 4.5)
					end
				end
				if not washSound then
					washSound = Sfx.loop("washer", -10)
				end
			else
				hit = ToolController.aim(d.reach * M)
			end
			runCd -= dt
			if runCd <= 0 and hit then
				runCd = d.cooldown
				local tree = treeOf(hit.Instance)
				if tree and d.kind == "planer" and not tree:GetAttribute("Log") then
					tell("planer", "The planer only works on logs lying down - fell the tree first")
				elseif tree then
					if d.kind == "planer" then
						Sfx.play("saw", 1.6, -4)
						Sfx.play("drill", 1.3, -8)
					end
					remotes.StripRequest:FireServer(tree, hit.Position, State.tool)
				end
			end
		end
		if (not motor or d.kind ~= "washer") and washSound then
			washSound:Destroy()
			washSound = nil
		end
		local on = alive and d.hold and d.kind ~= "polesaw" and d.kind ~= "drill" and d.kind ~= "vacuum" and not motor
		local hit = if on then ToolController.aim(d.reach * M) else nil
		local m = hit and treeOf(hit.Instance)
		local canFell = d.fell ~= false
		local blocked = m and not m:GetAttribute("Log") and ((m:GetAttribute("Bands") :: number) < 4 or not canFell)
		if m and not m:GetAttribute("Log") and m:GetAttribute("Legendary") then
			tell("legend", "Only the two-man crosscut gets through the Legendary Tree")
			blocked = true
		elseif m and not m:GetAttribute("Log") and m:GetAttribute("Giant") and State.tool ~= "chainsaw" then
			tell("giant", "Too thick for this saw - it needs a two-man crosscut, or a chainsaw")
			blocked = true
		end
		if d.kind == "polesaw" then
			-- (done above)
		elseif not hit or not m or blocked then
			State.sawProgress = math.max(0, State.sawProgress - dt * 2)
			if State.sawProgress <= 0 then
				sawTarget = nil
			end
		else
			State.sawing = true
			if m ~= sawTarget then
				sawTarget = m
				State.sawProgress = 0
				remotes.SawStart:FireServer(hit.Instance)
			end
			local need = if m:GetAttribute("Log") then Config.Saw.logTime
				else Config.Saw.treeTime * ((m:GetAttribute("Radius") :: number or 1.14) / M / 0.38)
			State.sawProgress += dt / need * (d.speed or 1)
			sawFx -= dt
			if sawFx <= 0 then
				local isChain = State.tool == "chainsaw"
				sawFx = if isChain then 0.05 else 0.09
				local sp = (Config.Species :: any)[m:GetAttribute("Species") or "oak"] or Config.Species.oak
				burst(hit.Position, hit.Normal - Vector3.new(0, 0.3, 0), Color3.fromHex(sp.wood):Lerp(Color3.new(1, 1, 1), 0.1), if isChain then 10 else 6, if isChain then 7.8 else 4.2)
				if not isChain then
					Sfx.play("saw", 0.9 + math.random() * 0.2, -6)
				end
			end
			if State.sawProgress >= 1 then
				State.sawProgress = 0
				sawTarget = nil
				remotes.Sawn:FireServer(hit.Instance, hit.Position)
				burst(hit.Position, Vector3.yAxis, Color3.fromHex(((Config.Species :: any)[m:GetAttribute("Species") or "oak"] or Config.Species.oak).wood), 24, 6)
			end
		end
		-- the chainsaw idles while it's in your hand and revs while it cuts
		if State.tool == "chainsaw" and not chain then
			chain = Sfx.loop("chainsaw", -14)
		elseif State.tool ~= "chainsaw" and chain then
			chain:Destroy()
			chain = nil
		end
		if chain then
			chain.PlaybackSpeed = if State.sawing then 1.35 else 1
		end
		State.comboT += dt
		if State.comboT > 1.25 and State.combo > 0 then
			State.combo = 0
			Sfx.play("click", 0.5, -8)
		end
	end)
	remotes.Fx.OnClientEvent:Connect(function(name: string, at: Vector3?)
		if name == "lightning" and at then
			lightning(at)
		end
	end)
	InputController.on("NextTool", function(state)
		if state == Enum.UserInputState.Begin and not State.uiOpen and not State.placing then
			cycle(1)
		end
	end)
	InputController.on("PrevTool", function(state)
		if state == Enum.UserInputState.Begin and not State.uiOpen and not State.placing then
			cycle(-1)
		end
	end)
	InputController.on("DropTool", function(state)
		if state == Enum.UserInputState.Begin and State.tool ~= "hands" and not State.uiOpen then
			remotes.DropTool:FireServer()
			State.tool = "hands"
			State.swing = -1
			State.equipT = 0
			Sfx.play("drop", 0.8)
			State.toolsChanged()
		end
	end)
	-- 1-9 pick your first nine tools; with Shift held, the next nine
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
		Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or State.uiOpen then
			return
		end
		local n = table.find(keys, input.KeyCode)
		if n then
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				n += 9
			end
			local bar = ToolController.bar()
			if bar[n] then
				ToolController.equip(bar[n])
			end
		end
	end)
	-- the server put something in your hand (taken from the chopping block, bought, picked back up)
	local function fromServer()
		local id = player:GetAttribute("Tool")
		if typeof(id) == "string" and id ~= State.tool then
			State.tool = id
			State.swing = -1
			State.equipT = 0
			if id ~= "hands" then
				Sfx.play("equip")
			end
		end
		State.toolsChanged()
	end
	player:GetAttributeChangedSignal("Tool"):Connect(fromServer)
	player:GetAttributeChangedSignal("Owned"):Connect(State.toolsChanged)
	player:GetAttributeChangedSignal("Dropped"):Connect(State.toolsChanged)
	RunService.Heartbeat:Connect(function(dt)
		State.equipT = math.min(1, State.equipT + dt * 4)
		if State.swing < 0 then
			return
		end
		local d = def()
		State.swing += dt / d.cooldown
		local hits = d.impacts or { d.impact }
		while impacts < #hits and State.swing >= hits[impacts + 1] do
			impacts += 1
			impact()
		end
		if State.swing >= 1 then
			State.swing = -1
		end
	end)
	-- a respawn: back to bare hands in view until the server says otherwise
	player.CharacterAdded:Connect(function()
		State.swing = -1
		State.equipT = 0
	end)
end

return ToolController
