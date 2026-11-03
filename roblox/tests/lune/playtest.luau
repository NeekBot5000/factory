-- The scripted playtest: a first session played through the real server scripts, then the ways players break games.
--   lune run tests/lune/playtest.luau <path to Timber.rbxl>
local process = require("@lune/process")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local Harness = require("./harness")

local place = process.args[1] or "Timber.rbxl"
local fails, passes = 0, 0
local function check(ok: boolean, msg: string)
	if ok then
		passes += 1
		print("PASS " .. msg)
	else
		fails += 1
		print("FAIL " .. msg)
	end
end
local V3 = roblox.Vector3.new

local A = Harness.boot(place, "server-A")
A.start()
local Data = A.service("DataService")
local Carry = A.service("CarryService")
task.wait(0.1)

-- ---------------------------------------------------------------- the world
local forest = A.workspace:FindFirstChild("Forest")
local trees = {}
for _, t in forest:GetChildren() do
	if t:HasTag("Tree") then
		table.insert(trees, t)
	end
end
check(#trees == 40, "the test world grows 40 trees (" .. #trees .. ")")
check(A.workspace:FindFirstChild("Truck") and A.workspace.Truck:FindFirstChild("Bed") ~= nil, "a log truck with a bed stands by the spawn")
check(A.workspace:FindFirstChild("TimberMart") ~= nil, "the TimberMart stall is there")
check(A.game:GetService("ReplicatedStorage"):FindFirstChild("ToolModels") ~= nil and #A.game:GetService("ReplicatedStorage").ToolModels:GetChildren() == 6, "every shop tool has a model for the shop's 3D preview")
-- how close is the first tree to the spawn? (the first swing should be seconds away)
local spawn = V3(0, 0, 14)
local nearest, nearestD = nil, math.huge
for _, t in trees do
	local d = (t.WorldPivot.Position - spawn).Magnitude
	if d < nearestD then
		nearest, nearestD = t, d
	end
end
check(nearestD < 45, string.format("a tree is a few steps from the spawn (%d studs)", nearestD))

-- ---------------------------------------------------------------- a new player
local alice = A.join(101, "Alice")
task.wait(0.6)
local data = Data.get(alice)
check(data ~= nil and data.money == 0 and data.owned.hands, "a new player starts with $0 and bare hands")
check(alice:FindFirstChild("leaderstats") and alice.leaderstats.Money.Value == 0, "their money shows in the player list")
task.wait(2.2)
local q = A.last(alice, "Quest")
check(q ~= nil and q.i == 1 and q.target == "tree", "the first goal points them at a tree")

-- peel: walk up to the nearest tree and swing five times with bare hands
local r = nearest:GetAttribute("Radius")
local base = nearest.WorldPivot.Position
A.stand(alice, base + V3(r + 3, 5, 0))
local strip = A.remotes.StripRequest.OnServerEvent
local loose = A.workspace:FindFirstChild("Loose")
for i = 1, 6 do
	strip:Fire(alice, nearest, base + V3(r, 3 + i * 1.2, 0), "hands")
	task.wait(0.36)
end
local sheets = loose:GetChildren()
check(#sheets >= 5, "bare-handed swings peel bark sheets (" .. #sheets .. ")")
local hum = alice.Character:FindFirstChildOfClass("Humanoid")
if nearest:GetAttribute("Species") ~= "hickory" then
	check((A.damage or 0) > 0 and hum.Health > 0, string.format("rough bark hurts bare hands a little (-%d hp)", A.damage or 0))
	local hinted = 0
	for _, e in A.clientLog do
		if e.remote == "Notify" and e.player == alice and string.find(tostring(e.args[1]), "hickory") then
			hinted += 1
		end
	end
	check(hinted == 1, "and the game says why, and what to do about it")
	for _ = 1, 30 do
		strip:Fire(alice, nearest, base + V3(r, 3, 0), "hands")
		task.wait(0.36)
	end
	check(hum.Health >= 30, string.format("but a minute of bare-handed peeling never knocks you out (%d hp left)", hum.Health))
	hinted = 0
	for _, e in A.clientLog do
		if e.remote == "Notify" and e.player == alice and string.find(tostring(e.args[1]), "hickory") then
			hinted += 1
		end
	end
	check(hinted == 1, "and the tip only shows once, not on every swing")
end
q = A.last(alice, "Quest")
check(q ~= nil and q.i == 2, "five peels finish the first goal; the next is carrying")

-- carry three sheets into the truck bed
local bed = A.workspace.Truck.Bed
local grab = A.remotes.Grab.OnServerEvent
for i = 1, 3 do
	local s = sheets[i]
	A.stand(alice, s.CFrame.Position + V3(2, 2, 0))
	grab:Fire(alice, s)
	task.wait(0.05)
	check(Carry.holding[alice] == s and s:FindFirstChild("Carry") ~= nil, "E picks up a sheet (" .. i .. ")")
	s.CFrame = bed.CFrame + V3(0, 2, -3 + i * 2)     -- (carried over to the truck)
	grab:Fire(alice, nil)
	task.wait(0.05)
end
check(Carry.holding[alice] == nil, "E again drops it")
q = A.last(alice, "Quest")
check(q ~= nil and q.i == 3, "three sheets dropped in the bed finish the carrying goal")

-- ship
local cab = A.workspace.Truck.Cab
local prompt = cab:FindFirstChildOfClass("ProximityPrompt")
local before = data.money
A.ProximityPromptService.PromptTriggered:Fire(prompt, alice)
task.wait(0.1)
local sold = A.last(alice, "Sold")
check(sold ~= nil and sold > 0 and data.money > before, string.format("shipping sells what's in the bed ($%.2f)", sold or 0))
check(alice.leaderstats.Money.Value == data.money, "the player list shows the new money")
local left = 0
for _, s in loose:GetChildren() do
	local lp = bed.CFrame:PointToObjectSpace(s.CFrame.Position)
	if math.abs(lp.X) < 4 and math.abs(lp.Z) < 6 and lp.Y > 0 then
		left += 1
	end
end
check(left == 0, "the truck bed is empty after shipping")
q = A.last(alice, "Quest")
check(q ~= nil and q.i == 4 and q.target == "shop", "shipping finishes its goal (and pays the $15 reward); next: the shop")
-- an empty ship says so instead of doing nothing
A.ProximityPromptService.PromptTriggered:Fire(prompt, alice)
task.wait(0.1)
local note = A.last(alice, "Notify")
check(type(note) == "string" and string.find(note, "empty") ~= nil, "shipping an empty truck tells you to load it first")

-- keep working until there's enough for a hatchet (peel, carry, ship)
local rounds = 0
local t2i = 1
while data.money < 30 and rounds < 40 do
	rounds += 1
	local t = trees[t2i]
	local tb = t.WorldPivot.Position
	local tr = t:GetAttribute("Radius")
	A.stand(alice, tb + V3(tr + 3, 5, 0))
	local n0 = #loose:GetChildren()
	for k = 1, 4 do
		strip:Fire(alice, t, tb + V3(tr, 2 + k * 1.5, 0), "hands")
		task.wait(0.36)
	end
	if #loose:GetChildren() == n0 then
		t2i += 1
	end
	for _, s in loose:GetChildren() do
		s.CFrame = bed.CFrame + V3(0, 2, 0)
	end
	A.ProximityPromptService.PromptTriggered:Fire(prompt, alice)
	task.wait(0.1)
end
check(data.money >= 30, string.format("a few minutes of bare-handed work earns a hatchet ($%.2f after %d trips)", data.money, rounds))

-- buy the hatchet
local buy = A.remotes.Buy.OnServerEvent
local m0 = data.money
buy:Fire(alice, "hatchet")
task.wait(0.1)
local hatchet = nil
for _, t in alice.Backpack:GetChildren() do
	if t:GetAttribute("ToolId") == "hatchet" then
		hatchet = t
	end
end
check(hatchet ~= nil and hatchet:IsA("Tool") and hatchet:FindFirstChild("Handle") ~= nil, "buying the hatchet puts a real Tool with a handle in the hotbar")
check(math.abs(data.money - (m0 - 30)) < 0.01 + 20, "it costs $30 (and the shop goal pays $20)")
local kept = false
for _, t in alice.StarterGear:GetChildren() do
	kept = kept or t:GetAttribute("ToolId") == "hatchet"
end
check(kept, "and it's kept when you respawn (StarterGear)")
q = A.last(alice, "Quest")
check(q ~= nil and q.i == 5, "buying it finishes the shop goal")

-- the hatchet peels more per swing than bare hands
local fresh = trees[#trees]
local fb = fresh.WorldPivot.Position
local fr = fresh:GetAttribute("Radius")
A.stand(alice, fb + V3(fr + 3, 5, 0))
local n1 = #loose:GetChildren()
strip:Fire(alice, fresh, fb + V3(fr, 6, 0), "hatchet")
task.wait(0.1)
local newest = loose:GetChildren()[#loose:GetChildren()]
check(#loose:GetChildren() > n1 and newest:GetAttribute("Value") > 0.6, string.format("a hatchet swing takes a bigger sheet ($%.2f)", newest:GetAttribute("Value") or 0))

-- ---------------------------------------------------------------- trying to cheat
local m1 = data.money
buy:Fire(alice, "greataxe")              -- can't afford
buy:Fire(alice, "flamethrower")          -- doesn't exist
buy:Fire(alice, 12345)                   -- nonsense
task.wait(0.1)
check(data.money == m1 and not data.owned.greataxe, "can't buy what you can't afford, what doesn't exist, or with junk arguments")
local nTrees = #loose:GetChildren()
task.wait(0.6)
strip:Fire(alice, fresh, fb + V3(fr, 8, 0), "greataxe")      -- not owned
strip:Fire(alice, fresh, fb + V3(200, 8, 0), "hatchet")      -- too far
strip:Fire(alice, A.workspace.Truck, fb, "hatchet")           -- not a tree
strip:Fire(alice, "tree", "here", "hatchet")                  -- junk
task.wait(0.1)
check(#loose:GetChildren() == nTrees, "swings with a tool you don't own, from too far, at a non-tree or with junk do nothing")
-- spam: the cooldown holds even if a client fires 20 swings at once
for _ = 1, 20 do
	strip:Fire(alice, fresh, fb + V3(fr, 10, 0), "hatchet")
end
task.wait(0.1)
check(#loose:GetChildren() - nTrees <= 1, "firing 20 swings at once only lands one (the cooldown is checked on the server)")
-- grabbing: something too far away, an anchored part, the truck
local far = loose:GetChildren()[1]
A.stand(alice, far.CFrame.Position + V3(100, 0, 0))
grab:Fire(alice, far)
grab:Fire(alice, bed)
task.wait(0.05)
check(Carry.holding[alice] == nil, "can't grab things out of reach, or the truck itself")
-- someone else's bark doesn't sell for you
local bob = A.join(202, "Bob")
task.wait(0.6)
for _, s in loose:GetChildren() do
	s.CFrame = bed.CFrame + V3(0, 2, 0)
end
local bobBefore = Data.get(bob).money
A.ProximityPromptService.PromptTriggered:Fire(prompt, bob)
task.wait(0.1)
check(Data.get(bob).money == bobBefore, "another player can't sell your bark")

-- ---------------------------------------------------------------- saving
local moneyAtLeave = data.money
A.leave(alice)
task.wait(0.2)
local saved = A.stores.Timber_v1 and A.stores.Timber_v1.p_101
check(saved ~= nil and math.abs(saved.money - moneyAtLeave) < 0.01 and saved.owned.hatchet and saved._lock == nil, "leaving saves money and tools, and releases the save")
check(saved ~= nil and saved.quest and saved.quest.i == 5, "and how far through the goals they got")

-- rejoin on another server: everything comes back
local B = Harness.boot(place, "server-B")
B.start()
local alice2 = B.join(101, "Alice")
task.wait(1.2)
local data2 = B.service("DataService").get(alice2)
check(data2 ~= nil and math.abs(data2.money - moneyAtLeave) < 0.01, "rejoining on another server brings the money back")
local back = false
for _, t in alice2.Backpack:GetChildren() do
	back = back or t:GetAttribute("ToolId") == "hatchet"
end
check(back, "and the hatchet is back in the hotbar")

-- session lock: while server B holds Alice's save, server C can't load it
local C = Harness.boot(place, "server-C")
C.start()
C.join(101, "Alice")
task.wait(0.6)
check(#C.kicked == 1, "joining a second server while the first still holds the save is refused (no duplicated items)")

-- ---------------------------------------------------------------- machines and oil
local Machines = B.service("MachineService")
local function machine(id, kind, attrs)
	local m = roblox.Instance.new("Model")
	m.Name = id
	m:SetAttribute("Id", id)
	m:SetAttribute("Kind", kind)
	for k, v in attrs or {} do
		m:SetAttribute(k, v)
	end
	m:AddTag("Machine")
	m.Parent = B.workspace
	return m
end
local crank = machine("c1", "crank", { Charge = 5 })
local lever = machine("l1", "lever", { On = false })
local lamp = machine("p1", "lamp")
table.insert(Machines.wires, { "c1", "l1" })
table.insert(Machines.wires, { "l1", "p1" })
task.wait(0.35)
check(crank:GetAttribute("Powered") == true and lamp:GetAttribute("Powered") ~= true, "a wound crank powers a lever, but an open lever stops it there")
lever:SetAttribute("On", true)
task.wait(0.35)
check(lamp:GetAttribute("Powered") == true, "flip the lever and the lamp lights")
check(crank:GetAttribute("Charge") < 5, "the crank runs down")

local OilField = require("../../src/shared/OilField")
local bx, bz, br = 0, 0, 0
for x = -2000, 2000, 40 do
	for z = -2000, 2000, 40 do
		local v = OilField.richness(x, z)
		if v > br then
			bx, bz, br = x, z, v
		end
	end
end
local pump = machine("o1", "oil_pump", { Powered = true, Fill = 0.995, Owner = 101 })
pump:AddTag("OilPump")
pump.WorldPivot = roblox.CFrame.new(bx, 0, bz)
local barrelsBefore = 0
for _, c in B.workspace.Loose:GetChildren() do
	if c:GetAttribute("Kind") == "oil_barrel" then
		barrelsBefore += 1
	end
end
-- the power solver would switch it off (no wires): keep it powered for the test
Machines.wires = {}
pump:RemoveTag("Machine")
task.wait(2.2)
local barrels = 0
for _, c in B.workspace.Loose:GetChildren() do
	if c:GetAttribute("Kind") == "oil_barrel" then
		barrels += 1
	end
end
check(barrels > barrelsBefore, string.format("a powered pump over an oil pocket (richness %.2f) fills a barrel", br))

print(string.format("\nPLAYTEST RESULT: %s (%d passed, %d failed)", if fails == 0 then "PASS" else "FAIL", passes, fails))
process.exit(if fails == 0 then 0 else 1)
