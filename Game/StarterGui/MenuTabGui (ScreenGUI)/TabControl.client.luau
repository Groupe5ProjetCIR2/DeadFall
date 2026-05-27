-- ============================================================
-- Ce script gère l'affichage du menu des joueurs (Scoreboard/TabList) personnalisé.
-- Il s'active lorsque le joueur maintient la touche TAB.
-- Pendant l'affichage du menu, il masque temporairement les autres éléments 
-- de l'interface (Minimap, Boussole, Inventaire, Barre de vie) en sauvegardant leur état.
-- ============================================================

local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Désactive la liste des joueurs par défaut de Roblox
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local menuGui = script.Parent
local mainFrame = menuGui:WaitForChild("MainFrame")
local playerList = mainFrame:WaitForChild("PlayerList")

local template = script:WaitForChild("PlayerTemplate") 

-- Rend la fenêtre principale transparente et sans bordure
mainFrame.BorderSizePixel = 0
mainFrame.BackgroundTransparency = 1 

local GetStatsFunction = ReplicatedStorage:WaitForChild("GetPlayerStats")
local cachedStats = {}

---------------------------------------------------------
-- INITIALISATION DE L'ARRIÈRE-PLAN
---------------------------------------------------------
-- Crée et configure automatiquement l'image de fond si elle n'existe pas
local backgroundImage = mainFrame:FindFirstChild("CustomBackgroundImage")
if not backgroundImage then
	backgroundImage = Instance.new("ImageLabel")
	backgroundImage.Name = "CustomBackgroundImage"

	backgroundImage.Size = UDim2.new(1.45, 0, 1.45, 0)
	backgroundImage.AnchorPoint = Vector2.new(0.5, 0.5)
	backgroundImage.Position = UDim2.new(0.5, 0, 0.5, 0)

	backgroundImage.ZIndex = 0
	backgroundImage.BackgroundTransparency = 1
	backgroundImage.BorderSizePixel = 0
	backgroundImage.Image = "rbxassetid://130872408105188"
	backgroundImage.ScaleType = Enum.ScaleType.Fit 
	backgroundImage.Parent = mainFrame
end

---------------------------------------------------------
-- FONCTIONS UTILITAIRES ET SYNCHRONISATION
---------------------------------------------------------
-- Attends que les autres interfaces soient chargées avant de les manipuler
local function waitForGuis()
	local maxWait = 5
	local startTime = tick()
	while tick() - startTime < maxWait do
		local minimap = playerGui:FindFirstChild("MinimapGUI")
		local argent = playerGui:FindFirstChild("ArgentUI")
		if minimap and argent then
			return true
		end
		task.wait(0.1)
	end
	return false
end

waitForGuis()

-- Récupère les statistiques des joueurs depuis le serveur
local function refreshStats()
	local ok, result = pcall(function()
		return GetStatsFunction:InvokeServer()
	end)
	if ok and result then
		cachedStats = result
	end
end

local thumbType = Enum.ThumbnailType.HeadShot
local thumbSize = Enum.ThumbnailSize.Size100x100 

local hiddenScreenGuis = {}
local savedMiniMapProps = {}
local savedHealthProps = {} 

---------------------------------------------------------
-- MISE À JOUR DU SCOREBOARD
---------------------------------------------------------
local function updatePlayerList()
	-- 1. Supprime les lignes des joueurs qui ont quitté la partie
	for _, child in pairs(playerList:GetChildren()) do
		if child:IsA("Frame") and string.sub(child.Name, 1, 10) == "PlayerRow_" then
			local userId = tonumber(string.sub(child.Name, 11))
			if not Players:GetPlayerByUserId(userId) then
				child:Destroy()
			end
		end
	end

	-- 2. Met à jour ou crée les lignes pour les joueurs présents
	for _, p in pairs(Players:GetPlayers()) do
		local rowName = "PlayerRow_" .. tostring(p.UserId)
		local existingRow = playerList:FindFirstChild(rowName)

		if not existingRow then
			existingRow = template:Clone()
			existingRow.Name = rowName
			existingRow.Parent = playerList
			existingRow.Visible = true

			-- Charge l'avatar du joueur en asynchrone pour ne pas bloquer l'interface
			task.spawn(function()
				local success, imageURL = pcall(function()
					return Players:GetUserThumbnailAsync(p.UserId, thumbType, thumbSize)
				end)

				if success and imageURL and existingRow and existingRow.Parent then
					existingRow.Tete.Image = imageURL
				else
					if existingRow and existingRow.Parent then
						existingRow.Tete.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
					end
				end
			end)
		end

		-- Met à jour les informations textuelles (Nom, Couleur)
		existingRow.NomPlayer.Text = p.DisplayName

		local tabColor = p:GetAttribute("TabColor")
		if tabColor then
			existingRow.NomPlayer.TextColor3 = tabColor
		elseif p.Team then
			existingRow.NomPlayer.TextColor3 = p.TeamColor.Color
		else
			existingRow.NomPlayer.TextColor3 = Color3.fromRGB(255, 255, 0)
		end

		-- Applique les statistiques (Argent, Kills, KOs)
		local leaderstats = p:FindFirstChild("leaderstats")
		local serverStats = cachedStats[p.UserId] or cachedStats[tostring(p.UserId)] or {}

		if leaderstats then
			local money = leaderstats:FindFirstChild("Argent")
			local kills = leaderstats:FindFirstChild("Kills")

			existingRow.ArgentStat.Text = money and tostring(money.Value) .. " $" or "0 $"
			existingRow.KillStat.Text = kills and tostring(kills.Value) or "0"
		else
			existingRow.ArgentStat.Text = "0 $"
			existingRow.KillStat.Text = "0"
		end

		existingRow.KoStat.Text = tostring(serverStats.timesKO or 0)
	end
end

local isTabPressed = false 

---------------------------------------------------------
-- GESTION DES ENTRÉES (TOUCHE TAB)
---------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Tab then
		isTabPressed = true

		table.clear(hiddenScreenGuis)
		table.clear(savedMiniMapProps)
		table.clear(savedHealthProps)

		-- 1. Masque les interfaces secondaires (Boussole, Inventaire)
		local guisToHide = {"CompassGui", "CustomInventoryGui"}
		for _, guiName in pairs(guisToHide) do
			local gui = playerGui:FindFirstChild(guiName)
			if gui and gui:IsA("ScreenGui") and gui.Enabled then
				gui.Enabled = false
				table.insert(hiddenScreenGuis, gui)
			end
		end

		-- 2. Masque minutieusement la Minimap
		local minimapGui = playerGui:FindFirstChild("MinimapGUI")
		if minimapGui then
			local surfaceGui = minimapGui:FindFirstChild("SurfaceGui")
			if surfaceGui then
				local miniMap = surfaceGui:FindFirstChild("MiniMap")
				if miniMap then
					savedMiniMapProps.Object = miniMap

					if pcall(function() return miniMap.BackgroundTransparency end) then
						savedMiniMapProps.BgTrans = miniMap.BackgroundTransparency
						miniMap.BackgroundTransparency = 1
					end

					if pcall(function() return miniMap.ImageTransparency end) then
						savedMiniMapProps.ImgTrans = miniMap.ImageTransparency
						miniMap.ImageTransparency = 1
					end

					local stroke = miniMap:FindFirstChildOfClass("UIStroke")
					if stroke then
						savedMiniMapProps.Stroke = stroke
						savedMiniMapProps.StrokeTrans = stroke.Transparency
						stroke.Transparency = 1
					end

					local radarSweep = miniMap:FindFirstChild("RadarSweep")
					if radarSweep then
						savedMiniMapProps.Radar = radarSweep
						savedMiniMapProps.RadarSize = radarSweep.Size
						radarSweep.Size = UDim2.new(0, 0, 0, 0)

						local radarStroke = radarSweep:FindFirstChildOfClass("UIStroke")
						if radarStroke then
							savedMiniMapProps.RadarStroke = radarStroke
							savedMiniMapProps.RadarStrokeThick = radarStroke.Thickness
							radarStroke.Thickness = 0
						end
					end
				end
			end
		end

		-- 3. Masque la barre de vie
		local customHealthBar = playerGui:FindFirstChild("CustomHealthBar")
		if customHealthBar then
			local healthSurfaceGui = customHealthBar:FindFirstChild("SurfaceGui")
			if healthSurfaceGui then
				local healthFrame = healthSurfaceGui:FindFirstChild("Frame")
				if healthFrame and healthFrame.Visible then
					savedHealthProps.Frame = healthFrame
					healthFrame.Visible = false
				end
			end
		end

		-- 4. Affiche immédiatement la liste des joueurs avec les données en cache
		updatePlayerList() 
		mainFrame.Visible = true

		-- 5. Rafraîchit les statistiques auprès du serveur en arrière-plan
		task.spawn(function()
			refreshStats()
			if isTabPressed then
				updatePlayerList()
			end
		end)
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Tab then
		isTabPressed = false 

		-- Masque le menu des joueurs
		mainFrame.Visible = false

		-- Restaure les interfaces secondaires
		for _, gui in pairs(hiddenScreenGuis) do
			if gui then
				gui.Enabled = true
			end
		end

		-- Restaure les propriétés de la Minimap
		if savedMiniMapProps.Object then
			local miniMap = savedMiniMapProps.Object

			if savedMiniMapProps.BgTrans then
				pcall(function() miniMap.BackgroundTransparency = savedMiniMapProps.BgTrans end)
			end

			if savedMiniMapProps.ImgTrans then
				pcall(function() miniMap.ImageTransparency = savedMiniMapProps.ImgTrans end)
			end

			if savedMiniMapProps.Stroke and savedMiniMapProps.StrokeTrans then
				savedMiniMapProps.Stroke.Transparency = savedMiniMapProps.StrokeTrans
			end

			if savedMiniMapProps.Radar and savedMiniMapProps.RadarSize then
				savedMiniMapProps.Radar.Size = savedMiniMapProps.RadarSize
			end
			if savedMiniMapProps.RadarStroke and savedMiniMapProps.RadarStrokeThick then
				savedMiniMapProps.RadarStroke.Thickness = savedMiniMapProps.RadarStrokeThick
			end
		end

		-- Restaure la barre de vie
		if savedHealthProps.Frame then
			savedHealthProps.Frame.Visible = true
		end

		-- Nettoie la mémoire
		table.clear(hiddenScreenGuis)
		table.clear(savedMiniMapProps)
		table.clear(savedHealthProps)
	end
end)
