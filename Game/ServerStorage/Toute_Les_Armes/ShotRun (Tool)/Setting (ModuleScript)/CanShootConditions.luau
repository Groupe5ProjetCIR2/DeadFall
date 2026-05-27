-- ============================================================
-- Ce script définit un module de validation pour le tir,
-- utilisant une fonction de rappel pour vérifier les conditions
-- nécessaires avant d'autoriser une action de tir.
-- ============================================================

local module = {
	[1] = function(Tool, Humanoid, Heat, MaxHeat, Mag, AmmoPerMag, Ammo, MaxAmmo, ShootCounts, CurrentFireRate)
		return true
	end,
}

return table.isfrozen(module) and module or table.freeze(module)