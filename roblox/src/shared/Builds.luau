--!strict
-- What the hammer builds, the Godot game's way (Builds.gd): each build's needs (bigger builds cost more: the
-- footprint, size squared, at least 1 of each), its blueprint from TimberMart if it's a machine, what dropped things
-- count as, and its model. The model is made of Godot's own parts (props.glb, one mesh a part: b__<id>__<part>__<res>),
-- each either needing a resource (it turns solid in that material's colour as it's filled) or a finishing part that
-- appears when the build completes. Until the meshes have loaded, boxes stand in at each part's place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GB = require(script.Parent.GodotBuilds) :: any

local Builds = {}
Builds.data = GB
Builds.REACH = 9          -- metres (Builder.REACH)

export type Def = { name: string, needs: { [string]: number }, bp: string?, sell: number, fixed: boolean, machine: boolean, top: number, parts: { any } }

function Builds.def(id: string): Def?
	return GB.builds[id]
end

function Builds.needsFor(id: string, size: number): { [string]: number }
	local out = {}
	local d = GB.builds[id]
	if not d then
		return out
	end
	for r, n in d.needs do
		out[r] = math.max(1, math.ceil(n * size * size - 0.001))
	end
	return out
end

-- in Godot's order of the resources (bark, log, leaf, stone, ...)
local RES_ORDER = { "bark", "log", "leaf", "stone", "copper", "iron", "plank", "copper_bar", "iron_bar" }
Builds.RES_ORDER = RES_ORDER

-- "1 log  ·  6 bark", in the build's own order (Godot lists them as Builds.gd does)
function Builds.needsText(needs: { [string]: number }, id: string?, sep: string?): string
	local bits = {}
	local d = id and GB.builds[id]
	for _, r in (if d and d.needsOrder then d.needsOrder else RES_ORDER) do
		if needs[r] and needs[r] > 0 then
			table.insert(bits, string.format("%d %s", needs[r], GB.resName[r] or r))
		end
	end
	return table.concat(bits, sep or "  ·  ")
end

function Builds.unlocked(id: string, owned: { [string]: boolean }): boolean
	local d = GB.builds[id]
	return d ~= nil and (d.bp == nil or owned[d.bp] == true)
end

function Builds.sizeOk(id: string, size: number): boolean
	local d = GB.builds[id]
	if not d then
		return false
	end
	if d.fixed then
		return size == 1
	end
	return table.find(GB.sizes, size) ~= nil
end

-- What a dropped thing is worth to a build (Builds.resource_of): res, amount, colour; nil if it's no use.
function Builds.resourceOf(p: Instance): (string?, number, Color3?)
	if not p:IsA("BasePart") then
		return nil, 0, nil
	end
	local kind = p:GetAttribute("Kind")
	if kind == "bark" then
		return "bark", p:GetAttribute("Panels") :: number? or 1, p.Color
	elseif kind == "leaf" then
		return "leaf", 1, p.Color
	elseif kind == "ore" then
		return p:GetAttribute("Ore") :: string?, 1, p.Color
	elseif kind == "product" then
		local res = p:GetAttribute("Res") :: string?
		return res, 1, p.Color
	end
	local m = p.Parent
	if p.Name == "Trunk" and m and m:GetAttribute("Kind") == "log" then
		return "log", 1, p.Color
	end
	return nil, 0, nil
end

-- The build's model at 1x around its own origin (pivot), one part per Godot part: each named after its index, with
-- its resource ("" for a finishing part) as attributes. Godot's meshes if they've loaded, else boxes.
function Builds.model(id: string): Model?
	local d = GB.builds[id]
	if not d then
		return nil
	end
	local props = ReplicatedStorage:FindFirstChild("Props")
	local src = props and props:FindFirstChild("b__" .. id)
	local m: Model
	if src then
		m = (src :: Model):Clone()
	else
		m = Instance.new("Model")
		for k, p in d.parts do
			local b = Instance.new("Part")
			b.Name = tostring(k - 1)
			b.Size = Vector3.new(math.max(p.size[1], 0.05), math.max(p.size[2], 0.05), math.max(p.size[3], 0.05))
			b.CFrame = CFrame.new(p.at[1], p.at[2], p.at[3])
			b.Color = Color3.fromHex(p.color)
			b:SetAttribute("Index", k - 1)
			b:SetAttribute("Res", p.res)
			b.Parent = m
		end
		m:SetAttribute("Standin", true)
	end
	m.Name = id
	m.WorldPivot = CFrame.new()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local pd = d.parts[(p:GetAttribute("Index") :: number? or -1) + 1]
			if pd and pd.group then
				p:SetAttribute("Group", pd.group)      -- (the catapult's Arm, the compost's Mound: parts that move)
			end
			p.Anchored = true
			p.Material = Enum.Material.SmoothPlastic
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
		end
	end
	return m
end

-- the parts of a model that need `res`, in Godot's order
function Builds.partsFor(m: Model, res: string): { BasePart }
	local out = {}
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Res") == res then
			table.insert(out, p)
		end
	end
	table.sort(out, function(a, b)
		return (a:GetAttribute("Index") :: number) < (b:GetAttribute("Index") :: number)
	end)
	return out
end

return Builds
