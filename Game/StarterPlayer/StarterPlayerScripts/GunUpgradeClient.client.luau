-- ============================================================
--  Ce script a pour but de mettre à jour dynamiquement les 
--  statistiques d'une arme côté client suite à une amélioration. 
--  Il réceptionne les niveaux d'amélioration du serveur, 
--  sauvegarde les statistiques d'usine de l'arme pour garantir 
--  des calculs justes, puis applique les nouveaux multiplicateurs.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local updateEvent = ReplicatedStorage:WaitForChild("UpdateGunStatsEvent")
local Config = require(ReplicatedStorage:WaitForChild("UpgradesConfig"))

-- S'exécute à la réception du signal serveur pour modifier en direct les paramètres de l'arme en fonction des niveaux reçus
updateEvent.OnClientEvent:Connect(function(arme, nivDmg, nivPene, nivMag)
	if not arme then return end

	local setting = arme:WaitForChild("Setting", 5)
	if not setting then return end

	local module = require(setting:WaitForChild("1") :: ModuleScript)

	-- Mise en cache des statistiques d'origine lors du premier appel pour éviter une croissance exponentielle des valeurs lors d'améliorations successives
	if not module.OriginalBaseDamage then
		module.OriginalBaseDamage = module.BaseDamage
		module.OriginalAmmoPerMag = module.AmmoPerMag
		module.OriginalMaxAmmo = module.MaxAmmo
	end

	-- Calcule et écrase les statistiques actuelles en multipliant les valeurs de base sauvegardées par les coefficients de la configuration
	module.BaseDamage = module.OriginalBaseDamage * Config.Paliers.Damage[nivDmg]
	module.PenetrationAmount = Config.Paliers.Penetration[nivPene]
	module.AmmoPerMag = math.floor(module.OriginalAmmoPerMag * Config.Paliers.Magazine[nivMag])
	module.MaxAmmo = math.floor(module.OriginalMaxAmmo * Config.Paliers.Magazine[nivMag])
end)