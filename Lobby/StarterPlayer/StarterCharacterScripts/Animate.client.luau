-- ============================================================
--  Ce script gère le système d'animation complet du personnage,
--  incluant la gestion des états (course, marche, saut, etc.)
--  et les transitions fluides entre les animations.
--  Il intègre également une mécanique de sprint avec modification
--  dynamique du champ de vision (FOV) et de la vitesse de déplacement.
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
local UserInputService
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local camera = workspace.CurrentCamera
local defaultFOV = camera.FieldOfView
local fovTween

local runEvent = ReplicatedStorage:WaitForChild("UpdateRunningState")

local isRunning = false
local originalWalkSpeed = 12
local runSpeedBoost = 18
local runAcceleration = 50
local targetWalkSpeed = originalWalkSpeed

local currentAnim = ""
local currentAnimInstance = nil
local currentAnimTrack = nil
local currentAnimKeyframeHandler = nil
local currentAnimSpeed = 1
local animTable = {}
local animNames = {
	idle = 	{
		{ id = "http://www.roblox.com/asset/?id=180435571", weight = 9 },
		{ id = "http://www.roblox.com/asset/?id=180435792", weight = 1 }
	},
	walk = 	{
		{ id = "http://www.roblox.com/asset/?id=180426354", weight = 10 }
	},
	jump = 	{
		{ id = "http://www.roblox.com/asset/?id=111251100867105", weight = 10 }
	},
	fall = 	{
		{ id = "http://www.roblox.com/asset/?id=91288583206060", weight = 10 }
	},
	climb = {
		{ id = "http://www.roblox.com/asset/?id=132969691712833", weight = 10 }
	},
	sit = 	{
		{ id = "http://www.roblox.com/asset/?id=178130996", weight = 10 }
	},
	run = {
		{ id = "http://www.roblox.com/asset/?id=180426354", weight = 10 }
	},
	slide = {
		{ id = "http://www.roblox.com/asset/?id=180426354", weight = 10 }
	},
}

local idleWalkTransitionTime = 0.35

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

function scriptChildModified(child)
	local fileList = animNames[child.Name]
	if (fileList ~= nil) then
		configureAnimationSet(child.Name, fileList)
	end
end

script.ChildAdded:connect(scriptChildModified)
script.ChildRemoved:connect(scriptChildModified)

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

function setAnimationSpeed(speed)
	if speed ~= currentAnimSpeed then
		currentAnimSpeed = speed
		if currentAnimTrack then
			currentAnimTrack:AdjustSpeed(currentAnimSpeed)
		end
	end
end

function keyFrameReachedFunc(frameName)
	if (frameName == "End") then
		local repeatAnim = currentAnim
		local animSpeed = currentAnimSpeed
		playAnimation(repeatAnim, 0.0, Humanoid)
		setAnimationSpeed(animSpeed)
	end
end

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

local function tweenFOV(targetFOV)
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

function onRunning(speed)
	if speed > 0.01 then
		local backwards = false
		local HumanoidRootPart = getHumanoidRootPart()
		if HumanoidRootPart then
			local velocity = HumanoidRootPart.Velocity
			local look = HumanoidRootPart.CFrame.LookVector
			if velocity.Magnitude > 0.1 then
				local dot = velocity.Unit:Dot(look)
				if dot < -0.1 then
					backwards = true
				end
			end
		end

		local animToPlay = "walk"
		local transition = idleWalkTransitionTime

		if backwards then
			targetWalkSpeed = originalWalkSpeed
			Humanoid.WalkSpeed = originalWalkSpeed
			animToPlay = "walk"
			tweenFOV(defaultFOV)
			if currentAnim == "walk" then
				transition = 0.1
			end
			playAnimation(animToPlay, transition, Humanoid)
			
			
			setAnimationSpeed(-speed / 14.5)
		else
			if isRunning then
				targetWalkSpeed = originalWalkSpeed + runSpeedBoost
			else
				targetWalkSpeed = originalWalkSpeed
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

function move(time)
	local amplitude = 1
	local frequency = 1
	local deltaTime = time - lastTick
	lastTick = time

	if Humanoid.WalkSpeed < targetWalkSpeed then
		Humanoid.WalkSpeed = math.min(Humanoid.WalkSpeed + runAcceleration * deltaTime, targetWalkSpeed)
	elseif Humanoid.WalkSpeed > targetWalkSpeed then
		Humanoid.WalkSpeed = math.max(Humanoid.WalkSpeed - runAcceleration * deltaTime, targetWalkSpeed)
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

local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
		if not isRunning then
			isRunning = true
			targetWalkSpeed = originalWalkSpeed + runSpeedBoost
			runEvent:FireServer(true)
		end
	end
end

local function onInputEnded(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
		if isRunning then
			isRunning = false
			targetWalkSpeed = originalWalkSpeed
			runEvent:FireServer(false)
		end
	end
end

local function setupInputConnection()
	local player = Players.LocalPlayer
	if player then
		UserInputService = game:GetService("UserInputService")
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