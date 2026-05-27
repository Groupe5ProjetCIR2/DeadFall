-- ============================================================
--  Ce script automatise le changement de tenue des joueurs 
--  dès leur apparition en jeu.
--  Il supprime les vêtements existants avant d'appliquer les 
--  nouveaux modèles de chemise et de pantalon via leurs identifiants.
-- ============================================================

local SHIRT_ID = "rbxassetid://1161632544"
local PANTS_ID = "http://www.roblox.com/asset/?id=481216916"

-- Initialise le remplacement des vêtements à chaque apparition du personnage
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		-- Suppression des anciens éléments vestimentaires présents par défaut
		for _, item in pairs(character:GetChildren()) do
			if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
				item:Destroy()
			end
		end

		-- Création et assignation de la nouvelle chemise
		local newShirt = Instance.new("Shirt")
		newShirt.Name = "UniformShirt"
		newShirt.ShirtTemplate = SHIRT_ID
		newShirt.Parent = character

		-- Création et assignation du nouveau pantalon
		local newPants = Instance.new("Pants")
		newPants.Name = "UniformPants"
		newPants.PantsTemplate = PANTS_ID
		newPants.Parent = character
	end)
end)