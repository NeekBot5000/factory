local process = require("@lune/process")
-- Lune check (no Roblox needed): runs roblox/src/server/Services/TestWorld.luau against Lune's Roblox objects, which check every class and
-- property name against Roblox's own API list.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile(process.args[1] or "Timber.rbxl"))
local workspace = game:GetService("Workspace")
local tagged = {}
local CollectionService = {
	AddTag = function(_, inst, tag)
		inst:AddTag(tag)
		tagged[tag] = (tagged[tag] or 0) + 1
	end,
}
local function makeRandom(seed)
	local state = seed
	return {
		NextNumber = function(_, a, b)
			state = (state * 1103515245 + 12345) % 2147483648
			return a + (b - a) * (state / 2147483648)
		end,
	}
end
local env
local function req(inst)
	local fn = luau.load(inst.Source, { debugName = inst.Name, environment = env })
	return fn()
end
local fakeGame = setmetatable({}, { __index = function(_, k)
	if k == "GetService" then
		return function(_, name)
			if name == "CollectionService" then
				return CollectionService
			end
			return game:GetService(name)
		end
	end
	return game[k]
end })
env = setmetatable({
	game = fakeGame, workspace = workspace, require = req,
	Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	Enum = roblox.Enum, Random = { new = makeRandom },
}, { __index = _G })
local TestWorld = req(game:GetService("ServerScriptService").Server.Services.TestWorld)
TestWorld.start()
local forest = workspace:FindFirstChild("Forest")
local trees = forest and #forest:GetChildren() or 0
local truck = workspace:FindFirstChild("Truck")
print(string.format("TESTWORLD trees=%d tagged=%d truck=%s bed=%s prompt=%s", trees, tagged.Tree or 0, tostring(truck ~= nil),
	tostring(truck and truck:FindFirstChild("Bed") ~= nil), tostring(truck and truck:FindFirstChild("Cab") and truck.Cab:FindFirstChildOfClass("ProximityPrompt") ~= nil)))
local t1 = forest:GetChildren()[1]
print("TESTWORLD first tree", t1.Name, t1:GetAttribute("Species"), t1:GetAttribute("Radius"), t1:GetAttribute("Height"), "pivot", t1.WorldPivot.Position)
-- (the world is built when the server starts; nothing to save here)
assert(trees == 35 and (tagged.Tree or 0) == 35 and truck, "the test world didn't build")
print("LUNE TESTWORLD PASS")
process.exit(0)
