--!strict
-- The production machines, the Godot game's way (Sawmill.gd, Processor.gd, Chipper.gd, Product.gd). Powered:
--   sawmill   a log on its table becomes planks (one a 0.55 m, worth half as much again as the log) out of the front
--   smelter   copper ore or iron ore in the hopper -> a copper or iron bar (2.2x), 3 s each
--   kiln      planks -> dried planks (1.4x), 4 s each
--   chipper   bark and leaves -> a bag of mulch once there's $4 of it (1.6x)
--   assembler planks and bars -> furniture (2.5x what went in) or parts; E picks what it makes
-- What comes out is a real thing (Godot's Product): carry it, sell it, build with it, burn it in a generator.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage.Shared.Config)

local ProductionService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
local COPPER = Color3.fromHex("c8703a")

ProductionService.KINDS = {
	plank = { name = "Plank", fuel = 8, res = "plank", size = { 0.22, 0.05, 0.9 } },
	dry_plank = { name = "Dried Plank", fuel = 10, res = "plank", size = { 0.22, 0.05, 0.9 } },
	mulch = { name = "Bag of Mulch", fuel = 30, res = "", size = { 0.36, 0.22, 0.26 } },
	copper_bar = { name = "Copper Bar", fuel = 0, res = "copper_bar", size = { 0.12, 0.07, 0.3 } },
	iron_bar = { name = "Iron Bar", fuel = 0, res = "iron_bar", size = { 0.12, 0.07, 0.3 } },
	chair = { name = "Chair", fuel = 20, res = "", size = { 0.45, 0.8, 0.45 } },
	table = { name = "Table", fuel = 30, res = "", size = { 0.9, 0.7, 0.6 } },
	lantern = { name = "Lantern", fuel = 0, res = "", size = { 0.2, 0.35, 0.2 } },
	cabinet = { name = "Cabinet", fuel = 40, res = "", size = { 0.6, 0.9, 0.4 } },
	toy_truck = { name = "Toy Truck", fuel = 10, res = "", size = { 0.25, 0.2, 0.45 } },
	battery_cell = { name = "Battery Cell", fuel = 0, res = "", size = { 0.18, 0.32, 0.18 } },
	rail = { name = "Rail", fuel = 0, res = "", size = { 0.8, 0.12, 1.0 } },
	curved_rail = { name = "Curved Rail", fuel = 0, res = "", size = { 1.0, 0.12, 1.0 } },
	oil_barrel = { name = "Barrel of Oil", fuel = 90, res = "", size = { 0.4, 0.6, 0.4 } },
	fuel_can = { name = "Fuel Can", fuel = 240, res = "", size = { 0.25, 0.35, 0.15 } },
	plastic = { name = "Plastic Sheet", fuel = 0, res = "", size = { 0.5, 0.03, 0.5 } },
	lawn_chair = { name = "Lawn Chair", fuel = 0, res = "", size = { 0.5, 0.7, 0.5 } },
	bucket = { name = "Bucket", fuel = 0, res = "", size = { 0.3, 0.3, 0.3 } },
}
ProductionService.RECIPES = {
	chair = { plank = 2 }, table = { plank = 4, iron_bar = 1 }, lantern = { copper_bar = 1, plank = 1 },
	cabinet = { plank = 6, copper_bar = 1 }, toy_truck = { plank = 2, iron_bar = 1 }, battery_cell = { copper_bar = 1, iron_bar = 1 },
	rail = { iron_bar = 1 }, curved_rail = { iron_bar = 1 }, lawn_chair = { plastic = 2 }, bucket = { plastic = 1, iron_bar = 1 },
}
ProductionService.RECIPE_ORDER = { "chair", "table", "lantern", "cabinet", "toy_truck", "lawn_chair", "bucket", "battery_cell", "rail", "curved_rail" }
local PART_VALUE = { battery_cell = 1.2, rail = 0.7, curved_rail = 0.7 }
local MAKES = { rail = 2 }
local WORK_TIME = { smelter = 3.0, kiln = 4.0, assembler = 3.0, refinery = 4.0 }
local PLANK_LEN = 0.55

local function loose(): Instance
	local f = workspace:FindFirstChild("Loose")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Loose"
		f.Parent = workspace
	end
	return f :: Instance
end

-- a product (Godot's Product.setup): Godot's mesh, the wood tinted to what it was made from
function ProductionService.product(kind: string, value: number, color: Color3, cf: CFrame, vel: Vector3, owner: number?): BasePart
	local d = ProductionService.KINDS[kind] or ProductionService.KINDS.plank
	local root = Instance.new("Part")
	root.Name = d.name
	root.Size = Vector3.new(d.size[1], d.size[2], d.size[3]) * M
	root.CFrame = cf
	root.Color = color
	root.Material = Enum.Material.SmoothPlastic
	root:SetAttribute("Kind", "product")
	root:SetAttribute("Product", kind)
	root:SetAttribute("Res", d.res)
	root:SetAttribute("Value", math.floor(value * 100 + 0.5) / 100)
	root:SetAttribute("Fuel", d.fuel)
	if owner then
		root:SetAttribute("Owner", owner)
	end
	local props = ReplicatedStorage:FindFirstChild("Props")
	local src = props and props:FindFirstChild("product_" .. kind)
	if src then
		root.Transparency = 1
		local m = (src :: Model):Clone()
		m:PivotTo(cf)
		local plank = Color3.fromHex("e2c08d")
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				-- (Godot builds it in the colour it's given: the plank's own wood; the rest keeps its colours)
				local dist = math.abs(p.Color.R - plank.R) + math.abs(p.Color.G - plank.G) + math.abs(p.Color.B - plank.B)
				if dist < 0.02 then
					p.Color = color
				elseif dist < 0.25 and kind ~= "copper_bar" and kind ~= "iron_bar" then
					p.Color = color:Lerp(Color3.new(0, 0, 0), 0.15)
				end
				p.Anchored = false
				p.CanCollide = false
				p.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = p
				w.Parent = p
				p.Parent = root
			end
		end
		m:Destroy()
	end
	root.Parent = loose()
	root.AssemblyLinearVelocity = vel
	return root
end

local function inBox(m: Model, off: Vector3, box: Vector3): { BasePart }
	local size = m:GetAttribute("Size") :: number? or 1
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local roots = {}
	for _, name in { "Loose", "Logs" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(roots, f)
		end
	end
	params.FilterDescendantsInstances = roots
	local out, seen = {}, {}
	for _, p in workspace:GetPartBoundsInBox(m:GetPivot() * CFrame.new(off * M * size), box * M * size, params) do
		local item: BasePart = if p.Parent and p.Parent:IsA("BasePart") then p.Parent :: BasePart else p
		if not seen[item] and item.Parent and not item:GetAttribute("HeldBy") then
			seen[item] = true
			table.insert(out, item)
		end
	end
	return out
end

local function outCF(m: Model, z: number, y: number): CFrame
	local size = m:GetAttribute("Size") :: number? or 1
	return m:GetPivot() * CFrame.new(Vector3.new(0, y, z) * M * size)
end

local function ownerOf(m: Model): Player?
	return Players:GetPlayerByUserId(m:GetAttribute("Owner") :: number)
end

local function award(m: Model, id: string)
	local p = ownerOf(m)
	if p then
		(require(script.Parent.TrophyService) :: any).award(p, id)
	end
end

local function valueOf(item: BasePart): number
	if item.Name == "Trunk" and item.Parent and item.Parent:GetAttribute("Kind") == "log" then
		return (require(script.Parent.LogService) :: any).value(item.Parent)
	end
	return item:GetAttribute("Value") :: number? or 0
end

-- ------------------------------------------------------------------ the sawmill
local function sawmill(m: Model, dt: number)
	local log: Model? = nil
	for _, item in inBox(m, Vector3.new(0, 0.85, 0), Vector3.new(1.1, 0.7, 1.1)) do
		if item.Name == "Trunk" and item.Parent and item.Parent:GetAttribute("Kind") == "log" then
			log = item.Parent :: Model
			break
		end
	end
	local cur = m:GetAttribute("LogUid")
	local uid = if log then (log:GetAttribute("Uid") :: string? or log:GetFullName()) else nil
	if uid ~= cur then
		m:SetAttribute("LogUid", uid)
		m:SetAttribute("Work", 0)
	end
	if not log then
		return
	end
	local len = (log:GetAttribute("Bands") :: number? or 1) * Config.Tree.bandH
	local work = (m:GetAttribute("Work") :: number? or 0) + dt
	m:SetAttribute("Work", work)
	if math.random() < dt * 4 then
		remotes.Fx:FireAllClients("saw", m:GetPivot().Position, 1.5, -6)
	end
	if work >= 0.8 + len * 0.4 then
		local n = math.clamp(math.round(len / PLANK_LEN), 1, 14)
		local each = valueOf(log:FindFirstChild("Trunk") :: BasePart) * 1.5 / n
		local sp = (Config.Species :: any)[log:GetAttribute("Species") or "oak"] or Config.Species.oak
		local col = Color3.fromHex(sp.wood)
		for k = 0, n - 1 do
			ProductionService.product("plank", each, col, m:GetPivot() * CFrame.new(Vector3.new(math.random() * 0.3 - 0.15, 0.6 + k * 0.06, -0.75) * M),
				m:GetPivot().LookVector * 1.5 * M + Vector3.new(0, 0.5 * M, 0), m:GetAttribute("Owner") :: number)
		end
		remotes.Fx:FireAllClients("thud", m:GetPivot().Position, 1.2, 0)
		award(m, "first_plank")
		log:Destroy()
		m:SetAttribute("Work", 0)
		m:SetAttribute("LogUid", nil)
	end
end

-- ------------------------------------------------------------------ smelter, kiln, assembler
local function accepts(m: Model, kind: string, item: BasePart): boolean
	local prod = item:GetAttribute("Product")
	local res = if item:GetAttribute("Kind") == "ore" then item:GetAttribute("Ore") elseif prod == "plastic" then "plastic" elseif prod then (ProductionService.KINDS[prod :: string] or {}).res else nil
	if kind == "refinery" then
		return prod == "oil_barrel"
	end
	if kind == "smelter" then
		return res == "copper" or res == "iron"
	elseif kind == "kiln" then
		return prod == "plank"
	elseif kind == "assembler" then
		local r = ProductionService.RECIPE_ORDER[(m:GetAttribute("Recipe") :: number? or 0) + 1]
		local need = ProductionService.RECIPES[r]
		local have = m:GetAttribute("Have_" .. tostring(res)) :: number? or 0
		return res ~= nil and need[res :: string] ~= nil and have < need[res :: string]
	end
	return false
end

local function queueOf(m: Model): { any }
	local s = m:GetAttribute("Queue")
	if typeof(s) ~= "string" or s == "" then
		return {}
	end
	local out = {}
	for entry in string.gmatch(s, "[^;]+") do
		local o, v, c = string.match(entry, "^(.-)|(.-)|(.-)$")
		if o then
			table.insert(out, { out = o, value = tonumber(v) or 0, color = c })
		end
	end
	return out
end

local function setQueue(m: Model, q: { any })
	local bits = {}
	for _, o in q do
		table.insert(bits, string.format("%s|%.2f|%s", o.out, o.value, o.color))
	end
	m:SetAttribute("Queue", table.concat(bits, ";"))
end

local function processor(m: Model, kind: string, dt: number)
	local q = queueOf(m)
	if #q < 6 then
		for _, item in inBox(m, Vector3.new(0, 1.0, 0), Vector3.new(0.75, 0.5, 0.75)) do
			if not accepts(m, kind, item) then
				continue
			end
			local v = valueOf(item)
			local prod = item:GetAttribute("Product")
			local res = if item:GetAttribute("Kind") == "ore" then item:GetAttribute("Ore") :: string elseif prod == "plastic" then "plastic" elseif prod then ProductionService.KINDS[prod :: string].res else ""
			if kind == "refinery" then
				-- the oil's worth splits over what comes out, and gains on the way
				table.insert(q, { out = "fuel_can", value = v * 0.8, color = "ffffff" })
				table.insert(q, { out = "plastic", value = v * 0.6, color = "ffffff" })
			elseif kind == "smelter" then
				table.insert(q, { out = res .. "_bar", value = v * 2.2, color = if res == "copper" then COPPER:ToHex() else "9aa1ab" })
			elseif kind == "kiln" then
				table.insert(q, { out = "dry_plank", value = v * 1.4, color = item.Color:ToHex() })
			else
				m:SetAttribute("Have_" .. res, (m:GetAttribute("Have_" .. res) :: number? or 0) + 1)
				m:SetAttribute("HaveValue", (m:GetAttribute("HaveValue") :: number? or 0) + v)
				if prod and string.find(prod :: string, "plank") then
					m:SetAttribute("Wood", item.Color:ToHex())
				end
				local r = ProductionService.RECIPE_ORDER[(m:GetAttribute("Recipe") :: number? or 0) + 1]
				local done = true
				for need, n in ProductionService.RECIPES[r] do
					if (m:GetAttribute("Have_" .. need) :: number? or 0) < n then
						done = false
					end
				end
				if done then
					local hv = m:GetAttribute("HaveValue") :: number? or 0
					for _ = 1, MAKES[r] or 1 do
						table.insert(q, { out = r, value = hv * (PART_VALUE[r] or 2.5) / (MAKES[r] or 1), color = m:GetAttribute("Wood") or "a0703c" })
					end
					for need in ProductionService.RECIPES[r] do
						m:SetAttribute("Have_" .. need, nil)
					end
					m:SetAttribute("HaveValue", 0)
				end
			end
			remotes.Fx:FireAllClients("crumble", item.Position, 1.4, -10)
			item:Destroy()
		end
		setQueue(m, q)
	end
	if #q == 0 then
		m:SetAttribute("Work", 0)
		return
	end
	local work = (m:GetAttribute("Work") :: number? or 0) + dt
	if work >= WORK_TIME[kind] then
		work = 0
		local o = table.remove(q, 1)
		ProductionService.product(o.out, o.value, Color3.fromHex(o.color), outCF(m, -0.8, 0.5), m:GetPivot().LookVector * 1.2 * M, m:GetAttribute("Owner") :: number)
		remotes.Fx:FireAllClients(if kind == "smelter" then "clink" else "thud", m:GetPivot().Position, 1.1, -4)
		if o.out == "iron_bar" then
			award(m, "first_iron")
		elseif kind == "assembler" then
			award(m, "first_furniture")
		end
		setQueue(m, q)
	end
	m:SetAttribute("Work", work)
end

-- ------------------------------------------------------------------ the chipper
local function chipper(m: Model)
	local stock = m:GetAttribute("Stock") :: number? or 0
	for _, item in inBox(m, Vector3.new(0, 1.0, 0), Vector3.new(0.75, 0.5, 0.75)) do
		local kind = item:GetAttribute("Kind")
		if kind == "bark" or kind == "leaf" then
			stock += valueOf(item) * 1.6
			m:SetAttribute("Chips", if kind == "bark" then item.Color:ToHex() else "5f8a3a")
			remotes.Fx:FireAllClients("crumble", item.Position, 1.4, -10)
			item:Destroy()
		end
	end
	if stock >= 4 then
		ProductionService.product("mulch", stock, Color3.fromHex(m:GetAttribute("Chips") :: string? or "5f8a3a"), outCF(m, -0.75, 0.45),
			m:GetPivot().LookVector * 1.2 * M, m:GetAttribute("Owner") :: number)
		remotes.Fx:FireAllClients("drop", m:GetPivot().Position, 0.8)
		stock = 0
	end
	m:SetAttribute("Stock", stock)
end

-- ------------------------------------------------------------------ the oil pump (OilPump.gd)
local function oilPump(m: Model, dt: number)
	local Mining = require(ReplicatedStorage.Shared.Mining) :: any
	local at = m:GetPivot().Position
	local r = Mining.richness("oil", at.X, at.Z)
	if r < 0.12 then
		return
	end
	local fill = (m:GetAttribute("Fill") :: number? or 0) + (1 / 25) * r * dt
	if fill >= 1 then
		fill = 0
		ProductionService.product("oil_barrel", 8, Color3.new(1, 1, 1), outCF(m, -0.85, 0.4), m:GetPivot().LookVector * 1.0 * M, m:GetAttribute("Owner") :: number)
		remotes.Fx:FireAllClients("thud", at, 0.7, -4)
		award(m, "first_oil")
	end
	m:SetAttribute("Fill", fill)
end

-- E on the assembler: the next recipe (what was collected for the old one is used up)
function ProductionService.cycle(m: Model)
	local r = ((m:GetAttribute("Recipe") :: number? or 0) + 1) % #ProductionService.RECIPE_ORDER
	m:SetAttribute("Recipe", r)
	for res in pairs({ plank = 1, iron_bar = 1, copper_bar = 1, plastic = 1 }) do
		m:SetAttribute("Have_" .. res, nil)
	end
	m:SetAttribute("HaveValue", 0)
	remotes.Fx:FireAllClients("click", m:GetPivot().Position, 0.9 + r * 0.08, -4)
end

function ProductionService.step(dt: number)
	local f = workspace:FindFirstChild("Builds")
	for _, m in if f then f:GetChildren() else {} do
		if not m:IsA("Model") or m:GetAttribute("Powered") ~= true then
			continue
		end
		local id = m:GetAttribute("Build")
		if id == "sawmill" then
			sawmill(m, dt)
		elseif id == "smelter" or id == "kiln" or id == "assembler" or id == "refinery" then
			processor(m, id :: string, dt)
		elseif id == "oil_pump" then
			oilPump(m, dt)
		elseif id == "chipper" then
			chipper(m)
		end
	end
end

function ProductionService.start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local ok, err = pcall(ProductionService.step, now - last)
			if not ok then
				warn("[Timber] production: " .. tostring(err))
			end
			last = now
		end
	end)
end

return ProductionService
