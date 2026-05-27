-- ============================================================
-- Ce script ajoute une mécanique de double saut avec des effets de caméra dynamiques (inclinaison et secousses).
-- Il vérifie la présence d'un attribut spécifique et consomme de l'endurance avant d'appliquer l'impulsion physique.
-- ============================================================

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Stamina = require(ReplicatedStorage:WaitForChild("StaminaManager"))

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HRP = Character:WaitForChild("HumanoidRootPart")
local Head = Character:WaitForChild("Head")
local Camera = workspace.CurrentCamera

local CONFIG = {
	DoubleJumpForce        = 60,
	DoubleJumpForwardBoost = 20,
	CameraTiltAngleZ       = 5,
	CameraTiltDuration     = 0.22,
	CameraShakeIntensity   = 0.8,
	CameraShakeDuration    = 0.2,
	SND_IDS = {
		118228128668228,
		133266288501181,
		78518310321674,
	},
	MaxVolume = 0.8,
}

local jumpSounds = {}
for i, id in ipairs(CONFIG.SND_IDS) do
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://106080887189875"
	s.Volume = CONFIG.MaxVolume
	s.Looped = false
	s.Parent = Head
	table.insert(jumpSounds, s)
end

local lastSoundIndex = 0

-- Joue un son de saut aléatoire parmi la liste sans répéter le même consécutivement
local function playJumpSound()
	local newIndex
	repeat newIndex = math.random(1, #jumpSounds)
	until newIndex ~= lastSoundIndex or #jumpSounds == 1
	lastSoundIndex = newIndex
	jumpSounds[newIndex]:Play()
end

local canDoubleJump  = false
local hasDoubleJumped = false
local isAirborne     = false

local cameraTiltZ = Instance.new("NumberValue")
cameraTiltZ.Value = 0

local cameraShakeIntensity = Instance.new("NumberValue")
cameraShakeIntensity.Value = 0

local lastCameraOffset = CFrame.identity

-- Retire l'offset de caméra de la frame précédente juste avant le rendu pour éviter de cumuler les angles
RunService:BindToRenderStep("DoubleJumpCameraPre", Enum.RenderPriority.Camera.Value - 1, function()
	if lastCameraOffset ~= CFrame.identity then
		Camera.CFrame = Camera.CFrame * lastCameraOffset:Inverse()
	end
end)

-- Applique le nouveau décalage (secousse procédurale et inclinaison) après la mise à jour par défaut de la caméra
RunService:BindToRenderStep("DoubleJumpCameraPost", Enum.RenderPriority.Camera.Value + 1, function()
	local tiltZ = cameraTiltZ.Value
	local shake = cameraShakeIntensity.Value

	if tiltZ ~= 0 or shake > 0.01 then
		local rx = (math.random() * 2 - 1) * shake
		local ry = (math.random() * 2 - 1) * shake
		local rz = (math.random() * 2 - 1) * shake

		local currentOffset = CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(tiltZ + rz))
		Camera.CFrame = Camera.CFrame * currentOffset
		lastCameraOffset = currentOffset
	else
		lastCameraOffset = CFrame.identity
	end
end)

-- Actualise les variables de permission de saut en surveillant les transitions d'état du moteur physique
Humanoid.StateChanged:Connect(function(oldState, newState)
	if newState == Enum.HumanoidStateType.Landed then
		isAirborne      = false
		canDoubleJump   = false
		hasDoubleJumped = false 
	elseif newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
		isAirborne = true
		if not hasDoubleJumped then
			task.delay(0.1, function()
				canDoubleJump = true
			end)
		end
	end
end)

-- Intercepte la touche de saut pour déclencher l'impulsion et les effets si les conditions sont remplies
UserInputService.InputBegan:Connect(function(input, isProcessed)
	if isProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.Space then return end

	if Player:GetAttribute("BouncyBubble") ~= true then return end

	if isAirborne and canDoubleJump and not hasDoubleJumped then
		if Stamina.IsExhausted or Stamina.Current < 50 then return end

		hasDoubleJumped = true
		canDoubleJump   = false

		Stamina:Consume(50)

		local forwardBoost = Humanoid.MoveDirection * CONFIG.DoubleJumpForwardBoost
		local currentVel = HRP.AssemblyLinearVelocity

		if currentVel.X ~= currentVel.X or currentVel.Z ~= currentVel.Z or currentVel.Magnitude > 3000 then
			currentVel = Vector3.new(0, 0, 0)
		end

		-- Applique la force verticale combinée au boost directionnel en sécurité
		HRP.AssemblyLinearVelocity = Vector3.new(
			currentVel.X + forwardBoost.X,
			CONFIG.DoubleJumpForce,
			currentVel.Z + forwardBoost.Z
		)

		local moveDirCamSpace = Camera.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
		local targetTiltZ = 0

		if moveDirCamSpace.X < -0.1 then
			targetTiltZ = CONFIG.CameraTiltAngleZ
		elseif moveDirCamSpace.X > 0.1 then
			targetTiltZ = -CONFIG.CameraTiltAngleZ
		end

		if targetTiltZ ~= 0 then
			local tweenZInfo = TweenInfo.new(CONFIG.CameraTiltDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
			TweenService:Create(cameraTiltZ, tweenZInfo, {Value = targetTiltZ}):Play()
		end

		cameraShakeIntensity.Value = CONFIG.CameraShakeIntensity
		TweenService:Create(cameraShakeIntensity, TweenInfo.new(CONFIG.CameraShakeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = 0}):Play()

		playJumpSound()
		Character:SetAttribute("IsDoubleJumping", true)
		task.delay(0.3, function()
			Character:SetAttribute("IsDoubleJumping", false)
		end)
	end
end)