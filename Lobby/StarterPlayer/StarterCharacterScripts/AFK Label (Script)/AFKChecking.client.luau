local timeToAfk = script.Parent:WaitForChild("TimeToAfk").Value
local event = script.Parent:WaitForChild("ToggleLabel")
local uis = game:GetService("UserInputService")
local guiService = game:GetService("GuiService")

local afk = false
local lastActive = time()

local function setAfk(state : boolean)
	if afk ~= state then
		afk = state
		event:FireServer(state)
	end
end

uis.InputBegan:Connect(function()
	lastActive = time()
	setAfk(false)
end)

uis.WindowFocusReleased:Connect(function()
	setAfk(true)
end)

uis.WindowFocused:Connect(function()
	lastActive = time()
	setAfk(false)
end)

guiService.MenuOpened:Connect(function()
	setAfk(true)
end)

guiService.MenuClosed:Connect(function()
	lastActive = time()
	setAfk(false)
end)

while task.wait(0.1) do
	if not afk and (time() - lastActive > timeToAfk) then
		setAfk(true)
	end
end
