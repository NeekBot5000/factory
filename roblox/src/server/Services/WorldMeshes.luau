--!strict
-- The Godot game's own meshes, so the world looks the same: the terrain and its grass, the cabin, the crowns and
-- root flares of every tree, rocks, bushes, the hills round the valley, the clouds, the chopping block, the trucks and
-- the tools. tools/ExportRobloxWorld.gd writes them as three glb files; GitHub uploads them (tools/roblox_assets.py),
-- and their asset ids land in Shared.Assets as GodotWorld, GodotTrucks and GodotTools. This loads them.
-- Roblox imports a glb as a Model of MeshParts but drops the colours, so each MeshPart is named after its colour
-- ("terrain_3_4_c4f8a35") and gets it back here. Two marker cubes, at 0 and at 30 studs along X, give the import's
-- scale and offset, so everything lands exactly where it is in Godot.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMeshes = {}
WorldMeshes.loaded = {} :: { [string]: Model }

local NO_SHADOW = { grass = true, cloud = true, hills = true, marker = true }

-- the part of a name before the colour ("terrain_3_4"), the kind ("terrain") and the colour
function WorldMeshes.parseName(name: string): (string, string, Color3?)
	local base, hexs = string.match(name, "^(.-)_c(%x%x%x%x%x%x)")
	if not base then
		return name, string.match(name, "^([%a]+)") or name, nil
	end
	return base, string.match(base, "^([%a]+)") or base, Color3.fromHex(hexs :: string)
end

-- the image a ground chunk's texture points at (its Decal asset, loaded once), or nil
local groundTextures: { [string]: string } = {}
local function groundTexture(ck: string): string?
	if groundTextures[ck] then
		return groundTextures[ck]
	end
	local ok, Assets = pcall(require, ReplicatedStorage.Shared.Assets)
	local id = ok and (Assets :: any)["Ground_" .. ck]
	if not id then
		return nil
	end
	local got, container = pcall(function()
		return InsertService:LoadAsset(tonumber(id) :: number)
	end)
	local decal = got and container and (container :: Instance):FindFirstChildWhichIsA("Decal", true)
	local tex = if decal then (decal :: Decal).Texture else nil
	if got and container then
		(container :: Instance):Destroy()
	end
	if tex then
		groundTextures[ck] = tex
	end
	return tex
end

-- Loads an uploaded glb and returns its MeshParts placed in studs around Godot's origin (or nil).
function WorldMeshes.load(key: string): Model?
	local ok, Assets = pcall(require, ReplicatedStorage.Shared.Assets)
	local id = ok and (Assets :: any)[key]
	if not id then
		return nil
	end
	local got, container = pcall(function()
		return InsertService:LoadAsset(tonumber(id) :: number)
	end)
	if not got or not container then
		warn("[Timber] couldn't load the Godot meshes (" .. key .. " " .. tostring(id) .. "): " .. tostring(container))
		return nil
	end
	local model = Instance.new("Model")
	model.Name = key
	local parts: { BasePart } = {}
	local origin, xmark = nil, nil
	for _, d in (container :: Instance):GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if string.find(d.Name, "^marker_origin") then
				origin = d
			elseif string.find(d.Name, "^marker_x") then
				xmark = d
			end
		end
	end
	-- the import's scale and offset, from the markers (Godot put them at 0 and at +30 studs along X)
	local k, o = 1, Vector3.zero
	if origin and xmark then
		local span = (xmark.Position - origin.Position).Magnitude
		if span > 0.001 then
			k = 30 / span
		end
		o = origin.Position
		if (xmark.Position - origin.Position).X < 0 then
			warn("[Timber] the Godot meshes came in mirrored")
		end
	end
	for _, p in parts do
		local base, kind, color = WorldMeshes.parseName(p.Name)
		if kind == "marker" then
			p:Destroy()
			continue
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = not NO_SHADOW[kind]
		p.Material = Enum.Material.SmoothPlastic
		if color then
			p.Color = color
		end
		if kind == "glow" then
			p.Material = Enum.Material.Neon       -- (Godot's emissive materials: the lamp, the computer's screen)
		end
		if kind == "ground" then
			-- the forest floor: Godot paints it with a shader (lighter and darker patches, drier areas, grain, pebbles
			-- on the dirt); its colours are baked into an image a chunk (ExportRobloxWorld), put on with TextureID
			local ck = string.match(base, "^ground_(%-?%d+_%-?%d+)")
			local tex = ck and groundTexture(ck)
			if tex then
				(p :: MeshPart).TextureID = tex
			end
		end
		if p:IsA("MeshPart") then
			p.TextureID = ""
		end
		if k ~= 1 then
			p.Size *= k
		end
		p.CFrame = CFrame.new((p.Position - o) * k) * p.CFrame.Rotation
		p:SetAttribute("GodotName", base)
		p.Parent = model
	end
	model.WorldPivot = CFrame.new()
	;(container :: Instance):Destroy()
	WorldMeshes.loaded[key] = model
	return model
end

-- the Godot world: in place, the stand-ins hidden
local function world()
	local m = WorldMeshes.load("GodotWorld")
	if not m then
		-- (no meshes: the stand-ins stay; trees that were built without crowns get simple ones)
		return
	end
	for _, p in m:GetChildren() do
		local _, kind = WorldMeshes.parseName(p.Name)
		-- the hatchet in the block is the game's own (it disappears when you take it); the world copy goes
		if kind == "blockhatchet" then
			p:Destroy()
		end
	end
	m.Name = "GodotWorld"
	m.Parent = workspace
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Standin") then
			d.Transparency = 1
		end
	end
	local solids = workspace:FindFirstChild("Solids")
	if solids then
		for _, p in solids:GetChildren() do
			(p :: BasePart).Transparency = 1
		end
	end
end

-- every tree's crown, on its own ("crown_17"): it falls with the log when the tree is felled
local function crowns()
	local m = WorldMeshes.load("GodotCrowns")
	if not m then
		return
	end
	m.Name = "GodotCrowns"
	-- (a tree felled before its crown arrived: that crown goes)
	local felled = {}
	local forest = workspace:FindFirstChild("Forest")
	for _, t in if forest then forest:GetChildren() else {} do
		if t:GetAttribute("Felled") then
			felled["crown_" .. tostring(t:GetAttribute("Index"))] = true
		end
	end
	for _, p in m:GetChildren() do
		if felled[p:GetAttribute("GodotName")] then
			p:Destroy()
		end
	end
	m.Parent = workspace
end

-- the trucks: the log truck's mesh rides on the truck (it moves with it)
local function trucks()
	local m = WorldMeshes.load("GodotTrucks")
	local truck = workspace:FindFirstChild("Truck") :: Model?
	if not m or not truck then
		return
	end
	local pivot = truck:GetPivot()
	local van = workspace:FindFirstChild("Van") :: Model?
	local vanPivot = if van then van:GetPivot() else CFrame.new()
	for _, p in m:GetChildren() do
		local base = WorldMeshes.parseName(p.Name)
		if string.find(base, "^ship") then
			(p :: BasePart).CFrame = pivot * (p :: BasePart).CFrame
			p.Parent = truck
		elseif van and string.find(base, "^van") then
			(p :: BasePart).CFrame = vanPivot * (p :: BasePart).CFrame
			p.Parent = van
		end
	end
	if van then
		for _, d in van:GetChildren() do
			if d:IsA("BasePart") and d:GetAttribute("Standin") then
				d.Transparency = 1
			end
		end
	end
	for _, d in truck:GetChildren() do
		if d:IsA("BasePart") and d:GetAttribute("Standin") then
			d.Transparency = 1
		end
	end
	m:Destroy()
end

-- the tools: each one's MeshParts around the hand's grip, replacing the stand-in models
local function tools()
	local m = WorldMeshes.load("GodotTools")
	local folder = ReplicatedStorage:FindFirstChild("ToolModels")
	if not m or not folder then
		return
	end
	local byTool: { [string]: Model } = {}
	for _, p in m:GetChildren() do
		local base = WorldMeshes.parseName(p.Name)
		local id = string.match(base, "^tool_(.+)$")
		if id then
			local tm = byTool[id]
			if not tm then
				tm = Instance.new("Model")
				tm.Name = id
				tm:SetAttribute("Godot", true)
				byTool[id] = tm
			end
			(p :: BasePart).CastShadow = false
			p.Parent = tm
		end
	end
	for id, tm in byTool do
		tm.WorldPivot = CFrame.new()        -- the grip
		local first = tm:FindFirstChildWhichIsA("BasePart")
		tm.PrimaryPart = first
		if first then
			first.Name = "Handle"
			tm.WorldPivot = CFrame.new()
		end
		local old = folder:FindFirstChild(id)
		if old then
			old:Destroy()
		end
		tm.Parent = folder
	end
	m:Destroy()
	-- the hatchet in the chopping block, now the Godot one
	local block = workspace:FindFirstChild("ChoppingBlock")
	local h = byTool.hatchet
	if block and h then
		local old = block:FindFirstChild("Hatchet")
		local WorldService = require(script.Parent.WorldService) :: any
		local copy = h:Clone()
		copy.Name = "Hatchet"
		for _, p in copy:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanQuery = true
				p.CastShadow = true
			end
		end
		WorldService.placeBlockHatchet(copy)
		copy.Parent = block
		if old then
			old:Destroy()
		end
	end
end

-- Godot's sky (a blue-to-pale gradient, rendered into six images by tools/make_sky.py): an uploaded image is a Decal
-- asset, so each face is loaded to read the image it points at
local function sky()
	local ok, Assets = pcall(require, ReplicatedStorage.Shared.Assets)
	if not ok or not (Assets :: any).SkyUp then
		return
	end
	local Lighting = game:GetService("Lighting")
	local s = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	local faces = { Up = "SkyboxUp", Dn = "SkyboxDn", Ft = "SkyboxFt", Bk = "SkyboxBk", Lf = "SkyboxLf", Rt = "SkyboxRt" }
	for k, prop in faces do
		local id = (Assets :: any)["Sky" .. k]
		if id then
			local got, container = pcall(function()
				return InsertService:LoadAsset(tonumber(id) :: number)
			end)
			local decal = got and container and (container :: Instance):FindFirstChildWhichIsA("Decal", true)
			if decal then
				(s :: any)[prop] = (decal :: Decal).Texture
			end
			if got and container then
				(container :: Instance):Destroy()
			end
		end
	end
	s.CelestialBodiesShown = true
	s.StarCount = 0
	s.Parent = Lighting
end

-- props: things the game puts up and changes (the company sign's tiers, ...), each a Model around its own origin
-- in ReplicatedStorage.Props (clients use some: the chimney's smoke puff), named after its group ("sign_3")
local function props()
	local m = WorldMeshes.load("GodotProps")
	if not m then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Props"
	local byName: { [string]: Model } = {}
	for _, p in m:GetChildren() do
		local base = WorldMeshes.parseName(p.Name)
		local name = string.gsub(base, "_p%d+$", "")
		if string.find(name, "^marker") then
			continue
		end
		-- a build's part (b__<id>__<part>__<resource or fin>): into the build's model, named after its index
		local bid, idx, res = string.match(name, "^b__(.-)__(%d+)__(.+)$")
		if bid then
			name = "b__" .. bid
			p.Name = idx :: string
			p:SetAttribute("Index", tonumber(idx))
			p:SetAttribute("Res", if res == "fin" then "" else res)
		end
		local model = byName[name]
		if not model then
			model = Instance.new("Model")
			model.Name = name
			model.WorldPivot = CFrame.new()
			model.Parent = folder
			byName[name] = model
		end
		p.Parent = model
	end
	folder.Parent = ReplicatedStorage
	m:Destroy()
end

function WorldMeshes.start()
	task.spawn(function()
		for _, f in { sky, world, crowns, trucks, tools, props } do
			local ok, err = pcall(f)
			if not ok then
				warn("[Timber] Godot meshes: " .. tostring(err))
			end
		end
	end)
end

return WorldMeshes
