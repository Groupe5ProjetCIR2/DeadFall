-- ============================================================
-- Ce script gère un système de jeu de hasard interactif permettant aux joueurs de parier leur monnaie via un ProximityPrompt.
-- Il intègre un système de probabilités avec effets sonores et applique un temps de recharge individuel affiché via une interface locale.
-- ============================================================

local prompt = script.Parent
local bankPart = prompt.Parent

prompt.Style = Enum.ProximityPromptStyle.Custom
prompt.ObjectText = "Best casino in the world: Double your money!!"
prompt.ActionText = "Trust or not?"

local winSound = Instance.new("Sound")
winSound.SoundId = "rbxassetid://112124972739618"
winSound.Volume = 0.8
winSound.Parent = bankPart

local loseSound = Instance.new("Sound")
loseSound.SoundId = "rbxassetid://9701013480"
loseSound.Volume = 0.8
loseSound.Parent = bankPart

local playerCooldowns = {} 
local COOLDOWN_TIME = 120 

-- Écoute l'interaction du joueur avec le prompt et exécute la logique de pari si le délai de récupération est écoulé
prompt.Triggered:Connect(function(player)
	local userId = player.UserId

	if playerCooldowns[userId] then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	local argent = leaderstats and leaderstats:FindFirstChild("Argent")

	if not argent or argent.Value <= 0 then return end

	playerCooldowns[userId] = true

	-- Calcule mathématiquement le résultat de l'action selon une probabilité fixe (20% de succès)
	local chance = math.random(1, 100)

	if chance <= 20 then
		argent.Value = argent.Value * 2
		winSound:Play()
	else
		argent.Value = math.floor(argent.Value * 0.85) 
		loseSound:Play()
	end

	-- Génère une instance visuelle de compte à rebours localement dans le PlayerGui pour qu'elle soit invisible des autres joueurs
	local playerGui = player:FindFirstChild("PlayerGui")
	local billboard = nil
	local textLabel = nil

	if playerGui then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "CasinoCooldown_" .. userId
		billboard.Adornee = bankPart
		billboard.Size = UDim2.new(0, 200, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 20 
		billboard.ResetOnSpawn = false 

		textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.TextColor3 = Color3.fromRGB(255, 50, 50) 
		textLabel.TextStrokeTransparency = 0
		textLabel.TextScaled = true
		textLabel.Font = Enum.Font.SciFi
		textLabel.Parent = billboard

		billboard.Parent = playerGui 
	end

	-- Lance une routine asynchrone pour mettre à jour l'affichage du temps restant sans bloquer le fil d'exécution principal
	task.spawn(function()
		for i = COOLDOWN_TIME, 1, -1 do
			if not player or not player.Parent then break end
			if textLabel then
				textLabel.Text = "Come back later\nWait: " .. i .. "s"
			end
			task.wait(1)
		end

		if billboard then billboard:Destroy() end
		playerCooldowns[userId] = nil
	end)
end)

-- Libère la mémoire du tableau de cooldowns lors de la déconnexion d'un joueur pour éviter les fuites de données
game:GetService("Players").PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
end)