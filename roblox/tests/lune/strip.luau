local process = require("@lune/process")
-- Lune check (no Roblox needed): builds the test world, then plays one hatchet swing through TreeService's real request handler.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local game = roblox.deserializePlace(fs.readFile(process.args[1] or "Timber.rbxl"))
local workspace = game:GetService("Workspace")
local tags = {}
local CollectionService = {
	AddTag = function(_, inst, tag) inst:AddTag(tag) end,
	HasTag = function(_, inst, tag) return inst:HasTag(tag) end,
	GetTagged = function(_, tag)
		local out = {}
		for _, d in workspace:GetDescendants() do
			if d:HasTag(tag) then table.insert(out, d) end
		end
		return out
	end,
}
local handlers, fired = {}, {}
local function fakeEvent(name)
	return {
		OnServerEvent = { Connect = function(_, f) handlers[name] = f end },
		FireAllClients = function(_, ...) table.insert(fired, name) end,
		FireClient = function() end,
	}
end
local remotes = { StripRequest = fakeEvent("StripRequest"), TreeChanged = fakeEvent("TreeChanged") }
local fakeRS = {
	WaitForChild = function(_, n) return remotes end,
	Shared = game:GetService("ReplicatedStorage").Shared,
}
local Players = { PlayerRemoving = { Connect = function() end } }
local profile = { owned = { hands = true, hatchet = true } }
local DataService = { get = function() return profile end }
local env
local loaded = {}
local function req(inst)
	if inst == "DataService" then return DataService end
	if loaded[inst] then return loaded[inst] end
	-- (Lune has no engine methods like GetPivot; a model's WorldPivot is the same thing for these trees)
	local src = string.gsub(inst.Source, ":GetPivot%(%)", ".WorldPivot")
	local fn = luau.load(src, { debugName = inst.Name, environment = env })
	loaded[inst] = fn()
	return loaded[inst]
end
local fakeGame = setmetatable({}, { __index = function(_, k)
	if k == "GetService" then
		return function(_, name)
			if name == "CollectionService" then return CollectionService end
			if name == "ReplicatedStorage" then return fakeRS end
			if name == "Players" then return Players end
			return game:GetService(name)
		end
	end
	return game[k]
end })
local function makeRandom(seed)
	local s = seed
	return { NextNumber = function(_, a, b) s = (s * 1103515245 + 12345) % 2147483648 return a + (b - a) * (s / 2147483648) end }
end
env = setmetatable({
	game = fakeGame, workspace = workspace, require = function(x)
		if typeof(x) == "table" and x.__name == "DataService" then return DataService end
		return req(x)
	end,
	script = { Parent = { DataService = { __name = "DataService" } } },
	Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	Enum = roblox.Enum, Random = { new = makeRandom }, task = task,
}, { __index = _G })
local services = game:GetService("ServerScriptService").Server.Services
req(services.TestWorld).start()
local TreeService = req(services.TreeService)
TreeService.start()
-- a pretend player standing next to the first tree
local tree = workspace.Forest:GetChildren()[1]
local base = tree.WorldPivot.Position
local head = roblox.Instance.new("Part")
head.Name = "Head"
head.Position = base + roblox.Vector3.new(tree:GetAttribute("Radius") + 3, 5, 0)
local character = roblox.Instance.new("Model")
head.Parent = character
local player = { Character = character, UserId = 1, Name = "Tester" }
local point = base + roblox.Vector3.new(tree:GetAttribute("Radius"), 5, 0)
handlers.StripRequest(player, tree, point, "hatchet")
local sheets = workspace.Loose:GetChildren()
local bark = tree:GetAttribute("Bark")
print(string.format("STRIP sheets=%d value=%s bark=%s events=%d", #sheets, tostring(sheets[1] and sheets[1]:GetAttribute("Value")), tostring(bark), #fired))
-- too far away: refused
local far = base + roblox.Vector3.new(100, 5, 0)
task.wait(1)
handlers.StripRequest(player, tree, far, "hatchet")
print("STRIP after a far request, sheets=" .. #workspace.Loose:GetChildren())
-- a tool they don't own: refused
task.wait(1)
handlers.StripRequest(player, tree, point, "greataxe")
print("STRIP after an unowned tool, sheets=" .. #workspace.Loose:GetChildren())
-- a bad argument: ignored
handlers.StripRequest(player, "not a tree", point, "hatchet")
print("STRIP bad arguments ignored")
assert(#sheets >= 1 and sheets[1]:GetAttribute("Value") > 0 and typeof(bark) == "string" and #fired >= 1, "a swing didn't peel bark")
assert(#workspace.Loose:GetChildren() == #sheets, "a refused swing still peeled bark")
print("LUNE STRIP PASS")
process.exit(0)
