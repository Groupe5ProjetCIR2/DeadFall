-- ============================================================
-- Ce script rend le personnage invisible en supprimant ses parties de corps via HumanoidDescription.
-- Utile pour le mode spectateur, cacher le corps par défaut, ou préparer un modèle custom.
-- ============================================================

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player) 
	-- Attend le chargement complet du skin avant de modifier le corps
	player.CharacterAppearanceLoaded:Connect(function(character) 

		-- Sécurité : attend le Humanoid pour éviter les erreurs de timing
		local hum = character:WaitForChild("Humanoid") 
		local currentdescription = hum:GetAppliedDescription() 

		-- Remise à 0 des IDs pour supprimer visuellement les membres
		currentdescription.Head = 0
		currentdescription.Torso = 0
		currentdescription.LeftArm = 0
		currentdescription.RightArm = 0
		currentdescription.LeftLeg = 0
		currentdescription.RightLeg = 0

		hum:ApplyDescription(currentdescription) 
	end)
end)