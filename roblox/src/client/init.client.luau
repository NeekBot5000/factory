--!strict
-- Client entry point: the sounds (breeze, birds, music), then each controller in order.
require(script:WaitForChild("Sfx")).start()
local controllers = script:WaitForChild("Controllers")
for _, name in { "InputController", "MoveController", "TreeVisuals", "ShopController", "ToolController", "InteractController", "ViewModel", "Hud" } do
	local c = require(controllers:WaitForChild(name)) :: any
	c.start()
end
