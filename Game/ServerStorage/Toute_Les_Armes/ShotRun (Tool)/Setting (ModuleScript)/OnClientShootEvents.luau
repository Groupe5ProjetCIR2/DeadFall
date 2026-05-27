-- ============================================================
-- Ce script définit un module de gestion d'événements pour le
-- tir client, permettant d'exécuter une logique personnalisée
-- lors de l'action de tir. Il sert de template pour définir
-- des comportements spécifiques liés à l'arme ou au personnage.
-- ============================================================

local module = {
	["Template"] = function(OnClientShootEventData, Character, Viewmodel, Tool, Handle, VMHandle, CLDirections, SVDirections, FirePointObject, MuzzlePointObject, Misc)
		
	end,
}

return table.isfrozen(module) and module or table.freeze(module)