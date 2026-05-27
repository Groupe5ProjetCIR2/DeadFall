-- ============================================================
-- Ce script gère la barre de vie personnalisée du joueur. 
-- Elle utilise un module 3D pour incliner l'interface, anime les 
-- segments de vie comme un électrocardiogramme, et affiche un 
-- battement de cœur qui accélère lorsque la santé est basse.
-- ============================================================

local Players = game:GetService("Players")
local RunServ = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RepStorage = game:GetService("ReplicatedStorage")

-- Import du module qui permet de rendre des UI en 3D
local Screen3D = require(RepStorage:WaitForChild("Screen3D"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = playerGui:WaitForChild("CustomHealthBar")
local originalFrame = screenGui:WaitForChild("Frame")

-- On utilise un CanvasGroup pour appliquer des transparences globales facilement
local mainFrame = Instance.new("CanvasGroup")
mainFrame.Name = "AnimatedHealthFrame"
mainFrame.AnchorPoint = Vector2.new(0, 1)
mainFrame.Size = UDim2.new(0, 456, 0, 54) 
mainFrame.BackgroundTransparency = 1
mainFrame.Parent = screenGui

originalFrame:Destroy()

-- Définit les positions de l'animation d'entrée du HUD
local finalPosition = UDim2.new(0, 24, 1, -24)
local startPosition = UDim2.new(0, -600, 1, -24)

mainFrame.Position = startPosition
mainFrame.GroupTransparency = 1
mainFrame.Visible = false

local function animateHealthBarIn()
	mainFrame.Visible = true
	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(mainFrame, tweenInfo, {
		Position = finalPosition,
		GroupTransparency = 0
	}):Play()
end

-- Attends la fin de la cinématique (définie par un attribut du joueur) pour faire apparaître la barre
if player:GetAttribute("CinematicFinished") then
	mainFrame.Position = finalPosition
	mainFrame.GroupTransparency = 0
	mainFrame.Visible = true
else
	player:GetAttributeChangedSignal("CinematicFinished"):Connect(function()
		if player:GetAttribute("CinematicFinished") == true then
			animateHealthBarIn()
		end
	end)
end

local characterImage = Instance.new("ImageLabel")
characterImage.Name = "HeartIcon"
characterImage.Image = "rbxassetid://124194279608481"
characterImage.Size = UDim2.new(0, 48, 0, 42)
characterImage.Position = UDim2.new(0, 30, 0.5, 0)
characterImage.AnchorPoint = Vector2.new(0.5, 0.5) 
characterImage.BackgroundTransparency = 1
characterImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
characterImage.Parent = mainFrame

local barContainer = Instance.new("Frame")
barContainer.Name = "BarContainer"
barContainer.Size = UDim2.new(0, 296, 0, 30)
barContainer.Position = UDim2.new(0, 72, 0.5, 0)
barContainer.AnchorPoint = Vector2.new(0, 0.5)
barContainer.BackgroundTransparency = 1
barContainer.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 3.6)
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.Parent = barContainer

local percentText = Instance.new("TextLabel")
percentText.Name = "PercentText"
percentText.Size = UDim2.new(0, 72, 0, 30)
percentText.Position = UDim2.new(0, 345, 0.5, 0)
percentText.AnchorPoint = Vector2.new(0, 0.5)
percentText.BackgroundTransparency = 1
percentText.Text = "100%"
percentText.TextColor3 = Color3.fromRGB(255, 255, 255)
percentText.Font = Enum.Font.Michroma 
percentText.RichText = true
percentText.Text = "<b>100%</b>"
percentText.TextScaled = false
percentText.TextSize = 19
percentText.TextYAlignment = Enum.TextYAlignment.Center
percentText.TextXAlignment = Enum.TextXAlignment.Left
percentText.Parent = mainFrame

local textStroke = Instance.new("UIStroke")
textStroke.Color = Color3.fromRGB(0, 0, 0)
textStroke.Thickness = 1
textStroke.Parent = percentText

-- Génère 50 barres verticales de tailles aléatoires pour créer l'effet "ondes/électrocardiogramme"
local segments = {}
for i = 1, 50 do
	local segment = Instance.new("Frame")
	segment.Name = "Segment_" .. i
	local randomHeightScale = math.random(40, 100) / 100
	segment.Size = UDim2.new(0, 2.4, randomHeightScale, 0)

	segment.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	segment.BorderSizePixel = 0
	segment.LayoutOrder = i
	segment.Parent = barContainer

	local segmentStroke = Instance.new("UIStroke")
	segmentStroke.Color = Color3.fromRGB(0, 0, 0)
	segmentStroke.Thickness = 1
	segmentStroke.Parent = segment

	table.insert(segments, segment)
end

-- Active le rendu 3D sur notre CanvasGroup
local GUI3D = Screen3D.new(screenGui, 5)
local Frame3D = GUI3D:GetComponent3D(mainFrame)
Frame3D:Enable()

local lastSegmentsDisplayed = 50
local damageId = 0
local wasAtFullHealth = false
local flashCoroutine = nil
local heartTween = nil

local currentBeatSpeed = 5 
local heartPhase = 0
local scrollAccumulator = 0

-- Nettoie les animations visuelles si elles sont en cours
local function stopFlash()
	if flashCoroutine then
		coroutine.close(flashCoroutine)
		flashCoroutine = nil
	end
	if heartTween then
		heartTween:Cancel()
		heartTween = nil
	end
	for i = 1, 50 do
		if segments[i] then
			segments[i].BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			segments[i].BackgroundTransparency = 0
			segments[i].UIStroke.Transparency = 0
		end
	end
	percentText.TextColor3 = Color3.fromRGB(255, 255, 255)
	characterImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
end

-- Crée un effet de "flash vert" quand le joueur regagne 100% de sa vie
local function startFlashEffect()
	stopFlash()
	flashCoroutine = coroutine.create(function()
		local yellowColor = Color3.fromRGB(102, 255, 125)
		local whiteColor = Color3.fromRGB(255, 255, 255)
		for i = 1, 50 do
			if segments[i] then segments[i].BackgroundColor3 = yellowColor end
		end
		percentText.TextColor3 = yellowColor
		characterImage.ImageColor3 = yellowColor
		local duration = 0.4
		local steps = 20
		local stepTime = duration / steps
		for step = 0, steps do
			local t = step / steps
			local easeOut = 1 - (1 - t) * (1 - t)
			local currentColor = yellowColor:Lerp(whiteColor, easeOut)
			for i = 1, 50 do
				if segments[i] then segments[i].BackgroundColor3 = currentColor end
			end
			percentText.TextColor3 = currentColor
			characterImage.ImageColor3 = currentColor
			task.wait(stepTime)
		end
		flashCoroutine = nil
	end)
	coroutine.resume(flashCoroutine)
end

-- S'occupe de mettre à jour la barre (texte, couleur, cacher/montrer les segments) en fonction de la santé
local function updateHealth(humanoid)
	local health = humanoid.Health
	local maxHealth = humanoid.MaxHealth
	if maxHealth <= 0 then maxHealth = 100 end

	local healthRatio = math.clamp(health / maxHealth, 0, 1)
	-- Plus la vie est basse, plus le cœur bat vite
	currentBeatSpeed = 5 + (20 * (1 - healthRatio))
	local percentage = math.floor(healthRatio * 100)

	percentText.Text = "<b>" .. percentage .. "%</b>"

	local currentSegmentsToDisplay = math.ceil(healthRatio * 50)
	local isAtFullHealth = (percentage == 100)

	-- Gère l'animation rouge/disparition lors d'une perte de vie
	if currentSegmentsToDisplay < lastSegmentsDisplayed then
		damageId = damageId + 1
		local currentDamageId = damageId
		wasAtFullHealth = false
		if heartTween then heartTween:Cancel() end

		characterImage.ImageColor3 = Color3.fromRGB(255, 50, 50)
		heartTween = TweenService:Create(characterImage, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {ImageColor3 = Color3.fromRGB(255, 255, 255)})
		heartTween:Play()

		for i = 1, currentSegmentsToDisplay do
			segments[i].BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			segments[i].BackgroundTransparency = 0
			segments[i].UIStroke.Transparency = 0
		end

		local highestVisible = currentSegmentsToDisplay
		for i = 50, currentSegmentsToDisplay + 1, -1 do
			if segments[i].BackgroundTransparency == 0 then
				segments[i].BackgroundColor3 = Color3.fromRGB(255, 50, 50)
				if highestVisible < i then highestVisible = i end
			end
		end

		task.spawn(function()
			task.wait(0.5)
			if damageId ~= currentDamageId then return end
			for i = highestVisible, currentSegmentsToDisplay + 1, -1 do
				if damageId ~= currentDamageId then break end
				if segments[i] and segments[i].BackgroundColor3 == Color3.fromRGB(255, 50, 50) then
					segments[i].BackgroundTransparency = 1
					segments[i].UIStroke.Transparency = 1
					task.wait(0.03)
				end
			end
		end)
	else
		-- Gère le gain de vie
		damageId = damageId + 1
		for i = 1, 50 do
			if i <= currentSegmentsToDisplay then
				segments[i].BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				segments[i].BackgroundTransparency = 0
				segments[i].UIStroke.Transparency = 0
			else
				segments[i].BackgroundTransparency = 1
				segments[i].UIStroke.Transparency = 1
			end
		end
		if isAtFullHealth and not wasAtFullHealth and currentSegmentsToDisplay == 50 then startFlashEffect() end
		wasAtFullHealth = isAtFullHealth
	end
	lastSegmentsDisplayed = currentSegmentsToDisplay
end

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	lastSegmentsDisplayed = math.ceil((humanoid.Health / humanoid.MaxHealth) * 50)
	wasAtFullHealth = (humanoid.Health == humanoid.MaxHealth)
	updateHealth(humanoid)

	humanoid.HealthChanged:Connect(function() updateHealth(humanoid) end)
end

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

-- Désactive la barre de vie par défaut de Roblox
pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end)

local BASE_SCROLL_SPEED = 20  
local PULSE_SCROLL_BONUS = 30 
local DECAY_FACTOR = 0.90 

-- Applique un angle de vue 3D permanent
Frame3D.offset = CFrame.Angles(0, 0.14, 0)

-- Boucle ultra-rapide qui fait défiler l'animation des segments vers la droite
RunServ.Heartbeat:Connect(function(deltaTime)

	-- Coupe les calculs si la barre est invisible (optimisation des performances)
	if not mainFrame.Visible or mainFrame.GroupTransparency >= 0.99 then 
		return 
	end

	-- Mathématiques du battement de cœur (calcul sinusoïdal)
	heartPhase = heartPhase + (currentBeatSpeed * deltaTime)
	local pulse = math.max(0, math.sin(heartPhase)) ^ 4 

	local newWidth = 48 + (12 * pulse)
	local newHeight = 42 + (10.5 * pulse)
	characterImage.Size = UDim2.new(0, newWidth, 0, newHeight)

	local dynamicScrollSpeed = BASE_SCROLL_SPEED + (PULSE_SCROLL_BONUS * pulse)
	scrollAccumulator = scrollAccumulator + (dynamicScrollSpeed * deltaTime)

	if scrollAccumulator >= 1 then
		local steps = math.floor(scrollAccumulator)
		scrollAccumulator = scrollAccumulator - steps

		-- Sécurité anti-lag : on empêche les bonds géants dans l'animation 
		steps = math.min(steps, 2)

		-- Décale les valeurs de hauteur des segments vers la droite pour créer le mouvement
		for s = 1, steps do
			for i = 50, 2, -1 do
				local prevHeight = segments[i-1].Size.Y.Scale
				local newHeight = prevHeight
				if i % 22 == 0 then
					newHeight = math.clamp(prevHeight * DECAY_FACTOR, 0.02, 1)
				end
				segments[i].Size = UDim2.new(0, 2.4, newHeight, 0)
			end
			-- Le 1er segment prend une nouvelle taille aléatoire qui va ensuite se décaler
			local randomHeightScale = math.random(40, 100) / 100
			segments[1].Size = UDim2.new(0, 2.4, randomHeightScale, 0)
		end
	end
end)