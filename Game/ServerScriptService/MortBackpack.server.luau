-- ============================================================
-- Ce script vide l'inventaire du joueur (Backpack et outils équipés)
-- dès que son Humanoid meurt.
-- ============================================================

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		humanoid.Died:Connect(function()
			-- Nettoyage du Backpack
			local backpack = player:FindFirstChild("Backpack")
			if backpack then
				for _, tool in ipairs(backpack:GetChildren()) do
					if tool:IsA("Tool") then tool:Destroy() end
				end
			end

			-- Nettoyage de l'outil éventuellement encore dans les mains
			for _, tool in ipairs(character:GetChildren()) do
				if tool:IsA("Tool") then tool:Destroy() end
			end
		end)
	end)
end)