--!strict
-- A tree's bark as two layers of panels (outer, then inner), `sectors` round and `bands` high, one byte per panel
-- in a Luau buffer (a 16 x 40 tree is 1.3 KB, not 1,280 Parts). The server owns the grid; clients only ever see the
-- meshes built from it. Pure Luau: no Roblox calls, so it runs in the command-line tests too.

local BarkGrid = {}
BarkGrid.__index = BarkGrid

export type Strip = { layer: number, panels: { { number } } }

export type Grid = {
	sectors: number,
	bands: number,
	data: buffer,       -- [layer][band][sector], 1 = panel present
}

BarkGrid.OUTER = 0
BarkGrid.INNER = 1

function BarkGrid.new(sectors: number, bands: number): Grid
	local data = buffer.create(sectors * bands * 2)
	buffer.fill(data, 0, 1)
	return { sectors = sectors, bands = bands, data = data }
end

local function index(g: Grid, layer: number, i: number, j: number): number
	return (layer * g.bands + j) * g.sectors + (i % g.sectors)
end

function BarkGrid.has(g: Grid, layer: number, i: number, j: number): boolean
	if j < 0 or j >= g.bands then
		return false
	end
	return buffer.readu8(g.data, index(g, layer, i, j)) == 1
end

local function clear(g: Grid, layer: number, i: number, j: number)
	buffer.writeu8(g.data, index(g, layer, i, j), 0)
end

-- Takes one layer off in a circle around panel (i, j): the outer layer if it's there at the centre, else the inner.
-- The inner layer only comes away where the outer is already gone. `only` limits it to "outer" or "inner".
-- Returns {layer, panels = {{i, j}, ...}} or nil if nothing came off.
function BarkGrid.stripCircle(g: Grid, i: number, j: number, radius: number, only: string?): Strip?
	local layer: number
	if BarkGrid.has(g, BarkGrid.OUTER, i, j) then
		layer = BarkGrid.OUTER
	elseif BarkGrid.has(g, BarkGrid.INNER, i, j) then
		layer = BarkGrid.INNER
	else
		return nil
	end
	if only == "outer" and layer ~= BarkGrid.OUTER then
		return nil
	end
	if only == "inner" and layer ~= BarkGrid.INNER then
		return nil
	end
	local panels = {}
	local r2 = (radius + 0.5) * (radius + 0.5)
	for dj = -radius, radius do
		for di = -radius, radius do
			if di * di + dj * dj <= r2 then
				local pi, pj = (i + di) % g.sectors, j + dj
				if BarkGrid.has(g, layer, pi, pj) and (layer == BarkGrid.OUTER or not BarkGrid.has(g, BarkGrid.OUTER, pi, pj)) then
					clear(g, layer, pi, pj)
					table.insert(panels, { pi, pj })
				end
			end
		end
	end
	if #panels == 0 then
		return nil
	end
	return { layer = layer, panels = panels }
end

-- Cork: grows back up to `n` outer panels over still-living inner bark. Returns how many grew.
function BarkGrid.regrow(g: Grid, n: number): number
	local grew = 0
	for j = 0, g.bands - 1 do
		for i = 0, g.sectors - 1 do
			if not BarkGrid.has(g, BarkGrid.OUTER, i, j) and BarkGrid.has(g, BarkGrid.INNER, i, j) then
				buffer.writeu8(g.data, index(g, BarkGrid.OUTER, i, j), 1)
				grew += 1
				if grew >= n then
					return grew
				end
			end
		end
	end
	return grew
end

function BarkGrid.count(g: Grid, layer: number): number
	local n = 0
	for j = 0, g.bands - 1 do
		for i = 0, g.sectors - 1 do
			if BarkGrid.has(g, layer, i, j) then
				n += 1
			end
		end
	end
	return n
end

-- Saving: run-length encoded, because almost every tree is either untouched or has a few patches off.
-- "1:640,0:12,1:628" style, compact and safe for DataStores (plain text).
function BarkGrid.encode(g: Grid): string
	local out = {}
	local n = buffer.len(g.data)
	local cur = buffer.readu8(g.data, 0)
	local run = 0
	for k = 0, n - 1 do
		local v = buffer.readu8(g.data, k)
		if v == cur then
			run += 1
		else
			table.insert(out, cur .. ":" .. run)
			cur, run = v, 1
		end
	end
	table.insert(out, cur .. ":" .. run)
	return table.concat(out, ",")
end

function BarkGrid.decode(sectors: number, bands: number, s: string): Grid?
	local g = BarkGrid.new(sectors, bands)
	local k = 0
	for v, run in string.gmatch(s, "(%d):(%d+)") do
		local val, len = tonumber(v) :: number, tonumber(run) :: number
		if k + len > buffer.len(g.data) then
			return nil
		end
		buffer.fill(g.data, k, val, len)
		k += len
	end
	if k ~= buffer.len(g.data) then
		return nil
	end
	return g
end

return BarkGrid
