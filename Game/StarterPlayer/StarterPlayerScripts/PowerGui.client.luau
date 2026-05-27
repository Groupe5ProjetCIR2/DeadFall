-- ============================================================
--  Ce script a pour but de créer et de gérer l'affichage 
--  d'une interface d'avertissement indiquant l'état du 
--  courant électrique dans le jeu. Il génère le panneau 
--  visuel puis utilise des animations pour le faire 
--  glisser à l'écran en fonction des signaux du serveur.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local powerEvent = ReplicatedStorage:WaitForChild("PowerEvent")

local zektonFont = Font.new("rbxasset://fonts/families/Zekton.json")
local son_power_off = game:GetService("SoundService").PowerOFF

local warningGui = Instance.new("ScreenGui")
warningGui.Name = "WarningGui"
warningGui.ResetOnSpawn = false 
warningGui.Parent = playerGui

-- Génère la fenêtre d'avertissement en dehors de l'écran (Position Y négative) pour qu'elle puisse glisser vers le bas lors de son activation
local messageFrame = Instance.new("Frame")
messageFrame.Name = "MessageFrame"
messageFrame.Size = UDim2.new(0, 500, 0, 80)
messageFrame.Position = UDim2.new(0.5, -250, 0, -300) 
messageFrame.BackgroundTransparency = 1
messageFrame.BorderSizePixel = 2
messageFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
messageFrame.Parent = warningGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0.4, 0)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "WARNING"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextScaled = true
titleLabel.Parent = messageFrame

local subTextLabel = Instance.new("TextLabel")
subTextLabel.Name = "SubTextLabel"
subTextLabel.Size = UDim2.new(1, 0, 0.6, 0)
subTextLabel.Position = UDim2.new(0, 0, 0.4, 0)
subTextLabel.BackgroundTransparency = 1
subTextLabel.Text = "You must turn on the power to use the machines."
subTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
subTextLabel.FontFace = zektonFont
subTextLabel.TextScaled = true

local padding = Instance.new("UIPadding")
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingTop = UDim.new(0, 5)
padding.PaddingLeft = UDim.new(0, 15)
padding.PaddingRight = UDim.new(0, 15)
padding.Parent = subTextLabel

subTextLabel.Parent = messageFrame

-- Écoute les signaux du serveur pour déclencher une transition fluide (Tween) de l'interface et jouer un effet sonore selon l'état du courant
powerEvent.OnClientEvent:Connect(function(action)
	if not warningGui or not messageFrame then return end

	local tweenInfo = TweenInfo.new(
		0.4,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out
	)

	if action == "PowerTurnedOn" then
		local goal = { Position = UDim2.new(0.5, -250, 0, -300) }
		local tween = TweenService:Create(messageFrame, tweenInfo, goal)
		tween:Play()

	elseif action == "PowerTurnedOff" then
		local goal = { Position = UDim2.new(0.5, -250, 0, 50) }
		local tween = TweenService:Create(messageFrame, tweenInfo, goal)
		son_power_off:Play()
		tween:Play()
	end
end)