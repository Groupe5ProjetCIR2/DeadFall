-- ============================================================
--  Ce script configure l'interface utilisateur personnalisée 
--  qui sera affichée lors des téléportations.
--  Il assigne un objet ScreenGui spécifique depuis ReplicatedStorage 
--  au service de téléportation pour le remplacer par défaut.
-- ============================================================

local TeleportService = game:GetService("TeleportService")

-- Définition et application de l'interface de chargement personnalisée
local teleportgui = game:GetService("ReplicatedStorage").TeleportGui
TeleportService:SetTeleportGui(teleportgui)