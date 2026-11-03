--!strict
-- Command-line tests for the pure game logic (no Roblox needed):
--   luau tests/run.luau        (from the roblox/ folder; https://github.com/luau-lang/luau/releases)
local Config = require("../src/shared/Config")
local BarkGrid = require("../src/shared/BarkGrid")
local PowerGrid = require("../src/shared/PowerGrid")
local OilField = require("../src/shared/OilField")
local Economy = require("../src/shared/Economy")

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

-- bark: outer first, then inner, never inner under outer
local g = BarkGrid.new(16, 40)
check(BarkGrid.count(g, BarkGrid.OUTER) == 640 and buffer.len(g.data) == 1280, "a new tree has every panel, in 1.3 KB")
local r = BarkGrid.stripCircle(g, 3, 10, 1)
check(r ~= nil and r.layer == BarkGrid.OUTER and #r.panels >= 5, "a hit takes a circle of outer bark")
local r2 = BarkGrid.stripCircle(g, 3, 10, 1)
check(r2 ~= nil and r2.layer == BarkGrid.INNER, "hitting the same spot again takes the inner bark under it")
check(BarkGrid.stripCircle(g, 3, 10, 0) == nil, "with both layers gone, nothing more comes off")
local g2 = BarkGrid.new(16, 40)
check(BarkGrid.stripCircle(g2, 0, 5, 1, "inner") == nil, "an inner-only tool can't cut through outer bark")
local wrap = BarkGrid.stripCircle(g2, 0, 5, 1)
local wrapped = false
for _, p in (wrap :: any).panels do
	if p[1] == 15 then
		wrapped = true
	end
end
check(wrapped, "strips wrap round the trunk")
check(BarkGrid.stripCircle(g2, 0, 39, 2) ~= nil and BarkGrid.has(g2, 0, 0, 39) == false, "strips near the top stay on the trunk")
-- cork regrowth
local before = BarkGrid.count(g2, BarkGrid.OUTER)
local grew = BarkGrid.regrow(g2, 4)
check(grew == 4 and BarkGrid.count(g2, BarkGrid.OUTER) == before + 4, "cork grows back over living inner bark")
-- saving
local s = BarkGrid.encode(g)
local back = BarkGrid.decode(16, 40, s)
check(back ~= nil and BarkGrid.encode(back :: any) == s and #s < 120, "a stripped tree saves to a short string (" .. #s .. " chars) and loads back")
check(BarkGrid.decode(16, 40, "1:5") == nil, "a damaged save string is rejected, not half-loaded")

-- power
local nodes = {
	crank = { id = "crank", source = true, conducts = true },
	lever = { id = "lever", source = false, conducts = false },
	lamp = { id = "lamp", source = false, conducts = true },
	belt = { id = "belt", source = false, conducts = true },
}
local live = PowerGrid.solve(nodes, { { "crank", "belt" }, { "crank", "lever" }, { "lever", "lamp" } })
check(live.belt == true and live.lever == true and not live.lamp, "power flows along wires but stops at an open lever")
nodes.lever.conducts = true
live = PowerGrid.solve(nodes, { { "crank", "belt" }, { "crank", "lever" }, { "lever", "lamp" } })
check(live.lamp == true, "close the lever and the lamp lights")
local bnodes = { bat = { id = "bat", source = false, conducts = true, battery = 5 }, lamp = { id = "lamp", source = false, conducts = true } }
local blive, feeding = PowerGrid.solve(bnodes, { { "bat", "lamp" } })
check(blive.lamp == true and feeding.bat == true, "a charged battery powers its network when nothing else does")

-- oil
local rich, dry, best = 0, 0, 0
for x = -2000, 2000, 50 do
	for z = -2000, 2000, 50 do
		local v = OilField.richness(x, z)
		best = math.max(best, v)
		if v > 0.5 then
			rich += 1
		elseif v < Config.Oil.minRichness then
			dry += 1
		end
	end
end
check(best > 0.8 and rich > 20, "there are rich oil pockets (" .. rich .. " rich spots)")
check(dry > 3000, "most ground has no oil (" .. dry .. " of 6561 dry)")
check(OilField.richness(123, 456) == OilField.richness(123, 456), "the oil field is the same every time")

-- economy
check(Economy.barkValue(Config, "cedar", 0, 10) == 9.6, "10 panels of cedar outer bark are worth $9.60")
local out = Economy.refine(Config, 8)
check(math.abs(out.fuel_can - 6.4) < 1e-9 and math.abs(out.plastic - 4.8) < 1e-9, "the refinery splits a barrel into fuel and plastic")

-- config sanity: every tool has the Godot numbers a swing needs, every shop tool a model and a description,
-- and Getting started begins at the chopping block
local toolsOk = true
for _, id in Config.ToolOrder do
	local t = (Config.Tools :: any)[id]
	if not t or not t.reach or not t.impact or not t.cooldown or not t.stripRadius or not t.anim then
		toolsOk = false
	end
end
check(toolsOk, "every tool has its reach, swing timing, bark circle and swing shape")
local shopOk = true
for _, id in Config.ShopOrder do
	local t = (Config.Tools :: any)[id]
	local item = (Config.Items :: any)[id]
	if item then
		shopOk = shopOk and item.desc ~= nil and item.price > 0
	elseif not t or not t.look or not t.desc or not t.price or t.price <= 0 or not table.find(Config.ToolOrder, id) then
		shopOk = false
	end
end
check(shopOk, "everything in the shop has a description and a price, and every tool a model and a tool bar place")
check(Config.Tools.double_bit.impacts and #Config.Tools.double_bit.impacts == 2, "the double-bit hits twice a swing")
check(#Config.Tutorial >= 4 and Config.Tutorial[1].check == "hatchet", "Getting started begins with the hatchet in the chopping block")

-- logs: a slice keeps its bark; a bare log is worth 60 a metre at Godot's average radius, a barked one 15% of that
do
	local g = BarkGrid.new(16, 30)
	BarkGrid.stripCircle(g, 3, 25, 1)
	local log = BarkGrid.slice(g, 20, 30)
	check(log.bands == 10 and not BarkGrid.has(log, 0, 3, 5) and BarkGrid.has(log, 0, 3, 0), "a sawn log keeps the bark it had, band for band")
	local full = BarkGrid.new(16, 10)
	check(math.abs(BarkGrid.logValue(full, 2, 0.4) - 18) < 1e-6, "a 2 m log in all its bark is worth $18 (15% of $120)")
	local bare = BarkGrid.new(16, 10)
	buffer.fill(bare.data, 0, 0)
	check(math.abs(BarkGrid.logValue(bare, 2, 0.4) - 120) < 1e-6, "stripped bare, $120")
end

print(string.format("\nROBLOX LOGIC RESULT: %s (%d passed, %d failed)", if fails == 0 then "PASS" else "FAIL", passes, fails))
