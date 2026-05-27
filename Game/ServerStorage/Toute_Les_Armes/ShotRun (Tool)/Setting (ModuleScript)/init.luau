-- ============================================================
-- Ce script définit un module de configuration pour le système 
-- d'arme, regroupant les paramètres de comportement, de maniement 
-- et les entrées clavier/manette. Il centralise les variables 
-- permettant de personnaliser le gameplay lié à l'arme.
-- ============================================================

local Module = {
	AltFire = false; 

	ThirdPersonADS = true; 
	ForceFirstPerson = false; 

	AutoReload = true; 
	CancelReload = true; 

	DirectShootingAt = "None"; 

	CustomGripEnabled = false; 
	CustomGrips = {
		[1] = {
			CustomGripName = "Handle";
			CustomGripPart0 = {"Character", "Right Arm"}; 
			CustomGripPart1 = {"Tool", "Handle"}; 
			AlignC0AndC1FromDefaultGrip = true;
			CustomGripCFrame = false;
			CustomGripC0 = CFrame.new(0, 0, 0);
			CustomGripC1 = CFrame.new(0, 0, 0);    
		}
	};

	UniversalAmmoEnabled = false;
	Ammo = 60;
	MaxAmmo = 60;    

	WalkSpeedModifierEnabled = false;
	WalkSpeed = 32;

	DualWeldEnabled = false;    

	MagCartridge = false; 
	MaxCount = 200;
	RemoveOldAtMax = false;
	MaxRotationSpeed = 360;
	Drag = 1;
	Gravity = Vector2.new(0, 1000);
	Ejection = true;
	Shockwave = true;
	Velocity = 50;
	XMin = -4;
	XMax = -2;
	YMin = -6;
	YMax = -5;
	DropAllRemainingBullets = false;
	DropVelocity = 10;
	DropXMin = -5;
	DropXMax = 5;
	DropYMin = -0.1;
	DropYMax = 0;

	Keyboard = {
		Reload = Enum.KeyCode.R;
		HoldDown = Enum.KeyCode.E;
		Inspect = Enum.KeyCode.F;
		Switch = Enum.KeyCode.V;
		ToogleAim = Enum.KeyCode.Q;
		Melee = Enum.KeyCode.H;
		AltFire = Enum.KeyCode.C;
	};

	Controller = {
		Fire = Enum.KeyCode.ButtonR1;
		Reload = Enum.KeyCode.ButtonX;
		HoldDown = Enum.KeyCode.DPadUp;
		Inspect = Enum.KeyCode.DPadDown;
		Switch = Enum.KeyCode.DPadRight;
		ToogleAim = Enum.KeyCode.ButtonL1;
		Melee = Enum.KeyCode.ButtonR3;
		AltFire = Enum.KeyCode.DPadRight;
	};
}

-- Application d'une protection sur la table pour éviter toute modification accidentelle des paramètres en cours d'exécution.
return table.isfrozen(Module) and Module or table.freeze(Module)