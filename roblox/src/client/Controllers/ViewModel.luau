--!strict
-- The first-person arm, ported from the Godot game's Player.gd (_build_arm, _animate_arm, ARCS, _poses), in metres x3:
--   * a red sleeve with two plaid cuffs, skin at the wrist, and the flat karate hand (bare hands) or a fist (a tool)
--   * axes swing along Godot's arcs: the hand travels round a pivot (wind up, strike, follow through, back to rest),
--     the double-bit sweeps forehand then backhand, the labrys and the greataxe slam overhead (the labrys spins)
--   * bare hands use Godot's three poses (rest, wind-up, strike) for a karate chop
--   * it sways as you walk, comes up tilted when you take a tool out, and follows its target smoothly
-- Camera space is the same in both engines (-Z ahead, +Y up, +X right), so Godot's numbers carry straight over.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.State)

local ViewModel = {}
local M = Config.StudsPerMetre
local SLEEVE = Color3.fromHex("b8322c")
local PLAID = Color3.fromHex("2a2a2a")
local SKIN = Color3.fromHex("e0a989")
local ARM_BASE = Vector3.new(0.26, -0.3, -0.46)       -- metres, camera space
local TOOL_ROOT = CFrame.new(0, -0.01 * M, -0.13 * M)
-- the tool inside the arm: handle (+Y) along the forearm (-Z), cutting edge (-Z) along the arm's +X
local TOOL_IN_ARM = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 1, 0), Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0))
local TOOL_SCALE = 0.5          -- (the stand-in models are sized for a character's hand; the Godot ones are exact)

-- Godot's swing arcs (camera space, metres): the hand goes round `pivot` about `axis`, starting from r0, `len` out;
-- a = { wind-up, strike, follow-through } angles in degrees
local ARCS = {
	chop = { pivot = Vector3.new(-0.2, -0.45, -0.4), axis = Vector3.new(-0.87, 0.5, 0.0), r0 = Vector3.new(0.5, 0.87, 0.0), len = 0.3, a = { -70, 36, 90 } },
	sweep = { pivot = Vector3.new(-0.3, -0.65, -0.28), axis = Vector3.new(-0.87, 0.5, 0.0), r0 = Vector3.new(0.5, 0.87, 0.0), len = 0.32, a = { -75, 36, 90 } },
	sweep_back = { pivot = Vector3.new(0.3, -0.65, -0.28), axis = Vector3.new(-0.87, -0.5, 0.0), r0 = Vector3.new(-0.5, 0.87, 0.0), len = 0.32, a = { -75, 36, 90 } },
	slam = { pivot = Vector3.new(-0.3, -0.7, -0.25), axis = Vector3.new(-0.87, 0.5, 0.0), r0 = Vector3.new(0.5, 0.87, 0.0), len = 0.32, a = { -85, 36, 90 } },
	twin = { pivot = Vector3.new(-0.15, -0.45, -0.35), axis = Vector3.new(-0.87, 0.5, 0.0), r0 = Vector3.new(0.5, 0.87, 0.0), len = 0.3, a = { -60, 36, 85 } },
}
-- { offset, rotation in degrees } for rest, wind-up and strike (Godot's _poses): bare hands, and the spud's thrust
local POSES = {
	karate = {
		{ Vector3.new(0, 0, 0), Vector3.new(4, 6, 0) },
		{ Vector3.new(0.06, 0.24, 0.1), Vector3.new(55, -5, 30) },
		{ Vector3.new(-0.2, -0.02, -0.26), Vector3.new(-20, 25, -15) },
	},
	-- saws: push-pull strokes against the trunk
	saw = {
		{ Vector3.new(-0.06, -0.02, 0), Vector3.new(-4, 6, 0) },
		{ Vector3.new(-0.08, -0.04, 0.05), Vector3.new(-6, 3, 0) },
		{ Vector3.new(-0.1, -0.06, -0.12), Vector3.new(-8, 0, 0) },
	},
	-- the shears: raised into the leaves, jaws snapping
	snip = {
		{ Vector3.new(-0.04, 0.04, 0), Vector3.new(14, 6, 0) },
		{ Vector3.new(-0.05, 0.08, -0.02), Vector3.new(22, 4, 0) },
		{ Vector3.new(-0.06, 0.12, -0.14), Vector3.new(28, 2, 0) },
	},
	-- the vacuums: held level, humming
	vacuum = {
		{ Vector3.new(-0.06, 0.0, 0), Vector3.new(-2, 6, 0) },
		{ Vector3.new(-0.08, 0.0, -0.04), Vector3.new(-2, 3, 0) },
		{ Vector3.new(-0.1, 0.0, -0.06), Vector3.new(0, 0, 0) },
	},
	-- the pressure washer: held like the vacuum; the planer: pushed along the log
	washer = {
		{ Vector3.new(-0.06, 0.0, 0), Vector3.new(-2, 6, 0) },
		{ Vector3.new(-0.08, 0.0, -0.04), Vector3.new(-2, 3, 0) },
		{ Vector3.new(-0.1, 0.0, -0.06), Vector3.new(0, 0, 0) },
	},
	planer = {
		{ Vector3.new(-0.05, 0.02, 0), Vector3.new(-6, 8, 0) },
		{ Vector3.new(-0.06, 0.01, -0.05), Vector3.new(-10, 5, 0) },
		{ Vector3.new(-0.07, 0.0, -0.1), Vector3.new(-14, 2, 0) },
	},
	-- the drills: pushed in against the trunk, buzzing
	drill = {
		{ Vector3.new(-0.02, 0.02, 0), Vector3.new(2, 4, 0) },
		{ Vector3.new(-0.04, 0.02, -0.06), Vector3.new(0, 2, 0) },
		{ Vector3.new(-0.05, 0.02, -0.12), Vector3.new(0, 0, 0) },
	},
	-- the pole saw: held up high, pushing and pulling up in the leaves
	polesaw = {
		{ Vector3.new(-0.05, -0.06, 0), Vector3.new(0, 5, 0) },
		{ Vector3.new(-0.06, -0.05, 0.07), Vector3.new(2, 4, 0) },
		{ Vector3.new(-0.07, -0.02, -0.12), Vector3.new(4, 2, 0) },
	},
	-- draw the spud back, then push it in under the bark
	thrust = {
		{ Vector3.new(-0.02, 0.0, 0.08), Vector3.new(4, 14, 0) },
		{ Vector3.new(-0.01, 0.02, 0.18), Vector3.new(6, 12, 0) },
		{ Vector3.new(-0.07, -0.02, -0.2), Vector3.new(-3, 4, 0) },
	},
}

local model: Model
local leftArm: Model          -- the left arm: only out for the twin hatchets
local handFlat: { BasePart } = {}
local handFist: { BasePart } = {}
local toolModel: Model? = nil
local leftTool: Model? = nil
local shownTool = ""
local armCf = CFrame.new(ARM_BASE * M)        -- the arm, camera space, as drawn last frame
local leftCf = CFrame.new(ARM_BASE * Vector3.new(-1, 1, 1) * M)

-- Godot's ease(x, curve)
local function ease(x: number, c: number): number
	x = math.clamp(x, 0, 1)
	if c > 0 then
		if c < 1 then
			return 1 - (1 - x) ^ (1 / c)
		end
		return x ^ c
	elseif c < 0 then
		if x < 0.5 then
			return (x * 2) ^ -c * 0.5
		end
		return (1 - (1 - (x - 0.5) * 2) ^ -c) * 0.5 + 0.5
	end
	return 0
end

local function follow(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

local function rotate(v: Vector3, axis: Vector3, deg: number): Vector3
	return CFrame.fromAxisAngle(axis.Unit, math.rad(deg)):VectorToWorldSpace(v)
end

-- the arm with its hand at `hand`, forearm along `radial`, its +X along `tangent` (Godot's _arm_xform), in studs
local function armXform(hand: Vector3, radial: Vector3, tangent: Vector3): CFrame
	local z = -radial.Unit
	local x = (tangent - z * tangent:Dot(z)).Unit
	local y = z:Cross(x)
	return CFrame.fromMatrix((hand + radial.Unit * 0.13) * M, x, y, z)
end

local function arcXform(arc: any, deg: number): CFrame
	local r = rotate(arc.r0.Unit, arc.axis, deg)
	return armXform(arc.pivot + r * arc.len, r, arc.axis.Unit:Cross(r))
end

local function sway(): Vector3
	local on = if (State :: any).settings and (State :: any).settings.bob == false then 0 else 1
	return Vector3.new(math.sin(State.bob * 0.5) * 0.012, -math.abs(math.sin(State.bob)) * 0.008, 0) * on
end

local function restXform(): CFrame
	-- the tool held up in front, edge facing forward
	local radial = Vector3.new(0.15, 0.8, -0.55).Unit
	return armXform(ARM_BASE + Vector3.new(0, -0.04, 0.02) + sway(), radial, radial:Cross(Vector3.xAxis))
end

local function raised(t: CFrame, raise: number): CFrame
	if raise <= 0 then
		return t
	end
	return CFrame.new(t.Position - Vector3.new(0, raise * M, 0)) * CFrame.Angles(-raise * 1.1, 0, 0) * t.Rotation
end

-- left <-> right (Godot's _mirror: x flips, and the rotation is reflected through the YZ plane)
local function mirror(t: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = t:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

local function euler(deg: Vector3): CFrame
	-- Godot's rotation_degrees: Y, then X, then Z
	return CFrame.fromEulerAnglesYXZ(math.rad(deg.X), math.rad(deg.Y), math.rad(deg.Z))
end

-- ------------------------------------------------------------------ building the arm (Godot's _build_arm)
local function piece(shape: Enum.PartType, size: Vector3, at: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = at
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

-- a cylinder along the arm (Godot's lie along Z; Roblox's run along X)
local function cyl(radius: number, length: number, z: number, color: Color3, material: Enum.Material?): Part
	return piece(Enum.PartType.Cylinder, Vector3.new(length * M, radius * 2 * M, radius * 2 * M), CFrame.new(0, 0, z * M) * CFrame.Angles(0, math.rad(90), 0), color, material)
end

local function build()
	model = Instance.new("Model")
	model.Name = "ViewModel"
	cyl(0.046, 0.34, 0.17, SLEEVE, Enum.Material.Fabric)
	cyl(0.051, 0.025, 0.08, PLAID, Enum.Material.Fabric)
	cyl(0.046, 0.04, 0.0, PLAID, Enum.Material.Fabric)
	cyl(0.032, 0.07, -0.05, SKIN)
	table.insert(handFlat, piece(Enum.PartType.Block, Vector3.new(0.026, 0.085, 0.11) * M, CFrame.new(0, 0, -0.13 * M), SKIN))
	table.insert(handFlat, piece(Enum.PartType.Block, Vector3.new(0.024, 0.075, 0.035) * M, CFrame.new(0, -0.004 * M, -0.2 * M), SKIN))
	table.insert(handFlat, piece(Enum.PartType.Block, Vector3.new(0.022, 0.022, 0.06) * M, CFrame.new(0.016 * M, 0.036 * M, -0.1 * M) * CFrame.Angles(0, math.rad(-20), 0), SKIN))
	table.insert(handFist, piece(Enum.PartType.Block, Vector3.new(0.06, 0.075, 0.08) * M, CFrame.new(0, 0, -0.12 * M), SKIN))
	table.insert(handFist, piece(Enum.PartType.Block, Vector3.new(0.062, 0.03, 0.05) * M, CFrame.new(0, -0.035 * M, -0.15 * M), SKIN))
	model.WorldPivot = CFrame.new()
	-- the left arm: the same arm with a fist (Godot duplicates it)
	leftArm = Instance.new("Model")
	leftArm.Name = "LeftArm"
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and not table.find(handFlat, p) then
			p:Clone().Parent = leftArm
		end
	end
	leftArm.WorldPivot = CFrame.new()
end

local function setTool(id: string)
	shownTool = id
	if toolModel then
		toolModel:Destroy()
		toolModel = nil
	end
	for _, p in handFlat do
		p.Transparency = if id == "hands" then 0 else 1
	end
	for _, p in handFist do
		p.Transparency = if id == "hands" then 1 else 0
	end
	if leftTool then
		leftTool:Destroy()
		leftTool = nil
	end
	local models = ReplicatedStorage:FindFirstChild("ToolModels")
	local src = models and models:FindFirstChild(id)
	if id ~= "hands" and src then
		local m = (src :: Model):Clone()
		if not m:GetAttribute("Godot") then
			m:ScaleTo(TOOL_SCALE)
		end
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CastShadow = false
			end
		end
		m.Parent = model
		toolModel = m
		if (Config.Tools :: any)[id] and (Config.Tools :: any)[id].charge then
			-- the Thunder Axe's head glows, brighter as it charges (Godot's Glow)
			local glow = Instance.new("PointLight")
			glow.Name = "Glow"
			glow.Color = Color3.fromHex("bfe9ff")
			glow.Range = 6
			glow.Brightness = 0.6
			glow.Parent = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
		end
		if id == "twins" then
			leftTool = m:Clone()
			leftTool.Parent = leftArm
		end
	end
end

-- ------------------------------------------------------------------ where the arm should be this frame
local function target(def: any): (CFrame, number, number)
	local anim = def.anim or "chop"
	local impact = def.impact
	local raise = (1 - ease(State.equipT, 0.4)) * 0.35
	local spin = 0
	if POSES[anim] then
		-- bare hands and the spud: Godot's poses
		local P = POSES[anim]
		local base = ARM_BASE
		local restP, restR = base + P[1][1] + sway(), P[1][2]
		local upP, upR = base + P[2][1], P[2][2]
		local hitP, hitR = base + P[3][1], P[3][2]
		local p, r = restP, restR
		local t = State.swing
		if anim == "drill" or anim == "vacuum" or anim == "washer" or anim == "planer" then
			if State.drilling or State.vacuuming or State.running then
				p = hitP + Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, 0) * (if anim == "drill" or anim == "planer" then 0.004 else 0.006)
				r = hitR
			end
			t = -1
		elseif anim == "saw" or anim == "polesaw" then
			-- Godot: back and forth while it cuts (the chainsaw just pushes in, buzzing)
			if State.sawing then
				if State.tool == "chainsaw" then
					p = hitP + Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, 0) * 0.006
					r = hitR
				else
					local k = math.sin(os.clock() * 13) * 0.5 + 0.5
					p, r = upP:Lerp(hitP, k), upR:Lerp(hitR, k)
				end
			end
			t = -1
		end
		if t >= 0 then
			local windEnd = impact * 0.7
			if t < windEnd then
				local k = ease(t / windEnd, 0.5)
				p, r = restP:Lerp(upP, k), restR:Lerp(upR, k)
			elseif t < impact then
				local k = ease((t - windEnd) / (impact - windEnd), 2.0)
				p, r = upP:Lerp(hitP, k), upR:Lerp(hitR, k)
			else
				local k = ease((t - impact) / (1 - impact), 0.6)
				p, r = hitP:Lerp(restP, k), hitR:Lerp(restR, k)
			end
		end
		p -= Vector3.new(0, raise, 0)
		r -= Vector3.new(raise * 60, 0, 0)
		return CFrame.new(p * M) * euler(r), 55, 0
	end
	if anim == "throw" then
		local arc = { pivot = ARCS.chop.pivot, axis = ARCS.chop.axis, r0 = ARCS.chop.r0, len = ARCS.chop.len }
		local rest = restXform()
		local target = rest
		local t = State.swing
		local release = impact
		if t >= 0 then
			local wEnd, followEnd = release * 0.72, release + 0.2
			if t < wEnd then
				target = rest:Lerp(arcXform(arc, -112), ease(t / wEnd, 0.4))
			elseif t < release then
				target = arcXform(arc, -112 + 120 * ease((t - wEnd) / (release - wEnd), 2.6))
			elseif t < followEnd then
				target = arcXform(arc, 8 + 56 * ease((t - release) / (followEnd - release), 0.45))
			else
				target = arcXform(arc, 64):Lerp(rest, ease((t - followEnd) / (1 - followEnd), 0.6))
			end
		elseif State.thrown then
			-- the open hand held up and forward, ready to catch it
			local radial = Vector3.new(0.05, 0.55, -0.83).Unit
			target = armXform(ARM_BASE + Vector3.new(-0.03, 0.05 + math.sin(os.clock() * 3) * 0.006, -0.06), radial, radial:Cross(Vector3.xAxis))
		elseif State.catch > 0 then
			-- the catch: pushed back and down by its weight, then it settles
			local c = State.catch * State.catch
			target = CFrame.new(target.Position + Vector3.new(0.015, -0.06, 0.08) * c * M) * CFrame.Angles(0.45 * c, 0, 0) * target.Rotation
		end
		return raised(target, raise), if t >= 0 then 90 else 30, 0
	end
	-- axes: Godot's arcs
	local name = if anim == "double" then "sweep" elseif anim == "sweep" and State.backhand then "sweep_back" else anim
	local arc = ARCS[name] or ARCS.chop
	local t = State.swing
	if anim == "double" then
		-- forehand into the trunk, then straight back across with the other bit
		impact = 0.7
		if State.swing >= 0.5 then
			arc = ARCS.sweep_back
			t = (State.swing - 0.5) * 2
		elseif State.swing >= 0 then
			t = State.swing * 2
		end
	end
	local rest = restXform()
	local swing = rest
	if State.swing >= 0 then
		local windEnd = impact * 0.55
		local followEnd = math.min(impact + 0.18, 0.95)
		if t < windEnd then
			swing = rest:Lerp(arcXform(arc, arc.a[1]), ease(t / windEnd, 0.5))
		elseif t < impact then
			local k = ease((t - windEnd) / (impact - windEnd), 2.2)
			swing = arcXform(arc, arc.a[1] + (arc.a[2] - arc.a[1]) * k)
			if State.tool == "labrys" then
				spin = k * 360
			end
		elseif t < followEnd then
			swing = arcXform(arc, arc.a[2] + (arc.a[3] - arc.a[2]) * ease((t - impact) / (followEnd - impact), 0.5))
		else
			swing = arcXform(arc, arc.a[3]):Lerp(rest, ease((t - followEnd) / (1 - followEnd), 0.7))
		end
	end
	-- fast while swinging so the arc stays crisp, softer when settling back to rest
	local rate = if State.swing >= 0 then 85 else 22
	if anim == "twin" then
		-- twin hatchets: the hands take turns (the left one mirrors the right one's arc)
		local right = if State.backhand then rest else swing
		local left = mirror(if State.backhand then swing else rest)
		return raised(right, raise), rate, spin, raised(left, raise)
	end
	return raised(swing, raise), rate, spin
end

function ViewModel.start()
	build()
	local player = Players.LocalPlayer
	RunService:BindToRenderStep("TimberViewModel", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not camera or not hum or hum.Health <= 0 or State.uiOpen or State.fainted then
			model.Parent = nil
			leftArm.Parent = nil
			return
		end
		model.Parent = camera
		if State.tool ~= shownTool then
			setTool(State.tool)
		end
		local def = (Config.Tools :: any)[State.tool] or Config.Tools.hands
		State.catch = math.max(0, State.catch - dt * 3.5)
		-- the throwing hatchet out of your hand: the open hand, no tool
		if toolModel then
			toolModel.Parent = if State.thrown then nil else model
		end
		for _, p in handFlat do
			p.Transparency = if State.tool == "hands" or State.thrown then 0 else 1
		end
		for _, p in handFist do
			p.Transparency = if State.tool == "hands" or State.thrown then 1 else 0
		end
		local want, rate, spin, left = target(def)
		armCf = armCf:Lerp(want, follow(rate, dt))
		if left then
			leftCf = leftCf:Lerp(left, follow(rate, dt))
			leftArm.Parent = camera
			local lw = camera.CFrame * leftCf
			leftArm:PivotTo(lw)
			if leftTool then
				leftTool:PivotTo(lw * TOOL_ROOT * mirror(TOOL_IN_ARM))
			end
		else
			leftArm.Parent = nil
			leftCf = mirror(armCf)
		end
		-- a jolt on impact (heavier tools kick harder)
		local jolt = CFrame.new(0, 0, State.kick * M * 0.5)
		State.kick = math.max(0, State.kick - dt * 0.6)
		local world = camera.CFrame * armCf * jolt
		model:PivotTo(world)
		if toolModel then
			local inArm = if def.anim == "thrust" or def.anim == "saw" or def.anim == "drill" or def.anim == "vacuum" or def.anim == "washer" or def.anim == "planer" then CFrame.new(0, -0.02 * M, 0)
				elseif def.anim == "karate" then CFrame.Angles(math.rad(-35), 0, 0)
				elseif def.anim == "polesaw" then CFrame.Angles(math.rad(30), 0, 0)
				else TOOL_IN_ARM * CFrame.Angles(0, math.rad(spin), 0)
			toolModel:PivotTo(world * TOOL_ROOT * inArm)
			local glow = toolModel:FindFirstChild("Glow", true) :: PointLight?
			if glow then
				glow.Brightness = if State.thunderCd > 0 then 0.15 else 0.6 + State.charge * 5 + math.sin(os.clock() * 30) * 0.8 * State.charge
			end
		end
	end)
end

return ViewModel
