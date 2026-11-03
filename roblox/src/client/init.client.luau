--!strict
-- Client entry point: the sounds (breeze, birds, music), then each controller in order. A controller that fails to
-- start says so in the Output window and the rest still start.
local ok, err = pcall(function()
	require(script:WaitForChild("Sfx")).start()
end)
if not ok then
	warn("[Timber] Sfx: " .. tostring(err))
end
local controllers = script:WaitForChild("Controllers")
for _, name in { "InputController", "MoveController", "TreeVisuals", "ShopController", "ToolController", "InteractController", "ViewModel", "SkyController", "Hud" } do
	local started, why = pcall(function()
		local c = require(controllers:WaitForChild(name)) :: any
		c.start()
	end)
	if not started then
		warn("[Timber] " .. name .. " didn't start: " .. tostring(why))
	end
end
