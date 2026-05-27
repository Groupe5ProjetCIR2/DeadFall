-- ============================================================
--  Ce script gère l'affichage dynamique d'étiquettes au-dessus 
--  de la tête des joueurs lors de leur apparition.
--  Il vérifie l'attribut d'hôte du joueur pour personnaliser 
--  le texte et la couleur via l'utilisation du RichText.
-- ============================================================

local nameTag = script.NameTag

-- Initialise l'étiquette sur le personnage dès que celui-ci rejoint et apparaît
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local head = character:WaitForChild("Head")

		local plrTag = nameTag:Clone()

		-- Activation du support du balisage HTML pour le formatage du texte
		plrTag.PlayerName.RichText = true

		-- Applique le tag spécifique si le joueur possède l'attribut d'hôte
		if player:GetAttribute("IsHost") then
			plrTag.PlayerName.Text = '<font color="#00AAFF">[HOST]</font> ' .. player.Name
		else
			plrTag.PlayerName.Text = player.Name
		end

		plrTag.Parent = head
	end)
end)