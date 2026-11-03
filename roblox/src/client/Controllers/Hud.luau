--!strict
-- A crosshair in the middle of the screen (every device aims from there), and short messages from the server
-- ("Sold for $12.40"). Money shows in the player list through leaderstats.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = {}

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TimberHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(6, 6)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	dot.Parent = gui
	local msg = Instance.new("TextLabel")
	msg.Size = UDim2.new(0.6, 0, 0, 40)
	msg.AnchorPoint = Vector2.new(0.5, 0)
	msg.Position = UDim2.new(0.5, 0, 0, 70)
	msg.BackgroundTransparency = 1
	msg.TextColor3 = Color3.fromRGB(122, 255, 154)
	msg.TextStrokeTransparency = 0.4
	msg.Font = Enum.Font.FredokaOne
	msg.TextScaled = true
	msg.Text = ""
	msg.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local n = 0
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify").OnClientEvent:Connect(function(text: string)
		n += 1
		local mine = n
		msg.Text = text
		task.delay(3, function()
			if n == mine then
				msg.Text = ""
			end
		end)
	end)
end

return Hud
