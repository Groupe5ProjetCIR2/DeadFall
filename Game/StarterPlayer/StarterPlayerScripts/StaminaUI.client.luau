-- ============================================================
--  Ce script gère l'interface utilisateur 3D de l'endurance (stamina), 
--  incluant une barre de progression et des icônes d'action dynamiques. 
--  Il optimise les performances en interrompant les calculs lorsque l'endurance 
--  est pleine et au repos, tout en assurant des transitions visuelles fluides.
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider") 

local Stamina = require(ReplicatedStorage:WaitForChild("StaminaManager"))
local Screen3D = require(ReplicatedStorage:WaitForChild("Screen3D"))

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local UI_CONFIG = {
	BarWidth = 220,          
	BarHeight = 6,           
	IndicatorWidth = 2,
	FadeTransparencyBg = 0.6, 
	IconWidth = 35,
	IconHeight = 32,
	IconPadding = 10,
}

local COLORS = {
	Normal = Color3.fromRGB(255, 255, 255),
	EmptyFlash = Color3.fromRGB(255, 0, 0),
	FullFlash = Color3.fromRGB(138, 210, 255),
	Indicator = Color3.fromRGB(255, 255, 255),
	IconBase = Color3.fromRGB(255, 255, 255),
}

local ICONS = {
	Run = "rbxassetid://93496716763836",
	Slide = "rbxassetid://121473934396482",
	Wallrun = "rbxassetid://133458672881160",
	Jetpack = "rbxassetid://103131643060936",
	Jump = "rbxassetid://112032973735235"
}

-- Préchargement asynchrone des assets visuels pour éviter les saccades lors du premier affichage
task.spawn(function()
	local imagesToLoad = {}
	for _, id in pairs(ICONS) do
		local decal = Instance.new("Decal")
		decal.Texture = id
		table.insert(imagesToLoad, decal)
	end
	ContentProvider:PreloadAsync(imagesToLoad)
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "StaminaDisplay_3D"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainContainer"
MainFrame.AnchorPoint = Vector2.new(0, 1) 
MainFrame.Position = UDim2.new(0, 20, 1, -90) 
MainFrame.Size = UDim2.new(0, UI_CONFIG.BarWidth + UI_CONFIG.IconPadding + UI_CONFIG.IconWidth, 0, math.max(UI_CONFIG.BarHeight, UI_CONFIG.IconHeight))
MainFrame.BackgroundTransparency = 1 
MainFrame.Parent = ScreenGui

local StaminaIconA = Instance.new("ImageLabel")
StaminaIconA.Name = "StaminaIconA"
StaminaIconA.Image = ICONS.Run
StaminaIconA.Size = UDim2.new(0, UI_CONFIG.IconWidth, 0, UI_CONFIG.IconHeight)
StaminaIconA.AnchorPoint = Vector2.new(0, 0.5)
StaminaIconA.Position = UDim2.new(0, 0, 0.5, 0)
StaminaIconA.BackgroundTransparency = 1
StaminaIconA.ImageTransparency = 1 
StaminaIconA.ImageColor3 = COLORS.IconBase
StaminaIconA.Parent = MainFrame

local StaminaIconB = StaminaIconA:Clone()
StaminaIconB.Name = "StaminaIconB"
StaminaIconB.ImageTransparency = 1 
StaminaIconB.Parent = MainFrame

local activeImg = StaminaIconA
local inactiveImg = StaminaIconB
local IconBaseTransparency = 1

local BgFrame = Instance.new("Frame")
BgFrame.Name = "Background"
BgFrame.AnchorPoint = Vector2.new(0, 0.5) 
BgFrame.Position = UDim2.new(0, UI_CONFIG.IconWidth + UI_CONFIG.IconPadding, 0.5, 0) 
BgFrame.Size = UDim2.new(0, UI_CONFIG.BarWidth, 0, UI_CONFIG.BarHeight)
BgFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
BgFrame.BackgroundTransparency = 1 
BgFrame.BorderSizePixel = 0
BgFrame.Parent = MainFrame

local FillFrame = Instance.new("Frame")
FillFrame.Name = "Fill"
FillFrame.Size = UDim2.new(1, 0, 1, 0)
FillFrame.BackgroundColor3 = COLORS.Normal 
FillFrame.BackgroundTransparency = 1 
FillFrame.BorderSizePixel = 0
FillFrame.Parent = BgFrame

local Indicator = Instance.new("Frame")
Indicator.Name = "Indicator"
Indicator.AnchorPoint = Vector2.new(0.5, 0.5)
Indicator.Size = UDim2.new(0, UI_CONFIG.IndicatorWidth, 0, UI_CONFIG.BarHeight + 6) 
Indicator.BackgroundColor3 = COLORS.Indicator
Indicator.BackgroundTransparency = 1 
Indicator.BorderSizePixel = 0
Indicator.ZIndex = FillFrame.ZIndex + 1 
Indicator.Parent = BgFrame

local IndicatorShadow = Instance.new("Frame")
IndicatorShadow.Name = "Shadow"
IndicatorShadow.ZIndex = Indicator.ZIndex - 1
IndicatorShadow.Size = UDim2.new(1, 2, 1, 0) 
IndicatorShadow.Position = UDim2.new(0.5, 1, 0.5, 0)
IndicatorShadow.AnchorPoint = Vector2.new(0.5, 0.5)
IndicatorShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
IndicatorShadow.BackgroundTransparency = 1 
IndicatorShadow.BorderSizePixel = 0
IndicatorShadow.Parent = Indicator

-- Instanciation du module Screen3D pour projeter le GUI dans l'espace physique
local GUI3D = Screen3D.new(ScreenGui, 5)
local Frame3D = GUI3D:GetComponent3D(MainFrame)
Frame3D:Enable()

local fadeSpeed = 0.1     
local indicatorFade = 0.08

-- Déclenche l'apparition progressive de l'interface complète
local function FadeIn()
	IconBaseTransparency = 0
	local transBg = UI_CONFIG.FadeTransparencyBg
	TweenService:Create(BgFrame, TweenInfo.new(fadeSpeed), {BackgroundTransparency = transBg}):Play()
	TweenService:Create(FillFrame, TweenInfo.new(fadeSpeed), {BackgroundTransparency = 0}):Play()
	TweenService:Create(activeImg, TweenInfo.new(fadeSpeed), {ImageTransparency = 0}):Play()
end

-- Dissimule entièrement l'interface lorsque l'endurance est pleine et inactive
local function FadeOut()
	IconBaseTransparency = 1
	TweenService:Create(BgFrame, TweenInfo.new(fadeSpeed), {BackgroundTransparency = 1}):Play()
	TweenService:Create(FillFrame, TweenInfo.new(fadeSpeed), {BackgroundTransparency = 1}):Play()
	TweenService:Create(activeImg, TweenInfo.new(fadeSpeed), {ImageTransparency = 1}):Play()
	TweenService:Create(inactiveImg, TweenInfo.new(fadeSpeed), {ImageTransparency = 1}):Play()
end

-- Alterne la visibilité du curseur (indicateur) en fin de jauge
local isIndicatorVisible = false
local function FadeIndicator(show)
	if isIndicatorVisible == show then return end
	isIndicatorVisible = show

	local targetTrans = show and 0 or 1
	local shadowTrans = show and 0.5 or 1

	TweenService:Create(Indicator, TweenInfo.new(indicatorFade), {BackgroundTransparency = targetTrans}):Play()
	TweenService:Create(IndicatorShadow, TweenInfo.new(indicatorFade), {BackgroundTransparency = shadowTrans}):Play()
end

-- Change la couleur de l'interface en rouge pour indiquer l'épuisement total
local isExhausted = false
local function BecomeExhausted()
	if isExhausted then return end
	isExhausted = true

	local info = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(FillFrame, info, {BackgroundColor3 = COLORS.EmptyFlash}):Play()
	TweenService:Create(activeImg, info, {ImageColor3 = COLORS.EmptyFlash}):Play()
	TweenService:Create(inactiveImg, info, {ImageColor3 = COLORS.EmptyFlash}):Play()
	TweenService:Create(Indicator, info, {BackgroundColor3 = COLORS.EmptyFlash}):Play()
end

-- Exécute une animation de clignotement bleu signifiant le rechargement complet de la jauge
local isFlashingBlue = false
local function FlashBlueAndFade()
	if isFlashingBlue then return end
	isFlashingBlue = true

	local info = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local fillBlue = {BackgroundColor3 = COLORS.FullFlash}
	local fillNormal = {BackgroundColor3 = COLORS.Normal}
	local indicatorNormal = {BackgroundColor3 = COLORS.Indicator} 

	local iconBlue = {ImageColor3 = COLORS.FullFlash}
	local iconNormal = {ImageColor3 = COLORS.IconBase}

	local t1_fill = TweenService:Create(FillFrame, info, fillBlue)
	local t1_iconA = TweenService:Create(activeImg, info, iconBlue)
	local t1_iconB = TweenService:Create(inactiveImg, info, iconBlue)
	local t1_indicator = TweenService:Create(Indicator, info, fillBlue) 

	local t2_fill = TweenService:Create(FillFrame, info, fillNormal)
	local t2_iconA = TweenService:Create(activeImg, info, iconNormal)
	local t2_iconB = TweenService:Create(inactiveImg, info, iconNormal)
	local t2_indicator = TweenService:Create(Indicator, info, indicatorNormal) 

	t1_fill:Play(); t1_iconA:Play(); t1_iconB:Play(); t1_indicator:Play()
	t1_fill.Completed:Wait()

	t2_fill:Play(); t2_iconA:Play(); t2_iconB:Play(); t2_indicator:Play()
	t2_fill.Completed:Wait()

	task.wait(0.5)

	if Stamina.Current >= Stamina.Max then
		FadeOut()
	end

	isFlashingBlue = false
end

local lastStamina = Stamina.Max
local currentPhysWidth = 1 

local Lerp = function(a, b, t) return a + (b - a) * t end

-- Définit statiquement le décalage angulaire de l'élément 3D
Frame3D.offset = CFrame.Angles(0, 0.14, 0)

-- Boucle de rendu optimisée (Heartbeat) gérant la logique d'interpolation de la jauge
RunService.Heartbeat:Connect(function(dt)
	local current = Stamina.Current
	local max = Stamina.Max

	-- Vérifie si le joueur est au repos complet pour couper les calculs inutiles
	local isIdle = (current == max) and (math.abs(currentPhysWidth - 1) < 0.001) and (BgFrame.BackgroundTransparency >= 0.99) and (not isFlashingBlue)

	if isIdle then
		currentPhysWidth = 1
		lastStamina = current
		return 
	end

	local rawProgress = math.clamp(current / max, 0, 1)
	currentPhysWidth = Lerp(currentPhysWidth, rawProgress, 25 * dt) 

	FillFrame.Size = UDim2.new(currentPhysWidth, 0, 1, 0)
	Indicator.Position = UDim2.new(currentPhysWidth, 0, 0.5, 0)

	if currentPhysWidth > 0.99 then
		FadeIndicator(false)
	else
		FadeIndicator(true)
	end

	if current < lastStamina then
		if BgFrame.BackgroundTransparency > 0.8 then
			FadeIn()
		end
	end

	if current <= 0 and not isExhausted then
		BecomeExhausted()
	end

	if current >= max and lastStamina < max then
		isExhausted = false 
		task.spawn(FlashBlueAndFade) 
	end

	lastStamina = current
end)

local iconResetTask = nil

-- Gère le fondu croisé (crossfade) fluide entre deux icônes d'action
local function TransitionToIcon(newImageId)
	if activeImg.Image == newImageId then return end

	inactiveImg.Image = newImageId
	inactiveImg.ImageColor3 = activeImg.ImageColor3

	local crossFadeTime = 0.25
	local tweenInfo = TweenInfo.new(crossFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(inactiveImg, tweenInfo, {ImageTransparency = IconBaseTransparency}):Play()
	TweenService:Create(activeImg, tweenInfo, {ImageTransparency = 1}):Play()

	local temp = activeImg
	activeImg = inactiveImg
	inactiveImg = temp
end

-- Lit les attributs du personnage pour déterminer quelle icône afficher selon son état physique
local function UpdateStaminaIcon()
	local char = Player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")

	local isJet = char:GetAttribute("IsJetpacking")
	local isWall = char:GetAttribute("IsWallrunning")
	local isSlide = hrp and hrp:GetAttribute("IsSliding")
	local isJump = char:GetAttribute("IsDoubleJumping")

	if isJet or isWall or isSlide or isJump then
		if iconResetTask then
			task.cancel(iconResetTask)
			iconResetTask = nil
		end

		if isJump then
			TransitionToIcon(ICONS.Jump)
		elseif isJet then
			TransitionToIcon(ICONS.Jetpack)
		elseif isWall then
			TransitionToIcon(ICONS.Wallrun)
		elseif isSlide then
			TransitionToIcon(ICONS.Slide)
		end
	else
		if not iconResetTask then
			iconResetTask = task.delay(0.5, function()
				TransitionToIcon(ICONS.Run)
				iconResetTask = nil
			end)
		end
	end
end

-- Connecte les signaux de changement d'attributs aux mises à jour de l'icône de la jauge
local function SetupIconListeners(char)
	local hrp = char:WaitForChild("HumanoidRootPart")

	char:GetAttributeChangedSignal("IsJetpacking"):Connect(UpdateStaminaIcon)
	char:GetAttributeChangedSignal("IsWallrunning"):Connect(UpdateStaminaIcon)
	char:GetAttributeChangedSignal("IsDoubleJumping"):Connect(UpdateStaminaIcon)
	hrp:GetAttributeChangedSignal("IsSliding"):Connect(UpdateStaminaIcon)

	UpdateStaminaIcon()
end

if Player.Character then
	SetupIconListeners(Player.Character)
end
Player.CharacterAdded:Connect(SetupIconListeners)