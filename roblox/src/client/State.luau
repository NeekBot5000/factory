--!strict
-- What the client's controllers share: the tool in your hand, whether a screen (the shop) is open, whether you've
-- fainted, the swing in progress, and the toast line (any controller can show a message, Godot's Game.toast).
local State = {
	tool = "hands",
	equipT = 1,             -- 0 -> 1 while a tool comes up into view (Godot's _equip_t)
	swing = -1,             -- 0 -> 1 through a swing, -1 when not swinging
	backhand = false,       -- the double-bit alternates forehand and backhand swings
	kick = 0,               -- view kick on impact
	uiOpen = false,
	fainted = false,
	sprinting = false,
	bob = 0,                -- walking: the arm sways with it
	combo = 0,              -- the combo axe: hits in a row
	sawProgress = 0,        -- 0 -> 1 while a saw is cutting (shown round the crosshair)
	thrown = false,         -- the throwing hatchet is out of your hand
	catch = 0,              -- 1 -> 0 just after catching it
	sawing = false,
	drilling = false,       -- a bark drill is running
	vacuuming = false,      -- a vacuum is sucking
	comboT = 0,
	charge = 0,             -- the Thunder Axe: 0 -> 1 while you hold the button
	thunderCd = 0,          -- seconds until it can strike again
	white = 0,              -- the lightning's white flash over the screen
}

local toastEvent = Instance.new("BindableEvent")
State.toasted = toastEvent.Event

function State.toast(text: string, color: Color3?)
	toastEvent:Fire(text, color or Color3.new(1, 1, 1))
end

local toolEvent = Instance.new("BindableEvent")
State.toolChanged = toolEvent.Event       -- the tool in hand, or what's in the bar, changed

function State.toolsChanged()
	toolEvent:Fire()
end

return State
