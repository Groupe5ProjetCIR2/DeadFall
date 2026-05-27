-- ============================================================
--  Ce script gère une transition visuelle de type "balayage" 
--  noir à travers l'écran lors d'un événement de lancement.
--  Il utilise le service TweenService pour déplacer dynamiquement 
--  un cadre opaque sur l'interface utilisateur du joueur.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local LaunchGui = ReplicatedStorage:WaitForChild("LaunchGui")

-- Écoute l'événement distant pour déclencher la transition
LaunchGui.OnClientEvent:Connect(function()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("MainGui")

	-- Initialisation du conteneur d'interface s'il n'existe pas
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "MainGui"
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = playerGui
	end

	gui.Enabled = true

	-- Création du panneau noir servant de transition
	local blackScreen = Instance.new("Frame")
	blackScreen.Name = "TransitionBlackScreen"
	blackScreen.Size = UDim2.new(3, 0, 1, 0)
	blackScreen.Position = UDim2.new(-3, 0, 0, 0)
	blackScreen.BackgroundColor3 = Color3.new(0, 0, 0)
	blackScreen.BorderSizePixel = 0
	blackScreen.ZIndex = 1000
	blackScreen.Parent = gui

	-- Configuration de l'animation de balayage
	local sweepInfo = TweenInfo.new(
		1.65,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)

	-- Exécution du déplacement du panneau à travers l'écran
	local sweepTween = TweenService:Create(blackScreen, sweepInfo, {
		Position = UDim2.new(0, 0, 0, 0),
	})

	print("Animation black screen démarrée")
	sweepTween:Play()
end)