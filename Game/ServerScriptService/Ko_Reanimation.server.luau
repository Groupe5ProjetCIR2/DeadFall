-- ============================================================
-- Ce script gère le système de mise à terre (KO) et de réanimation des joueurs, incluant la sauvegarde temporaire de l'inventaire et les statistiques de partie.
-- Il détecte également les conditions de fin de partie et déclenche des événements spécifiques comme l'utilisation d'atouts ou la mort définitive si aucun allié n'est en vie.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local StarterPack = game:GetService("StarterPack")
local ProximityPromptService = game:GetService("ProximityPromptService")

local LOBBY_PLACE_ID = 92938025114562
local DOWNED_DURATION = 60
local REVIVE_HEALTH_PC = 0.50
local PISTOL_NAME = "Desert Eagle 2"

local SavedInventories = Instance.new("Folder")
SavedInventories.Name = "SavedInventories"
SavedInventories.Parent = ReplicatedStorage

local StarterGui = game:GetService("StarterGui")
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

-- Récupère un RemoteEvent existant dans ReplicatedStorage ou le crée s'il n'existe pas
local function getOrCreate(name)
	local e = ReplicatedStorage:FindFirstChild(name)
	if not e then
		e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = ReplicatedStorage
	end
	return e
end

local DownedEvent = getOrCreate("PlayerDowned")
local RevivedEvent = getOrCreate("PlayerRevived")
local EquipPistolEvent = getOrCreate("EquipPistolDowned")
local ForceDeathEvent = getOrCreate("ForceDeath")
local SpectateEvent = getOrCreate("StartSpectate")
local GameOverEvent = getOrCreate("GameOver")
local ClearGumsEvent = getOrCreate("ClearAllGums")
local PhoenixEffectEvent = getOrCreate("PhoenixEffectEvent")

local PlayerStats = {}

for _, p in ipairs(Players:GetPlayers()) do
	if not PlayerStats[p.UserId] then
		PlayerStats[p.UserId] = {
			zombieKills = 0,
			timesKO = 0,
			revives = 0,
			money = 0
		}
	end
end

Players.PlayerAdded:Connect(function(p)
	PlayerStats[p.UserId] = {
		zombieKills = 0,
		timesKO = 0,
		revives = 0,
		money = 0
	}
end)

Players.PlayerRemoving:Connect(function(p)
	PlayerStats[p.UserId] = nil
end)

-- Compte le nombre de joueurs actuellement en vie et non mis à terre, en excluant un personnage spécifique
local function countStandingExcept(excludeChar)
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c and c ~= excludeChar and not c:GetAttribute("IsDowned") then
			local h = c:FindFirstChild("Humanoid")
			if h and h.Health > 0 then n = n + 1 end
		end
	end
	return n
end

-- Tue instantanément tous les joueurs présents et déclenche l'événement de fin de partie
local function killEveryone(reason)
	warn("🚨 KILL EVERYONE DÉCLENCHÉ ! Raison : " .. tostring(reason))
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c then
			c:SetAttribute("IsDowned", false)
			c:SetAttribute("IsCrouching", false)
			local h = c:FindFirstChild("Humanoid")
			if h then h.Health = 0 end
		end
	end
	GameOverEvent:FireAllClients()
end

-- Sauvegarde l'inventaire du joueur dans un dossier temporaire lorsqu'il tombe KO
local function setupDownedInventory(player, char)
	local storage = SavedInventories:FindFirstChild(player.Name) or Instance.new("Folder", SavedInventories)
	storage.Name = player.Name
	storage:ClearAllChildren()

	local hum = char:FindFirstChild("Humanoid")
	if hum then 
		hum:UnequipTools()
		task.wait(0.1)
	end

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then
				item.Parent = storage
			end
		end
	end

	for _, item in ipairs(char:GetChildren()) do
		if item:IsA("Tool") then
			item.Parent = storage
		end
	end
end

-- Restaure les objets sauvegardés dans le sac à dos du joueur lors de sa réanimation
local function restoreInventory(player, char)
	local storage = SavedInventories:FindFirstChild(player.Name)
	local backpack = player:FindFirstChild("Backpack")

	if storage and backpack then
		for _, item in ipairs(storage:GetChildren()) do
			item.Parent = backpack
		end
		storage:Destroy()
	end
end

-- Réinitialise tous les attributs liés aux atouts du joueur
local function clearAllGums(player)
	local gums = {"BouncyBubble", "TitanJawbreaker", "SonicMint", "MedicMix", "PhoenixPop"}

	for _, gumName in ipairs(gums) do
		player:SetAttribute(gumName, nil)
	end

	ClearGumsEvent:FireClient(player)
	print("Toutes les compétences de " .. player.Name .. " ont été réinitialisées.")
end


Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		local hrp = char:WaitForChild("HumanoidRootPart")
		local torso = char:WaitForChild("Torso", 2) or char:WaitForChild("UpperTorso", 2)

		hum.BreakJointsOnDeath = false
		char:SetAttribute("IsDowned", false)
		char:SetAttribute("DownedTimer", 0)
		char:SetAttribute("IsCrouching", false)

		-- Gestion des changements d'état physique lors de la mise à terre ou réanimation
		char:GetAttributeChangedSignal("IsDowned"):Connect(function()
			local isDowned = char:GetAttribute("IsDowned")
			if isDowned then
				hum.WalkSpeed = 0.05
				hum.JumpPower = 0
				char:SetAttribute("IsCrouching", true)
				setupDownedInventory(player, char)
				hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			else
				hum.WalkSpeed = 16
				hum.JumpPower = 50
				char:SetAttribute("IsCrouching", false)

				restoreInventory(player, char)
				local ff = char:FindFirstChild("KOSafety")
				if ff then ff:Destroy() end
				if hum.Health > 0 then
					hum.Health = hum.MaxHealth * REVIVE_HEALTH_PC
					RevivedEvent:FireClient(player)
				end
				local indicator = hrp:FindFirstChild("DownedIndicator")
				if indicator then indicator:Destroy() end
				prompt.Enabled = false
			end
		end)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "REVIVE"
		prompt.HoldDuration = 2
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.Parent = torso or hrp
		prompt.Enabled = false
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("IsBeingHeld", false)

		prompt.PromptButtonHoldBegan:Connect(function()
			prompt:SetAttribute("IsBeingHeld", true)
		end)

		prompt.PromptButtonHoldEnded:Connect(function()
			prompt:SetAttribute("IsBeingHeld", false)
		end)

		prompt.Triggered:Connect(function(interactor)
			if interactor and interactor ~= player then
				local interChar = interactor.Character
				if interChar and not interChar:GetAttribute("IsDowned") then
					char:SetAttribute("IsDowned", false)
					prompt.Enabled = false
					prompt:SetAttribute("IsBeingHeld", false)
					if PlayerStats[interactor.UserId] then
						PlayerStats[interactor.UserId].revives += 1
					end
				end
			end
		end)

		-- Surveille la santé du joueur pour déclencher le KO ou l'utilisation d'un atout de résurrection
		hum.HealthChanged:Connect(function(health)
			if health <= 1 and not char:GetAttribute("IsDowned") then
				char:SetAttribute("IsDowned", true)

				warn("==================================================")
				warn("💀 ALERTE MORT : " .. player.Name .. " vient de tomber à " .. tostring(health) .. " HP.")

				if hrp then
					print("📍 Position exacte : ", hrp.Position)
					print("💨 Vitesse au moment de la mort : ", hrp.AssemblyLinearVelocity.Magnitude)

					if hrp.Position.Y < workspace.FallenPartsDestroyHeight + 50 then
						warn("⚠️ LE JOUEUR A GLITCHÉ SOUS LA MAP ! (FallenPartsDestroyHeight)")
					end
				end

				local standingCount = countStandingExcept(char)
				print("👥 Joueurs encore debout : " .. standingCount)

				local hasPhoenix = player:GetAttribute("PhoenixPop") == true

				-- Vérification de l'atout de résurrection automatique
				if hasPhoenix then
					print("🔥 " .. player.Name .. " utilise Phoenix Pop et ressuscite !")
					clearAllGums(player)
					char:SetAttribute("IsDowned", false)
					hum.Health = 100  
					PhoenixEffectEvent:FireClient(player)
					return
				end

				if standingCount <= 0 then
					warn("❌ Fin de partie : " .. player.Name .. " était le dernier joueur en vie.")
					task.delay(3, function()
						if char and char.Parent then char:Destroy() end
					end)
					char:SetAttribute("IsDowned", false)
					hum.Health = 0
					ForceDeathEvent:FireClient(player)
					killEveryone("Dernier joueur mort (" .. player.Name .. ")")
				else
					print("🩸 " .. player.Name .. " tombe KO (Mode Multi).")
					clearAllGums(player)
					if not PlayerStats[player.UserId] then
						PlayerStats[player.UserId] = { zombieKills = 0, timesKO = 0, revives = 0, money = 0 }
					end
					PlayerStats[player.UserId].timesKO += 1
					hum.Health = 100
					prompt.Enabled = true

					local ff = Instance.new("ForceField")
					ff.Name = "KOSafety"
					ff.Visible = false
					ff.Parent = char

					DownedEvent:FireClient(player)

					local billboard = Instance.new("BillboardGui")
					billboard.Name = "DownedIndicator"
					billboard.Size = UDim2.new(0, 50, 0, 50)
					billboard.StudsOffset = Vector3.new(0, 3, 0)
					billboard.AlwaysOnTop = true
					billboard.Parent = hrp

					local label = Instance.new("ImageLabel")
					label.Size = UDim2.new(1, 0, 1, 0)
					label.BackgroundTransparency = 1
					label.Image = "rbxassetid://135016153356622"
					label.ImageColor3 = Color3.fromRGB(200, 0, 0)
					label.Parent = billboard

					-- Boucle asynchrone gérant le compte à rebours de l'état KO et la mort définitive
					task.spawn(function()
						local i = DOWNED_DURATION
						while i > 0 do
							if not char or not char:GetAttribute("IsDowned") then break end
							if prompt:GetAttribute("IsBeingHeld") then
								task.wait(0.1)
							else
								char:SetAttribute("DownedTimer", i)
								i = i - 1
								task.wait(1)
							end
							if countStandingExcept(nil) == 0 and char:GetAttribute("IsDowned") then 
								killEveryone("Tous les autres joueurs sont morts pendant que " .. player.Name .. " était KO.") 
								break 
							end
						end

						if i <= 0 and char and char:GetAttribute("IsDowned") then
							char:SetAttribute("IsDowned", false)
							hum.Health = 0
							local indicator = hrp:FindFirstChild("DownedIndicator")
							if indicator then indicator:Destroy() end
							prompt.Enabled = false
							task.delay(3, function()
								if char and char.Parent then char:Destroy() end
							end)
							local standing = countStandingExcept(char)
							if standing > 0 then
								local alreadySent = false
								ForceDeathEvent:FireClient(player)
								task.delay(4, function()
									if not alreadySent then
										alreadySent = true
										SpectateEvent:FireClient(player)
									end
								end)
							else
								ForceDeathEvent:FireClient(player)
								killEveryone("Le timer KO de " .. player.Name .. " a expiré en étant le dernier.")
							end
						end
					end)
				end
			end
		end)
	end)
end)

local GetStatsFunction = Instance.new("RemoteFunction")
GetStatsFunction.Name = "GetPlayerStats"
GetStatsFunction.Parent = ReplicatedStorage

-- Fournit les statistiques globales de tous les joueurs pour l'affichage client
GetStatsFunction.OnServerInvoke = function(player)
	local stats = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local leaderstats = p:FindFirstChild("leaderstats")
		local internalData = PlayerStats[p.UserId] or { revives = 0, timesKO = 0 }

		stats[tostring(p.UserId)] = {
			name = p.Name,
			zombieKills = leaderstats and leaderstats:FindFirstChild("Kills") and leaderstats.Kills.Value or 0,
			money = leaderstats and leaderstats:FindFirstChild("Argent") and leaderstats.Argent.Value or 0,
			timesKO = internalData.timesKO,
			revives = internalData.revives,
		}
	end
	return stats
end