--!strict
-- What's under the ground, the Godot game's way (Mining.gd): copper and iron lie in patches (rich in some places,
-- poor in others) and the deeper you go the more there is: topsoil and stone near the surface, copper from about
-- 1.5 m down, iron from about 5 m (and only a tier-2 tool gets it out). Godot's noise is exported as a grid
-- (GodotWorld.ore, every 3 m), so the patches are exactly Godot's.
local W = require(script.Parent.GodotWorld) :: any

local Mining = {}
Mining.COPPER_FROM = 1.5
Mining.IRON_FROM = 5.0
Mining.MAX_DEPTH = 40.0
Mining.KINDS = {
	stone = { name = "Stone", color = "8a8780", fleck = "a39f95", value = 0.4 },
	copper = { name = "Copper ore", color = "7a746c", fleck = "d9783a", value = 3.0 },
	iron = { name = "Iron ore", color = "6e6a66", fleck = "6f80a8", value = 6.0 },
}

-- 0..1: how rich the ground is in copper, iron or oil at (x, z) studs
function Mining.richness(kind: string, x: number, z: number): number
	local g = W.ore
	local data = g and g[kind]
	if not data then
		return 0
	end
	local fx = math.clamp((x - g.origin) / g.step, 0, g.n - 1.001)
	local fz = math.clamp((z - g.origin) / g.step, 0, g.n - 1.001)
	local ix, iz = math.floor(fx), math.floor(fz)
	local tx, tz = fx - ix, fz - iz
	local function h(i: number, k: number): number
		return data[k * g.n + i + 1]
	end
	local a = h(ix, iz) + (h(ix + 1, iz) - h(ix, iz)) * tx
	local b = h(ix, iz + 1) + (h(ix + 1, iz + 1) - h(ix, iz + 1)) * tx
	return a + (b - a) * tz
end

-- what one chunk dug out at this depth (metres) is
function Mining.roll(x: number, z: number, depth: number, tier: number, rnd: (() -> number)?): string
	local r = rnd or math.random
	if depth >= Mining.IRON_FROM and r() < Mining.richness("iron", x, z) * math.clamp((depth - Mining.IRON_FROM) / 6 + 0.35, 0, 0.8) then
		return if tier >= 2 then "iron" else "stone"
	end
	if depth >= Mining.COPPER_FROM and r() < Mining.richness("copper", x, z) * math.clamp((depth - Mining.COPPER_FROM) / 4 + 0.3, 0, 0.7) then
		return "copper"
	end
	return "stone"
end

function Mining.layerName(depth: number): string
	if depth < Mining.COPPER_FROM then
		return "topsoil"
	elseif depth < Mining.IRON_FROM then
		return "copper layer"
	end
	return "iron layer"
end

return Mining
