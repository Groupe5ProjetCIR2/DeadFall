-- ============================================================
-- Ce script gère l'interface personnalisée des ProximityPrompts 
-- spécifiquement pour la réparation des barricades (barre de progression au-dessus de l'objet).
-- Il s'occupe également de jouer le son de réparation de manière locale (uniquement pour le joueur concerné).
-- ============================================================

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent

local container = gui:WaitForChild("Container", 10) 
local fill = container and container:WaitForChild("Fill", 10)
local currentPrompt = nil 

local PASTEL_GREEN = Color3.fromRGB(152, 251, 152)
local currentRepairSound = nil

-- Boucle qui s'exécute à chaque image pour "coller" la barre de chargement 2D 
-- exactement au-dessus de la position 3D de la barricade à l'écran.
RunService.RenderStepped:Connect(function()
	if currentPrompt and container and container.Visible then
		local worldPos = currentPrompt.Parent.Position
		local screenPos, onScreen = workspace.CurrentCamera:WorldToScreenPoint(worldPos)
		if onScreen then
			container.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y - 50)
		else
			container.Visible = false
		end
	end
end)

-- S'active quand un joueur s'approche d'une interaction
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.ActionText == "Repair Barricade" or prompt.ActionText == "Réparer Barricade" or prompt.ActionText == "Repair Plank" then
		currentPrompt = prompt

		if container and fill then
			container.Visible = true
			fill.Size = UDim2.new(0, 0, 1, 0)

			local gradient = fill:FindFirstChildOfClass("UIGradient")
			if gradient then
				gradient:Destroy()
			end

			fill.BackgroundColor3 = PASTEL_GREEN
		end
	end
end)

-- Cache l'interface personnalisée si le joueur s'éloigne ou tourne la caméra
ProximityPromptService.PromptHidden:Connect(function(prompt)
	if prompt == currentPrompt then
		if container then
			container.Visible = false
		end
		currentPrompt = nil
	end
end)

-- S'active quand le joueur commence à maintenir la touche d'interaction
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	if prompt.ActionText == "Repair Barricade" or prompt.ActionText == "Réparer Barricade" or prompt.ActionText == "Repair Plank" then
		currentPrompt = prompt

		if container and fill then
			container.Visible = true
			TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
				Size = UDim2.new(1, 0, 1, 0)
			}):Play()
			TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(0, 170, 0, 45)}):Play()
		end

		if currentRepairSound then
			currentRepairSound:Destroy()
		end

		currentRepairSound = Instance.new("Sound")
		currentRepairSound.SoundId = "rbxassetid://73294347545120"
		currentRepairSound.Volume = 2
		currentRepairSound.Parent = SoundService
		currentRepairSound:Play()
	end
end)

-- S'active si le joueur relâche la touche avant la fin
ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	if prompt.ActionText == "Repair Barricade" or prompt.ActionText == "Réparer Barricade" or prompt.ActionText == "Repair Plank" then
		if container and fill then
			TweenService:Create(fill, TweenInfo.new(0.2), {Size = UDim2.new(0, 0, 1, 0)}):Play()
			TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(0, 150, 0, 40)}):Play()
		end

		if currentRepairSound then
			currentRepairSound:Stop()
			currentRepairSound:Destroy()
			currentRepairSound = nil
		end
	end
end)

-- S'active quand l'interaction est réussie (barre remplie à 100%)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.ActionText == "Repair Barricade" or prompt.ActionText == "Réparer Barricade" or prompt.ActionText == "Repair Plank" then
		if container then
			container.Visible = false
		end

		if currentRepairSound then
			currentRepairSound:Stop()
			currentRepairSound:Destroy()
			currentRepairSound = nil
		end
	end
end)