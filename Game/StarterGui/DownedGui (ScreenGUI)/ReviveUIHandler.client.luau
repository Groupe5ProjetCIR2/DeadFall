-- ============================================================
-- Ce script gère l'interface personnalisée de l'interaction "Revive" (Réanimation).
-- Il affiche une barre de progression au-dessus du joueur à terre et gère 
-- le préchargement ainsi que la lecture d'une voiceline aléatoire en cas de succès.
-- ============================================================

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local gui = script.Parent

local container = gui:WaitForChild("Container", 10) 
local fill = container and container:WaitForChild("Fill", 10)
local currentPrompt = nil 

local replicatedStorage_folder_voiceslines = game:GetService("ReplicatedStorage"):WaitForChild("VoiceLines")
local replicatedStorage_folder_eventvoiceslines = game:GetService("ReplicatedStorage"):WaitForChild("EventVoices")

local lastVoiceTime = 0 

-- CHARGEMENT DES SONS EN ARRIÈRE-PLAN
-- Utilise ContentProvider pour charger les fichiers audio en mémoire dès le début,
-- évitant ainsi un délai de chargement (lag) lors de la première lecture d'une voix.
task.spawn(function()
	local soundsToLoad = {}

	for _, categoryFolder in ipairs(replicatedStorage_folder_voiceslines:GetChildren()) do
		for _, sound in ipairs(categoryFolder:GetChildren()) do
			if sound:IsA("Sound") then
				table.insert(soundsToLoad, sound)
			end
		end
	end

	if #soundsToLoad > 0 then
		ContentProvider:PreloadAsync(soundsToLoad)
		print("Toutes les voicelines ont été chargées !")
	end
end)

-- FONCTION POUR JOUER UN DES SONS AU HASARD
-- Sélectionne une voix aléatoire, la joue localement, puis avertit le serveur
-- pour synchroniser l'effet sonore avec les autres joueurs.
local function playReviveVoice()
	local revivingFolder = replicatedStorage_folder_voiceslines:FindFirstChild("Reviving")

	if revivingFolder then
		local sounds = revivingFolder:GetChildren()

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

	local revivingEvent = replicatedStorage_folder_eventvoiceslines:FindFirstChild("Reviving")
	if revivingEvent then
		revivingEvent:FireServer()
	end
end

-- LOGIQUE UI ET DÉCLENCHEMENT
-- Projette la position 3D de l'interaction en coordonnées 2D sur l'écran
-- pour que l'interface suive parfaitement le joueur à terre.
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

-- Apparition de l'interface personnalisée quand le joueur s'approche
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.ActionText == "Revive" and container and fill then
		currentPrompt = prompt
		container.Visible = true
		fill.Size = UDim2.new(0, 0, 1, 0)
	end
end)

-- Disparition de l'interface si le joueur s'éloigne
ProximityPromptService.PromptHidden:Connect(function(prompt)
	if prompt == currentPrompt and container then
		container.Visible = false
		currentPrompt = nil
	end
end)

-- Lance l'animation de la barre de progression selon le temps requis (HoldDuration)
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	if prompt == currentPrompt and container and fill then
		TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
			Size = UDim2.new(1, 0, 1, 0)
		}):Play()

		TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(0, 170, 0, 45)}):Play()
	end
end)

-- Annule et réinitialise l'animation si le joueur relâche la touche trop tôt
ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	if prompt == currentPrompt and container and fill then
		TweenService:Create(fill, TweenInfo.new(0.2), {Size = UDim2.new(0, 0, 1, 0)}):Play()
		TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(0, 150, 0, 40)}):Play()
	end
end)

-- S'exécute lorsque l'interaction est complétée avec succès
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt == currentPrompt then
		if container then
			container.Visible = false
		end

		-- Sécurité anti-spam : Empêche de jouer plusieurs voicelines consécutives
		-- si plusieurs réanimations s'enchaînent trop vite (cooldown de 4 secondes).
		if tick() - lastVoiceTime > 4 then
			lastVoiceTime = tick()
			playReviveVoice()
		end
	end
end)