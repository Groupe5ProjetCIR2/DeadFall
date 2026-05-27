-- ============================================================
-- Ce script équipe automatiquement une chemise et un pantalon spécifiques au personnage du joueur lors de son apparition.
-- Il applique la tenue deux fois avec un léger délai pour forcer le chargement, puis signale au client de mettre à jour son modèle à la première personne (viewmodel).
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadViewmodelAppearance = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LoadViewmodelAppearance")

local SHIRT_ID = "rbxassetid://1161632544"
local PANTS_ID = "rbxassetid://481216916"

-- Détecte l'arrivée d'un joueur et l'apparition de son personnage pour lui appliquer l'uniforme
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		-- Première purge pour retirer les vêtements d'origine ou personnalisés du joueur
		for _, item in pairs(character:GetChildren()) do
			if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
				item:Destroy()
			end
		end

		local newShirt = Instance.new("Shirt")
		newShirt.ShirtTemplate = SHIRT_ID
		newShirt.Parent = character

		local newPants = Instance.new("Pants")
		newPants.PantsTemplate = PANTS_ID
		newPants.Parent = character

		-- Délai technique et seconde application pour corriger les bugs de réplication de Roblox où les vêtements ne s'affichent pas
		task.wait(0.5)

		for _, item in pairs(character:GetChildren()) do
			if item:IsA("Shirt") or item:IsA("Pants") then
				item:Destroy()
			end
		end

		local fixShirt = Instance.new("Shirt")
		fixShirt.ShirtTemplate = SHIRT_ID
		fixShirt.Parent = character

		local fixPants = Instance.new("Pants")
		fixPants.PantsTemplate = PANTS_ID
		fixPants.Parent = character

		-- Notifie le client local pour qu'il synchronise les textures des bras sur sa caméra (Viewmodel)
		LoadViewmodelAppearance:FireClient(player)
	end)
end)