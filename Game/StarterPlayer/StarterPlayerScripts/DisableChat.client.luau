-- ============================================================
--  Ce script a pour but de désactiver l'interface de chat 
--  par défaut de Roblox. Il utilise un appel protégé (pcall) 
--  pour s'assurer que le jeu ne génère pas d'erreur si 
--  l'interface met un peu de temps à se charger côté client.
-- ============================================================

local StarterGui = game:GetService("StarterGui")

-- Utilisation d'un appel protégé (pcall) pour éviter de faire planter le script si le CoreGui n'est pas encore prêt à être modifié
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end)