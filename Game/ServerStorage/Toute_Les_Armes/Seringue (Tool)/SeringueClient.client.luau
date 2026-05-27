-- ============================================================
-- Ce script gère l'équipement, l'animation et le comportement
-- local d'une seringue de soin. Il inclut des effets visuels
-- (flash, flou), la gestion du viewmodel, le déclenchement
-- automatique de la guérison et le basculement vers l'arme
-- précédente après usage.
-- ============================================================

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Events = ReplicatedStorage:WaitForChild("Events")
local viewmodelEvent = Events.viewmodelEvent
local viewmodelFunction = Events.viewmodelFunction

local Tool = script.Parent
local AnimationFolder = Tool:WaitForChild("AnimationFolder")
local ValueFolder = Tool:WaitForChild("ValueFolder")

local Camera = Workspace.CurrentCamera
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

-- ==========================================
-- MÉMOIRE DU DERNIER TOOL ÉQUIPÉ
-- ==========================================
local PreviousTool = nil
Character.ChildRemoved:Connect(function(child)
	if child:IsA("Tool") and child ~= Tool then
		PreviousTool = child
	end
end)

-- ==========================================
-- PRÉCHARGEMENT DES ANIMATIONS
-- ==========================================
task.spawn(function()
	local assetsToLoad = {}
	for _, v in ipairs(AnimationFolder:GetDescendants()) do
		if v:IsA("Animation") then table.insert(assetsToLoad, v) end
	end
	if #assetsToLoad > 0 then ContentProvider:PreloadAsync(assetsToLoad) end
end)

local CommonVariables = {
	Equipped = false, ActuallyEquipped = false, Enabled = true,
	Inspecting = false, IsEquipping = false, NextAllowedHoldTime = 0, 
	SettingModules = {}, Animations = {}, VMAnimations = {}, EquipID = 0
}

local Variables = {}
local Setting = Tool:WaitForChild("Setting")
local Module = require(Setting)

local Settings = {}
for _, v in pairs(Setting:GetChildren()) do
	if v.Name ~= "CanShootConditions" and v.Name ~= "ConditionableGunMods" and v.Name ~= "OnClientShootEvents" then
		table.insert(Settings, v)
	end
end
table.sort(Settings, function(a, b) return tonumber(a.Name) < tonumber(b.Name) end)

for i, v in ipairs(Settings) do
	table.insert(CommonVariables.SettingModules, require(v))
	table.insert(Variables, { Mag = ValueFolder:FindFirstChild(tostring(i)) and ValueFolder[tostring(i)].Mag.Value or 1 })
end

for i, v in ipairs(AnimationFolder:GetChildren()) do
	local AnimTable = {}
	local ThirdPerson = v:WaitForChild("ThirdPerson")
	local mod = CommonVariables.SettingModules[i]

	if mod.EquippedAnimationID then AnimTable.EquippedAnim = Humanoid:LoadAnimation(ThirdPerson:WaitForChild("EquippedAnim")) end
	if mod.EmptyEquippedAnimationID then AnimTable.EmptyEquippedAnim = Humanoid:LoadAnimation(ThirdPerson:WaitForChild("EmptyEquippedAnim")) end
	if mod.IdleAnimationID then AnimTable.IdleAnim = Humanoid:LoadAnimation(ThirdPerson:WaitForChild("IdleAnim")) end
	if mod.EmptyIdleAnimationID then AnimTable.EmptyIdleAnim = Humanoid:LoadAnimation(ThirdPerson:WaitForChild("EmptyIdleAnim")) end
	if mod.InspectAnimationEnabled and mod.InspectAnimationID then AnimTable.InspectAnim = Humanoid:LoadAnimation(ThirdPerson:WaitForChild("InspectAnim")) end
	if mod.InspectAnimationEnabled and mod.EmptyInspectAnimationID then AnimTable.EmptyInspectAnim = Humanoid:LoadAnimation(ThirdPerson:WaitForChild("EmptyInspectAnim")) end

	table.insert(CommonVariables.Animations, AnimTable)
end

local CurrentFireMode = 1
local CurrentModule = CommonVariables.SettingModules[CurrentFireMode]
local CurrentVariables = Variables[CurrentFireMode]
local CurrentAnimTable = CommonVariables.Animations[CurrentFireMode]

local Viewmodel
local CurrentVMAnimTable = {}

-- ==========================================
-- GESTION DE L'OFFSET DU VIEWMODEL
-- ==========================================
local CurrentViewmodelOffset = Vector3.new(0.25, -0.25, 0)
local TargetViewmodelOffset = Vector3.new(0.25, -0.25, 0)
local OffsetLerpSpeed = 16
local cachedConfigTable = nil
local lastViewmodel = nil

function UpdateViewmodelOffsetFromState(dt)
	if not Viewmodel or not Viewmodel.PrimaryPart then return end

	if lastViewmodel ~= Viewmodel then
		lastViewmodel = Viewmodel
		local vmConfigModule = Viewmodel:FindFirstChild("Configs")
		cachedConfigTable = vmConfigModule and require(vmConfigModule) or nil
	end

	if not cachedConfigTable then return end

	local wallrunning = Character:GetAttribute("IsWallrunning") or false
	local wallDirection = Character:GetAttribute("WallrunDirection") or 0

	if wallrunning and wallDirection > 0 then
		TargetViewmodelOffset = Vector3.new(-1.5, -0.25, 0)
	else
		TargetViewmodelOffset = Vector3.new(0.78, -0.25, 0)
	end

	CurrentViewmodelOffset = CurrentViewmodelOffset:Lerp(TargetViewmodelOffset, dt * OffsetLerpSpeed)
	cachedConfigTable.Offset = CFrame.new(CurrentViewmodelOffset)
end

-- ==========================================
-- EFFETS VISUELS ET SONORES (FLASH/BLUR)
-- ==========================================
local function TriggerEquipFlashAndBlur(currentEquipID)
	task.delay(1.25, function() 
		if CommonVariables.EquipID ~= currentEquipID or not CommonVariables.ActuallyEquipped then return end

		local flashGui = Instance.new("ScreenGui")
		flashGui.Name = "EquipFlashGui"
		flashGui.IgnoreGuiInset = true 
		flashGui.Parent = Player:WaitForChild("PlayerGui")

		local flashFrame = Instance.new("Frame")
		flashFrame.Size = UDim2.new(1, 0, 1, 0)
		flashFrame.BackgroundColor3 = Color3.fromRGB(134, 255, 138) 
		flashFrame.BackgroundTransparency = 1
		flashFrame.BorderSizePixel = 0
		flashFrame.Parent = flashGui

		local blur = Instance.new("BlurEffect")
		blur.Name = "EquipBlur"
		blur.Size = 0 
		blur.Parent = Lighting

		local audioEffect = Instance.new("EqualizerSoundEffect")
		audioEffect.Name = "EquipMuffle"
		audioEffect.LowGain = 0    
		audioEffect.MidGain = 0  
		audioEffect.HighGain = 0 

		local soundGroup = SoundService:FindFirstChild("MuffleGroup")
		if not soundGroup then
			soundGroup = Instance.new("SoundGroup")
			soundGroup.Name = "MuffleGroup"
			soundGroup.Parent = SoundService
			for _, s in ipairs(SoundService:GetDescendants()) do
				if s:IsA("Sound") then s.SoundGroup = soundGroup end
			end
		end
		audioEffect.Parent = soundGroup

		local fadeInTime = 0.35    
		local fadeOutTime = 1.25  
		local peakOpacity = 0.75  
		local peakBlur = 18        

		local tweenInfoIn = TweenInfo.new(fadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local flashIn = TweenService:Create(flashFrame, tweenInfoIn, {BackgroundTransparency = peakOpacity})
		local blurIn = TweenService:Create(blur, tweenInfoIn, {Size = peakBlur})
		local audioIn = TweenService:Create(audioEffect, tweenInfoIn, {LowGain = 8, MidGain = -60, HighGain = -60})

		local tweenInfoOut = TweenInfo.new(fadeOutTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local flashOut = TweenService:Create(flashFrame, tweenInfoOut, {BackgroundTransparency = 1})
		local blurOut = TweenService:Create(blur, tweenInfoOut, {Size = 0})
		local audioOut = TweenService:Create(audioEffect, tweenInfoOut, {LowGain = 0, MidGain = 0, HighGain = 0})

		flashIn:Play()
		blurIn:Play()
		audioIn:Play()

		task.delay(fadeInTime, function()
			if flashFrame.Parent then flashOut:Play() end
			if blur.Parent then blurOut:Play() end
			if audioEffect.Parent then audioOut:Play() end
		end)

		local totalDuration = fadeInTime + fadeOutTime
		Debris:AddItem(flashGui, totalDuration + 0.2)
		Debris:AddItem(blur, totalDuration + 0.2)
		Debris:AddItem(audioEffect, totalDuration + 0.2)
	end)
end

function SetAnimationTrack(AnimationName, Action, Speed, FadeTime)
	FadeTime = FadeTime or 0.3 
	local AnimationTrack = CurrentAnimTable[AnimationName]

	if AnimationName:match("VM") then
		AnimationTrack = CurrentVMAnimTable[AnimationName]
		if AnimationName == "VMInspectAnim" then
			AnimationTrack = (CurrentVariables.Mag <= 0) and CurrentVMAnimTable.VMEmptyInspectAnim or CurrentVMAnimTable.VMInspectAnim
		end
	else
		if AnimationName == "InspectAnim" then
			AnimationTrack = (CurrentVariables.Mag <= 0) and CurrentAnimTable.EmptyInspectAnim or CurrentAnimTable.InspectAnim
		end
	end

	if AnimationTrack then
		if Action == "Play" then
			AnimationTrack:Play(FadeTime, nil, Speed)
		else
			AnimationTrack:Stop(FadeTime)
		end
	end
end

-- ==========================================
-- LOGIQUE D'ANIMATION DE LA SERINGUE
-- ==========================================
function OnInspecting(isFirstTime)
	if not isFirstTime then return end

	if CommonVariables.ActuallyEquipped and CommonVariables.Enabled and not CommonVariables.Inspecting and CurrentModule.InspectAnimationEnabled then
		if CurrentAnimTable.IdleAnim and CurrentAnimTable.IdleAnim.IsPlaying then CurrentAnimTable.IdleAnim:Stop(0) end
		if CurrentAnimTable.EmptyIdleAnim and CurrentAnimTable.EmptyIdleAnim.IsPlaying then CurrentAnimTable.EmptyIdleAnim:Stop(0) end
		if CurrentVMAnimTable.VMIdleAnim and CurrentVMAnimTable.VMIdleAnim.IsPlaying then CurrentVMAnimTable.VMIdleAnim:Stop(0) end
		if CurrentVMAnimTable.VMEmptyIdleAnim and CurrentVMAnimTable.VMEmptyIdleAnim.IsPlaying then CurrentVMAnimTable.VMEmptyIdleAnim:Stop(0) end

		CommonVariables.Inspecting = true
		Character:SetAttribute("IsInspecting", true)

		local InspectAnim, VMInspectAnim = nil, nil
		local InspectSpeed, VMInspectSpeed = 1, 1

		if CurrentVariables.Mag <= 0 then
			if CurrentAnimTable.EmptyInspectAnim then
				InspectAnim = CurrentAnimTable.EmptyInspectAnim
				InspectSpeed = CurrentModule.EmptyInspectAnimationSpeed or 1
			elseif CurrentAnimTable.InspectAnim then
				InspectAnim = CurrentAnimTable.InspectAnim
				InspectSpeed = CurrentModule.InspectAnimationSpeed or 1
			end

			if CurrentVMAnimTable.VMEmptyInspectAnim then
				VMInspectAnim = CurrentVMAnimTable.VMEmptyInspectAnim
				VMInspectSpeed = CurrentModule.VMEmptyInspectAnimationSpeed or 1
			elseif CurrentVMAnimTable.VMInspectAnim then
				VMInspectAnim = CurrentVMAnimTable.VMInspectAnim
				VMInspectSpeed = CurrentModule.VMInspectAnimationSpeed or 1
			end
		else
			if CurrentAnimTable.InspectAnim then
				InspectAnim = CurrentAnimTable.InspectAnim
				InspectSpeed = CurrentModule.InspectAnimationSpeed or 1
			end
			if CurrentVMAnimTable.VMInspectAnim then
				VMInspectAnim = CurrentVMAnimTable.VMInspectAnim
				VMInspectSpeed = CurrentModule.VMInspectAnimationSpeed or 1
			end
		end

		local fadeTime = isFirstTime and 0 or 0.1
		if InspectAnim then InspectAnim:Play(fadeTime, nil, InspectSpeed) end
		if VMInspectAnim then VMInspectAnim:Play(fadeTime, nil, VMInspectSpeed) end

		local TempsDAttente = 2.2
		local Debut = os.clock()

		repeat
			task.wait()
			if not CommonVariables.ActuallyEquipped or not CommonVariables.Enabled then break end
		until (os.clock() - Debut) >= TempsDAttente

		CommonVariables.Inspecting = false
		Character:SetAttribute("IsInspecting", false)

		if InspectAnim and InspectAnim.IsPlaying then InspectAnim:Stop(0.1) end
		if VMInspectAnim and VMInspectAnim.IsPlaying then VMInspectAnim:Stop(0.1) end

		if CommonVariables.ActuallyEquipped and CommonVariables.Enabled then
			if CurrentVariables.Mag <= 0 then
				if CurrentAnimTable.EmptyIdleAnim then CurrentAnimTable.EmptyIdleAnim:Play(0.1, nil, CurrentModule.EmptyIdleAnimationSpeed or 1)
				elseif CurrentAnimTable.IdleAnim then CurrentAnimTable.IdleAnim:Play(0.1, nil, CurrentModule.IdleAnimationSpeed or 1) end

				if CurrentVMAnimTable.VMEmptyIdleAnim then CurrentVMAnimTable.VMEmptyIdleAnim:Play(0.1, nil, CurrentModule.VMEmptyIdleAnimationSpeed or 1)
				elseif CurrentVMAnimTable.VMIdleAnim then CurrentVMAnimTable.VMIdleAnim:Play(0.1, nil, CurrentModule.VMIdleAnimationSpeed or 1) end
			else
				if CurrentAnimTable.IdleAnim then CurrentAnimTable.IdleAnim:Play(0.1, nil, CurrentModule.IdleAnimationSpeed or 1) end
				if CurrentVMAnimTable.VMIdleAnim then CurrentVMAnimTable.VMIdleAnim:Play(0.1, nil, CurrentModule.VMIdleAnimationSpeed or 1) end
			end
		end
	end
end

function InitializeViewmodel()
	Viewmodel = viewmodelFunction:Invoke("SetUpViewmodel", Tool.Name)

	if #CommonVariables.VMAnimations <= 0 then
		local VMHumanoid = Viewmodel:WaitForChild("Humanoid")
		for i, v in ipairs(AnimationFolder:GetChildren()) do
			local VMAnimTable = {}
			local FirstPerson = v:WaitForChild("FirstPerson")
			local mod = CommonVariables.SettingModules[i]

			if mod.VMEquippedAnimationID then VMAnimTable.VMEquippedAnim = VMHumanoid:LoadAnimation(FirstPerson:WaitForChild("VMEquippedAnim")) end
			if mod.VMEmptyEquippedAnimationID then VMAnimTable.VMEmptyEquippedAnim = VMHumanoid:LoadAnimation(FirstPerson:WaitForChild("VMEmptyEquippedAnim")) end
			if mod.VMIdleAnimationID then VMAnimTable.VMIdleAnim = VMHumanoid:LoadAnimation(FirstPerson:WaitForChild("VMIdleAnim")) end   
			if mod.VMEmptyIdleAnimationID then VMAnimTable.VMEmptyIdleAnim = VMHumanoid:LoadAnimation(FirstPerson:WaitForChild("VMEmptyIdleAnim")) end
			if mod.InspectAnimationEnabled and mod.VMInspectAnimationID then VMAnimTable.VMInspectAnim = VMHumanoid:LoadAnimation(FirstPerson:WaitForChild("VMInspectAnim")) end
			if mod.InspectAnimationEnabled and mod.VMEmptyInspectAnimationID then VMAnimTable.VMEmptyInspectAnim = VMHumanoid:LoadAnimation(FirstPerson:WaitForChild("VMEmptyInspectAnim")) end

			table.insert(CommonVariables.VMAnimations, VMAnimTable)
		end
		CurrentVMAnimTable = CommonVariables.VMAnimations[CurrentFireMode]
	end
end

local OnUnequipping
local isFirstEquip = true

Tool.Equipped:Connect(function()
	Character:SetAttribute("BlockSlide", true)
	CommonVariables.NextAllowedHoldTime = os.clock() + 0.65
	CommonVariables.IsEquipping = true
	CommonVariables.Equipped = true
	CommonVariables.EquipID = CommonVariables.EquipID + 1 
	Player.CameraMode = Enum.CameraMode.LockFirstPerson

	InitializeViewmodel()
	CommonVariables.ActuallyEquipped = true

	RunService:BindToRenderStep("SyringeRender_"..Tool.Name, Enum.RenderPriority.Camera.Value, function(dt)
		if CommonVariables.ActuallyEquipped then UpdateViewmodelOffsetFromState(dt) end
	end)

	TriggerEquipFlashAndBlur(CommonVariables.EquipID)

	task.spawn(function()
		local currentEquip = CommonVariables.EquipID
		task.wait(1.2)
		if CommonVariables.EquipID == currentEquip and CommonVariables.Equipped then
			local healEvent = ReplicatedStorage:FindFirstChild("SyringeHealEvent")
			if healEvent then healEvent:FireServer() end
		end
	end)

	if isFirstEquip then
		isFirstEquip = false

		if Viewmodel then
			for _, v in pairs(Viewmodel:GetDescendants()) do
				if v:IsA("BasePart") or v:IsA("MeshPart") or v:IsA("Decal") then v.LocalTransparencyModifier = 1 end
			end
		end
		viewmodelEvent:Fire("SetViewmodelTransparent", true)

		task.spawn(function()
			OnInspecting(true)

			if Tool and Tool.Parent == Character then
				local backpack = Player:FindFirstChild("Backpack")
				local toolToEquip = PreviousTool 

				OnUnequipping()
				if Humanoid then Humanoid:UnequipTools() end

				local hasEquipped = false
				if toolToEquip and toolToEquip.Parent == backpack and Humanoid then
					Humanoid:EquipTool(toolToEquip)
					hasEquipped = true
				end

				if not hasEquipped and backpack and Humanoid then
					local armePrincipale, armeSecondaire = nil, nil
					for _, item in ipairs(backpack:GetChildren()) do
						if item:IsA("Tool") and item ~= Tool then
							if string.find(item.Name, "Desert Eagle") then armeSecondaire = item
							else armePrincipale = item end
						end
					end
					local toolToForceEquip = armePrincipale or armeSecondaire
					if toolToForceEquip then Humanoid:EquipTool(toolToForceEquip) end
				end

				local DestroyEvent = ReplicatedStorage:FindFirstChild("DestroyWeaponEvent")
				if DestroyEvent then DestroyEvent:FireServer(Tool)
				else Tool.Parent = nil Debris:AddItem(Tool, 0.1) end
			end
		end)

		task.spawn(function()
			task.wait(0.15) 
			if Viewmodel and CommonVariables.Equipped then
				for _, v in pairs(Viewmodel:GetDescendants()) do
					if v:IsA("BasePart") or v:IsA("MeshPart") or v:IsA("Decal") then v.LocalTransparencyModifier = 0 end
				end
				viewmodelEvent:Fire("SetViewmodelTransparent", false)
			end
		end)
	else
		if CurrentAnimTable.EmptyIdleAnim and CurrentVariables.Mag <= 0 then
			SetAnimationTrack("EmptyIdleAnim", "Play", CurrentModule.EmptyIdleAnimationSpeed, 0)
			SetAnimationTrack("VMEmptyIdleAnim", "Play", CurrentModule.VMEmptyIdleAnimationSpeed, 0)
		else
			SetAnimationTrack("IdleAnim", "Play", CurrentModule.IdleAnimationSpeed, 0)
			SetAnimationTrack("VMIdleAnim", "Play", CurrentModule.VMIdleAnimationSpeed, 0)
		end

		if CurrentAnimTable.EmptyEquippedAnim and CurrentVariables.Mag <= 0 then
			CurrentAnimTable.EmptyEquippedAnim.Looped = false
			SetAnimationTrack("EmptyEquippedAnim", "Play", CurrentModule.EmptyEquippedAnimationSpeed, 0)
			if CurrentVMAnimTable.VMEmptyEquippedAnim then CurrentVMAnimTable.VMEmptyEquippedAnim.Looped = false end
			SetAnimationTrack("VMEmptyEquippedAnim", "Play", CurrentModule.VMEmptyEquippedAnimationSpeed, 0)
		else
			if CurrentAnimTable.EquippedAnim then CurrentAnimTable.EquippedAnim.Looped = false end
			SetAnimationTrack("EquippedAnim", "Play", CurrentModule.EquippedAnimationSpeed, 0)
			if CurrentVMAnimTable.VMEquippedAnim then CurrentVMAnimTable.VMEquippedAnim.Looped = false end
			SetAnimationTrack("VMEquippedAnim", "Play", CurrentModule.VMEquippedAnimationSpeed, 0)
		end
	end
end)

local isCleaningUp = false 
OnUnequipping = function()
	if isCleaningUp then return end
	isCleaningUp = true

	Character:SetAttribute("BlockSlide", false)
	CommonVariables.IsEquipping = false
	CommonVariables.Equipped = false
	CommonVariables.ActuallyEquipped = false
	CommonVariables.Inspecting = false
	CommonVariables.EquipID = CommonVariables.EquipID + 1

	Character:SetAttribute("IsInspecting", false)
	RunService:UnbindFromRenderStep("SyringeRender_"..Tool.Name)

	for _, a in pairs(CurrentAnimTable) do
		if typeof(a) == "table" then
			for _, a2 in pairs(a) do if a2[1].IsPlaying then a2[1]:Stop(0.1) end end
		else if a.IsPlaying then a:Stop(0.1) end end 
	end

	for _, a in pairs(CurrentVMAnimTable) do
		if typeof(a) == "table" then
			for _, a2 in pairs(a) do if a2[1].IsPlaying then a2[1]:Stop(0.1) end end
		else if a.IsPlaying then a:Stop(0.1) end end
	end

	viewmodelEvent:Fire("CullViewmodel", Viewmodel)
	Viewmodel = nil

	task.delay(0.5, function() isCleaningUp = false end)
end

Tool.Unequipped:Connect(OnUnequipping)

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	if GameProcessed then return end
	local InputType = (Input.UserInputType == Enum.UserInputType.Keyboard) and "Keyboard" or (Input.UserInputType == Enum.UserInputType.Gamepad1) and "Controller" or nil

	if InputType and Module[InputType] and Input.KeyCode == Module[InputType].Inspect then
		OnInspecting(true)
	end
end)