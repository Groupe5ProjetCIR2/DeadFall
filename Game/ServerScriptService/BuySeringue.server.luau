-- ============================================================
-- Ce script gère l'achat et la suppression sécurisée de la seringue 
-- via des RemoteEvents pour communiquer avec le client.
-- ============================================================

local ServerStorage = game:GetService("ServerStorage")
local Toute_Les_Armes = ServerStorage:FindFirstChild("Toute_Les_Armes")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Crée les RemoteEvents s'ils n'existent pas encore
local BuySyringeEvent = ReplicatedStorage:FindFirstChild("BuySyringeEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
BuySyringeEvent.Name = "BuySyringeEvent"

local DestroyWeaponEvent = ReplicatedStorage:FindFirstChild("DestroyWeaponEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
DestroyWeaponEvent.Name = "DestroyWeaponEvent"

-- GESTION DE L'ACHAT
BuySyringeEvent.OnServerEvent:Connect(function(player, weaponName, price)
	if weaponName == "Seringue" then

		-- Vérifications de sécurité : possède le pass et pas déjà l'arme
		if player:GetAttribute("MedicMix") ~= true then return end

		local character = player.Character
		local backpack = player:FindFirstChild("Backpack")

		if (backpack and backpack:FindFirstChild("Seringue")) or (character and character:FindFirstChild("Seringue")) then
			return 
		end

		local leaderstats = player:FindFirstChild("leaderstats")
		local argent = leaderstats and leaderstats:FindFirstChild("Argent")

		-- Vérifie le budget et donne l'arme si tout est OK
		if argent and argent.Value >= price then
			local seringue = Toute_Les_Armes:FindFirstChild("Seringue")

			if seringue then
				argent.Value = argent.Value - price

				local nouvelleSeringue = seringue:Clone()
				nouvelleSeringue.Parent = backpack

				-- Force l'équipement immédiat de l'arme
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:EquipTool(nouvelleSeringue)
				end
			end
		end
	end
end)

-- GESTION DE LA DESTRUCTION PROPRE
DestroyWeaponEvent.OnServerEvent:Connect(function(player, toolToDestroy)
	-- Vérifie la possession de l'objet avant destruction pour éviter les erreurs
	if toolToDestroy and (toolToDestroy.Parent == player.Character or toolToDestroy.Parent == player:FindFirstChild("Backpack")) then
		toolToDestroy:Destroy()
	end
end)