--!strict
-- Replaces Roblox's own "Health" script (same name, so the default one isn't added): health comes back like in the
-- Godot game. Nothing for 3 seconds after you were hurt, then 5 a second until you're full again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
humanoid.BreakJointsOnDeath = false       -- you faint (fall over and the screen goes dark), you don't fall apart
-- the ground you walk on (terrain) lies a little under the ground you see (Godot's mesh): stand that much higher,
-- so your feet are on what you see and your eyes are where Godot's are
task.defer(function()
	humanoid.HipHeight += Config.GroundSink
end)
local lastHealth = humanoid.Health
local sinceHurt = 99

humanoid.HealthChanged:Connect(function(h)
	if h < lastHealth - 0.01 then
		sinceHurt = 0
	end
	lastHealth = h
end)

while humanoid.Parent and humanoid.Health > 0 do
	local dt = task.wait(0.1)
	sinceHurt += dt
	if sinceHurt > Config.Player.regenDelay and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.Player.regenPerSecond * dt)
		lastHealth = humanoid.Health
	end
end
