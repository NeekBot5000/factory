--!strict
-- Track, the Godot game's way (Rail.gd): a laid rail is one 1 m grid square, straight (along X or along Z) or a
-- curve joining two neighbouring sides. Laid rails are Models in workspace.Rails with attributes Cell ("x,z", in
-- metres), AlongX, Curve (-1 straight, 0..3 a curve joining DIRS[curve] and DIRS[curve + 1]), Value and, while a
-- powered rail switch works it, Branch ("dx,dz;dx,dz": the two ways it leads instead). Shared so the client can
-- check a minecart's placement against the same track.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Rail = {}
local M = Config.StudsPerMetre
Rail.TOP = 0.13         -- metres above a rail's origin that a cart's wheels sit
Rail.VALUE = 2.0        -- what a rail item is worth (Godot's Product.RAIL_VALUE)

export type Cell = { x: number, z: number }
-- north, east, south, west on the grid (Godot's DIRS: Vector2i(0, -1), (1, 0), (0, 1), (-1, 0))
Rail.DIRS = { { x = 0, z = -1 }, { x = 1, z = 0 }, { x = 0, z = 1 }, { x = -1, z = 0 } } :: { Cell }

function Rail.cellOf(p: Vector3): Cell
	return { x = math.round(p.X / M), z = math.round(p.Z / M) }
end

function Rail.key(c: Cell): string
	return c.x .. "," .. c.z
end

function Rail.centre(c: Cell, y: number): Vector3
	return Vector3.new(c.x * M, y, c.z * M)
end

function Rail.add(a: Cell, b: Cell, k: number?): Cell
	local n = k or 1
	return { x = a.x + b.x * n, z = a.z + b.z * n }
end

function Rail.same(a: Cell, b: Cell): boolean
	return a.x == b.x and a.z == b.z
end

-- the laid rail on a grid square, if any
function Rail.at(c: Cell): Model?
	local f = workspace:FindFirstChild("Rails")
	local r = f and f:FindFirstChild(Rail.key(c))
	return if r and r:IsA("Model") then r else nil
end

-- the two directions (out of its square) the track on a rail leads
function Rail.links(r: Model): { Cell }
	local curve = r:GetAttribute("Curve") :: number? or -1
	if curve >= 0 then
		return { Rail.DIRS[curve + 1], Rail.DIRS[(curve + 1) % 4 + 1] }
	end
	local br = r:GetAttribute("Branch") :: string?
	if br and br ~= "" then
		local out = {}
		for _, s in string.split(br, ";") do
			local xz = string.split(s, ",")
			table.insert(out, { x = tonumber(xz[1]) or 0, z = tonumber(xz[2]) or 0 })
		end
		return out
	end
	if r:GetAttribute("AlongX") then
		return { { x = 1, z = 0 }, { x = -1, z = 0 } }
	end
	return { { x = 0, z = 1 }, { x = 0, z = -1 } }
end

function Rail.leads(r: Model, d: Cell): boolean
	for _, l in Rail.links(r) do
		if Rail.same(l, d) then
			return true
		end
	end
	return false
end

-- where a cart's wheels sit on a rail (studs)
function Rail.top(r: Model): number
	return r:GetPivot().Position.Y + Rail.TOP * M
end

-- the grid direction a CFrame faces (its front is -Z, as in Godot)
function Rail.dirOf(cf: CFrame): Cell
	local f = cf.LookVector
	if math.abs(f.X) > math.abs(f.Z) then
		return { x = if f.X > 0 then 1 else -1, z = 0 }
	end
	return { x = 0, z = if f.Z > 0 then 1 else -1 }
end

-- the rails under a whole cart, for placing one: all there, the front one running the cart's way (Minecart.fits)
function Rail.fits(c: Cell, d: Cell, n: number): boolean
	for k = 0, n - 1 do
		local r = Rail.at(Rail.add(c, d, -k))
		if not r or (k == 0 and not (Rail.leads(r, d) or Rail.leads(r, { x = -d.x, z = -d.z }))) then
			return false
		end
	end
	return true
end

return Rail
