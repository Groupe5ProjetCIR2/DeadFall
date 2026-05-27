-- ============================================================
-- Ce script gère l'achat et le rechargement d'une arme accrochée au mur via un ProximityPrompt en vérifiant l'argent et l'inventaire du joueur.
-- Il permet de remplir les munitions si l'arme est déjà en main, ou de l'acheter en remplaçant intelligemment l'arme actuelle si l'inventaire est plein.
-- ============================================================

local prompt = script.Parent
local wallPart = prompt.Parent

local weaponName = wallPart:GetAttribute("WeaponName")
local price = wallPart:GetAttribute("Price")

prompt.ObjectText = tostring(price) .. " $" 
prompt.Style = Enum.ProximityPromptStyle.Custom

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris") 
local weaponsFolder = ServerStorage:WaitForChild("Toute_Les_Armes")

-- Déclenche le processus de transaction en vérifiant la solvabilité du joueur, la possession de l'arme et gère dynamiquement le rechargement ou l'ajout à l'inventaire
prompt.Triggered:Connect(function(player)
	if not prompt.Enabled then return end
	prompt.Enabled = false

	local character = player.Character
	if not character then prompt.Enabled = true return end

	local leaderstats = player:FindFirstChild("leaderstats")
	local points = leaderstats and leaderstats:FindFirstChild("Argent")

	if not points or points.Value < price then 
		task.wait(0.5)
		prompt.Enabled = true
		return 
	end

	local backpack = player:FindFirstChild("Backpack")
	local equippedWeapon = character:FindFirstChildOfClass("Tool")

	local inBackpack = backpack and backpack:FindFirstChild(weaponName)
	local isEquipped = (equippedWeapon and equippedWeapon.Name == weaponName)

	if inBackpack and not isEquipped then
		task.wait(0.5)
		prompt.Enabled = true
		return
	end

	if isEquipped then
		points.Value -= price

		-- Accède dynamiquement aux modules de configuration de l'arme pour recalculer et synchroniser les valeurs maximales de munitions
		local setting1 = equippedWeapon:WaitForChild("Setting"):WaitForChild("1")
		local settings = require(setting1)
		local mainSettings = require(equippedWeapon.Setting)

		local maxMag = settings.AmmoPerMag
		local maxStock = 0

		if mainSettings.UniversalAmmoEnabled then
			maxStock = mainSettings.Ammo
		else
			maxStock = settings.MaxAmmo
		end

		local valueFolder = equippedWeapon:FindFirstChild("ValueFolder")
		if valueFolder then
			local folder1 = valueFolder:FindFirstChild("1")
			if folder1 then
				if folder1:FindFirstChild("Mag") then folder1.Mag.Value = maxMag end
				if folder1:FindFirstChild("Ammo") then folder1.Ammo.Value = maxStock end
			end
			if mainSettings.UniversalAmmoEnabled and valueFolder:FindFirstChild("Ammo") then
				valueFolder.Ammo.Value = maxStock
			end
		end

		local syncEvent = equippedWeapon:FindFirstChild("SyncWeaponEvent")
		if syncEvent then
			syncEvent:FireClient(player, "SetAmmo", {Mag = maxMag, Ammo = maxStock})
		end

		task.wait(1)
		prompt.Enabled = true
		return 
	end

	local weaponModel = weaponsFolder:FindFirstChild(weaponName)
	if weaponModel then
		points.Value -= price
		local newWeapon = weaponModel:Clone()

		local weaponsInBackpack = backpack:GetChildren()
		local totalWeaponsCount = #weaponsInBackpack + (equippedWeapon and 1 or 0)
		local humanoid = character:FindFirstChildOfClass("Humanoid")

		if totalWeaponsCount < 2 then
			newWeapon.Parent = backpack
			if humanoid then humanoid:EquipTool(newWeapon) end
		else
			if equippedWeapon then
				equippedWeapon.Parent = backpack

				-- Utilise le service Debris pour planifier la destruction de l'ancienne arme, ce qui laisse le temps au client de traiter le déséquipement sans provoquer d'erreurs
				Debris:AddItem(equippedWeapon, 1)

				newWeapon.Parent = backpack
				if humanoid then humanoid:EquipTool(newWeapon) end
			else
				if #weaponsInBackpack > 0 then 
					local oldWeapon = weaponsInBackpack[1]
					Debris:AddItem(oldWeapon, 1) 
				end
				newWeapon.Parent = backpack
				if humanoid then humanoid:EquipTool(newWeapon) end
			end
		end
	end

	task.wait(1)
	prompt.Enabled = true
end)