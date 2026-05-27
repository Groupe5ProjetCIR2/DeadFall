-- ============================================================
-- Ce script ajoute un système de ragdoll à chaque personnage 
-- dès qu'il apparaît dans le jeu en activant un script dédié.
-- ============================================================

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	-- Attend l'apparition du personnage pour y insérer le script
	player.CharacterAdded:Connect(function(character)
		local ragdollV3 = script.RagdollV3:Clone()
		ragdollV3.Parent = character
		ragdollV3.Disabled = false
	end)
end)