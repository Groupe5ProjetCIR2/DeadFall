-- ============================================================
--  Ce script remplace l'affichage par défaut des ProximityPrompts
--  par une interface 2D personnalisée qui suit l'objet en 3D. 
--  Il met à jour dynamiquement le texte selon le contexte du jeu 
--  (courant électrique, niveaux d'amélioration, atouts, munitions).
-- ============================================================

local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("UpgradesConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UniversalPromptGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Instancie les éléments visuels de l'interface personnalisée et retourne leurs références
local function createUI()
	local container = Instance.new("Frame")
	container.Name = "CustomPromptContainer"
	container.Size = UDim2.new(0, 180, 0, 50)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = screenGui

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 0, 4)
	background.Position = UDim2.new(0, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	background.BackgroundTransparency = 0.5
	background.BorderSizePixel = 0
	background.Visible = false
	background.Parent = container

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 170, 0) 
	fill.BorderSizePixel = 0
	fill.Parent = background

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "ActionLabel"
	actionLabel.Size = UDim2.new(1, 0, 0.4, 0)
	actionLabel.Position = UDim2.new(0, 0, 0, 0)
	actionLabel.BackgroundTransparency = 1
	actionLabel.Font = Enum.Font.Michroma
	actionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionLabel.TextSize = 14
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.Parent = container

	local objectLabel = Instance.new("TextLabel")
	objectLabel.Name = "ObjectLabel"
	objectLabel.Size = UDim2.new(1, 0, 0.6, 0)
	objectLabel.Position = UDim2.new(0, 0, 0.4, 0)
	objectLabel.BackgroundTransparency = 1
	objectLabel.Font = Enum.Font.Michroma
	objectLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
	objectLabel.TextSize = 18
	objectLabel.TextXAlignment = Enum.TextXAlignment.Left
	objectLabel.Parent = container

	local keyHint = Instance.new("TextLabel")
	keyHint.Name = "KeyHint"
	keyHint.Size = UDim2.new(0, 30, 0, 30)
	keyHint.Position = UDim2.new(-0.25, 0, 0.1, 0)
	keyHint.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	keyHint.TextColor3 = Color3.fromRGB(0, 0, 0)
	keyHint.Font = Enum.Font.Michroma
	keyHint.TextSize = 14
	keyHint.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = keyHint

	return container, background, fill, actionLabel, objectLabel, keyHint
end

local container, background, fill, actionLabel, objectLabel, keyHint = createUI()
local currentPrompt = nil

-- Boucle de rendu frame-par-frame pour projeter la position 3D en 2D sur l'écran et actualiser les textes conditionnels
RunService.RenderStepped:Connect(function()
	if currentPrompt then
		local worldPos = currentPrompt.Parent.Position
		local screenPos, onScreen = workspace.CurrentCamera:WorldToScreenPoint(worldPos)

		if onScreen then
			container.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y - 50)
			container.Visible = true

			local actionText = currentPrompt.ActionText
			local objectText = currentPrompt.ObjectText

			local machineModel = currentPrompt:FindFirstAncestorWhichIsA("Model")

			-- Logique conditionnelle modifiant l'affichage selon le courant, le type d'arme ou l'état des atouts
			if machineModel and machineModel:GetAttribute("PowerOn") == false then
				actionText = "REQUIRES POWER"
				objectText = "TURN ON ELECTRICITY"
				objectLabel.TextColor3 = Color3.fromRGB(255, 50, 50) 
			else
				objectLabel.TextColor3 = Color3.fromRGB(255, 170, 0) 

				local character = player.Character
				local weapon = character and character:FindFirstChildOfClass("Tool")

				if weapon and weapon:FindFirstChild("Setting") then
					local level = 1
					local typeStr = ""
					local priceCategory = ""

					if string.find(actionText:lower(), "damage") then
						level = weapon:GetAttribute("DamageLevel") or 1
						typeStr = "Damage"
						priceCategory = "Damage"
					elseif string.find(actionText:lower(), "penetration") then
						level = weapon:GetAttribute("PenetrationLevel") or 1
						typeStr = "Penetration"
						priceCategory = "Penetration"
					elseif string.find(actionText:lower(), "capacity") then
						level = weapon:GetAttribute("ChargeurLevel") or 1
						typeStr = "Capacity"
						priceCategory = "Magazine"
					end

					if level >= 5 then
						actionText = "MAX " .. typeStr:upper() .. " REACHED"
						objectText = "FULLY UPGRADED"
					elseif priceCategory ~= "" then
						local nextPrice = Config.Prices[priceCategory][level + 1]
						objectText = tostring(nextPrice) .. " $"
					end
				end

				local gumName = currentPrompt:GetAttribute("GumName")
				if gumName then
					if player:GetAttribute(gumName) == true then
						actionText = "ALREADY OWNED"
						objectText = "SOLD OUT"
					end
				end
			end

			actionLabel.Text = string.upper(actionText)
			objectLabel.Text = objectText
		else
			container.Visible = false
		end
	end
end)

-- Intercepte l'affichage natif du Prompt pour le remplacer par l'UI personnalisée
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Style == Enum.ProximityPromptStyle.Custom then
		currentPrompt = prompt
		keyHint.Text = prompt.KeyboardKeyCode.Name

		if prompt.HoldDuration > 0 then
			background.Visible = true
			fill.Size = UDim2.new(0, 0, 1, 0)

			if prompt.ActionText == "Lancer la roue" then
				fill.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
			else
				fill.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
			end
		else
			background.Visible = false
		end

		container.Visible = true
	end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	if prompt == currentPrompt then
		container.Visible = false
		currentPrompt = nil
	end
end)

-- Déclenche l'animation de la barre de progression (fill) et un léger agrandissement lors de la touche maintenue
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	if prompt == currentPrompt then
		if prompt.HoldDuration > 0 then
			TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
				Size = UDim2.new(1, 0, 1, 0)
			}):Play()
		end

		TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(0, 190, 0, 55)}):Play()
	end
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	if prompt == currentPrompt then
		if prompt.HoldDuration > 0 then
			TweenService:Create(fill, TweenInfo.new(0.2), {Size = UDim2.new(0, 0, 1, 0)}):Play()
		end

		TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(0, 180, 0, 50)}):Play()
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt == currentPrompt then
		if prompt.HoldDuration > 0 then
			fill.Size = UDim2.new(0, 0, 1, 0)
		end
	end
end)

local activeWallPrompts = {}

ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Parent and prompt.Parent:GetAttribute("WeaponName") then
		activeWallPrompts[prompt] = true
	end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	activeWallPrompts[prompt] = nil
end)

-- Scrute dynamiquement l'arme en main pour basculer l'action des armes murales entre "Buy" et "Refill"
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local equippedWeapon = character and character:FindFirstChildOfClass("Tool")

	for prompt in pairs(activeWallPrompts) do
		if prompt.Enabled then
			local weaponName = prompt.Parent:GetAttribute("WeaponName")

			if equippedWeapon and equippedWeapon.Name == weaponName then
				prompt.ActionText = "Refill Ammo"
			else
				prompt.ActionText = "Buy " .. tostring(weaponName)
			end
		end
	end
end)