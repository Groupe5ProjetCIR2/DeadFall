-- ============================================================
-- Ce script gère le retour des joueurs vers le lobby via 
-- TeleportService et récupère les données de téléportation 
-- transmises lors de la connexion.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local LOBBY_PLACE_ID = 92938025114562

local TeleportEvent = ReplicatedStorage:FindFirstChild("TeleportRequest") or Instance.new("RemoteEvent", ReplicatedStorage)
TeleportEvent.Name = "TeleportRequest"

-- Affiche les informations reçues (host, nb joueurs) lors de l'arrivée d'un joueur
Players.PlayerAdded:Connect(function(player)
	local data = player:GetJoinData()
	local td = data.TeleportData

	if td then
		print("Partie lancée par :", td.hostName)
		print("Nb joueurs :", td.playerCount)
		print("JobId du lobby :", td.lobbyJobId)
	end
end)

-- Téléporte le joueur vers le lobby en toute sécurité
local function retourLobby(player)
	if player:GetAttribute("IsTeleporting") then return end
	player:SetAttribute("IsTeleporting", true)

	local success, err = pcall(function()
		TeleportService:TeleportAsync(LOBBY_PLACE_ID, {player})
	end)

	if not success then
		warn("Retour lobby échoué pour " .. player.Name .. " :", err)
		player:SetAttribute("IsTeleporting", nil)
	end
end

-- Déclenche la fonction de retour quand le client envoie une demande
TeleportEvent.OnServerEvent:Connect(function(player) 
	print("!!! TELEPORTATION DECLENCHEE PAR : " .. player.Name)
	retourLobby(player)
end)