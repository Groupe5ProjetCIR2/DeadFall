-- ============================================================
-- Ce script (ToutArgent) gère l'interface de l'argent du joueur.
-- Il est placé dans l'interface "ArgentUI" aux côtés de l'élément "phonk_gif".
-- Il gère l'affichage classique de la monnaie, un système de combo, 
-- et un mode "Fever" (Bonus x2) avec des animations (tremblements, GIF dynamique).
-- ============================================================

local Players = game:GetService("Players")
local RunServ = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local replicatedStorage_folder_voiceslines = RepStorage:WaitForChild("VoiceLines")
local boostSound = SoundService:FindFirstChild("boost_argent")

local perteArgentSound = Instance.new("Sound")
perteArgentSound.Name = "PerteArgentSound"
perteArgentSound.SoundId = "rbxassetid://87123900728301"
perteArgentSound.Volume = 1
perteArgentSound.Parent = SoundService

local Screen3D = require(RepStorage:WaitForChild("Screen3D"))
local AfficherGainEvent = RepStorage:WaitForChild("AfficherGainArgent")
local ActiverFeverEvent = RepStorage:WaitForChild("ActiverFever")

local player = Players.LocalPlayer
local screenGui = script.Parent -- Fait référence à "ArgentUI"
local zektonFont = Font.new("rbxasset://fonts/families/Zekton.json")

-- Récupération du GIF situé au même niveau que ce script
local phonk_gif = screenGui:WaitForChild("phonk_gif")

local comboIntensity = 0 
local MAX_TEXT_SIZE = 55  
local BASE_TEXT_SIZE = 40 

local feverActive = false
local feverTimer = 0
local FEVER_DURATION = 3.5

local visualColor = Color3.fromRGB(255, 255, 255)
local visualScale = 1
local visualRotation = -140
local visualGifAlpha = 0
local visualComboAlpha = 0
local punchScale = 0

local BASE_CHRONO_SIZE = 58
local BASE_AIGUILLE_W = 10.5
local BASE_AIGUILLE_H = 7.5 
local MIN_ROTATION = -140       
local MAX_ROTATION = 150      

local GIF_SCALE = 0.8
local GIF_BASE_WIDTH = (1100 / 5) * GIF_SCALE
local GIF_BASE_HEIGHT = (3100 / 25) * GIF_SCALE

local C_BLANC = Color3.fromRGB(255, 255, 255)
local C_JAUNE = Color3.fromRGB(255, 230, 0)
local C_ORANGE = Color3.fromRGB(255, 130, 0)
local C_ROUGE = Color3.fromRGB(255, 20, 0)
local C_ROUGE_FONCE = Color3.fromRGB(255, 0, 0)
local C_DEPENSE = Color3.fromRGB(255, 60, 60)

local currentArgent = nil
local rollTicket = 0

-- Détermine la couleur de l'interface en fonction de l'intensité du combo
local function getComboColor(intensity)
	if intensity <= 0.33 then
		local alpha = intensity / 0.33
		return C_BLANC:Lerp(C_JAUNE, alpha)
	elseif intensity <= 0.66 then
		local alpha = (intensity - 0.33) / 0.33
		return C_JAUNE:Lerp(C_ORANGE, alpha)
	else
		local alpha = (intensity - 0.66) / 0.34
		return C_ORANGE:Lerp(C_ROUGE, alpha)
	end
end

-- FONCTION VOICELINE ALÉATOIRE BOOST
-- Joue un effet vocal au hasard lorsque le mode Fever s'active
local function playRandomBoostVoice()
	local boostFolder = replicatedStorage_folder_voiceslines:FindFirstChild("Boost")

	if boostFolder then
		local sounds = boostFolder:GetChildren()

		if #sounds > 0 then
			local randomSound = sounds[math.random(1, #sounds)]
			local soundClone = randomSound:Clone()
			soundClone.Parent = SoundService
			soundClone:Play()

			soundClone.Ended:Connect(function()
				soundClone:Destroy()
			end)
		end
	end
end

-- 1. STRUCTURE DE L'ARGENT TOTAL (À GAUCHE)
local finalPosition = UDim2.new(0, 30, 0.5, 0)
local startPosition = UDim2.new(0, -600, 0.5, 0) 

local argent3DFrame = Instance.new("CanvasGroup")
argent3DFrame.Name = "Argent3DFrame"
argent3DFrame.Size = UDim2.new(0, 400, 0, 150)
argent3DFrame.Position = startPosition
argent3DFrame.AnchorPoint = Vector2.new(0, 0.5)
argent3DFrame.BackgroundTransparency = 1
argent3DFrame.GroupTransparency = 1 
argent3DFrame.Visible = false
argent3DFrame.Parent = screenGui

-- Fait glisser l'interface à l'écran après la cinématique d'intro
local function animateMoneyIn()
	argent3DFrame.Visible = true
	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(argent3DFrame, tweenInfo, {
		Position = finalPosition,
		GroupTransparency = 0
	}):Play()
end

if player:GetAttribute("CinematicFinished") then
	argent3DFrame.Position = finalPosition
	argent3DFrame.GroupTransparency = 0
	argent3DFrame.Visible = true
else
	player:GetAttributeChangedSignal("CinematicFinished"):Connect(function()
		if player:GetAttribute("CinematicFinished") == true then
			animateMoneyIn()
		end
	end)
end

local chronoImg = Instance.new("ImageLabel")
chronoImg.Name = "ChronoImage"
chronoImg.Image = "rbxassetid://98819016420153"
chronoImg.BackgroundTransparency = 1
chronoImg.Size = UDim2.new(0, BASE_CHRONO_SIZE, 0, BASE_CHRONO_SIZE)
chronoImg.AnchorPoint = Vector2.new(0, 0.5)
chronoImg.Position = UDim2.new(0, 0, 0.5, 0)
chronoImg.ImageTransparency = 1
chronoImg.ZIndex = 2 
chronoImg.Parent = argent3DFrame

-- Reparentage du GIF à l'intérieur du chrono pour la structure visuelle
phonk_gif.Parent = chronoImg
phonk_gif.AnchorPoint = Vector2.new(0.5, 0.5)
phonk_gif.Position = UDim2.new(0.5, 0, 0.5, -45) 
phonk_gif.BackgroundTransparency = 1
phonk_gif.ZIndex = 1 
phonk_gif.ImageTransparency = 1 
phonk_gif.Image = "rbxassetid://83606041914902"

local aiguilleImg = Instance.new("ImageLabel")
aiguilleImg.Name = "AiguilleImage"
aiguilleImg.Image = "rbxassetid://106940291657759"
aiguilleImg.BackgroundTransparency = 1
aiguilleImg.Size = UDim2.new(0, BASE_AIGUILLE_W, 0, BASE_AIGUILLE_H)
aiguilleImg.Position = UDim2.new(0.5, 0, 0.5, 0)
aiguilleImg.AnchorPoint = Vector2.new(0.5, 0.5)
aiguilleImg.Rotation = MIN_ROTATION
aiguilleImg.ImageTransparency = 1
aiguilleImg.ZIndex = 3
aiguilleImg.Parent = chronoImg

local totalArgentLabel = Instance.new("TextLabel")
totalArgentLabel.Name = "TotalArgentLabel"
totalArgentLabel.Size = UDim2.new(0, 0, 0, 100)
totalArgentLabel.AutomaticSize = Enum.AutomaticSize.X
totalArgentLabel.AnchorPoint = Vector2.new(0, 0.5)
totalArgentLabel.Position = UDim2.new(0, 0, 0.5, 0)
totalArgentLabel.BackgroundTransparency = 1
totalArgentLabel.TextColor3 = C_BLANC
totalArgentLabel.TextSize = BASE_TEXT_SIZE
totalArgentLabel.FontFace = zektonFont
totalArgentLabel.TextXAlignment = Enum.TextXAlignment.Left
totalArgentLabel.Text = "0$"
totalArgentLabel.Parent = argent3DFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Thickness = 2.5
UIStroke.Transparency = 0.4
UIStroke.Color = Color3.new(0, 0, 0)
UIStroke.Parent = totalArgentLabel

local x2Label = Instance.new("TextLabel")
x2Label.Name = "X2Label"
x2Label.Text = "x2"
x2Label.TextColor3 = C_ROUGE_FONCE
x2Label.TextSize = 0 
x2Label.FontFace = zektonFont
x2Label.BackgroundTransparency = 1
x2Label.TextTransparency = 1
x2Label.AnchorPoint = Vector2.new(0.5, 0.5)
x2Label.Position = UDim2.new(0.5, 0, 0.77, 0)
x2Label.Size = UDim2.new(1, 0, 0, 60)
x2Label.TextXAlignment = Enum.TextXAlignment.Center
x2Label.ZIndex = 4
x2Label.Parent = chronoImg

local x2Stroke = Instance.new("UIStroke")
x2Stroke.Thickness = 2
x2Stroke.Transparency = 1
x2Stroke.Color = Color3.new(0, 0, 0)
x2Stroke.Parent = x2Label

-- 2. ANIMATION DU GIF (OPTIMISÉ)
-- Découpe une spritesheet pour animer le GIF
local function SetupGifAnimation()
	local RobloxMaxImageSize = 1024
	local ImageWidth, ImageHeight = 1100, 3100
	local Rows, Columns, NumberOfFrames = 25, 5, 123

	local RealWidth, RealHeight
	if math.max(ImageWidth, ImageHeight) > RobloxMaxImageSize then
		local Longest = ImageWidth > ImageHeight and "Width" or "Height"
		if Longest == "Width" then
			RealWidth = RobloxMaxImageSize
			RealHeight = (RealWidth / ImageWidth) * ImageHeight
		elseif Longest == "Height" then
			RealHeight = RobloxMaxImageSize
			RealWidth = (RealHeight / ImageHeight) * ImageWidth
		end
	else
		RealWidth, RealHeight = ImageWidth, ImageHeight
	end

	local TextureFrameSize = Vector2.new(RealWidth / Columns, RealHeight / Rows)
	phonk_gif.ImageRectSize = TextureFrameSize

	local Offsets = {}
	local CurrentRow, CurrentColumn = 0, 0
	for i = 1, NumberOfFrames do
		table.insert(Offsets, Vector2.new(CurrentColumn * TextureFrameSize.X, CurrentRow * TextureFrameSize.Y))
		CurrentColumn += 1
		if CurrentColumn >= Columns then
			CurrentColumn = 0
			CurrentRow += 1
		end
	end

	local Index = 0
	task.spawn(function()
		-- Optimisation : Le gif tourne à 30fps au lieu de 60, et uniquement s'il est visible.
		while task.wait(1/30) and phonk_gif:IsDescendantOf(game) do
			if phonk_gif.ImageTransparency < 1 then
				Index += 1
				phonk_gif.ImageRectOffset = Offsets[Index]
				if Index >= NumberOfFrames then Index = 0 end
			end
		end
	end)
end
SetupGifAnimation()

-- 3. INITIALISATION 3D
local GUI3D = Screen3D.new(screenGui, 5)
local Frame3D = GUI3D:GetComponent3D(argent3DFrame)
Frame3D:Enable()
-- Optimisation : L'angle 3D est défini une seule fois.
Frame3D.offset = CFrame.Angles(0, 0.14, 0)

-- 4. LOGIQUE DES ANIMATIONS DE DEPENSE
-- Fait apparaître le texte indiquant la dépense d'argent
local function ShowExpensePopup(montant)
	local expenseLabel = Instance.new("TextLabel")
	expenseLabel.Text = "- " .. montant .. " $"
	expenseLabel.FontFace = zektonFont
	expenseLabel.TextSize = 35 
	expenseLabel.TextColor3 = C_DEPENSE
	expenseLabel.BackgroundTransparency = 1
	expenseLabel.AnchorPoint = Vector2.new(0, 0)
	expenseLabel.TextXAlignment = Enum.TextXAlignment.Left
	expenseLabel.Position = UDim2.new(0, 0, 1, -10) 
	expenseLabel.TextTransparency = 1
	expenseLabel.Parent = totalArgentLabel

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = expenseLabel

	local tweenIn = TweenService:Create(expenseLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 1, 5),
		TextTransparency = 0
	})
	local tweenStrokeIn = TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 0.4})

	tweenIn:Play()
	tweenStrokeIn:Play()

	task.delay(1.3, function()
		if expenseLabel then
			local tweenOut = TweenService:Create(expenseLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0, 0, 1, 25),
				TextTransparency = 1
			})
			local tweenStrokeOut = TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 1})
			tweenOut:Play()
			tweenStrokeOut:Play()
			tweenOut.Completed:Connect(function() expenseLabel:Destroy() end)
		end
	end)
end

-- Simule le défilement rapide des chiffres lors d'une perte d'argent
local function AnimateMoneyLoss(startVal, endVal)
	rollTicket += 1
	local currentTicket = rollTicket
	local duration = 0.5 
	local startTime = os.clock()

	local conn
	conn = RunServ.Heartbeat:Connect(function()
		if rollTicket ~= currentTicket then
			conn:Disconnect()
			return
		end

		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			totalArgentLabel.Text = endVal .. " $"
			conn:Disconnect()
		else
			local progress = elapsed / duration
			local maxPossible = math.max(endVal, math.floor(startVal - (startVal - endVal) * progress))
			local randomVal = math.random(endVal, maxPossible)
			totalArgentLabel.Text = randomVal .. " $"
		end
	end)
end

-- 5. LOGIQUE DU COMBO ET BOUCLE PRINCIPALE (OPTIMISÉE)
RunServ.Heartbeat:Connect(function(dt)
	-- Optimisation : Coupe l'animation si le joueur est inactif
	local isIdle = (not feverActive) and (comboIntensity <= 0) and (punchScale <= 0.01) and (math.abs(visualScale - 1) < 0.01)

	if isIdle then
		if visualScale ~= 1 then
			visualColor = C_BLANC
			visualScale = 1
			visualRotation = MIN_ROTATION
			visualGifAlpha = 0
			visualComboAlpha = 0
			punchScale = 0

			totalArgentLabel.TextColor3 = visualColor
			chronoImg.ImageColor3 = visualColor
			aiguilleImg.ImageColor3 = visualColor
			phonk_gif.ImageColor3 = visualColor

			totalArgentLabel.Position = UDim2.new(0, 0, 0.5, 0)
			chronoImg.ImageTransparency = 1
			aiguilleImg.ImageTransparency = 1
			phonk_gif.ImageTransparency = 1

			totalArgentLabel.TextSize = BASE_TEXT_SIZE
			chronoImg.Size = UDim2.new(0, BASE_CHRONO_SIZE, 0, BASE_CHRONO_SIZE)
			aiguilleImg.Size = UDim2.new(0, BASE_AIGUILLE_W, 0, BASE_AIGUILLE_H)
			phonk_gif.Size = UDim2.new(0, GIF_BASE_WIDTH, 0, GIF_BASE_HEIGHT)
			aiguilleImg.Rotation = MIN_ROTATION
		end

		return 
	end

	-- Logique de progression du mode Fever et du Combo
	local targetColor = C_BLANC
	local targetScale = 1
	local targetRotation = MIN_ROTATION
	local targetGifAlpha = 0
	local targetComboAlpha = 0

	if feverActive then
		feverTimer -= dt
		if feverTimer <= 0 then
			feverActive = false
			comboIntensity = 0 
			TweenService:Create(x2Label, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextSize = 0, TextTransparency = 1}):Play()
			TweenService:Create(x2Stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
		end

		targetColor = C_ROUGE_FONCE
		targetScale = MAX_TEXT_SIZE / BASE_TEXT_SIZE
		targetRotation = MIN_ROTATION + ((MAX_ROTATION - MIN_ROTATION) * (math.max(0, feverTimer) / FEVER_DURATION))
		targetGifAlpha = 1
		targetComboAlpha = 1
	else
		if comboIntensity > 0 then
			comboIntensity = math.max(0, comboIntensity - (dt * 1.5)) 
			targetComboAlpha = 1
		end
		targetColor = getComboColor(comboIntensity)
		targetScale = 1 + ((MAX_TEXT_SIZE / BASE_TEXT_SIZE) - 1) * comboIntensity
		targetRotation = MIN_ROTATION + ((MAX_ROTATION - MIN_ROTATION) * comboIntensity)
		targetGifAlpha = math.clamp((comboIntensity - 0.66) / 0.24, 0, 1)
	end

	local lerpSpeed = 10 * dt
	local alphaLerpSpeed = 5 * dt

	visualColor = visualColor:Lerp(targetColor, lerpSpeed)
	visualScale = visualScale + (targetScale - visualScale) * lerpSpeed
	visualGifAlpha = visualGifAlpha + (targetGifAlpha - visualGifAlpha) * lerpSpeed
	visualComboAlpha = visualComboAlpha + (targetComboAlpha - visualComboAlpha) * alphaLerpSpeed
	punchScale = math.max(0, punchScale - dt * 4) 

	if feverActive then
		visualRotation = targetRotation
	else
		visualRotation = visualRotation + (targetRotation - visualRotation) * lerpSpeed
	end

	totalArgentLabel.TextColor3 = visualColor
	chronoImg.ImageColor3 = visualColor
	aiguilleImg.ImageColor3 = visualColor
	phonk_gif.ImageColor3 = visualColor

	local currentOffset = (BASE_CHRONO_SIZE * visualScale + 15) * visualComboAlpha
	totalArgentLabel.Position = UDim2.new(0, currentOffset, 0.5, 0)

	chronoImg.ImageTransparency = 1 - visualComboAlpha
	aiguilleImg.ImageTransparency = 1 - visualComboAlpha
	phonk_gif.ImageTransparency = 1 - visualGifAlpha

	totalArgentLabel.TextSize = BASE_TEXT_SIZE * (visualScale + punchScale)
	chronoImg.Size = UDim2.new(0, BASE_CHRONO_SIZE * visualScale, 0, BASE_CHRONO_SIZE * visualScale)
	aiguilleImg.Size = UDim2.new(0, BASE_AIGUILLE_W * visualScale, 0, BASE_AIGUILLE_H * visualScale)
	phonk_gif.Size = UDim2.new(0, GIF_BASE_WIDTH * visualScale, 0, GIF_BASE_HEIGHT * visualScale)
	aiguilleImg.Rotation = visualRotation
end)

-- Déclenche les animations en fonction des variations de la variable leaderstats
local function updateDisplay(valeur)
	if currentArgent == nil then
		currentArgent = valeur
		totalArgentLabel.Text = valeur .. " $"
		return
	end

	local difference = valeur - currentArgent

	if difference < 0 then
		if perteArgentSound then
			perteArgentSound:Play()
		end

		local amountLost = math.abs(difference)
		ShowExpensePopup(amountLost)
		AnimateMoneyLoss(currentArgent, valeur)
		punchScale = 0.3 
	elseif difference > 0 then
		totalArgentLabel.Text = valeur .. " $"
		rollTicket += 1 

		if not feverActive then
			comboIntensity = math.min(1, comboIntensity + 0.24)

			if comboIntensity >= 1 then
				feverActive = true
				feverTimer = FEVER_DURATION
				ActiverFeverEvent:FireServer() 

				if boostSound then boostSound:Play() end
				playRandomBoostVoice()

				TweenService:Create(x2Label, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
				TweenService:Create(x2Stroke, TweenInfo.new(0.4), {Transparency = 0.4}):Play()
			end
		end
		punchScale = 0.3 
	end

	currentArgent = valeur
end

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	if leaderstats then
		local argent = leaderstats:WaitForChild("Argent")
		if argent then
			updateDisplay(argent.Value)
			argent.Changed:Connect(updateDisplay)
		end
	end
end)

-- 6. LOGIQUE DES POP-UPS "+X"
-- Fait apparaître des petits textes de gain d'argent flottants
AfficherGainEvent.OnClientEvent:Connect(function(montant)
	local popLabel = Instance.new("TextLabel")
	popLabel.Text = "+" .. montant .. " $"
	popLabel.FontFace = zektonFont
	popLabel.TextSize = 28
	popLabel.TextColor3 = visualColor 
	popLabel.BackgroundTransparency = 1
	popLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	popLabel.ZIndex = 10

	local xBase, yBase = 0.53, 0.5
	local randomOffset = UDim2.new(xBase + (math.random(-2, 2)/100), 0, yBase + (math.random(-6, 6)/100), 0)

	popLabel.Position = randomOffset
	popLabel.Parent = screenGui

	local tween = TweenService:Create(popLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		Position = randomOffset - UDim2.new(0, 0, 0.04, 0)
	})
	task.wait(0.1) 
	tween:Play()
	tween.Completed:Connect(function() popLabel:Destroy() end)
end)