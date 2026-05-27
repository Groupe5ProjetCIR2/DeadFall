-- ============================================================
--  Ce script gère l'affichage d'un chronomètre dynamique au-dessus 
--  de la tête du personnage.
--  Il active ou désactive un compteur de temps via un signal 
--  distant (RemoteEvent) et met à jour l'interface textuelle.
-- ============================================================

local billboard = script:WaitForChild("BillboardGui")
local char = script.Parent
local event = script:WaitForChild("ToggleLabel")
local label = billboard:WaitForChild("TextLabel")

-- Configuration de la police spécifique pour l'étiquette
label.FontFace = Font.new("rbxasset://fonts/families/Zekton.json")

-- Attachement de l'interface au modèle du personnage
billboard.Parent = char:WaitForChild("Head")

local running = false
local startTime = 0
local loopTask

-- Réception du signal pour démarrer ou arrêter le chronomètre
event.OnServerEvent:Connect(function(player, thing : boolean)
	if thing and not running then
		running = true
		label.Visible = true
		startTime = time()

		-- Boucle de mise à jour du temps écoulé
		loopTask = task.spawn(function()
			while running do
				label.Text = "Waiting for "  .. math.floor(time() - startTime + 1) .. "s"
				task.wait(0.1)
			end
		end)
	elseif not thing and running then
		running = false
		label.Visible = false
	end
end)