-- Checks the Live Sync plugin against Rojo: from the same files, the plugin must make the same scripts, with the
-- same classes, names, places and sources, as the place Rojo built.
--   lune run tests/lune/sync.luau <path to Timber.rbxl>     (from the repository root or roblox/)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local here = string.match(process.args[0] or "", "^(.*)/tests/lune/") or "roblox"
local repo = here .. "/.."
local place = roblox.deserializePlace(fs.readFile(process.args[1] or "Timber.rbxl"))

local fails = 0
local function check(ok: boolean, msg: string)
	print((if ok then "PASS " else "FAIL ") .. msg)
	if not ok then
		fails += 1
	end
end

local Core = luau.load(fs.readFile(here .. "/plugin/TimberSync.lua"), { debugName = "TimberSync", environment = setmetatable({ plugin = nil }, { __index = _G }) })()

-- the git endpoint's reply, as GitHub sends it
local sample = "001e# service=git-upload-pack\n0000017e00f7d61b682dcad1ce1f9e33efa4a572c2983f8d HEAD\0multi_ack thin-pack\n"
	.. "006200f7d61b682dcad1ce1f9e33efa4a572c2983f8d refs/heads/claude/roblox-islands-factory-game-u7anm4\n"
	.. "003fabcdefabcdefabcdefabcdefabcdefabcdefabcd refs/heads/main\n0000"
check(Core.parseRefs(sample, "claude/roblox-islands-factory-game-u7anm4") == "00f7d61b682dcad1ce1f9e33efa4a572c2983f8d", "reads the branch's latest commit from git's reply")
check(Core.parseRefs(sample, "main") == "abcdefabcdefabcdefabcdefabcdefabcdefabcd", "and tells branches apart")
check(Core.parseRefs(sample, "nope") == nil, "and finds nothing for a branch that isn't there")

-- every file in the repository, the way GitHub's file list gives them
local files = {}
local res = process.exec("git", { "ls-files" }, { cwd = repo })
for line in string.gmatch(res.stdout, "[^\n]+") do
	table.insert(files, line)
end
local project = serde.decode("json", fs.readFile(here .. "/default.project.json"))
local synced, props = Core.plan(project, files, "roblox/")
check(#synced == 3, "syncs the three code folders (" .. #synced .. ")")
check(#props >= 7, "and applies the Workspace and Lighting settings (" .. #props .. ")")

-- compare with what Rojo built
local count = 0
local function compare(node, inst, where: string)
	if not inst then
		check(false, where .. " is missing from the Rojo place")
		return
	end
	if inst.ClassName ~= node.className then
		check(false, string.format("%s is a %s, Rojo made a %s", where, node.className, inst.ClassName))
	end
	if node.path then
		count += 1
		local src = fs.readFile(repo .. "/" .. node.path)
		if inst.Source ~= src then
			check(false, where .. " has different source from Rojo's")
		end
	end
	local rojoKids = 0
	for _, c in inst:GetChildren() do
		if c:IsA("LuaSourceContainer") or c:IsA("Folder") then
			rojoKids += 1
		end
	end
	if rojoKids ~= #node.children then
		check(false, string.format("%s has %d children, Rojo's has %d", where, #node.children, rojoKids))
	end
	for _, c in node.children do
		compare(c, inst:FindFirstChild(c.name), where .. "." .. c.name)
	end
end
local before = fails
for _, s in synced do
	local parent: any = place
	for _, name in s.parent do
		parent = if parent == place then place:GetService(name) else parent:FindFirstChild(name)
	end
	compare(s.node, parent and parent:FindFirstChild(s.node.name), table.concat(s.parent, ".") .. "." .. s.node.name)
end
check(fails == before and count > 20, "builds the same " .. count .. " scripts as Rojo, in the same places")

-- property short forms
local types = { Vector3 = roblox.Vector3, Color3 = roblox.Color3 }
local v = Core.convert({ 1, 2, 3 }, roblox.Vector3.new(0, 0, 0), types)
local c = Core.convert({ 0.5, 0.25, 1 }, roblox.Color3.new(0, 0, 0), types)
local e = Core.convert("Grass", roblox.Enum.Material.Plastic, types)
check(v == roblox.Vector3.new(1, 2, 3) and c == roblox.Color3.new(0.5, 0.25, 1) and e == roblox.Enum.Material.Grass and Core.convert(2.4, 1, types) == 2.4, "turns the project file's numbers into Vector3s, Colors and Enums")

print(string.format("\nSYNC RESULT: %s", if fails == 0 then "PASS" else "FAIL"))
process.exit(if fails == 0 then 0 else 1)
