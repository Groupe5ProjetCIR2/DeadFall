-- ============================================================
-- Ce script gère l'attribution d'une arme à un joueur après un tirage, en limitant l'inventaire à deux armes maximum. 
-- Il équipe automatiquement l'arme, remplace celle en main si le quota est plein, ou la renouvelle si elle est déjà possédée.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local weaponsFolder = ServerStorage:WaitForChild("Toute_Les_Armes")
local giveWeaponEvent = ReplicatedStorage:WaitForChild("GiveSpinnerWeapon")

-- Écoute l'événement de la roulette pour distribuer l'arme demandée au joueur tout en gérant les limites d'inventaire
giveWeaponEvent.OnServerEvent:Connect(function(player, weaponName)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChild("Backpack")

	if not backpack or not humanoid then return end

	local weaponsInBackpack = backpack:GetChildren()
	local equippedWeapon = character:FindFirstChildOfClass("Tool")

	-- Parcours l'inventaire inactif pour forcer l'équipement direct si l'arme s'y trouve déjà
	for _, tool in pairs(weaponsInBackpack) do
		if tool.Name == weaponName then 
			print("L'arme est déjà dans le sac, je l'équipe automatiquement !")
			humanoid:EquipTool(tool)
			return 
		end
	end

	-- Valide l'existence du modèle de l'arme côté serveur avant toute tentative de clonage
	local weaponModel = weaponsFolder:FindFirstChild(weaponName)
	if not weaponModel then 
		warn("L'arme " .. tostring(weaponName) .. " n'existe pas dans le dossier !")
		return 
	end

	-- Renouvelle l'arme actuellement tenue en main via une mise en file de destruction par le service Debris
	if equippedWeapon and equippedWeapon.Name == weaponName then
		print("L'arme est en main, je la remplace par une neuve (réparée) !")

		equippedWeapon.Parent = backpack
		Debris:AddItem(equippedWeapon, 1)

		local newWeapon = weaponModel:Clone()
		newWeapon.Parent = backpack
		humanoid:EquipTool(newWeapon)

		return
	end

	local totalWeaponsCount = #weaponsInBackpack + (equippedWeapon and 1 or 0)

	if totalWeaponsCount < 2 then
		print("CHEMIN 1 : Moins de 2 armes. J'ajoute au sac et j'équipe.")
		local newWeapon = weaponModel:Clone()
		newWeapon.Parent = backpack
		humanoid:EquipTool(newWeapon)

	else
		-- Écrase l'arme équipée actuelle avec un délai de suppression sécurisé si le quota d'armes est atteint
		if equippedWeapon then
			print("CHEMIN 2 : 2 armes ET une arme en main (" .. equippedWeapon.Name .. "). Je remplace et j'équipe !")

			equippedWeapon.Parent = backpack
			Debris:AddItem(equippedWeapon, 1)

			local newWeapon = weaponModel:Clone()
			newWeapon.Parent = backpack
			humanoid:EquipTool(newWeapon)
		else
			-- Force le remplacement du premier objet du sac à dos si l'inventaire est plein mais qu'aucune arme n'est active
			print("CHEMIN 3 : 2 armes, MAIS le serveur pense que tu as les MAINS VIDES. Je remplace dans le sac et j'équipe.")

			if #weaponsInBackpack > 0 then
				local oldWeapon = weaponsInBackpack[1]
				Debris:AddItem(oldWeapon, 1)
			end

			local newWeapon = weaponModel:Clone()
			newWeapon.Parent = backpack
			humanoid:EquipTool(newWeapon)
		end
	end
end)