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

-- Godot's strip_circle (ForestTree.gd), exactly: takes one layer off every panel whose centre is within `circleR`
-- metres of the hit point `hit` (tree-local, metres). The layer is the outermost one at the hit panel (i, j), or
-- `only` (0 outer, 1 inner) for a specialist tool; the inner layer only comes away where the outer is already gone.
-- rOuter / rMid are the outer radii of the outer and inner layers (metres), bandH a panel's height (metres).
function BarkGrid.stripCircleAt(g: Grid, i: number, j: number, hit: { x: number, y: number, z: number }, circleR: number,
	rOuter: number, rMid: number, bandH: number, only: number?): Strip?
	local function strippable(l: number, pi: number, pj: number): boolean
		if l == BarkGrid.OUTER then
			return BarkGrid.has(g, BarkGrid.OUTER, pi, pj)
		end
		return BarkGrid.has(g, BarkGrid.INNER, pi, pj) and not BarkGrid.has(g, BarkGrid.OUTER, pi, pj)
	end
	if j < 0 or j >= g.bands then
		return nil
	end
	local layer = -1
	if only then
		layer = only
	elseif BarkGrid.has(g, BarkGrid.OUTER, i, j) then
		layer = BarkGrid.OUTER
	elseif BarkGrid.has(g, BarkGrid.INNER, i, j) then
		layer = BarkGrid.INNER
	end
	if layer < 0 then
		return nil
	end
	local ro = if layer == BarkGrid.OUTER then rOuter else rMid
	local panels = {}
	if strippable(layer, i, j) then
		table.insert(panels, { i, j })
	end
	local reachJ = math.ceil(circleR / bandH) + 1
	local reachI = math.ceil(circleR / (2 * math.pi * ro / g.sectors)) + 1
	for dj = -reachJ, reachJ do
		for di = -reachI, reachI do
			if di ~= 0 or dj ~= 0 then
				local pi, pj = (i + di) % g.sectors, j + dj
				if pj >= 0 and pj < g.bands and strippable(layer, pi, pj) then
					local a = 2 * math.pi * (pi + 0.5) / g.sectors
					local cx, cy, cz = math.cos(a) * ro, (pj + 0.5) * bandH, math.sin(a) * ro
					local dx, dy, dz = cx - hit.x, cy - hit.y, cz - hit.z
					if dx * dx + dy * dy + dz * dz <= circleR * circleR then
						table.insert(panels, { pi, pj })
					end
				end
			end
		end
	end
	if #panels == 0 then
		return nil
	end
	for _, p in panels do
		clear(g, layer, p[1], p[2])
	end
	return { layer = layer, panels = panels }
end

-- Godot's strip_through: every panel in the area loses its outer bark AND the inner bark under it in one go. The
-- area is a circle of `circleR` metres round the hit, or (grid > 0) a square of grid x grid panels centred on (i, j).
-- Returns a strip per layer that lost something.
function BarkGrid.stripThrough(g: Grid, i: number, j: number, hit: { x: number, y: number, z: number }, circleR: number,
	rOuter: number, bandH: number, grid: number?): { Strip }
	local area = {}
	if grid and grid > 0 then
		local h = grid // 2
		for dj = -h, grid - h - 1 do
			for di = -h, grid - h - 1 do
				local pj = j + dj
				if pj >= 0 and pj < g.bands then
					table.insert(area, { (i + di) % g.sectors, pj })
				end
			end
		end
	else
		local reachJ = math.ceil(circleR / bandH) + 1
		local reachI = math.ceil(circleR / (2 * math.pi * rOuter / g.sectors)) + 1
		for dj = -reachJ, reachJ do
			for di = -reachI, reachI do
				local pi, pj = (i + di) % g.sectors, j + dj
				if pj >= 0 and pj < g.bands then
					local a = 2 * math.pi * (pi + 0.5) / g.sectors
					local dx, dy, dz = math.cos(a) * rOuter - hit.x, (pj + 0.5) * bandH - hit.y, math.sin(a) * rOuter - hit.z
					if (di == 0 and dj == 0) or dx * dx + dy * dy + dz * dz <= circleR * circleR then
						table.insert(area, { pi, pj })
					end
				end
			end
		end
	end
	local out = {}
	for _, layer in { BarkGrid.OUTER, BarkGrid.INNER } do
		local got = {}
		for _, p in area do
			if BarkGrid.has(g, layer, p[1], p[2]) then
				table.insert(got, p)
			end
		end
		if #got > 0 then
			for _, p in got do
				clear(g, layer, p[1], p[2])
			end
			table.insert(out, { layer = layer, panels = got })
		end
	end
	return out
end

-- Godot's strip_ring (the ringing axe): the whole band at the hit height, all the way round, from the outermost
-- layer at the hit.
function BarkGrid.stripRing(g: Grid, i: number, j: number): Strip?
	if j < 0 or j >= g.bands then
		return nil
	end
	local layer = if BarkGrid.has(g, BarkGrid.OUTER, i, j) then BarkGrid.OUTER elseif BarkGrid.has(g, BarkGrid.INNER, i, j) then BarkGrid.INNER else -1
	if layer < 0 then
		return nil
	end
	local panels = {}
	for k = 0, g.sectors - 1 do
		local pi = (i + k) % g.sectors
		if BarkGrid.has(g, layer, pi, j) and (layer == BarkGrid.OUTER or not BarkGrid.has(g, BarkGrid.OUTER, pi, j)) then
			table.insert(panels, { pi, j })
		end
	end
	for _, p in panels do
		clear(g, layer, p[1], p[2])
	end
	return if #panels > 0 then { layer = layer, panels = panels } else nil
end

-- Godot's strip_panels: the given panels, each from whichever layer is outermost there. A strip per layer.
function BarkGrid.stripPanels(g: Grid, list: { { number } }): { Strip }
	local got: { [number]: { { number } } } = { [0] = {}, [1] = {} }
	local seen = {}
	for _, p in list do
		local pi, pj = p[1] % g.sectors, p[2]
		if pj >= 0 and pj < g.bands then
			local layer = if BarkGrid.has(g, BarkGrid.OUTER, pi, pj) then BarkGrid.OUTER elseif BarkGrid.has(g, BarkGrid.INNER, pi, pj) then BarkGrid.INNER else -1
			local key = layer .. ":" .. pi .. ":" .. pj
			if layer >= 0 and not seen[key] then
				seen[key] = true
				table.insert(got[layer], { pi, pj })
			end
		end
	end
	local out = {}
	for _, layer in { BarkGrid.OUTER, BarkGrid.INNER } do
		if #got[layer] > 0 then
			for _, p in got[layer] do
				clear(g, layer, p[1], p[2])
			end
			table.insert(out, { layer = layer, panels = got[layer] })
		end
	end
	return out
end

-- Godot's strip_soft (the pressure washer): the `most` panels nearest the hit within `circleR` metres, each from
-- whichever layer is outermost there. `hit` is in the tree's own frame, metres; rOuter is the bark's radius.
function BarkGrid.stripSoft(g: Grid, i: number, j: number, hit: { x: number, y: number, z: number }, circleR: number,
	rOuter: number, bandH: number, most: number): { Strip }
	local reachJ = math.ceil(circleR / bandH) + 1
	local reachI = math.ceil(circleR / (2 * math.pi * rOuter / g.sectors)) + 1
	local cand = {}
	for dj = -reachJ, reachJ do
		for di = -reachI, reachI do
			local pi, pj = (i + di) % g.sectors, j + dj
			if pj >= 0 and pj < g.bands and (BarkGrid.has(g, BarkGrid.OUTER, pi, pj) or BarkGrid.has(g, BarkGrid.INNER, pi, pj)) then
				local a = 2 * math.pi * (pi + 0.5) / g.sectors
				local dx, dy, dz = math.cos(a) * rOuter - hit.x, (pj + 0.5) * bandH - hit.y, math.sin(a) * rOuter - hit.z
				local d = math.sqrt(dx * dx + dy * dy + dz * dz)
				if d <= circleR then
					table.insert(cand, { d, pi, pj })
				end
			end
		end
	end
	table.sort(cand, function(a, b)
		return a[1] < b[1]
	end)
	local list = {}
	for k = 1, math.min(most, #cand) do
		table.insert(list, { cand[k][2], cand[k][3] })
	end
	return BarkGrid.stripPanels(g, list)
end

-- Godot's strip_column (the electric planer): the whole run of the outermost layer's panels in the hit's column
-- (or the next column round that still has bark), top to bottom, as one long strip.
function BarkGrid.stripColumn(g: Grid, i: number, j: number): Strip?
	local function strippable(l: number, pi: number, pj: number): boolean
		if l == BarkGrid.OUTER then
			return BarkGrid.has(g, BarkGrid.OUTER, pi, pj)
		end
		return BarkGrid.has(g, BarkGrid.INNER, pi, pj) and not BarkGrid.has(g, BarkGrid.OUTER, pi, pj)
	end
	if j < 0 or j >= g.bands then
		return nil
	end
	local function layerAt(pi: number): number
		return if BarkGrid.has(g, BarkGrid.OUTER, pi, j) then BarkGrid.OUTER elseif BarkGrid.has(g, BarkGrid.INNER, pi, j) then BarkGrid.INNER else -1
	end
	local l = layerAt(i)
	if l < 0 then
		for _, k in { 1, -1, 2, -2 } do
			if layerAt((i + k) % g.sectors) >= 0 then
				i = (i + k) % g.sectors
				l = layerAt(i)
				break
			end
		end
	end
	if l < 0 then
		return nil
	end
	i %= g.sectors
	local j0 = j
	while j0 > 0 and strippable(l, i, j0 - 1) do
		j0 -= 1
	end
	local panels = {}
	local k = j0
	while k < g.bands and strippable(l, i, k) do
		table.insert(panels, { i, k })
		k += 1
	end
	if #panels == 0 then
		return nil
	end
	for _, p in panels do
		clear(g, l, p[1], p[2])
	end
	return { layer = l, panels = panels }
end

-- Godot's strip_all (the Thunder Axe): every panel left, both layers, in sheets of block x block panels.
function BarkGrid.stripAll(g: Grid, block: number): { Strip }
	local out = {}
	for _, layer in { BarkGrid.OUTER, BarkGrid.INNER } do
		for j0 = 0, g.bands - 1, block do
			for i0 = 0, g.sectors - 1, block do
				local panels = {}
				for j = j0, math.min(j0 + block, g.bands) - 1 do
					for i = i0, i0 + block - 1 do
						if BarkGrid.has(g, layer, i, j) then
							table.insert(panels, { i % g.sectors, j })
						end
					end
				end
				if #panels > 0 then
					for _, p in panels do
						clear(g, layer, p[1], p[2])
					end
					table.insert(out, { layer = layer, panels = panels })
				end
			end
		end
	end
	return out
end

-- Bands j0 .. j1-1 of a grid as a grid of their own (a log sawn off a tree keeps its bark, Godot's setup_section).
function BarkGrid.slice(g: Grid, j0: number, j1: number): Grid
	local out = BarkGrid.new(g.sectors, j1 - j0)
	for layer = 0, 1 do
		for j = j0, j1 - 1 do
			for i = 0, g.sectors - 1 do
				if not BarkGrid.has(g, layer, i, j) then
					clear(out, layer, i, j - j0)
				end
			end
		end
	end
	return out
end

-- How much of the bark is still on (0..1): both layers, every panel (Godot's Log.value)
function BarkGrid.fraction(g: Grid): number
	local left = 0
	local n = buffer.len(g.data)
	for k = 0, n - 1 do
		left += buffer.readu8(g.data, k)
	end
	return left / math.max(n, 1)
end

-- What the mill pays for a log (Godot's Log.value): clean timber is worth a lot, but bark left on drags it down -
-- a log still in all its bark fetches only 15% of what the same log stripped bare would. Metres.
function BarkGrid.logValue(g: Grid, lengthM: number, radiusM: number): number
	local clean = 60 * lengthM * (radiusM / 0.4) ^ 2
	return clean * (1 - 0.85 * BarkGrid.fraction(g))
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
