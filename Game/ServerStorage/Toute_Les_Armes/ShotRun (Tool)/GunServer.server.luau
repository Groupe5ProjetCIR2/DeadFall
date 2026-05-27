-- ============================================================
-- Ce script gère l'initialisation côté serveur d'une arme, incluant la configuration des munitions et des dossiers d'animations.
-- Il orchestre également la gestion des poignées personnalisées (CustomGrips) et la synchronisation des données de tir entre le serveur et les clients.
-- ============================================================

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Tool = script.Parent
local Player
local Character
local Humanoid
local LeftArm
local RightArm
local OriginalWalkSpeed
local Grip2
local Handle2
local Motor6DInstances = {}
local GripId = 0
local DefaultC0
local DefaultC1

local Setting = Tool:WaitForChild("Setting")
local Module = require(Setting)

local ChangeMagAndAmmo = script:WaitForChild("ChangeMagAndAmmo")
local SyncWeaponEvent = Tool:FindFirstChild("SyncWeaponEvent") or Instance.new("RemoteEvent")
SyncWeaponEvent.Name = "SyncWeaponEvent"
SyncWeaponEvent.Parent = Tool

local AnimationFolder = Tool:FindFirstChild("AnimationFolder") or Instance.new("Folder")
AnimationFolder.Name = "AnimationFolder"
AnimationFolder.Parent = Tool

local ValueFolder = Tool:FindFirstChild("ValueFolder") or Instance.new("Folder")
ValueFolder.Name = "ValueFolder"
ValueFolder.Parent = Tool

local Settings = {}
for i, v in pairs(Setting:GetChildren()) do
	if v.Name ~= "CanShootConditions" and v.Name ~= "ConditionableGunMods" and v.Name ~= "OnClientShootEvents" then
		table.insert(Settings, v)
	end
end
table.sort(Settings, function(a, b)
	return tonumber(a.Name) < tonumber(b.Name)
end)

-- On ne remet les balles par défaut que si c'est la 1ère fois
if Module.UniversalAmmoEnabled then
	local AmmoValue = ValueFolder:FindFirstChild("Ammo")
	if not AmmoValue then
		AmmoValue = Instance.new("NumberValue")
		AmmoValue.Name = "Ammo"
		AmmoValue.Value = Module.Ammo
		AmmoValue.Parent = ValueFolder
	end
end

if Module.DualWeldEnabled then
	Handle2 = Tool:WaitForChild("Handle2", 1)
	if Handle2 == nil and Module.DualWeldEnabled then error("\"Dual\" setting is enabled but \"Handle2\" is missing!") end
end

for i, v in ipairs(Settings) do
	local Module2 = require(v)

	local ValFolder = ValueFolder:FindFirstChild(tostring(i)) or Instance.new("Folder")
	ValFolder.Name = tostring(i)
	ValFolder.Parent = ValueFolder

	local MagValue = ValFolder:FindFirstChild("Mag")
	if not MagValue then
		MagValue = Instance.new("NumberValue")
		MagValue.Name = "Mag"
		MagValue.Value = Module2.AmmoPerMag
		MagValue.Parent = ValFolder
	end

	local AmmoValue = ValFolder:FindFirstChild("Ammo")
	if not AmmoValue then
		AmmoValue = Instance.new("NumberValue")
		AmmoValue.Name = "Ammo"
		AmmoValue.Value = (not Module.UniversalAmmoEnabled and Module2.LimitedAmmoEnabled) and Module2.Ammo or 0
		AmmoValue.Parent = ValFolder
	end

	local AnimFolder = AnimationFolder:FindFirstChild(tostring(i)) or Instance.new("Folder")
	AnimFolder.Name = tostring(i)
	AnimFolder.Parent = AnimationFolder

	local ThirdPerson = AnimFolder:FindFirstChild("ThirdPerson") or Instance.new("Folder")
	ThirdPerson.Name = "ThirdPerson"
	ThirdPerson.Parent = AnimFolder

	if Module2.EquippedAnimationID ~= nil and not ThirdPerson:FindFirstChild("EquippedAnim") then
		local EquippedAnim = Instance.new("Animation")
		EquippedAnim.Name = "EquippedAnim"
		EquippedAnim.AnimationId = "rbxassetid://"..Module2.EquippedAnimationID
		EquippedAnim.Parent = ThirdPerson
	end
	if Module2.EmptyEquippedAnimationID ~= nil and not ThirdPerson:FindFirstChild("EmptyEquippedAnim") then
		local EmptyEquippedAnim = Instance.new("Animation")
		EmptyEquippedAnim.Name = "EmptyEquippedAnim"
		EmptyEquippedAnim.AnimationId = "rbxassetid://"..Module2.EmptyEquippedAnimationID
		EmptyEquippedAnim.Parent = ThirdPerson
	end
	if Module2.IdleAnimationID ~= nil and not ThirdPerson:FindFirstChild("IdleAnim") then
		local IdleAnim = Instance.new("Animation")
		IdleAnim.Name = "IdleAnim"
		IdleAnim.AnimationId = "rbxassetid://"..Module2.IdleAnimationID
		IdleAnim.Parent = ThirdPerson
	end
	if Module2.EmptyIdleAnimationID ~= nil and not ThirdPerson:FindFirstChild("EmptyIdleAnim") then
		local EmptyIdleAnim = Instance.new("Animation")
		EmptyIdleAnim.Name = "EmptyIdleAnim"
		EmptyIdleAnim.AnimationId = "rbxassetid://"..Module2.EmptyIdleAnimationID
		EmptyIdleAnim.Parent = ThirdPerson
	end
	if #Module2.FireAnimations > 0 and not ThirdPerson:FindFirstChild("FireAnimations") then
		local FireAnimFolder = Instance.new("Folder")
		FireAnimFolder.Name = "FireAnimations"
		FireAnimFolder.Parent = ThirdPerson
		for ii, vv in ipairs(Module2.FireAnimations) do
			if vv.FireAnimationID ~= nil then
				local FireAnim = Instance.new("Animation")
				FireAnim.Name = "FireAnim_"..ii
				FireAnim.AnimationId = "rbxassetid://"..vv.FireAnimationID
				FireAnim.Parent = FireAnimFolder
			end			
		end
	end
	if #Module2.LastFireAnimations > 0 and not ThirdPerson:FindFirstChild("LastFireAnimations") then
		local LastFireAnimFolder = Instance.new("Folder")
		LastFireAnimFolder.Name = "LastFireAnimations"
		LastFireAnimFolder.Parent = ThirdPerson
		for ii, vv in ipairs(Module2.LastFireAnimations) do
			if vv.LastFireAnimationID ~= nil then
				local LastFireAnim = Instance.new("Animation")
				LastFireAnim.Name = "LastFireAnim_"..ii
				LastFireAnim.AnimationId = "rbxassetid://"..vv.LastFireAnimationID
				LastFireAnim.Parent = LastFireAnimFolder
			end			
		end
	end
	if Module2.ReloadAnimationID ~= nil and not ThirdPerson:FindFirstChild("ReloadAnim") then
		local ReloadAnim = Instance.new("Animation")
		ReloadAnim.Name = "ReloadAnim"
		ReloadAnim.AnimationId = "rbxassetid://"..Module2.ReloadAnimationID
		ReloadAnim.Parent = ThirdPerson
	end
	if Module2.ShotgunClipinAnimationID ~= nil and not ThirdPerson:FindFirstChild("ShotgunClipinAnim") then
		local ShotgunClipinAnim = Instance.new("Animation")
		ShotgunClipinAnim.Name = "ShotgunClipinAnim"
		ShotgunClipinAnim.AnimationId = "rbxassetid://"..Module2.ShotgunClipinAnimationID
		ShotgunClipinAnim.Parent = ThirdPerson
	end
	if #Module2.ShotgunPumpinAnimations > 0 and not ThirdPerson:FindFirstChild("ShotgunPumpinAnimations") then
		local ShotgunPumpinAnimFolder = Instance.new("Folder")
		ShotgunPumpinAnimFolder.Name = "ShotgunPumpinAnimations"
		ShotgunPumpinAnimFolder.Parent = ThirdPerson
		for ii, vv in ipairs(Module2.ShotgunPumpinAnimations) do
			if vv.ShotgunPumpinAnimationID ~= nil then
				local ShotgunPumpinAnim = Instance.new("Animation")
				ShotgunPumpinAnim.Name = "ShotgunPumpinAnim_"..ii
				ShotgunPumpinAnim.AnimationId = "rbxassetid://"..vv.ShotgunPumpinAnimationID
				ShotgunPumpinAnim.Parent = ShotgunPumpinAnimFolder
			end		
		end
	end
	if Module2.HoldDownAnimationID ~= nil and not ThirdPerson:FindFirstChild("HoldDownAnim") then
		local HoldDownAnim = Instance.new("Animation")
		HoldDownAnim.Name = "HoldDownAnim"
		HoldDownAnim.AnimationId = "rbxassetid://"..Module2.HoldDownAnimationID
		HoldDownAnim.Parent = ThirdPerson
	end
	if Module2.AimIdleAnimationID ~= nil and not ThirdPerson:FindFirstChild("AimIdleAnim") then
		local AimIdleAnim = Instance.new("Animation")
		AimIdleAnim.Name = "AimIdleAnim"
		AimIdleAnim.AnimationId = "rbxassetid://"..Module2.AimIdleAnimationID
		AimIdleAnim.Parent = ThirdPerson
	end
	if Module2.EmptyAimIdleAnimationID ~= nil and not ThirdPerson:FindFirstChild("EmptyAimIdleAnim") then
		local EmptyAimIdleAnim = Instance.new("Animation")
		EmptyAimIdleAnim.Name = "EmptyAimIdleAnim"
		EmptyAimIdleAnim.AnimationId = "rbxassetid://"..Module2.EmptyAimIdleAnimationID
		EmptyAimIdleAnim.Parent = ThirdPerson
	end
	if #Module2.AimFireAnimations > 0 and not ThirdPerson:FindFirstChild("AimFireAnimations") then
		local AimFireAnimFolder = Instance.new("Folder")
		AimFireAnimFolder.Name = "AimFireAnimations"
		AimFireAnimFolder.Parent = ThirdPerson
		for ii, vv in ipairs(Module2.AimFireAnimations) do
			if vv.AimFireAnimationID ~= nil then
				local AimFireAnim = Instance.new("Animation")
				AimFireAnim.Name = "AimFireAnim_"..ii
				AimFireAnim.AnimationId = "rbxassetid://"..vv.AimFireAnimationID
				AimFireAnim.Parent = AimFireAnimFolder
			end		
		end
	end
	if #Module2.AimLastFireAnimations > 0 and not ThirdPerson:FindFirstChild("AimLastFireAnimations") then
		local AimLastFireAnimFolder = Instance.new("Folder")
		AimLastFireAnimFolder.Name = "AimLastFireAnimations"
		AimLastFireAnimFolder.Parent = ThirdPerson
		for ii, vv in ipairs(Module2.AimLastFireAnimations) do
			if vv.AimLastFireAnimationID ~= nil then
				local AimLastFireAnim = Instance.new("Animation")
				AimLastFireAnim.Name = "AimLastFireAnim_"..ii
				AimLastFireAnim.AnimationId = "rbxassetid://"..vv.AimLastFireAnimationID
				AimLastFireAnim.Parent = AimLastFireAnimFolder
			end		
		end
	end
	if Module2.AimChargingAnimationID ~= nil and not ThirdPerson:FindFirstChild("AimChargingAnim") then
		local AimChargingAnim = Instance.new("Animation")
		AimChargingAnim.Name = "AimChargingAnim"
		AimChargingAnim.AnimationId = "rbxassetid://"..Module2.AimChargingAnimationID
		AimChargingAnim.Parent = ThirdPerson
	end
	if Module2.TacticalReloadAnimationEnabled and Module2.TacticalReloadAnimationID ~= nil and not ThirdPerson:FindFirstChild("TacticalReloadAnim") then
		local TacticalReloadAnim = Instance.new("Animation")
		TacticalReloadAnim.Name = "TacticalReloadAnim"
		TacticalReloadAnim.AnimationId = "rbxassetid://"..Module2.TacticalReloadAnimationID
		TacticalReloadAnim.Parent = ThirdPerson
	end
	if Module2.InspectAnimationEnabled and Module2.InspectAnimationID ~= nil and not ThirdPerson:FindFirstChild("InspectAnim") then
		local InspectAnim = Instance.new("Animation")
		InspectAnim.Name = "InspectAnim"
		InspectAnim.AnimationId = "rbxassetid://"..Module2.InspectAnimationID
		InspectAnim.Parent = ThirdPerson
	end
	if Module2.InspectAnimationEnabled and Module2.EmptyInspectAnimationID ~= nil and not ThirdPerson:FindFirstChild("EmptyInspectAnim") then
		local EmptyInspectAnim = Instance.new("Animation")
		EmptyInspectAnim.Name = "EmptyInspectAnim"
		EmptyInspectAnim.AnimationId = "rbxassetid://"..Module2.EmptyInspectAnimationID
		EmptyInspectAnim.Parent = ThirdPerson
	end
	if Module2.ShotgunReload and Module2.PreShotgunReload and Module2.PreShotgunReloadAnimationID ~= nil and not ThirdPerson:FindFirstChild("PreShotgunReloadAnim") then
		local PreShotgunReloadAnim = Instance.new("Animation")
		PreShotgunReloadAnim.Name = "PreShotgunReloadAnim"
		PreShotgunReloadAnim.AnimationId = "rbxassetid://"..Module2.PreShotgunReloadAnimationID
		PreShotgunReloadAnim.Parent = ThirdPerson
	end
	if Module2.MinigunRevUpAnimationID ~= nil and not ThirdPerson:FindFirstChild("MinigunRevUpAnim") then
		local MinigunRevUpAnim = Instance.new("Animation")
		MinigunRevUpAnim.Name = "MinigunRevUpAnim"
		MinigunRevUpAnim.AnimationId = "rbxassetid://"..Module2.MinigunRevUpAnimationID
		MinigunRevUpAnim.Parent = ThirdPerson
	end
	if Module2.MinigunRevDownAnimationID ~= nil and not ThirdPerson:FindFirstChild("MinigunRevDownAnim") then
		local MinigunRevDownAnim = Instance.new("Animation")
		MinigunRevDownAnim.Name = "MinigunRevDownAnim"
		MinigunRevDownAnim.AnimationId = "rbxassetid://"..Module2.MinigunRevDownAnimationID
		MinigunRevDownAnim.Parent = ThirdPerson
	end
	if Module2.ChargingAnimationEnabled and Module2.ChargingAnimationID ~= nil and not ThirdPerson:FindFirstChild("ChargingAnim") then
		local ChargingAnim = Instance.new("Animation")
		ChargingAnim.Name = "ChargingAnim"
		ChargingAnim.AnimationId = "rbxassetid://"..Module2.ChargingAnimationID
		ChargingAnim.Parent = ThirdPerson
	end
	if Module2.SelectiveFireEnabled and Module2.SwitchAnimationID ~= nil and not ThirdPerson:FindFirstChild("SwitchAnim") then
		local SwitchAnim = Instance.new("Animation")
		SwitchAnim.Name = "SwitchAnim"
		SwitchAnim.AnimationId = "rbxassetid://"..Module2.SwitchAnimationID
		SwitchAnim.Parent = ThirdPerson
	end
	if Module2.BatteryEnabled and Module2.OverheatAnimationID ~= nil and not ThirdPerson:FindFirstChild("OverheatAnim") then
		local OverheatAnim = Instance.new("Animation")
		OverheatAnim.Name = "OverheatAnim"
		OverheatAnim.AnimationId = "rbxassetid://"..Module2.OverheatAnimationID
		OverheatAnim.Parent = ThirdPerson
	end
	if Module2.MeleeAttackEnabled and Module2.MeleeAttackAnimationID ~= nil and not ThirdPerson:FindFirstChild("MeleeAttackAnim") then
		local MeleeAttackAnim = Instance.new("Animation")
		MeleeAttackAnim.Name = "MeleeAttackAnim"
		MeleeAttackAnim.AnimationId = "rbxassetid://"..Module2.MeleeAttackAnimationID
		MeleeAttackAnim.Parent = ThirdPerson
	end
	if Module.AltFire and Module2.AltAnimationID ~= nil and not ThirdPerson:FindFirstChild("AltAnim") then
		local AltAnim = Instance.new("Animation")
		AltAnim.Name = "AltAnim"
		AltAnim.AnimationId = "rbxassetid://"..Module2.AltAnimationID
		AltAnim.Parent = ThirdPerson
	end
	if Module2.LaserBeamStartupAnimationID ~= nil and not ThirdPerson:FindFirstChild("LaserBeamStartupAnim") then
		local LaserBeamStartupAnim = Instance.new("Animation")
		LaserBeamStartupAnim.Name = "LaserBeamStartupAnim"
		LaserBeamStartupAnim.AnimationId = "rbxassetid://"..Module2.LaserBeamStartupAnimationID
		LaserBeamStartupAnim.Parent = ThirdPerson
	end
	if Module2.LaserBeamLoopAnimationID ~= nil and not ThirdPerson:FindFirstChild("LaserBeamLoopAnim") then
		local LaserBeamLoopAnim = Instance.new("Animation")
		LaserBeamLoopAnim.Name = "LaserBeamLoopAnim"
		LaserBeamLoopAnim.AnimationId = "rbxassetid://"..Module2.LaserBeamLoopAnimationID
		LaserBeamLoopAnim.Parent = ThirdPerson
	end
	if Module2.LaserBeamStopAnimationID ~= nil and not ThirdPerson:FindFirstChild("LaserBeamStopAnim") then
		local LaserBeamStopAnim = Instance.new("Animation")
		LaserBeamStopAnim.Name = "LaserBeamStopAnim"
		LaserBeamStopAnim.AnimationId = "rbxassetid://"..Module2.LaserBeamStopAnimationID
		LaserBeamStopAnim.Parent = ThirdPerson
	end

	--First person
	local FirstPerson = AnimFolder:FindFirstChild("FirstPerson") or Instance.new("Folder")
	FirstPerson.Name = "FirstPerson"
	FirstPerson.Parent = AnimFolder

	if Module2.VMEquippedAnimationID ~= nil and not FirstPerson:FindFirstChild("VMEquippedAnim") then
		local VMEquippedAnim = Instance.new("Animation")
		VMEquippedAnim.Name = "VMEquippedAnim"
		VMEquippedAnim.AnimationId = "rbxassetid://"..Module2.VMEquippedAnimationID
		VMEquippedAnim.Parent = FirstPerson
	end
	if Module2.VMEmptyEquippedAnimationID ~= nil and not FirstPerson:FindFirstChild("VMEmptyEquippedAnim") then
		local VMEmptyEquippedAnim = Instance.new("Animation")
		VMEmptyEquippedAnim.Name = "VMEmptyEquippedAnim"
		VMEmptyEquippedAnim.AnimationId = "rbxassetid://"..Module2.VMEmptyEquippedAnimationID
		VMEmptyEquippedAnim.Parent = FirstPerson
	end
	if Module2.VMIdleAnimationID ~= nil and not FirstPerson:FindFirstChild("VMIdleAnim") then
		local VMIdleAnim = Instance.new("Animation")
		VMIdleAnim.Name = "VMIdleAnim"
		VMIdleAnim.AnimationId = "rbxassetid://"..Module2.VMIdleAnimationID
		VMIdleAnim.Parent = FirstPerson
	end
	if Module2.VMEmptyIdleAnimationID ~= nil and not FirstPerson:FindFirstChild("VMEmptyIdleAnim") then
		local VMEmptyIdleAnim = Instance.new("Animation")
		VMEmptyIdleAnim.Name = "VMEmptyIdleAnim"
		VMEmptyIdleAnim.AnimationId = "rbxassetid://"..Module2.VMEmptyIdleAnimationID
		VMEmptyIdleAnim.Parent = FirstPerson
	end
	if #Module2.VMFireAnimations > 0 and not FirstPerson:FindFirstChild("VMFireAnimations") then
		local VMFireAnimFolder = Instance.new("Folder")
		VMFireAnimFolder.Name = "VMFireAnimations"
		VMFireAnimFolder.Parent = FirstPerson
		for ii, vv in ipairs(Module2.VMFireAnimations) do
			if vv.VMFireAnimationID ~= nil then
				local VMFireAnim = Instance.new("Animation")
				VMFireAnim.Name = "VMFireAnim_"..ii
				VMFireAnim.AnimationId = "rbxassetid://"..vv.VMFireAnimationID
				VMFireAnim.Parent = VMFireAnimFolder
			end			
		end
	end
	if #Module2.VMLastFireAnimations > 0 and not FirstPerson:FindFirstChild("VMLastFireAnimations") then
		local VMLastFireAnimFolder = Instance.new("Folder")
		VMLastFireAnimFolder.Name = "VMLastFireAnimations"
		VMLastFireAnimFolder.Parent = FirstPerson
		for ii, vv in ipairs(Module2.VMLastFireAnimations) do
			if vv.VMLastFireAnimationID ~= nil then
				local VMLastFireAnim = Instance.new("Animation")
				VMLastFireAnim.Name = "VMLastFireAnim_"..ii
				VMLastFireAnim.AnimationId = "rbxassetid://"..vv.VMLastFireAnimationID
				VMLastFireAnim.Parent = VMLastFireAnimFolder
			end			
		end
	end
	if Module2.VMReloadAnimationID ~= nil and not FirstPerson:FindFirstChild("VMReloadAnim") then
		local VMReloadAnim = Instance.new("Animation")
		VMReloadAnim.Name = "VMReloadAnim"
		VMReloadAnim.AnimationId = "rbxassetid://"..Module2.VMReloadAnimationID
		VMReloadAnim.Parent = FirstPerson
	end
	if Module2.VMShotgunClipinAnimationID ~= nil and not FirstPerson:FindFirstChild("VMShotgunClipinAnim") then
		local VMShotgunClipinAnim = Instance.new("Animation")
		VMShotgunClipinAnim.Name = "VMShotgunClipinAnim"
		VMShotgunClipinAnim.AnimationId = "rbxassetid://"..Module2.VMShotgunClipinAnimationID
		VMShotgunClipinAnim.Parent = FirstPerson
	end
	if #Module2.VMShotgunPumpinAnimations > 0 and not FirstPerson:FindFirstChild("VMShotgunPumpinAnimations") then
		local VMShotgunPumpinAnimFolder = Instance.new("Folder")
		VMShotgunPumpinAnimFolder.Name = "VMShotgunPumpinAnimations"
		VMShotgunPumpinAnimFolder.Parent = FirstPerson
		for ii, vv in ipairs(Module2.VMShotgunPumpinAnimations) do
			if vv.VMShotgunPumpinAnimationID ~= nil then
				local VMShotgunPumpinAnim = Instance.new("Animation")
				VMShotgunPumpinAnim.Name = "VMShotgunPumpinAnim_"..ii
				VMShotgunPumpinAnim.AnimationId = "rbxassetid://"..vv.VMShotgunPumpinAnimationID
				VMShotgunPumpinAnim.Parent = VMShotgunPumpinAnimFolder
			end		
		end
	end
	if Module2.VMHoldDownAnimationID ~= nil and not FirstPerson:FindFirstChild("VMHoldDownAnim") then
		local VMHoldDownAnim = Instance.new("Animation")
		VMHoldDownAnim.Name = "VMHoldDownAnim"
		VMHoldDownAnim.AnimationId = "rbxassetid://"..Module2.VMHoldDownAnimationID
		VMHoldDownAnim.Parent = FirstPerson
	end
	if Module2.TacticalReloadAnimationEnabled and Module2.VMTacticalReloadAnimationID ~= nil and not FirstPerson:FindFirstChild("VMTacticalReloadAnim") then
		local VMTacticalReloadAnim = Instance.new("Animation")
		VMTacticalReloadAnim.Name = "VMTacticalReloadAnim"
		VMTacticalReloadAnim.AnimationId = "rbxassetid://"..Module2.VMTacticalReloadAnimationID
		VMTacticalReloadAnim.Parent = FirstPerson
	end
	if Module2.InspectAnimationEnabled and Module2.VMInspectAnimationID ~= nil and not FirstPerson:FindFirstChild("VMInspectAnim") then
		local VMInspectAnim = Instance.new("Animation")
		VMInspectAnim.Name = "VMInspectAnim"
		VMInspectAnim.AnimationId = "rbxassetid://"..Module2.VMInspectAnimationID
		VMInspectAnim.Parent = FirstPerson
	end
	if Module2.InspectAnimationEnabled and Module2.VMEmptyInspectAnimationID ~= nil and not FirstPerson:FindFirstChild("VMEmptyInspectAnim") then
		local VMEmptyInspectAnim = Instance.new("Animation")
		VMEmptyInspectAnim.Name = "VMEmptyInspectAnim"
		VMEmptyInspectAnim.AnimationId = "rbxassetid://"..Module2.VMEmptyInspectAnimationID
		VMEmptyInspectAnim.Parent = FirstPerson
	end
	if Module2.ShotgunReload and Module2.PreShotgunReload and Module2.VMPreShotgunReloadAnimationID ~= nil and not FirstPerson:FindFirstChild("VMPreShotgunReloadAnim") then
		local VMPreShotgunReloadAnim = Instance.new("Animation")
		VMPreShotgunReloadAnim.Name = "VMPreShotgunReloadAnim"
		VMPreShotgunReloadAnim.AnimationId = "rbxassetid://"..Module2.VMPreShotgunReloadAnimationID
		VMPreShotgunReloadAnim.Parent = FirstPerson	
	end
	if Module2.VMMinigunRevUpAnimationID ~= nil and not FirstPerson:FindFirstChild("VMMinigunRevUpAnim") then
		local VMMinigunRevUpAnim = Instance.new("Animation")
		VMMinigunRevUpAnim.Name = "VMMinigunRevUpAnim"
		VMMinigunRevUpAnim.AnimationId = "rbxassetid://"..Module2.VMMinigunRevUpAnimationID
		VMMinigunRevUpAnim.Parent = FirstPerson	
	end
	if Module2.VMMinigunRevDownAnimationID ~= nil and not FirstPerson:FindFirstChild("VMMinigunRevDownAnim") then
		local VMMinigunRevDownAnim = Instance.new("Animation")
		VMMinigunRevDownAnim.Name = "VMMinigunRevDownAnim"
		VMMinigunRevDownAnim.AnimationId = "rbxassetid://"..Module2.VMMinigunRevDownAnimationID
		VMMinigunRevDownAnim.Parent = FirstPerson	
	end
	if Module2.ChargingAnimationEnabled and Module2.VMChargingAnimationID ~= nil and not FirstPerson:FindFirstChild("VMChargingAnim") then
		local VMChargingAnim = Instance.new("Animation")
		VMChargingAnim.Name = "VMChargingAnim"
		VMChargingAnim.AnimationId = "rbxassetid://"..Module2.VMChargingAnimationID
		VMChargingAnim.Parent = FirstPerson	
	end
	if Module2.SelectiveFireEnabled and Module2.VMSwitchAnimationID ~= nil and not FirstPerson:FindFirstChild("VMSwitchAnim") then
		local VMSwitchAnim = Instance.new("Animation")
		VMSwitchAnim.Name = "VMSwitchAnim"
		VMSwitchAnim.AnimationId = "rbxassetid://"..Module2.VMSwitchAnimationID
		VMSwitchAnim.Parent = FirstPerson	
	end
	if Module2.BatteryEnabled and Module2.VMOverheatAnimationID ~= nil and not FirstPerson:FindFirstChild("VMOverheatAnim") then
		local VMOverheatAnim = Instance.new("Animation")
		VMOverheatAnim.Name = "VMOverheatAnim"
		VMOverheatAnim.AnimationId = "rbxassetid://"..Module2.VMOverheatAnimationID
		VMOverheatAnim.Parent = FirstPerson
	end
	if Module2.MeleeAttackEnabled and Module2.VMMeleeAttackAnimationID ~= nil and not FirstPerson:FindFirstChild("VMMeleeAttackAnim") then
		local VMMeleeAttackAnim = Instance.new("Animation")
		VMMeleeAttackAnim.Name = "VMMeleeAttackAnim"
		VMMeleeAttackAnim.AnimationId = "rbxassetid://"..Module2.VMMeleeAttackAnimationID
		VMMeleeAttackAnim.Parent = FirstPerson
	end
	if Module.AltFire and Module2.VMAltAnimationID ~= nil and not FirstPerson:FindFirstChild("VMAltAnim") then
		local VMAltAnim = Instance.new("Animation")
		VMAltAnim.Name = "VMAltAnim"
		VMAltAnim.AnimationId = "rbxassetid://"..Module2.VMAltAnimationID
		VMAltAnim.Parent = FirstPerson
	end
	if Module2.VMLaserBeamStartupAnimationID ~= nil and not FirstPerson:FindFirstChild("VMLaserBeamStartupAnim") then
		local VMLaserBeamStartupAnim = Instance.new("Animation")
		VMLaserBeamStartupAnim.Name = "VMLaserBeamStartupAnim"
		VMLaserBeamStartupAnim.AnimationId = "rbxassetid://"..Module2.VMLaserBeamStartupAnimationID
		VMLaserBeamStartupAnim.Parent = FirstPerson
	end
	if Module2.VMLaserBeamLoopAnimationID ~= nil and not FirstPerson:FindFirstChild("VMLaserBeamLoopAnim") then
		local VMLaserBeamLoopAnim = Instance.new("Animation")
		VMLaserBeamLoopAnim.Name = "VMLaserBeamLoopAnim"
		VMLaserBeamLoopAnim.AnimationId = "rbxassetid://"..Module2.VMLaserBeamLoopAnimationID
		VMLaserBeamLoopAnim.Parent = FirstPerson
	end
	if Module2.VMLaserBeamStopAnimationID ~= nil and not FirstPerson:FindFirstChild("VMLaserBeamStopAnim") then
		local VMLaserBeamStopAnim = Instance.new("Animation")
		VMLaserBeamStopAnim.Name = "VMLaserBeamStopAnim"
		VMLaserBeamStopAnim.AnimationId = "rbxassetid://"..Module2.VMLaserBeamStopAnimationID
		VMLaserBeamStopAnim.Parent = FirstPerson
	end
end

local function GetInstanceFromAncestor(Table)
	if Table[1] == "Tool" then
		return Tool:FindFirstChild(Table[2], true)
	end
	if Table[1] ~= "Character" then
		return
	end
	return Character:FindFirstChild(Table[2], true)
end

function SetCustomGrip(Enabled)
	if Enabled then
		GripId += 1
		local LastGripId = GripId
		for i, v in pairs(Module.CustomGrips) do
			if LastGripId ~= GripId then
				break
			end
			local Part0 = GetInstanceFromAncestor(v.CustomGripPart0)
			local Part1 = GetInstanceFromAncestor(v.CustomGripPart1)
			if not Part0 or not Part1 then
				continue
			end
			local Motor6DInstance = Instance.new("Motor6D")
			Motor6DInstance.Name = v.CustomGripName
			Motor6DInstance.Part0 = Part0
			Motor6DInstance.Part1 = Part1
			Motor6DInstance:SetAttribute("ServerInitialized", "")
			if Part1.Name == "Handle" and Part1.Parent == Tool then
				if not DefaultC0 or not DefaultC1 then
					repeat task.wait() if LastGripId ~= GripId then break end until RightArm:FindFirstChild("RightGrip")
					if LastGripId == GripId then
						local RightGrip = RightArm:FindFirstChild("RightGrip")
						if RightGrip then
							DefaultC0 = RightGrip.C0
							DefaultC1 = RightGrip.C1
							RightGrip.Enabled = false
							RightGrip:Destroy()
						end
					end
				end
				if DefaultC0 and DefaultC1 then
					if v.AlignC0AndC1FromDefaultGrip then
						Motor6DInstance.C0 = DefaultC0
						Motor6DInstance.C1 = DefaultC1
					end
					if v.CustomGripCFrame then
						Motor6DInstance.C0 *= v.CustomGripC0
						Motor6DInstance.C1 *= v.CustomGripC1
					end
					Motor6DInstance.Parent = Part0
					table.insert(Motor6DInstances, Motor6DInstance)
				end
			else
				if v.AlignC0AndC1FromDefaultGrip and DefaultC0 and DefaultC1 then
					Motor6DInstance.C0 = DefaultC0
					Motor6DInstance.C1 = DefaultC1
				end
				if v.CustomGripCFrame then
					Motor6DInstance.C0 *= v.CustomGripC0
					Motor6DInstance.C1 *= v.CustomGripC1
				end
				Motor6DInstance.Parent = Part0
				table.insert(Motor6DInstances, Motor6DInstance)
			end
		end
	else
		GripId += 1
		for _, v in pairs(Motor6DInstances) do
			if v then
				v:Destroy()
			end
		end
		table.clear(Motor6DInstances)
		DefaultC0 = nil
		DefaultC1 = nil
	end
end

function OnUnequipping(Remove)
	if Module.WalkSpeedModifierEnabled then
		Humanoid.WalkSpeed = OriginalWalkSpeed
	end
	if Module.CustomGripEnabled and not Tool.RequiresHandle then
		task.spawn(function()
			SetCustomGrip(false)
		end)	
	end
	if Module.DualWeldEnabled and not Module.CustomGripEnabled and Tool.RequiresHandle then
		Handle2.CanCollide = true
		if Grip2 then
			Grip2:Destroy()
		end
	end
end

ChangeMagAndAmmo.OnServerEvent:Connect(function(Player, Id, Mag, Ammo)
	ValueFolder[Id].Mag.Value = Mag
	if Module.UniversalAmmoEnabled then
		ValueFolder.Ammo.Value = Ammo
	else
		ValueFolder[Id].Ammo.Value = Ammo
	end
end)

Tool.Equipped:Connect(function()
	Player = Players:GetPlayerFromCharacter(Tool.Parent)
	Character = Tool.Parent
	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	LeftArm = Character:FindFirstChild("Left Arm") or Character:FindFirstChild("LeftHand")
	RightArm = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightHand")
	OriginalWalkSpeed = Humanoid.WalkSpeed
	if Module.WalkSpeedModifierEnabled then
		Humanoid.WalkSpeed = Module.WalkSpeed
	end
	if Module.CustomGripEnabled and not Tool.RequiresHandle then
		task.spawn(function()
			SetCustomGrip(true)
		end)	
	end
	if Module.DualWeldEnabled and not Module.CustomGripEnabled and Tool.RequiresHandle then
		Handle2.CanCollide = false
		if RightArm then
			local Grip = RightArm:WaitForChild("RightGrip", 0.01)
			if Grip then
				Grip2 = Grip:Clone()
				Grip2.Name = "LeftGrip"
				Grip2.Part0 = LeftArm
				Grip2.Part1 = Handle2
				--Grip2.C1 = Grip2.C1:inverse()
				Grip2:SetAttribute("ServerInitialized", "")
				Grip2.Parent = LeftArm
			end
		end
	end
end)

Tool.Unequipped:Connect(function()
	OnUnequipping()
end)

Tool.AncestryChanged:Connect(function()
	if not Tool:IsDescendantOf(game) then
		OnUnequipping(true)
	end
end)