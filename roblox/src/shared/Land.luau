--!strict
-- Land, the Godot game's way (Land.gd): the world is cut into 20 m plots; you start with the four around the cabin
-- and can only build on land you own. A "for sale" sign stands just past your border on every plot next to yours:
-- E on it buys that plot, each costing more than the last. (Trees and rocks can be harvested anywhere.)
-- Plots are keyed "x,z" (whole plots from the origin, like Godot's). Pure Luau maths, studs in, keys out.
local Land = {}
Land.PLOT = 20 * 3          -- studs
Land.LIMIT = 5              -- plots go out to +-5 (the edge of the map)
Land.START = { "-1,-1", "-1,0", "0,-1", "0,0" }

function Land.keyAt(p: Vector3): string
	return string.format("%d,%d", math.floor(p.X / Land.PLOT), math.floor(p.Z / Land.PLOT))
end

function Land.owns(land: { string }, p: Vector3): boolean
	return table.find(land, Land.keyAt(p)) ~= nil
end

-- Godot's next_price: 400, then 1.7 times as much for each plot bought, rounded to 10
function Land.nextPrice(land: { string }): number
	local bought = math.max(0, #land - #Land.START)
	return math.floor(400 * 1.7 ^ bought / 10 + 0.5) * 10
end

-- Where the for-sale signs go: on each plot next to yours that you could buy, on the shared edge, 2 m into it.
-- Returns { key, x, z } in studs. And the corner stakes round everything you own: { x, z }.
function Land.signs(land: { string }): ({ { key: string, x: number, z: number } }, { { x: number, z: number } })
	local own = {}
	for _, k in land do
		own[k] = true
	end
	local signs, seen, corners, cseen = {}, {}, {}, {}
	for _, k in land do
		local xz = string.split(k, ",")
		local px, pz = tonumber(xz[1]) :: number, tonumber(xz[2]) :: number
		for dx = 0, 1 do
			for dz = 0, 1 do
				local ck = (px + dx) .. "," .. (pz + dz)
				if not cseen[ck] then
					cseen[ck] = true
					table.insert(corners, { x = (px + dx) * Land.PLOT, z = (pz + dz) * Land.PLOT })
				end
			end
		end
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, nz = px + d[1], pz + d[2]
			local nk = nx .. "," .. nz
			if own[nk] or seen[nk] or math.abs(nx) > Land.LIMIT or math.abs(nz) > Land.LIMIT
				or math.abs(nx + 1) > Land.LIMIT + 1 or math.abs(nz + 1) > Land.LIMIT + 1 then
				continue
			end
			seen[nk] = true
			local mx = (px + 0.5) * Land.PLOT + d[1] * (Land.PLOT * 0.5 + 2 * 3)
			local mz = (pz + 0.5) * Land.PLOT + d[2] * (Land.PLOT * 0.5 + 2 * 3)
			table.insert(signs, { key = nk, x = mx, z = mz })
		end
	end
	return signs, corners
end

return Land
