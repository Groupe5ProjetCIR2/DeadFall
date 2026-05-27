-- ============================================================
--  Ce script modifie l'apparence des joueurs lors de leur apparition 
--  en réinitialisant les identifiants des composants corporels.
--  Il utilise l'objet HumanoidDescription pour appliquer ces changements 
--  aux personnages dès que leur chargement est complet.
-- ============================================================

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	-- Déclenche le processus dès que le modèle du personnage est chargé dans le jeu
	player.CharacterAppearanceLoaded:Connect(function(character)
		local hum = character:WaitForChild("Humanoid")

		-- Extraction de la configuration actuelle du personnage
		local currentdescription = hum:GetAppliedDescription()

		currentdescription.Head = 0
		currentdescription.Torso = 0
		currentdescription.LeftArm = 0
		currentdescription.RightArm = 0
		currentdescription.LeftLeg = 0
		currentdescription.RightLeg = 0

		-- Mise à jour effective du personnage avec les nouveaux paramètres
		hum:ApplyDescription(currentdescription)
	end)
end)