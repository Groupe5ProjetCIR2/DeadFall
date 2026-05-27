-- ============================================================
--  Ce script sert de fichier de configuration (ModuleScript)
--  pour définir les statistiques et les prix des différents
--  paliers d'améliorations des stands d'armes du jeu.
-- ============================================================

local UpgradesConfig = {
	-- Multiplicateurs de statistiques
	Paliers = {
		Damage = { [1] = 1.00, [2] = 1.25, [3] = 1.50, [4] = 1.75, [5] = 2.00 },
		Penetration = { [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4 },
		Magazine = { [1] = 1.00, [2] = 1.25, [3] = 1.50, [4] = 1.75, [5] = 2.00 }
	},

	-- Prix des améliorations pour chaque stand
	Prices = {
		Damage = { [2] = 1000, [3] = 1250, [4] = 1500, [5] = 1750 },
		Penetration = { [2] = 1500, [3] = 1750, [4] = 2000, [5] = 2250 },
		Magazine = { [2] = 750, [3] = 1000, [4] = 1250, [5] = 1500 }
	}
}

return UpgradesConfig