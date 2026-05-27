-- ============================================================
-- Ce script gère la mécanique de wallrun côté client en ajustant dynamiquement l'inclinaison de la caméra, les animations et les sons de pas.
-- Il intègre des optimisations de raycasting et des sécurités mathématiques pour empêcher la corruption physique du personnage.
-- ============================================================

local TiltSpeed = 10 
local JumpPower = 50
local PushForward = 30
local PushAway = 50

local FakeWeaponSpeed = 45
local OriginalWalkSpeed = 16 

local MaxLookAngle = 75
local WallForward = Vector3.zero

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Stamina = require(ReplicatedStorage:WaitForChild("StaminaManager"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local FootstepModule = require(Modules:WaitForChild("FootstepModule"))

local MainSound = SoundService:WaitForChild("Main")
local CharacterSounds = MainSound:WaitForChild("Character")
local FootstepsSoundGroup = CharacterSounds:WaitForChild("Footsteps")

local CachedFootsteps = FootstepModule:GetCached(FootstepsSoundGroup, "Footsteps")
local wallstepTimer = 0
local WALLSTEP_INTERVAL = 0.25 

local LocalPlayer = Players.LocalPlayer
local cam = workspace.CurrentCamera
local Character = script.Parent
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")
local Signal = Character:WaitForChild("WallrunSignal")

local Goal = 0
local CurrentAngle = 0
local isWallrunning = false
local isStopping = false 
local wallDirection = 1
local wallrunStartTime = 0

local WallRideL = script:WaitForChild("WallRideR")
local WallRideR = script:WaitForChild("WallRideL")

local AnimationTracks = {
	WallRideL = nil,
	WallRideR = nil
}

local lastEquippedTool = nil
local pendingReequip = false 

-- Allocation unique des paramètres de Raycast pour réduire l'empreinte mémoire lors des appels haute fréquence
local sharedRayParams = RaycastParams.new()
sharedRayParams.FilterDescendantsInstances = {Character, cam}
sharedRayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Filtre et détruit spécifiquement les animations de wallrun en cours d'exécution sans altérer les animations natives
local function CleanupExistingAnimations(animator)
	if not animator then return end

	local tracks = animator:GetPlayingAnimationTracks()
	for _, track in pairs(tracks) do
		if track.Name == "WallRideL" or track.Name == "WallRideR" then
			track:Stop()
			track:Destroy()
		end
	end
end

-- Initialise l'Animator et charge les pistes d'animation en mémoire après un nettoyage préalable
local function LoadAnimations()
	local animator = Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = Humanoid
	end

	CleanupExistingAnimations(animator)

	AnimationTracks.WallRideL = animator:LoadAnimation(WallRideL)
	AnimationTracks.WallRideL.Name = "WallRideL" 

	AnimationTracks.WallRideR = animator:LoadAnimation(WallRideR)
	AnimationTracks.WallRideR.Name = "WallRideR" 
end

-- Force l'arrêt de toutes les animations de wallrun actives
local function StopWallrunAnimations()
	if AnimationTracks.WallRideL and AnimationTracks.WallRideL.IsPlaying then
		AnimationTracks.WallRideL:Stop()
	end
	if AnimationTracks.WallRideR and AnimationTracks.WallRideR.IsPlaying then
		AnimationTracks.WallRideR:Stop()
	end
end

-- Bascule sur l'animation de wallrun adéquate en fonction du côté du mur détecté
local function PlayWallrunAnimation(direction)
	StopWallrunAnimations()
	if direction == 1 then
		if AnimationTracks.WallRideR then AnimationTracks.WallRideR:Play() end
	elseif direction == -1 then
		if AnimationTracks.WallRideL then AnimationTracks.WallRideL:Play() end
	end
end

-- Retire temporairement l'équipement actif pour éviter les conflits d'animation des bras
local function unequipForWallrun()
	local currentTool = Character:FindFirstChildOfClass("Tool")
	if currentTool then
		lastEquippedTool = currentTool
		Humanoid:UnequipTools()
		pendingReequip = true
	end
end

-- Restaure de façon transparente l'équipement qui avait été rangé au début de l'action
local function reequipTool()
	if pendingReequip and lastEquippedTool and lastEquippedTool.Parent == LocalPlayer.Backpack then
		Humanoid:EquipTool(lastEquippedTool)
	end
	lastEquippedTool = nil
	pendingReequip = false
end

-- Interpolation linéaire mathématique standard pour lisser les transitions de variables
local function Lerp(a, b, t)
	return a + (b - a) * t
end

-- Détermine le matériau du mur par projection de rayon et instancie dynamiquement le son de pas correspondant
local function PlayWallstepSound()
	if not CachedFootsteps then return end

	local rayDir = HRP.CFrame.RightVector * wallDirection * 3
	local rayResult = workspace:Raycast(HRP.Position, rayDir, sharedRayParams)
	local material = rayResult and rayResult.Material or Enum.Material.Concrete

	local typeName = FootstepModule.MaterialMap[material] or "Concrete"
	local set = Character:GetAttribute("Set") or "Default"

	local typeTable = CachedFootsteps[set]
	if not typeTable then return end

	local materialSounds = typeTable[typeName]
	if materialSounds and #materialSounds > 0 then
		local sound = materialSounds[math.random(#materialSounds)]:Clone()
		local defaultPitch = sound:GetAttribute("DefaultPitch") or 1
		local defaultVolume = sound:GetAttribute("DefaultVolume") or 0.5

		sound.PlaybackSpeed = defaultPitch * (math.random(950, 1050) / 1000)
		sound.Volume = defaultVolume
		sound.Parent = HRP
		sound:Play()

		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
end

-- Calcule et applique le vecteur de force impulsant le personnage hors du mur tout en brisant l'état de wallrun
local function jump()
	if isWallrunning then
		isWallrunning = false 
		isStopping = true 

		local currentHVel = Vector3.new(HRP.AssemblyLinearVelocity.X, 0, HRP.AssemblyLinearVelocity.Z).Magnitude

		Signal:FireServer("stop", wallDirection)

		local linVel = HRP:FindFirstChildOfClass("LinearVelocity")
		if linVel then
			linVel.Enabled = false
		end

		StopWallrunAnimations()
		Humanoid.WalkSpeed = OriginalWalkSpeed

		local lookVector = HRP.CFrame.LookVector
		local actualForwardPush = math.max(PushForward, currentHVel * 1.15) 

		local rayRight = workspace:Raycast(HRP.Position, HRP.CFrame.RightVector * 3, sharedRayParams)
		local rayLeft = workspace:Raycast(HRP.Position, HRP.CFrame.RightVector * -3, sharedRayParams)

		local wallPushDirection = Vector3.zero
		local rightDist = rayRight and rayRight.Distance or math.huge
		local leftDist = rayLeft and rayLeft.Distance or math.huge

		if rightDist < leftDist and rayRight then
			wallPushDirection = rayRight.Normal
		elseif leftDist < rightDist and rayLeft then
			wallPushDirection = rayLeft.Normal
		else
			wallPushDirection = HRP.CFrame.RightVector * -wallDirection
		end

		local jumpForce = (lookVector * actualForwardPush) + (wallPushDirection * PushAway) + Vector3.new(0, JumpPower, 0)

		HRP.AssemblyLinearVelocity = jumpForce
		Character:SetAttribute("LastWallJump", tick())

		reequipTool()
	end
end

LoadAnimations()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.Space then
		jump()
	end
end)

Signal.OnClientEvent:Connect(function(angle)
	local targetDirection = (angle > 0) and 1 or -1

	if angle ~= 0 then
		local moveDot = Humanoid.MoveDirection:Dot(HRP.CFrame.LookVector)
		if moveDot <= 0.1 or Stamina.Current <= 0 or Stamina.IsExhausted then
			if not isStopping then
				isStopping = true
				Signal:FireServer("stop", targetDirection)
			end
			return
		end
	end

	Goal = angle
	local wasWallrunning = isWallrunning
	isWallrunning = (angle ~= 0)

	if not isWallrunning then 
		isStopping = false 
	end

	wallDirection = targetDirection
	Character:SetAttribute("IsWallrunning", isWallrunning)

	if isWallrunning then
		Character:SetAttribute("WallrunDirection", wallDirection)
		wallrunStartTime = tick()

		if not wasWallrunning then
			OriginalWalkSpeed = Humanoid.WalkSpeed
			Humanoid.WalkSpeed = FakeWeaponSpeed

			local flatLook = Vector3.new(HRP.CFrame.LookVector.X, 0, HRP.CFrame.LookVector.Z)
			if flatLook.Magnitude > 0.01 then
				WallForward = flatLook.Unit
			end

			wallstepTimer = WALLSTEP_INTERVAL 
			if wallDirection ~= 1 then
				pendingReequip = false
				lastEquippedTool = nil
			end
		end
		PlayWallrunAnimation(wallDirection)
	else
		Character:SetAttribute("WallrunDirection", 0)
		StopWallrunAnimations()
		Humanoid.WalkSpeed = OriginalWalkSpeed

		if pendingReequip then
			reequipTool()
		end
	end
end)

Humanoid.StateChanged:Connect(function(oldState, newState)
	if newState == Enum.HumanoidStateType.Landed then
		if not isWallrunning and pendingReequip then
			reequipTool()
		end
	end
end)

-- Boucle de rendu asynchrone modifiant la physique du joueur et l'inclinaison de la caméra avec un filtre directionnel anti-NaN
RunService:BindToRenderStep("WallrunCameraTilt", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
	CurrentAngle = Lerp(CurrentAngle, Goal, TiltSpeed * deltaTime)
	cam:SetAttribute("Tilt_Wallrun", CurrentAngle)
	cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(CurrentAngle))

	if isWallrunning then
		if Humanoid:GetState() ~= Enum.HumanoidStateType.Running then
			Humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end

		local cameraLook = cam.CFrame.LookVector
		local flatLook = Vector3.new(cameraLook.X, 0, cameraLook.Z)
		local directionAlign

		if flatLook.Magnitude > 0.001 then
			directionAlign = flatLook.Unit
		else
			directionAlign = HRP.CFrame.LookVector 
		end

		local targetRotation = CFrame.lookAt(HRP.Position, HRP.Position + directionAlign)

		HRP.CFrame = HRP.CFrame:Lerp(targetRotation, 0.3)

		wallstepTimer += deltaTime
		if wallstepTimer >= WALLSTEP_INTERVAL then
			wallstepTimer = 0
			PlayWallstepSound()
		end

		if not isStopping then
			local moveDot = Humanoid.MoveDirection:Dot(HRP.CFrame.LookVector)
			local camLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
			local angleDifference = 0

			if camLook.Magnitude > 0.01 and WallForward.Magnitude > 0.01 then
				local dotProduct = WallForward:Dot(camLook.Unit)
				angleDifference = math.deg(math.acos(math.clamp(dotProduct, -1, 1)))
			end

			if moveDot <= 0.1 or angleDifference > MaxLookAngle then
				isStopping = true
				Signal:FireServer("stop", wallDirection)
			end
		end
	else
		wallstepTimer = 0
	end
end)

Character.AncestryChanged:Connect(function()
	if not Character.Parent then
		StopWallrunAnimations()
	end
end)