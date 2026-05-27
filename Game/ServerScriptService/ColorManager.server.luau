-- ============================================================
-- Ce script assigne une couleur unique à chaque joueur à son arrivée 
-- et libère cette couleur lorsqu'il quitte le serveur.
-- Utile pour distinguer les équipes ou les joueurs dans l'interface (HUD).
-- ============================================================

local Players = game:GetService("Players")

local colors = {
	Color3.fromRGB(0, 0, 139),    -- Bleu foncé
	Color3.fromRGB(138, 43, 226), -- Violet
	Color3.fromRGB(178, 34, 34),  -- Rouge foncé
	Color3.fromRGB(0, 100, 0)     -- Vert foncé
}

local availableColors = {1, 2, 3, 4}
local playerColors = {}

Players.PlayerAdded:Connect(function(player)
	if #availableColors > 0 then
		local randomIndex = math.random(1, #availableColors)
		local colorIndex = availableColors[randomIndex]

		-- Retire l'index de la liste des dispos pour qu'il soit unique
		table.remove(availableColors, randomIndex)

		playerColors[player.UserId] = colorIndex
		player:SetAttribute("TabColor", colors[colorIndex])
	else
		player:SetAttribute("TabColor", Color3.fromRGB(255, 255, 255))
	end
end)

-- Lorsqu'un joueur quitte, sa couleur redevient disponible pour les prochains
Players.PlayerRemoving:Connect(function(player)
	local colorIndex = playerColors[player.UserId]
	if colorIndex then
		table.insert(availableColors, colorIndex)
		playerColors[player.UserId] = nil
	end
end)