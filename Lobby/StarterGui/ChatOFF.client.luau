-- ============================================================
--  Ce script désactive l'interface utilisateur native du chat 
--  Roblox pour le joueur.
-- ============================================================

local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)