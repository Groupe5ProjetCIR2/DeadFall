-- ============================================================
-- Ce script gère l'interface et l'animation de l'écran de mort.
-- Il contrôle les transitions visuelles (fondus, apparitions de texte),
-- l'état "à terre" (caméra baissée) et la transition vers le mode spectateur.
-- ============================================================

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeleportEvent   = ReplicatedStorage:WaitForChild("TeleportRequest")
local ForceDeathEvent = ReplicatedStorage:WaitForChild("ForceDeath")
local SpectateEvent   = ReplicatedStorage:WaitForChild("StartSpectate")

local player      = Players.LocalPlayer
local ScreenGui   = script.Parent
local MainFrame   = ScreenGui.MainFrame
local Skull1, Skull2 = MainFrame.Skull1, MainFrame.Skull2
local Light       = ScreenGui.Light
local YDText      = MainFrame.YDText
local RestartText = MainFrame.RestartText

local isDead       = false
local isDowned     = false
local isSpectating = false
local isSpectator  = false
local gameOver = false

Players.RespawnTime = 10e5

-- ANIMATION DE DISPARITION
-- Fait disparaître les textes de mort progressivement avant de cacher l'écran
local function fadeOutDeathScreen()
	local tInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	TweenService:Create(YDText,          tInfo, {TextTransparency = 1}):Play()
	TweenService:Create(YDText.UIStroke, tInfo, {Transparency = 1}):Play()

	local t = TweenService:Create(RestartText, tInfo, {TextTransparency = 1})
	t:Play()
	t.Completed:Wait()

	local waited = 0
	-- Attend que le mode spectateur s'active (avec une limite de 5 secondes de sécurité)
	while not isSpectating and waited < 5 do
		task.wait(0.1)
		waited = waited + 0.1
	end

	MainFrame.Visible = false
	isSpectating = false
	TweenService:Create(Light, TweenInfo.new(1), {BackgroundTransparency = 1}):Play()
end

-- ANIMATION DE MORT PRINCIPALE
-- Lance la séquence de mort : écran rouge vers noir, apparition du crâne et du texte
local function playDeathAnimation()
	if isDead then return end
	isDead = true
	isDowned = false

	-- Désactive l'interface de santé pour nettoyer l'écran
	local playerGui = ScreenGui.Parent
	local healthGui = playerGui:FindFirstChild("HealthGui")
	if healthGui and healthGui:IsA("ScreenGui") then
		healthGui.Enabled = false
	end

	MainFrame.BackgroundColor3 = Color3.fromRGB(16, 0, 0)
	MainFrame.Visible          = true
	MainFrame.GroupTransparency = 0

	if script.Parent:FindFirstChild("DeathSound") then
		script.Parent.DeathSound:Play()
	end

	TweenService:Create(MainFrame, TweenInfo.new(2), {BackgroundColor3 = Color3.fromRGB(0,0,0)}):Play()

	local s1 = TweenService:Create(Skull1, TweenInfo.new(0.5), {Size = UDim2.new(0.133, 0, 0.305, 0), ImageTransparency = 0.3})
	s1:Play()
	s1.Completed:Wait()

	TweenService:Create(YDText,          TweenInfo.new(1), {TextTransparency = 0}):Play()
	TweenService:Create(YDText.UIStroke, TweenInfo.new(1), {Transparency = 0}):Play()
	task.wait(1)

	fadeOutDeathScreen()
end

-- GESTION DU PERSONNAGE
-- Initialise le personnage et écoute l'état "À terre" pour baisser la caméra
local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	isDead   = false
	isDowned = false
	character:SetAttribute("IsDowned", false)

	character:GetAttributeChangedSignal("IsDowned"):Connect(function()
		if character:GetAttribute("IsDowned") then
			isDowned = true
			-- Baisse la caméra pour simuler le fait d'être allongé au sol
			humanoid.CameraOffset = Vector3.new(0, -3.5, 0)
			RestartText.TextTransparency = 0
		else
			-- Si le joueur est réanimé (et non mort)
			if not isDead then
				isDowned = false
				RestartText.TextTransparency = 1
				humanoid.CameraOffset = Vector3.new(0, 0, 0)
			end
		end
	end)
end

-- ÉCOUTE DES ÉVÉNEMENTS SERVEUR
SpectateEvent.OnClientEvent:Connect(function()
	isSpectating = true
	isSpectator  = true
end)

ForceDeathEvent.OnClientEvent:Connect(function()
	playDeathAnimation()
end)

player.CharacterAdded:Connect(setupCharacter)
if player.Character then setupCharacter(player.Character) end

local GameOverEvent = ReplicatedStorage:WaitForChild("GameOver")

GameOverEvent.OnClientEvent:Connect(function()
	isSpectator = false
	isSpectating = false
	isDead = false
	playDeathAnimation()
end)