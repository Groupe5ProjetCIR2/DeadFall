-- ============================================================
-- Ce script initialise le tableau des scores (leaderstats) pour chaque joueur rejoignant la partie.
-- Il crée les statistiques de base telles que l'argent, les éliminations (Kills) et les mises à terre (KOs).
-- ============================================================

local Players = game:GetService("Players")

-- Écoute l'événement de connexion d'un joueur pour générer ses données de session
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Argent" 
	cash.Value = 0
	cash.Parent = leaderstats

	local kills = Instance.new("IntValue")
	kills.Name = "Kills" 
	kills.Value = 0 
	kills.Parent = leaderstats

	local kos = Instance.new("IntValue")
	kos.Name = "KOs" 
	kos.Value = 0 
	kos.Parent = leaderstats
end)