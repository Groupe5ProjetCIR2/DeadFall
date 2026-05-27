-- ============================================================
-- Ce script gère les animations et les déplacements du joueur en intégrant un système de sprint avec ajustement du FOV et la détection des mouvements en arrière. 
-- Il adapte dynamiquement la vitesse en fonction d'attributs personnalisés (comme "SonicMint") et de l'état actuel du personnage (visée, inspection d'arme).
-- ============================================================

local Figure = script.Parent
local Torso = Figure:WaitForChild("Torso")
local RightShoulder = Torso:WaitForChild("Right Shoulder")
local LeftShoulder = Torso:WaitForChild("Left Shoulder")
local RightHip = Torso:WaitForChild("Right Hip")
local LeftHip = Torso:WaitForChild("Left Hip")
local Neck = Torso:WaitForChild("Neck")
local Humanoid = Figure:WaitForChild("Humanoid")
local pose = "Standing"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera
local defaultFOV = camera.FieldOfView
local fovTween

local runEvent = ReplicatedStorage:WaitForChild("UpdateRunningState")

local isRunning = false
local currentlyBackwards = false 

local runAcceleration = 50

local Player = game:GetService("Players").LocalPlayer

-- Calcule et renvoie la vitesse de marche et de sprint selon les attributs du joueur
local function getSpeeds()
	local walk = 12
	local boost = 13  

	if Player and Player:GetAttribute("SonicMint") == true then
		walk = 12
		boost = 18
	end

	return walk, boost
end

local currentWalk_Init, _ = getSpeeds()
local targetWalkSpeed = currentWalk_Init

-- Met à jour la vitesse cible dynamiquement si l'attribut est modifié en pleine partie
Player:GetAttributeChangedSignal("SonicMint"):Connect(function()
	local currentWalk, currentBoost = getSpeeds()
	targetWalkSpeed = isRunning and (currentWalk + currentBoost) or currentWalk
end)

local currentAnim = ""
local currentAnimInstance = nil
local currentAnimTrack = nil
local currentAnimKeyframeHandler = nil
local currentAnimSpeed = 1
local animTable = {}
local animNames = {
	idle =     {
		{ id = "http://www.roblox.com/asset/?id=180435571", weight = 9 },
		{ id = "http://www.roblox.com/asset/?id=180435792", weight = 1 }
	},
	walk =     {
		{ id = "http://www.roblox.com/asset/?id=180426354", weight = 10 }
	},
	jump =     {
		{ id = "http://www.roblox.com/asset/?id=111251100867105", weight = 10 }
	},
	fall =     {
		{ id = "http://www.roblox.com/asset/?id=91288583206060", weight = 10 }
	},
	climb = {
		{ id = "http://www.roblox.com/asset/?id=132969691712833", weight = 10 }
	},
	sit =      {
		{ id = "http://www.roblox.com/asset/?id=178130996", weight = 10 }
	},
	run = {
		{ id = "http://www.roblox.com/asset/?id=180426354", weight = 10 }
	},
}

local idleWalkTransitionTime = 0.35

-- Charge et configure un set d'animations spécifique en instanciant les objets Animation
function configureAnimationSet(name, fileList)
	if (animTable[name] ~= nil) then
		for _, connection in pairs(animTable[name].connections) do
			connection:disconnect()
		end
	end
	animTable[name] = {}
	animTable[name].count = 0
	animTable[name].totalWeight = 0
	animTable[name].connections = {}

	local config = script:FindFirstChild(name)
	if (config ~= nil) then
		table.insert(animTable[name].connections, config.ChildAdded:connect(function(child) configureAnimationSet(name, fileList) end))
		table.insert(animTable[name].connections, config.ChildRemoved:connect(function(child) configureAnimationSet(name, fileList) end))
		local idx = 1
		for _, childPart in pairs(config:GetChildren()) do
			if (childPart:IsA("Animation")) then
				table.insert(animTable[name].connections, childPart.Changed:connect(function(property) configureAnimationSet(name, fileList) end))
				animTable[name][idx] = {}
				animTable[name][idx].anim = childPart
				local weightObject = childPart:FindFirstChild("Weight")
				if (weightObject == nil) then
					animTable[name][idx].weight = 1
				else
					animTable[name][idx].weight = weightObject.Value
				end
				animTable[name].count = animTable[name].count + 1
				animTable[name].totalWeight = animTable[name].totalWeight + animTable[name][idx].weight
				idx = idx + 1
			end
		end
	end

	if (animTable[name].count <= 0) then
		for idx, anim in pairs(fileList) do
			animTable[name][idx] = {}
			animTable[name][idx].anim = Instance.new("Animation")
			animTable[name][idx].anim.Name = name
			animTable[name][idx].anim.AnimationId = anim.id
			animTable[name][idx].weight = anim.weight
			animTable[name].count = animTable[name].count + 1
			animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
		end
	end
end

-- Relance la configuration des animations si un enfant du script change
function scriptChildModified(child)
	local fileList = animNames[child.Name]
	if (fileList ~= nil) then
		configureAnimationSet(child.Name, fileList)
	end
end

script.ChildAdded:connect(scriptChildModified)
script.ChildRemoved:connect(scriptChildModified)

-- Initialise l'animation de course personnalisée si une StringValue est trouvée
local function setupRunAnimation()
	local runValue = script:FindFirstChild("run")
	if runValue and runValue:IsA("StringValue") and runValue.Value ~= "" then
		animNames.run = { { id = runValue.Value, weight = 10 } }
	end
end

setupRunAnimation()

for name, fileList in pairs(animNames) do
	configureAnimationSet(name, fileList)
end

-- Télécharge les animations en mémoire au lancement pour éviter les latences en jeu
local function preloadAnimations()
	local assetsToLoad = {}
	for animName, animSet in pairs(animTable) do
		for i = 1, animSet.count do
			table.insert(assetsToLoad, animSet[i].anim)
		end
	end

	local success, err = pcall(function()
		ContentProvider:PreloadAsync(assetsToLoad)
	end)
end

preloadAnimations()
setupRunAnimation()

local jumpAnimTime = 0
local jumpAnimDuration = 0.3
local fallTransitionTime = 0.3
local jumpMaxLimbVelocity = 0.75

-- Arrête et détruit la piste d'animation en cours
function stopAllAnimations()
	local oldAnim = currentAnim

	currentAnim = ""
	currentAnimInstance = nil
	if (currentAnimKeyframeHandler ~= nil) then
		currentAnimKeyframeHandler:disconnect()
	end

	if (currentAnimTrack ~= nil) then
		currentAnimTrack:Stop()
		currentAnimTrack:Destroy()
		currentAnimTrack = nil
	end
	return oldAnim
end

-- Modifie la vitesse de lecture de l'animation active
function setAnimationSpeed(speed)
	if speed ~= currentAnimSpeed then
		currentAnimSpeed = speed
		if currentAnimTrack then
			currentAnimTrack:AdjustSpeed(currentAnimSpeed)
		end
	end
end

-- Boucle l'animation de manière fluide lorsqu'elle atteint la fin
function keyFrameReachedFunc(frameName)
	if (frameName == "End") then
		local repeatAnim = currentAnim
		local animSpeed = currentAnimSpeed
		playAnimation(repeatAnim, 0.0, Humanoid)
		setAnimationSpeed(animSpeed)
	end
end

-- Gère la sélection (via système de poids/probabilité) et la transition d'une nouvelle animation
function playAnimation(animName, transitionTime, humanoid)
	local roll = math.random(1, animTable[animName].totalWeight)
	local origRoll = roll
	local idx = 1
	while (roll > animTable[animName][idx].weight) do
		roll = roll - animTable[animName][idx].weight
		idx = idx + 1
	end
	local anim = animTable[animName][idx].anim

	if (anim ~= currentAnimInstance) then

		if (currentAnimTrack ~= nil) then
			currentAnimTrack:Stop(transitionTime)
			currentAnimTrack:Destroy()
		end

		currentAnimSpeed = 1.0

		currentAnimTrack = humanoid:LoadAnimation(anim)
		currentAnimTrack.Priority = Enum.AnimationPriority.Core

		currentAnimTrack:Play(transitionTime)
		currentAnim = animName
		currentAnimInstance = anim

		if (currentAnimKeyframeHandler ~= nil) then
			currentAnimKeyframeHandler:disconnect()
		end
		currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)

	end
end

-- Interpole la valeur du FieldOfView avec une vérification de blocage lors de la visée
local function tweenFOV(targetFOV)
	if Figure:GetAttribute("IsAiming") then
		return
	end

	if fovTween then
		fovTween:Cancel()
	end

	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	fovTween = TweenService:Create(camera, tweenInfo, {FieldOfView = targetFOV})
	fovTween:Play()
end

local function getHumanoidRootPart()
	local hrp = Figure:FindFirstChild("HumanoidRootPart")
	return hrp
end

-- Calcule le produit scalaire entre la vélocité et l'orientation (ignorant l'axe Y) pour détecter un recul
local function checkBackwards()
	local backwards = false
	local hrp = getHumanoidRootPart()
	if hrp then
		local vel = hrp.Velocity
		local flatVel = Vector3.new(vel.X, 0, vel.Z)
		local look = hrp.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)

		if flatVel.Magnitude > 0.1 and flatLook.Magnitude > 0 then
			flatLook = flatLook.Unit
			local dot = flatVel.Unit:Dot(flatLook)
			if dot < -0.1 then
				backwards = true
			end
		end
	end
	return backwards
end

-- Événement de déplacement qui adapte l'animation, la vitesse de lecture et le FOV en fonction de l'état du joueur
function onRunning(speed)
	if Figure:GetAttribute("IsDowned") then return end
	if speed > 0.01 then
		local backwards = checkBackwards()
		currentlyBackwards = backwards

		local animToPlay = "walk"
		local transition = idleWalkTransitionTime

		local currentTool = Figure:FindFirstChildOfClass("Tool")
		local isHoldingSyringe = currentTool and (string.lower(currentTool.Name) == "seringue" or string.lower(currentTool.Name) == "syringe")

		local currentWalk, currentBoost = getSpeeds()

		if backwards or Figure:GetAttribute("IsAiming") or (Figure:GetAttribute("IsInspecting") and not isHoldingSyringe) then
			targetWalkSpeed = currentWalk
			Humanoid.WalkSpeed = currentWalk
			animToPlay = "walk"
			tweenFOV(defaultFOV)
			if currentAnim == "walk" then
				transition = 0.1
			end
			playAnimation(animToPlay, transition, Humanoid)

			if backwards then
				setAnimationSpeed(-speed / 14.5)
			else
				setAnimationSpeed(speed / 14.5)
			end
		else
			if isRunning then
				targetWalkSpeed = currentWalk + currentBoost
			else
				targetWalkSpeed = currentWalk
			end

			if isRunning and animNames.run[1].id ~= "" then
				animToPlay = "run"
				tweenFOV(defaultFOV + 15)
				if currentAnim == "run" then
					transition = 0.1
				end
			else
				animToPlay = "walk"
				tweenFOV(defaultFOV)
				if currentAnim == "walk" then
					transition = 0.1
				end
			end
			playAnimation(animToPlay, transition, Humanoid)

			if animToPlay == "run" then
				setAnimationSpeed(1.3)
			else
				setAnimationSpeed(speed / 14.5)
			end
		end

		pose = "Running"
	else
		local transition = idleWalkTransitionTime
		if currentAnim == "idle" then
			transition = 0.1
		end
		playAnimation("idle", transition, Humanoid)
		pose = "Standing"
		tweenFOV(defaultFOV)
	end
end

-- Restauration instantanée du FOV via événement
Figure:GetAttributeChangedSignal("IsAiming"):Connect(function()
	if not Figure:GetAttribute("IsAiming") then
		local hrp = Figure:FindFirstChild("HumanoidRootPart")
		local speed = hrp and Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude or 0
		onRunning(speed) 
	end
end)

-- Boucle de détection haute fréquence liée au moteur physique (changement de direction)
RunService.Heartbeat:Connect(function()
	if pose == "Running" then
		local isBack = checkBackwards()
		if isBack ~= currentlyBackwards then
			currentlyBackwards = isBack
			local hrp = getHumanoidRootPart()
			local speed = hrp and Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude or 0
			onRunning(speed) 
		end
	end
end)

function onDied()
	pose = "Dead"
end

function onJumping()
	playAnimation("jump", 0.1, Humanoid)
	jumpAnimTime = jumpAnimDuration
	pose = "Jumping"
end

function onClimbing(speed)
	playAnimation("climb", 0.1, Humanoid)
	setAnimationSpeed(speed / 12.0)
	pose = "Climbing"
end

function onGettingUp()
	pose = "GettingUp"
end

function onFreeFall()
	if (jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	end
	pose = "FreeFall"
end

function onFallingDown()
	pose = "FallingDown"
end

function onSeated()
	pose = "Seated"
end

function onPlatformStanding()
	pose = "PlatformStanding"
end

function onSwimming(speed)
	if speed > 0 then
		pose = "Running"
	else
		pose = "Standing"
	end
end

function moveSit()
	RightShoulder.MaxVelocity = 0.15
	LeftShoulder.MaxVelocity = 0.15
	RightShoulder:SetDesiredAngle(3.14 /2)
	LeftShoulder:SetDesiredAngle(-3.14 /2)
	RightHip:SetDesiredAngle(3.14 /2)
	LeftHip:SetDesiredAngle(-3.14 /2)
end

local lastTick = 0

-- Boucle principale procédurale : Gère l'accélération graduelle et l'animation manuelle des joints en cas d'immobilisation
function move(time)
	local amplitude = 1
	local frequency = 1
	local deltaTime = time - lastTick
	lastTick = time

	if not Figure:GetAttribute("IsDowned") then
		if Humanoid.WalkSpeed < targetWalkSpeed then
			Humanoid.WalkSpeed = math.min(Humanoid.WalkSpeed + runAcceleration * deltaTime, targetWalkSpeed)
		elseif Humanoid.WalkSpeed > targetWalkSpeed then
			Humanoid.WalkSpeed = math.max(Humanoid.WalkSpeed - runAcceleration * deltaTime, targetWalkSpeed)
		end
	end

	local climbFudge = 0
	local setAngles = false

	if (jumpAnimTime > 0) then
		jumpAnimTime = jumpAnimTime - deltaTime
	end

	if (pose == "FreeFall" and jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	elseif (pose == "Seated") then
		playAnimation("sit", 0.5, Humanoid)
		return
	elseif (pose == "Running") then
	elseif (pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "Seated" or pose == "PlatformStanding") then
		stopAllAnimations()
		amplitude = 0.1
		frequency = 1
		setAngles = true
	end

	if (setAngles) then
		local desiredAngle = amplitude * math.sin(time * frequency)

		RightShoulder:SetDesiredAngle(desiredAngle + climbFudge)
		LeftShoulder:SetDesiredAngle(desiredAngle - climbFudge)
		RightHip:SetDesiredAngle(-desiredAngle)
		LeftHip:SetDesiredAngle(-desiredAngle)
	end

end

-- Détecte les inputs pour déclencher le sprint (Shift, Gâchette gauche)
local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
		if not isRunning and not Figure:GetAttribute("IsDowned") then
			local currentWalk, currentBoost = getSpeeds() 
			isRunning = true
			targetWalkSpeed = currentWalk + currentBoost 
			runEvent:FireServer(true)
			if pose == "Running" then
				local hrp = getHumanoidRootPart()
				local speed = hrp and Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude or 0
				onRunning(speed)
			end
		end
	end
end

-- Détecte la fin de l'input pour relâcher le sprint
local function onInputEnded(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
		if isRunning then
			local currentWalk, currentBoost = getSpeeds() 
			isRunning = false
			targetWalkSpeed = currentWalk 
			runEvent:FireServer(false)
			if pose == "Running" then
				local hrp = getHumanoidRootPart()
				local speed = hrp and Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude or 0
				onRunning(speed)
			end
		end
	end
end

-- Connecte de façon sécurisée les événements d'entrée du LocalPlayer
local function setupInputConnection()
	local player = Players.LocalPlayer
	if player then
		if player.Character == Figure or player.CharacterAdded:Wait() == Figure then
			local success, err = pcall(function()
				UserInputService.InputBegan:Connect(onInputBegan)
				UserInputService.InputEnded:Connect(onInputEnded)
			end)
		end
	end
end

spawn(function()
	wait(1)
	setupInputConnection()
end)

Humanoid.Died:connect(onDied)
Humanoid.Running:connect(onRunning)
Humanoid.Jumping:connect(onJumping)
Humanoid.Climbing:connect(onClimbing)
Humanoid.GettingUp:connect(onGettingUp)
Humanoid.FreeFalling:connect(onFreeFall)
Humanoid.FallingDown:connect(onFallingDown)
Humanoid.Seated:connect(onSeated)
Humanoid.PlatformStanding:connect(onPlatformStanding)
Humanoid.Swimming:connect(onSwimming)

playAnimation("idle", idleWalkTransitionTime, Humanoid)
pose = "Standing"

while Figure.Parent ~= nil do
	local _, time = wait(0.1)
	move(time)
end