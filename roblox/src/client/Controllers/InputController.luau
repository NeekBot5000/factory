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
