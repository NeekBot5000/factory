-- The client playtest: the real client scripts, joined to the real server scripts, driven with key presses, clicks
-- and the camera, the way a player would. Checks the HUD, the keys, swinging, the bark drawing and the shop.
--   lune run tests/lune/client.luau <path to Timber.rbxl>
local process = require("@lune/process")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local Harness = require("./harness")
local ClientHarness = require("./clientharness")

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
local K = roblox.Enum.KeyCode

local S = Harness.boot(place, "client-test")
S.start()
task.wait(0.1)
local alice = S.join(101, "Alice", V3(0, 5, 14))
task.wait(0.6)
local C = ClientHarness.start(S, alice)
C.boot()
C.frames(5)
task.wait(2.5)
C.frames(3)
check(#ClientHarness.errors == 0, "the client starts with no errors (" .. #ClientHarness.errors .. ")")
-- the title screen first: Timber, and (for a new player) only New Game
local title = C.gui("TitleMenu")
check(title ~= nil and C.find(title, function(d) return d:IsA("TextLabel") and d.Text == "Timber" end), "the Godot title screen shows first")
local newGame = title and C.find(title, function(d) return d:IsA("TextButton") and d.Text == "New Game" end)
local cont = title and C.find(title, function(d) return d:IsA("TextButton") and d.Text == "Continue" end)
check(newGame ~= nil and cont == nil, "a new player gets New Game (and no Continue)")
if newGame then
	ClientHarness.signal(newGame, "Activated"):Fire()
end
C.frames(2)
check(C.gui("TitleMenu") == nil, "New Game starts playing")
for _, e in ClientHarness.errors do
	print("   " .. e)
end

local ws = S.workspace
local hud = C.gui("Hud")
check(hud ~= nil, "the HUD is on screen")
check(C.coreOff.PlayerList and C.coreOff.Backpack and C.coreOff.Health, "Roblox's player list, backpack and health bar are off")
local function text(pred)
	local l = C.find(hud, function(d)
		return d:IsA("TextLabel") and pred(d.Text)
	end)
	return l
end
local function hint(): string
	-- the hint line sits above the tool bar (bottom centre)
	local l = C.find(hud, function(d)
		return d:IsA("TextLabel") and d.AnchorPoint == roblox.Vector2.new(0.5, 1) and d.Position.Y.Offset == -110
	end)
	return if l then l.Text else "<no hint label>"
end
check(text(function(t) return t == "$0.00" end), "the money counter says $0.00")
check(text(function(t) return string.find(t, "Getting started", 1, true) ~= nil end), "Getting started shows, top left")

-- walk up to the chopping block and look at it
local block = ws.ChoppingBlock
local stump = block.Stump
S.stand(alice, stump.CFrame.Position + V3(0, 3.5, 4))
C.look(stump.CFrame.Position + V3(0, 1, 0))
C.frames(3)
check(hint() == "[E] take", "looking at the hatchet in the block: '[E] take' (" .. hint() .. ")")
C.press(K.E)
task.wait(0.2)
C.frames(3)
check(alice:GetAttribute("Tool") == "hatchet", "E takes the hatchet: it's in your hand")
check(text(function(t) return string.find(t, "Trusty Hatchet", 1, true) ~= nil end), "and the tool bar shows it, named, in gold")
-- on a phone, tapping a slot in the tool bar takes that tool out (there are no number keys)
do
	local hud = C.gui("Hud")
	local handsSlot = hud and C.find(hud, function(d)
		return d:IsA("TextLabel") and d.Text == "1" and d.Parent and d.Parent:IsA("Frame")
	end)
	if handsSlot then
		ClientHarness.signal(handsSlot.Parent, "InputBegan"):Fire({ UserInputType = roblox.Enum.UserInputType.Touch })
		task.wait(0.2)
		C.frames(2)
	end
	check(handsSlot ~= nil and alice:GetAttribute("Tool") == "hands", "tapping a tool bar slot takes that tool out (phones)")
	-- and back to the hatchet, by its slot
	local hatchetSlot = hud and C.find(hud, function(d)
		return d:IsA("TextLabel") and d.Text == "2" and d.Parent and d.Parent:IsA("Frame")
	end)
	if hatchetSlot then
		ClientHarness.signal(hatchetSlot.Parent, "InputBegan"):Fire({ UserInputType = roblox.Enum.UserInputType.Touch })
		task.wait(0.2)
		C.frames(2)
	end
	check(alice:GetAttribute("Tool") == "hatchet", "and tapping the hatchet's slot takes the hatchet out again")
end

-- the TimberPhone: Tab opens it, with the server's lumberjacks by what they've earned
do
	S.service("ToolService").grant(alice, "phone")
	S.game:GetService("ReplicatedStorage"):SetAttribute("AllTime", '[{"name":"Alice","earned":5000},{"name":"Bob","earned":1200}]')
	alice:SetAttribute("Earned", 42)
	alice:SetAttribute("Felled", 3)
	alice:SetAttribute("Streak", 4)
	task.wait(0.2)
	C.frames(2)
	C.press(K.Tab)
	C.frames(3)
	local shop = C.gui("TimberMart")
	check(shop ~= nil and C.find(shop, function(d) return d:IsA("TextLabel") and d.Text == "LUMBERJACKS HERE" end) ~= nil, "Tab opens the TimberPhone, with the Lumberjacks list")
	check(shop ~= nil and C.find(shop, function(d) return d:IsA("TextLabel") and string.find(d.Text, "1. Alice", 1, true) ~= nil and string.find(d.Text, "$42", 1, true) ~= nil end) ~= nil,
		"and you're on it, with what you've earned and felled")
	check(shop ~= nil and C.find(shop, function(d) return d:IsA("TextLabel") and d.Text == "Daily streak: 4 days" end) ~= nil, "and your daily streak")
	check(shop ~= nil and C.find(shop, function(d) return d:IsA("TextLabel") and string.find(d.Text, "golden tree", 1, true) ~= nil end) ~= nil,
		"and when the next golden tree comes")
	check(shop ~= nil and C.find(shop, function(d) return d:IsA("TextLabel") and string.find(d.Text, "1. Alice   $5000", 1, true) ~= nil end) ~= nil,
		"and the all-time best, across every server")
	C.press(K.Tab)
	C.frames(2)
end


-- number keys and Q
C.press(K.One)
task.wait(0.1)
C.frames(2)
check(alice:GetAttribute("Tool") == "hands", "1: bare hands")
C.press(K.Two)
task.wait(0.1)
C.frames(2)
check(alice:GetAttribute("Tool") == "hatchet", "2: the hatchet")
C.look(stump.CFrame.Position + V3(0, 1, 0) + V3(0, 0, 3))
C.press(K.Q)
task.wait(0.1)
C.frames(2)
local item = ws.Loose:FindFirstChild("Tool_hatchet")
check(item ~= nil and alice:GetAttribute("Tool") == "hands", "Q puts the hatchet down on the ground")
if item then
	C.look(item.Handle.CFrame.Position)
	S.stand(alice, item.Handle.CFrame.Position + V3(0, 3, 3))
	C.frames(3)
	check(hint() == "[E] take", "looking at it: '[E] take' (" .. hint() .. ")")
	C.press(K.E)
	task.wait(0.2)
	C.frames(2)
	check(alice:GetAttribute("Tool") == "hatchet" and ws.Loose:FindFirstChild("Tool_hatchet") == nil, "E picks it back up, into your hand")
end

-- Shift sprints
local hum = alice.Character.Humanoid
C.frames(1)
local walk = hum.WalkSpeed
C.hold(K.LeftShift, true)
C.frames(1)
local run = hum.WalkSpeed
C.hold(K.LeftShift, false)
C.frames(1)
check(math.abs(walk - 12.6) < 0.01 and math.abs(run - 20.4) < 0.01 and math.abs(hum.WalkSpeed - 12.6) < 0.01, string.format("Shift sprints: %.1f -> %.1f studs a second", walk, run))

-- swing at a tree: the blade lands partway through, the server takes the bark, the client draws it
local tree, td = nil, math.huge
for _, t in ws.Forest:GetChildren() do
	if t:HasTag("Tree") then
		local d = (t.WorldPivot.Position - alice.Character.Head.CFrame.Position).Magnitude
		if d < td then
			tree, td = t, d
		end
	end
end
local base = tree.WorldPivot.Position
local r = tree:GetAttribute("Radius")
S.stand(alice, base + V3(r + 3, 4.5, 0))
C.look(base + V3(0, 4.5, 0))
C.frames(20)       -- (a tool you just took out has to come up into view before you can swing it, like Godot's)
local vm = C.camera:FindFirstChild("ViewModel")
check(vm ~= nil, "the first-person arm is in view")
local function armAt()
	return C.camera.CFrame:PointToObjectSpace(vm:GetPivot().Position)
end
local rest = vm and armAt()
check(rest and rest.X > 0 and rest.Y < 0 and rest.Z < 0, "at rest it's lower right, in front of you (" .. tostring(rest) .. ")")
local sent0 = #C.sent
C.click()
local moved = 0
for _ = 1, 12 do
	C.frame(1 / 60)
	task.wait()
	if vm then
		moved = math.max(moved, (armAt() - rest).Magnitude)
	end
end
check(moved > 0.5, string.format("a swing carries the arm along Godot's arc (moves %.1f studs)", moved))
for _ = 1, 40 do
	C.frame(1 / 60)
	task.wait()
end
local stripped = false
for k = sent0 + 1, #C.sent do
	stripped = stripped or C.sent[k].remote == "StripRequest"
end
check(stripped, "a click swings, and the blade landing asks the server for the bark")
task.wait(0.2)
C.frames(3)
check(#ws.Loose:GetChildren() > 0, "bark comes off")
local sheet = nil
for _, c in ws.Loose:GetChildren() do
	if c:GetAttribute("Kind") == "bark" then
		sheet = c
	end
end
if sheet then
	local Config = C.require(S.game.ReplicatedStorage.Shared.Config)
	local want = roblox.Color3.fromHex(Config.Species[tree:GetAttribute("Species")].bark)
	local faces = 0
	for _, d in sheet:GetDescendants() do
		if d:IsA("BasePart") then
			faces += 1
		end
	end
	check(faces >= 1 and math.abs(sheet.Size.Y - 0.54) < 0.01, string.format("the sheet is the panels that came off, 0.18 m high each (%d parts)", faces + 1))
	check(math.abs(sheet.Color.R - want.R) < 0.15, "in the trunk's own bark colours")
	-- (nothing moves in Lune: lift the sheet off the trunk, as it would have flown)
	local away = (sheet.CFrame.Position - base) * V3(1, 0, 1)
	local cf = sheet.CFrame + away.Unit * 4
	for _, d in sheet:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = cf * sheet.CFrame:ToObjectSpace(d.CFrame)
		end
	end
	sheet.CFrame = cf
	C.look(sheet.CFrame.Position)
	S.stand(alice, sheet.CFrame.Position + away.Unit * 3 + V3(0, 2, 0))
	C.frames(2)
	check(string.find(hint(), "%[E%] grab    %$%d+%.%d%d") ~= nil, "looking at it: Godot's '[E] grab    $0.60' (" .. hint() .. ")")
	S.stand(alice, base + V3(r + 3, 4.5, 0))
end
C.frames(3)
local panels = tree:FindFirstChild("BarkPanels")
check(panels ~= nil, "the tree is redrawn with its bark panels")
if panels then
	local bands = tree:GetAttribute("Bands")
	local R = tree:GetAttribute("Radius")
	local n, thin, off, inner = 0, 0, 0, 0
	local outerColors = {}
	local sp = tree:GetAttribute("Species")
	local Config = C.require(S.game.ReplicatedStorage.Shared.Config)
	local innerHex = Config.Species[sp].inner
	for _, p in panels:GetChildren() do
		n += 1
		local sz = p.Size
		if math.min(sz.X, sz.Y, sz.Z) < 0.05 or sz.X > 2 or sz.Y > 1 and sz.Y < bands * 0.54 - 0.1 then
			thin += 1
		end
		local lp = tree.WorldPivot:PointToObjectSpace(p.CFrame.Position)
		local rr = math.sqrt(lp.X * lp.X + lp.Z * lp.Z)
		if rr > R + 0.05 or rr < R * 0.5 then
			off += 1
		end
		local c = p.Color
		local ic = roblox.Color3.fromHex(innerHex)
		if math.abs(c.R - ic.R) < 0.08 and math.abs(c.G - ic.G) < 0.08 and math.abs(c.B - ic.B) < 0.08 then
			inner += 1
		end
		outerColors[string.format("%.2f", c.R)] = true
	end
	local shades = 0
	for _ in outerColors do
		shades += 1
	end
	check(n > 16 * (bands - 2), string.format("a panel for every spot of bark, 16 round and %d high, plus the wood (%d parts)", bands, n))
	check(thin == 0, "no panel is a sliver or a line: each is a proper flat block (" .. thin .. " bad)")
	check(off == 0, "every panel sits on the trunk's surface (" .. off .. " off)")
	check(shades > 4, "panels vary in shade, the Godot checkered look (" .. shades .. " shades)")
	check(inner > 0, "where the outer bark came off, the inner layer shows in its own colour (" .. inner .. " panels)")
end

-- the Thunder Axe: hold the button to charge it, let go on the trunk and the strike goes to the server
do
	S.service("ToolService").grant(alice, "thunder")
	S.stand(alice, base + V3(r + 3, 4.5, 0))
	C.look(base + V3(0, 4.5, 0))
	task.wait(0.2)
	C.frames(40)
	local sent1 = #C.sent
	C.hold(K.ButtonR2, true)
	for _ = 1, 90 do       -- 1.5 s: past Godot's 1.2 s charge
		C.frame(1 / 60)
		task.wait()
	end
	C.hold(K.ButtonR2, false)
	C.frames(2)
	local strike = false
	for k = sent1 + 1, #C.sent do
		local e = C.sent[k]
		strike = strike or (e.remote == "StripRequest" and e.args[3] == "thunder" and e.args[4] == true)
	end
	if not strike then
		for k = sent1 + 1, #C.sent do
			print("  sent", C.sent[k].remote, C.sent[k].args[3], C.sent[k].args[4])
		end
	end
	check(strike, "holding the Thunder Axe charges it; letting go on a trunk strikes")
	task.wait(0.3)
	C.frames(2)
	local flash = C.find(C.gui("Hud"), function(d)
		return d.Name == "Lightning"
	end)
	check(flash ~= nil and flash.BackgroundTransparency < 1, "and the lightning flashes white over the screen")
end

-- a bark drill: held on the trunk, it bites again and again (every 0.2 s for the timber auger)
do
	S.service("ToolService").grant(alice, "drill")
	S.stand(alice, base + V3(r + 3, 7, 0))
	C.look(base + V3(0, 7, 0))
	task.wait(0.2)
	C.frames(40)
	local sent1 = #C.sent
	C.hold(K.ButtonR2, true)
	for _ = 1, 45 do       -- 0.75 s
		C.frame(1 / 60)
		task.wait()
	end
	C.hold(K.ButtonR2, false)
	local bites = 0
	for k = sent1 + 1, #C.sent do
		if C.sent[k].remote == "StripRequest" and C.sent[k].args[3] == "drill" then
			bites += 1
		end
	end
	check(bites >= 3, "holding the timber auger on a trunk keeps boring (" .. bites .. " bites in 0.75 s)")
end

-- the leaf vacuum: while the trigger is held it tells the server where it points; letting go says so
do
	S.service("ToolService").grant(alice, "vacuum")
	task.wait(0.2)
	C.frames(40)
	local sent1 = #C.sent
	C.hold(K.ButtonR2, true)
	for _ = 1, 30 do
		C.frame(1 / 60)
		task.wait()
	end
	C.hold(K.ButtonR2, false)
	C.frames(2)
	local on, off = 0, 0
	for k = sent1 + 1, #C.sent do
		local e = C.sent[k]
		if e.remote == "Vacuum" then
			if e.args[1] == true then
				on += 1
			else
				off += 1
			end
		end
	end
	check(on >= 2 and off == 1, string.format("holding the leaf vacuum runs it, letting go stops it (%d, %d)", on, off))
end

-- the hammer: a click opens the build menu; a card starts the hologram; a click on your land sets the plan down
do
	S.service("ToolService").grant(alice, "hammer")
	-- (Lune has no terrain to aim at: a flat bit of ground where we'll build)
	local WS = S.service("WorldService")
	local ground = roblox.Instance.new("Part")
	ground.Anchored = true
	ground.Size = V3(30, 1, 30)
	ground.CFrame = roblox.CFrame.new(-24, WS.heightAt(-24, 24) - 0.5, 24)
	ground.Position = ground.CFrame.Position
	ground.Parent = ws
	S.stand(alice, V3(-24, 5, 33))
	C.look(V3(-24, 0, 24))
	task.wait(0.2)
	C.frames(40)
	C.click()
	C.frames(2)
	local menu = C.gui("BuildMenu")
	check(menu ~= nil and C.find(menu, function(d) return d:IsA("TextLabel") and d.Text == "Log Bench" end) ~= nil, "a click with the hammer opens Godot's build menu")
	local cardBtn = menu and C.find(menu, function(d)
		return d:IsA("TextButton") and C.find(d, function(x) return x:IsA("TextLabel") and x.Text == "Log Bench" end) ~= nil
	end)
	if cardBtn then
		ClientHarness.signal(cardBtn, "Activated"):Fire()
	end
	C.frames(3)
	local holo = C.camera:FindFirstChild("Hologram")
	check(C.gui("BuildMenu") == nil and holo ~= nil, "picking the Log Bench puts its hologram where you look")
	local sent1 = #C.sent
	C.click()
	C.frames(2)
	local placed = false
	for k = sent1 + 1, #C.sent do
		placed = placed or (C.sent[k].remote == "Build" and C.sent[k].args[1] == "bench")
	end
	check(placed and C.camera:FindFirstChild("Hologram") == nil, "a click sets the plan down")
end

print(string.format("\nCLIENT RESULT: %s (%d passed, %d failed)", if fails == 0 then "PASS" else "FAIL", passes, fails))
process.exit(if fails == 0 then 0 else 1)
