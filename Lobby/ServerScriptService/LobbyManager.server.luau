-- ============================================================
--  Ce script centralise la gestion des lobbies en créant des
--  interfaces dynamiques pour regrouper les joueurs.
--  Il coordonne ensuite leur téléportation isolée vers une
--  nouvelle instance de jeu dédiée via le TeleportService.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local TeleportService   = game:GetService("TeleportService")
local RunService        = game:GetService("RunService")

local IS_STUDIO = RunService:IsStudio()
local GAME_PLACE_ID = 119875932283561

-- ============================================================
--  RemoteEvents & RemoteFunctions
-- ============================================================

local joinEvent  = ReplicatedStorage:WaitForChild("JoinCyborgMode")
local leaveEvent = ReplicatedStorage:WaitForChild("LeaveCyborgMode")

local function getOrCreate(className, name)
	local obj = ReplicatedStorage:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name   = name
		obj.Parent = ReplicatedStorage
	end
	return obj
end

local requestJoinEvent     = getOrCreate("RemoteEvent",    "RequestJoinLobby")
local joinLobbyClientEvent = getOrCreate("RemoteEvent",    "JoinLobbyClientEvent")
local hostLeftEvent        = getOrCreate("RemoteEvent",    "HostLeftEvent")
local getLobbyPlayersFunc  = getOrCreate("RemoteFunction", "GetMyLobbyPlayers")
local updateLobbyUIEvent   = getOrCreate("RemoteEvent",    "UpdateLobbyUIEvent")
local kickPlayerEvent      = getOrCreate("RemoteEvent",    "KickPlayerFromLobby")
local kickedEvent          = getOrCreate("RemoteEvent",    "KickedFromLobbyEvent")
local bannedFromLobbyEvent = getOrCreate("RemoteEvent",    "BannedFromLobbyEvent")
local startGameEvent       = getOrCreate("RemoteEvent",    "StartGame")
local gameStartingEvent    = getOrCreate("RemoteEvent",    "GameStartingEvent")
local cancelTeleportEvent  = getOrCreate("RemoteEvent",    "CancelTeleportEvent")

-- ============================================================
--  UI Workspace
-- ============================================================

local lobbySystem  = workspace:WaitForChild("LobbySystem")
local surfaceGui   = lobbySystem:WaitForChild("SurfaceGui")
local mainLobby    = surfaceGui.PartyFrame.Main.Panel.LobbyText.Lobby.MainLobby
local zektonFont   = Font.new("rbxasset://fonts/families/Zekton.json")

local listLayout = mainLobby:FindFirstChildWhichIsA("UIListLayout")
if not listLayout then
	listLayout = Instance.new("UIListLayout")
	listLayout.Padding             = UDim.new(0, 10)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.SortOrder           = Enum.SortOrder.LayoutOrder
	listLayout.Parent              = mainLobby
end

local activeLobbies = {}

-- ============================================================
--  Fonctions utilitaires
-- ============================================================

local function broadcastLobbyUpdate(lobby)
	if not lobby then return end
	for _, p in ipairs(lobby.PlayersList) do
		updateLobbyUIEvent:FireClient(p, lobby.PlayersList, lobby.KickCounts)
	end
end

local function updateLobbyFrameUI(lobby)
	if not lobby or not lobby.UIFrame then return end
	local numPlayers = #lobby.PlayersList
	local isFull     = numPlayers >= 4

	local countLabel = lobby.UIFrame:FindFirstChild("PlayerCount")
	if countLabel then
		countLabel.Text = "PLAYERS: " .. numPlayers .. "/4"
	end

	local joinButton = lobby.UIFrame:FindFirstChild("JoinButton")
	if isFull then
		lobby.UIFrame.BackgroundColor3 = Color3.fromRGB(160, 80, 80)
		if joinButton then
			joinButton.Text             = "FULL"
			joinButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
			joinButton.TextColor3       = Color3.fromRGB(200, 200, 200)
		end
	else
		lobby.UIFrame.BackgroundColor3 = Color3.fromRGB(128, 128, 128)
		if joinButton then
			joinButton.Text             = "JOIN"
			joinButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			joinButton.TextColor3       = Color3.fromRGB(255, 255, 255)
		end
	end

	local startButton = lobby.UIFrame:FindFirstChild("StartButton")
	if startButton then
		startButton.Text = lobby.IsLaunching and "..." or "START"
	end
end

local function cleanupLobby(hostUserId)
	local lobby = activeLobbies[hostUserId]
	if not lobby then return end
	if lobby.UIFrame then lobby.UIFrame:Destroy() end
	activeLobbies[hostUserId] = nil
end

-- ============================================================
--  GetMyLobbyPlayers  (RemoteFunction)
-- ============================================================

getLobbyPlayersFunc.OnServerInvoke = function(player)
	if activeLobbies[player.UserId] then
		return activeLobbies[player.UserId].PlayersList
	end
	for _, lobby in pairs(activeLobbies) do
		if table.find(lobby.PlayersList, player) then
			return lobby.PlayersList
		end
	end
	return { player }
end

-- ============================================================
--  KickPlayerFromLobby
-- ============================================================

kickPlayerEvent.OnServerEvent:Connect(function(hostPlayer, targetUserId)
	local lobby = activeLobbies[hostPlayer.UserId]
	if not lobby then return end

	for i, guestPlayer in ipairs(lobby.PlayersList) do
		if guestPlayer.UserId == targetUserId and guestPlayer ~= hostPlayer then
			table.remove(lobby.PlayersList, i)

			lobby.KickCounts[targetUserId] = (lobby.KickCounts[targetUserId] or 0) + 1

			if lobby.KickCounts[targetUserId] >= 2 then
				lobby.BannedPlayers[targetUserId] = true
				bannedFromLobbyEvent:FireClient(guestPlayer, hostPlayer.UserId)
			end

			updateLobbyFrameUI(lobby)
			kickedEvent:FireClient(guestPlayer)
			broadcastLobbyUpdate(lobby)

			for _, p in ipairs(lobby.PlayersList) do
				joinLobbyClientEvent:FireClient(p, "UPDATE_VISIBILITY")
			end

			print(hostPlayer.Name .. " a expulsé " .. guestPlayer.Name)
			break
		end
	end
end)

-- ============================================================
--  JoinCyborgMode  →  Création du lobby
-- ============================================================

joinEvent.OnServerEvent:Connect(function(player)
	if activeLobbies[player.UserId] then return end

	local lobbyFrame = Instance.new("Frame")
	lobbyFrame.Name                   = "Lobby_" .. player.UserId
	lobbyFrame.Size                   = UDim2.new(1, -20, 0, 80)
	lobbyFrame.BackgroundColor3       = Color3.fromRGB(128, 128, 128)
	lobbyFrame.BackgroundTransparency = 0.5
	lobbyFrame.BorderSizePixel        = 0

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 8)
	frameCorner.Parent       = lobbyFrame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color        = Color3.fromRGB(255, 255, 255)
	frameStroke.Thickness    = 2
	frameStroke.Transparency = 0.2
	frameStroke.Parent       = lobbyFrame

	local playerIcon = Instance.new("ImageLabel")
	playerIcon.Name                   = "PlayerIcon"
	playerIcon.Size                   = UDim2.new(0, 60, 0, 60)
	playerIcon.Position               = UDim2.new(0, 10, 0.5, 0)
	playerIcon.AnchorPoint            = Vector2.new(0, 0.5)
	playerIcon.BackgroundTransparency = 1
	playerIcon.Parent                 = lobbyFrame

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent       = playerIcon

	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color     = Color3.fromRGB(255, 255, 255)
	iconStroke.Thickness = 1.5
	iconStroke.Parent    = playerIcon

	task.spawn(function()
		local content, isReady = Players:GetUserThumbnailAsync(
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
		if isReady then playerIcon.Image = content end
	end)

	local playerName = Instance.new("TextLabel")
	playerName.Name                   = "PlayerName"
	playerName.Size                   = UDim2.new(0.4, 0, 0, 30)
	playerName.Position               = UDim2.new(0, 85, 0, 10)
	playerName.BackgroundTransparency = 1
	playerName.Text                   = player.DisplayName .. " [HOST]"
	playerName.TextColor3             = Color3.fromRGB(255, 255, 255)
	playerName.FontFace               = zektonFont
	playerName.TextSize               = 20
	playerName.TextXAlignment         = Enum.TextXAlignment.Left
	playerName.Parent                 = lobbyFrame

	local playerCount = Instance.new("TextLabel")
	playerCount.Name                   = "PlayerCount"
	playerCount.Size                   = UDim2.new(0.4, 0, 0, 30)
	playerCount.Position               = UDim2.new(0, 85, 0, 40)
	playerCount.BackgroundTransparency = 1
	playerCount.Text                   = "PLAYERS: 1/4"
	playerCount.TextColor3             = Color3.fromRGB(200, 200, 200)
	playerCount.FontFace               = zektonFont
	playerCount.TextSize               = 16
	playerCount.TextXAlignment         = Enum.TextXAlignment.Left
	playerCount.Parent                 = lobbyFrame

	local joinButton = Instance.new("TextButton")
	joinButton.Name                   = "JoinButton"
	joinButton.Size                   = UDim2.new(0, 80, 0, 35)
	joinButton.Position               = UDim2.new(1, -90, 0.5, 10)
	joinButton.AnchorPoint            = Vector2.new(0, 0.5)
	joinButton.BackgroundColor3       = Color3.fromRGB(40, 40, 40)
	joinButton.BackgroundTransparency = 0.3
	joinButton.Text                   = "JOIN"
	joinButton.TextColor3             = Color3.fromRGB(255, 255, 255)
	joinButton.FontFace               = zektonFont
	joinButton.TextSize               = 18
	joinButton.Parent                 = lobbyFrame

	local hostIdValue = Instance.new("NumberValue")
	hostIdValue.Name   = "HostID"
	hostIdValue.Value  = player.UserId
	hostIdValue.Parent = joinButton

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent       = joinButton

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color     = Color3.fromRGB(255, 255, 255)
	btnStroke.Thickness = 2
	btnStroke.Parent    = joinButton

	local startButton = Instance.new("TextButton")
	startButton.Name                   = "StartButton"
	startButton.Size                   = UDim2.new(0, 80, 0, 35)
	startButton.Position               = UDim2.new(1, -90, 0.5, -30)
	startButton.AnchorPoint            = Vector2.new(0, 0.5)
	startButton.BackgroundColor3       = Color3.fromRGB(30, 120, 60)
	startButton.BackgroundTransparency = 0.2
	startButton.Text                   = "START"
	startButton.TextColor3             = Color3.fromRGB(255, 255, 255)
	startButton.FontFace               = zektonFont
	startButton.TextSize               = 18
	startButton.Visible                = false
	startButton.Parent                 = lobbyFrame

	local startCorner = Instance.new("UICorner")
	startCorner.CornerRadius = UDim.new(0, 6)
	startCorner.Parent       = startButton

	local startStroke = Instance.new("UIStroke")
	startStroke.Color     = Color3.fromRGB(100, 220, 130)
	startStroke.Thickness = 2
	startStroke.Parent    = startButton

	lobbyFrame.Parent = mainLobby

	activeLobbies[player.UserId] = {
		Host          = player,
		PlayersList   = { player },
		UIFrame       = lobbyFrame,
		KickCounts    = {},
		BannedPlayers = {},
		IsLaunching   = false,
	}

	player:SetAttribute("IsHost", true)

	local character = player.Character
	if character and character:FindFirstChild("Head") then
		local tag = character.Head:FindFirstChild("NameTag")
		if tag and tag:FindFirstChild("PlayerName") then
			tag.PlayerName.RichText = true
			tag.PlayerName.Text     = '<font color="#00AAFF">[HOST]</font> ' .. player.Name
		end
	end

	updateLobbyFrameUI(activeLobbies[player.UserId])
	broadcastLobbyUpdate(activeLobbies[player.UserId])

	print("Lobby créé par " .. player.Name)
end)

-- ============================================================
--  RequestJoinLobby  →  Rejoindre un lobby existant
-- ============================================================

requestJoinEvent.OnServerEvent:Connect(function(clicker, targetHostID)
	local lobby = activeLobbies[targetHostID]
	if not lobby then return end
	if lobby.IsLaunching then return end
	if lobby.BannedPlayers[clicker.UserId] then
		warn(clicker.Name .. " est banni du lobby de " .. lobby.Host.Name)
		return
	end
	if table.find(lobby.PlayersList, clicker) then return end

	local numPlayers = #lobby.PlayersList
	if numPlayers < 4 then
		table.insert(lobby.PlayersList, clicker)
		numPlayers = #lobby.PlayersList

		updateLobbyFrameUI(lobby)

		local tpName = "TP" .. numPlayers
		joinLobbyClientEvent:FireClient(clicker, tpName)

		for _, p in ipairs(lobby.PlayersList) do
			if p ~= clicker then
				joinLobbyClientEvent:FireClient(p, "UPDATE_VISIBILITY")
			end
		end

		broadcastLobbyUpdate(lobby)
	else
		warn("Lobby plein !")
	end
end)

-- ============================================================
--  StartGame  →  Téléportation forcée vers une NOUVELLE instance
-- ============================================================

startGameEvent.OnServerEvent:Connect(function(player)
	local lobby = activeLobbies[player.UserId]
	if not lobby then
		warn(player.Name .. " a tenté de lancer sans être hôte")
		return
	end
	if lobby.IsLaunching then return end

	lobby.IsLaunching = true
	updateLobbyFrameUI(lobby)

	-- Notifie les clients pour lancer l'écran noir de chargement
	for _, p in ipairs(lobby.PlayersList) do
		gameStartingEvent:FireClient(p)
	end

	task.wait(2)

	local joueurs = {}
	for _, p in ipairs(lobby.PlayersList) do
		table.insert(joueurs, p)
	end

	local teleportData = {
		hostName    = player.Name,
		hostId      = player.UserId,
		playerCount = #joueurs,
		lobbyJobId  = game.JobId,
	}

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(teleportData)
	options.ShouldReserveServer = true 

	-- ============================================================
	--  MODE STUDIO : simulation virtuelle (Pas de téléportation possible)
	-- ============================================================
	if IS_STUDIO then
		print("🧪 STUDIO : Simulation téléportation isolée pour " .. player.Name .. " (" .. #joueurs .. " joueurs) vers PlaceId " .. GAME_PLACE_ID)
		cleanupLobby(player.UserId)
		player:SetAttribute("IsHost", false)
		for _, p in ipairs(joueurs) do
			cancelTeleportEvent:FireClient(p)
		end
		return
	end

	-- ============================================================
	--  MODE PRODUCTION : Vrai TeleportAsync
	-- ============================================================
	local MAX_RETRIES = 3
	local teleported  = false

	for attempt = 1, MAX_RETRIES do
		local success, err = pcall(function()
			TeleportService:TeleportAsync(GAME_PLACE_ID, joueurs, options)
		end)

		if success then
			teleported = true
			print("✅ Nouvelle instance isolée créée avec succès pour le groupe de " .. player.Name)

			cleanupLobby(player.UserId)
			player:SetAttribute("IsHost", false)
			break
		else
			warn("Tentative " .. attempt .. " échouée : " .. tostring(err))
			if attempt < MAX_RETRIES then
				task.wait(3)
			end
		end
	end

	if not teleported then
		local currentLobby = activeLobbies[player.UserId]
		if currentLobby then
			currentLobby.IsLaunching = false
			updateLobbyFrameUI(currentLobby)
		end
		warn("❌ Échec définitif de la téléportation isolée pour " .. player.Name)
		for _, p in ipairs(joueurs) do
			cancelTeleportEvent:FireClient(p)
		end
	end
end)

-- ============================================================
--  LeaveCyborgMode  →  Quitter / Annuler le lobby
-- ============================================================

leaveEvent.OnServerEvent:Connect(function(player)
	if activeLobbies[player.UserId] then
		local lobby = activeLobbies[player.UserId]

		for _, guestPlayer in ipairs(lobby.PlayersList) do
			if guestPlayer ~= player then
				hostLeftEvent:FireClient(guestPlayer)
			end
		end

		cleanupLobby(player.UserId)
		player:SetAttribute("IsHost", false)

		local character = player.Character
		if character and character:FindFirstChild("Head") then
			local tag = character.Head:FindFirstChild("NameTag")
			if tag and tag:FindFirstChild("PlayerName") then
				tag.PlayerName.Text = player.Name
			end
		end

		print("Lobby annulé par l'hôte : " .. player.Name)
		return
	end

	for _, lobby in pairs(activeLobbies) do
		local index = table.find(lobby.PlayersList, player)
		if index then
			table.remove(lobby.PlayersList, index)
			updateLobbyFrameUI(lobby)
			broadcastLobbyUpdate(lobby)

			for _, p in ipairs(lobby.PlayersList) do
				joinLobbyClientEvent:FireClient(p, "UPDATE_VISIBILITY")
			end

			print(player.Name .. " a quitté le lobby de " .. lobby.Host.Name)
			break
		end
	end
end)

-- ============================================================
--  PlayerRemoving  →  Nettoyage si déconnexion
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
	if activeLobbies[player.UserId] then
		local lobby = activeLobbies[player.UserId]
		for _, guestPlayer in ipairs(lobby.PlayersList) do
			if guestPlayer ~= player then
				hostLeftEvent:FireClient(guestPlayer)
			end
		end
		cleanupLobby(player.UserId)
		return
	end

	for _, lobby in pairs(activeLobbies) do
		local index = table.find(lobby.PlayersList, player)
		if index then
			table.remove(lobby.PlayersList, index)
			updateLobbyFrameUI(lobby)
			broadcastLobbyUpdate(lobby)

			for _, p in ipairs(lobby.PlayersList) do
				joinLobbyClientEvent:FireClient(p, "UPDATE_VISIBILITY")
			end

			break
		end
	end
end)