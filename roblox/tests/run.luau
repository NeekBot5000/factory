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

-- config sanity: every shop tool has a look, a price that climbs, and the quests are in order
local lastPrice = 0
local shopOk = true
for _, id in Config.ShopOrder do
	local t = (Config.Tools :: any)[id]
	if not t or not t.look or not t.desc or t.price < lastPrice then
		shopOk = false
	end
	lastPrice = t and t.price or lastPrice
end
check(shopOk, "every tool in the shop has a model, a description and a price at least the one before")
check(#Config.Quests >= 4 and Config.Quests[1].id == "peel", "the starter quests begin with peeling")

print(string.format("\nROBLOX LOGIC RESULT: %s (%d passed, %d failed)", if fails == 0 then "PASS" else "FAIL", passes, fails))
