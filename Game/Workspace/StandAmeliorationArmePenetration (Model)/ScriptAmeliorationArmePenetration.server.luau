-- ============================================================
-- Ce script gère l'amélioration de la pénétration des balles d'une arme via l'interaction avec un ProximityPrompt.
-- Il valide les conditions requises (fonds, arme équipée, niveau max) avant d'appliquer les nouvelles statistiques et de synchroniser les munitions avec le client.
-- ============================================================

local prompt = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local updateEvent = ReplicatedStorage:WaitForChild("UpdateGunStatsEvent")
local Config = require(ReplicatedStorage:WaitForChild("UpgradesConfig"))

prompt.Style = Enum.ProximityPromptStyle.Custom
prompt.ActionText = "Upgrade bullet penetration"
prompt.ObjectText = tostring(Config.Prices.Penetration[2]) .. " $"

-- Écoute l'interaction du joueur, s'assure que la machine est sous tension et qu'une arme valide est équipée avant de procéder aux vérifications de niveau et de fonds
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

	if peneLevel >= 5 then 
		local oldText = prompt.ActionText
		prompt.ActionText = "Max Penetration Reached!"
		task.wait(1.5)
		prompt.ActionText = oldText
		return 
	end

	if not prompt.Enabled then return end
	prompt.Enabled = false 

	local nextLevel = peneLevel + 1
	local cost = Config.Prices.Penetration[nextLevel]

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

	equippedWeapon:SetAttribute("PenetrationLevel", nextLevel)

	-- Modifie dynamiquement les paramètres de pénétration du module de l'arme pour que le moteur de tir prenne en compte la nouvelle statistique
	local settings = require(equippedWeapon.Setting:FindFirstChild("1"))

	settings.PenetrationType = "HumanoidPenetration"
	settings.PenetrationAmount = Config.Paliers.Penetration[nextLevel]

	updateEvent:FireClient(player, equippedWeapon, dmgLevel, nextLevel, magLevel)

	task.wait(1)
	prompt.Enabled = true
end)