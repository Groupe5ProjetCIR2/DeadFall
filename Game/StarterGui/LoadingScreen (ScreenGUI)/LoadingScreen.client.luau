-- ============================================================
-- Script de gestion de l'écran de chargement (Loading Screen).
-- Gère l'immobilisation du joueur, la barre de progression, 
-- l'affichage de conseils, les effets visuels (glitch/fondu) 
-- et la transition vers le jeu une fois la map chargée.
-- ============================================================

local ReplicatedFirst = game:GetService("ReplicatedFirst")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local MapLoadedEvent = ReplicatedStorage:WaitForChild("MapLoadedEvent", 10)

-- On signale que le joueur est en train de charger
player:SetAttribute("IsLoading", true)

local screenGui = script.Parent
screenGui.Parent = playerGui
screenGui.DisplayOrder = 9999 

local tweenService = game:GetService("TweenService")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")

local mouseLock = runService.RenderStepped:Connect(function()
	userInputService.MouseIconEnabled = false
	userInputService.MouseIcon = "rbxassetid://0"
end)

screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true

local ecranNoir = Instance.new("Frame")
ecranNoir.Name = "EcranNoir"
ecranNoir.Size = UDim2.new(1, 0, 1, 0)
ecranNoir.Position = UDim2.new(0, 0, 0, 0)
ecranNoir.BackgroundColor3 = Color3.new(0, 0, 0)
ecranNoir.BackgroundTransparency = 1
ecranNoir.BorderSizePixel = 0
ecranNoir.ZIndex = 10
ecranNoir.Parent = screenGui

local craneFerme = screenGui:WaitForChild("Craneferme")
local craneOuvert = screenGui:WaitForChild("Craneouvert")
local mongif = screenGui:WaitForChild("mongif")

-- Taille augmentée à 1.1 pour permettre le déplacement sans voir les bords de l'écran
local function configurerImage(image)
	image.Size = UDim2.new(1.1, 0, 1.1, 0)
	image.Position = UDim2.new(0, 0, 0, 0)
	image.BackgroundTransparency = 1 
	image.ScaleType = Enum.ScaleType.Crop
	image.Visible = true
end

configurerImage(craneFerme)
configurerImage(craneOuvert)

local barreFond = Instance.new("Frame")
barreFond.Name = "BarreFond"
barreFond.Size = UDim2.new(0.2, 0, 0, 4)
barreFond.Position = UDim2.new(0.5, 0, 0.6, 0)
barreFond.AnchorPoint = Vector2.new(0.5, 0.5)
barreFond.BackgroundColor3 = Color3.new(0, 0, 0)
barreFond.BorderSizePixel = 0
barreFond.BackgroundTransparency = 1 
barreFond.Parent = screenGui

local barreChargement = Instance.new("Frame")
barreChargement.Name = "BarreChargement"
barreChargement.Size = UDim2.new(0, 0, 1, 0)
barreChargement.Position = UDim2.new(0, 0, 0, 0)
barreChargement.BackgroundColor3 = Color3.new(1, 1, 1)
barreChargement.BorderSizePixel = 0
barreChargement.BackgroundTransparency = 1 
barreChargement.Parent = barreFond

-- ==========================================
-- TEXTE DE CONSEIL ET ANIMATION GLITCH
-- ==========================================
local texteConseil = Instance.new("TextLabel")
texteConseil.Name = "TexteConseil"
texteConseil.Size = UDim2.new(0.8, 0, 0.1, 0)
texteConseil.Position = UDim2.new(0.5, 0, 0.85, 0)
texteConseil.AnchorPoint = Vector2.new(0.5, 0.5)
texteConseil.BackgroundTransparency = 1
texteConseil.FontFace = Font.new("rbxasset://fonts/families/Zekton.json")
texteConseil.RichText = true 
texteConseil.TextColor3 = Color3.new(1, 1, 1)
texteConseil.TextStrokeTransparency = 0 
texteConseil.TextTransparency = 1
texteConseil.TextScaled = true
texteConseil.ZIndex = 50 -- Forcé tout devant pour être lisible par-dessus le gif
texteConseil.Parent = screenGui

local listeConseils = {
	"<b>ECONOMY</b>\nMaximize your early-game income by repairing the window barricades.",
	"<b>WEAK POINTS</b>\nFind the bubblegum vending machines to get character boosts.",
	"<b>STAMINA</b>\nWall-running and slide-jumping consume stamina. Don't get caught walking in a horde!",
	"<b>MAP CONTROL</b>\nNever corner yourself. Always keep an escape route open.",
	"<b>DEFENSE</b>\nMake sure to get your gear ready between waves.",
	"<b>GEAR</b>\nAim for the head to maximize your damage.",
	"<b>MODULES</b>\nFind the stalls and some money to upgrade your weapons.",
	"<b>WEAPONS</b>\nChoose your weapons wisely, they all have their own unique characteristics..",
	"<b>AWARENESS</b>\nBe careful... During certain waves, a nasty zombie might appear.",
	"<b>UPGRADES</b>\nSave your credits! Upgrading your weapon is crucial to survive later waves.",
	"<b>TRAINING</b>\nGroup the mechanical horde into a tight cluster before using explosive ordnance.",
	"<b>TEAMWORK</b>\nCommunicate with your squad. Reviving a downed teammate is much harder mid-wave.",
	"<b>LUCKY DAY</b>\nGive the wheel a try, you never know when your luck might change."
}

local currentTipIndex = math.random(1, #listeConseils)
texteConseil.Text = listeConseils[currentTipIndex]

local isGlitching = false
local glitchChars = {"#", "0", "E", "5", "1", "6", "@", "%", "?", "X", "Z", "&", "*", "!", ">", "<"}

local function generateRandomString(length)
	local str = ""
	for i = 1, length do
		str = str .. glitchChars[math.random(1, #glitchChars)]
	end
	return str
end

local function glitchTextAndChange()
	if isGlitching then return end
	isGlitching = true

	local nextTipIndex = currentTipIndex
	repeat
		nextTipIndex = math.random(1, #listeConseils)
	until nextTipIndex ~= currentTipIndex
	currentTipIndex = nextTipIndex

	for i = 1, 5 do
		local randomTitle = generateRandomString(math.random(5, 8))
		local randomBody = generateRandomString(math.random(20, 40))
		texteConseil.Text = "<b>" .. randomTitle .. "</b>\n" .. randomBody
		task.wait(0.02) 
	end

	texteConseil.Text = listeConseils[currentTipIndex]
	isGlitching = false
end

local progression = 0
local chargementTermine = false

local inputConnection
inputConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if not chargementTermine then
			glitchTextAndChange()
		end
	end
end)

local animationSpeed = 0.12
craneFerme.Visible = true
craneOuvert.Visible = false

local bloqueurEquipement = nil
local backpackConnection = nil
local charToolConnection = nil

local function bloquerPersonnage()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
	end
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			tool.Parent = player:FindFirstChild("Backpack")
		end
	end
end

local function surveillerEquipement()
	bloqueurEquipement = player.CharacterAdded:Connect(function(character)
		if not chargementTermine then
			task.wait()
			bloquerPersonnage()

			local backpack = player:WaitForChild("Backpack", 5)
			if backpack then
				if backpackConnection then backpackConnection:Disconnect() end
				backpackConnection = backpack.ChildAdded:Connect(function(tool)
					if not chargementTermine and tool:IsA("Tool") then
						task.wait()
						tool.Parent = backpack
					end
				end)
			end

			if charToolConnection then charToolConnection:Disconnect() end
			charToolConnection = character.ChildAdded:Connect(function(tool)
				if not chargementTermine and tool:IsA("Tool") then
					tool.Parent = player:FindFirstChild("Backpack")
				end
			end)
		end
	end)

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then tool.Parent = backpack end
		end
		backpackConnection = backpack.ChildAdded:Connect(function(tool)
			if not chargementTermine and tool:IsA("Tool") then
				task.wait()
				tool.Parent = backpack
			end
		end)
	end

	if player.Character then
		charToolConnection = player.Character.ChildAdded:Connect(function(tool)
			if not chargementTermine and tool:IsA("Tool") then
				tool.Parent = player:FindFirstChild("Backpack")
			end
		end)
	end
end

surveillerEquipement()
if player.Character then bloquerPersonnage() end

local function deleteAllWhiteRectangles()
	for _, child in ipairs(ecranNoir:GetChildren()) do
		if child.Name:find("WhiteRectangle_") then child:Destroy() end
	end
end

local function createWhiteRectangles()
	local rectangles = {}
	local rectangleCount = math.random(2, 4)
	for i = 1, rectangleCount do
		local rect = Instance.new("Frame")
		rect.Name = "WhiteRectangle_" .. i
		rect.Size = UDim2.new(0, 90, 0, 10)
		rect.BackgroundColor3 = Color3.new(1, 1, 1)
		rect.BorderSizePixel = 0
		rect.ZIndex = 20
		rect.Visible = false
		rect.Parent = ecranNoir
		table.insert(rectangles, rect)
	end
	return rectangles
end

local function getRandomPosition(usedPositions, minDistance)
	local maxAttempts = 50
	local attempt = 0
	while attempt < maxAttempts do
		local randomX = math.random(10, 90) / 100
		local randomY = math.random(10, 90) / 100
		local tooClose = false
		for _, pos in ipairs(usedPositions) do
			local dx = math.abs(randomX - pos.x)
			local dy = math.abs(randomY - pos.y)
			if dx < minDistance and dy < minDistance then
				tooClose = true
				break
			end
		end
		if not tooClose then return {x = randomX, y = randomY} end
		attempt = attempt + 1
	end
	return {x = math.random(10, 90) / 100, y = math.random(10, 90) / 100}
end

local function showWhiteRectangles(rectangles)
	local usedPositions = {}
	local minDistance = 0.15
	for _, rect in ipairs(rectangles) do
		local pos = getRandomPosition(usedPositions, minDistance)
		rect.Position = UDim2.new(pos.x, 0, pos.y, 0)
		rect.AnchorPoint = Vector2.new(0.5, 0.5)
		rect.Visible = true
		table.insert(usedPositions, pos)
	end
end

local function hideWhiteRectangles(rectangles)
	for _, rect in ipairs(rectangles) do rect.Visible = false end
end

local function runWhiteRectanglesSequence()
	for i = 1, 3 do
		deleteAllWhiteRectangles()
		local rectangles = createWhiteRectangles()
		showWhiteRectangles(rectangles)
		task.wait(0.05)
		hideWhiteRectangles(rectangles)
		task.wait(0.05)
	end
	task.wait(0.05)
	deleteAllWhiteRectangles()
end

-- Gère le déplacement en diagonale infini des crânes
local function demarrerPanoramique()
	-- Temps réduit de 15 à 6 secondes pour un mouvement plus rapide
	local panInfo = TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
	local positionCible = UDim2.new(-0.1, 0, -0.1, 0)

	tweenService:Create(craneFerme, panInfo, {Position = positionCible}):Play()
	tweenService:Create(craneOuvert, panInfo, {Position = positionCible}):Play()
end

local function apparitionEnFondu()
	local ti = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
	tweenService:Create(craneFerme, ti, {BackgroundTransparency = 0}):Play()
	tweenService:Create(barreFond, ti, {BackgroundTransparency = 0}):Play()
	tweenService:Create(barreChargement, ti, {BackgroundTransparency = 0}):Play()
	tweenService:Create(texteConseil, ti, {TextTransparency = 0}):Play()
end

local function alternerCranes()
	while not chargementTermine do
		task.wait(animationSpeed)
		craneFerme.Visible = false
		craneOuvert.Visible = true
		task.wait(animationSpeed)
		craneFerme.Visible = true
		craneOuvert.Visible = false
	end
end

local function miseAJourBarre(nouvelleProgression)
	progression = math.min(nouvelleProgression, 1)
	barreChargement:TweenSize(UDim2.new(progression, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
end

local function chargerJeu()
	if not game:IsLoaded() then game.Loaded:Wait() end
	local attenteMap = true
	local mapPrete = false -- On ajoute une variable pour savoir si la minimap a dit "OK"

	-- On écoute le signal de la minimap (s'il existe)
	if MapLoadedEvent then
		MapLoadedEvent.Event:Connect(function()
			mapPrete = true
		end)
	else
		mapPrete = true -- Sécurité : si l'event n'existe pas, on passe la map
	end

	task.spawn(function()
		local fausseProgression = 0
		-- On bloque la barre à 90% tant que la map n'est pas prête !
		while attenteMap and fausseProgression < 0.90 do
			fausseProgression += 0.01
			miseAJourBarre(fausseProgression)
			task.wait(0.05)
		end
	end)

	-- Au lieu d'attendre 3 secondes, on attend que la map soit prête !
	-- (On met quand même une sécurité de 10 secondes max au cas où la minimap bug)
	local tempsAttente = 0
	while not mapPrete and tempsAttente < 10 do
		task.wait(0.1)
		tempsAttente += 0.1
	end

	attenteMap = false
	miseAJourBarre(1)
	task.wait(0.8) 
	return true
end

local function debloquerPersonnage()
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then root.Anchored = false end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local backpack = player:FindFirstChild("Backpack")
		if humanoid and backpack then
			local pistol = backpack:FindFirstChild("Desert Eagle 2")
			if pistol then
				humanoid:EquipTool(pistol)
			end
		end
	end
end

local function afficherControles()
	-- 1. Overlay plein écran (beaucoup plus transparent)
	local overlay = Instance.new("Frame")
	overlay.Name = "CinematicControlsOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 1 
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	-- Bandes cinématiques (Letterbox) allégées
	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 120)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	topBar.BorderSizePixel = 0
	topBar.BackgroundTransparency = 1
	topBar.Parent = overlay

	local bottomBar = topBar:Clone()
	bottomBar.Position = UDim2.new(0, 0, 1, -120)
	bottomBar.Parent = overlay

	-- Grand Titre
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 100)
	header.Position = UDim2.new(0, 0, 0.12, 0)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBlack
	header.Text = "C O M B A T   P R O T O C O L S"
	header.TextColor3 = Color3.fromRGB(255, 255, 255)
	header.TextSize = 45 
	header.TextTransparency = 1
	header.Parent = overlay

	-- Conteneur massif pour les touches
	local controlsContainer = Instance.new("Frame")
	controlsContainer.Size = UDim2.new(0.9, 0, 0.6, 0)
	controlsContainer.Position = UDim2.new(0.5, 0, 0.55, 0)
	controlsContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	controlsContainer.BackgroundTransparency = 1
	controlsContainer.Parent = overlay

	local layout = Instance.new("UIListLayout")
	layout.Parent = controlsContainer
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 25) 

	local touches = {
		{"SHIFT", "S P R I N T  /  W A L L R I D E"},
		{"SPACE", "J U M P"},
		{"C", "S L I D E"},
		{"R", "R E L O A D"},
		{"E", "I N T E R A C T"}
	}

	local elementsToFadeText = {header}
	local elementsToFadeBg = {overlay, topBar, bottomBar}
	local elementsToFadeLine = {}

	for i, data in ipairs(touches) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 50)
		row.BackgroundTransparency = 1
		row.Parent = controlsContainer

		-- La Touche
		local keyLabel = Instance.new("TextLabel")
		keyLabel.Size = UDim2.new(0.48, 0, 1, 0)
		keyLabel.Position = UDim2.new(0, 0, 0, 0)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Font = Enum.Font.GothamBlack
		keyLabel.Text = "[ " .. data[1] .. " ]"
		keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		keyLabel.TextSize = 35 
		keyLabel.TextXAlignment = Enum.TextXAlignment.Right
		keyLabel.TextTransparency = 1
		keyLabel.Parent = row

		-- Séparateur vertical allégé
		local separator = Instance.new("Frame")
		separator.Size = UDim2.new(0, 2, 0.6, 0)
		separator.Position = UDim2.new(0.5, -1, 0.2, 0)
		separator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		separator.BorderSizePixel = 0
		separator.BackgroundTransparency = 1
		separator.Parent = row

		-- L'Action
		local actionLabel = Instance.new("TextLabel")
		actionLabel.Size = UDim2.new(0.48, 0, 1, 0)
		actionLabel.Position = UDim2.new(0.52, 0, 0, 0)
		actionLabel.BackgroundTransparency = 1
		actionLabel.Font = Enum.Font.GothamMedium
		actionLabel.Text = data[2]
		actionLabel.TextColor3 = Color3.fromRGB(180, 190, 200)
		actionLabel.TextSize = 30 
		actionLabel.TextXAlignment = Enum.TextXAlignment.Left
		actionLabel.TextTransparency = 1
		actionLabel.Parent = row

		table.insert(elementsToFadeText, keyLabel)
		table.insert(elementsToFadeText, actionLabel)
		table.insert(elementsToFadeLine, separator)
	end

	-- =======================================
	-- ANIMATIONS ET GESTION DU TEMPS
	-- =======================================

	local tiIn = TweenInfo.new(1.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

	-- Le fond laisse beaucoup plus voir le jeu (65% transparent pour l'overlay)
	tweenService:Create(overlay, tiIn, {BackgroundTransparency = 0.65}):Play() 
	tweenService:Create(topBar, tiIn, {BackgroundTransparency = 0.35}):Play()
	tweenService:Create(bottomBar, tiIn, {BackgroundTransparency = 0.35}):Play()

	for _, el in ipairs(elementsToFadeText) do
		tweenService:Create(el, tiIn, {TextTransparency = 0}):Play()
	end
	for _, el in ipairs(elementsToFadeLine) do
		tweenService:Create(el, tiIn, {BackgroundTransparency = 0.75}):Play()
	end

	-- Durée réduite
	task.wait(6)

	local tiOut = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

	for _, el in ipairs(elementsToFadeBg) do
		tweenService:Create(el, tiOut, {BackgroundTransparency = 1}):Play()
	end
	for _, el in ipairs(elementsToFadeText) do
		tweenService:Create(el, tiOut, {TextTransparency = 1}):Play()
	end
	for _, el in ipairs(elementsToFadeLine) do
		tweenService:Create(el, tiOut, {BackgroundTransparency = 1}):Play()
	end

	task.wait(1.5)
	overlay:Destroy()
end

local function transitionGlitch()
	chargementTermine = true
	player:SetAttribute("IsLoading", false)

	if inputConnection then inputConnection:Disconnect() end
	if bloqueurEquipement then bloqueurEquipement:Disconnect() end
	if backpackConnection then backpackConnection:Disconnect() end
	if charToolConnection then charToolConnection:Disconnect() end

	-- Nettoyage de l'écran de chargement
	ecranNoir.BackgroundTransparency = 0
	texteConseil.Visible = false
	craneFerme.Visible = false
	craneOuvert.Visible = false
	barreFond.BackgroundTransparency = 1
	barreChargement.BackgroundTransparency = 1
	mongif.ImageTransparency = 1
	craneFerme.ImageTransparency = 1
	craneOuvert.ImageTransparency = 1
	craneFerme.BackgroundTransparency = 1
	craneOuvert.BackgroundTransparency = 1

	task.wait(0.1)
	runWhiteRectanglesSequence()

	-- ==========================================
	-- 1. DÉBLOCAGE IMMÉDIAT DU JOUEUR
	-- ==========================================
	if mouseLock then mouseLock:Disconnect() end
	userInputService.MouseIconEnabled = true
	userInputService.MouseIcon = ""

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	if player.Character then
		local humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
	end

	debloquerPersonnage()

	local playerLoadedEvent = ReplicatedStorage:WaitForChild("PlayerLoaded")
	playerLoadedEvent:FireServer()
	player:SetAttribute("CinematicFinished", true)

	-- ==========================================
	-- 2. DISPARITION DE L'ÉCRAN NOIR
	-- ==========================================
	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quart)
	local fonduOuverture = tweenService:Create(ecranNoir, tweenInfo, {BackgroundTransparency = 1})
	fonduOuverture:Play()
	fonduOuverture.Completed:Wait()

	-- Destruction du GUI une fois le bandeau effacé
	screenGui:Destroy()
end

task.spawn(function()
	apparitionEnFondu()
	demarrerPanoramique()
	task.spawn(alternerCranes)
	local succes = chargerJeu()
	if succes then transitionGlitch() end
end)