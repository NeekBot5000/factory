-- Dumps what the Roblox scripts build, for tools/RobloxView (the visual check against the Godot game): every part in
-- the workspace after a player has joined at the porch and the client has drawn the trees around them, and the
-- camera. Mesh assets don't load in Lune; RobloxView puts in the uploaded Godot meshes the way WorldMeshes does.
--   lune run tests/lune/dump.luau <path to Timber.rbxl> <out.json>
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local Harness = require("./harness")
local ClientHarness = require("./clientharness")

local place = process.args[1] or "Timber.rbxl"
local out = process.args[2] or "roblox_scene.json"
local W = require("../../src/shared/GodotWorld")

local S = Harness.boot(place, "dump")
S.start()
task.wait(0.1)
local at = W.spawn.at
local alice = S.join(101, "Alice", roblox.Vector3.new(at[1], at[2] + 3, at[3]))
task.wait(0.6)
local C = ClientHarness.start(S, alice)
print("DUMP boot")
C.boot()
print("DUMP booted")
C.frames(5)
task.wait(2.5)
local title = C.gui("TitleMenu")
local newGame = title and C.find(title, function(d)
	return d:IsA("TextButton") and d.Text == "New Game"
end)
if newGame then
	ClientHarness.signal(newGame, "Activated"):Fire()
end
-- let the client draw the trees near you (the camera where Godot's eye is, on the porch)
local views = process.args[3]
if views then
	local v = serde.decode("json", fs.readFile(views))[1]
	C.camera.CFrame = roblox.CFrame.new(v.origin[1] * 3, v.origin[2] * 3, v.origin[3] * 3)
end
for _ = 1, 30 do
	C.frame(1 / 30)
	task.wait()
end

print("DUMP drawing done")
local parts = {}
local function cfOf(cf)
	local c = { cf:GetComponents() }
	return c
end
local all = S.workspace:GetDescendants()
print("DUMP descendants", #all)
local t0 = os.clock()
for n, d in all do
	if d.ClassName == "Part" or d.ClassName == "MeshPart" or d.ClassName == "WedgePart" or d.ClassName == "SpawnLocation" then
		-- (the top folder under the workspace, and the parent: enough to tell what built it)
		local top, p = d, d.Parent
		local chain = {}
		while p and p ~= S.workspace and #chain < 8 do
			table.insert(chain, 1, p.Name)
			top = p
			p = p.Parent
		end
		if chain[1] ~= "Alice" then
			table.insert(parts, {
				name = d.Name,
				path = table.concat(chain, "."),
				shape = if d.ClassName == "Part" then d.Shape.Name else d.ClassName,
				size = { d.Size.X, d.Size.Y, d.Size.Z },
				cf = cfOf(d.CFrame),
				color = { d.Color.R, d.Color.G, d.Color.B },
				transparency = math.max(d.Transparency, (pcall(function() return d.LocalTransparencyModifier end) and d.LocalTransparencyModifier) or 0),
				material = d.Material.Name,
				standin = d:GetAttribute("Standin") == true,
			})
		end
	end
	if n % 2000 == 0 then
		print("DUMP", n, os.clock() - t0)
	end
end
print("DUMP loop done", #parts)
local cam = C.camera
print("DUMP cam", cam)
local camcf = cfOf(cam.CFrame)
print("DUMP camcf")
local fov = cam.FieldOfView
print("DUMP fov", fov)
-- (written by hand: Lune's JSON encoder crawls on this many entries)
local function nums(t)
	local o = {}
	for k, v in t do
		o[k] = string.format("%.4f", v)
	end
	return "[" .. table.concat(o, ",") .. "]"
end
local function str(x)
	return '"' .. string.gsub(x, '[%c"\\]', "_") .. '"'
end
local lines = {}
for _, p in parts do
	table.insert(lines, string.format('{"name":%s,"path":%s,"shape":%s,"size":%s,"cf":%s,"color":%s,"transparency":%.3f,"material":%s}',
		str(p.name), str(p.path), str(p.shape), nums(p.size), nums(p.cf), nums(p.color), if p.standin then 1 else p.transparency, str(p.material)))
end
local pivots = {}
for _, name in { "Truck", "Van" } do
	local m = S.workspace:FindFirstChild(name)
	if m then
		table.insert(pivots, string.format('"%s":%s', name, nums({ m:GetPivot():GetComponents() })))
	end
end
local json = '{"pivots":{' .. table.concat(pivots, ",") .. '},"camera":' .. nums(camcf) .. ',"fov":' .. fov .. ',"parts":[\n' .. table.concat(lines, ",\n") .. "\n]}"
print("DUMP encoded", #json)
fs.writeFile(out, json)
print(string.format("DUMP %d parts -> %s", #parts, out))
process.exit(0)
