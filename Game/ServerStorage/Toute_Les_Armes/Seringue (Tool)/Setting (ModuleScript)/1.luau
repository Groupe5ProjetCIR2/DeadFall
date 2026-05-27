-- ============================================================
-- Ce script définit le module de configuration pour une seringue
-- de soin, incluant la gestion des doses (munitions) et les
-- paramètres de lecture des animations (vitesse et identifiants
-- d'assets) pour les vues à la troisième et première personne.
-- ============================================================

local Module = {
	ModuleName = script.Name,
	
	LimitedAmmoEnabled = true,
	Ammo = 1,
	AmmoPerMag = 1, 

	EquippedAnimationSpeed = 1,
	EmptyEquippedAnimationSpeed = 1,
	IdleAnimationSpeed = 1,
	EmptyIdleAnimationSpeed = 1,

	InspectAnimationEnabled = true,
	InspectAnimationSpeed = 1,
	EmptyInspectAnimationSpeed = 1,

	VMEquippedAnimationSpeed = 1,
	VMEmptyEquippedAnimationSpeed = 1,
	VMIdleAnimationSpeed = 1,
	VMEmptyIdleAnimationSpeed = 1,
	VMInspectAnimationSpeed = 1,
	VMEmptyInspectAnimationSpeed = 1,

	EquippedAnimationID = nil,
	EmptyEquippedAnimationID = nil,

	IdleAnimationID = nil,
	EmptyIdleAnimationID = nil,

	InspectAnimationID = nil,
	EmptyInspectAnimationID = nil,

	VMEquippedAnimationID = nil,
	VMEmptyEquippedAnimationID = nil,

	VMIdleAnimationID = nil,
	VMEmptyIdleAnimationID = nil,

	VMInspectAnimationID = 90705926617067,
	VMEmptyInspectAnimationID = nil,
}

return table.isfrozen(Module) and Module or table.freeze(Module)