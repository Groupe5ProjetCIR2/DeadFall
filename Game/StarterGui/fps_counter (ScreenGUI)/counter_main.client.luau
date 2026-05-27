-- ============================================================
-- Ce script gère l'affichage des images par seconde (FPS) à l'écran.
-- Il compte le nombre de frames rendues sur une période donnée 
-- (update_rate) et met à jour le texte de l'interface en conséquence.
-- ============================================================

local services = {
	["run_service"] = game:GetService("RunService"),
}

local gui = script.Parent
local fps_label = gui:WaitForChild("fps_label")

-- Récupère la fréquence de mise à jour et la limite entre 0.25 et 2 secondes
local update_rate = gui:WaitForChild("update_rate").Value
update_rate = (update_rate < 0.25 or update_rate > 2) and 1 or update_rate

local frames_rendered = 0
local last_update = tick() - update_rate
local multiplier = 1 / update_rate

-- Boucle exécutée à chaque image (RenderStepped) pour calculer et afficher les FPS
services["run_service"].RenderStepped:Connect(
	function()
		-- Si le temps écoulé dépasse la fréquence de mise à jour, on actualise l'affichage
		if tick() - last_update >= update_rate then
			fps_label.Text = tostring(math.round(frames_rendered * multiplier)).. " FPS"
			frames_rendered = 0
			last_update = tick()
		else
			-- Sinon, on continue de compter les images générées
			frames_rendered += 1
		end
	end
)