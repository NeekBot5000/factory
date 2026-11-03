--!strict
-- One set of actions for every device. ContextActionService binds each action to a key, a gamepad button and
-- (on phones and tablets) an on-screen button, so the rest of the game only ever hears "Swing", never "MouseButton1".
-- (the keys are the Godot game's)
--   Swing    - left click / R2 / touch button
--   Grab     - E (or F) / X on a gamepad / touch button     (use, pick up, drop)
--   DropTool - Q / D-pad down / touch button                (put the tool in your hand down)
--   Sprint   - Shift / L3
--   NextTool / PrevTool - mouse wheel / D-pad right and left (1-9 are read by the ToolController)
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local InputController = {}
local handlers: { [string]: { (state: Enum.UserInputState) -> () } } = {}

-- the rest of the game listens here
function InputController.on(action: string, f: (state: Enum.UserInputState) -> ())
	handlers[action] = handlers[action] or {}
	table.insert(handlers[action], f)
end

local function dispatch(action: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	for _, f in handlers[action] or {} do
		f(state)
	end
	return Enum.ContextActionResult.Sink
end

local BINDINGS = {
	{ "Swing", { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 }, "Swing", UDim2.new(1, -110, 1, -170) },
	{ "Grab", { Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.ButtonX }, "Use", UDim2.new(1, -190, 1, -110) },
	{ "DropTool", { Enum.KeyCode.Q, Enum.KeyCode.DPadDown }, "Drop", UDim2.new(1, -190, 1, -190) },
	{ "Sprint", { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 }, nil, nil },
	{ "NextTool", { Enum.KeyCode.DPadRight }, nil, nil },
	{ "PrevTool", { Enum.KeyCode.DPadLeft }, nil, nil },
}

function InputController.start()
	for _, b in BINDINGS do
		local name, inputs, label, pos = b[1] :: string, b[2] :: { any }, b[3] :: string?, b[4] :: UDim2?
		-- touch buttons only for the actions a thumb needs; the thumbstick and jump come from Roblox
		ContextActionService:BindAction(name, dispatch, label ~= nil, table.unpack(inputs))
		if label then
			ContextActionService:SetTitle(name, label)
			if pos then
				ContextActionService:SetPosition(name, pos)
			end
		end
	end
	-- the mouse wheel and number keys switch tools on PC
	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			dispatch(if input.Position.Z < 0 then "NextTool" else "PrevTool", Enum.UserInputState.Begin, input)
		end
	end)
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
