-- ============================================================
--  Ce script gère un système de mode spectateur permettant de 
--  suivre d'autres joueurs en vie avec une caméra à la 3ème personne. 
--  Il crée l'interface de navigation et masque dynamiquement 
--  le HUD du joueur (santé, minimap, etc.) pendant l'observation.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local SpectateEvent = ReplicatedStorage:WaitForChild("StartSpectate")

local spectating = false
local currentTarget = nil
local watchConnection = nil
local currentIndex = 1

-- Parcourt tous les joueurs pour filtrer et retourner ceux qui sont en vie et actifs
local function getAliveTargets()
	local targets = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and not p.Character:GetAttribute("IsDowned") then
			local hum = p.Character:FindFirstChild("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(targets, p)
			end
		end
	end
	return targets
end

-- Définit la cible actuelle et verrouille la caméra pour un contrôle par script
local function spectateTarget(target)
	currentTarget = target
	Camera.CameraType = Enum.CameraType.Scriptable
end

-- Boucle de rendu prioritaire pour calculer la position de la caméra spectateur derrière la cible
RunService:BindToRenderStep("SpectatorCamera", Enum.RenderPriority.Camera.Value + 1, function()
	if not spectating or not currentTarget or not currentTarget.Character then return end
	local hrp = currentTarget.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local backOffset = hrp.CFrame.LookVector * -12
	local heightOffset = Vector3.new(0, 4, 0)
	local camPos = hrp.Position + backOffset + heightOffset
	Camera.CFrame = CFrame.new(camPos, hrp.Position + heightOffset)
end)

-- Sélectionne automatiquement le premier joueur valide disponible
local function findNewTarget()
	local targets = getAliveTargets()
	if #targets == 0 then return end
	spectateTarget(targets[1])
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpectatorUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 50)
frame.Position = UDim2.new(0.5, -150, 0.9, 0)
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
frame.BackgroundTransparency = 0.4
frame.Visible = false
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(255, 255, 255)
uiStroke.Transparency = 0.8
uiStroke.Thickness = 1
uiStroke.Parent = frame

local prevButton = Instance.new("TextButton")
prevButton.Size = UDim2.new(0, 80, 1, 0)
prevButton.Position = UDim2.new(0, 0, 0, 0)
prevButton.BackgroundTransparency = 1
prevButton.TextColor3 = Color3.fromRGB(255, 255, 255)
prevButton.Text = "◀"
prevButton.TextSize = 24
prevButton.Parent = frame

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(0, 140, 1, 0)
nameLabel.Position = UDim2.new(0, 80, 0, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLabel.TextSize = 18
nameLabel.Font = Enum.Font.Michroma
nameLabel.Text = ""
nameLabel.Parent = frame

local nextButton = Instance.new("TextButton")
nextButton.Size = UDim2.new(0, 80, 1, 0)
nextButton.Position = UDim2.new(0, 220, 0, 0)
nextButton.BackgroundTransparency = 1
nextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
nextButton.Text = "▶"
nextButton.TextSize = 24
nextButton.Parent = frame

-- Actualise l'affichage du nom dans l'UI du spectateur
local function updateUI()
	nameLabel.Text = currentTarget and currentTarget.Name or ""
end

-- Calcule de manière circulaire le prochain joueur à observer grâce au modulo
local function spectateIndex(index)
	local targets = getAliveTargets()
	if #targets == 0 then return end
	currentIndex = ((index - 1) % #targets) + 1
	spectateTarget(targets[currentIndex])
	updateUI()
end

prevButton.MouseButton1Click:Connect(function()
	spectateIndex(currentIndex - 1)
end)

nextButton.MouseButton1Click:Connect(function()
	spectateIndex(currentIndex + 1)
end)

-- Déclencheur principal du mode spectateur, gère la préparation de l'environnement visuel
SpectateEvent.OnClientEvent:Connect(function()
	spectating = true

	UserInputService.MouseIconEnabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	game:GetService("ProximityPromptService").Enabled = false

	local playerGui = player:WaitForChild("PlayerGui")

	local healthScript = playerGui:FindFirstChild("HealthGuiSystem")
	if healthScript and healthScript:IsA("LocalScript") then
		healthScript.Disabled = true
	end

	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Name ~= "SpectatorUI" then 
			gui.Enabled = false 
		end
	end

	-- Désactivation des interfaces natives de Roblox via un pcall pour éviter une erreur de permission
	pcall(function() 
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) 
	end)

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

	-- Masque les noms au-dessus des personnages des autres joueurs
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			local hum = p.Character:FindFirstChild("Humanoid")
			if hum then
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
	end

	local targets = getAliveTargets()
	if #targets == 0 then return end
	spectateTarget(targets[1])
	currentIndex = 1
	frame.Visible = true
	updateUI()

	-- Surveillance continue (Heartbeat) de la cible pour réassigner automatiquement la caméra si elle meurt
	if watchConnection then watchConnection:Disconnect() end
	watchConnection = RunService.Heartbeat:Connect(function()
		if not spectating then
			watchConnection:Disconnect()
			watchConnection = nil
			return
		end
		if not currentTarget or not currentTarget.Character then
			findNewTarget()
			return
		end
		local hum = currentTarget.Character:FindFirstChild("Humanoid")
		if not hum or hum.Health <= 0 then
			findNewTarget()
		end
	end)
end)