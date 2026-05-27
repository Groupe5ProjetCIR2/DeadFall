-- ============================================================
--  Ce script a pour but de désactiver l'inventaire 
--  (Backpack) par défaut de Roblox. Il utilise un appel 
--  protégé (pcall) pour s'assurer que le jeu ne génère 
--  pas d'erreur si l'interface n'est pas encore prête.
-- ============================================================

local StarterGui = game:GetService("StarterGui")

-- Utilisation d'un appel protégé (pcall) pour éviter de faire planter le script si le CoreGui n'est pas encore prêt
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)