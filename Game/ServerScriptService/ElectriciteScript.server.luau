-- ============================================================
-- Ce script gère le système de coupure de courant globale (celà coupe la lumière, les bubblegum et les stand d'amélioration d'arme)
-- ainsi que le mini-jeu de réparation des panneaux électriques.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

local REMOTES_FOLDER_NAME = "SkillCheckRemotes"
local COLOR_NAMES = { "Red", "Green", "Blue", "Yellow" }
local LEFT_BUTTON_NAMES = { "LW1", "LW2", "LW3", "LW4" }
local RIGHT_BUTTON_NAMES = { "RW1", "RW2", "RW3", "RW4" }

local remotesFolder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME) or Instance.new("Folder", ReplicatedStorage)
remotesFolder.Name = REMOTES_FOLDER_NAME

-- Récupère ou crée un RemoteEvent pour la communication client-serveur
local function getOrCreateRemote(name)
	local remote = remotesFolder:FindFirstChild(name) or Instance.new("RemoteEvent", remotesFolder)
	remote.Name = name
	return remote
end

local startSkillCheckRemote = getOrCreateRemote("StartSkillCheck")
local submitAttemptRemote = getOrCreateRemote("SubmitSkillCheckAttempt")
local skillCheckStateRemote = getOrCreateRemote("SkillCheckState")

local powerEvent = ReplicatedStorage:FindFirstChild("PowerEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
powerEvent.Name = "PowerEvent"

local playerLoadedEvent = ReplicatedStorage:FindFirstChild("PlayerLoaded") or Instance.new("RemoteEvent", ReplicatedStorage)
playerLoadedEvent.Name = "PlayerLoaded"

local cutPowerEvent = ServerStorage:FindFirstChild("CutPowerEvent") or Instance.new("BindableEvent", ServerStorage)
cutPowerEvent.Name = "CutPowerEvent"

local MachinesAActiver = {
	"BubbleGumDoubleSaut", "BubbleGumSeringue", "BubbleGumHeal",
	"BubbleGumRevive", "BubbleGumSpeed", "StandAmeliorationArmeChargeur", 
	"StandAmeliorationArmePenetration", "StandAmeliorationArmeDamage"
}

local panneauxFolder = workspace:WaitForChild("Panneaux")
local listePanneaux = {}
local popwer_sound = game:GetService("SoundService"):WaitForChild("PowerON")

for _, panneau in ipairs(panneauxFolder:GetChildren()) do
	local powerBox = panneau:WaitForChild("Power Box")
	local panel = powerBox:WaitForChild("Panel")
	local promptPart = panel:WaitForChild("PromptPart")
	local prompt = promptPart:WaitForChild("ProximityPrompt")

	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Fix the wire"
	prompt.ObjectText = "Power Box"
	prompt.Enabled = false

	table.insert(listePanneaux, {
		modele = panneau,
		panelPart = panel,
		prompt = prompt,
		s0 = promptPart:FindFirstChild("Sound0s"),
		s1 = promptPart:FindFirstChild("Sound1s"),
		s2 = promptPart:FindFirstChild("Sound2s"),
		ledRouge = powerBox:WaitForChild("LedRouge"):WaitForChild("Led"),
		ledVerte = powerBox:WaitForChild("LedVerte"):WaitForChild("Led")
	})
end

local batteryGui = Instance.new("BillboardGui")
batteryGui.Name = "NeedPowerGui"
batteryGui.Size = UDim2.new(0, 100, 0, 100)
batteryGui.StudsOffset = Vector3.new(0, 4, 0)
batteryGui.AlwaysOnTop = true
batteryGui.Enabled = false

local batteryImage = Instance.new("ImageLabel", batteryGui)
batteryImage.Size = UDim2.new(1, 0, 1, 0)
batteryImage.BackgroundTransparency = 1
batteryImage.Image = "rbxassetid://101880017270274"
batteryImage.Rotation = 90

local mapFolder = workspace:WaitForChild("MapFolder")
local defaultAmbient, defaultOutdoorAmbient, defaultBrightness = Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness
local darkAmbient, darkOutdoorAmbient, darkBrightness = Color3.fromRGB(130, 130, 130), Color3.fromRGB(130, 130, 130), 1

local toutesLesLumieres, toutesLesNeons, tousLesBeams = {}, {}, {}
local isPowerOn, panneauActif, activeSessions = true, nil, {}

-- Retourne la liste des panneaux interactifs selon les conditions de portes ouvertes
local function getAccessiblePanneaux()
	local accessible = {}
	local function isDoorOpen(doorName)
		local door = workspace:FindFirstChild(doorName, true)
		return door and door:GetAttribute("isOpen") == true
	end

	local pMap = {}
	for _, pd in ipairs(listePanneaux) do pMap[pd.modele.Name] = pd end

	if isDoorOpen("PorteLaserMotel") then table.insert(accessible, pMap["PanneauElectrique3"]) end
	if isDoorOpen("PorteLaserHouse") or isDoorOpen("PorteLaserHouse2") then table.insert(accessible, pMap["PanneauElectrique2"]) end
	if isDoorOpen("PorteLaserMotel2") or isDoorOpen("PorteLaserMotel3") then table.insert(accessible, pMap["PanneauElectrique1"]) end
	if isDoorOpen("PorteLaserPiscine") or isDoorOpen("PorteLaserChill2") then table.insert(accessible, pMap["PanneauElectrique4"]) end
	if isDoorOpen("PorteLaserPolice") then table.insert(accessible, pMap["PanneauElectrique5"]) end

	return accessible
end

-- Mélange les éléments d'une table
local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Crée un mélange sans qu'aucun élément ne soit à sa place d'origine
local function buildDerangement(sourceList)
	local shuffled = {}
	for i, v in ipairs(sourceList) do shuffled[i] = v end
	repeat
		shuffle(shuffled)
		local valid = true
		for i, color in ipairs(shuffled) do
			if color == sourceList[i] then valid = false break end
		end
	until valid
	return shuffled
end

-- Initialise une nouvelle session de mini-jeu avec des correspondances de couleurs
local function createSession()
	local leftColors = shuffle({unpack(COLOR_NAMES)})
	local rightColors = buildDerangement(leftColors)
	local session = { leftColors = {}, rightColors = {}, matchedLeftToRight = {}, matchedRightToLeft = {}, matchCount = 0 }

	for i, name in ipairs(LEFT_BUTTON_NAMES) do session.leftColors[name] = leftColors[i] end
	for i, name in ipairs(RIGHT_BUTTON_NAMES) do session.rightColors[name] = rightColors[i] end
	return session
end

-- Envoie l'état actuel de la session au client via RemoteEvent
local function sendState(player, session, result)
	local matched = {}
	for l, r in pairs(session.matchedLeftToRight) do matched[l] = r end
	skillCheckStateRemote:FireClient(player, { result = result, matched = matched, matchCount = session.matchCount })
end

-- Inflige des dégâts au joueur
local function damagePlayer(player, amount)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then hum:TakeDamage(amount) end
end

-- Joue la séquence visuelle et sonore de rétablissement du courant
local function triggerPowerOnCinematic()
	isPowerOn = true
	for _, pd in ipairs(listePanneaux) do pd.prompt.Enabled = false end

	popwer_sound:Play()
	powerEvent:FireAllClients("PowerTurnedOn")
	batteryGui.Enabled = false

	for _, pd in ipairs(listePanneaux) do
		pd.ledRouge.Color, pd.ledRouge.Material = Color3.fromRGB(99, 95, 98), Enum.Material.SmoothPlastic
		if pd.ledRouge:FindFirstChildOfClass("PointLight") then pd.ledRouge:FindFirstChildOfClass("PointLight"):Destroy() end
		pd.ledVerte.Color, pd.ledVerte.Material = Color3.fromRGB(0, 255, 0), Enum.Material.Neon
		if not pd.ledVerte:FindFirstChildOfClass("PointLight") then
			local light = Instance.new("PointLight", pd.ledVerte)
			light.Color, light.Brightness, light.Range = Color3.fromRGB(0, 255, 0), 8, 4
		end
	end

	Lighting.Ambient = defaultAmbient
	Lighting.OutdoorAmbient = defaultOutdoorAmbient
	Lighting.Brightness = defaultBrightness

	for _, l in ipairs(toutesLesLumieres) do l.Enabled = true end
	for _, b in ipairs(tousLesBeams) do b.Enabled = true end
	for _, n in ipairs(toutesLesNeons) do n.Material = Enum.Material.Neon end

	for _, nom in ipairs(MachinesAActiver) do
		local m = workspace:FindFirstChild(nom, true)
		if m then
			m:SetAttribute("PowerOn", true)
			local l1 = m:FindFirstChild("Gums") and m.Gums:FindFirstChild("Sphere") and m.Gums.Sphere:FindFirstChildOfClass("PointLight")
			local l2 = m:FindFirstChild("Table") and m.Table:FindFirstChild("Table2") and m.Table.Table2:FindFirstChild("Table3") and m.Table.Table2.Table3:FindFirstChild("Pen") and m.Table.Table2.Table3.Pen:FindFirstChildOfClass("PointLight")
			if l1 then l1.Enabled = true end
			if l2 then l2.Enabled = true end
		end
	end
end

-- Coupe le courant et active le panneau nécessaire
local function turnOffPower()
	if not isPowerOn and panneauActif then return end
	isPowerOn = false

	local accessibles = getAccessiblePanneaux()
	if #accessibles == 0 then return end
	panneauActif = accessibles[math.random(1, #accessibles)]

	batteryGui.Adornee, batteryGui.Parent, batteryGui.Enabled = panneauActif.panelPart, panneauActif.panelPart, true

	for _, nom in ipairs(MachinesAActiver) do
		local m = workspace:FindFirstChild(nom, true)
		if m then
			m:SetAttribute("PowerOn", false)
			local l1 = m:FindFirstChild("Gums") and m.Gums:FindFirstChild("Sphere") and m.Gums.Sphere:FindFirstChildOfClass("PointLight")
			local l2 = m:FindFirstChild("Table") and m.Table:FindFirstChild("Table2") and m.Table.Table2:FindFirstChild("Table3") and m.Table.Table2.Table3:FindFirstChild("Pen") and m.Table.Table2.Table3.Pen:FindFirstChildOfClass("PointLight")
			if l1 then l1.Enabled = false end
			if l2 then l2.Enabled = false end
		end
	end

	if #toutesLesLumieres == 0 then
		for _, obj in ipairs(mapFolder:GetDescendants()) do
			if obj:IsA("Light") then table.insert(toutesLesLumieres, obj)
			elseif obj:IsA("BasePart") and obj.Material == Enum.Material.Neon then table.insert(toutesLesNeons, obj)
			elseif obj:IsA("Beam") then table.insert(tousLesBeams, obj) end
		end
	end

	Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness = darkAmbient, darkOutdoorAmbient, darkBrightness
	for _, l in ipairs(toutesLesLumieres) do l.Enabled = false end
	for _, b in ipairs(tousLesBeams) do b.Enabled = false end
	for _, n in ipairs(toutesLesNeons) do n.Material = Enum.Material.SmoothPlastic end

	for _, pData in ipairs(listePanneaux) do
		pData.prompt.Enabled = (pData == panneauActif)
		pData.ledRouge.Color, pData.ledRouge.Material = Color3.fromRGB(255, 0, 0), Enum.Material.Neon
		if not pData.ledRouge:FindFirstChildOfClass("PointLight") then
			local l = Instance.new("PointLight", pData.ledRouge)
			l.Color, l.Brightness, l.Range = Color3.fromRGB(255, 0, 0), 8, 4
		end
		pData.ledVerte.Color, pData.ledVerte.Material = Color3.fromRGB(99, 95, 98), Enum.Material.SmoothPlastic
		if pData.ledVerte:FindFirstChildOfClass("PointLight") then pData.ledVerte:FindFirstChildOfClass("PointLight"):Destroy() end
	end

	powerEvent:FireAllClients("PowerTurnedOff")
end

-- Initialisation visuelle des panneaux au lancement
for _, pData in ipairs(listePanneaux) do
	pData.prompt.Enabled = false
	pData.ledRouge.Color, pData.ledRouge.Material = Color3.fromRGB(99, 95, 98), Enum.Material.SmoothPlastic
	pData.ledVerte.Color, pData.ledVerte.Material = Color3.fromRGB(0, 255, 0), Enum.Material.Neon
	if not pData.ledVerte:FindFirstChildOfClass("PointLight") then
		local l = Instance.new("PointLight", pData.ledVerte)
		l.Color, l.Brightness, l.Range = Color3.fromRGB(0, 255, 0), 8, 4
	end
end

-- Déclenche la coupure initiale 5 secondes après le chargement du premier joueur
local hasPowerCut = false
playerLoadedEvent.OnServerEvent:Connect(function()
	if not hasPowerCut then
		hasPowerCut = true
		task.delay(5, turnOffPower)
	end
end)

-- Écoute les demandes externes de coupure de courant
cutPowerEvent.Event:Connect(turnOffPower)

-- Gère les interactions (maintien et déclenchement) avec les panneaux
for _, pData in ipairs(listePanneaux) do
	local isHolding = false
	pData.prompt.PromptButtonHoldBegan:Connect(function()
		isHolding = true
		task.spawn(function()
			if isHolding and pData.s0 then pData.s0:Play() end
			task.wait(1)
			if isHolding and pData.s1 then pData.s1:Play() end
			task.wait(1)
			if isHolding and pData.s2 then pData.s2:Play() end
		end)
	end)

	pData.prompt.PromptButtonHoldEnded:Connect(function()
		isHolding = false
		if pData.s0 then pData.s0:Stop() end
		if pData.s1 then pData.s1:Stop() end
		if pData.s2 then pData.s2:Stop() end
	end)

	pData.prompt.Triggered:Connect(function(player)
		if activeSessions[player] or isPowerOn then return end
		local session = createSession()
		activeSessions[player] = session
		startSkillCheckRemote:FireClient(player, { leftColors = session.leftColors, rightColors = session.rightColors })
		sendState(player, session, "started")
	end)
end

-- Vérifie les entrées du joueur lors du mini-jeu
submitAttemptRemote.OnServerEvent:Connect(function(player, left, right)
	local session = activeSessions[player]
	if not session or type(left) ~= "string" or type(right) ~= "string" then return end

	if left == "Cancel" then
		activeSessions[player] = nil
		return
	end

	if session.leftColors[left] ~= session.rightColors[right] or session.matchedLeftToRight[left] then
		damagePlayer(player, 10)
		sendState(player, session, "miss")
		activeSessions[player] = nil
		return
	end

	session.matchedLeftToRight[left] = right
	session.matchCount += 1

	if session.matchCount >= #LEFT_BUTTON_NAMES then
		triggerPowerOnCinematic()
		activeSessions[player] = nil
	else
		sendState(player, session, "matched")
	end
end)

-- Supprime la session du joueur lorsqu'il quitte
Players.PlayerRemoving:Connect(function(player) activeSessions[player] = nil end)