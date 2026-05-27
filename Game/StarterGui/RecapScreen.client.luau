-- ============================================================
-- Ce script gère la séquence complète de fin de partie (Game Over).
-- Il nettoie l'écran en cachant toutes les interfaces de jeu, 
-- prend le contrôle de la caméra pour une cinématique (travelling), 
-- et affiche le tableau des scores final avec un bouton de retour au lobby.
-- ============================================================

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Camera = workspace.CurrentCamera
local player = Players.LocalPlayer
local GameOverEvent = ReplicatedStorage:WaitForChild("GameOver")
local TeleportEvent = ReplicatedStorage:WaitForChild("TeleportRequest")

local POINT_A = Vector3.new(229, 40, 162)
local POINT_B = Vector3.new(168, 40, 395)
local DURATION = 40

local Lighting = game:GetService("Lighting")

-- Fonction utilitaire pour générer une ligne de statistiques pour un joueur dans le tableau
local function createPlayerRow(parent, name, kills, kos, revives, money)
	local row = Instance.new("Frame")
	row.Name = "PlayerRow"
	row.Size = UDim2.new(0.95, 0, 0, 40)
	row.BackgroundTransparency = 0.9
	row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	row.Parent = parent

	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

	local function createStatLabel(text, xPos, width, color)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(width, 0, 1, 0)
		lbl.Position = UDim2.new(xPos, 0, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
		lbl.FontFace = Font.new("rbxasset://fonts/families/Zekton.json")
		lbl.TextSize = 14
		lbl.Parent = row
	end

	--  Nom | Argent | Kills | KO | Réas
	createStatLabel(name, 0.05, 0.25, Color3.fromRGB(0, 145, 255))
	createStatLabel("Money : " .. money .. " $", 0.30, 0.2, Color3.fromRGB(255, 215, 0))
	createStatLabel("Kills : " .. kills, 0.50, 0.15)
	createStatLabel("KO : " .. kos, 0.65, 0.15, Color3.fromRGB(255, 80, 80))
	createStatLabel("Revive : " .. revives, 0.80, 0.15, Color3.fromRGB(170, 85, 255))
end

-- Construit et anime le tableau des scores final
local function createModernRecapUI(allStats)
	-- Ajoute un effet de flou progressif sur le jeu en arrière-plan pour bien faire ressortir l'UI
	local blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Name = "RecapBlur"
	blur.Parent = Lighting

	TweenService:Create(blur, TweenInfo.new(1), {Size = 10}):Play()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RecapModernUI"
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0.6, 0, 0.5, 0)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	mainFrame.BackgroundTransparency = 0.6
	mainFrame.Parent = screenGui

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 20)
	uiCorner.Parent = mainFrame

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 1.2
	uiStroke.Color = Color3.fromRGB(255, 255, 255)
	uiStroke.Transparency = 0.85
	uiStroke.Parent = mainFrame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 180, 180)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180))
	})
	gradient.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Text = "RÉCAPITULATIF"
	title.FontFace = Font.new("rbxasset://fonts/families/Zekton.json", Enum.FontWeight.Bold)
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0.5, 0, 0.12, 0)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Parent = mainFrame

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(0.9, 0, 0.55, 0)
	list.Position = UDim2.new(0.5, 0, 0.52, 0)
	list.AnchorPoint = Vector2.new(0.5, 0.5)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 2
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Parcourt les stats reçues du serveur et crée une ligne pour chaque joueur
	for _, stats in pairs(allStats) do
		createPlayerRow(list, stats.name, stats.zombieKills, stats.timesKO, stats.revives, stats.money)
	end

	local lobbyBtn = Instance.new("TextButton")
	lobbyBtn.Name = "LobbyButton"
	lobbyBtn.Size = UDim2.new(0.25, 0, 0.08, 0)
	lobbyBtn.Position = UDim2.new(0.5, 0, 0.9, 0)
	lobbyBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	lobbyBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	lobbyBtn.BackgroundTransparency = 0.9
	lobbyBtn.Text = "RETOUR LOBBY"
	lobbyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	lobbyBtn.FontFace = Font.new("rbxasset://fonts/families/Zekton.json", Enum.FontWeight.Medium)
	lobbyBtn.TextSize = 14
	lobbyBtn.Parent = mainFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = lobbyBtn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Thickness = 1
	btnStroke.Color = Color3.fromRGB(255, 255, 255)
	btnStroke.Transparency = 0.8
	btnStroke.Parent = lobbyBtn

	local isTeleporting = false

	lobbyBtn.MouseButton1Click:Connect(function()
		-- Sécurité anti-spam : Empêche le joueur de cliquer plusieurs fois et de déclencher plusieurs TP
		if isTeleporting then return end
		isTeleporting = true

		lobbyBtn.Text = "CHARGEMENT..."
		lobbyBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
		btnStroke.Color = Color3.fromRGB(150, 150, 150)

		-- Crée un fondu au noir avant la téléportation
		local fadeFrame = Instance.new("Frame")
		fadeFrame.Size = UDim2.new(1, 0, 1, 0)
		fadeFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		fadeFrame.BackgroundTransparency = 1
		fadeFrame.ZIndex = 100
		fadeFrame.Parent = screenGui

		local fadeTween = TweenService:Create(fadeFrame, TweenInfo.new(1), {BackgroundTransparency = 0})
		fadeTween:Play()

		TeleportEvent:FireServer()
	end)

	return screenGui
end

-- Lance un travelling fluide de la caméra pour la cinématique de fin
local function startCinematic()
	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CFrame = CFrame.new(POINT_A, POINT_B)

	local startTime = tick()

	local tweenInfo = TweenInfo.new(DURATION, Enum.EasingStyle.Linear)
	local goal = {
		CFrame = CFrame.new(POINT_B, POINT_B + (POINT_B - POINT_A).Unit)
	}

	local tween = TweenService:Create(Camera, tweenInfo, goal)
	tween:Play()

	tween.Completed:Connect(function()
		local timeElapsed = tick() - startTime

		-- Sécurité : On vérifie le temps écoulé pour être sûr que le joueur n'a pas altéré 
		-- la cinématique côté client (skip glitch/exploit) pour forcer un TP immédiat.
		if timeElapsed > 2 then
			print("Fin normale de la cinématique. Téléportation...")
			TeleportEvent:FireServer()
		else
			warn("ALERTE : Le Tween a fini trop vite (" .. math.round(timeElapsed) .. "s). TP automatique annulé pour éviter le skip.")
		end
	end)
end

-- Événement principal appelé par le serveur quand la partie est officiellement perdue ou terminée
GameOverEvent.OnClientEvent:Connect(function()
	-- Petit délai avant de couper l'écran pour laisser le temps au joueur de réaliser la fin de partie
	task.wait(4)

	local playerGui = player:WaitForChild("PlayerGui")

	local healthScript = playerGui:FindFirstChild("HealthGuiSystem")
	if healthScript and healthScript:IsA("LocalScript") then
		healthScript.Disabled = true
	end

	-- Désactive massivement toutes les interfaces de jeu habituelles (HUD)
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") then 
			gui.Enabled = false 
		end
	end

	-- Désactive l'interface native de Roblox (Chat, Sac à dos, Menu, etc.)
	pcall(function() 
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) 
	end)

	-- Dissimulation spécifique d'autres UIs qui pourraient rester coincées à l'écran
	local minimapGui = playerGui:FindFirstChild("MinimapGUI")
	if minimapGui then
		local surfaceGui = minimapGui:FindFirstChild("SurfaceGui")
		if surfaceGui and surfaceGui:FindFirstChild("MiniMap") then
			surfaceGui.MiniMap.Size = UDim2.new(0, 0, 0, 0)
		end
	end

	local customHealthBar = playerGui:FindFirstChild("CustomHealthBar")
	if customHealthBar then
		local frame = customHealthBar:FindFirstChild("SurfaceGui") and customHealthBar.SurfaceGui:FindFirstChild("Frame")
		if frame then frame.Visible = false end
	end

	local argentUI = playerGui:FindFirstChild("ArgentUI")

	if argentUI then
		argentUI.Enabled = false
		for _, obj in ipairs(argentUI:GetDescendants()) do
			if obj:IsA("Frame") or obj:IsA("TextLabel") or obj:IsA("ImageLabel") then
				obj.Visible = false
			end
		end 
	end

	-- Demande au serveur les statistiques finales de tous les joueurs de la partie
	local GetStatsFunction = ReplicatedStorage:FindFirstChild("GetPlayerStats")
	local statsData = {}

	if GetStatsFunction then
		statsData = GetStatsFunction:InvokeServer()
	end

	-- Lance la séquence de fin visuelle avec les données récupérées
	startCinematic()
	createModernRecapUI(statsData)

	-- Réactive la souris pour que le joueur puisse cliquer sur le bouton de retour au lobby
	game:GetService("UserInputService").MouseIconEnabled = true
end)