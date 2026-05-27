-- ============================================================
-- Ce script gère la logique serveur d'une arme/outil. Il
-- initialise les dossiers de données, configure dynamiquement
-- les animations et les grips personnalisés (Motor6D), et
-- synchronise les munitions/doses via des événements distants.
-- ============================================================

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Tool = script.Parent
local Player, Character, Humanoid, LeftArm, RightArm, OriginalWalkSpeed
local Motor6DInstances = {}
local GripId = 0
local DefaultC0, DefaultC1

local Setting = Tool:WaitForChild("Setting")
local Module = require(Setting)
local SyringeAnim = script:WaitForChild("SyringeAnim")

local AnimationFolder = Instance.new("Folder")
AnimationFolder.Name = "AnimationFolder"
AnimationFolder.Parent = Tool

local ValueFolder = Instance.new("Folder")
ValueFolder.Name = "ValueFolder"
ValueFolder.Parent = Tool

local Settings = {}
for _, v in pairs(Setting:GetChildren()) do
	if v.Name ~= "CanShootConditions" and v.Name ~= "ConditionableGunMods" and v.Name ~= "OnClientShootEvents" then
		table.insert(Settings, v)
	end
end
table.sort(Settings, function(a, b) return tonumber(a.Name) < tonumber(b.Name) end)

if Module.UniversalAmmoEnabled then
	local AmmoValue = Instance.new("NumberValue")
	AmmoValue.Name = "Ammo"
	AmmoValue.Value = Module.Ammo
	AmmoValue.Parent = ValueFolder
end

local function LoadAnim(folder, animName, animId)
	if animId then
		local anim = Instance.new("Animation")
		anim.Name = animName
		anim.AnimationId = "rbxassetid://" .. tostring(animId)
		anim.Parent = folder
	end
end

local function LoadAnimList(folder, folderName, animList, namePrefix, idKey)
	if animList and #animList > 0 then
		local subFolder = Instance.new("Folder")
		subFolder.Name = folderName
		subFolder.Parent = folder
		for i, v in ipairs(animList) do
			LoadAnim(subFolder, namePrefix .. "_" .. i, v[idKey])
		end
	end
end

for i, v in ipairs(Settings) do
	local Module2 = require(v)

	local ValFolder = Instance.new("Folder")
	ValFolder.Name = tostring(i)
	ValFolder.Parent = ValueFolder

	local MagValue = Instance.new("NumberValue")
	MagValue.Name = "Mag" 
	MagValue.Value = Module2.AmmoPerMag
	MagValue.Parent = ValFolder

	local AmmoValue = Instance.new("NumberValue")
	AmmoValue.Name = "Ammo"
	AmmoValue.Value = (not Module.UniversalAmmoEnabled and Module2.LimitedAmmoEnabled) and Module2.Ammo or 0
	AmmoValue.Parent = ValFolder

	local AnimFolder = Instance.new("Folder")
	AnimFolder.Name = tostring(i)
	AnimFolder.Parent = AnimationFolder

	-- Animations Third Person
	local TP = Instance.new("Folder")
	TP.Name = "ThirdPerson"
	TP.Parent = AnimFolder

	local tpAnims = {
		EquippedAnim = Module2.EquippedAnimationID, EmptyEquippedAnim = Module2.EmptyEquippedAnimationID,
		IdleAnim = Module2.IdleAnimationID, EmptyIdleAnim = Module2.EmptyIdleAnimationID,
		ReloadAnim = Module2.ReloadAnimationID, HoldDownAnim = Module2.HoldDownAnimationID, 
		AimIdleAnim = Module2.AimIdleAnimationID, EmptyAimIdleAnim = Module2.EmptyAimIdleAnimationID, 
		AimChargingAnim = Module2.AimChargingAnimationID, InspectAnim = Module2.InspectAnimationID,
		EmptyInspectAnim = Module2.EmptyInspectAnimationID, ChargingAnim = Module2.ChargingAnimationID, 
		MeleeAttackAnim = Module2.MeleeAttackAnimationID, AltAnim = Module2.AltAnimationID
	}
	for name, id in pairs(tpAnims) do LoadAnim(TP, name, id) end

	LoadAnimList(TP, "FireAnimations", Module2.FireAnimations, "FireAnim", "FireAnimationID")
	LoadAnimList(TP, "LastFireAnimations", Module2.LastFireAnimations, "LastFireAnim", "LastFireAnimationID")

	-- Animations First Person
	local FP = Instance.new("Folder")
	FP.Name = "FirstPerson"
	FP.Parent = AnimFolder

	local fpAnims = {
		VMEquippedAnim = Module2.VMEquippedAnimationID, VMEmptyEquippedAnim = Module2.VMEmptyEquippedAnimationID,
		VMIdleAnim = Module2.VMIdleAnimationID, VMEmptyIdleAnim = Module2.VMEmptyIdleAnimationID,
		VMReloadAnim = Module2.VMReloadAnimationID, VMHoldDownAnim = Module2.VMHoldDownAnimationID, 
		VMInspectAnim = Module2.VMInspectAnimationID, VMEmptyInspectAnim = Module2.VMEmptyInspectAnimationID,
		VMChargingAnim = Module2.VMChargingAnimationID, VMMeleeAttackAnim = Module2.VMMeleeAttackAnimationID, 
		VMAltAnim = Module2.VMAltAnimationID
	}
	for name, id in pairs(fpAnims) do LoadAnim(FP, name, id) end

	LoadAnimList(FP, "VMFireAnimations", Module2.VMFireAnimations, "VMFireAnim", "VMFireAnimationID")
	LoadAnimList(FP, "VMLastFireAnimations", Module2.VMLastFireAnimations, "VMLastFireAnim", "VMLastFireAnimationID")
end

local function GetInstanceFromAncestor(Table)
	if Table[1] == "Tool" then return Tool:FindFirstChild(Table[2], true) end
	if Table[1] ~= "Character" then return end
	return Character:FindFirstChild(Table[2], true)
end

function SetCustomGrip(Enabled)
	if Enabled then
		GripId += 1
		local LastGripId = GripId
		for i, v in pairs(Module.CustomGrips) do
			if LastGripId ~= GripId then break end

			local Part0 = GetInstanceFromAncestor(v.CustomGripPart0)
			local Part1 = GetInstanceFromAncestor(v.CustomGripPart1)
			if not Part0 or not Part1 then continue end

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
			if v then v:Destroy() end
		end
		table.clear(Motor6DInstances)
		DefaultC0 = nil
		DefaultC1 = nil
	end
end

function OnUnequipping(Remove)
	if Module.WalkSpeedModifierEnabled and Humanoid then
		Humanoid.WalkSpeed = OriginalWalkSpeed
	end
	if Module.CustomGripEnabled and not Tool.RequiresHandle then
		task.spawn(function() SetCustomGrip(false) end)	
	end
end

-- MISE A JOUR DU NOM DU REMOTE EVENT ICI
SyringeAnim.OnServerEvent:Connect(function(Player, Id, CurrentDoses, Reserves)
	if ValueFolder:FindFirstChild(Id) then
		ValueFolder[Id].Mag.Value = CurrentDoses
		if Module.UniversalAmmoEnabled then
			ValueFolder.Ammo.Value = Reserves
		else
			ValueFolder[Id].Ammo.Value = Reserves
		end
	end
end)

Tool.Equipped:Connect(function()
	Player = Players:GetPlayerFromCharacter(Tool.Parent)
	Character = Tool.Parent
	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	LeftArm = Character:FindFirstChild("Left Arm") or Character:FindFirstChild("LeftHand")
	RightArm = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightHand")

	if Humanoid then
		OriginalWalkSpeed = Humanoid.WalkSpeed
		if Module.WalkSpeedModifierEnabled then
			Humanoid.WalkSpeed = Module.WalkSpeed
		end
	end

	if Module.CustomGripEnabled and not Tool.RequiresHandle then
		task.spawn(function() SetCustomGrip(true) end)	
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