-- ============================================================
--  Ce script instancie automatiquement un système de ragdoll 
--  sur le personnage de chaque joueur dès son apparition.
--  Il clone le module depuis le script parent et l'active 
--  immédiatement pour garantir la prise en compte physique.
-- ============================================================

-- Établit la connexion lors de l'arrivée du joueur dans la session
game.Players.PlayerAdded:connect(function(player)
	-- Déclenche l'ajout du composant dès que le modèle du personnage est prêt
	player.CharacterAdded:connect(function(character)
		local ragdollV3 = script.RagdollV3:Clone()

		-- Intégration du module au personnage et activation du script
		ragdollV3.Parent = character
		ragdollV3.Disabled = false
	end)
end)