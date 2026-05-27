-- ============================================================
-- Ce script gère l'inventaire personnalisé du joueur (le HUD).
-- Il affiche jusqu'à 3 emplacements : deux pour les armes classiques 
-- et un 3ème slot spécial pour la Seringue (Medic-Mix) qui intègre 
-- un système d'achat, d'équipement rapide et un temps de recharge.
-- Le "Gum" est intentionnellement exclu de ce HUD.
-- ============================================================

local zektonFont = Font.new("rbxasset://fonts/families/Zekton.json")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CustomInventoryGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Dimensions standards
local width, height = 240, 91
local marginSide, marginBottom = 50, 50
local spacing = 5

-- Dimensions et positions du Slot 3 (Seringue) -> Encore plus petit (55%) et au-dessus
local slot3Width, slot3Height = width * 0.85, height * 0.85

-- Position : un peu plus vers la droite et encore plus haut
local slot3X = (width + spacing) + (width - slot3Width) / 2 + 25
local slot3Y = -slot3Height - spacing - 100 

local images = {
	leftNormal = "rbxassetid://133271604706657",
	leftSelected = "rbxassetid://121485751280972",
	rightNormal = "rbxassetid://135117726301123",
	rightSelected = "rbxassetid://108625671112976"
}

local customIcons = {
	["AK-207"] = "rbxassetid://125721882862803",
	["Desert Eagle 2"] = "rbxassetid://125265396705724",
	["Galax-4"] = "rbxassetid://90050176459665",
	["Seringue"] = "rbxassetid://135903612037151",
	["FAMAS-3"] = "rbxassetid://127678184438441",
	["ShotRun"] = "rbxassetid://72973622240777",
	["P-240"] = "rbxassetid://129204293316318",
	["DF-1008"] = "rbxassetid://100246987485045",
	["GT-505"] = "rbxassetid://97306265276468",
	["Snizer"] = "rbxassetid://85383001155607"
}

local slot1Tool = nil
local slot2Tool = nil
local slot3Tool = nil

local slotRefs = {}
local iconRefs = {}
local keybindRefs = {} -- Nouveau : stocker les références aux conteneurs de touches

-- Variables pour le Cooldown & L'équipement
local isSyringeOnCooldown = false
local syringeIsCurrentlyEquipped = false
local lastEquippedTool = nil 
local cooldownDuration = 60
local cooldownEndTime = 0

-- ==========================================
-- ANIMATION D'APPARITION DU HUD
-- ==========================================
local finalPosition = UDim2.new(1, -((width * 2) + spacing + marginSide), 1, -(height + marginBottom))
local startPosition = UDim2.new(1, -((width * 2) + spacing + marginSide) + 800, 1, -(height + marginBottom))

-- On utilise une Frame classique qu'on fait glisser depuis l'extérieur de l'écran 
-- à la fin de la cinématique d'intro.
local mainFrame = Instance.new("Frame")
mainFrame.Name = "InventoryContainer"
mainFrame.Size = UDim2.new(0, (width * 2) + spacing, 0, height)
mainFrame.Position = startPosition 
mainFrame.BackgroundTransparency = 1
mainFrame.Visible = false
mainFrame.Parent = screenGui

local function animateInventoryIn()
	mainFrame.Visible = true
	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(mainFrame, tweenInfo, {
		Position = finalPosition
	}):Play()
end

-- Détection de la fin du chargement
if player:GetAttribute("CinematicFinished") then
	mainFrame.Position = finalPosition
	mainFrame.Visible = true
else
	player:GetAttributeChangedSignal("CinematicFinished"):Connect(function()
		if player:GetAttribute("CinematicFinished") == true then
			animateInventoryIn()
		end
	end)
end
-- ==========================================

local weaponNameLabel = Instance.new("TextLabel")
weaponNameLabel.Name = "WeaponName"
weaponNameLabel.Size = UDim2.new(0, width, 0, 30)
weaponNameLabel.BackgroundTransparency = 1
weaponNameLabel.Text = ""
weaponNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
weaponNameLabel.TextStrokeTransparency = 0.5
weaponNameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
weaponNameLabel.Font = Enum.Font.Michroma
weaponNameLabel.TextSize = 24
weaponNameLabel.TextTransparency = 1
weaponNameLabel.RichText = true
weaponNameLabel.Parent = screenGui

local bounceSelectTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
local deselectTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local fadeInTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local fadeOutTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local fastTransTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local slowTransTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local colorTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local glowTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 1, true)
local errorBlinkTweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 3, true)
local fluidCooldownTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) 

local currentNameTween = nil
local equipCounter = 0
local magConnections = {}
local lastColorState = {}

local function applyColorFade(guiObject, property, targetColor)
	if not guiObject then return end
	if lastColorState[guiObject] ~= targetColor then
		lastColorState[guiObject] = targetColor
		TweenService:Create(guiObject, colorTweenInfo, {[property] = targetColor}):Play()
	end
end

-- Détermine la couleur de l'icône et du texte en fonction de l'arme 
-- ou de ses munitions restantes (ex: devient rouge si le chargeur est vide)
local function getWeaponColor(tool)
	if not tool then return Color3.fromRGB(255, 255, 255) end

	local magValue = nil
	local valueFolder = tool:FindFirstChild("ValueFolder")
	if valueFolder then
		local modeFolder = valueFolder:FindFirstChild("1")
		if modeFolder then
			local mag = modeFolder:FindFirstChild("Mag")
			if mag then magValue = mag.Value end
		end
	end

	if magValue then
		if magValue <= 0 then return Color3.fromRGB(255, 0, 0)
		elseif magValue == 1 then return Color3.fromRGB(255, 65, 0)
		elseif magValue == 2 then return Color3.fromRGB(255, 130, 0)
		elseif magValue == 3 then return Color3.fromRGB(255, 185, 0)
		end
	end

	if tool.Name == "AK-207" then return Color3.fromRGB(35, 132, 24)
	elseif tool.Name == "Galax-4" then return Color3.fromRGB(84, 144, 223)
	elseif tool.Name == "FAMAS-3" then return Color3.fromRGB(35, 132, 24)
	elseif tool.Name == "GT-505" then return Color3.fromRGB(35, 132, 24)
	elseif tool.Name == "DF-1008" then return Color3.fromRGB(234, 73, 255)
	end

	return Color3.fromRGB(255, 255, 255)
end

local function refreshColors()
	applyColorFade(slotRefs["Slot1"], "ImageColor3", getWeaponColor(slot1Tool))
	applyColorFade(slotRefs["Slot2"], "ImageColor3", getWeaponColor(slot2Tool))

	if not isSyringeOnCooldown then
		applyColorFade(slotRefs["Slot3"], "ImageColor3", getWeaponColor(slot3Tool))
	end

	local character = player.Character
	local equippedTool = character and character:FindFirstChildOfClass("Tool")

	if equippedTool and (equippedTool == slot1Tool or equippedTool == slot2Tool) then
		applyColorFade(weaponNameLabel, "TextColor3", getWeaponColor(equippedTool))
	elseif equippedTool and equippedTool == slot3Tool and not isSyringeOnCooldown then
		applyColorFade(weaponNameLabel, "TextColor3", getWeaponColor(equippedTool))
	end
end

-- Connecte le HUD aux munitions de l'arme pour mettre à jour les couleurs en temps réel lors des tirs
local function hookToolAmmo(tool, slotName)
	if magConnections[slotName] then
		magConnections[slotName]:Disconnect()
		magConnections[slotName] = nil
	end
	if tool then
		local valueFolder = tool:FindFirstChild("ValueFolder")
		if valueFolder then
			local modeFolder = valueFolder:FindFirstChild("1")
			if modeFolder then
				local mag = modeFolder:FindFirstChild("Mag")
				if mag then
					magConnections[slotName] = mag.Changed:Connect(refreshColors)
				end
			end
		end
	end
end

local function createSlot(name, xOffset, yOffset, sWidth, sHeight, defaultImage)
	local btn = Instance.new("ImageButton")
	btn.Name = name
	btn.Image = defaultImage
	btn.Size = UDim2.new(0, sWidth, 0, sHeight)
	btn.Position = UDim2.new(0, xOffset, 0, yOffset)
	btn.ImageTransparency = 0.45 
	btn.BackgroundTransparency = 1
	btn.ScaleType = Enum.ScaleType.Stretch
	btn.Visible = false
	btn.Parent = mainFrame

	slotRefs[name] = btn

	local icon = Instance.new("ImageLabel")
	icon.Name = "WeaponIcon"
	icon.Size = UDim2.new(0.8, 0, 0.8, 0)
	icon.Position = UDim2.new(0.1, 0, 0.1, 0)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Visible = false
	icon.ImageTransparency = 0.45 
	icon.Parent = btn

	iconRefs[name] = icon

	return btn
end

local slot1 = createSlot("Slot1", 0, 0, width, height, images.leftNormal)
local slot2 = createSlot("Slot2", width + spacing, 0, width, height, images.rightNormal)
local slot3 = createSlot("Slot3", slot3X, slot3Y, slot3Width, slot3Height, images.rightNormal)

-- ==========================================
-- NOUVEAU : INDICATEURS DE TOUCHES (Style uniforme)
-- ==========================================
local function createKeybindLabel(parentSlot, keyText, keyCode, isLeft)
	local container = Instance.new("Frame")
	container.Name = "KeybindContainer"
	-- Si isLeft est vrai, on positionne à gauche, sinon par défaut (en dessous)
	if isLeft then
		container.Size = UDim2.new(0, 40, 1, 0)
		container.Position = UDim2.new(-0.25, 0, 0, 0)
	else
		container.Size = UDim2.new(1, 0, 0, 24)
		container.Position = UDim2.new(0.5, 0, 1, 8)
		container.AnchorPoint = Vector2.new(0.5, 0)
	end
	container.BackgroundTransparency = 1
	container.Parent = parentSlot

	local keyBox = Instance.new("Frame")
	keyBox.Name = "KeyBox"
	keyBox.Size = UDim2.new(0, 36, 0, 24)
	keyBox.Position = UDim2.new(0.5, 0, 0.5, 0)
	keyBox.AnchorPoint = Vector2.new(0.5, 0.5)
	keyBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	keyBox.BorderSizePixel = 0
	keyBox.BackgroundTransparency = 0.5
	keyBox.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = keyBox

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyLabel"
	keyLabel.Size = UDim2.new(1, 0, 1, 0)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Font = Enum.Font.Michroma
	keyLabel.Text = string.upper(keyText)
	keyLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	keyLabel.TextSize = 12
	keyLabel.Parent = keyBox

	-- Animation de pression
	local function updateVisual(pressed)
		local targetColor = pressed and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(255, 255, 255)
		local targetTextColor = pressed and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)

		TweenService:Create(keyBox, TweenInfo.new(0.08), {BackgroundColor3 = targetColor}):Play()
		TweenService:Create(keyLabel, TweenInfo.new(0.08), {TextColor3 = targetTextColor}):Play()
	end

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == keyCode then updateVisual(true) end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == keyCode then updateVisual(false) end
	end)

	return container -- Retourner le container pour pouvoir le contrôler plus tard
end

-- On applique les touches :
-- Les slots 1 et 2 en dessous (isLeft = false)
-- Le slot 3 (Seringue) à gauche (isLeft = true)
createKeybindLabel(slot1, "1", Enum.KeyCode.One, false)
createKeybindLabel(slot2, "2", Enum.KeyCode.Two, false)
keybindRefs["Slot3"] = createKeybindLabel(slot3, "3", Enum.KeyCode.Three, true) -- Stocker la référence

-- ==========================================
-- FONCTIONS POUR LE FONDU DE LA TOUCHE 3
-- ==========================================
local function fadeOutKey3()
	if keybindRefs["Slot3"] then
		-- Fondu fluide vers la transparence totale
		TweenService:Create(keybindRefs["Slot3"], TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1
		}):Play()

		-- Chercher et animer tous les enfants
		for _, child in ipairs(keybindRefs["Slot3"]:GetDescendants()) do
			if child:IsA("Frame") then
				TweenService:Create(child, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 1
				}):Play()
			elseif child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 1
				}):Play()
			end
		end
	end
end

local function fadeInKey3()
	if keybindRefs["Slot3"] then
		-- Fondu fluide vers la transparence normale
		TweenService:Create(keybindRefs["Slot3"], TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1
		}):Play()

		-- Chercher et animer tous les enfants
		for _, child in ipairs(keybindRefs["Slot3"]:GetDescendants()) do
			if child:IsA("Frame") and child.Name == "KeyBox" then
				TweenService:Create(child, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0.5
				}):Play()
			elseif child:IsA("TextLabel") and child.Name == "KeyLabel" then
				TweenService:Create(child, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 0
				}):Play()
			end
		end
	end
end

-- ==========================================
-- PARAMÉTRAGE DU SLOT 3 (Lié au Medic-Mix)
-- ==========================================
-- Ce slot est visible uniquement si le joueur possède l'atout MedicMix.
local hasMedicMix = player:GetAttribute("MedicMix") == true
slot3.Visible = hasMedicMix

iconRefs["Slot3"].Image = customIcons["Seringue"]
iconRefs["Slot3"].Visible = hasMedicMix

local priceLabel = Instance.new("TextLabel")
priceLabel.Name = "PriceLabel"
priceLabel.Size = UDim2.new(0, 100, 0, 30)
priceLabel.Position = UDim2.new(0, -110, 0.5, -15) 
priceLabel.BackgroundTransparency = 1
priceLabel.FontFace = zektonFont
priceLabel.Text = ""
priceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
priceLabel.TextTransparency = 0.45
priceLabel.TextStrokeTransparency = 0.5
priceLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
priceLabel.TextSize = 22
priceLabel.TextXAlignment = Enum.TextXAlignment.Right
priceLabel.Parent = slot3


local function animateSlot(slot, isSelected)
	local targetSize
	local targetPosition

	local baseW, baseH, baseX, baseY = width, height, 0, 0
	if slot.Name == "Slot1" then
		baseX, baseY = 0, 0
	elseif slot.Name == "Slot2" then
		baseX, baseY = width + spacing, 0
	elseif slot.Name == "Slot3" then
		baseW, baseH, baseX, baseY = slot3Width, slot3Height, slot3X, slot3Y
	end

	if isSelected then
		targetSize = UDim2.new(0, baseW * 1.1, 0, baseH * 1.1)
		targetPosition = UDim2.new(0, baseX - (baseW * 0.05), 0, baseY - (baseH * 0.05))
	else
		targetSize = UDim2.new(0, baseW, 0, baseH)
		targetPosition = UDim2.new(0, baseX, 0, baseY)
	end

	local activeTweenInfo = isSelected and bounceSelectTweenInfo or deselectTweenInfo
	TweenService:Create(slot, activeTweenInfo, {Size = targetSize, Position = targetPosition}):Play()
end

local function animateWeaponImage(slotName, isSelected)
	local icon = iconRefs[slotName]
	if not icon then return end

	local targetSize
	local targetPosition

	if isSelected then
		if slotName == "Slot1" then
			targetSize = UDim2.new(1.2, 0, 1.2, 0)
			targetPosition = UDim2.new(-0.1, 0, -0.35, 0)
		elseif slotName == "Slot2" then
			targetSize = UDim2.new(1.04, 0, 1.04, 0)
			targetPosition = UDim2.new(-0.02, 0, -0.25, 0)
		elseif slotName == "Slot3" then
			targetSize = UDim2.new(1.1, 0, 1.1, 0)
			targetPosition = UDim2.new(-0.05, 0, -0.05, 0)
		end
	else
		targetSize = UDim2.new(0.8, 0, 0.8, 0)
		targetPosition = UDim2.new(0.1, 0, 0.1, 0)
	end

	local activeTweenInfo = isSelected and bounceSelectTweenInfo or deselectTweenInfo
	TweenService:Create(icon, activeTweenInfo, {Size = targetSize, Position = targetPosition}):Play()
end

local function applyTransparency(slotName, isSelected, isDelayed)
	if slotName == "Slot3" and isSyringeOnCooldown then return end 

	local targetAlpha
	if isSelected then
		targetAlpha = isDelayed and 0.45 or 0.1 
	else
		targetAlpha = isDelayed and 0.65 or 0.45
	end

	local tInfo = isDelayed and slowTransTweenInfo or fastTransTweenInfo

	if slotRefs[slotName] then TweenService:Create(slotRefs[slotName], tInfo, {ImageTransparency = targetAlpha}):Play() end
	if iconRefs[slotName] then TweenService:Create(iconRefs[slotName], tInfo, {ImageTransparency = targetAlpha}):Play() end

	if isSelected then
		TweenService:Create(weaponNameLabel, tInfo, {
			TextTransparency = targetAlpha,
			TextStrokeTransparency = math.min(1, targetAlpha + 0.3)
		}):Play()
	end
end

local function showWeaponName(tool, slotName)
	if currentNameTween then currentNameTween:Cancel() end

	if not tool or tool.Name == "Seringue" then
		local fadeOut = TweenService:Create(weaponNameLabel, fadeOutTweenInfo, {TextTransparency = 1, TextStrokeTransparency = 1})
		fadeOut:Play()
		currentNameTween = fadeOut
		return
	end

	applyColorFade(weaponNameLabel, "TextColor3", getWeaponColor(tool))
	weaponNameLabel.Text = "<b>" .. tool.Name .. "</b>"

	if slotName == "Slot1" then
		weaponNameLabel.Position = UDim2.new(1, -((width * 2) + spacing + marginSide), 1, -(height + marginBottom + 50))
	elseif slotName == "Slot2" then
		weaponNameLabel.Position = UDim2.new(1, -(width + marginSide), 1, -(height + marginBottom + 50))
	elseif slotName == "Slot3" then
		weaponNameLabel.Position = UDim2.new(1, -(width + marginSide), 1, -(height + slot3Height + marginBottom + 50))
	end

	local fadeIn = TweenService:Create(weaponNameLabel, fadeInTweenInfo, {TextTransparency = 0.2, TextStrokeTransparency = 0.5})
	fadeIn:Play()
	currentNameTween = fadeIn
end

local startSyringeCooldown

local function playSyringeTakeAnimation()
	priceLabel.Text = ""
	local glowIn = TweenService:Create(priceLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextStrokeTransparency = 0,
		TextColor3 = Color3.fromRGB(255, 255, 255)
	})
	local fadeOut = TweenService:Create(priceLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1
	})
	glowIn:Play()
	task.delay(0.15, function()
		if syringeIsCurrentlyEquipped and not isSyringeOnCooldown then
			fadeOut:Play()
		end
	end)
end

local function updateSlotAppearance()
	local character = player.Character
	local equippedTool = character and character:FindFirstChildOfClass("Tool") or nil

	equipCounter = equipCounter + 1
	local currentEquip = equipCounter

	if equippedTool ~= lastEquippedTool then
		lastEquippedTool = equippedTool
		if equippedTool and equippedTool.Name == "Seringue" then
			syringeIsCurrentlyEquipped = true
			playSyringeTakeAnimation()
		elseif syringeIsCurrentlyEquipped and (not equippedTool or equippedTool.Name ~= "Seringue") then
			syringeIsCurrentlyEquipped = false
			startSyringeCooldown()
		end
	end

	local function setSlotActive(activeSlotNum)
		for i = 1, 3 do
			local sName = "Slot" .. i
			local isSelected = (i == activeSlotNum)

			if i == 1 then 
				slotRefs[sName].Image = isSelected and images.leftSelected or images.leftNormal
			else 
				slotRefs[sName].Image = isSelected and images.rightSelected or images.rightNormal 
			end

			animateSlot(slotRefs[sName], isSelected)
			animateWeaponImage(sName, isSelected)

			if i == 3 then
				if isSyringeOnCooldown then
					slotRefs[sName].Image = images.rightNormal
					TweenService:Create(slotRefs[sName], fluidCooldownTweenInfo, {
						ImageColor3 = Color3.fromRGB(40, 40, 40), 
						ImageTransparency = 0.7
					}):Play()
					TweenService:Create(iconRefs[sName], fluidCooldownTweenInfo, {
						ImageColor3 = Color3.fromRGB(40, 40, 40),
						ImageTransparency = 0.7
					}):Play()
					TweenService:Create(priceLabel, fluidCooldownTweenInfo, {
						TextColor3 = Color3.fromRGB(150, 150, 150),
						TextTransparency = 0.3,
						TextStrokeTransparency = 0.5
					}):Play()
				else
					TweenService:Create(slotRefs[sName], fastTransTweenInfo, {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
					TweenService:Create(iconRefs[sName], fastTransTweenInfo, {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
					if not syringeIsCurrentlyEquipped then 
						priceLabel.Text = ""
						TweenService:Create(priceLabel, fastTransTweenInfo, {
							TextColor3 = Color3.fromRGB(255, 255, 255),
							TextTransparency = 0.45,
							TextStrokeTransparency = 0.5
						}):Play()
					end
					applyTransparency(sName, isSelected, false)
				end
			else
				applyTransparency(sName, isSelected, false)
			end
		end

		task.delay(1.5, function()
			if currentEquip == equipCounter then
				for i = 1, 3 do
					if i == 3 and isSyringeOnCooldown then
						TweenService:Create(slotRefs["Slot3"], slowTransTweenInfo, {ImageTransparency = 0.7}):Play()
						TweenService:Create(iconRefs["Slot3"], slowTransTweenInfo, {ImageTransparency = 0.7}):Play()
					else
						applyTransparency("Slot"..i, (i == activeSlotNum), true)
					end
				end
			end
		end)
	end

	if equippedTool and equippedTool == slot1Tool then
		setSlotActive(1)
		showWeaponName(slot1Tool, "Slot1")
	elseif equippedTool and equippedTool == slot2Tool then
		setSlotActive(2)
		showWeaponName(slot2Tool, "Slot2")
	elseif equippedTool and equippedTool == slot3Tool then
		setSlotActive(3)
		showWeaponName(slot3Tool, "Slot3")
	else
		setSlotActive(0)
		showWeaponName(nil, nil)
	end

	refreshColors()
end

local function equipTool(tool)
	if not tool then return end
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if tool.Parent ~= character then
		humanoid:EquipTool(tool)
		updateSlotAppearance()
	end
end

local function playGlowAnimation()
	slotRefs["Slot3"].ImageColor3 = Color3.fromRGB(255, 255, 255)
	iconRefs["Slot3"].ImageColor3 = Color3.fromRGB(255, 255, 255)
	priceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

	local glowSlot = TweenService:Create(slotRefs["Slot3"], glowTweenInfo, {ImageTransparency = 0})
	local glowIcon = TweenService:Create(iconRefs["Slot3"], glowTweenInfo, {ImageTransparency = 0})
	local glowText = TweenService:Create(priceLabel, glowTweenInfo, {TextTransparency = 0, TextStrokeTransparency = 0})

	glowSlot:Play()
	glowIcon:Play()
	glowText:Play()

	glowSlot.Completed:Wait()
	updateSlotAppearance() 
end

local function playErrorBlink()
	local targetColor = Color3.fromRGB(255, 50, 50) 
	local originalColor = Color3.fromRGB(255, 255, 255) 

	local blinkSlot = TweenService:Create(slotRefs["Slot3"], errorBlinkTweenInfo, {ImageColor3 = targetColor})
	local blinkIcon = TweenService:Create(iconRefs["Slot3"], errorBlinkTweenInfo, {ImageColor3 = targetColor})
	local blinkText = TweenService:Create(priceLabel, errorBlinkTweenInfo, {TextColor3 = targetColor})

	blinkSlot:Play()
	blinkIcon:Play()
	blinkText:Play()

	blinkSlot.Completed:Wait()
	slotRefs["Slot3"].ImageColor3 = originalColor
	iconRefs["Slot3"].ImageColor3 = originalColor
	priceLabel.TextColor3 = originalColor
end

-- Lance le compte à rebours de 60 secondes pour la seringue.
-- Pendant ce temps, le bouton devient sombre et affiche le temps restant.
-- La touche 3 disparaît en fondu.
startSyringeCooldown = function()
	if isSyringeOnCooldown then return end
	isSyringeOnCooldown = true
	cooldownEndTime = os.time() + cooldownDuration

	-- Faire disparaître la touche 3 en fondu
	fadeOutKey3()

	updateSlotAppearance()

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not isSyringeOnCooldown then
			connection:Disconnect()
			return
		end

		local timeRemaining = cooldownEndTime - os.time()

		if timeRemaining > 0 then
			local minutes = math.floor(timeRemaining / 60)
			local seconds = timeRemaining % 60
			priceLabel.Text = string.format("%d:%02d", minutes, seconds)
		else
			isSyringeOnCooldown = false
			connection:Disconnect()
			priceLabel.Text = ""

			-- Faire réapparaître la touche 3 en fondu
			fadeInKey3()

			playGlowAnimation()
		end
	end)
end

local isBuying = false 

-- Gère l'appui sur les touches 1, 2 et 3.
-- Pour la touche 3 : équipe la seringue si on l'a déjà, sinon l'achète si on a assez d'argent.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if player:GetAttribute("IsLoading") then return end

	-- ========================================================
	-- MODIFIÉ : VERROUILLAGE DES ARMES SI SERINGUE OU GUM EN MAIN
	-- ========================================================
	local currentCharacter = player.Character
	local currentEquippedTool = currentCharacter and currentCharacter:FindFirstChildOfClass("Tool")

	if currentEquippedTool and (currentEquippedTool.Name == "Seringue" or string.find(currentEquippedTool.Name, "Gum")) then
		-- Le joueur est en train d'utiliser la Seringue ou un Gum.
		-- On bloque complètement tout changement d'arme ou achat en ignorant la touche pressée.
		return
	end
	-- ========================================================

	if input.KeyCode == Enum.KeyCode.One then
		if slot1Tool then equipTool(slot1Tool)
		elseif slot2Tool then equipTool(slot2Tool)
		elseif slot3Tool then equipTool(slot3Tool) end
	elseif input.KeyCode == Enum.KeyCode.Two then
		if slot2Tool then equipTool(slot2Tool) end
	elseif input.KeyCode == Enum.KeyCode.Three then

		if player:GetAttribute("MedicMix") ~= true then return end
		if isSyringeOnCooldown then return end

		local currentBackpack = player:FindFirstChild("Backpack")
		local seringueTrouvee = (currentBackpack and currentBackpack:FindFirstChild("Seringue")) or (currentCharacter and currentCharacter:FindFirstChild("Seringue"))

		if seringueTrouvee then
			equipTool(seringueTrouvee)
		else
			if isBuying then return end 

			local leaderstats = player:FindFirstChild("leaderstats")
			local argent = leaderstats and leaderstats:FindFirstChild("Argent")

			if argent and argent.Value >= 100 then
				isBuying = true 
				local BuyEvent = ReplicatedStorage:FindFirstChild("BuySyringeEvent")
				if BuyEvent then
					BuyEvent:FireServer("Seringue", 100)
				end
				task.delay(0.5, function() isBuying = false end)
			else
				playErrorBlink()
			end
		end
	end
end)

local function updateSlotDisplay(slotName, tool)
	local icon = iconRefs[slotName]
	if not tool then
		icon.Visible = false
		return
	end

	if customIcons[tool.Name] and customIcons[tool.Name] ~= "" then
		icon.Image = customIcons[tool.Name]
		icon.Visible = true
	else
		icon.Image = ""
		icon.Visible = false
	end
end

local updatePending = false

-- Met à jour visuellement les emplacements de l'interface en vérifiant 
-- les objets que le joueur possède réellement dans son inventaire (Backpack) ou en main (Character).
local function performUpdateSlots()
	updatePending = false
	local currentBackpack = player:FindFirstChild("Backpack")
	local character = player.Character
	local toolsInInventory = {}

	if currentBackpack then
		for _, tool in pairs(currentBackpack:GetChildren()) do
			if tool:IsA("Tool") and not string.find(tool.Name, "Gum") then 
				table.insert(toolsInInventory, tool) 
			end
		end
	end
	if character then
		for _, tool in pairs(character:GetChildren()) do
			if tool:IsA("Tool") and not string.find(tool.Name, "Gum") then 
				table.insert(toolsInInventory, tool) 
			end
		end
	end

	local oldSlot1Tool = slot1Tool
	local oldSlot2Tool = slot2Tool
	local oldSlot3Tool = slot3Tool

	slot1Tool = nil
	slot2Tool = nil
	slot3Tool = nil

	for _, tool in ipairs(toolsInInventory) do
		if tool.Name == "Seringue" then
			slot3Tool = tool
			break
		end
	end

	for _, tool in ipairs(toolsInInventory) do
		if tool ~= slot3Tool and string.find(tool.Name, "Desert Eagle") then
			slot2Tool = tool
			break
		end
	end

	for _, tool in ipairs(toolsInInventory) do
		if tool ~= slot3Tool and tool ~= slot2Tool and tool == oldSlot1Tool then
			slot1Tool = tool
			break
		end
	end

	for _, tool in ipairs(toolsInInventory) do
		if tool ~= slot3Tool and tool ~= slot2Tool and tool ~= slot1Tool then
			if not slot1Tool then
				slot1Tool = tool 
			elseif not slot2Tool then
				slot2Tool = tool 
			end
		end
	end

	if slot1Tool ~= oldSlot1Tool then
		hookToolAmmo(slot1Tool, "Slot1")
		if slot1Tool then
			slotRefs["Slot1"].Visible = true
			updateSlotDisplay("Slot1", slot1Tool)
		else
			slotRefs["Slot1"].Visible = false
		end
	end

	if slot2Tool ~= oldSlot2Tool then
		hookToolAmmo(slot2Tool, "Slot2")
		if slot2Tool then
			slotRefs["Slot2"].Visible = true
			updateSlotDisplay("Slot2", slot2Tool)
		else
			slotRefs["Slot2"].Visible = false
		end
	end

	if slot3Tool ~= oldSlot3Tool then
		hookToolAmmo(slot3Tool, "Slot3")
	end

	updateSlotAppearance()
end

local function updateSlots()
	if not updatePending then
		updatePending = true
		task.defer(performUpdateSlots)
	end
end

local eventConnections = {}

local function onCharacterAdded(char)
	for _, conn in ipairs(eventConnections) do
		conn:Disconnect()
	end
	table.clear(eventConnections)

	local currentBackpack = player:WaitForChild("Backpack")

	table.insert(eventConnections, currentBackpack.ChildAdded:Connect(updateSlots))
	table.insert(eventConnections, currentBackpack.ChildRemoved:Connect(updateSlots))
	table.insert(eventConnections, char.ChildAdded:Connect(updateSlots))
	table.insert(eventConnections, char.ChildRemoved:Connect(updateSlots))

	updateSlots()
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

updateSlots()

-- ==========================================
-- ÉCOUTE DE L'ACHAT OU PERTE DU MEDIC-MIX
-- ==========================================
-- Cache ou affiche dynamiquement le Slot 3 si le joueur perd ou gagne l'attribut MedicMix en cours de partie.
player:GetAttributeChangedSignal("MedicMix"):Connect(function()
	local hasMedicMix = player:GetAttribute("MedicMix") == true

	if slotRefs["Slot3"] then slotRefs["Slot3"].Visible = hasMedicMix end
	if iconRefs["Slot3"] then iconRefs["Slot3"].Visible = hasMedicMix end

	if not hasMedicMix then
		local char = player.Character
		if char then
			local currentTool = char:FindFirstChildOfClass("Tool")
			if currentTool and currentTool.Name == "Seringue" then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then hum:UnequipTools() end
			end
		end
	end

	updateSlotAppearance() 
end)