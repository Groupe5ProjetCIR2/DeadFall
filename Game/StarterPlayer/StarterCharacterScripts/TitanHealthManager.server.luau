-- ============================================================
--  Ce script ajuste dynamiquement la santé maximale du joueur 
--  en fonction de l'acquisition d'un atout (TitanJawbreaker).
--  Il écoute les changements d'attributs pour appliquer l'effet en temps réel.
-- ============================================================

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local player = game:GetService("Players"):GetPlayerFromCharacter(character)

-- Évalue l'attribut du joueur pour redéfinir sa capacité de santé maximale et le soigner si nécessaire
local function updateMaxHealth()
	if player:GetAttribute("TitanJawbreaker") == true then
		humanoid.MaxHealth = 150
		humanoid.Health = 150
		print("💪 TitanJawbreaker activé : 150 HP pour " .. player.Name)
	else
		humanoid.MaxHealth = 100
	end
end

updateMaxHealth()

-- Connecte un écouteur d'événement asynchrone pour réagir instantanément lors de l'achat de l'atout
player:GetAttributeChangedSignal("TitanJawbreaker"):Connect(function()
	updateMaxHealth()
end)