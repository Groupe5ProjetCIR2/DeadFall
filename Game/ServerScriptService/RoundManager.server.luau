-- ============================================================
-- Ce script gère le déroulement global des manches d'un jeu de survie zombie, incluant l'apparition progressive des ennemis, leur évolution statistique et la gestion des vagues.
-- Il s'occupe également du nettoyage des entités mortes, des conditions de fin de partie et du système de téléportation des zombies bloqués.
-- ============================================================

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local portalTemplate = ServerStorage:FindFirstChild("Portal")
local WindowManager = require(ServerStorage:WaitForChild("WindowManager"))
local PhysicsService = game:GetService("PhysicsService")
PhysicsService:RegisterCollisionGroup("Zombies")
PhysicsService:RegisterCollisionGroup("Portes")
PhysicsService:CollisionGroupSetCollidable("Zombies", "Zombies", false)
PhysicsService:CollisionGroupSetCollidable("Zombies", "Portes", false)

local cutPowerEvent = ServerStorage:FindFirstChild("CutPowerEvent")
if not cutPowerEvent then
	cutPowerEvent = Instance.new("BindableEvent")
	cutPowerEvent.Name = "CutPowerEvent"
	cutPowerEvent.Parent = ServerStorage
end

local teleportZombieEvent = ServerStorage:FindFirstChild("TeleportZombie")
if not teleportZombieEvent then
	teleportZombieEvent = Instance.new("BindableEvent")
	teleportZombieEvent.Name = "TeleportZombie"
	teleportZombieEvent.Parent = ServerStorage
end

-- ============================================================
-- REMOTE EVENTS (HUD + signaux)
-- ============================================================
local evtRound   = Instance.new("RemoteEvent"); evtRound.Name   = "HUD_Round";   evtRound.Parent   = ReplicatedStorage
local evtWave    = Instance.new("RemoteEvent"); evtWave.Name    = "HUD_Wave";    evtWave.Parent    = ReplicatedStorage
local evtZombies = Instance.new("RemoteEvent"); evtZombies.Name = "HUD_Zombies"; evtZombies.Parent = ReplicatedStorage
local evtPause   = Instance.new("RemoteEvent"); evtPause.Name   = "HUD_Pause";   evtPause.Parent   = ReplicatedStorage
local evtGameOver = Instance.new("RemoteEvent"); evtGameOver.Name = "GameOver";  evtGameOver.Parent = ReplicatedStorage

-- ============================================================
-- CONFIGURATION MANCHES
-- ============================================================
local ROUND_COUNT        = 30
local ZOMBIES_END        = 250
local MAX_ACTIVE_ZOMBIES = 150
local SPAWN_RATE_START   = 1
local SPAWN_RATE_END     = 3
local BASE_ROUND_TIME    = 180
local SPAWN_DELAY_BUFFER = 30
local SPAWN_THRESHOLD    = 150
local PAUSE_DURATION     = 10
local START_DELAY        = 5
local MIN_DIST = 15
local MAX_DIST = 150
local ZOMBIE_BONUS_START_ROUND = 20
local ZOMBIE_BONUS_PER_ROUND   = 25

-- ============================================================
-- ZOMBIE STATS EVOLUTION
-- ============================================================
local Z_STATS = {
	Speed_Base = 10, Speed_Max = 25, Speed_MaxRound =  15,
	Health_Base = 50, Health_Max = 200, Health_MaxRound = 20,
	Damage_Base = 20, Damage_Max = 40, Damage_StartRound = 10, Damage_MaxRound = 20,
}

local Z_EXTRA = {
	Speed_BonusPerRound  = 0.5,
	Health_BonusPerRound = 5,
	Damage_BonusPerRound = 1,
}

local function getZombiesStart()
	local count = #Players:GetPlayers()
	if count <= 1 then return 5
	elseif count == 2 then return 10
	elseif count == 3 then return 15
	else return 20
	end
end
local function setZombieCollisionGroup(model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Zombies"
		end
	end
end

-- ============================================================
-- ÉTAT & RÉFÉRENCES
-- ============================================================
local activeZombies   = {}
local roundInProgress = false
local gameRunning     = false
local currentRoundGlobal = 1

local spawnFolder    = workspace:FindFirstChild("CyborgSpawns")
local cyborgTemplate = ServerStorage:FindFirstChild("ZombieRobot")
local cyborgBossTemplate = ServerStorage:FindFirstChild("ZombieRobotBoss")

if not spawnFolder or not cyborgTemplate then
	warn("❌ RoundManager : CyborgSpawns ou ZombieRobot manquant !")
	return
end

-- ============================================================
-- ATTENTE DES JOUEURS
-- ============================================================
local playerLoadedEvent = ReplicatedStorage:FindFirstChild("PlayerLoaded")
if not playerLoadedEvent then
	playerLoadedEvent = Instance.new("RemoteEvent")
	playerLoadedEvent.Name = "PlayerLoaded"
	playerLoadedEvent.Parent = ReplicatedStorage
end

local loadedPlayers = {}
playerLoadedEvent.OnServerEvent:Connect(function(player) loadedPlayers[player] = true end)
Players.PlayerRemoving:Connect(function(player) loadedPlayers[player] = nil end)

local function waitForAllPlayersLoaded()
	while true do
		task.wait(0.5)
		local players = Players:GetPlayers()
		if #players == 0 then continue end

		local allReady = true
		for _, p in ipairs(players) do
			if not loadedPlayers[p] then
				allReady = false
				break
			end
		end
		if allReady then return end
	end
end

-- ============================================================
-- DÉTECTION GAME OVER
-- ============================================================
local function allPlayersDead()
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then return false end
		end
	end
	return true
end

-- ============================================================
-- FORMULES MANCHES & ZOMBIES
-- ============================================================
local function getZombieCount(round)
	local r = math.clamp(round, 1, ROUND_COUNT)
	local start = getZombiesStart()
	local ratio = ZOMBIES_END / start
	local base = math.floor(start * (ratio ^ ((r - 1) / (ROUND_COUNT - 1))))
	
	local bonus = 0
	if round > ZOMBIE_BONUS_START_ROUND then
		bonus = (round - ZOMBIE_BONUS_START_ROUND) * ZOMBIE_BONUS_PER_ROUND
	end

	return base + bonus
end

local function getSpawnRate(round)
	local r = math.clamp(round, 1, ROUND_COUNT)
	local ratio = SPAWN_RATE_END / SPAWN_RATE_START
	return SPAWN_RATE_START * (ratio ^ ((r - 1) / (ROUND_COUNT - 1)))
end

local function getRoundTime(round)
	local zombieCount   = getZombieCount(round)
	local spawnRate     = getSpawnRate(round)
	local spawnDuration = zombieCount / spawnRate
	return spawnDuration > SPAWN_THRESHOLD and (spawnDuration + SPAWN_DELAY_BUFFER) or BASE_ROUND_TIME
end

local function getValidSpawnParts()
	local spawnParts = spawnFolder:GetChildren()
	local validParts = {}
	local activePlayerPositions = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChild("Humanoid")
			if hrp and hum and hum.Health > 0 then table.insert(activePlayerPositions, hrp.Position) end
		end
	end

	for _, part in ipairs(spawnParts) do
		local pos      = part.Position
		local tooClose = false
		local tooFar   = true
		for _, pPos in ipairs(activePlayerPositions) do
			local dist = (pos - pPos).Magnitude
			if dist < MIN_DIST then tooClose = true break end
			if dist <= MAX_DIST then tooFar = false end
		end
		if not tooClose and not tooFar then table.insert(validParts, part) end
	end

	if #validParts == 0 then
		local best, bestDist = nil, 0
		for _, part in ipairs(spawnParts) do
			for _, pPos in ipairs(activePlayerPositions) do
				local dist = (part.Position - pPos).Magnitude
				if dist > bestDist then bestDist = dist; best = part end
			end
		end
		if best then table.insert(validParts, best) end
	end
	return validParts
end

-- ============================================================
-- CALCULS D'EVOLUTION ZOMBIE
local function calculateZombieStats(round)
	local stats = {speed = Z_STATS.Speed_Base, health = Z_STATS.Health_Base, damage = Z_STATS.Damage_Base}

	local speedProgress = math.clamp((round - 1) / (Z_STATS.Speed_MaxRound - 1), 0, 1)
	stats.speed = Z_STATS.Speed_Base + (Z_STATS.Speed_Max - Z_STATS.Speed_Base) * speedProgress
	if round > Z_STATS.Speed_MaxRound then
		stats.speed += (round - Z_STATS.Speed_MaxRound) * Z_EXTRA.Speed_BonusPerRound
	end

	local healthProgress = math.clamp((round - 1) / (Z_STATS.Health_MaxRound - 1), 0, 1)
	stats.health = math.floor(Z_STATS.Health_Base + (Z_STATS.Health_Max - Z_STATS.Health_Base) * healthProgress)
	if round > Z_STATS.Health_MaxRound then
		stats.health += (round - Z_STATS.Health_MaxRound) * Z_EXTRA.Health_BonusPerRound
	end

	if round >= Z_STATS.Damage_StartRound then
		local dmgProgress = math.clamp((round - Z_STATS.Damage_StartRound) / (Z_STATS.Damage_MaxRound - Z_STATS.Damage_StartRound), 0, 1)
		stats.damage = math.floor(Z_STATS.Damage_Base + (Z_STATS.Damage_Max - Z_STATS.Damage_Base) * dmgProgress)
		if round > Z_STATS.Damage_MaxRound then
			stats.damage += (round - Z_STATS.Damage_MaxRound) * Z_EXTRA.Damage_BonusPerRound
		end
	end

	return stats
end
-- ============================================================
-- SPAWN LOGIQUE OPTIMISÉE ⚡ (Single Pass)
-- ============================================================
local function spawnZombie(customTemplate)
	local parts = getValidSpawnParts()
	if #parts == 0 then return end

	local part = parts[math.random(1, #parts)]
	local templateToUse = customTemplate or cyborgTemplate
	local zombie = templateToUse:Clone()
	local humanoid = zombie:FindFirstChildOfClass("Humanoid")

	local usePortal = (portalTemplate and templateToUse ~= cyborgBossTemplate)
	local partsToFade = {} -- Notre "tiroir" pour les animations

	for _, child in ipairs(zombie:GetDescendants()) do
		if child:IsA("BasePart") or child:IsA("MeshPart") then 
			child.CollisionGroup = "Zombies" 

			if usePortal and child.Name ~= "HumanoidRootPart" then
				child.Transparency = 1
				table.insert(partsToFade, child)
			end
		elseif child:IsA("Decal") and usePortal then
			child.Transparency = 1
			table.insert(partsToFade, child)
		end
	end

	local calculatedSpeed = 16 
	if humanoid then
		if templateToUse == cyborgTemplate then
			local targetStats = calculateZombieStats(currentRoundGlobal)
			humanoid.MaxHealth = targetStats.health
			humanoid.Health = targetStats.health
			zombie:SetAttribute("CurrentDamage", targetStats.damage)
			local randomOffset = (math.random() * 6) - 3
			calculatedSpeed = targetStats.speed + randomOffset

			humanoid.WalkSpeed = 0 

		elseif templateToUse == cyborgBossTemplate then
			local bossWaveIndex = math.floor(currentRoundGlobal / 3)
			local bossHealth = 1500 + ((bossWaveIndex - 1) * 250)

			humanoid.MaxHealth = bossHealth
			humanoid.Health = bossHealth
		end
	end

	local decalage = (templateToUse == cyborgBossTemplate) and 10 or 3
	local spawnPos = part.Position + Vector3.new(0, decalage, 0)
	zombie:PivotTo(CFrame.new(spawnPos))

	task.spawn(function()
		local fadeInfo = TweenInfo.new(1, Enum.EasingStyle.Linear)
		local portal = nil

		-- === GESTION DU PORTAIL ===
		if usePortal then
			portal = portalTemplate:Clone()
			local portalPos = spawnPos + Vector3.new(0, 3, 0)
			portal:PivotTo(CFrame.new(portalPos) * CFrame.Angles(math.rad(180), 0, math.rad(90)))

			if portal:IsA("BasePart") then
				portal.Anchored = true; portal.Transparency = 1
			end
			for _, p in ipairs(portal:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = true; p.Transparency = 1
				end
			end

			portal.Parent = workspace

			-- On lance l'animation du portail
			if portal:IsA("BasePart") then TweenService:Create(portal, fadeInfo, {Transparency = 0}):Play() end
			for _, p in ipairs(portal:GetDescendants()) do
				if p:IsA("BasePart") then TweenService:Create(p, fadeInfo, {Transparency = 0}):Play() end
			end

			task.wait(1)
		else
			-- Spawn immédiat du Boss
			zombie.Parent = workspace
			table.insert(activeZombies, zombie)
			task.wait(1)
			if zombie and zombie.Parent and humanoid then
				humanoid.WalkSpeed = (templateToUse == cyborgBossTemplate) and 10 or calculatedSpeed
			end
			return
		end

		-- === APPARITION DU ZOMBIE NORMAL ===
		task.wait(0.5)
		zombie.Parent = workspace
		table.insert(activeZombies, zombie)

		-- ⚡ OPTIMISATION : Plus besoin de refouiller, on anime juste la liste !
		for _, p in ipairs(partsToFade) do
			if p and p.Parent then
				TweenService:Create(p, fadeInfo, {Transparency = 0}):Play()
			end
		end

		task.wait(1.5)
		if portal and portal.Parent then portal:Destroy() end
		if zombie and zombie.Parent and humanoid then humanoid.WalkSpeed = calculatedSpeed end
	end)
end

-- ============================================================
-- NETTOYAGE & GAME OVER
-- ============================================================
local function cleanDead()
	for i = #activeZombies, 1, -1 do
		local z = activeZombies[i]
		if not z or not z.Parent or not z:IsDescendantOf(workspace) then 
			table.remove(activeZombies, i)
		else
			local hum = z:FindFirstChild("Humanoid")
			if hum and hum.Health <= 0 then
				z:Destroy()
				table.remove(activeZombies, i)
			end
		end
	end
end

local function killAllZombies()
	for _, z in ipairs(activeZombies) do if z and z.Parent then z:Destroy() end end
	activeZombies = {}
end

local function triggerGameOver()
	gameRunning = false
	killAllZombies()
	evtGameOver:FireAllClients()
end

-- ============================================================
-- BOUCLE DE MANCHE
-- ============================================================
local function runRound(round)
	currentRoundGlobal = round
	roundInProgress = true

	local zombieCount   = getZombieCount(round)
	local spawnRate     = getSpawnRate(round)
	local roundTime     = getRoundTime(round)
	local spawnInterval = 1 / spawnRate

	evtWave:FireAllClients(roundTime, roundTime)
	evtZombies:FireAllClients(zombieCount)

	local roundStart   = tick()
	local spawnedCount = 0
	local spawnDone    = false

	local regularCount, windowCount, bonusRegular, bonusWindow
	if round <= 3 then
		regularCount  = 0; windowCount    = zombieCount + math.ceil(zombieCount / 2)
		bonusRegular  = 0; bonusWindow    = 0
	else
		local quarter    = math.floor(zombieCount / 4)
		regularCount  = zombieCount - quarter; windowCount    = math.ceil(zombieCount / 2) - quarter
		bonusRegular  = quarter; bonusWindow    = quarter
	end
	local totalToSpawn = regularCount + windowCount + bonusRegular + bonusWindow

	local spawnThread = task.spawn(function()
		if round % 3 == 0 then
			local bossCount = math.floor(round / 3)
			task.spawn(function()
				for i = 1, bossCount do
					if not gameRunning then break end
					while #activeZombies >= MAX_ACTIVE_ZOMBIES and gameRunning do task.wait(0.2) end

					spawnZombie(cyborgBossTemplate)
					task.wait(5)
				end
			end)
		end

		task.spawn(function()
			for i = 1, regularCount do
				if not gameRunning then break end
				while #activeZombies >= MAX_ACTIVE_ZOMBIES and gameRunning do task.wait(0.2) end
				spawnZombie()
				spawnedCount += 1
				local waited = 0
				while waited < spawnInterval and gameRunning do
					local step = math.min(0.1, spawnInterval - waited)
					task.wait(step); waited += step
				end
			end
		end)

		task.spawn(function()
			for i = 1, windowCount do
				if not gameRunning then break end
				while #activeZombies >= MAX_ACTIVE_ZOMBIES and gameRunning do task.wait(0.2) end
				WindowManager.spawnWindowZombies(1, activeZombies, function() return gameRunning end, 0, function() spawnedCount += 1 end, currentRoundGlobal)
				local waited = 0
				while waited < spawnInterval and gameRunning do
					local step = math.min(0.1, spawnInterval - waited)
					task.wait(step); waited += step
				end
			end
		end)

		if bonusRegular + bonusWindow > 0 then
			task.spawn(function()
				local bonusList = {}
				for i = 1, bonusRegular do table.insert(bonusList, "regular") end
				for i = 1, bonusWindow  do table.insert(bonusList, "window")  end

				for i = #bonusList, 2, -1 do
					local j = math.random(1, i)
					bonusList[i], bonusList[j] = bonusList[j], bonusList[i]
				end

				for idx, spawnType in ipairs(bonusList) do
					if not gameRunning then break end
					while #activeZombies >= MAX_ACTIVE_ZOMBIES and gameRunning do task.wait(0.2) end

					if spawnType == "regular" then 
						spawnZombie()
					else 
						WindowManager.spawnWindowZombies(1, activeZombies, function() return gameRunning end, 0, nil, currentRoundGlobal) 
					end
					spawnedCount += 1

					local waited = 0
					while waited < spawnInterval and gameRunning do
						local step = math.min(0.1, spawnInterval - waited)
						task.wait(step); waited += step
					end
				end
			end)
		end
		spawnDone = true
	end)

	local blinkCounter = 0
	while gameRunning do
		task.wait(1)
		cleanDead()

		if allPlayersDead() then
			task.cancel(spawnThread)
			roundInProgress = false
			triggerGameOver()
			return false
		end

		local elapsed    = tick() - roundStart
		local remaining  = math.max(0, roundTime - elapsed)
		local allSpawned = spawnedCount >= totalToSpawn 
		
		if elapsed >= 240 then
			for _, z in ipairs(activeZombies) do
				if z and z.Parent then
					local hrp = z:FindFirstChild("HumanoidRootPart")
					if hrp then
						local isTooFar = true
						for _, p in ipairs(Players:GetPlayers()) do
							local char = p.Character
							if char then
								local pHrp = char:FindFirstChild("HumanoidRootPart")
								local hum = char:FindFirstChild("Humanoid")
								if pHrp and hum and hum.Health > 0 then
									local dist = (pHrp.Position - hrp.Position).Magnitude
									if dist <= 350 then
										isTooFar = false
										break
									end
								end
							end
						end
						if isTooFar then
							teleportZombieEvent:Fire(z)
						end
					end
				end
			end
		end
		
		if elapsed >= 240 and #activeZombies < 5 then
			blinkCounter = (blinkCounter + 1) % 5

			for _, z in ipairs(activeZombies) do
				if z and z.Parent then
					local hl = z:FindFirstChild("ZombieESP")
					if not hl then
						hl = Instance.new("Highlight")
						hl.Name = "ZombieESP"
						hl.FillColor = Color3.fromRGB(255, 0, 0)
						hl.OutlineColor = Color3.fromRGB(255, 0, 0)
						hl.FillTransparency = 0.5 
						hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						hl.Parent = z
					end
					hl.Enabled = (blinkCounter == 1)
				end
			end
		else
			for _, z in ipairs(activeZombies) do
				local hl = z and z:FindFirstChild("ZombieESP")
				if hl then hl.Enabled = false end
			end
		end

		evtWave:FireAllClients(remaining, roundTime)
		evtZombies:FireAllClients(#activeZombies)

		if allSpawned and #activeZombies == 0 then 
			break 
		end
		if spawnDone and #activeZombies == 0 then
			break
		end
	end

	task.cancel(spawnThread)
	roundInProgress = false
	return true
end

local function runPause(nextRound)
	for i = PAUSE_DURATION, 1, -1 do
		if not gameRunning then return end
		evtPause:FireAllClients(i)
		task.wait(1)
	end
	evtRound:FireAllClients(nextRound)
end

local ZOMBIE_SOUND_IDS = {
	"rbxassetid://82913343699528",
	"rbxassetid://116454071354008",
	"rbxassetid://95306591534442",
	"rbxassetid://137105744001234",
	"rbxassetid://243640200"
}

task.spawn(function()
	while true do
		task.wait(math.random(5, 8))

		if gameRunning and #activeZombies > 0 then
			local amountToPlay = math.min(math.random(1, 3), #activeZombies)
			local validZombies = {}
			for _, z in ipairs(activeZombies) do
				if z and z.Parent and z:FindFirstChild("HumanoidRootPart") then
					table.insert(validZombies, z)
				end
			end

			if #validZombies == 0 then continue end
			
			for i = #validZombies, 2, -1 do
				local j = math.random(1, i)
				validZombies[i], validZombies[j] = validZombies[j], validZombies[i]
			end
			
			local sonsDisponibles = {}
			for _, id in ipairs(ZOMBIE_SOUND_IDS) do
				table.insert(sonsDisponibles, id)
			end

			for i = 1, amountToPlay do
				local chosenZombie = validZombies[i]
				local dernierSonJoue = chosenZombie:GetAttribute("DernierSon")

				local sonsValides = {}
				for _, id in ipairs(sonsDisponibles) do
					if id ~= dernierSonJoue then
						table.insert(sonsValides, id)
					end
				end
				if #sonsValides == 0 then
					sonsValides = sonsDisponibles
				end

				local sonChoisi = sonsValides[math.random(1, #sonsValides)]
				chosenZombie:SetAttribute("DernierSon", sonChoisi)
				for idx, id in ipairs(sonsDisponibles) do
					if id == sonChoisi then
						table.remove(sonsDisponibles, idx)
						break
					end
				end

				task.spawn(function()
					task.wait(math.random() * 1.5)

					if chosenZombie and chosenZombie.Parent then
						local hrp = chosenZombie:FindFirstChild("HumanoidRootPart")
						if hrp then
							local sound = Instance.new("Sound")
							sound.SoundId = sonChoisi
							sound.Volume = 0.6
							sound.RollOffMaxDistance = 80
							sound.RollOffMinDistance = 5
							sound.Parent = hrp

							sound:Play()

							sound.Ended:Connect(function()
								sound:Destroy()
							end)
						end
					end
				end)
			end
		end
	end
end)



task.spawn(function()
	waitForAllPlayersLoaded()
	WindowManager.initWindows()

	for i = START_DELAY, 1, -1 do
		evtPause:FireAllClients(i)
		task.wait(1)
	end
	
	evtRound:FireAllClients(1)

	gameRunning = true
	local round = 1

	while gameRunning do
		local ok = runRound(round)
		if not ok then break end
		if allPlayersDead() then
			triggerGameOver()
			break
		end

		if math.random() <= 0.25 then
			cutPowerEvent:Fire()
		end

		runPause(round + 1)
		round += 1
	end
end)

teleportZombieEvent.Event:Connect(function(zombie)
	local parts = getValidSpawnParts()
	if #parts == 0 then return end
	local players = Players:GetPlayers()
	local validParts = {}
	for _, part in ipairs(parts) do
		local hiddenFromAll = true
		for _, p in ipairs(players) do
			local char = p.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local cam  = hrp
				if hrp then
					local rayParams = RaycastParams.new()
					rayParams.FilterDescendantsInstances = {zombie}
					rayParams.FilterType = Enum.RaycastFilterType.Exclude
					local dir    = (part.Position - hrp.Position)
					local result = workspace:Raycast(hrp.Position, dir, rayParams)
					if not result then
						hiddenFromAll = false
					end
				end
			end
		end
		if hiddenFromAll then
			table.insert(validParts, part)
		end
	end
	if #validParts == 0 then validParts = parts end

	local spawnPart = validParts[math.random(1, #validParts)]
	if zombie and zombie.Parent then
		zombie:PivotTo(CFrame.new(spawnPart.Position + Vector3.new(0, 3, 0)))
	end
end)