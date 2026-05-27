-- ============================================================
-- Ce script gère un système bancaire d'investissement permettant aux joueurs de placer un pourcentage de leur argent via un ProximityPrompt.
-- Il orchestre un cycle complet en trois phases individuelles (investissement, récolte avec bénéfice, et délai de récupération) avec des interfaces visuelles et sonores.
-- ============================================================

local prompt = script.Parent
local investPart = prompt.Parent

prompt.Style = Enum.ProximityPromptStyle.Custom
prompt.ObjectText = "Junia Bank"
prompt.ActionText = "Invest 25% of your money"

local cashRegisterSound = Instance.new("Sound")
cashRegisterSound.SoundId = "rbxassetid://101396758527961" 
cashRegisterSound.Volume = 1
cashRegisterSound.Parent = investPart

local chaChingSound = Instance.new("Sound")
chaChingSound.SoundId = "rbxassetid://137659049096552" 
chaChingSound.Volume = 1
chaChingSound.Parent = investPart

local playerTimers = {}    
local activeInvestors = {} 
local playerCooldowns = {} 

local WAIT_TIME = 60
local COOLDOWN_TIME = 120

-- Déclenche la machine à états gérant l'investissement, la récolte et le temps de recharge pour chaque joueur
prompt.Triggered:Connect(function(player)
	local userId = player.UserId
	local leaderstats = player:FindFirstChild("leaderstats")
	local argent = leaderstats and leaderstats:FindFirstChild("Argent")

	-- Bloque l'exécution si le joueur est actuellement soumis au délai de récupération global
	if playerCooldowns[userId] then
		return 
	end

	-- Traite la validation de la récolte, attribue les bénéfices et lance la phase de blocage asynchrone
	if activeInvestors[userId] then
		local reward = activeInvestors[userId]
		activeInvestors[userId] = nil 

		if argent then
			argent.Value = argent.Value + reward
			chaChingSound:Play()
		end

		playerCooldowns[userId] = true

		local playerGui = player:FindFirstChild("PlayerGui")
		if playerGui then
			local billboard = playerGui:FindFirstChild("InvestTimer_" .. userId)
			if billboard then
				local textLabel = billboard:FindFirstChildOfClass("TextLabel")
				if textLabel then
					textLabel.TextColor3 = Color3.fromRGB(255, 50, 50)

					task.spawn(function()
						for i = COOLDOWN_TIME, 1, -1 do
							if not player or not player.Parent then break end
							if textLabel then
								textLabel.Text = "Bank Closed\nWait: " .. i .. "s"
							end
							task.wait(1)
						end

						if billboard then billboard:Destroy() end
						playerCooldowns[userId] = nil
					end)
				end
			end
		end
		return
	end

	-- Initialise le processus d'investissement, déduit les fonds et génère l'interface locale de suivi
	if playerTimers[userId] then return end 
	if not argent or argent.Value <= 0 then return end

	local amountToInvest = math.floor(argent.Value * 0.25)
	if amountToInvest <= 0 then amountToInvest = 1 end

	argent.Value = argent.Value - amountToInvest
	playerTimers[userId] = true 
	cashRegisterSound:Play()

	local expectedReturn = math.floor(amountToInvest * 1.5)

	local playerGui = player:FindFirstChild("PlayerGui")
	local billboard = nil
	local textLabel = nil

	if playerGui then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "InvestTimer_" .. userId
		billboard.Adornee = investPart
		billboard.Size = UDim2.new(0, 200, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 40 
		billboard.ResetOnSpawn = false 

		textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.TextColor3 = Color3.fromRGB(85, 255, 127) 
		textLabel.TextStrokeTransparency = 0
		textLabel.TextScaled = true
		textLabel.Font = Enum.Font.SciFi
		textLabel.Parent = billboard

		billboard.Parent = playerGui 
	end

	-- Supervise l'attente des rendements via une coroutine pour ne pas entraver le fil d'exécution principal
	task.spawn(function()
		for i = WAIT_TIME, 1, -1 do
			if not player or not player.Parent then break end
			if textLabel then
				textLabel.Text = "Return in: " .. i .. "s\n(+" .. expectedReturn .. " $)"
			end
			task.wait(1)
		end

		if player and player.Parent then
			playerTimers[userId] = nil 
			activeInvestors[userId] = expectedReturn 

			if textLabel then
				textLabel.TextColor3 = Color3.fromRGB(255, 255, 0) 
				textLabel.Text = "READY!\nPress E to Collect"
			end
		else
			if billboard then billboard:Destroy() end
			playerTimers[userId] = nil
			activeInvestors[userId] = nil
		end
	end)
end)

-- Purge les données d'état stockées lors de la déconnexion d'un utilisateur pour prévenir les fuites de mémoire
game:GetService("Players").PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	playerTimers[userId] = nil
	activeInvestors[userId] = nil
	playerCooldowns[userId] = nil
end)