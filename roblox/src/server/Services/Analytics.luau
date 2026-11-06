--!strict
-- Roblox's own analytics (AnalyticsService), shown on the Creator Dashboard under Analytics: where new players stop
-- in Getting started (an onboarding funnel, one step per Config.Tutorial step), and where money comes from and goes
-- (economy events: the mill, daily rewards, jobs, codes in; the shop and land out). It changes nothing in the game.
-- Every call is wrapped: analytics failing (Studio, the Lune tests, Roblox having trouble) never stops play.
local Analytics = {}

local function service(): any
	local ok, s = pcall(function()
		return game:GetService("AnalyticsService")
	end)
	return if ok then s else nil
end

-- Roblox's own name for a kind of transaction if it has one (its charts know those), else ours
local function transactionType(kind: string): string
	local ok, name = pcall(function()
		return (Enum.AnalyticsEconomyTransactionType :: any)[kind].Name
	end)
	return if ok and typeof(name) == "string" then name else kind
end

-- a step of Getting started done (step 1 is the first); the last one is "finished"
function Analytics.onboarding(player: Player, step: number, name: string)
	local s = service()
	if s then
		pcall(function()
			s:LogOnboardingFunnelStepEvent(player, step, name)
		end)
	end
end

-- money in (amount > 0) or out (amount < 0); kind: "Gameplay", "Shop", "TimedReward" ...; sku: what, if anything
function Analytics.money(player: Player, amount: number, balance: number, kind: string, sku: string?)
	local s = service()
	if not s or amount == 0 then
		return
	end
	pcall(function()
		local flow = if amount > 0 then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
		s:LogEconomyEvent(player, flow, "Dollars", math.abs(amount), balance, transactionType(kind), sku)
	end)
end

return Analytics
