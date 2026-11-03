--!nocheck
-- Timber Live Sync: a Roblox Studio plugin that keeps the open place in step with the GitHub branch.
-- Every push shows up in Studio within about 10 seconds, with no downloads and no Rojo.
--
-- Install once: in Studio, Plugins tab > Plugins Folder, put this file there, then restart Studio.
-- Then open any place (a new Baseplate is fine), and click Plugins > Timber > Live Sync.
--
-- It reads roblox/default.project.json from the branch and builds the same instances Rojo would:
-- ReplicatedStorage.Shared, ServerScriptService.Server and StarterPlayerScripts.Client are replaced on each sync,
-- and the Workspace and Lighting settings in the project file are applied. Nothing else in the place is touched.
--
-- How it checks for pushes without hitting GitHub's limits: it asks GitHub's git endpoint (the one `git fetch`
-- uses, which has no hourly limit) for the branch's latest commit every 10 s. Only when that changes does it list
-- the files (one API call) and download them by commit, so it never gets a stale copy.

local OWNER = "NeekBot5000"
local REPO = "factory"
local BRANCH = "claude/roblox-islands-factory-game-u7anm4"
local ROOT = "roblox/"                -- where default.project.json lives in the repository
local POLL_SECONDS = 10

local Core = {}

-- ------------------------------------------------------------------ pure parts (also run by the Lune check)

-- the commit id for the branch, from git's "info/refs" reply
function Core.parseRefs(body: string, branch: string): string?
	for sha, ref in string.gmatch(body, "(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x) ([^%s%z]+)") do
		if ref == "refs/heads/" .. branch then
			return sha
		end
	end
	return nil
end

-- what a file becomes, Rojo's way: x.server.luau is a Script, x.client.luau a LocalScript, x.luau a ModuleScript
local function scriptKind(file: string): (string?, string?)
	for _, ext in { ".luau", ".lua" } do
		if string.sub(file, -#ext) == ext then
			local stem = string.sub(file, 1, -#ext - 1)
			if string.sub(stem, -7) == ".server" then
				return "Script", string.sub(stem, 1, -8)
			elseif string.sub(stem, -7) == ".client" then
				return "LocalScript", string.sub(stem, 1, -8)
			end
			return "ModuleScript", stem
		end
	end
	return nil, nil
end

-- Turns a folder of files into a node tree: { name, className, path (for scripts), children }.
-- `files` lists every file path in the repository; `dir` is the folder, like "roblox/src/server".
function Core.folderNode(name: string, dir: string, files: { string })
	local node = { name = name, className = "Folder", children = {} }
	local subdirs, order = {}, {}
	for _, f in files do
		if string.sub(f, 1, #dir + 1) == dir .. "/" then
			local rest = string.sub(f, #dir + 2)
			local slash = string.find(rest, "/", 1, true)
			if slash then
				local sub = string.sub(rest, 1, slash - 1)
				if not subdirs[sub] then
					subdirs[sub] = true
					table.insert(order, sub)
				end
			else
				local kind, stem = scriptKind(rest)
				if kind and stem == "init" then
					-- init.server.luau and friends make the folder itself a script
					node.className = kind
					node.path = f
				elseif kind then
					table.insert(node.children, { name = stem, className = kind, path = f, children = {} })
				end
			end
		end
	end
	table.sort(order)
	for _, sub in order do
		table.insert(node.children, Core.folderNode(sub, dir .. "/" .. sub, files))
	end
	table.sort(node.children, function(a, b)
		return a.name < b.name
	end)
	return node
end

-- Walks the project file. Returns the synced folders ({ parent path, node }) and the property settings
-- ({ instance path, className, properties }) in the order they appear.
function Core.plan(project, files: { string }, root: string)
	local synced, props = {}, {}
	local function walk(tree, path: { string })
		for key, child in tree do
			if string.sub(key, 1, 1) ~= "$" and type(child) == "table" then
				local here = table.clone(path)
				table.insert(here, key)
				if child["$path"] then
					local dir = root .. child["$path"]
					table.insert(synced, { parent = path, node = Core.folderNode(key, dir, files) })
				else
					if child["$properties"] or child["$className"] then
						table.insert(props, { path = here, className = child["$className"], properties = child["$properties"] or {} })
					end
					walk(child, here)
				end
			end
		end
	end
	local top = project.tree
	if top["$properties"] then
		table.insert(props, { path = {}, properties = top["$properties"] })
	end
	walk(top, {})
	table.sort(synced, function(a, b)
		return table.concat(a.parent, ".") .. a.node.name < table.concat(b.parent, ".") .. b.node.name
	end)
	table.sort(props, function(a, b)
		return #a.path < #b.path or (#a.path == #b.path and table.concat(a.path, ".") < table.concat(b.path, "."))
	end)
	return synced, props
end

-- Converts a value from the project file to the type the property already has (Rojo's short forms).
function Core.convert(value, current, types)
	local t = typeof(current)
	if t == "Vector3" and type(value) == "table" then
		return types.Vector3.new(value[1], value[2], value[3])
	elseif t == "Color3" and type(value) == "table" then
		return types.Color3.new(value[1], value[2], value[3])
	elseif t == "EnumItem" and type(value) == "string" then
		return (current :: any).EnumType[value]
	end
	return value
end

if not plugin then
	return Core     -- loaded by the Lune check, not by Studio
end

-- ------------------------------------------------------------------ the Studio side
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

if not RunService:IsEdit() then
	return          -- plugins also start inside Play sessions: only sync the place you're editing
end

local toolbar = plugin:CreateToolbar("Timber")
local liveButton = toolbar:CreateButton("Live Sync", "Keep this place in step with the Timber branch on GitHub", "rbxassetid://4458901886")
local nowButton = toolbar:CreateButton("Sync Now", "Pull the latest Timber code once", "rbxassetid://4458901886")
liveButton.ClickableWhenViewportHidden = true
nowButton.ClickableWhenViewportHidden = true

local live = plugin:GetSetting("TimberLiveSync") == true
local lastSha: string? = nil
local busy = false

local function get(url: string, headers: { [string]: string }?): string
	local res = HttpService:RequestAsync({ Url = url, Method = "GET", Headers = headers })
	if not res.Success then
		error(string.format("%s %s for %s", res.StatusCode, res.StatusMessage, url))
	end
	return res.Body
end

local function latestSha(): string?
	local body = get(string.format("https://github.com/%s/%s.git/info/refs?service=git-upload-pack", OWNER, REPO))
	return Core.parseRefs(body, BRANCH)
end

local function findPath(path: { string }): Instance?
	local inst: Instance = game
	for _, name in path do
		local nextInst = if inst == game then game:GetService(name) else inst:FindFirstChild(name)
		if not nextInst then
			return nil
		end
		inst = nextInst
	end
	return inst
end

local function build(node, sources: { [string]: string }): Instance
	local inst = Instance.new(node.className)
	inst.Name = node.name
	if node.path then
		(inst :: any).Source = sources[node.path]
	end
	for _, child in node.children do
		build(child, sources).Parent = inst
	end
	return inst
end

local function collectPaths(node, out: { string })
	if node.path then
		table.insert(out, node.path)
	end
	for _, c in node.children do
		collectPaths(c, out)
	end
end

local function sync(sha: string)
	busy = true
	local started = os.clock()
	local ok, err = pcall(function()
		local raw = string.format("https://raw.githubusercontent.com/%s/%s/%s/", OWNER, REPO, sha)
		local project = HttpService:JSONDecode(get(raw .. ROOT .. "default.project.json"))
		local treeJson = HttpService:JSONDecode(get(string.format("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1", OWNER, REPO, sha)))
		local files = {}
		for _, entry in treeJson.tree do
			if entry.type == "blob" then
				table.insert(files, entry.path)
			end
		end
		local synced, props = Core.plan(project, files, ROOT)

		-- download every script first, all at once, so a failed download leaves the place untouched
		local paths = {}
		for _, s in synced do
			collectPaths(s.node, paths)
		end
		local sources, pending, failed = {}, #paths, nil
		for _, p in paths do
			task.spawn(function()
				local okFile, body = pcall(get, raw .. p)
				if okFile then
					sources[p] = body
				else
					failed = body
				end
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
		if failed then
			error(failed)
		end

		local recording = ChangeHistoryService:TryBeginRecording("Timber Live Sync")
		for _, s in synced do
			local parent = findPath(s.parent)
			if not parent then
				-- e.g. StarterPlayerScripts in an odd template: make the missing containers
				parent = game
				for _, name in s.parent do
					local nextInst = if parent == game then game:GetService(name) else parent:FindFirstChild(name)
					if not nextInst then
						nextInst = Instance.new("Folder")
						nextInst.Name = name
						nextInst.Parent = parent
					end
					parent = nextInst
				end
			end
			local old = parent:FindFirstChild(s.node.name)
			local fresh = build(s.node, sources)
			if old then
				old:Destroy()
			end
			fresh.Parent = parent
		end
		local skipped = {}
		for _, p in props do
			local inst = findPath(p.path)
			if not inst and p.className and #p.path > 0 then
				local parentPath = table.clone(p.path)
				local name = table.remove(parentPath)
				local parent = findPath(parentPath)
				if parent then
					inst = Instance.new(p.className)
					inst.Name = name
					inst.Parent = parent
				end
			end
			if inst then
				for prop, value in p.properties do
					local okProp = pcall(function()
						(inst :: any)[prop] = Core.convert(value, (inst :: any)[prop], { Vector3 = Vector3, Color3 = Color3 })
					end)
					if not okProp then
						table.insert(skipped, inst.Name .. "." .. prop)
					end
				end
			end
		end
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
		print(string.format("[Timber] Synced to %s: %d scripts in %.1f s. Press Play to try it.", string.sub(sha, 1, 7), #paths, os.clock() - started))
		if #skipped > 0 then
			print("[Timber] (Studio wouldn't let a plugin set: " .. table.concat(skipped, ", ") .. ")")
		end
	end)
	busy = false
	if ok then
		lastSha = sha
	else
		warn("[Timber] Sync failed, will try again: " .. tostring(err))
	end
end

local function check(force: boolean)
	if busy then
		return
	end
	local ok, sha = pcall(latestSha)
	if not ok then
		warn("[Timber] Couldn't reach GitHub: " .. tostring(sha))
		return
	end
	if sha and (force or sha ~= lastSha) then
		sync(sha)
	end
end

local function setLive(on: boolean)
	live = on
	plugin:SetSetting("TimberLiveSync", on)
	liveButton:SetActive(on)
	print(if on then "[Timber] Live Sync is on: pushes to GitHub appear here within about 10 seconds." else "[Timber] Live Sync is off.")
	if on then
		task.spawn(check, false)
	end
end

liveButton.Click:Connect(function()
	setLive(not live)
end)
nowButton.Click:Connect(function()
	task.spawn(check, true)
end)

liveButton:SetActive(live)
task.spawn(function()
	if live then
		check(false)
	end
	while true do
		task.wait(POLL_SECONDS)
		if live then
			check(false)
		end
	end
end)
