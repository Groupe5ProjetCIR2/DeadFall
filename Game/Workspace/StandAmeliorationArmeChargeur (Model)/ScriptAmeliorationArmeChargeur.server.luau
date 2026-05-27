-- ============================================================
-- Ce script gère l'amélioration de la capacité du chargeur d'une arme via une interaction avec un ProximityPrompt. 
-- Il valide les conditions requises (fonds, arme équipée, niveau max) avant d'appliquer les nouvelles statistiques et de synchroniser les munitions avec le client.
-- ============================================================

local prompt = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local updateEvent = ReplicatedStorage:WaitForChild("UpdateGunStatsEvent")
local Config = require(ReplicatedStorage:WaitForChild("UpgradesConfig"))

prompt.Style = Enum.ProximityPromptStyle.Custom
prompt.ActionText = "Upgrade magazine capacity"
prompt.ObjectText = tostring(Config.Prices.Magazine[2]) .. " $"

-- Écoute l'interaction du joueur, vérifie l'état de la machine, la possession d'une arme et le solde avant de procéder à l'amélioration
prompt.Triggered:Connect(function(player)
	local machineModel = script:FindFirstAncestorWhichIsA("Model")
	if machineModel and machineModel:GetAttribute("PowerOn") == false then 
		return 
	end

	local character = player.Character
	local equippedWeapon = character and character:FindFirstChildOfClass("Tool")

	if not equippedWeapon or not equippedWeapon:FindFirstChild("Setting") then 
		local oldText = prompt.ActionText
		prompt.ActionText = "Equip a weapon!"
		task.wait(1.5)
		prompt.ActionText = oldText
		return 
	end

	local dmgLevel = equippedWeapon:GetAttribute("DamageLevel") or 1
	local peneLevel = equippedWeapon:GetAttribute("PenetrationLevel") or 1
	local magLevel = equippedWeapon:GetAttribute("ChargeurLevel") or 1

	if magLevel >= 5 then 
		local oldText = prompt.ActionText
		prompt.ActionText = "Max Capacity Reached!"
		task.wait(1.5)
		prompt.ActionText = oldText
		return 
	end

	if not prompt.Enabled then return end
	prompt.Enabled = false 

	local nextLevel = magLevel + 1
	local cost = Config.Prices.Magazine[nextLevel]

	local moneyStats = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Argent")
	if not moneyStats or moneyStats.Value < cost then
		local oldText = prompt.ActionText
		prompt.ActionText = "Not enough money!"
		task.wait(1.5)
		prompt.ActionText = oldText
		prompt.Enabled = true
		return
	end

	moneyStats.Value -= cost

	equippedWeapon:SetAttribute("ChargeurLevel", nextLevel)

	-- Recalcule dynamiquement les nouvelles capacités maximales en se basant sur les valeurs d'origine du module de configuration
	local settings = require(equippedWeapon.Setting:FindFirstChild("1"))

	if not settings.OriginalAmmoPerMag then
		settings.OriginalAmmoPerMag = settings.AmmoPerMag
		settings.OriginalMaxAmmo = settings.MaxAmmo
	end

	local newMagSize = math.floor(settings.OriginalAmmoPerMag * Config.Paliers.Magazine[nextLevel])
	local newMaxAmmo = math.floor(settings.OriginalMaxAmmo * Config.Paliers.Magazine[nextLevel])

	settings.AmmoPerMag = newMagSize
	settings.MaxAmmo = newMaxAmmo

	local valueFolder = equippedWeapon:FindFirstChild("ValueFolder")
	if valueFolder and valueFolder:FindFirstChild("1") then
		local folder1 = valueFolder:FindFirstChild("1")
		if folder1:FindFirstChild("Mag") then folder1.Mag.Value = newMagSize end
		if folder1:FindFirstChild("Ammo") then folder1.Ammo.Value = newMaxAmmo end
	end

	-- Synchronise les nouvelles statistiques avec le client et force l'actualisation de l'affichage HUD ainsi que le rechargement complet
	updateEvent:FireClient(player, equippedWeapon, dmgLevel, peneLevel, nextLevel)

	local syncEvent = equippedWeapon:FindFirstChild("SyncWeaponEvent")
	if syncEvent then
		syncEvent:FireClient(player, "RefreshStats", {})
		syncEvent:FireClient(player, "SetAmmo", {Mag = newMagSize, Ammo = newMaxAmmo})
	end

	task.wait(1)
	prompt.Enabled = true
end)