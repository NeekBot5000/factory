--!strict
-- One set of actions for every device, with the Godot game's keys. The rest of the game only ever hears "Swing",
-- "Grab" and so on, never "E" or "MouseButton1".
--   Swing    - left click / R2 / touch button
--   Grab     - E (or F) / X on a gamepad / touch button     (use, pick up, drop)
--   DropTool - Q / D-pad down / touch button                (put the tool in your hand down)
--   Sprint   - Shift (held) / L3
--   NextTool / PrevTool - mouse wheel / D-pad right and left (1-9 are read by the ToolController)
-- Keyboard, mouse and gamepad come straight from UserInputService, the most basic input path in Roblox: nothing else
-- can take the keys first (ContextActionService bindings, such as Roblox's own, can sink a key before ours sees it).
-- Phones and tablets get on-screen buttons from ContextActionService.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local InputController = {}
local handlers: { [string]: { (state: Enum.UserInputState) -> () } } = {}

-- the rest of the game listens here
function InputController.on(action: string, f: (state: Enum.UserInputState) -> ())
	handlers[action] = handlers[action] or {}
	table.insert(handlers[action], f)
end

-- runs one action's handlers; one failing handler can't stop the others
function InputController.fire(action: string, state: Enum.UserInputState)
	for _, f in handlers[action] or {} do
		local ok, err = pcall(f, state)
		if not ok then
			warn("[Timber] " .. action .. ": " .. tostring(err))
		end
	end
end

-- (keyed by name: the same key always matches, however the KeyCode reached us)
local KEYS: { [string]: string } = {
	E = "Grab", F = "Grab", ButtonX = "Grab",
	Q = "DropTool", DPadDown = "DropTool",
	LeftShift = "Sprint", RightShift = "Sprint", ButtonL3 = "Sprint",
	ButtonR2 = "Swing",
	DPadRight = "NextTool", DPadLeft = "PrevTool",
	Tab = "Phone", ButtonSelect = "Phone",
	R = "Turn", ButtonY = "Turn",                 -- turns the build you're placing
	X = "TakeDown",                               -- with the hammer: knock a plan or a build down
}

local function actionOf(input: InputObject): string?
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		return "Swing"
	end
	return KEYS[input.KeyCode.Name]
end

-- touch buttons: only on phones and tablets (the thumbstick and jump come from Roblox)
local TOUCH = {
	{ "Swing", "Swing", UDim2.new(1, -110, 1, -170) },
	{ "Grab", "Use", UDim2.new(1, -190, 1, -110) },
	{ "DropTool", "Drop", UDim2.new(1, -190, 1, -190) },
	{ "Phone", "Phone", UDim2.new(1, -270, 1, -110) },       -- (the shop, shipping and settings are on the phone)
}
-- with the hammer in hand: turn the build you're placing, take one down
local HAMMER_TOUCH = {
	{ "Turn", "Turn", UDim2.new(1, -110, 1, -250) },
	{ "TakeDown", "Take down", UDim2.new(1, -270, 1, -190) },
}

-- what a key is called on a touch screen: the hints say "[E] grab", a phone shows "[Use] grab"
local TOUCH_NAMES = {
	{ "%[E%]", "[Use]" }, { "%[Click empty%]", "[Swing at nothing]" }, { "%[Click%]", "[Swing]" }, { "%[Q%]", "[Drop]" },
	{ "%[R%]", "[Turn]" }, { "%[X%]", "[Take down]" }, { "%[Tab%]", "[Phone]" }, { "%[Scroll%] size [%d%.x]+    ", "" },
}

function InputController.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		-- (processed: typing in chat, or clicking a button on a screen)
		if processed then
			return
		end
		local action = actionOf(input)
		if action then
			InputController.fire(action, Enum.UserInputState.Begin)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local action = actionOf(input)
		if action then
			InputController.fire(action, Enum.UserInputState.End)
		end
	end)
	-- the mouse wheel switches tools on PC
	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			InputController.fire(if input.Position.Z < 0 then "NextTool" else "PrevTool", Enum.UserInputState.Begin)
		end
	end)
	if UserInputService.TouchEnabled then
		for _, b in TOUCH do
			local name, label, pos = b[1] :: string, b[2] :: string, b[3] :: UDim2
			ContextActionService:BindAction("Touch" .. name, function(_, state)
				InputController.fire(name, state)
				return Enum.ContextActionResult.Sink
			end, true)
			ContextActionService:SetTitle("Touch" .. name, label)
			ContextActionService:SetPosition("Touch" .. name, pos)
		end
		-- Run: a toggle (a phone's thumbstick has no Shift to hold)
		local running = false
		ContextActionService:BindAction("TouchRun", function(_, state)
			if state == Enum.UserInputState.Begin then
				running = not running
				InputController.fire("Sprint", if running then Enum.UserInputState.Begin else Enum.UserInputState.End)
			end
			return Enum.ContextActionResult.Sink
		end, true)
		ContextActionService:SetTitle("TouchRun", "Run")
		ContextActionService:SetPosition("TouchRun", UDim2.new(1, -270, 1, -270))
	end
end

-- a hint or message, with the keys named the way this player presses them
function InputController.label(text: string): string
	if InputController.device() ~= "touch" then
		return text
	end
	for _, r in TOUCH_NAMES do
		text = string.gsub(text, r[1], r[2])
	end
	return text
end

-- touch buttons that only make sense with the hammer in hand (Turn and Take down)
local shownHammer = false
function InputController.toolChanged(tool: string)
	if not UserInputService.TouchEnabled then
		return
	end
	local want = tool == "hammer"
	if want == shownHammer then
		return
	end
	shownHammer = want
	for _, b in HAMMER_TOUCH do
		local name, label, pos = b[1] :: string, b[2] :: string, b[3] :: UDim2
		if want then
			ContextActionService:BindAction("Touch" .. name, function(_, state)
				InputController.fire(name, state)
				return Enum.ContextActionResult.Sink
			end, true)
			ContextActionService:SetTitle("Touch" .. name, label)
			ContextActionService:SetPosition("Touch" .. name, pos)
		else
			ContextActionService:UnbindAction("Touch" .. name)
		end
	end
end

-- what the player is using right now, for showing the right prompts ("[E]", "X", or a touch button)
function InputController.device(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	elseif UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:find("Gamepad") then
		return "gamepad"
	end
	return "keyboard"
end

return InputController
