--!strict
-- Where the oil is: a smooth noise field, the same on server and client and in tests (deterministic, no
-- math.noise so the command-line tests get the same numbers). Most ground has none; a few big pockets are rich.

local OilField = {}

-- an exact 32-bit hash of a grid cell (xorshift, no float rounding, so every platform agrees)
local function hash(x: number, z: number, seed: number): number
	local h = bit32.bxor(bit32.band(x * 73856093, 0xFFFFFFFF), bit32.band(z * 19349663, 0xFFFFFFFF), bit32.band(seed * 83492791, 0xFFFFFFFF))
	for _ = 1, 3 do
		h = bit32.bxor(h, bit32.lshift(h, 13))
		h = bit32.bxor(h, bit32.rshift(h, 17))
		h = bit32.bxor(h, bit32.lshift(h, 5))
	end
	return (h % 100000) / 100000
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- value noise in 0..1, cell size `scale` studs
local function noise(x: number, z: number, scale: number, seed: number): number
	local fx, fz = x / scale, z / scale
	local ix, iz = math.floor(fx), math.floor(fz)
	local tx, tz = smooth(fx - ix), smooth(fz - iz)
	local a = hash(ix, iz, seed)
	local b = hash(ix + 1, iz, seed)
	local c = hash(ix, iz + 1, seed)
	local d = hash(ix + 1, iz + 1, seed)
	return (a + (b - a) * tx) + ((c + (d - c) * tx) - (a + (b - a) * tx)) * tz
end

-- 0..1: how rich the oil under (x, z) is
function OilField.richness(x: number, z: number, seed: number?): number
	local n = noise(x, z, 160, seed or 7171) * 0.7 + noise(x, z, 60, (seed or 7171) + 1) * 0.3
	return math.clamp((n - 0.62) * 3.2, 0, 1)
end

-- barrels a pump fills per second here
function OilField.pumpRate(x: number, z: number, cfg: { minRichness: number, barrelsPerSecondAtFull: number }): number
	local r = OilField.richness(x, z)
	if r < cfg.minRichness then
		return 0
	end
	return cfg.barrelsPerSecondAtFull * r
end

return OilField
