local Module = {
	ModuleName = script.Name,

	-- ==========================================
	-- PARAMÈTRES GLOBAUX SERINGUE
	-- ==========================================
	UniversalAmmoEnabled = false,
	WalkSpeedModifierEnabled = false,
	CustomGripEnabled = false,
	CustomGrips = {}, 

	-- ==========================================
	-- TOUCHES (INPUTS)
	-- ==========================================
	Keyboard = {
		Inspect = Enum.KeyCode.F,
	},

	Controller = {
		Inspect = Enum.KeyCode.DPadDown,
	};
}

return table.isfrozen(Module) and Module or table.freeze(Module)