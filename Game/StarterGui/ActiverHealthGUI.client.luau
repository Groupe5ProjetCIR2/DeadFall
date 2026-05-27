-- ============================================================
-- Ce script active l'interface de santé (HealthGui) du joueur au chargement.
-- Il gère l'affichage différé de l'effet d'écran rouge (BloodOverlay).
-- ============================================================

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local playerGui = player:WaitForChild("PlayerGui")

task.wait(1)

local healthGui = playerGui:FindFirstChild("HealthGui")
if healthGui then
	-- Masque l'effet de sang à l'activation pour avoir un écran propre au départ
	healthGui.BloodOverlay.Visible = false
	healthGui.Enabled = true
else
	warn("HealthGui n'a pas été trouvé dans PlayerGui !")
end

task.wait(2)

-- Réactive l'effet de sang après un court délai (fin de chargement/intro)
bloodoverlay_gui = healthGui:FindFirstChild("BloodOverlay")
bloodoverlay_gui.Visible = true