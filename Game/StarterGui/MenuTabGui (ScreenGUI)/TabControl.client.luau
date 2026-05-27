-- ============================================================
-- Ce script (Main) est le gestionnaire de la mini-carte (MinimapGUI).
-- Il s'appuie sur l'arborescence suivante :
-- - "MiniMap" : un ViewportFrame utilisé pour rendre la carte en 3D.
-- - "3D" : une BoolValue qui, si activée, incline l'interface pour un effet de perspective.
-- - "UICorner" : cloné et appliqué au ViewportFrame pour arrondir ses angles.
-- Le script génère dynamiquement un balayage radar, repère les ennemis (points rouges)
-- et affiche les points d'intérêt (atouts, portes) grâce à des attributs.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- Attente du chargement complet du jeu avant d'initialiser la carte
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Délai de sécurité pour s'assurer que toutes les pièces du MapFolder sont répliquées au client
task.wait(1)

local MapModule = require(ReplicatedStorage:WaitForChild("MinimapHandler"))
local Screen3D = require(ReplicatedStorage:WaitForChild("Screen3D"))
local PlrIndicator = ReplicatedStorage:WaitForChild("PlayerIndicator")
local CarIndicator = ReplicatedStorage:WaitForChild("VehicleIndicator")

local MapLoadedEvent = ReplicatedStorage:WaitForChild("MapLoadedEvent", 10)

-- Utilisation de WaitForChild pour garantir la présence du dossier de la carte
local MapFolder = workspace:WaitForChild("MapFolder", 10)

local Icons = {
	IconRoue = "rbxassetid://71396479410386",
	IconWeaponUpgrade = "rbxassetid://103468290994414",
	IconBubbleGum = "rbxassetid://122185496428438",
	IconWeapon = "rbxassetid://130972901559849",
	IconBarriere = "rbxassetid://115521194552320"
}

-- Génération des modèles d'icônes avec un Decal (compatible avec le ViewportFrame de la minimap)
local POITemplates = {}
for name, id in pairs(Icons) do
	local template = Instance.new("Part")
	template.Name = name .. "_Template"

	-- Définition de la taille de l'icône sur la carte
	template.Size = Vector3.new(90, 0.1, 60) 

	template.Transparency = 1
	template.Anchored = true
	template.CanCollide = false

	-- Le Decal est utilisé car c'est une texture 3D qui s'affiche correctement dans les ViewportFrames
	local decal = Instance.new("Decal")
	decal.Name = "IconDecal"
	decal.Texture = id
	decal.Face = Enum.NormalId.Top
	decal.Parent = template

	POITemplates[name] = template
end

local All = script.Parent 
local Player = Players.LocalPlayer

repeat task.wait() until Player.Character 
repeat task.wait() until script.Parent:WaitForChild("MiniMap")

local Viewport = All:FindFirstChild("MiniMap")
local ViewIn3D = All:FindFirstChild("3D")
local Character = Player.Character

---------------------------------------------------------
-- CRÉATION DU POINT ROUGE 3D POUR LES ZOMBIES
---------------------------------------------------------
local RedDotTemplate = Instance.new("Part")
RedDotTemplate.Name = "ZombieIndicator"
RedDotTemplate.Shape = Enum.PartType.Ball
RedDotTemplate.Size = Vector3.new(10, 10, 10) 
RedDotTemplate.Color = Color3.new(1, 0, 0)
RedDotTemplate.Material = Enum.Material.Neon
RedDotTemplate.Anchored = true
RedDotTemplate.CanCollide = false
RedDotTemplate.CastShadow = false
RedDotTemplate.Transparency = 1 

local ActiveZombies = {} 

---------------------------------------------------------
-- CRÉATION DE LA LIGNE RADAR (VERTICALE AVEC FADE)
---------------------------------------------------------
local RadarLine = Instance.new("Frame")
RadarLine.Name = "RadarSweep"
RadarLine.Size = UDim2.new(0, 2, 1, 0) 
RadarLine.AnchorPoint = Vector2.new(0.5, 0.5)
RadarLine.Position = UDim2.new(0, 0, 0.5, 0) 
RadarLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255) 
RadarLine.BackgroundTransparency = 1 
RadarLine.BorderSizePixel = 0 
RadarLine.ZIndex = 50
RadarLine.Parent = Viewport
RadarLine.Visible = false 

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(0, 180, 255)
UIStroke.Thickness = 1.5
UIStroke.Transparency = 1 
UIStroke.Parent = RadarLine

-- Mise en cache du TweenInfo pour optimisation
local revealTweenInfo = TweenInfo.new(0.5)

-- Fonction pour révéler un point sur le radar
local function RevealDot(dot)
	if not dot or not dot.Parent then return end

	dot.Transparency = 0 
	local revealId = tick() 
	dot:SetAttribute("RevealId", revealId)

	task.delay(1.5, function()
		if dot and dot.Parent and dot:GetAttribute("RevealId") == revealId then
			TweenService:Create(dot, revealTweenInfo, {Transparency = 1}):Play()
		end
	end)
end

---------------------------------------------------------
-- BOUCLE DE SCAN DU RADAR
---------------------------------------------------------
local sweepDuration = 0.6
local pauseDuration = 3.0
local fadeTime = 0.2     
local totalTimer = 0
local hasTriggeredThisScan = false 

RunService.Heartbeat:Connect(function(deltaTime)
	totalTimer += deltaTime
	local cycleTime = sweepDuration + pauseDuration
	local currentTime = totalTimer % cycleTime

	-- Mise à jour de l'interface uniquement pendant la phase de balayage
	if currentTime < sweepDuration then
		if not RadarLine.Visible then
			RadarLine.Visible = true
		end

		local progress = currentTime / sweepDuration
		RadarLine.Position = UDim2.new(progress, 0, 0.5, 0)

		local targetTransparency = 1
		if currentTime <= fadeTime then
			targetTransparency = 1 - (currentTime / fadeTime)
		elseif currentTime >= (sweepDuration - fadeTime) then
			local timeInFadeOut = currentTime - (sweepDuration - fadeTime)
			targetTransparency = timeInFadeOut / fadeTime
		else
			targetTransparency = 0
		end

		RadarLine.BackgroundTransparency = targetTransparency
		UIStroke.Transparency = targetTransparency

		-- Déclenchement de la révélation des points au milieu du balayage
		if progress >= 0.5 and not hasTriggeredThisScan then
			hasTriggeredThisScan = true 

			-- Boucle inversée pour permettre la suppression sécurisée d'éléments
			for i = #ActiveZombies, 1, -1 do
				local data = ActiveZombies[i]
				if data.Root and data.Root.Parent then
					RevealDot(data.Dot)
				else
					table.remove(ActiveZombies, i)
				end
			end
		end
	else
		if RadarLine.Visible then
			RadarLine.Visible = false
			hasTriggeredThisScan = false 
		end
	end
end)

---------------------------------------------------------
-- INITIALISATION & SUIVI DES ENTITÉS
---------------------------------------------------------
local poiCounter = 0 

-- Configuration du suivi des zombies
local function SetupRobotTracking(minimap, is3D)
	local function TrackRobot(robot)
		if robot:IsA("Model") and string.match(robot.Name, "^ZombieRobot") then
			local rootPart = robot:FindFirstChild("HumanoidRootPart") or robot.PrimaryPart

			if rootPart then
				poiCounter += 1
				local uniqueId = robot.Name .. "_Dot_" .. tostring(poiCounter)

				local indicator = minimap:AddIndicator(uniqueId, RedDotTemplate, rootPart)
				indicator.AlwaysOnTop = true
				if is3D then indicator.Camera = workspace.CurrentCamera end

				table.insert(ActiveZombies, {Root = rootPart, Dot = indicator.Indicator})

				robot.Destroying:Connect(function()
					minimap:RemoveIndicator(uniqueId)
				end)
			end
		end
	end

	-- Recherche initiale à la racine du workspace
	for _, child in ipairs(workspace:GetChildren()) do 
		TrackRobot(child) 
	end

	-- Écoute des ajouts ultérieurs
	workspace.ChildAdded:Connect(function(child) 
		task.wait(0.5) 
		TrackRobot(child) 
	end)
end

-- Applique le composant UICorner au parent spécifié
local function ApplyCorner(parent)
	local corner = script:FindFirstChild("UICorner")
	if corner then 
		local clone = corner:Clone()
		clone.Parent = parent 
	end
end

---------------------------------------------------------
-- SETUP DES POINTS D'INTÉRÊT (POI)
---------------------------------------------------------
local function SetupPOITracking(minimap, is3D)
	local function CheckAndAddPOI(item)
		if item:IsA("BasePart") or item:IsA("Model") then
			local iconType = item:GetAttribute("MinimapIcon")

			if iconType and POITemplates[iconType] then
				poiCounter += 1
				local uniqueId = item.Name .. "_" .. tostring(poiCounter)

				local indicator = minimap:AddIndicator(uniqueId, POITemplates[iconType], item)
				indicator.AlwaysOnTop = true
				indicator.RotOffset = Vector3.new(0, 180, 0)

				if is3D then indicator.Camera = workspace.CurrentCamera end

				local targetPart = item:IsA("BasePart") and item or item.PrimaryPart
				if targetPart then
					if iconType == "IconRoue" then
						indicator.Visible = true
					else
						indicator.Visible = targetPart.CanCollide
						targetPart:GetPropertyChangedSignal("CanCollide"):Connect(function()
							indicator.Visible = targetPart.CanCollide
						end)
					end
				end
			end
		end
	end

	-- Recherche dans le MapFolder
	if MapFolder then
		for _, item in ipairs(MapFolder:GetDescendants()) do
			CheckAndAddPOI(item)
		end

		MapFolder.DescendantAdded:Connect(function(child)
			task.wait(0.5) 
			CheckAndAddPOI(child)
		end)
	end

	-- Recherche à la racine du workspace
	for _, item in ipairs(workspace:GetChildren()) do
		CheckAndAddPOI(item)
	end

	workspace.ChildAdded:Connect(function(child)
		task.wait(0.5)
		CheckAndAddPOI(child)
	end)
end

-- Fonction d'initialisation principale
local function Init()
	local Minimap = MapModule.new(Viewport, Vector3.new(0, 300, 0), MapFolder)
	ApplyCorner(Viewport)

	Viewport.Ambient = Color3.fromRGB(150, 150, 150) 
	Viewport.LightColor = Color3.fromRGB(255, 255, 255) 
	Viewport.ImageColor3 = Color3.fromRGB(255, 240, 220)

	Minimap.Flatten = false 
	Minimap.HideObstructed = false 
	Minimap.FPSCap = 30 

	-- Actualise le rendu initial de la carte
	Minimap:Refresh()

	-- Indique au système que la carte est prête
	if MapLoadedEvent then
		MapLoadedEvent:Fire()
	end

	local is3D = ViewIn3D and ViewIn3D.Value
	if is3D then
		task.wait(1.5)
		local GUI3D = Screen3D.new(All, 5)
		local Frame3D = GUI3D:GetComponent3D(Viewport)

		Frame3D:Enable()
		Frame3D.offset = CFrame.Angles(0, -0.22, 0)
		Viewport.CurrentCamera.FieldOfView = 55
		Minimap.TrackerCamera = workspace.CurrentCamera
	end

	Minimap.TrackerPart = Character.PrimaryPart
	Minimap:Track(Minimap.TrackModes.FullTrack, is3D, 0.3)

	local CharIndicator = Minimap:AddIndicator(Character.Name, PlrIndicator, Character.PrimaryPart)
	CharIndicator.AlwaysOnTop = true
	if is3D then CharIndicator.Camera = workspace.CurrentCamera end

	SetupRobotTracking(Minimap, is3D)
	SetupPOITracking(Minimap, is3D)
end

Init()