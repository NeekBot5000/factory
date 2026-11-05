--!strict
-- How bark looks, the Godot game's way (ForestTree._panel_color / _corner): shared by the client, which draws the
-- trunks, and the server, which makes the sheets that come off them, so a sheet is exactly the panels it was.
local Config = require(script.Parent.Config)

local BarkLook = {}
local T = Config.Tree
local M = Config.StudsPerMetre

local function shade(c: Color3, k: number): Color3
	-- Godot's Color.lightened (k > 0) / darkened (k < 0)
	return if k >= 0 then c:Lerp(Color3.new(1, 1, 1), k) else c:Lerp(Color3.new(0, 0, 0), -k)
end
BarkLook.shade = shade

-- a fixed pseudo-random 0..1 for a panel (Godot hashes (i, j, seed + layer * 7) the same way every time)
local function hash01(i: number, j: number, seed: number): number
	local h = bit32.bxor(bit32.band(i * 73856093, 0xFFFFFFFF), bit32.band(j * 19349663, 0xFFFFFFFF), bit32.band(seed * 83492791, 0xFFFFFFFF))
	h = bit32.band(bit32.bxor(h, bit32.rshift(h, 13)) * 1274126177, 0xFFFFFFFF)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return (h % 1000) / 1000
end

-- the colour of one panel: layer 0 is the outer bark, 1 the inner
-- golden: the golden tree event's tree (EventService): its outer bark is gold
function BarkLook.panelColor(species: string, layer: number, i: number, j: number, seed: number, golden: boolean?): Color3
	local sp = (Config.Species :: any)[species] or Config.Species.oak
	local h = hash01(i, j, seed + layer * 7)
	if golden and layer == 0 then
		return shade(Color3.fromHex("e8b53a"), (h - 0.5) * 0.3)
	end
	if layer == 0 then
		local bark = Color3.fromHex(sp.bark)
		if species == "birch" then
			return if h < 0.12 then shade(bark, -0.35) else shade(bark, -h * 0.08)
		end
		return shade(bark, (h - 0.5) * 0.18)
	end
	return shade(Color3.fromHex(sp.inner), (h - 0.5) * 0.12)
end

-- what's under a sheet of this layer: inner bark under the outer, the wood (a touch darker) under the inner
function BarkLook.underColor(species: string, layer: number): Color3
	local sp = (Config.Species :: any)[species] or Config.Species.oak
	return if layer == 0 then Color3.fromHex(sp.inner) else shade(Color3.fromHex(sp.wood), -0.05)
end

-- the outer radius (studs) of a layer on a tree of radius R, and its thickness
function BarkLook.layerRadius(R: number, layer: number): (number, number)
	if layer == 0 then
		return R, T.outerT * M
	end
	return R - T.outerT * M, T.innerT * M
end

-- Where panel (i, j) sits: its centre and the way its face looks (out from the trunk), for a block of the given
-- thickness whose outer face is Godot's quad between corners i and i+1 at radius rOut. Also its size.
function BarkLook.panel(base: CFrame, sectors: number, i: number, j: number, rOut: number, thick: number): (CFrame, Vector3)
	local half = math.pi / sectors
	local chord = 2 * rOut * math.sin(half)
	local a = (i + 0.5) / sectors * 2 * math.pi
	local bandH = T.bandH * M
	local face = rOut * math.cos(half)
	-- Godot's angle runs from +X towards +Z: x = cos(a) r, z = sin(a) r
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local center = base.Position + base:VectorToWorldSpace(dir * (face - thick / 2) + Vector3.new(0, (j + 0.5) * bandH, 0))
	local out = base:VectorToWorldSpace(dir)
	-- (built from vectors, not CFrame.lookAt: -Z faces out of the trunk, Y stays up the trunk)
	local up = base:VectorToWorldSpace(Vector3.yAxis)
	local right = up:Cross(-out)
	return CFrame.fromMatrix(center, right, up, -out), Vector3.new(chord * 1.005, bandH, thick)
end

return BarkLook
