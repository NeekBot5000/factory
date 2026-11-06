--!strict
-- Server events (timed things that bring a server together, as popular Roblox games have). The golden tree: every
-- Config.GoldenTree.every seconds while someone's playing, a standing tree near the cabin turns gold for a while.
-- Its outer bark is worth Config.GoldenTree.value times as much (TreeService), it sparkles, and everyone is told
-- roughly where it is. When the time's up (or it's felled) it goes back to normal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage.Shared.Config)

local EventService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local M = Config.StudsPerMetre
EventService.golden = nil :: Model?

-- which way it is from the cabin, in words (north is -Z, as in Godot)
local function direction(p: Vector3): string
	local a = math.deg(math.atan2(p.X, -p.Z)) % 360
	local names = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }
	return names[math.floor((a + 22.5) / 45) % 8 + 1]
end

local function standing(t: Instance): boolean
	return t:IsA("Model") and not t:GetAttribute("Felled") and not t:GetAttribute("Log") and t.Parent ~= nil
end

-- ends the golden tree: back to its own bark
function EventService.endGolden()
	local t = EventService.golden
	EventService.golden = nil
	ReplicatedStorage:SetAttribute("GoldenWhere", nil)
	if not t then
		return
	end
	if t.Parent then
		t:SetAttribute("Golden", nil)
		local trunk = t:FindFirstChild("Trunk") :: BasePart?
		if trunk then
			local was = trunk:GetAttribute("WasColor")
			if typeof(was) == "Color3" then
				trunk.Color = was
			end
			local sp = trunk:FindFirstChild("GoldenSparkles")
			if sp then
				sp:Destroy()
			end
		end
	end
end

-- starts it on a tree (a random standing one near the cabin if none is given); returns the tree
function EventService.startGolden(tree: Model?): Model?
	EventService.endGolden()
	local pick = tree
	if not pick then
		local near = {}
		for _, t in CollectionService:GetTagged("Tree") do
			if standing(t) and not t:GetAttribute("Giant") and (t:GetPivot().Position * Vector3.new(1, 0, 1)).Magnitude < Config.GoldenTree.within * M then
				table.insert(near, t)
			end
		end
		if #near == 0 then
			return nil
		end
		pick = near[math.random(1, #near)] :: Model
	end
	local t = pick :: Model
	EventService.golden = t
	t:SetAttribute("Golden", true)
	local trunk = t:FindFirstChild("Trunk") :: BasePart?
	if trunk then
		-- (far away, before a client draws its panels, the plain trunk shows gold too; and it sparkles)
		trunk:SetAttribute("WasColor", trunk.Color)
		trunk.Color = Color3.fromHex("e8b53a")
		local sp = Instance.new("Sparkles")
		sp.Name = "GoldenSparkles"
		sp.SparkleColor = Color3.fromHex("ffd96a")
		sp.Parent = trunk
	end
	local at = t:GetPivot().Position
	-- (the phone says where it is while it lasts)
	ReplicatedStorage:SetAttribute("GoldenWhere", direction(at))
	remotes.Notify:FireAllClients(string.format("A golden tree has appeared %s of the cabin! Its bark is worth %dx", direction(at), Config.GoldenTree.value), "ffd27a", "reveal")
	return t
end

function EventService.start()
	task.spawn(function()
		while true do
			-- (the phone counts down to the next one)
			ReplicatedStorage:SetAttribute("GoldenNext", os.time() + Config.GoldenTree.every)
			-- (a minute before, everyone's told to get ready)
			task.wait(math.max(0, Config.GoldenTree.every - 60))
			if #Players:GetPlayers() > 0 then
				remotes.Notify:FireAllClients("A golden tree appears in one minute!", "ffd27a")
			end
			task.wait(math.min(60, Config.GoldenTree.every))
			if #Players:GetPlayers() > 0 then
				local t = EventService.startGolden()
				local until_ = os.clock() + Config.GoldenTree.lasts
				while t and EventService.golden == t and os.clock() < until_ and standing(t) do
					task.wait(5)
				end
				if t and EventService.golden == t then
					EventService.endGolden()
				end
			end
		end
	end)
end

return EventService
