-- ============================================================
--  Ce script verrouille l'heure du jeu en forçant continuellement 
--  la propriété ClockTime sur une valeur spécifique.
--  L'utilisation du service Heartbeat garantit que cette valeur 
--  reste constante malgré toute tentative de modification.
-- ============================================================

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- Mise à jour récursive de l'heure à chaque battement du moteur physique
RunService.Heartbeat:Connect(function()
	Lighting.ClockTime = 5
end)