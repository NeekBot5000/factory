-- Builds the Roblox world the way a player sees it, for Roblox's own renderer to draw (tools/roblox_engine.py).
-- The game's real scripts run in the Lune harness, with InsertService handing out the models and textures Roblox
-- made from the uploads (TIMBER_ASSETS: a folder of downloaded <key>.rbxm). Then, for each of the Godot views
-- (tests/engine/views.json, written by tools/RobloxView), the whole world is saved as a model with a
-- ThumbnailCamera at that view. Roblox's thumbnail of each one is the real thing, drawn by Roblox.
--   TIMBER_ASSETS=build/assets lune run roblox/tests/engine/scenes.luau Timber.rbxl build/scenes
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local Harness = require("../lune/harness")
local ClientHarness = require("../lune/clientharness")

local place = process.args[1] or "Timber.rbxl"
local outDir = process.args[2] or "build/scenes"
local views = serde.decode("json", fs.readFile(process.args[3] or "roblox/tests/engine/views.json"))
local W = require("../../src/shared/GodotWorld")
local STUD = 3
fs.writeDir(outDir)

local S = Harness.boot(place, "scenes")
S.start()
task.wait(0.1)
local at = W.spawn.at
local alice = S.join(101, "Alice", roblox.Vector3.new(at[1], at[2] + 3, at[3]))
task.wait(0.6)
local C = ClientHarness.start(S, alice)
C.boot()
C.frames(5)
task.wait(2.5)
local title = C.gui("TitleMenu")
local newGame = title and C.find(title, function(d)
	return d:IsA("TextButton") and d.Text == "New Game"
end)
if newGame then
	ClientHarness.signal(newGame, "Activated"):Fire()
end

local meshParts = 0
for _, d in S.workspace:GetDescendants() do
	if d.ClassName == "MeshPart" then
		meshParts += 1
	end
end
print("SCENES mesh parts in the world: " .. meshParts)

-- (Lune keeps a MeshPart's texture as TextureContent, and drops a plain TextureID: put the ground's back)
local fixed = 0
for _, d in S.workspace:GetDescendants() do
	local tex = d.ClassName == "MeshPart" and d:GetAttribute("GodotTexture")
	if tex then
		local ok = pcall(function()
			d.TextureContent = roblox.Content.fromUri(tex)
		end)
		if ok then
			fixed += 1
		end
	end
end
print("SCENES ground textures put on: " .. fixed)

local SKIP = { Camera = true, Terrain = true, Script = true, LocalScript = true, ModuleScript = true }
for _, v in views do
	local b = v.basis
	local cf = roblox.CFrame.fromMatrix(
		roblox.Vector3.new(v.origin[1], v.origin[2], v.origin[3]) * STUD,
		roblox.Vector3.new(b[1], b[2], b[3]),
		roblox.Vector3.new(b[4], b[5], b[6]),
		roblox.Vector3.new(b[7], b[8], b[9])
	)
	-- let the client draw what's near this view (trees close by get their full look)
	C.camera.CFrame = cf
	for _ = 1, 20 do
		C.frame(1 / 30)
		task.wait()
	end
	local scene = roblox.Instance.new("Model")
	scene.Name = "Timber_" .. v.name
	for _, child in S.workspace:GetChildren() do
		local isChar = child.ClassName == "Model" and child:FindFirstChildOfClass("Humanoid") ~= nil
		if not SKIP[child.ClassName] and not isChar then
			local ok, copy = pcall(function()
				return child:Clone()
			end)
			if ok and copy then
				for _, d in copy:GetDescendants() do
					if SKIP[d.ClassName] then
						d:Destroy()
					end
				end
				copy.Parent = scene
			end
		end
	end
	local cam = roblox.Instance.new("Camera")
	cam.Name = "ThumbnailCamera"
	cam.CFrame = cf
	cam.FieldOfView = 75
	cam.Parent = scene
	local bytes = roblox.serializeModel({ scene })
	fs.writeFile(outDir .. "/" .. v.name .. ".rbxm", bytes)
	print(string.format("SCENES %s: %d parts, %.1f MB", v.name, #scene:GetDescendants(), #bytes / 1e6))
	scene:Destroy()
end
process.exit(0)
