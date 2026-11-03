--!strict
-- The leaf vacuums, the Godot game's way (Player._vacuum_step). Hold the trigger: loose things in front of you
-- (bark, leaves, saplings, boxes) are pulled towards the nozzle, faster the closer they get, and once they reach it
-- they swirl there in a clump (up to 40) until you let go; then they drop. The Twin-Nozzle Vac has two intakes and
-- holds 70 in two clumps; the Cyclone Vac pulls from further in a narrow cone and fires its clump straight ahead.
-- The client says where you're aiming while the trigger is held; the server moves the things, so everyone sees it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local ToolService = require(script.Parent.ToolService)

local VacuumService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local RANGE, CONE, CAP = 7, 0.8, 40       -- Godot's VAC_RANGE, cone and VAC_MAX

type Aim = { on: boolean, origin: Vector3, dir: Vector3, right: Vector3, t: number }
local aims: { [number]: Aim } = {}      -- by UserId

local function release(uid: number, launch: boolean, dir: Vector3)
	local loose = workspace:FindFirstChild("Loose")
	for _, c in if loose then loose:GetChildren() else {} do
		if c:IsA("BasePart") and c:GetAttribute("VacBy") == uid then
			c:SetAttribute("VacBy", nil)
			c:SetAttribute("VacPhase", nil)
			if launch then
				c.AssemblyLinearVelocity = (dir * 16 + Vector3.new(0, 2, 0) + Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)) * M
			end
		end
	end
end

local function onVacuum(player: Player, on: unknown, origin: unknown, dir: unknown, right: unknown)
	local uid = player.UserId
	local tool = (Config.Tools :: any)[ToolService.current(player)]
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	local was = aims[uid]
	if on ~= true or not tool or tool.kind ~= "vacuum" or not head or typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3"
		or typeof(right) ~= "Vector3" or ((origin :: Vector3) - head.Position).Magnitude > 8 or (dir :: Vector3).Magnitude < 0.5 then
		if was and was.on then
			was.on = false
			release(uid, tool ~= nil and tool.launch == true, was.dir)
			if tool and tool.launch then
				remotes.Fx:FireAllClients("whoosh", was.origin, 0.5, 4)
			end
		end
		return
	end
	aims[uid] = { on = true, origin = origin :: Vector3, dir = (dir :: Vector3).Unit, right = (right :: Vector3).Unit, t = os.clock() }
end

function VacuumService.step(dt: number)
	local loose = workspace:FindFirstChild("Loose")
	if not loose then
		return
	end
	local now = os.clock()
	for uid, a in aims do
		if not a.on then
			continue
		end
		local player = Players:GetPlayerByUserId(uid)
		local tool = player and (Config.Tools :: any)[ToolService.current(player)]
		if not player or not tool or tool.kind ~= "vacuum" or now - a.t > 0.6 then
			-- (they let go, put it away, or stopped saying where they aim)
			a.on = false
			release(uid, false, a.dir)
			continue
		end
		local reach = (tool.range or RANGE) * M
		local cone = tool.cone or CONE
		local cap = tool.cap or CAP
		local nozzles = {}
		for _, x in tool.nozzles or { 0 } do
			table.insert(nozzles, a.origin + a.dir * 1.25 * M - Vector3.new(0, 0.18 * M, 0) + a.right * x * M)
		end
		local caughtN = 0
		for _, c in loose:GetChildren() do
			if c:IsA("BasePart") and c:GetAttribute("VacBy") == uid then
				caughtN += 1
			end
		end
		for _, c in loose:GetChildren() do
			if not c:IsA("BasePart") then
				continue
			end
			local b = c :: BasePart
			local by = b:GetAttribute("VacBy")
			if b.Anchored or b:GetAttribute("HeldBy") or (by ~= nil and by ~= uid) then
				continue
			end
			local to = b.Position - a.origin
			local nozzle = nozzles[1]
			for _, n in nozzles do
				if (b.Position - n).Magnitude < (b.Position - nozzle).Magnitude then
					nozzle = n
				end
			end
			local caught = by == uid
			if not caught then
				if to.Magnitude > reach or to.Magnitude < 0.01 or a.dir:Dot(to.Unit) < cone then
					continue
				end
				if (b.Position - nozzle).Magnitude < 0.7 * M and caughtN < cap then
					b:SetAttribute("VacBy", uid)
					b:SetAttribute("VacPhase", math.random() * 2 * math.pi)
					caughtN += 1
					caught = true
				end
			end
			pcall(function()
				b:SetNetworkOwner(nil)          -- (the server moves it now)
			end)
			if caught then
				local ph = b:GetAttribute("VacPhase") :: number? or 0
				local orbit = Vector3.new(math.cos(now * 5 + ph), math.sin(now * 7 + ph * 1.7) * 0.6, math.sin(now * 5 + ph)) * 0.22 * M
				b.AssemblyLinearVelocity = ((nozzle + orbit) - b.Position) * 10
				b.AssemblyAngularVelocity = b.AssemblyAngularVelocity:Lerp(Vector3.new(3, 5, 2), math.min(1, dt * 2))
			else
				local pull = nozzle - b.Position
				local speed = math.clamp(2 + (reach - pull.Magnitude) / M * 1.4, 2, 11) * M
				b.AssemblyLinearVelocity = b.AssemblyLinearVelocity:Lerp(pull.Unit * speed, math.min(1, dt * 6))
			end
		end
	end
end

function VacuumService.start()
	remotes.Vacuum.OnServerEvent:Connect(onVacuum)
	Players.PlayerRemoving:Connect(function(p)
		release(p.UserId, false, Vector3.zero)
		aims[p.UserId] = nil
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1 / 30)
			local now = os.clock()
			local ok, err = pcall(VacuumService.step, now - last)
			if not ok then
				warn("[Timber] vacuum: " .. tostring(err))
			end
			last = now
		end
	end)
end

return VacuumService
