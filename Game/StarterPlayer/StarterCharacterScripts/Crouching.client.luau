-- ============================================================
-- Ce script implémente une mécanique de glissade (slide) complète avec ajustement dynamique de la caméra, effets visuels au sol et gestion de l'endurance.
-- Il intègre de multiples vérifications physiques pour prévenir les anomalies de vélocité, brider les sauts excessifs (b-hop) et forcer le maintien de la position sous les obstacles.
-- ============================================================

local plr = game.Players.LocalPlayer
local Character = plr.Character or plr.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

local Stamina = require(ReplicatedStorage:WaitForChild("StaminaManager"))

local fxFolder = workspace:FindFirstChild("FX")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "FX"
	fxFolder.Parent = workspace
end

local slideDirection = Vector3.new(0, 0, 0)
local slideForceActive = false
local slideConnection = nil
local targetSlideSpeed = 0
local slideEntrySpeed = 0

local isWaitingForClearance = false
local slideCollisionConnection = nil

-- Projette un rayon vers le haut pour détecter si le joueur est bloqué par un plafond
local function isUnderCeiling()
	local origin = RootPart.Position
	local direction = Vector3.new(0, 4.5, 0)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {Character, fxFolder}
	params.FilterType = Enum.RaycastFilterType.Exclude
	return workspace:Raycast(origin, direction, params) ~= nil
end

local config = {
	DefaultFieldOfView = 70,
	CameraFOVResetTime = 1,
	BaseCameraOffsetY = 0, 
	BaseCameraOffsetZ = -1.4, 
	DustEnabled = true,
	DynamicDustColor = true,
	DustSpawnRate = 0.15,

	SlideKey = Enum.KeyCode.C,
	SlideSpeed = 45,
	MaxSlideSpeed = 90,
	SlideChainMultiplier = 1.25,
	SlideDuration = 0.47,
	SlideCooldown = 0.8,
	SlideFOV = 80,
	SlideCameraOffset = -2, 
	SlideCameraOffsetZ = 1.2,
	SlideMinCameraDistance = 3,
	SlideMaxCameraDistance = 12,
	SlideJumpEnabled = true,
	SlideJumpHeight = 55,
	JumpMomentumMultiplier = 1.85,
	MinSlideSpeedThreshold = 18, 
}

local Animator = Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", Humanoid)
local MonSlideAnim = Animator:LoadAnimation(script:WaitForChild("SlideAnim"))

local SlideSound = script:FindFirstChild("Crouch")

local originalSpeed = Humanoid.WalkSpeed
local originalMinCameraDistance = plr.CameraMinZoomDistance
local originalMaxCameraDistance = plr.CameraMaxZoomDistance

local dustTimer = 0
local isOnGround = true
local fovTween = nil
local lastFOV = config.DefaultFieldOfView
local isSliding = false
local slideDebounce = true
local slideTimer = 0
local sprintPressed = false
local lastEquippedTool = nil

local dustRayParams = RaycastParams.new()
dustRayParams.FilterType = Enum.RaycastFilterType.Exclude
dustRayParams.FilterDescendantsInstances = {Character}

Camera.FieldOfView = config.DefaultFieldOfView

-- Configure un écouteur asynchrone pour forcer le déséquipement de tout outil durant la glissade
local function SetupToolBlocker(char)
	char.ChildAdded:Connect(function(child)
		if isSliding and child:IsA("Tool") then
			task.defer(function()
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then hum:UnequipTools() end
			end)
		end
	end)
end

SetupToolBlocker(Character)

-- Crée ou récupère un Vector3Value pour servir de proxy aux Tweens d'offset de caméra
local function GetCamProxy(hum)
	local proxy = hum:FindFirstChild("CamOffsetProxy")
	if not proxy then
		proxy = Instance.new("Vector3Value")
		proxy.Name = "CamOffsetProxy"
		proxy.Value = Vector3.new(0, config.BaseCameraOffsetY, config.BaseCameraOffsetZ)
		proxy.Parent = hum
	end
	return proxy
end

if RootPart:GetAttribute("IsSliding") == nil then RootPart:SetAttribute("IsSliding", false) end

-- Anime la transition du FieldOfView en annulant proprement toute interpolation en cours
local function SmoothFOV(targetFOV, duration)
	if fovTween then
		fovTween:Cancel()
		fovTween = nil
	end
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	fovTween = TweenService:Create(Camera, tweenInfo, {FieldOfView = targetFOV})
	fovTween:Play()
	lastFOV = targetFOV
end

-- Rétablit la physique normale du joueur, gère les blocages sous plafond et sécurise la vélocité résiduelle
local function StopSlide()
	if not isSliding then return end

	-- Maintient la glissade de force tant que le joueur n'a pas l'espace vertical pour se relever
	if isUnderCeiling() then
		slideForceActive = false
		if slideConnection then
			slideConnection:Disconnect()
			slideConnection = nil
		end
		if not isWaitingForClearance then
			isWaitingForClearance = true
			task.spawn(function()
				while isUnderCeiling() do
					RunService.Heartbeat:Wait()
				end
				isWaitingForClearance = false
				StopSlide()
			end)
		end
		return
	end

	isSliding = false
	slideForceActive = false

	if slideConnection then slideConnection:Disconnect(); slideConnection = nil end
	if slideCollisionConnection then slideCollisionConnection:Disconnect(); slideCollisionConnection = nil end

	RootPart:SetAttribute("IsSliding", false)
	if MonSlideAnim then MonSlideAnim:Stop() end

	if lastEquippedTool and lastEquippedTool.Parent == plr.Backpack then
		Humanoid:EquipTool(lastEquippedTool)
	end
	lastEquippedTool = nil

	Humanoid.WalkSpeed = originalSpeed
	plr.CameraMinZoomDistance = originalMinCameraDistance
	plr.CameraMaxZoomDistance = originalMaxCameraDistance

	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	task.delay(0.15, function()
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end)

	SmoothFOV(config.DefaultFieldOfView, config.CameraFOVResetTime)

	-- Filtre de sécurité mathématique : purge les valeurs NaN ou de vélocité extrême
	local currentVel = RootPart.AssemblyLinearVelocity
	if currentVel.X ~= currentVel.X or currentVel.Y ~= currentVel.Y or currentVel.Z ~= currentVel.Z
		or math.abs(currentVel.X) > 2000 or math.abs(currentVel.Y) > 2000 or math.abs(currentVel.Z) > 2000 then
		currentVel = Vector3.new(0, 0, 0)
	end

	local flatVel = Vector3.new(currentVel.X, 0, currentVel.Z)
	if flatVel.Magnitude > originalSpeed then
		flatVel = flatVel.Unit * originalSpeed
	end
	RootPart.AssemblyLinearVelocity = Vector3.new(flatVel.X, currentVel.Y, flatVel.Z)

	local CAMgoal2 = { Value = Vector3.new(0, config.BaseCameraOffsetY, config.BaseCameraOffsetZ) }
	local CAMinfo2 = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local CAMtween2 = TweenService:Create(GetCamProxy(Humanoid), CAMinfo2, CAMgoal2)
	CAMtween2:Play()
end

-- Initialise l'état de glissade, modifie les collisions corporelles et lance la boucle de mouvement interpolé
local function StartSlide()
	if plr:GetAttribute("IsLoading") then return end 
	if Character:GetAttribute("BlockSlide") then return end
	if not slideDebounce then return end
	if not isOnGround then return end
	if isSliding then return end

	local currentHVel = Vector3.new(RootPart.AssemblyLinearVelocity.X, 0, RootPart.AssemblyLinearVelocity.Z)
	local entrySpeed = currentHVel.Magnitude

	if entrySpeed < config.MinSlideSpeedThreshold or entrySpeed <= originalSpeed + 1 then return end
	if not Stamina:Consume(30) then return end

	local currentTool = Character:FindFirstChildOfClass("Tool")
	if currentTool then
		lastEquippedTool = currentTool
		Humanoid:UnequipTools()
	else
		lastEquippedTool = nil
	end

	slideDebounce = false
	isSliding = true
	slideForceActive = true
	RootPart:SetAttribute("IsSliding", true)

	if MonSlideAnim then MonSlideAnim:Play() end
	if SlideSound then SlideSound:Play() end

	plr.CameraMinZoomDistance = config.SlideMinCameraDistance
	plr.CameraMaxZoomDistance = config.SlideMaxCameraDistance
	SmoothFOV(config.SlideFOV, 0.3)

	local CAMgoal1 = { Value = Vector3.new(0, config.SlideCameraOffset, config.SlideCameraOffsetZ) }
	local CAMinfo1 = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local CAMtween1 = TweenService:Create(GetCamProxy(Humanoid), CAMinfo1, CAMgoal1)
	CAMtween1:Play()

	-- Extraction du vecteur de direction sécurisé pour éviter l'échec si le joueur regarde directement vers le haut/bas
	local camLook = Camera.CFrame.LookVector
	local flatCamDir = Vector3.new(camLook.X, 0, camLook.Z)

	local cameraDirection
	if flatCamDir.Magnitude > 0.001 then
		cameraDirection = flatCamDir.Unit
	else
		cameraDirection = RootPart.CFrame.LookVector 
	end

	if Humanoid.MoveDirection.Magnitude > 0 then
		slideDirection = Humanoid.MoveDirection.Unit
	else
		slideDirection = cameraDirection
	end
	_G.lastSlideDirection = slideDirection

	if entrySpeed > originalSpeed + 10 then
		targetSlideSpeed = math.min(entrySpeed * config.SlideChainMultiplier, config.MaxSlideSpeed)
	else
		targetSlideSpeed = config.SlideSpeed
	end
	slideEntrySpeed = math.max(entrySpeed, originalSpeed)

	if slideConnection then slideConnection:Disconnect() end
	if slideCollisionConnection then slideCollisionConnection:Disconnect() end

	-- Modifie les groupes de collision des membres à l'exclusion du torse et de la tête pour affiner la hitbox
	slideCollisionConnection = RunService.Stepped:Connect(function()
		for _, part in ipairs(Character:GetChildren()) do
			if part:IsA("BasePart") 
				and part.Name ~= "HumanoidRootPart" 
				and part.Name ~= "LowerTorso"
				and part.Name ~= "Head" then
				if part.CollisionGroup == "Default" then
					part.CanCollide = false
				end
			end
		end
	end)

	-- Boucle de mouvement : gère les Blockcasts frontaux et applique une courbe de vélocité asymétrique
	slideConnection = RunService.Heartbeat:Connect(function(dt)
		if isSliding and slideForceActive and RootPart then

			local params = RaycastParams.new()
			params.FilterDescendantsInstances = {Character, fxFolder}
			params.FilterType = Enum.RaycastFilterType.Exclude

			local hit = workspace:Blockcast(RootPart.CFrame, Vector3.new(2, 1, 1), slideDirection * 2, params)
			if hit and hit.Instance.CanCollide then
				StopSlide()
				return
			end

			local t = math.clamp(slideTimer / config.SlideDuration, 0, 1)
			local currentSpeed = 0
			if t < 0.25 then
				local alpha = t / 0.25
				alpha = 1 - (1 - alpha)^2
				currentSpeed = slideEntrySpeed + (targetSlideSpeed - slideEntrySpeed) * alpha
			else
				local alpha = (t - 0.25) / 0.75
				alpha = alpha^2 * (3 - 2 * alpha)
				currentSpeed = targetSlideSpeed - ((targetSlideSpeed - (originalSpeed * 0.4)) * alpha)
			end

			local velocity = slideDirection * currentSpeed
			local currentY = RootPart.AssemblyLinearVelocity.Y

			if velocity.X ~= velocity.X or velocity.Z ~= velocity.Z or currentY ~= currentY then
				StopSlide()
				return
			end

			RootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, currentY, velocity.Z)
		end
	end)

	slideTimer = 0
	task.delay(config.SlideCooldown, function() slideDebounce = true end)
end

-- Extrait le joueur d'une glissade en un saut impulsé, avec bridage de la vélocité horizontale
local function SlideJump()
	if plr:GetAttribute("IsLoading") then return end 
	if not config.SlideJumpEnabled then return end
	if not isSliding then return end

	local currentHVel = Vector3.new(RootPart.AssemblyLinearVelocity.X, 0, RootPart.AssemblyLinearVelocity.Z)

	if currentHVel.X ~= currentHVel.X or currentHVel.Z ~= currentHVel.Z or currentHVel.Magnitude > 2000 then
		currentHVel = Vector3.new(0, 0, 0)
	end

	if currentHVel.Magnitude > config.MaxSlideSpeed then
		currentHVel = currentHVel.Unit * config.MaxSlideSpeed
	end

	if currentHVel.Magnitude < 5 then
		local jumpDir = slideDirection
		if jumpDir.Magnitude == 0 then
			local camLook = Camera.CFrame.LookVector
			local flatCamDir = Vector3.new(camLook.X, 0, camLook.Z)
			if flatCamDir.Magnitude > 0.001 then
				jumpDir = flatCamDir.Unit
			else
				jumpDir = RootPart.CFrame.LookVector
			end
		end
		currentHVel = jumpDir * config.SlideSpeed
	end

	local jumpVelocity = currentHVel * config.JumpMomentumMultiplier

	StopSlide()

	RootPart.AssemblyLinearVelocity = Vector3.new(jumpVelocity.X, math.clamp(config.SlideJumpHeight, 0, 60), jumpVelocity.Z)
	Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
end

UIS.InputBegan:Connect(function(input, isTyping)
	if isTyping then return end
	if input.KeyCode == config.SlideKey then
		sprintPressed = true
		StartSlide()
	end
	if input.KeyCode == Enum.KeyCode.Space then
		SlideJump()
	end
end)

UIS.InputEnded:Connect(function(input, isTyping)
	if isTyping then return end
	if input.KeyCode == config.SlideKey then sprintPressed = false end
end)

-- Coupe préventivement la glissade si le joueur passe dans un état incompatible 
local function onStateChanged(_, newState)
	if isSliding then
		if newState == Enum.HumanoidStateType.Dead
			or newState == Enum.HumanoidStateType.Climbing
			or newState == Enum.HumanoidStateType.Swimming
			or newState == Enum.HumanoidStateType.Seated
			or newState == Enum.HumanoidStateType.Physics then
			StopSlide()
		end
	end
end

-- Supervise l'état de glissade en temps réel, émet la poussière dynamique et régule l'arrêt
RunService.Heartbeat:Connect(function(dt)
	isOnGround = Humanoid.FloorMaterial ~= Enum.Material.Air

	if isSliding and not Character:GetAttribute("IsDowned") then
		slideTimer = slideTimer + dt
		if slideTimer >= config.SlideDuration then StopSlide() end

		if isWaitingForClearance then
			Humanoid.WalkSpeed = 10 
		else
			Humanoid.WalkSpeed = math.max(config.SlideSpeed, targetSlideSpeed)
		end

		if fovTween == nil and math.abs(Camera.FieldOfView - config.SlideFOV) > 0.5 then
			Camera.FieldOfView = config.SlideFOV
		end

		if config.DustEnabled and isOnGround then
			dustTimer = dustTimer + dt
			if dustTimer >= config.DustSpawnRate then
				dustTimer = 0
				local rayResult = workspace:Raycast(RootPart.Position + Vector3.new(0, 1, 0), Vector3.new(0, -4.5, 0), dustRayParams)
				local dustTemplate = game.ReplicatedStorage:FindFirstChild("VFX") and game.ReplicatedStorage.VFX:FindFirstChild("Dust")

				if dustTemplate then
					local dust = dustTemplate:Clone()
					dust.Position = RootPart.Position + Vector3.new(0, -2.5, 0)
					dust.Parent = fxFolder
					dust.Name = "SlideDust"

					if config.DynamicDustColor and rayResult and rayResult.Instance:IsA("BasePart") then
						dust.Attachment.Dust.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, rayResult.Instance.Color),
							ColorSequenceKeypoint.new(1, rayResult.Instance.Color)
						}
					else
						dust.Attachment.Dust.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
					end

					dust.Attachment.Dust:Emit(1)
					game.Debris:AddItem(dust, 0.8)
				end
			end
		end
	end
end)

Humanoid.StateChanged:Connect(onStateChanged)

-- Réinitialise les événements et l'état interne à chaque fois que le joueur respawn
plr.CharacterAdded:Connect(function(newCharacter)
	Character = newCharacter
	Humanoid = Character:WaitForChild("Humanoid")
	RootPart = Character:WaitForChild("HumanoidRootPart")
	Animator = Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", Humanoid)
	MonSlideAnim = Animator:LoadAnimation(script:WaitForChild("SlideAnim"))

	dustRayParams.FilterDescendantsInstances = {Character}

	dustTimer = 0
	isOnGround = true
	isSliding = false
	sprintPressed = false
	slideTimer = 0
	isWaitingForClearance = false
	originalSpeed = Humanoid.WalkSpeed
	fovTween = nil
	lastFOV = config.DefaultFieldOfView

	if RootPart:GetAttribute("IsSliding") == nil then RootPart:SetAttribute("IsSliding", false) end

	SetupToolBlocker(newCharacter) 
	Humanoid.StateChanged:Connect(onStateChanged)
end)

local SlideTilt = 0
local TargetRightTilt = -15
local TiltSpeed = 6
local Lerp = function(a, b, t) return a + (b - a) * t end

-- Procède à l'inclinaison dynamique de l'axe Z de la caméra durant le déplacement
RunService:BindToRenderStep("SlideCameraTilt", Enum.RenderPriority.Camera.Value + 2, function(deltaTime)
	if isSliding then
		SlideTilt = Lerp(SlideTilt, TargetRightTilt, TiltSpeed * deltaTime)
	else
		SlideTilt = Lerp(SlideTilt, 0, TiltSpeed * deltaTime)
	end
	Camera.CFrame = Camera.CFrame * CFrame.Angles(0, 0, math.rad(SlideTilt))
end)

RunService.RenderStepped:Connect(function()
	if isSliding then
		UIS.MouseIconEnabled = false
	end
end)