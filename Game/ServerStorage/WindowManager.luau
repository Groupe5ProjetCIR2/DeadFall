-- ============================================================
-- Ce module gère les barricades (fenêtres) où les zombies apparaissent, incluant la destruction progressive des planches et le système de réparation par les joueurs.
-- Il orchestre également les animations d'attaque des zombies sur les obstacles et gère une file d'attente pour réguler leur entrée fluide sur la carte.
-- ============================================================

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local windowFolder = workspace:WaitForChild("CyborgWindowSpawns")
local cyborgTemplate = ServerStorage:WaitForChild("ZombieRobot")

local PLANK_HITS_REQUIRED = 2
local PLANK_NAMES = {"Plank1", "Plank2", "Plank3"}
local PUNCH_ANIMS = {"punch","punch1","punch2","punch3","punch4","punch5"}
local PUNCH_SOUNDS = {"poing2","poing3","poing4","poing5"}

local windowStates = {}
local WindowManager = {}
local isInitialized = false

local Z_STATS = {
	Speed_Base = 10, Speed_Max = 25, Speed_MaxRound = 20,
	Health_Base = 50, Health_Max = 300, Health_MaxRound = 20,
	Damage_Base = 20, Damage_Max = 40, Damage_StartRound = 10, Damage_MaxRound = 20,
}

local STARTER_WINDOWS = {
	["Window1"] = true,
	["Window2"] = true
}

local repairEvent = Instance.new("RemoteEvent")
repairEvent.Name = "RepairWindow"
repairEvent.Parent = ReplicatedStorage

-- Calcule dynamiquement les attributs (vitesse, santé, dégâts) des zombies en fonction de la manche actuelle
local function calculateStats(round)
	local sProgress = math.clamp((round - 1) / (Z_STATS.Speed_MaxRound - 1), 0, 1)
	local hProgress = math.clamp((round - 1) / (Z_STATS.Health_MaxRound - 1), 0, 1)
	local dProgress = math.clamp((round - Z_STATS.Damage_StartRound) / (Z_STATS.Damage_MaxRound - Z_STATS.Damage_StartRound), 0, 1)

	return {
		speed = math.floor(Z_STATS.Speed_Base + (Z_STATS.Speed_Max - Z_STATS.Speed_Base) * sProgress),
		health = math.floor(Z_STATS.Health_Base + (Z_STATS.Health_Max - Z_STATS.Health_Base) * hProgress),
		damage = round < Z_STATS.Damage_StartRound and Z_STATS.Damage_Base or math.floor(Z_STATS.Damage_Base + (Z_STATS.Damage_Max - Z_STATS.Damage_Base) * dProgress)
	}
end

-- Vérifie si une planche est encore intacte et solidement attachée à la fenêtre
local function isPlankAlive(plank)
	return plank and plank.Parent and plank.Transparency < 0.1 and plank.Anchored == true
end

-- Nettoie la mémoire en supprimant les références internes aux planches qui ont été détruites
local function clearDeadPlankReferences(state, plankName, windowName)
	for plank, _ in pairs(state.planks) do
		if plank.Name == plankName and not isPlankAlive(plank) then
			state.planks[plank] = nil
		end
	end
end

-- Gère la logique de dégâts infligés par un zombie à une planche, incluant sa destruction visuelle et physique
local function hitPlank(window, plank)
	local state = windowStates[window]
	if not state or not plank or not state.planks[plank] then return end
	if state.planks[plank] <= 0 then return end

	state.planks[plank] -= 1

	if state.planks[plank] <= 0 then
		state.planks[plank] = nil 

		local brokenSound = plank:FindFirstChild("Broken")
		if brokenSound then brokenSound:Play() end

		TweenService:Create(plank, TweenInfo.new(0.4, Enum.EasingStyle.Linear), {Transparency = 1}):Play()

		task.delay(0.4, function()
			if plank and plank.Parent then
				plank.Anchored = false
				task.delay(2, function()
					if plank and plank.Parent then plank:Destroy() end
				end)
			end
		end)

		local anyAlive = false
		for p, hits in pairs(state.planks) do
			if isPlankAlive(p) and (hits or 0) > 0 then
				anyAlive = true
				break
			end
		end

		if not anyAlive then 
			state.isOpen = true 
		end
	end
end

-- Permet à un joueur de reconstruire une seule planche manquante sur une barricade spécifique
function WindowManager.repairOnePlank(window)
	local state = windowStates[window]
	if not state then return false end
	local plankTemplate = ServerStorage:FindFirstChild("Plank")
	if not plankTemplate then return false end

	local currentPlanks = {}
	for _, child in ipairs(window:GetChildren()) do
		if (child.Name == "Plank1" or child.Name == "Plank2" or child.Name == "Plank3") and isPlankAlive(child) then
			currentPlanks[child.Name] = child
		end
	end

	local nameToRepair = nil
	for _, name in ipairs(PLANK_NAMES) do
		if not currentPlanks[name] then
			nameToRepair = name
			break
		end
	end

	if not nameToRepair then 
		return false 
	end

	for _, child in ipairs(window:GetChildren()) do
		if child.Name == nameToRepair then
			child:Destroy()
		end
	end
	clearDeadPlankReferences(state, nameToRepair, window.Name)

	local newPlank = plankTemplate:Clone()
	newPlank.Name = nameToRepair

	if state.plankCFrames[nameToRepair] then
		newPlank.CFrame = state.plankCFrames[nameToRepair]
	end

	newPlank.Parent = window
	newPlank.Transparency = 0
	newPlank.Anchored = true
	newPlank.CanCollide = true

	state.planks[newPlank] = PLANK_HITS_REQUIRED
	state.isOpen = false 

	return true
end

-- Recherche un point de passage disponible pour qu'un zombie puisse franchir la fenêtre
local function findFreeTravers(state, traversPoints, windowName)
	for _, travers in ipairs(traversPoints) do
		if not state.traversOccupied[travers] then return travers end
	end
	return nil
end

local processQueue

-- Contrôle la séquence complète d'un zombie à une fenêtre : positionnement, destruction des planches, et franchissement
local function activateZombie(zombie, assignedTravers, window, state, traversPoints, activeZombies, onDone, targetSpeed)
	local humanoid = zombie:FindFirstChildOfClass("Humanoid")
	if not humanoid then onDone(); return end

	local animateScript = zombie:FindFirstChild("AnimateRobot")
	local msgValue = animateScript and animateScript:FindFirstChild("msg")
	local rootPart = zombie:FindFirstChild("HumanoidRootPart")
	if not rootPart or not assignedTravers then onDone(); return end

	local function setAnim(name)
		if not msgValue then return end
		msgValue.Value = ""
		task.wait(0.05)
		msgValue.Value = name
	end

	local alignPos = assignedTravers.Position + Vector3.new(0, 3, 0)
	local alignLookAt = Vector3.new(
		(alignPos + assignedTravers.CFrame.LookVector * 10).X,
		alignPos.Y,
		(alignPos + assignedTravers.CFrame.LookVector * 10).Z
	)

	zombie:PivotTo(CFrame.lookAt(alignPos, alignLookAt))
	setAnim("idle")

	-- Boucle d'attaque du zombie tant que la fenêtre n'est pas complètement ouverte
	while not state.isOpen do
		local targetPlank = nil
		for plank, hitsLeft in pairs(state.planks) do
			if hitsLeft > 0 and isPlankAlive(plank) then targetPlank = plank; break end
		end

		if not targetPlank then 
			break 
		end

		task.wait(1.5)
		if not zombie or not zombie.Parent then onDone(); return end
		if state.isOpen then break end
		if not state.planks[targetPlank] or state.planks[targetPlank] <= 0 or not targetPlank.Parent then continue end

		setAnim(PUNCH_ANIMS[math.random(1, #PUNCH_ANIMS)])

		local head = zombie:FindFirstChild("Head")
		if head then
			local s = head:FindFirstChild(PUNCH_SOUNDS[math.random(1, #PUNCH_SOUNDS)])
			if s then s:Play() end
		end

		task.wait(0.3)
		if not state.isOpen and state.planks[targetPlank] and state.planks[targetPlank] > 0 and isPlankAlive(targetPlank) then
			hitPlank(window, targetPlank)
		end
	end

	task.wait(0.5)
	if not zombie or not zombie.Parent then onDone(); return end

	-- Séquence de franchissement de la fenêtre (saut de barrière)
	rootPart.Anchored = true
	zombie:PivotTo(CFrame.lookAt(zombie:GetPivot().Position, alignLookAt))
	setAnim("walk")

	local dist = (rootPart.Position - alignPos).Magnitude
	local tweenTime = math.max(0.2, dist / 8)
	TweenService:Create(rootPart, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(alignPos, alignLookAt)
	}):Play()
	task.wait(tweenTime)

	setAnim("barrierjump")
	task.wait(0.6)

	TweenService:Create(rootPart, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {
		CFrame = rootPart.CFrame * CFrame.new(0, 0, -5.5)
	}):Play()
	task.wait(0.2)

	if zombie and zombie.Parent then
		rootPart.Anchored = false
		if rootPart:CanSetNetworkOwnership() then
			rootPart:SetNetworkOwner(nil)
		end
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.WalkSpeed = targetSpeed or 16
		humanoid:Move(rootPart.CFrame.LookVector)
	end

	humanoid.Died:Connect(function()
		state.traversOccupied[assignedTravers] = nil
		processQueue(state, traversPoints, window, activeZombies)
	end)

	onDone()
end

-- Gère la file d'attente des zombies assignés à une fenêtre pour éviter qu'ils ne se superposent
processQueue = function(state, traversPoints, window, activeZombies, round)
	for i = #state.queue, 1, -1 do
		if not state.queue[i].zombie or not state.queue[i].zombie.Parent then
			table.remove(state.queue, i)
		end
	end

	for i = 1, #state.queue do
		local entry = state.queue[i]
		if not entry.zombie or not entry.zombie.Parent then continue end

		local freeTravers = findFreeTravers(state, traversPoints, window.Name)
		if not freeTravers then break end

		state.traversOccupied[freeTravers] = entry.zombie
		state.activeCount += 1

		local stats = calculateStats(round or 1)

		table.remove(state.queue, i)

		task.spawn(function()
			activateZombie(entry.zombie, freeTravers, window, state, traversPoints, activeZombies, function()
				state.traversOccupied[freeTravers] = nil
				state.activeCount = math.max(0, state.activeCount - 1)
				processQueue(state, traversPoints, window, activeZombies, round) 
			end, stats.speed) 
		end)
		break
	end
end

-- Initialise toutes les fenêtres de la carte au démarrage, configure les planches et crée les interactions de réparation
function WindowManager.initWindows()
	if isInitialized then return end
	isInitialized = true

	if not windowFolder then return end

	task.wait(1) 

	local windows = windowFolder:GetChildren()

	for _, window in ipairs(windows) do
		if not window:IsA("Model") then continue end

		local planks, plankCFrames = {}, {}
		local countFound = 0

		for _, child in ipairs(window:GetChildren()) do
			if child.Name == "Plank1" or child.Name == "Plank2" or child.Name == "Plank3" then
				planks[child] = PLANK_HITS_REQUIRED
				plankCFrames[child.Name] = child.CFrame
				child.Transparency = 0
				child.Anchored = true
				countFound += 1
			end
		end

		windowStates[window] = {
			planks = planks, 
			plankCFrames = plankCFrames,
			isOpen = false, 
			activeCount = 0,
			queue = {}, 
			maxTotal = 5,
			traversOccupied = {},
		}

		local promptPart = window:FindFirstChild("PromptPart") or window:FindFirstChild("SpawnZombie") or window:FindFirstChild("Travers")
		if promptPart then
			local prompt = promptPart:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
			prompt.ActionText = "Repair Plank"
			prompt.ObjectText = "Window"
			prompt.HoldDuration = 1.2
			prompt.RequiresLineOfSight = false
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt.MaxActivationDistance = 15
			prompt.Parent = promptPart

			prompt.Triggered:Connect(function(player)
				if WindowManager.repairOnePlank(window) then
					local argent = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Argent")
					if argent then argent.Value += 40 end
					repairEvent:FireClient(player)
				end
			end)
		end
	end
end

-- Fait apparaître un nouveau zombie derrière une fenêtre spécifique et l'ajoute à la file d'attente
local function spawnWindowZombie(window, activeZombies, round)
	local state = windowStates[window]
	if not state then return end
	if state.activeCount + #state.queue >= state.maxTotal then return end

	local mainSpawnPoint = window:FindFirstChild("SpawnZombie")
	local traversPoints = {}
	for _, child in ipairs(window:GetChildren()) do
		if child.Name:match("Travers") then table.insert(traversPoints, child) end
	end
	if not mainSpawnPoint or #traversPoints == 0 then return end

	local zombie = cyborgTemplate:Clone()
	local humanoid = zombie:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local stats = calculateStats(round or 1)
	humanoid.MaxHealth = stats.health
	humanoid.Health = stats.health
	zombie:SetAttribute("CurrentDamage", stats.damage)
	humanoid.WalkSpeed = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	zombie:PivotTo(CFrame.new(mainSpawnPoint.Position + Vector3.new(math.random(-2,2), 3, math.random(-2,2))))
	zombie.Parent = workspace

	table.insert(activeZombies, zombie)
	table.insert(state.queue, {zombie = zombie})
	processQueue(state, traversPoints, window, activeZombies, round)
end

-- Sélectionne dynamiquement les fenêtres actives proches des joueurs pour y faire apparaître des groupes de zombies
function WindowManager.spawnWindowZombies(count, activeZombies, gameRunningRef, spawnInterval, onSpawned, round)
	local playerPositions = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChild("Humanoid")
			if hrp and hum and hum.Health > 0 then
				table.insert(playerPositions, hrp.Position)
			end
		end
	end

	local function isDoorOpen(doorName)
		local door = workspace:FindFirstChild(doorName, true)
		if not door then return true end
		return door:GetAttribute("isOpen") == true
	end

	local isStarterDoorClosed = not isDoorOpen("PorteLaserMotel")

	-- Filtrage des fenêtres disponibles selon la progression des portes et la proximité avec les joueurs
	local allWindows, validWindows = {}, {}
	for _, window in ipairs(windowFolder:GetChildren()) do
		if not window:IsA("Model") then continue end
		if isStarterDoorClosed and not STARTER_WINDOWS[window.Name] then
			continue
		end

		table.insert(allWindows, window)
		local wPos = window:GetPivot().Position
		for _, pPos in ipairs(playerPositions) do
			if (wPos - pPos).Magnitude <= 200 then
				table.insert(validWindows, window); break
			end
		end
	end

	if #validWindows == 0 then validWindows = allWindows end
	if #validWindows == 0 then return end

	for i = 1, count do
		if not gameRunningRef() then break end
		local attempts = 0
		local spawned = false
		while not spawned and attempts < 10 do
			local window = validWindows[math.random(1, #validWindows)]
			local state = windowStates[window]
			if state and state.activeCount + #state.queue < state.maxTotal then
				spawnWindowZombie(window, activeZombies, round)
				spawned = true
			end
			attempts += 1
		end

		if not spawned then
			task.wait(3)
			i -= 1
			continue
		end

		if onSpawned then onSpawned() end
		task.wait(spawnInterval * 1.5)
	end
end

return WindowManager