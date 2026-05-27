-- ============================================================
-- Ce script enregistre les déplacements des joueurs en stockant 
-- leurs positions récentes dans une table globale (_G).
-- Utile pour que les ennemis puissent suivre le chemin parcouru 
-- par le joueur (système de navigation).
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

_G.PlayerTrails = {} 

local RECORD_DISTANCE = 4
local MAX_TRAIL_SIZE = 60

-- Met à jour le chemin parcouru par chaque joueur à chaque frame physique
RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid").Health > 0 then
			local hrpPos = char.HumanoidRootPart.Position

			if not _G.PlayerTrails[player] then
				_G.PlayerTrails[player] = {hrpPos}
			else
				local trail = _G.PlayerTrails[player]
				local lastPos = trail[#trail]

				-- N'ajoute une position que si le joueur s'est assez éloigné de la précédente
				if (hrpPos - lastPos).Magnitude >= RECORD_DISTANCE then
					table.insert(trail, hrpPos)
					-- Maintient la taille de la liste sous la limite pour économiser la mémoire
					if #trail > MAX_TRAIL_SIZE then
						table.remove(trail, 1)
					end
				end
			end
		end
	end
end)

-- Nettoie la table globale quand un joueur quitte le serveur
Players.PlayerRemoving:Connect(function(player)
	_G.PlayerTrails[player] = nil
end)