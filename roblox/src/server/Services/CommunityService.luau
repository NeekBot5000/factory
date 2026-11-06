--!strict
-- The community around the game, the way popular Roblox games grow theirs:
--   * once, after your first truckload is paid, a toast asks you to like and favourite Timber on its page
--     (likes and favourites are what Roblox's discovery looks at);
--   * the group reward: once you're in the game's Roblox group (Config.Group.id, 0 = no group yet), the first time
--     you join a server you get Config.Group.reward. Players see the group on the game page.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local CommunityService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
CommunityService.ASK_DELAY = 6
CommunityService.group = Config.Group
-- (asks Roblox; the tests swap it out)
function CommunityService.isMember(player: Player, groupId: number): boolean
	local ok, member = pcall(function()
		return player:IsInGroup(groupId)
	end)
	return ok and member == true
end

-- a truckload was paid for this player (EconomyService): the first time, ask for a like
function CommunityService.sold(player: Player)
	local data = DataService.get(player)
	if not data or data.askedLike then
		return
	end
	data.askedLike = true
	task.delay(CommunityService.ASK_DELAY, function()
		if player.Parent then
			remotes.Notify:FireClient(player, "Enjoying Timber? A like and a favourite on the game page help it a lot!", "8fd0ff")
		end
	end)
end

-- the group reward, once, if the player is in the group (asked of Roblox when they join)
function CommunityService.groupReward(player: Player): number
	local group = CommunityService.group
	local data = DataService.get(player)
	if not data or group.id <= 0 or data.groupPaid or not CommunityService.isMember(player, group.id) then
		return 0
	end
	data.groupPaid = true
	local EconomyService = require(script.Parent.EconomyService) :: any
	EconomyService.addMoney(player, group.reward, "Gameplay", "group")
	task.delay(10, function()
		if player.Parent then
			remotes.Notify:FireClient(player, string.format("Thanks for joining the Timber group!  +$%d", group.reward), "ffd27a", "buy")
		end
	end)
	return group.reward
end

function CommunityService.start()
	table.insert(DataService.onLoaded, function(player)
		CommunityService.groupReward(player)
	end)
end

return CommunityService
