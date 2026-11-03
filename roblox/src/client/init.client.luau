--!strict
-- Client entry point: starts the controllers.
local controllers = script:WaitForChild("Controllers")
for _, name in { "InputController", "Hud", "TreeVisuals", "ToolController", "CarryController", "ShopController" } do
	local c = require(controllers:WaitForChild(name)) :: any
	c.start()
end
