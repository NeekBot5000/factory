--!strict
-- Client entry point: starts the controllers.
local controllers = script:WaitForChild("Controllers")
for _, name in { "InputController", "TreeVisuals", "ToolController" } do
	local c = require(controllers:WaitForChild(name)) :: any
	c.start()
end
