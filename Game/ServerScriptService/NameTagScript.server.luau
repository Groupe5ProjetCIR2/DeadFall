-- ============================================================
-- Ce script affiche un tag personnalisé au-dessus de la tête du joueur.
-- Il cache le tag par défaut de Roblox, applique une couleur basée
-- sur l'attribut "TabColor" et gère le nettoyage lors de la mort.
-- ============================================================

local nameTag = script.NameTag

-- Cache le nom et la barre de vie par défaut de Roblox
local function hideDefaultTag(character)
	local head = character:FindFirstChild("Head")
	if head then
		local defaultTag = head:FindFirstChildWhichIsA("BillboardGui")
		if defaultTag then defaultTag.Enabled = false end
	end
end

-- Applique la couleur stockée dans l'attribut "TabColor" du joueur
local function updateTagColor(tag, player)
	local tabColor = player:GetAttribute("TabColor")
	tag.PlayerName.TextColor3 = tabColor or Color3.new(1, 1, 1)
end

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		repeat task.wait() until character:FindFirstChild("Head")

		hideDefaultTag(character)

		local plrTag = nameTag:Clone()
		plrTag.PlayerName.Text = player.Name
		updateTagColor(plrTag, player)
		plrTag.Parent = character.Head

		-- Met à jour la couleur si l'attribut du joueur change
		local colorConnection = player:GetAttributeChangedSignal("TabColor"):Connect(function()
			updateTagColor(plrTag, player)
		end)

		-- Supprime le tag à la mort du personnage
		local humanoid = character:WaitForChild("Humanoid")
		local deathConnection = humanoid.Died:Connect(function()
			if plrTag then plrTag:Destroy() end
		end)

		-- Nettoie les connexions pour éviter les fuites de mémoire
		character.AncestryChanged:Connect(function()
			if not character.Parent then
				colorConnection:Disconnect()
				if deathConnection then deathConnection:Disconnect() end
			end
		end)
	end)
end)