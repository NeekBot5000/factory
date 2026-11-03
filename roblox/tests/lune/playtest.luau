-- The scripted playtest: a first session played through the real server scripts, the Godot way (take the hatchet
-- from the block, peel, carry, ship, buy, drop and pick up a tool, faint), then the ways players break games.
--   lune run tests/lune/playtest.luau <path to Timber.rbxl>
local process = require("@lune/process")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local Harness = require("./harness")

local place = process.args[1] or "Timber.rbxl"
local fails, passes = 0, 0
local function check(ok: any, msg: string)
	if ok then
		passes += 1
		print("PASS " .. msg)
	else
		fails += 1
		print("FAIL " .. msg)
	end
end
local V3 = roblox.Vector3.new
local W = require("../../src/shared/GodotWorld")
local function wv(t)
	return V3(t[1], t[2], t[3])
end

local A = Harness.boot(place, "server-A")
A.start()
local Data = A.service("DataService")
local bob = nil
local Carry = A.service("CarryService")
task.wait(0.1)

local function count(name: string, player, pattern: string?): number
	local n = 0
	for _, e in A.clientLog do
		if e.remote == name and (e.player == player or e.all) and (not pattern or string.find(tostring(e.args[1]), pattern, 1, true)) then
			n += 1
		end
	end
	return n
end

-- ---------------------------------------------------------------- the world
local ws = A.workspace
local forest = ws:FindFirstChild("Forest")
local trees = {}
for _, t in forest:GetChildren() do
	if t:HasTag("Tree") then
		table.insert(trees, t)
	end
end
check(#trees == #W.trees and #trees > 200, "every tree of the Godot forest stands where it does in Godot (" .. #trees .. ")")
local placed = true
for k = 1, 5 do
	local t = W.trees[k]
	local found = false
	for _, tr in trees do
		if (tr.WorldPivot.Position - wv(t.at)).Magnitude < 0.01 and tr:GetAttribute("Bands") == t.bands then
			found = true
		end
	end
	placed = placed and found
end
check(placed, "with its Godot size (bands of bark) and place")
check(ws:FindFirstChild("Truck") and ws.Truck:FindFirstChild("Bed") and ws.Truck:GetAttribute("State") == "parked", "the log truck is parked by the spawn")
check((ws.Truck.WorldPivot.Position - wv(W.truck.at)).Magnitude < 0.01, "in Godot's parking spot beside the cabin")
check(ws:FindFirstChild("Solids") and #ws.Solids:GetChildren() == #W.solid, "the cabin walls, porch and rocks are solid where Godot's are (" .. #W.solid .. " boxes)")
local sp = ws:FindFirstChildOfClass("SpawnLocation")
check(sp and (sp.CFrame.Position - wv(W.spawn.at)).Magnitude < 1, "you start on the cabin porch, like in Godot")
check(ws:FindFirstChild("TimberMart") ~= nil and ws.TimberMart:FindFirstChild("Computer") ~= nil, "TimberMart is on the computer in the cabin")
local block = ws:FindFirstChild("ChoppingBlock")
check(block and block:FindFirstChild("Hatchet") ~= nil, "the chopping block has the hatchet stuck in it")
check(#A.game:GetService("ReplicatedStorage").ToolModels:GetChildren() == #require("../../src/shared/Config").ShopOrder - 1, "every shop tool has a model (first-person view, tool bar, shop)")
local prompts = 0
for _, d in ws:GetDescendants() do
	if d:IsA("ProximityPrompt") then
		prompts += 1
	end
end
check(prompts == 0, "no Roblox prompts: everything is 'look at it and press E', like Godot")
local spawn = wv(W.spawn.at)
local nearest, nearestD = nil, math.huge
for _, t in trees do
	local d = (t.WorldPivot.Position - spawn).Magnitude
	if d < nearestD and t:GetAttribute("Species") ~= "hickory" then
		nearest, nearestD = t, d
	end
end
check(nearestD < 60, string.format("a tree is a few steps from the spawn (%d studs)", nearestD))

-- ---------------------------------------------------------------- a new player
local alice = A.join(101, "Alice")
task.wait(0.6)
local data = Data.get(alice)
check(data ~= nil and data.money == 0 and data.owned.hands and not data.owned.hatchet, "a new player starts with $0 and bare hands")
check(alice:FindFirstChild("leaderstats") == nil, "no leaderstats, so no Roblox player list scoreboard")
check(alice:GetAttribute("Money") == 0 and alice:GetAttribute("Tool") == "hands", "the money counter and the hand read the player's attributes")
local tut = A.last(alice, "Tutorial")
check(tut and tut.i == 1 and string.find(tut.text, "chopping block", 1, true), "Getting started, step 1: take the hatchet from the chopping block")

-- E on the chopping block
local stump = block.Stump
A.stand(alice, stump.CFrame.Position + V3(0, 4, 4))
A.remotes.Use.OnServerEvent:Fire(alice, stump)
task.wait(0.1)
check(data.owned.hatchet and alice:GetAttribute("Tool") == "hatchet", "E on the block: the hatchet is yours and in your hand")
check(string.find(alice:GetAttribute("Owned"), "hatchet", 1, true), "and in your tool bar")
tut = A.last(alice, "Tutorial")
check(tut and tut.i == 2, "step 2: peel some bark")

-- bare hands: equip them (1), peel, and it hurts
local equip = A.remotes.Equip.OnServerEvent
equip:Fire(alice, "hands")
task.wait(0.05)
check(alice:GetAttribute("Tool") == "hands", "key 1: back to bare hands")
local r = nearest:GetAttribute("Radius")
local base = nearest.WorldPivot.Position
A.stand(alice, base + V3(r + 3, 5, 0))
local strip = A.remotes.StripRequest.OnServerEvent
local loose = ws:FindFirstChild("Loose")
local hum = alice.Character:FindFirstChildOfClass("Humanoid")
for i = 1, 7 do
	strip:Fire(alice, nearest, base + V3(r, 3 + i * 1.2, 0), "hands")
	task.wait(0.3)
end
local sheets = loose:GetChildren()
check(#sheets >= 6, "bare-handed swings peel bark sheets (" .. #sheets .. ")")
check(math.abs(hum.Health - (100 - 7 * 6)) < 0.01, string.format("rough bark hurts bare hands 6 a hit, like Godot's (%d health)", hum.Health))
tut = A.last(alice, "Tutorial")
check(tut and tut.i == 3, "step 3: carry it to the truck")

-- the tool has to be the one in your hand
local n0 = #loose:GetChildren()
task.wait(0.4)
strip:Fire(alice, nearest, base + V3(r, 12, 0), "hatchet")
task.wait(0.05)
check(#loose:GetChildren() == n0, "a swing with a tool that isn't in your hand does nothing")

-- carry three sheets into the truck bed
local bed = ws.Truck.Bed
local grab = A.remotes.Grab.OnServerEvent
for i = 1, 3 do
	local s = sheets[i]
	A.stand(alice, s.CFrame.Position + V3(2, 2, 0))
	grab:Fire(alice, s)
	task.wait(0.05)
	check(Carry.holding[alice] == s and s:FindFirstChild("Carry") ~= nil, "E picks up a sheet (" .. i .. ")")
	s.CFrame = bed.CFrame + V3(0, 1.5, -3 + i * 2)
	grab:Fire(alice, nil)
	task.wait(0.05)
end
check(Carry.holding[alice] == nil, "E again drops it")
task.wait(1.2)
tut = A.last(alice, "Tutorial")
check(tut and tut.i == 4, "bark in the back finishes step 3; step 4: send the truck")
local Economy = A.service("EconomyService")
local load = Economy.bedValue(alice)
check(load > 0, string.format("the truck knows what its load is worth ($%.2f, its sign and the '[E] ship' hint)", load))

-- E on the truck: horn, off it goes, paid when it gets to the mill, back it comes
local before = data.money
A.stand(alice, bed.CFrame.Position + V3(6, 3, 0))
A.remotes.Use.OnServerEvent:Fire(alice, ws.Truck.Cab)
task.wait(0.05)
check(ws.Truck:GetAttribute("State") == "leaving", "E on the truck: it drives off")
check(count("Fx", nil, "horn") >= 1, "with a blast of its horn, for everyone nearby")
check(data.money == before, "you're not paid yet: only when it gets to the mill")
local cargoOnTruck = 0
for _, d in ws.Truck:GetDescendants() do
	if d:IsA("BasePart") and d.Anchored and d:GetAttribute("Owner") == 101 then
		cargoOnTruck += 1
	end
end
check(cargoOnTruck >= 3, "the bark rides away in the back")
A.remotes.Use.OnServerEvent:Fire(alice, ws.Truck.Cab)
local waited = 0
while ws.Truck:GetAttribute("State") ~= "parked" and waited < 60 do
	task.wait(0.25)
	waited += 0.25
end
local sold = A.last(alice, "Sold")
check(sold and math.abs(sold - load) < 0.02 and math.abs(data.money - (before + load)) < 0.02, string.format("paid at the mill: +$%.2f", sold or 0))
check(ws.Truck:GetAttribute("State") == "parked" and (ws.Truck.WorldPivot.Position - wv(W.truck.at)).Magnitude < 0.01, "and the truck comes back and parks in its spot")
check(alice:GetAttribute("Money") == data.money, "the money counter has the new total")
tut = A.last(alice, "Tutorial")
check(tut and tut.i == 5 and string.find(tut.text, "/ $160", 1, true), "step 5: save up for the Double-Bit Axe (with the count)")

-- (skip the grind) then buy it at TimberMart
data.money = 200
task.wait(0.5)
tut = A.last(alice, "Tutorial")
check(tut and tut.i == 6, "with $160, step 6: buy it at TimberMart")
local buy = A.remotes.Buy.OnServerEvent
buy:Fire(alice, "double_bit")
task.wait(0.3)
check(not data.owned.double_bit and math.abs(data.money - 40) < 0.01 and string.find(alice:GetAttribute("Ordered") or "", "double_bit", 1, true),
	"bought: $160 off, and it's on order (like Godot, it comes by van)")
check(count("Notify", alice, "Ordered Double-Bit Axe") == 1, "'Ordered Double-Bit Axe'")
tut = A.last(alice, "Tutorial")
check(tut and tut.i == 7 and string.find(tut.text, "delivery van", 1, true), "step 7: the van brings it")
buy:Fire(alice, "double_bit")
task.wait(0.1)
check(math.abs(data.money - 40) < 0.01, "ordering it again while it's on its way does nothing")
-- the van comes, backs onto the dock (beeping) and drops a box
local box = nil
for _ = 1, 240 do
	for _, c in loose:GetChildren() do
		if c:GetAttribute("Kind") == "box" and c:GetAttribute("Owner") == 101 then
			box = c
		end
	end
	if box then
		break
	end
	task.wait(0.1)
end
check(box ~= nil and box:GetAttribute("Item") == "double_bit", "the van drops a TimberMart box with the axe in it at the dock")
check(count("Fx", nil, "click") >= 1, "it beeps as it backs up")
local dock = W.van_dock[#W.van_dock]
check(box and (box.CFrame.Position - wv(dock)).Magnitude < 20, "right by the loading dock")
if box then
	-- someone else can't open it
	A.stand(bob or A.join(303, "Carol"), box.CFrame.Position + V3(0, 3, 2))
	A.stand(alice, box.CFrame.Position + V3(0, 3, 3))
	A.remotes.Open.OnServerEvent:Fire(alice, box)
	task.wait(1.5)
	check(box.Parent == nil, "click: the box opens and folds away")
	local pickup = nil
	for _, c in loose:GetChildren() do
		if c:GetAttribute("Kind") == "pickup" and c:GetAttribute("Owner") == 101 then
			pickup = c
		end
	end
	check(pickup ~= nil and count("Fx", nil, "rip") >= 1 and count("Fx", nil, "reveal") >= 1, "the tape rips and the axe rises out of it, glowing")
	if pickup then
		local part = pickup:FindFirstChildWhichIsA("BasePart", true)
		A.remotes.Use.OnServerEvent:Fire(alice, part)
		task.wait(0.6)
	end
end
check(data.owned.double_bit and alice:GetAttribute("Tool") == "double_bit", "E takes it: it's yours, in your hand")
check(count("Notify", alice, "Double-Bit Axe  [4]") == 1, "with Godot's toast: its name and its key")
check(data.tutorial == -1 and count("Notify", alice, "basics") == 1, "Getting started is done (and says so once)")
for _, o in data.orders do
	check(o.status == "delivered", "and the order is marked delivered")
end

-- the double-bit hits twice a swing
local fresh = trees[#trees]
local fb = fresh.WorldPivot.Position
local fr = fresh:GetAttribute("Radius")
A.stand(alice, fb + V3(fr + 3, 5, 0))
local n1 = #loose:GetChildren()
strip:Fire(alice, fresh, fb + V3(fr, 6, 0), "double_bit")
task.wait(0.43)
strip:Fire(alice, fresh, fb + V3(fr, 9, 0), "double_bit")
task.wait(0.05)
check(#loose:GetChildren() - n1 == 2, "the double-bit's forehand and backhand both land")

-- Q: put it down; E: pick it up
A.remotes.DropTool.OnServerEvent:Fire(alice)
task.wait(0.05)
local item = loose:FindFirstChild("Tool_double_bit")
check(item and item:GetAttribute("Kind") == "tool" and alice:GetAttribute("Tool") == "hands", "Q: the axe goes down on the ground as a real object")
check(alice:GetAttribute("Dropped") == "double_bit", "and leaves the tool bar")
equip:Fire(alice, "double_bit")
task.wait(0.05)
check(alice:GetAttribute("Tool") == "hands", "you can't take it out of the bar while it's on the ground")
bob = A.join(202, "Bob")
task.wait(0.6)
A.stand(bob, item.Handle.CFrame.Position + V3(0, 3, 2))
A.remotes.Use.OnServerEvent:Fire(bob, item.Handle)
task.wait(0.05)
check(item.Parent ~= nil and not Data.get(bob).owned.double_bit, "someone else can't walk off with it")
A.stand(alice, item.Handle.CFrame.Position + V3(0, 3, 2))
A.remotes.Use.OnServerEvent:Fire(alice, item.Handle)
task.wait(0.05)
check(item.Parent == nil and alice:GetAttribute("Tool") == "double_bit" and alice:GetAttribute("Dropped") == "", "E on it: back in your hand and your tool bar")

-- ---------------------------------------------------------------- Godot's other axes
local Tools = A.service("ToolService")
local Cfg = require("../../src/shared/Config")
local function freshTree(k)
	local t = trees[#trees - k]
	return t, t.WorldPivot.Position, t:GetAttribute("Radius")
end
local function bark(t)
	local Grid = require("../../src/shared/BarkGrid")
	return Grid.decode(t:GetAttribute("Sectors"), t:GetAttribute("Bands"), t:GetAttribute("Bark") or "")
end
local function hitWith(id, t, at)
	Tools.grant(alice, id)
	task.wait(1.3)
	local n0 = #loose:GetChildren()
	strip:Fire(alice, t, at, id)
	task.wait(0.1)
	local made = {}
	for k = n0 + 1, #loose:GetChildren() do
		table.insert(made, loose:GetChildren()[k])
	end
	return made
end
do
	local G = require("../../src/shared/BarkGrid")
	-- the ringing axe: a whole ring of bark, all the way round
	local t, b, rr = freshTree(1)
	A.stand(alice, b + V3(rr + 3, 5, 0))
	local made = hitWith("ringer", t, b + V3(rr, 6, 0))
	local g = bark(t)
	local band = math.floor(6 / 0.54)
	local gone = 0
	for i = 0, 15 do
		if g and not G.has(g, 0, i, band) then
			gone += 1
		end
	end
	check(#made == 1 and gone == 16, "the ringing axe takes a whole ring of bark, all the way round (" .. gone .. " of 16)")
	-- the robo-axe: a 3x3 patch through both layers
	t, b, rr = freshTree(2)
	A.stand(alice, b + V3(rr + 3, 5, 0))
	made = hitWith("robo", t, b + V3(rr, 6, 0))
	local layers = {}
	for _, m in made do
		layers[m:GetAttribute("Layer")] = (layers[m:GetAttribute("Layer")] or 0) + 1
	end
	check(#made == 2 and layers[0] == 1 and layers[1] == 1, "the robo-axe punches through both layers in one hit (outer and inner sheets)")
	-- the gouge: only inner bark, so on fresh bark it says so
	t, b, rr = freshTree(3)
	A.stand(alice, b + V3(rr + 3, 5, 0))
	made = hitWith("gouge", t, b + V3(rr, 6, 0))
	check(#made == 0 and count("Notify", alice, "gouge only cuts inner bark") == 1, "the gouge can't bite outer bark, and says to take that off first")
	-- the spud: sheets worth half as much again
	t, b, rr = freshTree(4)
	A.stand(alice, b + V3(rr + 3, 5, 0))
	made = hitWith("spud", t, b + V3(rr, 6, 0))
	local spudSheet = made[1]
	local Econ = require("../../src/shared/Economy")
	local plain = spudSheet and Econ.barkValue(Cfg, t:GetAttribute("Species"), 0, #spudSheet:GetChildren() // 2 + 1)
	check(spudSheet and math.abs(spudSheet:GetAttribute("Value") - plain * 1.5) < 0.02, string.format("the spud's sheets sell for 50%% more ($%.2f)", spudSheet and spudSheet:GetAttribute("Value") or 0))
	-- the spiral axe: each hit carries the stripe on up and round
	t, b, rr = freshTree(5)
	A.stand(alice, b + V3(rr + 3, 5, 0))
	local first = hitWith("spiral", t, b + V3(rr, 4, 0))
	task.wait(0.5)
	local n1 = #loose:GetChildren()
	strip:Fire(alice, t, b + V3(rr, 4, 0), "spiral")
	task.wait(0.1)
	check(#first >= 1 and #loose:GetChildren() > n1, "the spiral axe takes a slanted stripe, and the next hit carries it on")
	-- the combo axe: each hit in a row is bigger
	t, b, rr = freshTree(6)
	A.stand(alice, b + V3(rr + 3, 5, 0))
	local sizes = {}
	Tools.grant(alice, "combo")
	task.wait(1.3)
	for k = 1, 4 do
		local n0 = #loose:GetChildren()
		strip:Fire(alice, t, b + V3(rr, 2 + k * 2.4, 0), "combo")
		task.wait(0.45)
		local panels = 0
		for q = n0 + 1, #loose:GetChildren() do
			panels += #loose:GetChildren()[q]:GetChildren() // 2 + 1
		end
		sizes[k] = panels
	end
	check(sizes[4] > sizes[1], string.format("the combo axe's hits grow as the rhythm goes on (%d -> %d panels)", sizes[1], sizes[4]))
	Tools.equip(alice, "double_bit")
end

-- ---------------------------------------------------------------- felling and logs (Godot's saws)
do
	local saw = A.remotes.Sawn.OnServerEvent
	local start = A.remotes.SawStart.OnServerEvent
	local t, b, rr = freshTree(8)
	local bands0 = t:GetAttribute("Bands")
	A.stand(alice, b + V3(rr + 3, 5, 0))
	Tools.grant(alice, "saw")
	task.wait(0.1)
	start:Fire(alice, t.Trunk)
	task.wait(0.3)
	saw:Fire(alice, t.Trunk, b + V3(rr, 2, 0))
	task.wait(0.1)
	check(not t:GetAttribute("Felled"), "a cut that's too quick doesn't fell anything (the server times the saw)")
	local need = A.service("LogService").sawTime(t, Cfg.Tools.saw)
	start:Fire(alice, t.Trunk)
	task.wait(need * 0.85)
	saw:Fire(alice, t.Trunk, b + V3(rr, 2, 0))
	task.wait(0.1)
	local logs = ws:FindFirstChild("Logs")
	local log = logs and logs:GetChildren()[1]
	check(t:GetAttribute("Felled") and log ~= nil, string.format("hold the bow saw on it for %.1f s: the tree is felled", need))
	local cutJ = t:GetAttribute("Bands")
	check(cutJ == math.floor(2 / 0.54) and log and log:GetAttribute("Bands") == bands0 - cutJ, "leaving a stump; the rest of the trunk is the log")
	check(count("Fx", nil, "timber") >= 1, "with Godot's 'timber' crash")
	if log then
		local L = log:GetAttribute("Bands") * 0.18
		local v = A.service("LogService").value(log)
		check(math.abs(v - 60 * L * (log:GetAttribute("Radius") / 3 / 0.4) ^ 2 * 0.15) < 0.05, string.format("a log in all its bark is worth 15%% of clean timber ($%.2f)", v))
		check(log:HasTag("Tree") and log:GetAttribute("Bark") ~= nil, "and it keeps its bark, so axes can still peel it")
		-- the buck saw: the whole log into rounds
		Tools.grant(alice, "bucksaw")
		task.wait(0.1)
		local at = log:GetPivot().Position
		A.stand(alice, at + V3(0, 4, 3))
		start:Fire(alice, log.Trunk)
		task.wait(A.service("LogService").sawTime(log, Cfg.Tools.bucksaw) * 0.85)
		saw:Fire(alice, log.Trunk, at)
		task.wait(0.1)
		local rounds = logs:GetChildren()
		local short = true
		for _, r in rounds do
			short = short and r:GetAttribute("Bands") <= 9
		end
		check(#rounds >= 3 and short, "the buck saw cuts the whole log into carryable rounds (" .. #rounds .. ")")
		-- carry a round into the truck and ship it: the shipper's paid
		local round = rounds[1]
		local trunk = round.Trunk
		A.stand(alice, trunk.CFrame.Position + V3(0, 3, 3))
		grab:Fire(alice, trunk)
		task.wait(0.05)
		check(Carry.holding[alice] == trunk, "E picks up a round (3 m or shorter)")
		grab:Fire(alice, nil)
		task.wait(0.05)
		local worthIt = A.service("LogService").value(round)
		trunk.CFrame = ws.Truck.Bed.CFrame
		local m0 = data.money
		A.stand(alice, ws.Truck.Bed.CFrame.Position + V3(6, 3, 0))
		A.remotes.Use.OnServerEvent:Fire(alice, ws.Truck.Cab)
		local waited = 0
		task.wait(0.2)
		while ws.Truck:GetAttribute("State") ~= "parked" and waited < 60 do
			task.wait(0.25)
			waited += 0.25
		end
		check(math.abs(data.money - (m0 + worthIt)) < 0.02, string.format("the truck takes logs too: +$%.2f at the mill", worthIt))
	end
	-- the buck saw can't fell a standing tree; the giants need a chainsaw
	local t2, b2, r2 = freshTree(9)
	A.stand(alice, b2 + V3(r2 + 3, 5, 0))
	start:Fire(alice, t2.Trunk)
	task.wait(4)
	saw:Fire(alice, t2.Trunk, b2 + V3(r2, 2, 0))
	task.wait(0.1)
	check(not t2:GetAttribute("Felled"), "the buck saw can't fell a standing tree")
	Tools.equip(alice, "double_bit")
end

-- ---------------------------------------------------------------- the bark drills
do
	-- the hole saw bites through both layers at once; the twin auger bores two tracks side by side
	local t, b, rr = freshTree(16)
	A.stand(alice, b + V3(rr + 3, 5, 0))
	local made = hitWith("holesaw", t, b + V3(rr, 6, 0))
	local layers = {}
	for _, m in made do
		layers[m:GetAttribute("Layer")] = true
	end
	check(layers[0] and layers[1], "the hole saw takes outer and inner bark together")
	t, b, rr = freshTree(17)
	A.stand(alice, b + V3(rr + 3, 5, 0))
	made = hitWith("twin_auger", t, b + V3(rr, 6, 0))
	local G = require("../../src/shared/BarkGrid")
	local g = bark(t)
	local cols = {}
	for i = 0, 15 do
		for j = 0, t:GetAttribute("Bands") - 1 do
			if g and not G.has(g, 0, i, j) then
				cols[i] = true
			end
		end
	end
	local n = 0
	for _ in cols do
		n += 1
	end
	check(#made >= 1 and n >= 3, string.format("the twin auger bores two tracks at once (%d columns of panels)", n))
	-- the timber auger, held: a bite every 0.2 s
	t, b, rr = freshTree(18)
	A.stand(alice, b + V3(rr + 3, 5, 0))
	Tools.grant(alice, "drill")
	task.wait(1.3)
	local n0 = #loose:GetChildren()
	for k = 0, 4 do
		strip:Fire(alice, t, b + V3(rr, 3 + k * 0.6, 0), "drill")
		task.wait(0.2)
	end
	check(#loose:GetChildren() - n0 >= 5, "the timber auger strips bark continuously while it's held (" .. (#loose:GetChildren() - n0) .. " bites)")
end

-- ---------------------------------------------------------------- the shears
do
	local t, b, rr = freshTree(19)
	Tools.grant(alice, "shears")
	task.wait(1.3)
	A.stand(alice, b + V3(rr + 6, 5, 0))
	-- (the Godot crown meshes don't load in Lune: a crown part named the way they are)
	local crowns = ws:FindFirstChild("GodotCrowns") or roblox.Instance.new("Model")
	crowns.Name = "GodotCrowns"
	crowns.Parent = ws
	local c = roblox.Instance.new("Part")
	c.Size = V3(6, 4, 6)
	c.CFrame = roblox.CFrame.new(b + V3(0, t:GetAttribute("Height") + 1, 0))
	c.Position = c.CFrame.Position
	c:SetAttribute("GodotName", "crown_" .. tostring(t:GetAttribute("Index")))
	c.Parent = crowns
	for _, s in t:GetChildren() do
		if s.Name == "Crown" then
			s:Destroy()
		end
	end
	local at = c.CFrame.Position + V3(2, 0, 0)
	local snip = A.remotes.Snip.OnServerEvent
	local function leaves()
		local n = 0
		for _, x in loose:GetChildren() do
			if x:GetAttribute("Kind") == "leaf" then
				n += 1
			end
		end
		return n
	end
	local l0, s0 = leaves(), c.Size.X
	snip:Fire(alice, t, at)
	task.wait(0.1)
	check(leaves() - l0 >= 2 and leaves() - l0 <= 3 and c.Size.X < s0, "a snip tears 2 or 3 clumps of leaves off and the crown shrinks")
	snip:Fire(alice, t, at)
	task.wait(0.05)
	check(leaves() - l0 <= 3, "the shears snip once per click (Godot's 0.32 s)")
	for _ = 1, 20 do
		task.wait(0.3)
		snip:Fire(alice, t, at)
	end
	task.wait(0.1)
	local saps = 0
	for _, x in loose:GetChildren() do
		if x:GetAttribute("Kind") == "sapling" and (x.Position - at).Magnitude < 6 then
			saps += 1
		end
	end
	check(c.Parent == nil and t:GetAttribute("CrownCut") and saps >= 1, "snipped bare, the last clump holds a sapling or two (" .. saps .. ")")
end

-- ---------------------------------------------------------------- the crosscut, the throwing hatchet, the phone
do
	local saw = A.remotes.Sawn.OnServerEvent
	local start = A.remotes.SawStart.OnServerEvent
	-- an ancient giant: too thick for the bow saw, but the crosscut gets through (and its clean cut pays 20% more)
	local giant = nil
	for _, t in trees do
		if t:GetAttribute("Giant") and not t:GetAttribute("Legendary") then
			giant = t
		end
	end
	if giant then
		local gb, gr = giant.WorldPivot.Position, giant:GetAttribute("Radius")
		A.stand(alice, gb + V3(gr + 3, 5, 0))
		Tools.grant(alice, "saw")
		task.wait(0.1)
		start:Fire(alice, giant.Trunk)
		task.wait(A.service("LogService").sawTime(giant, Cfg.Tools.saw) * 0.9)
		saw:Fire(alice, giant.Trunk, gb + V3(gr, 2, 0))
		task.wait(0.1)
		check(not giant:GetAttribute("Felled"), "an ancient tree is too thick for the bow saw")
		Tools.grant(alice, "crosscut")
		task.wait(0.1)
		start:Fire(alice, giant.Trunk)
		task.wait(A.service("LogService").sawTime(giant, Cfg.Tools.crosscut) * 0.85)
		saw:Fire(alice, giant.Trunk, gb + V3(gr, 2, 0))
		task.wait(0.1)
		local glog = nil
		for _, l in ws.Logs:GetChildren() do
			if l:GetAttribute("Clean") then
				glog = l
			end
		end
		check(giant:GetAttribute("Felled") and glog ~= nil, "the two-man crosscut fells it, with a clean cut")
		if glog then
			local LS = A.service("LogService")
			local v = LS.value(glog)
			glog:SetAttribute("Clean", nil)
			local plain = LS.value(glog)
			check(math.abs(v - plain * 1.2) < 0.05, string.format("a clean-cut log is worth 20%% more ($%.2f vs $%.2f)", v, plain))
		end
	end
	-- the throwing hatchet bites bark from across the clearing (up to 12 m)
	local t, b, rr = freshTree(12)
	Tools.grant(alice, "throwing")
	task.wait(1.3)
	A.stand(alice, b + V3(rr + 30, 5, 0))
	local n0 = #loose:GetChildren()
	strip:Fire(alice, t, b + V3(rr, 6, 0), "throwing")
	task.wait(0.1)
	check(#loose:GetChildren() > n0, "the throwing hatchet takes bark from 10 m away")
	-- the Thunder Axe, charged: lightning takes every sheet off the whole tree, then it needs 6 s to recharge
	do
		local tt, tb, tr = freshTree(13)
		Tools.grant(alice, "thunder")
		task.wait(1.3)
		A.stand(alice, tb + V3(tr + 4, 5, 0))
		local fx0 = count("Fx", nil, "lightning")
		strip:Fire(alice, tt, tb + V3(tr, 6, 0), "thunder", true)
		task.wait(0.1)
		local G = require("../../src/shared/BarkGrid")
		local g = bark(tt)
		check(g ~= nil and G.count(g, 0) == 0 and G.count(g, 1) == 0 and count("Fx", nil, "lightning") == fx0 + 1,
			"the charged Thunder Axe strips the whole tree in one strike, with lightning")
		local t3, b3, r3 = freshTree(14)
		A.stand(alice, b3 + V3(r3 + 4, 5, 0))
		task.wait(0.7)
		strip:Fire(alice, t3, b3 + V3(r3, 6, 0), "thunder", true)
		task.wait(0.1)
		check(count("Fx", nil, "lightning") == fx0 + 1, "and it can't strike again until it has recharged")
	end
	-- the pole saw: held up in the leaves for 1.8 s, the crown comes off; the leaves rain down, with a sapling or two
	do
		local pt, pb, pr = freshTree(15)
		Tools.grant(alice, "pole_saw")
		task.wait(1.3)
		A.stand(alice, pb + V3(pr + 6, 5, 0))
		local top = pb + V3(pr, pt:GetAttribute("Height") - 3, 0)
		-- (the Godot crown meshes don't load in Lune: give this tree a crown part named the way they are)
		if not pt:FindFirstChild("Crown") then
			local crowns = ws:FindFirstChild("GodotCrowns") or roblox.Instance.new("Model")
			crowns.Name = "GodotCrowns"
			crowns.Parent = ws
			local c = roblox.Instance.new("Part")
			c.Size = V3(9, 6, 9)
			c.CFrame = roblox.CFrame.new(pb + V3(0, pt:GetAttribute("Height") + 2, 0))
			c.Position = c.CFrame.Position
			c.Color = roblox.Color3.fromHex("4f9a3c")
			c:SetAttribute("GodotName", "crown_" .. tostring(pt:GetAttribute("Index")))
			c.Parent = crowns
		end
		local start = A.remotes.SawStart.OnServerEvent
		local sawn = A.remotes.Sawn.OnServerEvent
		start:Fire(alice, pt.Trunk)
		task.wait(0.5)
		sawn:Fire(alice, pt.Trunk, top)
		task.wait(0.1)
		check(not pt:GetAttribute("CrownCut"), "the pole saw needs Godot's 1.8 s in the leaves")
		local before = {}
		for _, c in loose:GetChildren() do
			if c:GetAttribute("Kind") == "sapling" then
				before[c:GetAttribute("Id") or c:GetFullName() .. tostring(c.Position)] = true
			end
		end
		start:Fire(alice, pt.Trunk)
		task.wait(Cfg.Saw.crownTime * 0.85)
		sawn:Fire(alice, pt.Trunk, top)
		task.wait(0.1)
		local nLeaves, nSaplings, sap = 0, 0, nil
		for _, c in loose:GetChildren() do
			if c:GetAttribute("Kind") == "leaf" and c:GetAttribute("Owner") == 101 and c:GetAttribute("Value") == 0.05 then
				nLeaves += 1
			elseif c:GetAttribute("Kind") == "sapling" and not before[c:GetAttribute("Id") or c:GetFullName() .. tostring(c.Position)] then
				nSaplings += 1
				sap = c
			end
		end
		check(pt:GetAttribute("CrownCut") and #A.service("LogService").crownParts(pt) == 0, "the crown comes off the standing tree")
		check(nLeaves >= 4, string.format("its leaves come down as clumps worth $0.05 each (%d)", nLeaves))
		check(nSaplings >= 1 and nSaplings <= 2 and sap:GetAttribute("Species") == pt:GetAttribute("Species"),
			string.format("with a sapling or two of the tree's kind (%d)", nSaplings))
		if sap then
			-- put down on open ground and left there, it roots, then grows into a full tree
			local WS = A.service("WorldService")
			local x, z = pb.X + 20, pb.Z + 20
			sap.CFrame = roblox.CFrame.new(x, WS.heightAt(x, z) + 0.2, z)
			sap.Position = sap.CFrame.Position
			task.wait(Cfg.Sapling.rest + 0.8)
			check(sap:GetAttribute("Rooted") and sap.Anchored, "a sapling left on the ground takes root")
			local before = #ws.Forest:GetChildren()
			sap:SetAttribute("Grow", Cfg.Sapling.growTime - 0.1)
			task.wait(0.8)
			local grown = nil
			for _, t in ws.Forest:GetChildren() do
				if t:GetAttribute("Grown") then
					grown = t
				end
			end
			check(sap.Parent == nil and grown ~= nil and #ws.Forest:GetChildren() == before + 1 and grown:GetAttribute("Species") == pt:GetAttribute("Species"),
				"and after five minutes it's a full-size tree of its kind")
		end
	end
	-- the phone: bought like anything else, it never goes in your hand, and it sends the truck off from anywhere
	data.money += 400
	A.remotes.Buy.OnServerEvent:Fire(alice, "phone")
	local pbox = nil
	for _ = 1, 240 do
		for _, c in loose:GetChildren() do
			if c:GetAttribute("Kind") == "box" and c:GetAttribute("Item") == "phone" then
				pbox = c
			end
		end
		if pbox then
			break
		end
		task.wait(0.1)
	end
	if pbox then
		A.stand(alice, pbox.CFrame.Position + V3(0, 3, 3))
		A.remotes.Open.OnServerEvent:Fire(alice, pbox)
		task.wait(1.5)
		for _, c in loose:GetChildren() do
			if c:GetAttribute("Kind") == "pickup" and c:GetAttribute("Item") == "phone" then
				A.remotes.Use.OnServerEvent:Fire(alice, c:FindFirstChildWhichIsA("BasePart", true))
			end
		end
		task.wait(0.3)
	end
	local toolBefore = alice:GetAttribute("Tool")
	check(data.owned.phone and alice:GetAttribute("Tool") == toolBefore and count("Notify", alice, "TimberPhone  [Tab]") == 1, "the TimberPhone arrives by van: 'TimberPhone  [Tab]', and it's not a tool")
	-- bark in the truck, and the phone sends it off from far away
	local sheet = nil
	for _, c in loose:GetChildren() do
		if c:GetAttribute("Kind") == "bark" and c:GetAttribute("Owner") == 101 then
			sheet = c
		end
	end
	if sheet then
		sheet.CFrame = ws.Truck.Bed.CFrame
		A.stand(alice, V3(300, 10, 300))
		A.remotes.PhoneShip.OnServerEvent:Fire(alice)
		task.wait(0.1)
		check(ws.Truck:GetAttribute("State") ~= "parked", "the phone sends the truck to the mill from anywhere")
		local w2 = 0
		while ws.Truck:GetAttribute("State") ~= "parked" and w2 < 60 do
			task.wait(0.25)
			w2 += 0.25
		end
	end
	Tools.equip(alice, "double_bit")
end

-- ---------------------------------------------------------------- trying to cheat
local m1 = data.money
buy:Fire(alice, "greataxe")
buy:Fire(alice, "flamethrower")
buy:Fire(alice, 12345)
buy:Fire(alice, "hands")
task.wait(0.1)
check(data.money == m1 and not data.owned.greataxe, "can't buy what you can't afford, what doesn't exist, or with junk")
equip:Fire(alice, "labrys")
equip:Fire(alice, 42)
task.wait(0.05)
check(alice:GetAttribute("Tool") == "double_bit", "can't take out a tool you don't own")
local nT = #loose:GetChildren()
task.wait(1.1)
strip:Fire(alice, fresh, fb + V3(200, 8, 0), "double_bit")
strip:Fire(alice, ws.Truck, fb, "double_bit")
strip:Fire(alice, "tree", "here", "double_bit")
task.wait(0.05)
check(#loose:GetChildren() == nT, "swings from too far, at a non-tree or with junk do nothing")
task.wait(1.1)
for _ = 1, 20 do
	strip:Fire(alice, fresh, fb + V3(fr, 10, 0), "double_bit")
end
task.wait(0.1)
check(#loose:GetChildren() - nT <= 1, "20 swings fired at once land once (the server keeps the tool's pace)")
local far = loose:GetChildren()[1]
A.stand(alice, far.CFrame.Position + V3(100, 0, 0))
grab:Fire(alice, far)
grab:Fire(alice, bed)
task.wait(0.05)
check(Carry.holding[alice] == nil, "can't grab things out of reach, or the truck itself")
A.remotes.Use.OnServerEvent:Fire(alice, stump)
A.remotes.Use.OnServerEvent:Fire(alice, "truck")
task.wait(0.05)
check(ws.Truck:GetAttribute("State") == "parked", "can't use things from across the map")

-- fainting: bare hands at a rough tree until health runs out (Godot: you faint and wake at the start)
equip:Fire(alice, "hands")
task.wait(0.05)
A.stand(alice, base + V3(r + 3, 5, 0))
local hum2 = alice.Character:FindFirstChildOfClass("Humanoid")
for _ = 1, 30 do
	if hum2.Health <= 0 then
		break
	end
	strip:Fire(alice, nearest, base + V3(r, 4, 0), "hands")
	task.wait(0.3)
end
check(hum2.Health <= 0, "keep peeling bare-handed and you faint (no safety floor, like Godot)")
local nF = #loose:GetChildren()
strip:Fire(alice, nearest, base + V3(r, 5, 0), "hands")
task.wait(0.05)
check(#loose:GetChildren() == nF, "and while fainted you can't peel")

-- ---------------------------------------------------------------- the title screen's New Game and Settings
do
	local bd = Data.get(bob)
	bd.money = 50
	bd.owned.hatchet = true
	A.remotes.Settings.OnServerEvent:Fire(bob, { fov = 200, volume = 0.3, music = "loud", bob = false, junk = 1 })
	task.wait(0.05)
	bd = Data.get(bob)
	check(bd.settings.fov == 100 and bd.settings.volume == 0.3 and bd.settings.music == 0.5 and bd.settings.bob == false and bd.settings.junk == nil,
		"Settings are saved, kept in range, and junk is ignored")
	check(bob:GetAttribute("Fresh") == false, "someone who's played has something to Continue")
	A.remotes.NewGame.OnServerEvent:Fire(bob)
	task.wait(0.1)
	bd = Data.get(bob)
	check(bd.money == 0 and not bd.owned.hatchet and bd.tutorial == 1 and bd.settings.volume == 0.3, "New Game starts their save over (keeping their settings)")
	check(bob:GetAttribute("Fresh") == true and bob:GetAttribute("Tool") == "hands", "bare-handed, back at Getting started")
end

-- ---------------------------------------------------------------- saving
local moneyAtLeave = data.money
A.leave(alice)
task.wait(0.2)
local saved = A.stores.Timber_v1 and A.stores.Timber_v1.p_101
check(saved and math.abs(saved.money - moneyAtLeave) < 0.01 and saved.owned.hatchet and saved.owned.double_bit and saved._lock == nil, "leaving saves money and tools, and releases the save")
check(saved and saved.tutorial == -1, "and that Getting started is finished")

local B = Harness.boot(place, "server-B")
B.start()
local alice2 = B.join(101, "Alice")
task.wait(1.2)
local data2 = B.service("DataService").get(alice2)
check(data2 and math.abs(data2.money - moneyAtLeave) < 0.01, "rejoining on another server brings the money back")
check(string.find(alice2:GetAttribute("Owned") or "", "double_bit", 1, true) and alice2:GetAttribute("Dropped") == "", "and the tool bar")
check(B.last(alice2, "Tutorial") == nil, "and no Getting started panel again")

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
Machines.wires = {}
pump:RemoveTag("Machine")
task.wait(2.2)
local barrels = 0
for _, c in B.workspace.Loose:GetChildren() do
	if c:GetAttribute("Kind") == "oil_barrel" then
		barrels += 1
	end
end
check(barrels > 0, string.format("a powered pump over an oil pocket (richness %.2f) fills a barrel", br))

print(string.format("\nPLAYTEST RESULT: %s (%d passed, %d failed)", if fails == 0 then "PASS" else "FAIL", passes, fails))
process.exit(if fails == 0 then 0 else 1)
