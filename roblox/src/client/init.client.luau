--!strict
-- Client entry point: starts the controllers.
require(script:WaitForChild("Sfx")).start()      -- the breeze, birds and music
local controllers = script:WaitForChild("Controllers")
for _, name in { "InputController", "Hud", "TreeVisuals", "ToolController", "CarryController", "ShopController" } do
	local c = require(controllers:WaitForChild(name)) :: any
	c.start()
end
