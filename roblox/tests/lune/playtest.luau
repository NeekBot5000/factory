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
-- (the wood of the day pays more at the mill; it depends on the date, so the tests pin it: no bonus, except where
-- a test checks the bonus itself)
local woodOfTheDay = A.service("EconomyService").woodOfTheDay
A.service("EconomyService").woodOfTheDay = function()
	return "none"
end
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
do
	local Cfg0 = require("../../src/shared/Config")
	local tools = 0
	for _, id in Cfg0.ShopOrder do
		if Cfg0.Tools[id] then
			tools += 1
		end
	end
	check(#A.game:GetService("ReplicatedStorage").ToolModels:GetChildren() == tools, "every shop tool has a model (first-person view, tool bar, shop)")
end
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
-- what Roblox's analytics heard: every Getting started step in order, money in from the mill, out at the shop
do
	local steps, inOrder = 0, true
	local mill, shop = false, false
	for _, e in A.analytics do
		if e.player == alice and e.kind == "onboarding" then
			steps += 1
			inOrder = inOrder and e.step == steps
		elseif e.player == alice and e.kind == "economy" then
			mill = mill or (e.sku == "mill" and e.amount > 0 and string.find(e.flow, "Source", 1, true) ~= nil)
			shop = shop or (e.sku == "double_bit" and string.find(e.flow, "Sink", 1, true) ~= nil and e.balance == data.money)
		end
	end
	local total = #require("../../src/shared/Config").Tutorial
	check(steps == total and inOrder, string.format("Roblox's onboarding funnel hears each Getting started step in order (%d of %d)", steps, total))
	check(mill and shop, "and its economy charts hear money in from the mill and out at the shop")
end
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
	-- the golden tree event: its outer bark is gold, and worth 5x
	do
		local ES = A.service("EventService")
		local tg, bg, rg = freshTree(10)
		A.stand(alice, bg + V3(rg + 3, 5, 0))
		local plain = hitWith("hatchet", tg, bg + V3(rg, 6, 0))
		local plainValue = plain[1] and plain[1]:GetAttribute("Value") / (plain[1]:GetAttribute("Panels") or 1) or 0
		ES.startGolden(tg)
		local gold = hitWith("hatchet", tg, bg + V3(rg, 9, 0))
		local goldValue = gold[1] and gold[1]:GetAttribute("Value") / (gold[1]:GetAttribute("Panels") or 1) or 0
		check(tg:GetAttribute("Golden") == true and math.abs(goldValue / math.max(plainValue, 0.001) - 5) < 0.3,
			string.format("a golden tree's bark is worth 5x a panel ($%.2f against $%.2f)", goldValue, plainValue))
		local RS = A.game:GetService("ReplicatedStorage")
		check(typeof(RS:GetAttribute("GoldenWhere")) == "string" and typeof(RS:GetAttribute("GoldenNext")) == "number",
			"the phone can say where the golden tree is, and when the next one comes")
		ES.endGolden()
		check(tg:GetAttribute("Golden") == nil and RS:GetAttribute("GoldenWhere") == nil, "and when the event ends it's an ordinary tree again")
		-- felling it: the whole server hears who got it
		local tg2 = freshTree(11)
		ES.startGolden(tg2)
		local heard0 = count("Notify", alice, "felled the golden tree")
		local goldLog = A.service("LogService").fell(tg2, 2, V3(1, 0, 0), alice)
		check(count("Notify", alice, "felled the golden tree") == heard0 + 1, "felling the golden tree: the whole server hears who got it")
		ES.endGolden()
		if goldLog then
			goldLog:Destroy()          -- (out of the way of the saw checks further on)
		end
	end
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
	-- the pressure washer: each burst of the jet flakes off the 3 panels nearest where it lands
	t, b, rr = freshTree(20)
	A.stand(alice, b + V3(rr + 10, 5, 0))
	made = hitWith("washer", t, b + V3(rr, 6, 0))
	local panels = 0
	for _, m in made do
		for _, x in m:GetDescendants() do
			if x:IsA("BasePart") and x.CanQuery ~= false then
				panels += 1
			end
		end
		panels += 1
	end
	check(#made >= 1 and panels <= 3, "the pressure washer flakes off a soft little patch from 3 m away (" .. panels .. " panels)")
	-- the planer: logs only, a strip the whole length of the log in one sheet
	t, b, rr = freshTree(21)
	A.stand(alice, b + V3(rr + 2, 5, 0))
	made = hitWith("planer", t, b + V3(rr, 6, 0))
	check(#made == 0, "the planer does nothing to a standing tree")
	local log = nil
	for _, l in ws.Logs:GetChildren() do
		if l:GetAttribute("Kind") == "log" and l:FindFirstChild("Trunk") then
			log = l
		end
	end
	if log then
		local trunk = log.Trunk
		local lp = log:GetPivot()
		local hitAt = lp:PointToWorldSpace(V3(log:GetAttribute("Radius"), 1.5, 0))
		A.stand(alice, hitAt + V3(0, 4, 0))
		made = hitWith("planer", log, hitAt)
		local n = 0
		if made[1] then
			for _, x in made[1]:GetDescendants() do
				if x:IsA("BasePart") and x.CanQuery ~= false then
					n += 1
				end
			end
			n += 1
		end
		check(#made == 1 and n >= 3, "on a log it planes one long sheet down its length (" .. n .. " panels)")
	end
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

-- ---------------------------------------------------------------- the company sign
do
	local sign = ws:FindFirstChild("CompanySign")
	local SS = A.service("SignService")
	local function width()
		local w = 0
		for _, p in sign:GetDescendants() do
			if p:IsA("BasePart") then
				w = math.max(w, p.Size.X)
			end
		end
		return w
	end
	check(sign ~= nil and #sign:GetChildren() >= 2, "the company sign stands by the road: a scrap of board on a stake")
	check(SS.tierFor(0) == 0 and SS.tierFor(499) == 0 and SS.tierFor(500) == 1 and SS.tierFor(10000) == 3 and SS.tierFor(250000) == 5, "Godot's tiers: 500, 2,500, 10,000, 50,000, 200,000 earned")
	local w0 = width()
	local before = count("Notify", nil, "company sign got an upgrade")
	local saved = data.earned
	data.earned = 3000
	SS.step()
	check(width() > w0 and count("Notify", nil, "company sign got an upgrade") == before + 1, "earn more and it grows, with Godot's toast")
	data.earned = saved
end

-- ---------------------------------------------------------------- building with the hammer, and land
do
	local build = A.remotes.Build.OnServerEvent
	Tools.grant(alice, "hammer")
	task.wait(1.3)
	local spot = V3(-24, 0, 24)          -- (on the four plots round the cabin that everyone starts with)
	A.stand(alice, spot + V3(0, 5, 9))
	local plans = function()
		local f = ws:FindFirstChild("Plans")
		return if f then f:GetChildren() else {}
	end
	local n0 = #plans()
	build:Fire(alice, "crank", roblox.CFrame.new(spot), 1)
	A.stand(alice, V3(-24, 5, 52))
	build:Fire(alice, "bench", roblox.CFrame.new(V3(-24, 0, 66)), 1)       -- (just over the edge of your land)
	task.wait(0.1)
	A.stand(alice, spot + V3(0, 5, 9))
	check(#plans() == n0 and count("Notify", alice, "isn't your land") >= 1, "machines need their blueprint, and you can only build on your own land")
	build:Fire(alice, "bench", roblox.CFrame.new(spot), 1)
	task.wait(0.1)
	local plan = nil
	for _, p in plans() do
		if p:GetAttribute("Build") == "bench" then
			plan = p
		end
	end
	check(plan ~= nil and plan:GetAttribute("Left") == "1 log  ·  6 bark", "the hammer sets down a plan: a hologram that says what it still needs ('" .. tostring(plan and plan:GetAttribute("Left")) .. "')")
	if plan then
		local function sheet(panels)
			local p = roblox.Instance.new("Part")
			p.Size = V3(1, 1, 0.3)
			p.CFrame = plan:GetPivot() * roblox.CFrame.new(0, 2, 0)
			p.Position = p.CFrame.Position
			p.Color = roblox.Color3.fromHex("6b4a32")
			p:SetAttribute("Kind", "bark")
			p:SetAttribute("Panels", panels)
			p:SetAttribute("Value", 0.4)
			p:SetAttribute("Owner", 101)
			p.Parent = loose
			return p
		end
		local s1 = sheet(3)
		task.wait(0.4)
		local solid = 0
		for _, p in plan:GetChildren() do
			if p:IsA("BasePart") and p:GetAttribute("Res") == "bark" and p.Transparency == 0 then
				solid += 1
			end
		end
		check(s1.Parent ~= loose and plan:GetAttribute("Left") == "1 log  ·  3 bark" and solid >= 1, "drop bark in: it goes into the build and parts turn solid in proportion (" .. solid .. ")")
		sheet(4)
		local log = nil
		for _, l in ws.Logs:GetChildren() do
			if l:GetAttribute("Kind") == "log" and not l:GetAttribute("HeldBy") then
				log = l
			end
		end
		if log then
			local target = (plan:GetPivot() * roblox.CFrame.new(0, 2, 0)).Position
			log:PivotTo(log:GetPivot() + (target - log.Trunk.CFrame.Position))
			for _, d in log:GetDescendants() do
				if d:IsA("BasePart") then
					d.Position = d.CFrame.Position
				end
			end
		end
		task.wait(0.5)
		local built = nil
		for _, b in (ws:FindFirstChild("Builds") and ws.Builds:GetChildren() or {}) do
			if b:GetAttribute("Build") == "bench" then
				built = b
			end
		end
		check(plan.Parent == nil and built ~= nil and count("Notify", alice, "Log Bench") >= 1, "with everything in, it's built: the Log Bench (Godot's toast)")
		if built then
			check((built:GetAttribute("SaleValue") or 0) > 0, string.format("a bench is worth 2.5x what went into it ($%.2f)", built:GetAttribute("SaleValue") or 0))
			local before, value = data.money, built:GetAttribute("SaleValue")
			A.remotes.TakeDown.OnServerEvent:Fire(alice, built:FindFirstChildWhichIsA("BasePart"))
			task.wait(0.1)
			local gone = not pcall(function()
				return built.Parent.Name
			end)
			check(gone and math.abs(data.money - before - value) < 0.01, "X with the hammer takes it down and pays what it would have sold for")
		end
	end
	-- what finished builds do: the campfire burns what's dropped on it, the compost turns 8 leaves into a sapling
	do
		local BS = A.service("BuildService")
		local fire = BS.make("campfire", roblox.CFrame.new(spot + V3(0, 0, -12)), 1, 101, true, {})
		A.service("BuildBehaviors").activate(fire)
		local light = fire:FindFirstChild("FireLight")
		check(fire:FindFirstChild("Flames") ~= nil and light and light:FindFirstChildOfClass("PointLight") ~= nil, "a campfire burns with flames and a warm light")
		local leafy = roblox.Instance.new("Part")
		leafy.Size = V3(0.5, 0.5, 0.5)
		leafy.CFrame = fire:GetPivot() * roblox.CFrame.new(0, 1.3, 0)
		leafy.Position = leafy.CFrame.Position
		leafy:SetAttribute("Kind", "leaf")
		leafy.Parent = loose
		task.wait(0.5)
		check(leafy.Parent ~= nil and leafy:GetAttribute("Burning"), "leaves dropped on it start to burn")
		task.wait(1.4)
		check(not pcall(function() return leafy.Parent.Name end), "and burn away (Godot's 0.9 s for leaves)")
		local pile = BS.make("compost", roblox.CFrame.new(spot + V3(12, 0, -12)), 1, 101, true, {})
		A.service("BuildBehaviors").activate(pile)
		for k = 1, 8 do
			local l = roblox.Instance.new("Part")
			l.Size = V3(0.5, 0.5, 0.5)
			l.CFrame = pile:GetPivot() * roblox.CFrame.new(0, 1.5, 0)
			l.Position = l.CFrame.Position
			l:SetAttribute("Kind", "leaf")
			l.Parent = loose
		end
		task.wait(0.4)
		check(pile:GetAttribute("Stock") == 8, "the compost pile takes the leaves (8/8)")
		local saps0 = 0
		for _, c in loose:GetChildren() do
			if c:GetAttribute("Kind") == "sapling" then
				saps0 += 1
			end
		end
		pile:SetAttribute("Rot", 7.9)
		task.wait(0.4)
		local saps = 0
		for _, c in loose:GetChildren() do
			if c:GetAttribute("Kind") == "sapling" then
				saps += 1
			end
		end
		check(saps == saps0 + 1 and pile:GetAttribute("Stock") == 0, "and 8 s later a sapling pops out of the top")
		local hoopB = BS.make("ball", roblox.CFrame.new(spot + V3(-12, 0, -12)), 1, 101, true, {})
		hoopB:SetAttribute("SaleValue", 4)
		A.service("BuildBehaviors").activate(hoopB)
		local ball = nil
		for _, c in loose:GetChildren() do
			if c:GetAttribute("Kind") == "ball" then
				ball = c
			end
		end
		check(ball ~= nil and ball.Shape.Name == "Ball" and ball:GetAttribute("Value") == 4, "a finished leaf ball is a real ball you can pick up (and sell)")
	end
	-- your builds and plans are saved with you, and come back
	do
		local BS = A.service("BuildService")
		local b = BS.make("rack", roblox.CFrame.new(spot + V3(-12, 0, 12)), 1.5, 101, true, { ["0"] = "123456" })
		b:SetAttribute("SaleValue", 7.5)
		local pl = BS.make("bench", roblox.CFrame.new(spot + V3(12, 0, 12)), 1, 101)
		pl:SetAttribute("Have", '{"bark":3}')
		pl:SetAttribute("Filled", '{"2":"8a5a36"}')
		local saved = BS.serialize(101)
		local n = 0
		for _, e in saved do
			if (e.id == "rack" and e.kind == "build" and e.size == 1.5) or (e.id == "bench" and e.kind == "plan") then
				n += 1
			end
		end
		b:Destroy()
		pl:Destroy()
		BS.restore(alice, saved)
		local back, plan2 = nil, nil
		for _, m in ws.Builds:GetChildren() do
			if m:GetAttribute("Build") == "rack" then
				back = m
			end
		end
		for _, m in ws.Plans:GetChildren() do
			if m:GetAttribute("Build") == "bench" and m:GetAttribute("Have") == '{"bark":3}' then
				plan2 = m
			end
		end
		check(n == 2 and back ~= nil and back:GetAttribute("SaleValue") == 7.5 and plan2 ~= nil and plan2:GetAttribute("Left") == "1 log  ·  3 bark",
			"your builds and half-filled plans are saved with you and come back as they were")
		if plan2 then
			plan2:Destroy()
		end
	end
	-- a cancelled plan gives everything back
	build:Fire(alice, "basket", roblox.CFrame.new(spot + V3(9, 0, 0)), 1)
	task.wait(0.1)
	local basket = nil
	for _, p in plans() do
		if p:GetAttribute("Build") == "basket" then
			basket = p
		end
	end
	if basket then
		local p = roblox.Instance.new("Part")
		p.Size = V3(1, 1, 0.3)
		p.CFrame = basket:GetPivot() * roblox.CFrame.new(0, 1.5, 0)
		p.Position = p.CFrame.Position
		p:SetAttribute("Kind", "bark")
		p:SetAttribute("Panels", 5)
		p:SetAttribute("Owner", 101)
		p.Parent = loose
		task.wait(0.4)
		local inside = p.Parent ~= loose
		A.remotes.PlanCancel.OnServerEvent:Fire(alice, basket:FindFirstChildWhichIsA("BasePart"))
		task.wait(0.1)
		local gone = not pcall(function()
			return basket.Parent.Name
		end)
		check(inside and gone and p.Parent == loose, "E on a plan cancels it, and what went in tumbles back out")
	end
	-- land: buy the plot next to yours at its for-sale sign
	data.money += 500
	local m0 = data.money
	A.stand(alice, V3(100, 5, 30))
	A.remotes.BuyLand.OnServerEvent:Fire(alice, "1,0", V3(108, 0, 30))
	task.wait(0.1)
	check(table.find(data.land, "1,0") ~= nil and math.abs(m0 - data.money - 400) < 0.01, "a for-sale sign sells you the next plot ($400, then 1.7x more each)")
	A.stand(alice, V3(5 * 60 + 30, 5, 5 * 60 + 25))
	A.remotes.BuyLand.OnServerEvent:Fire(alice, "5,5", V3(5 * 60 + 30, 0, 5 * 60 + 30))
	task.wait(0.1)
	check(table.find(data.land, "5,5") == nil, "but only plots next to land you own")
end

-- ---------------------------------------------------------------- the rake, the blower, the watering can
do
	local function thing(at, kind)
		local p = roblox.Instance.new("Part")
		p.Size = V3(0.6, 0.6, 0.6)
		p.CFrame = roblox.CFrame.new(at)
		p.Position = at
		p.AssemblyLinearVelocity = V3(0, 0, 0)
		p:SetAttribute("Kind", kind)
		p.Parent = loose
		return p
	end
	Tools.grant(alice, "rake")
	task.wait(1.3)
	local root = alice.Character.HumanoidRootPart
	local here = V3(-40, 5, 40)
	A.stand(alice, here)
	root.CFrame = roblox.CFrame.new(root.CFrame.Position)        -- (facing -Z; Lune's own lookAt is reversed)
	local feet = root.CFrame.Position - V3(0, 2.5, 0)
	local leaf = thing(feet + V3(0, 1, -5.7), "leaf")
	A.remotes.Rake.OnServerEvent:Fire(alice)
	task.wait(0.1)
	check(leaf.AssemblyLinearVelocity.Z > 3, string.format("the rake drags what's in front of you a step closer (%.1f)", leaf.AssemblyLinearVelocity.Z))
	leaf:Destroy()
	-- the blower: blown away from you, light things far
	Tools.grant(alice, "blower")
	task.wait(1.3)
	local eye = root.CFrame.Position + V3(0, 1.5, 0)
	local light = thing(eye + V3(0, 0, -9), "leaf")
	local heavy = thing(eye + V3(1, 0, -9), "ore")
	heavy.Size = V3(1.5, 1.5, 1.5)          -- (a big stone: 2 kg)
	A.remotes.Vacuum.OnServerEvent:Fire(alice, true, eye, V3(0, 0, -1), V3(1, 0, 0))
	task.wait(0.3)
	A.remotes.Vacuum.OnServerEvent:Fire(alice, false)
	check(light.AssemblyLinearVelocity.Z < -1 and math.abs(light.AssemblyLinearVelocity.Z) > math.abs(heavy.AssemblyLinearVelocity.Z) * 1.5,
		string.format("the leaf blower blows things away, leaves much further than stone (%.1f vs %.1f)", light.AssemblyLinearVelocity.Z, heavy.AssemblyLinearVelocity.Z))
	light:Destroy()
	heavy:Destroy()
	-- the watering can: a rooted sapling grows twice as fast for a minute
	Tools.grant(alice, "can")
	task.wait(1.3)
	local sp = thing(feet + V3(0, 0.3, -3), "sapling")
	A.remotes.Water.OnServerEvent:Fire(alice, sp)
	task.wait(0.1)
	check(sp:GetAttribute("Boost") == nil and count("Notify", alice, "take root first") >= 1, "a sapling has to take root before watering helps")
	task.wait(1.1)
	sp:SetAttribute("Rooted", true)
	sp.Anchored = true
	sp:SetAttribute("Grow", 0)
	A.remotes.Water.OnServerEvent:Fire(alice, sp)
	task.wait(1.0)
	local g = sp:GetAttribute("Grow") or 0
	check(sp:GetAttribute("Boost") and sp:GetAttribute("Boost") > 55 and g > 1.2, string.format("watered, it grows twice as fast (%.1f s of growth in 1 s)", g))
	sp:Destroy()
end

-- ---------------------------------------------------------------- bushes and trophies
do
	Tools.grant(alice, "shears")
	task.wait(1.3)
	local bush = ws.Bushes:FindFirstChild("Bush_0")
	check(bush ~= nil and #ws.Bushes:GetChildren() > 5, "every bush is its own (" .. #ws.Bushes:GetChildren() .. ")")
	if bush then
		A.stand(alice, bush.CFrame.Position + V3(5, 3, 0))
		local snip = A.remotes.Snip.OnServerEvent
		local before = #loose:GetChildren()
		snip:Fire(alice, bush, bush.CFrame.Position + V3(2, 0, 0))
		task.wait(0.1)
		check(#loose:GetChildren() - before >= 2, "shears on a bush tear 2 or 3 clumps of leaves off it")
		for _ = 1, 5 do
			task.wait(0.3)
			snip:Fire(alice, bush, bush.CFrame.Position + V3(2, 0, 0))
		end
		task.wait(0.1)
		check(not pcall(function() return bush.Parent.Name end), "and after 6 snips it's trimmed away")
	end
	-- trophies: felling a tree earns "your first tree felled"
	check(string.find(alice:GetAttribute("Trophies") or "", "first_tree", 1, true) ~= nil and count("Notify", alice, "Trophy: your first tree felled") == 1,
		"felling your first tree puts a trophy on your wall (Godot's toast)")
end

-- ---------------------------------------------------------------- mining
do
	local mine = A.remotes.Mine.OnServerEvent
	local MS = A.service("MiningService")
	local WS = A.service("WorldService")
	Tools.grant(alice, "pickaxe")
	task.wait(1.3)
	-- (Lune has no terrain: a bit of ground to dig in)
	local spot = V3(-30, 0, -30)
	local g = roblox.Instance.new("Part")
	g.Anchored = true
	g.Size = V3(12, 1, 12)
	g.CFrame = roblox.CFrame.new(spot.X, WS.heightAt(spot.X, spot.Z) - 0.5, spot.Z)
	g.Position = g.CFrame.Position
	g:SetAttribute("Ground", true)
	g.Parent = ws
	A.stand(alice, spot + V3(0, 5, 4))
	local function ores()
		local n = 0
		for _, c in loose:GetChildren() do
			if c:GetAttribute("Kind") == "ore" then
				n += 1
			end
		end
		return n
	end
	local o0 = ores()
	for _ = 1, 3 do
		mine:Fire(alice, g, spot, V3(0, 1, 0))
		task.wait(0.55)
	end
	local shaft = ws:FindFirstChild("Shafts") and ws.Shafts:FindFirstChild("Shaft")
	check(shaft ~= nil and math.abs((shaft:GetAttribute("Depth") or 0) - 0.6) < 0.01 and ores() == o0 + 3, "a pickaxe digs a shaft straight down, 0.2 m a hit, throwing out a chunk each time")
	local chunk = nil
	for _, c in loose:GetChildren() do
		if c:GetAttribute("Kind") == "ore" then
			chunk = c
		end
	end
	check(chunk and chunk:GetAttribute("Ore") == "stone" and chunk:GetAttribute("Value") > 0.2, "near the top it's stone (worth about $0.40)")
	-- deep down, where Godot's ground is rich in iron, a steel pick gets iron out
	local Mining = A.shared("Mining")
	local best, bx, bz = -1, 0, 0
	for x = -150, 150, 9 do
		for z = -150, 150, 9 do
			local r = Mining.richness("iron", x, z)
			if r > best then
				best, bx, bz = r, x, z
			end
		end
	end
	local seen = {}
	for _ = 1, 60 do
		seen[Mining.roll(bx, bz, 12, 2)] = true
	end
	check(best > 0.5 and seen.iron and Mining.roll(bx, bz, 0.5, 2) == "stone", string.format("iron lies deep, in Godot's rich patches (best %.2f)", best))
	local onlyStone = true
	for _ = 1, 60 do
		onlyStone = onlyStone and Mining.roll(bx, bz, 12, 1) ~= "iron"
	end
	check(onlyStone, "and an ordinary pickaxe can't get iron out")
	-- a rock: chunks come off until it crumbles away; a sledgehammer bursts a small one in one blow
	local r0 = MS.rock(0)
	local idx = 0
	for i = 0, 60 do
		local r = MS.rock(i)
		if r and r.s > 0.85 then
			idx = i
			r0 = r
			break
		end
	end
	if r0 then
		A.stand(alice, r0.at + V3(4, 4, 0))
		local box = ws.Solids:FindFirstChild("Rock_" .. idx)
		local hits = 0
		while MS.rock(idx) and hits < 20 do
			mine:Fire(alice, box, r0.at + V3(2, 0, 0), V3(1, 0, 0))
			hits += 1
			task.wait(0.55)
		end
		check(MS.rock(idx) == nil and ws.Solids:FindFirstChild("Rock_" .. idx) == nil and hits == r0.max, string.format("a pickaxe knocks chunks off a rock until it crumbles away (%d hits)", hits))
	end
	Tools.grant(alice, "sledge")
	task.wait(1.3)
	local small, si = nil, 0
	for i = 0, 60 do
		local r = MS.rock(i)
		if r and r.s <= 0.8 then
			small, si = r, i
			break
		end
	end
	if small then
		A.stand(alice, small.at + V3(4, 4, 0))
		local before = ores()
		mine:Fire(alice, ws.Solids:FindFirstChild("Rock_" .. si), small.at + V3(2, 0, 0), V3(1, 0, 0))
		task.wait(0.1)
		check(MS.rock(si) == nil and ores() - before >= 2, "a sledgehammer bursts a small rock in one blow, every chunk flying out")
	end
end

-- ---------------------------------------------------------------- machines and power
do
	local BS, CS = A.service("BuildService"), A.service("CircuitService")
	local base = V3(-30, 0, 30)
	local function mk(id, off)
		local m = BS.make(id, roblox.CFrame.new(base + off), 1, 101, true, {})
		A.service("BuildBehaviors").activate(m)
		return m
	end
	local crank, lever, lamp = mk("crank", V3(0, 0, 0)), mk("lever", V3(6, 0, 0)), mk("lamp", V3(12, 0, 0))
	check(CS.toggle(crank, lever) == "added" and CS.toggle(lever, lamp) == "added", "wires run between machines")
	CS.use(crank)
	task.wait(0.2)
	check(crank:GetAttribute("Charge") > 14 and not lamp:GetAttribute("Powered"), "a wound crank gives power, but a lever that's off stops it")
	CS.use(lever)
	task.wait(0.2)
	local light = lamp:FindFirstChild("LampLight")
	check(lamp:GetAttribute("Powered") and light and light:FindFirstChildOfClass("PointLight").Brightness > 2, "switch the lever on and the lamp lights")
	-- a battery charges while its network has power, and powers it itself once the crank runs down
	local bat = mk("battery", V3(18, 0, 0))
	CS.toggle(lamp, bat)
	task.wait(1.0)
	local c = bat:GetAttribute("Charge") or 0
	check(c > 0.5, string.format("a battery charges while the network has power (%.1f s)", c))
	crank:SetAttribute("Charge", 0)
	task.wait(0.3)
	check(bat:GetAttribute("Feeding") and lamp:GetAttribute("Powered"), "and powers it itself when nothing else does")
	-- a generator burns bark, leaves and wood from its hopper
	local gen = mk("generator", V3(0, 0, 9))
	local leafy = roblox.Instance.new("Part")
	leafy.Size = V3(0.5, 0.5, 0.5)
	leafy.CFrame = gen:GetPivot() * roblox.CFrame.new(0.3, 3.15, -0.15)
	leafy.Position = leafy.CFrame.Position
	leafy:SetAttribute("Kind", "leaf")
	leafy.Parent = loose
	task.wait(0.3)
	check((gen:GetAttribute("Fuel") or 0) > 0.5 and not pcall(function() return leafy.Parent.Name end), "a generator burns what's dropped in its hopper (a leaf: 1 s of fuel)")
	-- the Wire Spool
	Tools.grant(alice, "wires")
	task.wait(1.3)
	A.stand(alice, base + V3(3, 5, 5))
	local w0 = #ws.Wires:GetChildren()
	A.remotes.Wire.OnServerEvent:Fire(alice, gen:FindFirstChildWhichIsA("BasePart"), crank:FindFirstChildWhichIsA("BasePart"))
	task.wait(0.1)
	check(#ws.Wires:GetChildren() == w0 + 1, "the Wire Spool runs a wire from one machine to another")
	-- machines and their wires are saved with you
	local saved = BS.serialize(101)
	local nw = 0
	for _, e in saved do
		if e.kind == "wire" then
			nw += 1
		end
	end
	check(nw == #ws.Wires:GetChildren(), "and the wires are saved with your machines (" .. nw .. ")")
end

-- ---------------------------------------------------------------- logic blocks
do
	local BS, CS = A.service("BuildService"), A.service("CircuitService")
	local base = V3(30, 0, -45)
	local function mk(id, off)
		local m = BS.make(id, roblox.CFrame.new(base + off), 1, 101, true, {})
		A.service("BuildBehaviors").activate(m)
		return m
	end
	-- a one-way block: power in the back (+Z: behind it), out the front (-Z)
	local crank, diode, lamp = mk("crank", V3(0, 0, 6)), mk("gate_diode", V3(0, 0, 0)), mk("lamp", V3(0, 0, -6))
	CS.toggle(crank, diode)
	CS.toggle(diode, lamp)
	CS.use(crank)
	task.wait(0.3)
	check(CS.sideOf(diode, crank) == "back" and CS.sideOf(diode, lamp) == "front" and lamp:GetAttribute("Powered"), "a one-way block passes power from its back out of its front")
	local crank2, lamp2 = mk("crank", V3(12, 0, -6)), mk("lamp", V3(12, 0, 6))
	local d2 = mk("gate_diode", V3(12, 0, 0))
	CS.toggle(crank2, d2)
	CS.toggle(d2, lamp2)
	CS.use(crank2)
	task.wait(0.3)
	check(not lamp2:GetAttribute("Powered"), "but not the other way")
	-- a relay: back -> front only while a side is powered
	local c3, relay, l3, side = mk("crank", V3(24, 0, 6)), mk("gate_and", V3(24, 0, 0)), mk("lamp", V3(24, 0, -6)), mk("crank", V3(30, 0, 0))
	CS.toggle(c3, relay)
	CS.toggle(relay, l3)
	CS.toggle(side, relay)
	CS.use(c3)
	task.wait(0.3)
	local before = l3:GetAttribute("Powered")
	CS.use(side)
	task.wait(0.3)
	check(not before and l3:GetAttribute("Powered"), "a relay passes power only while its side is powered")
end

-- ---------------------------------------------------------------- logistics, the tree farm, wireless
do
	local BS, CS = A.service("BuildService"), A.service("CircuitService")
	local base = V3(60, 0, -45)
	local crank = BS.make("crank", roblox.CFrame.new(base + V3(0, 0, 12)), 1, 101, true, {})
	for _ = 1, 8 do
		CS.use(crank)
	end
	local function mk(id, off)
		local m = BS.make(id, roblox.CFrame.new(base + off), 1, 101, true, {})
		A.service("BuildBehaviors").activate(m)
		CS.toggle(crank, m)
		return m
	end
	-- wireless: a powered transmitter powers every receiver on its channel
	local tx = mk("transmitter", V3(6, 0, 12))
	local rx = BS.make("receiver", roblox.CFrame.new(base + V3(40, 0, 12)), 1, 101, true, {})
	local lamp = BS.make("lamp", roblox.CFrame.new(base + V3(46, 0, 12)), 1, 101, true, {})
	CS.toggle(rx, lamp)
	task.wait(0.3)
	check(lamp:GetAttribute("Powered"), "a receiver on the transmitter's channel powers its lamp, no wire between")
	CS.use(rx)
	task.wait(0.3)
	check(not lamp:GetAttribute("Powered"), "on another channel it doesn't")
	-- the crate empties itself out of the front while powered
	local crate = mk("crate", V3(0, 0, 0))
	local thing = roblox.Instance.new("Part")
	thing.Size = V3(0.6, 0.6, 0.6)
	thing.CFrame = crate:GetPivot() * roblox.CFrame.new(0, 1.5, 0)
	thing.Position = thing.CFrame.Position
	thing.AssemblyLinearVelocity = V3(0, 0, 0)
	thing:SetAttribute("Kind", "leaf")
	thing.Parent = loose
	task.wait(0.3)
	check(thing.AssemblyLinearVelocity.Z < -5, "a powered crate pushes what's in it out of the front")
	thing:Destroy()
	-- the planter plants a sapling from its hopper in front of it
	local planter = mk("planter", V3(12, 0, 0))
	local sp = A.service("LogService").sapling((planter:GetPivot() * roblox.CFrame.new(0, 2.85, 0)).Position, "oak")
	sp.Position = sp.CFrame.Position
	task.wait(0.4)
	check(sp:GetAttribute("Rooted") and (sp.CFrame.Position - planter:GetPivot().Position).Magnitude > 5, "the planter plants saplings in a row in front of it")
	sp:Destroy()
	-- the tree feller: a saw handed to it fells the tree standing in front of it
	local tree = trees[#trees - 40]
	local M = Cfg.StudsPerMetre
	local fp = tree:GetPivot().Position + V3(0, 0, 1.5 * M)
	local fel = BS.make("feller", roblox.CFrame.new(fp), 1, 101, true, {})
	local crank2 = BS.make("crank", roblox.CFrame.new(fp + V3(3, 0, 3)), 1, 101, true, {})
	for _ = 1, 8 do
		CS.use(crank2)
	end
	CS.toggle(crank2, fel)
	fel:SetAttribute("Holds", "chainsaw")
	task.wait(5)
	check(tree:GetAttribute("Felled") == true, "a powered tree feller holding a chainsaw fells the tree in front of it")
	-- the drill rig: a rock drill handed to it bores down and throws out chunks
	local rig = mk("drill_rig", V3(24, 0, 0))
	rig:SetAttribute("Holds", "rock_drill")
	local n0 = #loose:GetChildren()
	task.wait(3)
	local chunks = 0
	for _, c in loose:GetChildren() do
		if c:GetAttribute("Kind") == "ore" then
			chunks += 1
		end
	end
	check((rig:GetAttribute("Depth") or 0) > 0.25 and #loose:GetChildren() > n0 and chunks > 0, "a powered drill rig bores down and throws out chunks (" .. string.format("%.2f", rig:GetAttribute("Depth") or 0) .. " m)")
	-- the level sensor: lets power through once the (unpowered) crate in front of it holds 5 things
	local box = BS.make("crate", roblox.CFrame.new(base + V3(36, 0, 20)), 1, 101, true, {})
	local ls = BS.make("level_sensor", roblox.CFrame.new(base + V3(36, 0, 20 + 0.8 * M)), 1, 101, true, {})
	ls:SetAttribute("Setting", 0)          -- (the dial at 5; it starts at 10, as in Godot)
	local things = {}
	local function drop(kind, at)
		local p = roblox.Instance.new("Part")
		p.Size = V3(0.5, 0.5, 0.5)
		p.CFrame = roblox.CFrame.new(at)
		p.Position = at
		p:SetAttribute("Kind", "product")
		p:SetAttribute("Product", kind)
		p.Parent = loose
		table.insert(things, p)
		return p
	end
	for k = 1, 4 do
		drop("chair", (box:GetPivot() * roblox.CFrame.new(0, 0.4 * M, 0)).Position + V3(k * 0.1, 0, 0))
	end
	task.wait(0.3)
	local below = ls:GetAttribute("Sensing")
	drop("chair", (box:GetPivot() * roblox.CFrame.new(0, 0.4 * M, 0)).Position)
	task.wait(0.3)
	check(not below and ls:GetAttribute("Sensing") and ls:GetAttribute("Has") == 5, "a level sensor lets power through once the crate in front holds 5 (" .. tostring(ls:GetAttribute("Has")) .. ")")
	CS.use(ls)
	task.wait(0.3)
	check(not ls:GetAttribute("Sensing"), "[E] raises it to 10")
	-- the charger: a battery cell in its cradle charges up while it's powered
	local ch = mk("charger", V3(-12, 0, 0))
	local cell = drop("battery_cell", (ch:GetPivot() * roblox.CFrame.new(0, 0.75 * M, 0)).Position)
	cell.Anchored = false
	task.wait(1.5)
	check((cell:GetAttribute("Charge") or 0) > 0.05 and ch:GetAttribute("Cells") == 1, "a powered charger charges the battery cell in it (" .. string.format("%.2f", cell:GetAttribute("Charge") or 0) .. ")")
	for _, t in things do
		t:Destroy()
	end
	-- the rotator: the hammer sticks what's on its table to it, and powered, it carries it round
	local rot = mk("rotator", V3(-24, 0, 0))
	local thing2 = drop("chair", (rot:GetPivot() * roblox.CFrame.new(1.4, 1.6, 0)).Position)
	local prev = alice:GetAttribute("Tool")
	Tools.grant(alice, "hammer")
	task.wait(1.3)
	A.stand(alice, rot:GetPivot().Position + V3(0, 5, 6))
	A.remotes.Hammer.OnServerEvent:Fire(alice, thing2)
	task.wait(0.1)
	local p0 = thing2.CFrame.Position
	check(thing2.Anchored and rot:GetAttribute("Stuck"), "the hammer sticks what's on a rotator's table to it")
	task.wait(1.5)
	local p1 = thing2.CFrame.Position
	check((p1 - p0).Magnitude > 0.2 and math.abs((p1 - rot:GetPivot().Position).Magnitude - (p0 - rot:GetPivot().Position).Magnitude) < 0.05,
		"powered, it turns, carrying it round (" .. string.format("%.2f", (rot:GetAttribute("Angle") or 0)) .. " rad)")
	A.remotes.Hammer.OnServerEvent:Fire(alice, thing2)
	task.wait(0.1)
	check(not thing2.Anchored and not rot:GetAttribute("Stuck"), "hammer it again and it lets go")
	-- a piston pushed out against the table clamps what's on it to it, until it pulls back
	local thing3 = drop("chair", (rot:GetPivot() * roblox.CFrame.new(0, 0.45 * M, 0)).Position)
	local crank3 = BS.make("crank", roblox.CFrame.new(rot:GetPivot().Position + V3(9, 0, 9)), 1, 101, true, {})
	for _ = 1, 8 do
		CS.use(crank3)
	end
	local lever3 = BS.make("lever", roblox.CFrame.new(rot:GetPivot().Position + V3(6, 0, 9)), 1, 101, true, {})
	local ps = BS.make("piston", rot:GetPivot() * roblox.CFrame.new(0, 0, 1.5 * M), 1, 101, true, {})
	CS.toggle(crank3, lever3)
	CS.toggle(lever3, ps)
	CS.use(lever3)
	task.wait(1.0)
	check(thing3.Anchored and thing3:GetAttribute("Stuck") ~= nil, "a piston pushed out against a rotator's table clamps what's on it to it")
	CS.use(lever3)
	task.wait(1.0)
	check(not thing3.Anchored, "and lets go when the piston pulls back")
	Tools.equip(alice, prev)
	for _, m in { rig, fel, ch, box, ls, rot, crank3, lever3, ps } do      -- (the rig would keep throwing chunks out for the rest of the run)
		m:Destroy()
	end
end

-- ---------------------------------------------------------------- rails and minecarts
do
	local BS, CS, RS = A.service("BuildService"), A.service("CircuitService"), A.service("RailService")
	local Rail = A.shared("Rail")
	local PS = A.service("ProductionService")
	local M = Cfg.StudsPerMetre
	local prev = alice:GetAttribute("Tool")
	Tools.grant(alice, "hammer")
	task.wait(1.3)
	-- the hammer on a loose rail lays it on the grid square it's lying on (alice faces -Z: it runs along Z)
	local c0 = { x = 15, z = 12 }
	local item = PS.product("rail", 2, roblox.Color3.new(0.55, 0.58, 0.62), roblox.CFrame.new(Rail.centre(c0, 2)), V3(0, 0, 0), alice.UserId)
	item.Position = item.CFrame.Position
	A.stand(alice, Rail.centre(c0, 5) + V3(0, 0, 6))
	A.remotes.Hammer.OnServerEvent:Fire(alice, item)
	task.wait(0.1)
	local r0 = Rail.at(c0)
	check(r0 ~= nil and r0:GetAttribute("AlongX") == false and item.Parent == nil, "the hammer lays a loose rail on its grid square, the way you face")
	A.remotes.Hammer.OnServerEvent:Fire(alice, r0:FindFirstChildWhichIsA("Part"), "turn")
	task.wait(0.05)
	local turned = r0:GetAttribute("AlongX") == true
	RS.turn(r0)
	check(turned and r0:GetAttribute("AlongX") == false, "R turns a laid rail")
	for z = 13, 17 do
		RS.lay({ x = 15, z = z }, true, nil, nil)       -- (lines up with the track: along Z, whatever it's asked)
	end
	check(Rail.at({ x = 15, z = 17 }) and Rail.at({ x = 15, z = 17 }):GetAttribute("AlongX") == false, "a rail laid next to track lines up with it")
	-- a 2-long cart on the track, a Go block and a lever on its deck, a charged cell in its cradle
	local front = { x = 15, z = 16 }
	local cart = BS.make("minecart_2", roblox.CFrame.new(Rail.centre(front, Rail.top(Rail.at(front)))), 1, 101, true, {})
	local deckY = RS.DECK_Y * M
	local go = BS.make("cart_go", cart:GetPivot() * roblox.CFrame.new(0, deckY, 0), 1, 101, true, {})
	local lever = BS.make("lever", cart:GetPivot() * roblox.CFrame.new(0, deckY, 1 * M), 1, 101, true, {})
	CS.toggle(lever, go)
	task.wait(0.2)
	check(go:GetAttribute("Deck") == cart:GetAttribute("Uid") and lever:GetAttribute("Deck") == cart:GetAttribute("Uid"), "machines built on a cart's deck become part of it")
	local cell = PS.product("battery_cell", 1.2, roblox.Color3.new(1, 1, 1), cart:GetPivot() * roblox.CFrame.new(0, 0.47 * M, 1.72 * M), V3(0, 0, 0), 101)
	cell.Position = cell.CFrame.Position
	cell:SetAttribute("Charge", 1)
	task.wait(0.3)
	check(cell.Parent == nil and cart:GetAttribute("Cell") ~= nil, "a battery cell dropped in the cradle snaps in")
	check(Rail.same(RS.frontCell(cart), front), "with the lever off it stays put")
	CS.use(lever)
	local fc = RS.frontCell(cart)
	for _ = 1, 60 do
		task.wait(0.25)
		fc = RS.frontCell(cart)
		if fc.z == 12 then
			break
		end
	end
	task.wait(1)
	fc = RS.frontCell(cart)
	check(fc.x == 15 and fc.z == 12, "lever on: it rolls along the track, a square at a time, and stops where it ends (" .. fc.x .. "," .. fc.z .. ")")
	check(Rail.same(Rail.cellOf(go:GetPivot().Position), fc) and (cart:GetAttribute("Cell") or 1) < 1, "its deck rides along, and the cell runs down")
	-- E takes the cell out again
	CS.use(cart)
	task.wait(0.1)
	check(cart:GetAttribute("Cell") == nil, "[E] takes the battery cell out")
	-- the hammer on a laid rail picks it up again
	local n0 = #loose:GetChildren()
	local r17 = Rail.at({ x = 15, z = 17 })
	A.stand(alice, r17:GetPivot().Position + V3(0, 5, 6))
	A.remotes.Hammer.OnServerEvent:Fire(alice, r17:FindFirstChildWhichIsA("Part"))
	task.wait(0.1)
	check(Rail.at({ x = 15, z = 17 }) == nil and #loose:GetChildren() > n0, "the hammer picks a laid rail up again")
	-- a rotator can go on the side of something, its spin axis pointing out of the face
	local dd = A.service("DataService").get(alice)
	dd.owned.bp_rotator = true
	local sideAt = V3(45, 4, 50)
	local nPlans = #ws.Plans:GetChildren()
	A.remotes.Build.OnServerEvent:Fire(alice, "rotator", roblox.CFrame.new(sideAt) * roblox.CFrame.fromAxisAngle(V3(0, 0, -1), math.pi / 2), 1)
	task.wait(0.1)
	local side
	for _, pl in ws.Plans:GetChildren() do
		if pl:GetAttribute("Build") == "rotator" then
			side = pl
		end
	end
	check(#ws.Plans:GetChildren() == nPlans + 1 and side and math.abs(side:GetPivot().UpVector.Y) < 0.05 and math.abs(math.abs(side:GetPivot().UpVector.X) - 1) < 0.05,
		"a rotator can be built on the side of something, its table facing out")
	if side then
		side:Destroy()
	end
	-- your track is saved with you
	local saved = RS.serialize(alice.UserId)
	check(#saved == 1 and saved[1].kind == "rail" and saved[1].x == 15 and saved[1].z == 12, "the track you laid is saved with you")
	Tools.equip(alice, prev)
	for _, m in { cart, go, lever } do
		m:Destroy()
	end
end

-- ---------------------------------------------------------------- drones
do
	local BS, CS, DS = A.service("BuildService"), A.service("CircuitService"), A.service("DroneService")
	local PS = A.service("ProductionService")
	local M = Cfg.StudsPerMetre
	local base = V3(-90, 0, 90)
	local h0 = A.service("WorldService").heightAt(base.X, base.Z)
	local drone = BS.make("drone_small", roblox.CFrame.new(V3(base.X, h0, base.Z)), 1, 101, true, {})
	task.wait(0.3)
	check(drone:GetAttribute("Dials") == "0,1,2,3,4", "a drone's five dials start on red, green, blue, yellow and purple")
	-- E on a dial changes its channel; on the body, with a cell in, takes the cell out
	local front
	for _, p in drone:GetChildren() do
		if DS.dialOf(drone, p) == 1 then
			front = p
		end
	end
	DS.use(drone, front)
	check(front ~= nil and DS.dials(drone)[1] == 1, "[E] on its front dial turns it to the next channel")
	for _ = 1, 7 do
		DS.use(drone, front)
	end
	check(DS.dials(drone)[1] == -1, "and after pink, off")
	for _ = 1, 6 do
		DS.use(drone, front)       -- (orange: the wireless test's transmitter is still on red)
	end
	-- a charged cell in its cradle: it rises to 3 m; a powered transmitter on red flies it forward
	local cell = PS.product("battery_cell", 1.2, roblox.Color3.new(1, 1, 1), drone:GetPivot() * roblox.CFrame.new(0, 0.42 * M, 0.18 * M), V3(0, 0, 0), 101)
	cell.Position = cell.CFrame.Position
	cell:SetAttribute("Charge", 1)
	for _ = 1, 40 do
		task.wait(0.25)
		if drone:GetPivot().Position.Y - h0 > 2.9 * M then
			break
		end
	end
	check(cell.Parent == nil and drone:GetPivot().Position.Y - h0 > 2.5 * M, string.format("with a charged cell it rises to cruise over the ground (%.1f m)", (drone:GetPivot().Position.Y - h0) / M))
	local z0 = drone:GetPivot().Position.Z
	local crank = BS.make("crank", roblox.CFrame.new(base + V3(12, 0, 0)), 1, 101, true, {})
	for _ = 1, 8 do
		CS.use(crank)
	end
	local tx = BS.make("transmitter", roblox.CFrame.new(base + V3(15, 0, 0)), 1, 101, true, {})
	tx:SetAttribute("Channel", 5)
	CS.toggle(crank, tx)
	task.wait(1.5)
	check(drone:GetPivot().Position.Z < z0 - 1 * M, "a powered transmitter on its front dial's channel (orange) flies it forward")
	tx:Destroy()
	task.wait(0.3)
	local z1 = drone:GetPivot().Position.Z
	task.wait(0.5)
	check(math.abs(drone:GetPivot().Position.Z - z1) < 0.05, "and it hovers when the channel goes off")
	DS.use(drone, nil)
	check(drone:GetAttribute("Cell") == nil, "[E] takes its cell out")
	for _, m in { drone, crank } do
		m:Destroy()
	end
end

-- ---------------------------------------------------------------- the daily reward
do
	local E = A.service("EconomyService")
	local d = A.service("DataService").get(alice)
	local money0, daily0 = d.money, d.daily
	d.daily = nil
	local first = E.daily(alice, 1000)
	check(first == 0 and d.money == money0, "your first day: no daily reward yet (you start with nothing, as in Godot)")
	local paid = { E.daily(alice, 1001), E.daily(alice, 1002), E.daily(alice, 1002) }
	check(paid[1] == 15 and paid[2] == 30 and paid[3] == 0, "the next day $15, the day after $30, and only once a day")
	check(E.daily(alice, 1005) == 15 and alice:GetAttribute("Streak") == 1, "miss a day and the streak starts again")
	local last = 0
	for day = 1006, 1015 do
		last = E.daily(alice, day)
	end
	check(last == 105, "a week in a row and more: $105 a day (" .. last .. ")")
	alice:SetAttribute("Streak", nil)
	check(E.daily(alice, 1015) == 0 and alice:GetAttribute("Streak") == 11, "back again the same day: nothing more, but the phone still shows the streak")
	-- codes from the phone: each pays once, typed any way
	local codes0 = d.codes
	d.codes = nil
	local paidA = E.redeem(alice, " timber")
	local paidB, why = E.redeem(alice, "TIMBER")
	local paidC = E.redeem(alice, "free-money")
	check(paidA == 100 and paidB == 0 and string.find(why, "already") ~= nil and paidC == 0, "a code pays once, typed any way; a made-up one pays nothing")
	d.codes = codes0
	-- the game page lists the same codes, with what they pay, and fits Roblox's 1000 characters
	local page = require("@lune/fs").readFile("roblox/publish/description.txt")
	local listed = true
	for code, amount in Cfg.Codes do
		listed = listed and string.find(page, string.format("%s - $%d", code, amount), 1, true) ~= nil
	end
	check(listed and #page <= 1000, string.format("the game page's description lists every code and what it pays (%d characters)", #page))
	-- today's jobs: counted from the day's start; each pays once when done
	local J = A.service("JobsService")
	local jobs0, felled0, earned0 = d.jobs, d.felled, d.earned
	d.jobs = nil
	local day = 3000                       -- (day % 3 == 0: fell 2 trees for $20, earn $40 for $20, a $20 load for $16)
	J.check(alice, day)
	d.felled = (d.felled or 0) + 1
	local none = J.check(alice, day)
	d.felled += 1
	local fell = J.check(alice, day)
	local again = J.check(alice, day)
	J.load(alice, 25, day)
	local load = J.check(alice, day)
	local shown = require("@lune/serde").decode("json", alice:GetAttribute("Jobs"))
	check(none == 0 and fell == 20 and again == 0 and load == 16 and shown[1].done and not shown[2].done and shown[3].done,
		string.format("today's jobs: felling 2 trees pays $20 once, a $25 truckload pays $16 (%d %d %d %d)", none, fell, again, load))
	d.earned = (d.earned or 0) + 40
	local all = J.check(alice, day)
	check(all == 20 + J.ALL_BONUS and J.check(alice, day) == 0, string.format("all three jobs done: their pay and a $%d bonus, once (%d)", J.ALL_BONUS, all))
	J.check(alice, day + 1)
	local fresh = require("@lune/serde").decode("json", alice:GetAttribute("Jobs"))
	check(not fresh[1].done and fresh[1].need == 3 and fresh[1].have == 0, "a new day, new jobs, counted from zero")
	d.jobs, d.felled, d.earned = jobs0, felled0, earned0
	-- the wood of the day: one species a day, in turn, pays 1.5x at the mill (bark and logs)
	local E2 = A.service("EconomyService")
	local seen = {}
	for dd = 0, 6 do
		seen[woodOfTheDay(dd)] = true
	end
	local n = 0
	for _ in seen do
		n += 1
	end
	check(n == 7 and woodOfTheDay(5) ~= woodOfTheDay(6), "the wood of the day goes round all seven species, a different one each day")
	local sheet = roblox.Instance.new("Part")
	sheet:SetAttribute("Value", 2)
	sheet:SetAttribute("Species", "birch")
	sheet:SetAttribute("Kind", "bark")
	E2.woodOfTheDay = function()
		return "birch"
	end
	local onDay = E2.worth(sheet)
	E2.woodOfTheDay = function()
		return "oak"
	end
	local offDay = E2.worth(sheet)
	E2.woodOfTheDay = function()
		return "none"
	end
	sheet:Destroy()
	check(math.abs(onDay - 3) < 0.01 and math.abs(offDay - 2) < 0.01, string.format("birch bark on birch day is worth 1.5x ($%.2f, other days $%.2f)", onDay, offDay))
	-- the friends boost: a Roblox friend on your server, +10% at the mill
	check(E2.friendBoost(alice) == 1, "no friends here: no boost")
	E2.friends[alice.UserId] = { [bob.UserId] = true }
	local withBob = E2.friendBoost(alice)
	E2.friends[alice.UserId] = { [999999] = true }
	local friendAway = E2.friendBoost(alice)
	E2.friends[alice.UserId] = nil
	check(math.abs(withBob - 1.1) < 1e-6 and friendAway == 1, "a friend on your server: the mill pays 10% more (only while they're here)")
	d.money, d.daily = money0, daily0
	alice:SetAttribute("Money", money0)
end

-- ---------------------------------------------------------------- dynamite
do
	local BS, CS, MS = A.service("BuildService"), A.service("CircuitService"), A.service("MiningService")
	local M = Cfg.StudsPerMetre
	local idx, rk = nil, nil
	for i = 0, 80 do
		local r = MS.rock(i)
		if r then
			idx, rk = i, r
		end
	end
	if rk then
		local prev = alice:GetAttribute("Tool")
		Tools.grant(alice, "dynamite")
		task.wait(1.3)
		local d = A.service("DataService").get(alice)
		d.charges = { dynamite = 5 }
		A.stand(alice, rk.at + V3(0, 3, 6))
		local pos = rk.at + V3(0, rk.s * 0.5 * M, 0)
		A.remotes.Plant.OnServerEvent:Fire(alice, nil, pos, V3(0, 1, 0))
		task.wait(0.1)
		local charge
		for _, m in ws.Builds:GetChildren() do
			if m:GetAttribute("Build") == "charge" then
				charge = m
			end
		end
		check(charge ~= nil and d.charges.dynamite == 4 and alice:GetAttribute("Charges") == 4, "dynamite: a click sticks a charge where you look (4 left)")
		local before = 0
		for _, c in loose:GetChildren() do
			if c:GetAttribute("Kind") == "ore" then
				before += 1
			end
		end
		-- wired to a wound crank: power reaches it, a hiss of fuse, then it goes off and the rock bursts
		local crank = BS.make("crank", roblox.CFrame.new(rk.at + V3(9, 0, 0)), 1, 101, true, {})
		for _ = 1, 4 do
			CS.use(crank)
		end
		CS.toggle(crank, charge)
		task.wait(1.2)
		local after = 0
		for _, c in loose:GetChildren() do
			if c:GetAttribute("Kind") == "ore" then
				after += 1
			end
		end
		check(MS.rock(idx) == nil and after - before >= 2 and charge.Parent == nil, "wired to a switch with power it goes off, and the rock bursts into every chunk")
		crank:Destroy()
		-- the hammer nails a log in place, and lets it go again
		local logs = ws:FindFirstChild("Logs")
		local lg = logs and logs:FindFirstChildWhichIsA("Model")
		if lg and lg:FindFirstChild("Trunk") then
			Tools.grant(alice, "hammer")
			task.wait(1.3)
			A.stand(alice, lg.Trunk.CFrame.Position + V3(0, 3, 6))
			A.remotes.Hammer.OnServerEvent:Fire(alice, lg.Trunk)
			task.wait(0.05)
			local locked = lg:GetAttribute("Locked") == true and lg.Trunk.Anchored
			A.remotes.Hammer.OnServerEvent:Fire(alice, lg.Trunk)
			task.wait(0.05)
			check(locked and not lg:GetAttribute("Locked") and not lg.Trunk.Anchored, "the hammer locks a log in place, and unlocks it")
		end
		Tools.equip(alice, prev)
	end
end

-- ---------------------------------------------------------------- production
do
	local BS, PS = A.service("BuildService"), A.service("ProductionService")
	local base = V3(-30, 0, -45)
	local CS = A.service("CircuitService")
	local crank = BS.make("crank", roblox.CFrame.new(base + V3(0, 0, 9)), 1, 101, true, {})
	for _ = 1, 8 do
		CS.use(crank)          -- (wound right up: 2 minutes of power)
	end
	local function mk(id, off)
		local m = BS.make(id, roblox.CFrame.new(base + off), 1, 101, true, {})
		A.service("BuildBehaviors").activate(m)
		CS.toggle(crank, m)
		return m
	end
	-- the sawmill: a log on its table becomes planks
	local mill = mk("sawmill", V3(0, 0, 0))
	local log = nil
	for _, l in ws.Logs:GetChildren() do
		if l:GetAttribute("Kind") == "log" and (l:GetAttribute("Bands") or 0) <= 12 then
			log = l
		end
	end
	if log then
		local target = (mill:GetPivot() * roblox.CFrame.new(0, 2.55, 0)).Position
		log:PivotTo(log:GetPivot() + (target - log.Trunk.CFrame.Position))
		local len = log:GetAttribute("Bands") * 0.18
		task.wait(0.8 + len * 0.4 + 0.4)
		local planks = 0
		for _, c in loose:GetChildren() do
			if c:GetAttribute("Product") == "plank" then
				planks += 1
			end
		end
		check(planks >= 1 and not pcall(function() return log.Parent.Name end), string.format("a powered sawmill turns a log into planks (%d)", planks))
		check(string.find(alice:GetAttribute("Trophies") or "", "first_plank", 1, true) ~= nil, "and your first planks go on the trophy wall")
	end
	-- the smelter: ore in, a bar out (2.2x)
	local sm = mk("smelter", V3(9, 0, 0))
	local ore = A.service("MiningService").chunk("iron", 0.14, (sm:GetPivot() * roblox.CFrame.new(0, 3, 0)).Position, V3(0, 0, 0), 101)
	ore.Position = ore.CFrame.Position
	local val = ore:GetAttribute("Value")
	task.wait(3.5)
	local bar = nil
	for _, c in loose:GetChildren() do
		if c:GetAttribute("Product") == "iron_bar" then
			bar = c
		end
	end
	check(bar ~= nil and math.abs(bar:GetAttribute("Value") - val * 2.2) < 0.02, "a smelter turns iron ore into an iron bar worth 2.2x")
	-- the assembler: E picks what it makes; 2 planks make a chair
	local asm = mk("assembler", V3(18, 0, 0))
	check(asm:GetAttribute("Recipe") == nil, "the assembler starts on chairs")
	for k = 1, 2 do
		local p = PS.product("plank", 2, roblox.Color3.fromHex("c69a62"), asm:GetPivot() * roblox.CFrame.new(0, 3, 0), V3(0, 0, 0), 101)
		p.Position = p.CFrame.Position
		task.wait(0.2)
	end
	task.wait(3.5)
	local chair = nil
	for _, c in loose:GetChildren() do
		if c:GetAttribute("Product") == "chair" then
			chair = c
		end
	end
	check(chair ~= nil and math.abs(chair:GetAttribute("Value") - 10) < 0.02, "2 planks make a chair worth 2.5x what went in")
	A.service("CircuitService").use(asm)
	check(asm:GetAttribute("Recipe") == 1, "E on the assembler changes what it makes")
end

-- ---------------------------------------------------------------- the bigger trucks
do
	local WS = A.service("WorldService")
	local truck = ws.Truck
	local bed0 = truck.Bed.Size
	WS.setTruckLevel(1)
	local bed1 = truck.Bed.Size
	WS.setTruckLevel(2)
	local bed2 = truck.Bed.Size
	check(bed1.Z > bed0.Z and bed2.Z > bed1.Z and bed2.Y > bed0.Y, "the Big Truck and the Log Hauler have bigger beds (Godot's)")
	WS.setTruckLevel(0)
	if truck:GetAttribute("State") == "parked" then
		data.money += 4000
		A.remotes.Buy.OnServerEvent:Fire(alice, "truck_big")
		task.wait(0.2)
		check(data.owned.truck_big and count("Notify", alice, "Bought the Big Truck") == 1 and truck:GetAttribute("State") ~= "parked",
			"buying the Big Truck: the old one drives off, and the new one will come back in its place")
	end
end

-- ---------------------------------------------------------------- the leaf vacuums
do
	Tools.grant(alice, "vacuum")
	task.wait(1.3)
	local head = alice.Character.Head
	local origin = head.CFrame.Position
	local dir, right = V3(1, 0, 0), V3(0, 0, -1)
	local nozzle = origin + dir * 3.75 - V3(0, 0.54, 0)
	local function bit(at)
		local p = roblox.Instance.new("Part")
		p.Size = V3(0.6, 0.6, 0.6)
		p.CFrame = roblox.CFrame.new(at)
		p.Position = at
		p.AssemblyLinearVelocity = V3(0, 0, 0)
		p:SetAttribute("Kind", "leaf")
		p:SetAttribute("Value", 0.05)
		p:SetAttribute("Owner", 101)
		p.Parent = loose
		return p
	end
	local near = bit(nozzle + V3(0.5, 0, 0))
	local far = bit(origin + dir * 15)
	local behind = bit(origin - dir * 6)
	local vac = A.remotes.Vacuum.OnServerEvent
	vac:Fire(alice, true, origin, dir, right)
	task.wait(0.3)
	local fv = far.AssemblyLinearVelocity
	check(near:GetAttribute("VacBy") == 101, "the leaf vacuum catches what reaches its nozzle")
	check(fv:Dot(nozzle - far.Position) > 0, "and pulls in what's in front of it, up to 7 m away")
	check(behind.AssemblyLinearVelocity.Magnitude < 0.01 and not behind:GetAttribute("VacBy"), "but nothing behind you")
	vac:Fire(alice, false)
	task.wait(0.1)
	check(near:GetAttribute("VacBy") == nil, "let go and it drops what it caught")
	-- the cyclone fires its clump straight ahead
	Tools.grant(alice, "cyclone")
	task.wait(1.3)
	near.CFrame = roblox.CFrame.new(nozzle)
	near.Position = nozzle
	vac:Fire(alice, true, origin, dir, right)
	task.wait(0.2)
	vac:Fire(alice, false)
	task.wait(0.1)
	check(near.AssemblyLinearVelocity.X > 30, string.format("the Cyclone Vac fires what it caught straight ahead (%.0f studs/s)", near.AssemblyLinearVelocity.X))
	for _, p in { near, far, behind } do
		p:Destroy()
	end
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

-- ---------------------------------------------------------------- the phone's Lumberjacks list
check((alice:GetAttribute("Felled") or 0) >= 1 and (alice:GetAttribute("Earned") or 0) > 0,
	string.format("everyone on the server sees what you've earned and felled ($%s, %s trees)", tostring(alice:GetAttribute("Earned")), tostring(alice:GetAttribute("Felled"))))

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
	bd.earned = 400
	A.service("EconomyService").redeem(bob, "timber")
	bd.daily = { last = 1000, streak = 3 }
	bd.jobs = { day = 1000, felled = 7, earned = 90, best = 0, done = { fell = true } }
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
	check(A.service("EconomyService").redeem(bob, "TIMBER") == 0 and bd.daily and bd.daily.streak == 3 and bd.bestEarned == 400,
		"but a new game doesn't hand out codes again, or lose the daily streak or the all-time best")
	check(bd.jobs and bd.jobs.done.fell == true and bd.jobs.felled == 0, "and today's finished jobs stay finished")
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
