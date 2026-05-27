-- ============================================================
-- Ce script configure les paramètres détaillés d'une arme à 
-- pompe, incluant la balistique, les effets visuels, les 
-- mécaniques de tir (shotgun/pump), les animations et le 
-- comportement des accessoires. Il sert de fichier de réglages 
-- complet pour le système d'arme.
-- ============================================================

local Module = {
	ModuleName = script.Name; 

	MuzzleEffect = "MuzzleEffect";
	HitEffect = "HitEffect";
	BloodEffect = "BloodEffect";
	MetalEffect = "MetalEffect";
	BlockEffect = "BlockEffect";
	ExplosionEffect = "ExplosionEffect";
	LaserBeamEffect = "LaserBeamEffect";
	MeleeHitEffect = "MeleeHitEffect";
	MeleeBloodEffect = "MeleeBloodEffect";
	MeleeMetalEffect = "MeleeMetalEffect";
	MeleeBlockEffect = "MeleeBlockEffect";
	GoreEffect = "GoreEffect";
	ShellEjectEffect = "ShellEjectEffect";
	MotionBeam = "MotionBeam";

	FireSound = "FireSounds"; 
	LowAmmoSound = "LowAmmoSound";

	Handles = {
		"Handle";
	};        

	Auto = false;
	BaseDamage = 17; 
	FireRate = 0.85; 
	ReloadTime = 0.5; 
	AmmoPerMag = 10; 
	AmmoCost = 2; 
	Spread = 15; 
	DamageMultipliers = { 
		["Head"] = 1.5, 
	};
	HeadshotHitmarker = true;
	EquipTime = 0;
	EmptyEquipTime = 0;

	GainFireRateAsAutoFire = false;
	FireRateIncrement = 0.025;
	MaximumFireRate = 0.1;

	ShootCounts = 0;

	EquippedAnimationID = nil;
	EquippedAnimationSpeed = 1;

	EmptyEquippedAnimationID = nil;
	EmptyEquippedAnimationSpeed = 1;

	IdleAnimationID = nil; 
	IdleAnimationSpeed = 1;

	EmptyIdleAnimationID = nil;
	EmptyIdleAnimationSpeed = 1;

	ReloadAnimationID = nil; 
	ReloadAnimationSpeed = 1;

	-- Gestion des animations lors du tir, permettant de définir des comportements spécifiques par tir ou fin de chargeur.
	FireAnimations = {
		{
			FireAnimationID = nil; 
			FireAnimationSpeed = 1;
		};
	};

	LastFireAnimations = {
		{
			LastFireAnimationID = nil; 
			LastFireAnimationSpeed = 1;
		};
	};        

	VMEquippedAnimationID = 91711021232346;
	VMEquippedAnimationSpeed = 1;

	VMEmptyEquippedAnimationID = nil;
	VMEmptyEquippedAnimationSpeed = 1;

	VMIdleAnimationID = 119539602875514; 
	VMIdleAnimationSpeed = 1;

	VMEmptyIdleAnimationID = nil;
	VMEmptyIdleAnimationSpeed = 1;

	VMReloadAnimationID = nil; 
	VMReloadAnimationSpeed = 1;

	VMFireAnimations = {
		{
			VMFireAnimationID = 125311573810498; 
			VMFireAnimationSpeed = 1;
		};
	};

	VMLastFireAnimations = {
		{
			VMLastFireAnimationID = nil; 
			VMLastFireAnimationSpeed = 1;
		};
	};    

	AimIdleAnimationID = nil; 
	AimIdleAnimationSpeed = 1;

	EmptyAimIdleAnimationID = nil; 
	EmptyAimIdleAnimationSpeed = 1;

	AimFireAnimations = {
		{
			AimFireAnimationID = nil; 
			AimFireAnimationSpeed = 1;
		};
	};

	AimLastFireAnimations = {
		{
			AimLastFireAnimationID = nil; 
			AimLastFireAnimationSpeed = 1;
		};
	};

	AltAnimationID = nil;
	AltAnimationSpeed = 1;
	AltTime = 1;    
	AltName = "";

	VMAltAnimationID = nil; 
	VMAltAnimationSpeed = 1;

	KeepAimingOnReloading = true; 
	AlignToAimPoint = true; 

	MeleeAttackEnabled = false;

	MeleeAttackAnimationID = nil;
	MeleeAttackAnimationSpeed = 1;

	VMMeleeAttackAnimationID = nil; 
	VMMeleeAttackAnimationSpeed = 1;

	MeleeDamage = 20;    
	MeleeDamageMultipliers = { 
		["Head"] = 2,
	};
	MeleeHeadshotHitmarker = true;

	-- Configuration de la zone de détection pour les attaques de mêlée, utilisant une région rotative ou un rayon.
	HitboxType = "RotatedRegion"; 
	HitboxShape = Enum.PartType.Block;
	HitboxSize = Vector3.new(2.5, 2.5, 3);
	HitboxCFrame = CFrame.new(0, 0, -2);
	VMHitboxShape = Enum.PartType.Block;
	VMHitboxSize = Vector3.new(2.5, 2.5, 3);
	VMHitboxCFrame = CFrame.new(0, 0, -2);

	MaxPartsInRegion = 50;
	MaxHits = 1;
	HitIgnoreDelay = math.huge;

	RaycastHitboxInstances = {{"Tool", "Handle"}};
	RespectAltFireMode = true; 

	VMRaycastHitboxInstances = {"Handle"};

	BlockMelee = true; 
	BlockDelay = 0.1;    
	MeleeBlockEffectEnabled = true;
	MeleeBlockSoundIDs = {13583794181};
	MeleeBlockSoundPitchMin = 1; 
	MeleeBlockSoundPitchMax = 1; 
	MeleeBlockSoundVolume = 1;
	NormalizeMeleeBlockEffect = true;

	MeleeHitEffectEnabled = true;
	MeleeHitSoundIDs = {6000828622};
	MeleeHitSoundPitchMin = 1; 
	MeleeHitSoundPitchMax = 1.5; 
	MeleeHitSoundVolume = 1;
	CustomMeleeHitEffect = false; 
	NormalizeMeleeHitEffect = true;

	MarkerEffectEnabled = true;
	MarkerEffectSize = 0.5;
	MarkerEffectTexture = {2078626}; 
	MarkerEffectVisibleTime = 3; 
	MarkerEffectFadeTime = 1; 
	MarkerPartColor = true; 

	TriggerEffectOnce = false;    
	EffectDelay = 0.1; 

	MeleeBloodEnabled = true;
	MeleeHitCharSndIDs = {6398015798, 6398016125, 6398016391, 6398016618};
	MeleeHitCharSndPitchMin = 1; 
	MeleeHitCharSndPitchMax = 1; 
	MeleeHitCharSndVolume = 1;
	NormalizeMeleeBlood = false;

	MeleeBloodWoundEnabled = true;
	MeleeBloodWoundSize = 0.5;
	MeleeBloodWoundTexture = {2078626}; 
	MeleeBloodWoundTextureColor = Color3.fromRGB(255, 0, 0);
	MeleeBloodWoundVisibleTime = 3; 
	MeleeBloodWoundFadeTime = 1; 
	MeleeBloodWoundPartColor = true; 

	MeleeMetalEnabled = true; 
	MeleeHitMetalSndIDs = {5462109045, 5462111332, 5462112925, 5462114029};
	MeleeHitMetalSndPitchMin = 1; 
	MeleeHitMetalSndPitchMax = 1; 
	MeleeHitMetalSndVolume = 1;

	MeleeMetalHoleEnabled = true;
	MeleeMetalHoleSize = 0.5;
	MeleeMetalHoleTexture = {2078626}; 
	MeleeMetalHoleTextureColor = Color3.fromRGB(255, 0, 0);
	MeleeMetalHoleVisibleTime = 3; 
	MeleeMetalHoleFadeTime = 1; 
	MeleeMetalHolePartColor = true; 

	MeleeKnockback = 0; 
	MeleeLifesteal = 0; 
	MeleeDebuff = false; 
	MeleeDebuffName = "";
	MeleeDebuffChance = 100;
	ApplyMeleeDebuffOnCritical = false; 
	MeleeCanBreakGlass = true;

	MeleeCriticalDamageEnabled = false;
	MeleeCriticalBaseChance = 5; 
	MeleeCriticalDamageMultiplier = 3;

	OnMeleeHitEventName = "None";    
	OnMeleeHitEventData = {};

	LaserTrailEnabled = false;
	LaserTrailWidth = 0.5;
	LaserTrailHeight = 0.5;
	LaserTrailColor = Color3.fromRGB(0, 170, 255);
	RandomizeLaserColorIn = "None"; 
	LaserColorCycleTime = 5; 
	LaserTrailMaterial = Enum.Material.Neon;
	LaserTrailShape = "Block"; 
	LaserTrailReflectance = 0;
	LaserTrailTransparency = 0;
	LaserTrailVisibleTime = 1; 
	LaserTrailFadeTime = 0.5; 
	ScaleLaserTrail = false; 
	LaserTrailScaleMultiplier = 1.5;

	DamageableLaserTrail = false; 
	LaserTrailDamage = 20;
	LaserTrailConstantDamage = true; 
	LaserTrailDamageRate = 0.1; 

	LaserTrailKnockback = 0; 
	LaserTrailLifesteal = 0; 
	LaserTrailDebuff = false; 
	LaserTrailDebuffName = "";
	LaserTrailDebuffChance = 100;
	ApplyLaserTrailDebuffOnCritical = false; 

	LaserTrailCriticalDamageEnabled = false;
	LaserTrailCriticalBaseChance = 5; 
	LaserTrailCriticalDamageMultiplier = 3;

	OnLaserHitEventName = "None";    
	OnLaserHitEventData = {};

	LightningBoltEnabled = false;
	BoltCount = 1;
	BoltRadius = 5;
	BoltWideness = 5;
	BoltWidth = 0.5;
	BoltHeight = 0.5;
	BoltColor = Color3.fromRGB(0, 170, 255);
	RandomizeBoltColorIn = "None"; 
	BoltMaterial = Enum.Material.Neon;
	BoltShape = "Block"; 
	BoltReflectance = 0;
	BoltTransparency = 0;
	BoltVisibleTime = 1; 
	BoltFadeTime = 0.5; 
	ScaleBolt = false; 
	BoltScaleMultiplier = 1.5;    

	LaserBeam = false;
	LaserBeamRange = 100;
	LaserBeamStartupDelay = 1;
	LaserBeamStopDelay = 1;
	IgnoreHumanoids = false;
	LookAtInput = false; 

	LaserBeamStartupAnimationID = nil;
	LaserBeamStartupAnimationSpeed = 1;
	LaserBeamLoopAnimationID = nil;
	LaserBeamLoopAnimationSpeed = 1;
	LaserBeamStopAnimationID = nil;
	LaserBeamStopAnimationSpeed = 1;    

	VMLaserBeamStartupAnimationID = nil;
	VMLaserBeamStartupAnimationSpeed = 1;
	VMLaserBeamLoopAnimationID = nil;
	VMLaserBeamLoopAnimationSpeed = 1;
	VMLaserBeamStopAnimationID = nil;
	VMLaserBeamStopAnimationSpeed = 1;

	LimitedAmmoEnabled = true;
	Ammo = 60;
	MaxAmmo = 60;    

	CrossSize = 25; 
	CrossExpansion = 200;
	CrossSpeed = 15;
	CrossDamper = 0.8;    

	HitmarkerEnabled = true;
	HitmarkerSoundIDs = {3748776946, 3748777642, 3748780065};
	HitmarkerColor = Color3.fromRGB(255, 255, 255);
	HitmarkerFadeTime = 0.4;
	HitmarkerSoundPitch = 1;
	HitmarkerColorHS = Color3.fromRGB(255, 0, 0);
	HitmarkerFadeTimeHS = 0.4;
	HitmarkerSoundPitchHS = 1;    

	CameraRecoilingEnabled = true;
	Recoil = 60; 
	AngleXMin = 2; 
	AngleXMax = 4; 
	AngleYMin = -1; 
	AngleYMax = 1; 
	AngleZMin = -2; 
	AngleZMax = 2; 
	Accuracy = 0.1; 
	RecoilSpeed = 15; 
	RecoilDamper = 0.65;

	ViewmodelRecoilInfluence = 0.1;

	ADSEnabled = true;
	ADSType = "Ironsight";
	ADSFieldOfView = 50;
	ADSMouseSensitivity = 0.6; 
	ADSSpreadRedution = 0.6; 
	ADSRecoilRedution = 0.6; 
	ADSCrossScale = 0.6;
	HideCrosshair = true;
	ScopeDelay = 0; 
	ScopeSensitivity = 0.25;
	ScopeKnockbackMultiplier = 5;
	ScopeKnockbackSpeed = 15;
	ScopeKnockbackDamper = 0.65;
	ScopeSwaySpeed = 15;
	ScopeSwayDamper = 0.65;

	TweenLength = 0.3; 
	EasingStyle = Enum.EasingStyle.Quart;
	EasingDirection = Enum.EasingDirection.Out;

	TweenLengthNAD = 0.5; 
	EasingStyleNAD = Enum.EasingStyle.Quart;
	EasingDirectionNAD = Enum.EasingDirection.Out;

	HideWhenADS = false; 

	SmokeTrailEnabled = true;
	SmokeTrailRateIncrement = 1;
	MaximumRate = 4; 
	MaximumTime = 1; 

	SilenceEffect = false; 
	EchoEffect = true; 
	LowAmmo = true; 
	RaisePitch = false; 
	ShouldLoop = false; 

	GoreEffectEnabled = false;
	GoreSoundIDs = {1930359546};
	GoreSoundPitchMin = 1; 
	GoreSoundPitchMax = 1.5; 
	GoreSoundVolume = 1;
	FullyGibbedLimbChance = 50; 

	InspectAnimationEnabled = true;
	InspectAnimationID = nil; 
	InspectAnimationSpeed = 1;

	EmptyInspectAnimationID = nil;
	EmptyInspectAnimationSpeed = 1;

	VMInspectAnimationID = 91711021232346; 
	VMInspectAnimationSpeed = 1;    

	VMEmptyInspectAnimationID = nil;
	VMEmptyInspectAnimationSpeed = 1;

	TacticalReloadAnimationEnabled = false;
	TacticalReloadAnimationID = nil; 
	TacticalReloadAnimationSpeed = 1;
	TacticalReloadTime = 3;

	VMTacticalReloadAnimationID = nil; 
	VMTacticalReloadAnimationSpeed = 1;    

	HoldDownEnabled = true;
	HoldDownAnimationID = nil;
	HoldDownAnimationSpeed = 0.5;    

	VMHoldDownAnimationID = 111498843056204;
	VMHoldDownAnimationSpeed = 0.5;    

	DamageDropOffEnabled = true; 
	ZeroDamageDistance = 150; 
	FullDamageDistance = 30; 

	CriticalDamageEnabled = false;
	CriticalBaseChance = 5; 
	CriticalDamageMultiplier = 3;

	HitEffectEnabled = true;
	HitSoundIDs = {186809061, 186809249, 186809250, 186809252};
	HitSoundPitchMin = 1; 
	HitSoundPitchMax = 1.5; 
	HitSoundVolume = 1;
	CustomHitEffect = false; 
	NormalizeHitEffect = true;

	BulletHoleEnabled = true;
	BulletHoleSize = 0.5;
	BulletHoleTexture = {2078626}; 
	BulletHoleVisibleTime = 3; 
	BulletHoleFadeTime = 1; 
	PartColor = true; 

	BloodEnabled = true;
	HitCharSndIDs = {3802437008, 3802437361, 3802437696, 3802440043, 3802440388, 3802442962};
	HitCharSndPitchMin = 1; 
	HitCharSndPitchMax = 1; 
	HitCharSndVolume = 1;
	NormalizeBlood = false;

	BloodWoundEnabled = true;
	BloodWoundSize = 0.5;
	BloodWoundTexture = {2078626}; 
	BloodWoundTextureColor = Color3.fromRGB(255, 0, 0);
	BloodWoundVisibleTime = 3; 
	BloodWoundFadeTime = 1; 
	BloodWoundPartColor = true; 

	MetalEnabled = true; 
	HitMetalSndIDs = {5462109045, 5462111332, 5462112925, 5462114029};
	HitMetalSndPitchMin = 1; 
	HitMetalSndPitchMax = 1; 
	HitMetalSndVolume = 1;

	MetalHoleEnabled = true;
	MetalHoleSize = 0.5;
	MetalHoleTexture = {2078626}; 
	MetalHoleTextureColor = Color3.fromRGB(255, 0, 0);
	MetalHoleVisibleTime = 3; 
	MetalHoleFadeTime = 1; 
	MetalHolePartColor = true;     

	WhizSoundEnabled = true;
	WhizSoundIDs = {3809084884, 3809085250, 3809085650, 3809085996, 3809086455};
	WhizSoundVolume = 1;
	WhizSoundPitchMin = 1; 
	WhizSoundPitchMax = 1; 
	WhizDistance = 25;

	MuzzleFlashEnabled = true;
	MuzzleLightEnabled = true;
	LightBrightness = 4;
	LightColor = Color3.new(255/255, 283/255, 0/255);
	LightRange = 15;
	LightShadows = true;
	VisibleTime = 0.01; 

	BulletShellEnabled = true;
	BulletShellType = "Shotgun"; 
	BulletShellDelay = 0;
	BulletShellVelocity = 17;
	BulletShellRotVelocity = 40;
	RadomizeRotVelocity = true;
	AllowCollide = false; 
	DisappearTime = 5; 
	BulletShellParticles = false;

	BulletShellHitSoundEnabled = true;
	BulletShellHitSoundIDs = {3909012115};
	BulletShellHitSoundVolume = 1;
	BulletShellHitSoundPitchMin = 1; 
	BulletShellHitSoundPitchMax = 1; 

	ShotgunEnabled = true; 
	BulletPerShot = 8;

	ShotgunPump = true; 
	ShotgunPumpinSpeed = 0.5; 
	ShotgunPumpinAnimations = {
		{
			ShotgunPumpinAnimationID = nil; 
			ShotgunPumpinAnimationSpeed = 1;
		};
	};

	VMShotgunPumpinAnimations = {
		{
			VMShotgunPumpinAnimationID = nil; 
			VMShotgunPumpinAnimationSpeed = 1;
		};
	};

	ShotgunReload = true; 
	ShotgunClipinAnimationID = nil; 
	ShotgunClipinAnimationSpeed = 1;
	ShellClipinSpeed = 0.75; 
	PreShotgunReload = false; 
	PreShotgunReloadAnimationID = nil; 
	PreShotgunReloadAnimationSpeed = 1;
	PreShotgunReloadSpeed = 0.5; 

	VMShotgunClipinAnimationID = 118830759127136; 
	VMShotgunClipinAnimationSpeed = 1;
	VMPreShotgunReloadAnimationID = nil; 
	VMPreShotgunReloadAnimationSpeed = 1;

	ShotgunPattern = false;
	SpreadPattern = { 
		{0, -0.4};
		{-0.35, 0.2};
		{0.35, 0.2};
		{0, 1};
		{0.95, 0.31};
		{0.59, -0.81};
		{-0.59, -0.81};
		{-0.95, 0.31};
	};

	BurstFireEnabled = false;
	BulletPerBurst = 3;
	BurstRate = 0.075; 
	CycleHandles = false; 

	SelectiveFireEnabled = false;
	FireModes = {1, 2, 3, true}; 
	FireRates = {0.125, 0.5, 0.5, 0.1};
	BurstRates = {0, 0.075, 0.075, 0};
	FireModeTexts = {"SEMI-AUTO", "2-ROUND-BURST", "3-ROUND-BURST", "AUTO"};
	SwitchTime = 0.25; 

	SwitchAnimationID = nil; 
	SwitchAnimationSpeed = 1;

	VMSwitchAnimationID = nil; 
	VMSwitchAnimationSpeed = 1;    

	ExplosiveEnabled = false;
	ExplosionSoundEnabled = true;
	ExplosionSoundIDs = {163064102};
	ExplosionSoundVolume = 1;
	ExplosionSoundPitchMin = 1; 
	ExplosionSoundPitchMax = 1.5; 
	ExplosionRadius = 8;

	DamageBasedOnDistance = false;
	DamageThroughWall = true;

	SelfDamage = false;
	SelfDamageRedution = 0.5; 
	ReduceSelfDamageOnAirOnly = false;

	CustomExplosion = false;

	ExplosionKnockback = false; 
	ExplosionKnockbackPower = 50;
	ExplosionKnockbackMultiplierOnPlayer = 2;
	ExplosionKnockbackMultiplierOnTarget = 2;

	ExplosionCraterEnabled = true;
	ExplosionCraterSize = 3;
	ExplosionCraterTexture = {53875997}; 
	ExplosionCraterVisibleTime = 3; 
	ExplosionCraterFadeTime = 1; 
	ExplosionCraterPartColor = false; 

	ProjectileType = "NewBullet"; 
	BulletSpeed = 2000;
	TravelType = "Distance"; 
	Range = 5000; 
	Lifetime = 5; 
	Acceleration = Vector3.new(0, 0, 0);
	RealAcceleration = 0;
	InvertRealAcceleration = false; 
	InitialBulletSpeed = 0; 

	BulletParticle = false;
	BulletType = "Normal";
	MotionBlur = true;
	BulletSize = 0.4;
	BulletBloom = 0.005;
	BulletBrightness = 400;

	CanSpinPart = false;
	SpinX = 3;
	SpinY = 0;
	SpinZ = 0;

	DebrisProjectile = false; 
	AnchorDebris = false;
	CollideDebris = true;
	NormalizeDebris = false;
	BounceDebris = true; 
	BounceVelocity = 30;
	WeldDebris = false; 

	DecayProjectile = false; 
	AnchorDecay = false;
	CollideDecay = true;
	DecayVelocity = 30;
	VelocityInfluence = true; 

	DisableDebrisContents = {  
		Light = false;
		Particle = false;
		Trail = false;
		Beam = false;
		Sound = false;
	};

	Homing = false; 
	HomingDistance = 250;
	TurnRatePerSecond = 1;
	HomeThroughWall = false;
	LockOnOnHovering = false;
	LockOnRadius = 10;
	LockOnDistance = 100;
	LockOnThroughWall = true;

	BlockBullet = true; 
	BlockEffectEnabled = true;
	BlockSoundIDs = {13583794181};
	BlockSoundPitchMin = 1; 
	BlockSoundPitchMax = 1; 
	BlockSoundVolume = 1;
	NormalizeBlockEffect = true;
	ReflectBullet = true; 

	RaycastHitbox = false; 
	RaycastHitboxData = { 
		CFrame.new(-1, 1, -1);
		CFrame.new(1, 1, -1);
		CFrame.new(-1, -1, -1);
		CFrame.new(1, -1, -1);
		CFrame.new(1, -1, 1);
		CFrame.new(-1, -1, 1);
		CFrame.new(-1, 1, 1);
		CFrame.new(1, 1, 1);
	};

	ShapeCast = false; 
	CastShape = "Block"; 
	CastSize = Vector3.new(1, 1, 1); 
	CastRadius = 5; 

	AnchorPoint = CFrame.new(0, 0, 0); 
	BounceDelay = 1; 

	UpdateRayInExtra = false; 
	ExtraRayUpdater = "Template"; 

	ShootType = "Projectile";
	CustomShotName = "Template"; 
	CustomShotData = {};

	ChargedShotEnabled = false;
	ChargingTime = 1;

	MinigunEnabled = false;
	DelayBeforeFiring = 1;
	DelayAfterFiring = 1;
	MinigunRevUpAnimationID = nil;
	MinigunRevUpAnimationSpeed = 1;
	MinigunRevDownAnimationID = nil;
	MinigunRevDownAnimationSpeed = 1;

	VMMinigunRevUpAnimationID = nil;
	VMMinigunRevUpAnimationSpeed = 1;
	VMMinigunRevDownAnimationID = nil;
	VMMinigunRevDownAnimationSpeed = 1;    

	BatteryEnabled = false;
	MaxHeat = 100;
	TimeBeforeCooldown = 3;
	CooldownTime = 0.05;
	CooldownRate = 1; 
	OverheatTime = 2.5;
	HeatPerFireMin = 7;
	HeatPerFireMax = 8;
	MinDepletion = 2;
	MaxDepletion = 4;
	ShotsForDepletion = 12;

	OverheatEffect = "Template";

	OverheatAnimationID = nil;
	OverheatAnimationSpeed = 1;

	VMOverheatAnimationID = nil;
	VMOverheatAnimationSpeed = 1;

	Knockback = 0; 
	Lifesteal = 0; 

	Debuff = false; 
	DebuffName = "";
	DebuffChance = 100;
	ApplyDebuffOnCritical = false; 

	PenetrationType = "HumanoidPenetration"; 
	PenetrationDepth = 0; 
	PenetrationAmount = 0; 
	PenetrationIgnoreDelay = math.huge; 
	PenetrationModifiers = {}; 

	BounceAmount = 0; 
	BounceElasticity = 1;
	FrictionConstant = 0;
	IgnoreSlope = false; 
	SlopeAngle = 45; 
	BounceHeight = 50;
	NoExplosionWhileBouncing = false; 
	StopBouncingOn = "None"; 
	SuperBounce = false; 
	BounceBetweenHumanoids = false; 
	PredictDirection = false; 
	MaxBounceAngle = 0; 
	UsePartDensity = false; 
	UseBulletSpeed = false; 

	HitEventOnTermination = true; 

	SelfKnockback = false; 
	SelfKnockbackPower = 50;
	SelfKnockbackMultiplier = 2;
	SelfKnockbackRedution = 0.8;

	ProjectileMotion = false; 

	FriendlyFire = false; 

	BlacklistParts = {["Part Name Here"] = true}; 
	IgnoreBlacklistedParts = true; 

	CanBreakGlass = true;

	OnHitEventName = "None";
	OnHitEventData = {};

	OnShootEventName = "None";
	OnShootEventData = {};        

	OnClientShootEventName = "None";
	OnClientShootEventData = {};        

	ChargedShotAdvanceEnabled = false;
	ShouldFireBeforeCharging = true;
	TimeBeforeAdvancedCharging = 0;
	AdvancedChargingTime = 5; 
	Level1ChargingTime = 1;
	Level2ChargingTime = 2;
	ChargeLevelCap = 3; 
	ChargingSoundIncreasePitch = true;
	ChargingSoundPitchRange = {1, 1.5};

	ChargeEffect = "Template";

	ChargingAnimationEnabled = false; 
	ChargingAnimationID = nil; 
	ChargingAnimationSpeed = 1;
	ChargingAnimationFadeTime = 0.1;

	AimChargingAnimationID = nil; 
	AimChargingAnimationSpeed = 1;
	AimChargingAnimationFadeTime = 0.1;

	VMChargingAnimationID = nil;
	VMChargingAnimationSpeed = 1;
	VMChargingAnimationFadeTime = 0.1;

	ChargeAlterTable = {};

	HoldAndReleaseEnabled = false;
	TimeBeforeHolding = 0;
	HoldingTime = 1; 

	HoldChargeEffect = "Template";

	LockOnScan = false; 
	TimeBeforeScan = 0.5;
	ScanRate = 0.5;
	ScanRateOnLockedTarget = 0.5;
	MaximumTargets = 3; 
	LockOnScanBurstRate = 0.1; 
	InstaBurst = false;
	TriggerOnce = false; 
	RemoveTargetsWhenOutbound = true;
	ShouldFireWhenTheresTarget = false;
	IgnoreLockedTargets = true;
	ContinueTrackingTargets = true; 
	StayInCenter = false;
	Radar = "Default";
	Marker = "Default";
	OnScannerToggle = function(Frame, MaximumTargets, Enabled)
		if Frame then
			local TweenService = game:GetService("TweenService")
			if Enabled then
				Frame.Scan:Play()
				Frame.Message.Text = "Searching targets... (0/"..MaximumTargets..")"
				TweenService:Create(Frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.5, 0.5)}):Play()
				TweenService:Create(Frame.UIStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
				TweenService:Create(Frame.Message, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextStrokeTransparency = 0.75, TextTransparency = 0}):Play()
			else
				Frame.Message.Text = ""
				TweenService:Create(Frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.5 * 1.25, 0.5 * 1.25)}):Play()
				TweenService:Create(Frame.UIStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1}):Play()
				TweenService:Create(Frame.Message, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextStrokeTransparency = 1, TextTransparency = 1}):Play()
			end
		end
	end;
	OnScannerUpdate = function(Frame, TargetCounts, MaximumTargets, AlreadyLocked, Track)
		if Frame then
			if TargetCounts < MaximumTargets then
				if Track then
					Frame["LockOn"..(AlreadyLocked and "Continue" or "")]:Play()
				end
				Frame.Message.Text = "Searching targets... ("..TargetCounts.."/"..MaximumTargets..")"
			else
				if Track then
					Frame.LockOnFull:Play()
				end
				Frame.Message.Text = "Ready! ("..TargetCounts.."/"..MaximumTargets..")"
			end
		end
	end;
	OnScannerRender = function(Frame, dt)
	end;
	OnTrackingTarget = function(Marker)
	end;

	Conditions = {}; 
	ConditionsInIndividualShot = {}; 
	ConditionsInIndividualBullet = {}; 

	AnimationKeyframes = {};
	VMAnimationKeyframes = {};
}

-- Application d'une protection sur la table pour éviter toute modification accidentelle des paramètres en cours d'exécution.
return table.isfrozen(Module) and Module or table.freeze(Module)