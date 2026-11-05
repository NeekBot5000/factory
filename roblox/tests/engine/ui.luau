-- The game's screens drawn by Roblox, at a phone's size and a desktop's (tools/roblox_engine.py): the client
-- scripts build their ScreenGuis in the Lune harness; each one is copied onto a SurfaceGui (Roblox's own layout,
-- fonts and text) on a flat panel the size of the screen, with a ThumbnailCamera looking straight at it. Roblox's
-- thumbnail of the model is then what that screen looks like.
--   TIMBER_ASSETS=build/assets lune run roblox/tests/engine/ui.luau Timber.rbxl build/ui
local fs = require("@lune/fs")
local process = require("@lune/process")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local Harness = require("../lune/harness")
local ClientHarness = require("../lune/clientharness")

local place = process.args[1] or "Timber.rbxl"
local outDir = process.args[2] or "build/ui"
local V3 = roblox.Vector3.new
local K = roblox.Enum.KeyCode
local W = require("../../src/shared/GodotWorld")
fs.writeDir(outDir)

local S = Harness.boot(place, "ui")
S.start()
task.wait(0.1)
local at = W.spawn.at
local alice = S.join(101, "Alice", V3(at[1], at[2] + 3, at[3]))
task.wait(0.6)
local C = ClientHarness.start(S, alice)
C.boot()
C.frames(5)
task.wait(2.5)
local title = C.gui("TitleMenu")

-- one screen: the ScreenGuis named, copied onto a panel of w x h pixels, saved as <name>.rbxm
local SIZES = { phone = { 844, 390 }, desktop = { 1920, 1080 } }
local function shoot(name: string, guiNames: { string })
	for kind, wh in SIZES do
		local w, h = wh[1], wh[2]
		local model = roblox.Instance.new("Model")
		model.Name = "TimberUI_" .. name .. "_" .. kind
		-- the panel: 1 stud = 100 px; a green backdrop like the game's grass behind the HUD
		local panel = roblox.Instance.new("Part")
		panel.Name = "Screen"
		panel.Anchored = true
		panel.Size = V3(w / 100, h / 100, 0.1)
		panel.CFrame = roblox.CFrame.new(0, 0, 0)
		panel.Color = roblox.Color3.fromHex("4f8a35")
		panel.Material = roblox.Enum.Material.SmoothPlastic
		panel.Parent = model
		local sg = roblox.Instance.new("SurfaceGui")
		sg.Face = roblox.Enum.NormalId.Front
		sg.SizingMode = roblox.Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = roblox.Vector2.new(w, h)
		sg.LightInfluence = 0
		sg.Parent = panel
		for _, gname in guiNames do
			local g = C.gui(gname)
			if g then
				for _, child in g:GetChildren() do
					local ok, copy = pcall(function()
						return child:Clone()
					end)
					if ok and copy then
						copy.Parent = sg
					end
				end
			end
		end
		-- the camera: straight at the panel's front (-Z), far enough back to fit its width
		local fov = 20
		local dist = (w / 100) / 2 / math.tan(math.rad(fov / 2)) / (16 / 9) * 1.02
		local cam = roblox.Instance.new("Camera")
		cam.Name = "ThumbnailCamera"
		cam.CFrame = roblox.CFrame.new(V3(0, 0, -dist), V3(0, 0, 0))
		cam.FieldOfView = fov
		cam.Parent = model
		fs.writeFile(outDir .. "/" .. name .. "_" .. kind .. ".rbxm", roblox.serializeModel({ model }))
		print(string.format("UI %s_%s: %d", name, kind, #model:GetDescendants()))
	end
end

-- 1. the title screen
shoot("title", { "TitleMenu" })
local newGame = title and C.find(title, function(d)
	return d:IsA("TextButton") and d.Text == "New Game"
end)
if newGame then
	ClientHarness.signal(newGame, "Activated"):Fire()
end
C.frames(10)
task.wait(1)
-- 2. playing: the HUD with a few tools, money, the Getting started panel and a hint
for _, id in { "hatchet", "double_bit", "saw", "hammer", "phone" } do
	S.service("ToolService").grant(alice, id)
end
S.service("EconomyService").addMoney(alice, 1234.5)
task.wait(0.3)
C.frames(10)
shoot("hud", { "Hud" })
-- 3. the TimberPhone (TimberMart, the Lumberjacks list, codes)
C.press(K.Tab)
C.frames(5)
shoot("phone", { "TimberMart" })
process.exit(0)
