--!strict
-- Rails and minecarts, the Godot game's way (Rail.gd, Minecart.gd, CartPart.gd, TrackPart.gd).
--   Rails: the hammer on a loose rail lays it on the grid square it's lying on (lined up with the track next to it;
--     a curve joins up with the rails beside it); on a laid rail it picks it up again; R turns it.
--   Minecarts (1-4 squares long) go on rails. Drop a charged battery cell into the cradle at the back (E takes it out):
--     while it has charge the cart powers the machines on its deck. It rolls one square at a time (1.6 m/s) while a
--     Go (or Reverse) block on its deck is powered, round curves, and stops where the track ends. Riders ride along.
--   Rail Layer / Rail Lifter on the deck lay track ahead from a deck crate / pick up the track behind into one.
--   Rail Switch: beside a straight rail, pointing along it; powered, that rail branches away from the switch.
--   Rail Buffer: carts stop at the square in front of it while it's off. Cart Unloader: powered, it takes things
--   out of a crate on the cart behind it. Drone Pad: powered, it charges battery cells left on it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Rail = require(ReplicatedStorage.Shared.Rail)
local Land = require(ReplicatedStorage.Shared.Land)

local RailService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
RailService.SPEED = 1.6           -- m/s
RailService.DRAIN_MOVE = 0.008    -- of a full cell per second per deck square while rolling
RailService.DRAIN_IDLE = 0.0005   -- while it powers its deck
RailService.DECK_Y = 0.45         -- deck top, above the rail
RailService.SETTLE = 0.12         -- after a step, wait for the circuit to catch up
RailService.UNLOAD_EVERY = 0.4
RailService.PAD_RATE = 0.08
local IRON, WOOD = Color3.fromHex("8d949e"), Color3.fromHex("6b4a32")

local function folder(name: string): Instance
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f :: Instance
end

local function builds(): { Model }
	local out = {}
	local f = workspace:FindFirstChild("Builds")
	for _, m in if f then f:GetChildren() else {} do
		if m:IsA("Model") then
			table.insert(out, m)
		end
	end
	return out
end

local function isCart(m: Instance): boolean
	return string.sub(m:GetAttribute("Build") :: string? or "", 1, 9) == "minecart_"
end

local function cartLength(m: Model): number
	return math.clamp(tonumber(string.sub(m:GetAttribute("Build") :: string, 10)) or 1, 1, 4)
end

-- ------------------------------------------------------------------ laying track
-- the ground (or platform, or pillar top) under a grid square, near a height; the terrain if nothing's there
local function ground(c: Rail.Cell, nearY: number?): number
	local WorldService = require(script.Parent.WorldService) :: any
	local fallback = WorldService.heightAt(c.x * M, c.z * M)
	local y = nearY or fallback
	local params = RaycastParams.new()
	local skip: { Instance } = {}
	for _, n in { "Builds", "Plans", "Rails", "Loose", "Logs", "Forest" } do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(skip, f)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(Vector3.new(c.x * M, y + 1 * M, c.z * M), Vector3.new(0, -4 * M, 0), params)
	return if hit then hit.Position.Y else fallback
end

local function piece(m: Model, size: Vector3, cf: CFrame, color: Color3)
	local p = Instance.new("Part")
	p.Size = size * M
	p.CFrame = m:GetPivot() * CFrame.new(cf.Position * M) * cf.Rotation
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Parent = m
end

-- builds a rail's model (Rail.setup): three sleepers and two rails, or a quarter-circle for a curve
local function build(m: Model)
	for _, ch in m:GetChildren() do
		ch:Destroy()
	end
	local c = string.split(m.Name, ",")
	local x, z = tonumber(c[1]) or 0, tonumber(c[2]) or 0
	local y = m:GetAttribute("Y") :: number? or 0
	local curve = m:GetAttribute("Curve") :: number? or -1
	local base = CFrame.new(x * M, y, z * M)
	local anchor = Instance.new("Part")
	anchor.Name = "Bed"
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(0.9, 0.12, 0.9) * M
	if curve >= 0 then
		-- built joining north and east, then turned (clockwise seen from above) to join DIRS[curve] and DIRS[curve+1]
		m.WorldPivot = base * CFrame.Angles(0, -curve * math.pi * 0.5, 0)
		anchor.CFrame = m.WorldPivot * CFrame.new(0, 0.06 * M, 0)
		anchor.Parent = m
		local corner = Vector3.new(0.5, 0, -0.5)
		for k = 0, 2 do
			local a = (k + 0.5) / 3 * math.pi * 0.5
			piece(m, Vector3.new(0.8, 0.06, 0.14), CFrame.new(corner + Vector3.new(-math.cos(a), 0, math.sin(a)) * 0.5 + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, -a + math.pi * 0.5, 0), WOOD)
		end
		for _, rr in { 0.25, 0.75 } do
			for k = 0, 4 do
				local a0, a1 = k / 5 * math.pi * 0.5, (k + 1) / 5 * math.pi * 0.5
				local p0 = corner + Vector3.new(-math.cos(a0), 0, math.sin(a0)) * rr
				local p1 = corner + Vector3.new(-math.cos(a1), 0, math.sin(a1)) * rr
				piece(m, Vector3.new(0.06, 0.07, (p1 - p0).Magnitude + 0.02), CFrame.new((p0 + p1) * 0.5 + Vector3.new(0, 0.09, 0)) * CFrame.Angles(0, math.atan2(p1.X - p0.X, p1.Z - p0.Z), 0), IRON)
			end
		end
	else
		m.WorldPivot = base * CFrame.Angles(0, if m:GetAttribute("AlongX") then math.pi * 0.5 else 0, 0)
		anchor.CFrame = m.WorldPivot * CFrame.new(0, 0.06 * M, 0)
		anchor.Parent = m
		for k = 0, 2 do
			piece(m, Vector3.new(0.8, 0.06, 0.14), CFrame.new(0, 0.03, -0.33 + k * 0.33), WOOD)
		end
		for _, sx in { -0.25, 0.25 } do
			piece(m, Vector3.new(0.06, 0.07, 1.0), CFrame.new(sx, 0.09, 0), IRON)
		end
	end
end

local function make(c: Rail.Cell, alongX: boolean, curve: number, y: number, owner: number?, value: number?): Model
	local m = Instance.new("Model")
	m.Name = Rail.key(c)
	m:SetAttribute("Kind", "rail")
	m:SetAttribute("Cell", Rail.key(c))
	m:SetAttribute("AlongX", alongX)
	m:SetAttribute("Curve", curve)
	m:SetAttribute("Y", y)
	m:SetAttribute("Value", value or Rail.VALUE)
	if owner then
		m:SetAttribute("Owner", owner)
	end
	build(m)
	m.Parent = folder("Rails")
	return m
end

-- lays a straight rail on a grid square, lined up with track that leads into it. nil if the square is taken.
function RailService.lay(c: Rail.Cell, alongX: boolean, nearY: number?, owner: number?, value: number?): Model?
	if Rail.at(c) then
		return nil
	end
	local y = ground(c, nearY)
	for _, d in Rail.DIRS do
		local n = Rail.at(Rail.add(c, d))
		if n and Rail.leads(n, { x = -d.x, z = -d.z }) then
			alongX = d.x ~= 0
		end
	end
	return make(c, alongX, -1, y, owner, value)
end

-- lays a curve: it joins up with the rails next to it if two of them meet here at a right angle (or one does,
-- turning the way you're facing); otherwise it comes in from behind you and turns right
function RailService.layCurve(c: Rail.Cell, facing: Rail.Cell, nearY: number?, owner: number?, value: number?): Model?
	if Rail.at(c) then
		return nil
	end
	local open = {}
	for i = 0, 3 do
		local d = Rail.DIRS[i + 1]
		local n = Rail.at(Rail.add(c, d))
		if n and Rail.leads(n, { x = -d.x, z = -d.z }) then
			table.insert(open, i)
		end
	end
	local fi = 0
	for i = 0, 3 do
		if Rail.same(Rail.DIRS[i + 1], facing) then
			fi = i
		end
	end
	local k = (fi + 1) % 4
	if #open >= 2 then
		for _, a in open do
			if table.find(open, (a + 1) % 4) then
				k = a
				break
			end
		end
	elseif #open == 1 then
		local a = open[1]
		k = if (a + 3) % 4 == fi then (a + 3) % 4 else a
	end
	return make(c, false, k, ground(c, nearY), owner, value)
end

-- R with the hammer: a straight rail swaps between along X and along Z; a curve turns a quarter
function RailService.turn(r: Model)
	local curve = r:GetAttribute("Curve") :: number? or -1
	if curve >= 0 then
		r:SetAttribute("Curve", (curve + 1) % 4)
	else
		r:SetAttribute("AlongX", not r:GetAttribute("AlongX"))
	end
	build(r)
end

-- picks a rail up: it turns back into a loose rail item
function RailService.lift(r: Model): BasePart
	local PS = require(script.Parent.ProductionService) :: any
	local kind = if (r:GetAttribute("Curve") :: number? or -1) >= 0 then "curved_rail" else "rail"
	local at = r:GetPivot().Position + Vector3.new(0, 0.4 * M, 0)
	local item = PS.product(kind, r:GetAttribute("Value") :: number? or Rail.VALUE, IRON, CFrame.new(at), Vector3.zero, r:GetAttribute("Owner"))
	r:Destroy()
	return item
end

-- ------------------------------------------------------------------ minecarts
type CartState = { t: number, from: CFrame, to: CFrame, fwd: boolean, settle: number, arrive: Rail.Cell, lift: Rail.Cell? }
local carts: { [string]: CartState } = {}       -- (by the cart's Uid)

local function stateOf(m: Model): CartState
	local uid = m:GetAttribute("Uid") :: string? or "?"
	local s = carts[uid]
	if not s then
		s = { t = -1, from = m:GetPivot(), to = m:GetPivot(), fwd = true, settle = 0, arrive = Rail.cellOf(m:GetPivot().Position), lift = nil }
		carts[uid] = s
	end
	return s :: CartState
end

function RailService.dir(m: Model): Rail.Cell
	return Rail.dirOf(m:GetPivot())
end

function RailService.frontCell(m: Model): Rail.Cell
	return Rail.cellOf(m:GetPivot().Position)
end

function RailService.rearCell(m: Model): Rail.Cell
	return Rail.add(RailService.frontCell(m), RailService.dir(m), -(cartLength(m) - 1))
end

-- the squares a cart is on
local function occupies(m: Model, c: Rail.Cell): boolean
	local f, d = RailService.frontCell(m), RailService.dir(m)
	for k = 0, cartLength(m) - 1 do
		if Rail.same(Rail.add(f, d, -k), c) then
			return true
		end
	end
	return false
end

function RailService.cartAt(c: Rail.Cell): Model?
	for _, m in builds() do
		if isCart(m) and occupies(m, c) then
			return m
		end
	end
	return nil
end

-- the machines built on a cart's deck (they ride along and share its battery): adopted by where they stand
function RailService.deck(m: Model): { Model }
	local uid = m:GetAttribute("Uid")
	local out = {}
	for _, b in builds() do
		if b ~= m and b:GetAttribute("Deck") == uid then
			table.insert(out, b)
		end
	end
	return out
end

local function adopt(m: Model)
	local len = cartLength(m)
	local uid = m:GetAttribute("Uid")
	for _, b in builds() do
		if b == m or isCart(b) or b:GetAttribute("Deck") ~= nil or (string.sub(b:GetAttribute("Build") :: string? or "", 1, 6) == "drone_" and b:GetAttribute("Build") ~= "drone_pad") then
			continue
		end
		local lp = m:GetPivot():PointToObjectSpace(b:GetPivot().Position) / M
		if math.abs(lp.X) < 0.5 and lp.Z > -0.5 and lp.Z < len - 0.5 and lp.Y > RailService.DECK_Y - 0.15 and lp.Y < RailService.DECK_Y + 0.3 then
			b:SetAttribute("Deck", uid)
		end
	end
end

-- whether a deck machine gets the cart's battery power without a wire. Go/Reverse don't (wire a switch into them,
-- or the cart would never stop), nor logic blocks, transmitters or crates (Minecart.auto_linked)
function RailService.autoLinked(b: Model): boolean
	local id = b:GetAttribute("Build") :: string? or ""
	return id ~= "crate" and id ~= "cart_go" and id ~= "cart_back" and id ~= "transmitter" and string.sub(id, 1, 5) ~= "gate_"
end

local function partOn(m: Model, kind: string): boolean
	for _, b in RailService.deck(m) do
		if b:GetAttribute("Build") == kind and b:GetAttribute("Powered") == true then
			return true
		end
	end
	return false
end

local function deckCrate(m: Model, kind: string?): Model?
	local FS = require(script.Parent.FactoryService) :: any
	for _, b in RailService.deck(m) do
		if b:GetAttribute("Build") == "crate" then
			if not kind then
				return b
			end
			for _, p in FS.contents(b) do
				if p:GetAttribute("Product") == kind then
					return b
				end
			end
		end
	end
	return nil
end

local function cradle(m: Model): CFrame
	return m:GetPivot() * CFrame.new(Vector3.new(0, 0.42, cartLength(m) - 0.28) * M)
end

local function showCell(m: Model)
	local c = m:FindFirstChild("Cell")
	local charge = m:GetAttribute("Cell") :: number?
	if charge and not c then
		local p = Instance.new("Part")
		p.Name = "Cell"
		p.Size = Vector3.new(0.18, 0.32, 0.18) * M
		p.Color = Color3.fromHex("e8e8e8")
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CFrame = cradle(m)
		p.Parent = m
	elseif not charge and c then
		c:Destroy()
	end
end

-- E on a cart: take the battery cell out of the cradle
function RailService.takeCell(m: Model): boolean
	local charge = m:GetAttribute("Cell") :: number?
	if not charge then
		return false
	end
	m:SetAttribute("Cell", nil)
	showCell(m)
	local PS = require(script.Parent.ProductionService) :: any
	local cell = PS.product("battery_cell", 1.2, Color3.fromHex("e8e8e8"), cradle(m) * CFrame.new(0, 0.3 * M, 0),
		(m:GetPivot().LookVector * -1.5 + Vector3.new(0, 1, 0)) * M, m:GetAttribute("Owner"))
	cell:SetAttribute("Charge", charge)
	remotes.Fx:FireAllClients("pickup", m:GetPivot().Position, 0.9, -4)
	return true
end

-- can't roll into a square another cart is on, or past a rail buffer that's down
function RailService.blocked(c: Rail.Cell, me: Model): boolean
	for _, o in builds() do
		if o ~= me and isCart(o) and occupies(o, c) then
			return true
		end
		if o:GetAttribute("Build") == "rail_buffer" and o:GetAttribute("Powered") ~= true then
			if Rail.same(Rail.cellOf(o:GetPivot():PointToWorldSpace(Vector3.new(0, 0, -1) * M)), c) then
				return true
			end
		end
	end
	return false
end

local function heightAt(m: Model, c: Rail.Cell): number
	local r = Rail.at(c)
	return if r then Rail.top(r) else m:GetPivot().Position.Y
end

local function try(m: Model, s: CartState, fwd: boolean)
	local d = RailService.dir(m)
	local mv = if fwd then d else { x = -d.x, z = -d.z }
	local fromC = if fwd then RailService.frontCell(m) else RailService.rearCell(m)
	local target = Rail.add(fromC, mv)
	if RailService.blocked(target, m) then
		return
	end
	local back = { x = -mv.x, z = -mv.z }
	local r = Rail.at(target)
	if not r and fwd and partOn(m, "rail_layer") then
		local cr = deckCrate(m, "rail")
		if cr then
			local FS = require(script.Parent.FactoryService) :: any
			local item: BasePart? = nil
			for _, p in FS.contents(cr) do
				if p:GetAttribute("Product") == "rail" then
					item = p
					break
				end
			end
			r = RailService.lay(target, d.x ~= 0, m:GetPivot().Position.Y, m:GetAttribute("Owner") :: number?, item and item:GetAttribute("Value") :: number?)
			if r and not Rail.leads(r, back) then
				local it = RailService.lift(r)
				it.CFrame = m:GetPivot() * CFrame.new(0, (RailService.DECK_Y + 0.5) * M, 0)
				r = nil
			elseif r and item then
				item:Destroy()
				remotes.Fx:FireAllClients("thunk", m:GetPivot().Position, 1.4, -4)
			end
		end
	end
	if not r or not Rail.leads(r, back) then
		return
	end
	s.fwd = fwd
	s.arrive = target
	s.lift = if fwd then RailService.rearCell(m) else RailService.frontCell(m)
	s.from = m:GetPivot()
	local to = s.from.Position + Vector3.new(mv.x, 0, mv.z) * M
	local y = if fwd then Rail.top(r) else heightAt(m, Rail.add(RailService.frontCell(m), mv))
	s.to = s.from.Rotation + Vector3.new(to.X, y, to.Z)
	s.t = 0
end

-- loose things on the deck (and in its crates), and you: they ride along
local function riders(m: Model): { BasePart }
	local len = cartLength(m)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local roots: { Instance } = {}
	for _, n in { "Loose", "Logs" } do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(roots, f)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(roots, p.Character)
		end
	end
	params.FilterDescendantsInstances = roots
	local out: { BasePart } = {}
	local box = m:GetPivot() * CFrame.new(Vector3.new(0, RailService.DECK_Y + 0.8, (len - 1) * 0.5) * M)
	for _, p in workspace:GetPartBoundsInBox(box, Vector3.new(0.98, 1.6, len + 0.1) * M, params) do
		local item: BasePart = p
		local char = p:FindFirstAncestorWhichIsA("Model")
		local isChar = false
		for _, pl in Players:GetPlayers() do
			if char and pl.Character == char then
				isChar = true
			end
		end
		if char and isChar then
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			item = root
		elseif p.Parent and p.Parent:IsA("BasePart") then
			item = p.Parent :: BasePart
		end
		local dup = false
		for _, o in out do
			if o == item then
				dup = true
				break
			end
		end
		if not dup and not item:GetAttribute("HeldBy") and not item.Anchored then
			table.insert(out, item)
		end
	end
	return out
end

-- round a curve: the cart swings about the square its leading end just reached, deck and riders with it
local function turnAt(m: Model, pivot: Rail.Cell, newDir: Rail.Cell)
	local p = Vector3.new(pivot.x * M, m:GetPivot().Position.Y, pivot.z * M)
	local nb = CFrame.lookAt(Vector3.zero, Vector3.new(newDir.x, 0, newDir.z))
	local rot = nb * m:GetPivot().Rotation:Inverse()
	local function xf(cf: CFrame): CFrame
		return CFrame.new(p) * rot * CFrame.new(-p) * cf
	end
	for _, b in riders(m) do
		b.CFrame = xf(b.CFrame)
	end
	for _, b in RailService.deck(m) do
		b:PivotTo(xf(b:GetPivot()))
	end
	m:PivotTo(xf(m:GetPivot()))
	remotes.Fx:FireAllClients("clink", m:GetPivot().Position, 0.7, -6)
end

local function roll(m: Model, s: CartState, dt: number)
	local was = m:GetPivot().Position
	s.t = math.min(1, s.t + dt * RailService.SPEED)
	local cf = s.from:Lerp(s.to, s.t)
	local moved = cf.Position - was
	m:PivotTo(cf)
	for _, b in RailService.deck(m) do
		b:PivotTo(b:GetPivot() + moved)
	end
	for _, b in riders(m) do
		b.CFrame = b.CFrame + moved
	end
	if s.t < 1 then
		return
	end
	s.t = -1
	s.settle = RailService.SETTLE
	-- the wheels clack over the rail joint
	remotes.Fx:FireAllClients("clink", m:GetPivot().Position, 0.55 + math.random() * 0.1, -14)
	-- a curve (or a switched rail) turns the cart: the leading end follows the track's other way out
	local ar = Rail.at(s.arrive)
	local d = RailService.dir(m)
	local mv = if s.fwd then d else { x = -d.x, z = -d.z }
	if ar and not Rail.leads(ar, mv) then
		local l = Rail.links(ar)
		local out = if not Rail.same(l[1], { x = -mv.x, z = -mv.z }) then l[1] else l[2]
		turnAt(m, s.arrive, if s.fwd then out else { x = -out.x, z = -out.z })
	end
	-- the lifter picks up the rail the cart has just left behind
	if s.fwd and s.lift and partOn(m, "rail_lifter") then
		local old = Rail.at(s.lift)
		if old then
			local item = RailService.lift(old)
			local cr = deckCrate(m)
			item.CFrame = if cr then cr:GetPivot() * CFrame.new(0, 0.6 * M, 0) else m:GetPivot() * CFrame.new(0, 0.8 * M, (cartLength(m) - 1) * M)
			remotes.Fx:FireAllClients("clink", m:GetPivot().Position, 0.9, -6)
		end
	end
end

local function cart(m: Model, dt: number)
	adopt(m)
	local s = stateOf(m)
	local charge = m:GetAttribute("Cell") :: number?
	-- a battery cell dropped in the cradle snaps in
	if not charge then
		local FS = require(script.Parent.FactoryService) :: any
		for _, b in FS.within(m, Vector3.new(0, 0.47, cartLength(m) - 0.28), Vector3.new(0.5, 0.5, 0.36)) do
			if b:GetAttribute("Product") == "battery_cell" then
				charge = b:GetAttribute("Charge") :: number? or 0
				m:SetAttribute("Cell", charge)
				b:Destroy()
				remotes.Fx:FireAllClients("clink", m:GetPivot().Position, 1.3, -4)
				break
			end
		end
	end
	showCell(m)
	if charge and charge > 0 then
		local drain = RailService.DRAIN_IDLE * dt + (if s.t >= 0 then RailService.DRAIN_MOVE * cartLength(m) * dt else 0)
		m:SetAttribute("Cell", math.max(0, charge - drain))
	end
	if s.t >= 0 then
		roll(m, s, dt)
		return
	end
	s.settle -= dt
	if not (charge and charge > 0) or s.settle > 0 then
		return
	end
	if partOn(m, "cart_go") then
		try(m, s, true)
	elseif partOn(m, "cart_back") then
		try(m, s, false)
	end
end

-- ------------------------------------------------------------------ beside the track
-- the rail a switch works: the straight rail beside it (left first, then right) that runs the way it points
function RailService.switchTarget(m: Model): Rail.Cell?
	local f = Rail.dirOf(m:GetPivot())
	local me = Rail.cellOf(m:GetPivot().Position)
	for _, side in { { x = f.z, z = -f.x }, { x = -f.z, z = f.x } } do
		local c = Rail.add(me, side)
		local r = Rail.at(c)
		if r and (r:GetAttribute("Curve") :: number? or -1) < 0 and (r:GetAttribute("AlongX") == true) == (f.x ~= 0) then
			return c
		end
	end
	return nil
end

local function unloadOne(m: Model)
	local behind = Rail.cellOf(m:GetPivot():PointToWorldSpace(Vector3.new(0, 0, 1) * M))
	local FS = require(script.Parent.FactoryService) :: any
	for _, c in builds() do
		if not isCart(c) or stateOf(c).t >= 0 then
			continue     -- (not while it's rolling)
		end
		for _, b in RailService.deck(c) do
			if b:GetAttribute("Build") == "crate" and Rail.same(Rail.cellOf(b:GetPivot().Position), behind) then
				local stuff = FS.contents(b)
				if #stuff > 0 then
					local p = stuff[1]
					p.CFrame = m:GetPivot() * CFrame.new(Vector3.new(0, 0.7, -0.75) * M)
					p.AssemblyLinearVelocity = m:GetPivot().LookVector * 1.0 * M
					remotes.Fx:FireAllClients("thud", m:GetPivot().Position, 1.3, -8)
					return
				end
			end
		end
	end
end

function RailService.step(dt: number)
	local branched: { [string]: string } = {}
	for _, m in builds() do
		local id = m:GetAttribute("Build")
		if isCart(m) then
			cart(m, dt)
		elseif id == "rail_switch" then
			local c = RailService.switchTarget(m)
			m:SetAttribute("Works", c ~= nil)
			if c and m:GetAttribute("Powered") == true then
				local f = Rail.dirOf(m:GetPivot())
				local me = Rail.cellOf(m:GetPivot().Position)
				local away = { x = c.x - me.x, z = c.z - me.z }
				branched[Rail.key(c)] = string.format("%d,%d;%d,%d", f.x, f.z, away.x, away.z)
			end
		elseif id == "cart_unloader" and m:GetAttribute("Powered") == true then
			local t = (m:GetAttribute("Cd") :: number? or 0) - dt
			if t <= 0 then
				t = RailService.UNLOAD_EVERY
				unloadOne(m)
			end
			m:SetAttribute("Cd", t)
		elseif id == "drone_pad" and m:GetAttribute("Powered") == true then
			-- the battery of a drone above it charges (and cells left on it)
			for _, d in builds() do
				local c = d:GetAttribute("Cell") :: number?
				if c and string.sub(d:GetAttribute("Build") :: string? or "", 1, 6) == "drone_" and d ~= m then
					local lp = m:GetPivot():PointToObjectSpace(d:GetPivot().Position) / M
					if math.abs(lp.X) < 0.6 and math.abs(lp.Z) < 0.6 and lp.Y > -0.2 and lp.Y < 4.0 then
						d:SetAttribute("Cell", math.min(1, c + RailService.PAD_RATE * dt))
					end
				end
			end
			local FS = require(script.Parent.FactoryService) :: any
			for _, b in FS.within(m, Vector3.new(0, 0.35, 0), Vector3.new(0.9, 0.5, 0.9)) do
				if b:GetAttribute("Product") == "battery_cell" then
					b:SetAttribute("Charge", math.min(1, (b:GetAttribute("Charge") :: number? or 0) + RailService.PAD_RATE * dt))
				end
			end
		end
	end
	for _, r in folder("Rails"):GetChildren() do
		local want = branched[r.Name]
		if r:GetAttribute("Branch") ~= want then
			r:SetAttribute("Branch", want)
		end
	end
	for uid in carts do
		local alive = false
		for _, m in builds() do
			if m:GetAttribute("Uid") == uid then
				alive = true
				break
			end
		end
		if not alive then
			carts[uid] = nil
		end
	end
end

-- ------------------------------------------------------------------ saving: your laid track goes with you
function RailService.serialize(userId: number): { any }
	local out = {}
	for _, r in folder("Rails"):GetChildren() do
		if r:GetAttribute("Owner") == userId then
			local c = string.split(r.Name, ",")
			table.insert(out, { kind = "rail", x = tonumber(c[1]), z = tonumber(c[2]), ax = r:GetAttribute("AlongX") == true,
				curve = r:GetAttribute("Curve"), y = r:GetAttribute("Y"), value = r:GetAttribute("Value") })
		end
	end
	return out
end

function RailService.restore(player: Player, list: { any })
	for _, e in list or {} do
		if typeof(e) == "table" and e.kind == "rail" and typeof(e.x) == "number" and typeof(e.z) == "number" then
			local c = { x = e.x, z = e.z }
			if not Rail.at(c) then
				make(c, e.ax == true, if typeof(e.curve) == "number" then e.curve else -1, if typeof(e.y) == "number" then e.y else ground(c, nil), player.UserId, e.value)
			end
		end
	end
end

-- a player leaves: their track goes with them (saved first)
function RailService.removeFor(userId: number)
	for _, r in folder("Rails"):GetChildren() do
		if r:GetAttribute("Owner") == userId then
			r:Destroy()
		end
	end
end

-- ------------------------------------------------------------------ the hammer on a rail
local function railOf(target: Instance): Model?
	local m = target:FindFirstAncestorWhichIsA("Model")
	return if m and m:GetAttribute("Kind") == "rail" then m else nil
end

function RailService.start()
	folder("Rails")
	remotes.Hammer.OnServerEvent:Connect(function(player, target, how)
		local ToolService = require(script.Parent.ToolService) :: any
		local DataService = require(script.Parent.DataService) :: any
		if typeof(target) ~= "Instance" or not target:IsA("BasePart") or not target.Parent or ToolService.current(player) ~= "hammer" then
			return
		end
		if how ~= "turn" and (require(script.Parent.FactoryService) :: any).onHammer(player, target) then
			return       -- (a rotator)
		end
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		if not head or (head.CFrame.Position - target.CFrame.Position).Magnitude > 6 * M then
			return
		end
		-- a log: nail it in place, or let it go again (Godot's Log.set_locked)
		local lg = target:FindFirstAncestorWhichIsA("Model")
		if how ~= "turn" and lg and lg:GetAttribute("Kind") == "log" then
			local trunk = lg:FindFirstChild("Trunk") :: BasePart?
			if trunk and not trunk:GetAttribute("HeldBy") then
				local on = not lg:GetAttribute("Locked")
				lg:SetAttribute("Locked", on)
				trunk.Anchored = on
				if on then
					trunk.AssemblyLinearVelocity = Vector3.zero
				end
				remotes.Fx:FireAllClients("clink", trunk.CFrame.Position, if on then 0.8 else 1.2, 0)
				remotes.Fx:FireAllClients("thud", trunk.CFrame.Position, 1.5, -4)
			end
			return
		end
		local laid = railOf(target)
		if laid then
			if how == "turn" then
				RailService.turn(laid)
				remotes.Fx:FireAllClients("click", laid:GetPivot().Position, 1.1, -4)
			else
				local at = laid:GetPivot().Position
				RailService.lift(laid)
				remotes.Fx:FireAllClients("clink", at, 1.2, 0)
			end
			return
		end
		local item: BasePart = if target.Parent and target.Parent:IsA("BasePart") then target.Parent :: BasePart else target
		local kind = item:GetAttribute("Product")
		if (kind ~= "rail" and kind ~= "curved_rail") or item.Anchored or item:GetAttribute("HeldBy") then
			return
		end
		local c = Rail.cellOf(item.CFrame.Position)
		local data = DataService.get(player)
		if not data or not Land.owns(data.land or {}, Rail.centre(c, 0)) then
			remotes.Notify:FireClient(player, "That isn't your land", "ff8a6a")
			return
		end
		local f = head.CFrame.LookVector
		local r: Model?
		if kind == "curved_rail" then
			local fc = if math.abs(f.X) > math.abs(f.Z) then { x = if f.X > 0 then 1 else -1, z = 0 } else { x = 0, z = if f.Z > 0 then 1 else -1 }
			r = RailService.layCurve(c, fc, item.CFrame.Position.Y, player.UserId, item:GetAttribute("Value") :: number?)
		else
			r = RailService.lay(c, math.abs(f.X) > math.abs(f.Z), item.CFrame.Position.Y, player.UserId, item:GetAttribute("Value") :: number?)
		end
		if r then
			item:Destroy()
			remotes.Fx:FireAllClients("clink", r:GetPivot().Position, 0.9, 0)
			remotes.Fx:FireAllClients("thud", r:GetPivot().Position, 1.5, -4)
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.05)
			local now = os.clock()
			local ok, err = pcall(RailService.step, now - last)
			if not ok then
				warn("[Timber] rails: " .. tostring(err))
			end
			last = now
		end
	end)
end

return RailService
