-- ============================================================
-- Ce script implémente une condition spécifique nommée
-- "Maxwell" pour restreindre les tirs, autorisant l'action
-- uniquement si le nombre de tirs effectués est inférieur
-- ou égal à un.
-- ============================================================

local module = {
	["Maxwell"] = function(Tool, Humanoid, Heat, MaxHeat, Mag, AmmoPerMag, Ammo, MaxAmmo, ShootCounts, CurrentFireRate)
		return ShootCounts <= 1
	end,
}

return table.isfrozen(module) and module or table.freeze(module)