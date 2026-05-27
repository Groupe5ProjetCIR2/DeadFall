-- ============================================================
-- Ce script gère l'IA complète d'un Boss : système d'animations 
-- avancé, logique d'attaques variées (Coup de poing, Slam avec 
-- onde de choc, Kick), gestion de la mort avec loot aléatoire 
-- et effet de disparition progressive.
-- ============================================================

function waitForChild(parent, childName)
	local child = parent:findFirstChild(childName)
	if child then return child end
	while true do
		child = parent.ChildAdded:wait()
		if child.Name==childName then return child end
	end
end

local ATTACK_RANGE    = 18  
local ATTACK_MIN_RANGE = 0 
local SHOCKWAVE_RADIUS  = 27   

local lastTick = 0
local jumpAnimTime = 0
local jumpAnimDuration = 0.31
local fallTransitionTime = 0.2
local Figure = script.Parent
local Humanoid = waitForChild(Figure, "Zombie")
local pose = "Standing"
local currentMoveAnim = "walk" 

Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

local currentAnim = ""
local currentAnimInstance = nil
local currentAnimTrack = nil
local currentAnimKeyframeHandler = nil
local currentAnimSpeed = 1.0
local animTable = {}
local animNames = { 
	idle = {  
		{ id = "http://www.roblox.com/asset/?id=507766666", weight = 1 },
		{ id = "http://www.roblox.com/asset/?id=507766951", weight = 1 },
		{ id = "http://www.roblox.com/asset/?id=507766388", weight = 9 }
	},
	walk = { { id = "http://www.roblox.com/asset/?id=507777826", weight = 10 } }, 
	punch = { { id = "http://www.roblox.com/asset/?id=83253809303415", weight = 10 } },
	slam = { { id = "http://www.roblox.com/asset/?id=103414261310763", weight = 10 } },
	run = { { id = "http://www.roblox.com/asset/?id=507767718", weight = 10 } }, 
	run2 = { { id = "http://www.roblox.com/asset/?id=507435072", weight = 10 } }, 
	jump = { { id = "http://www.roblox.com/asset/?id=507765000", weight = 10 } }, 
	fall = { { id = "http://www.roblox.com/asset/?id=507767968", weight = 10 } }, 
	climb = { { id = "http://www.roblox.com/asset/?id=507765644", weight = 10 } }
}

math.randomseed(tick())

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

for name, fileList in pairs(animNames) do 
	configureAnimationSet(name, fileList)
end

function preloadAllAnimations()
	for animName, animData in pairs(animTable) do
		if animData.count > 0 then
			for i = 1, animData.count do
				if animData[i] and animData[i].anim then
					local tempTrack = Humanoid:LoadAnimation(animData[i].anim)
					if tempTrack then
						tempTrack:Stop()
						tempTrack:Destroy()
					end
				end
			end
		end
	end
end

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
		playAnimation(repeatAnim, 0.15, Humanoid)
		setAnimationSpeed(animSpeed)
	end
end

function playAnimation(animName, transitionTime, humanoid) 
	if not animTable[animName] or animTable[animName].count == 0 then return end

	local roll = math.random(1, animTable[animName].totalWeight) 
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
		currentAnimTrack:Play(transitionTime)
		currentAnim = animName
		currentAnimInstance = anim

		if (currentAnimKeyframeHandler ~= nil) then
			currentAnimKeyframeHandler:disconnect()
		end
		currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)
	end
end

-- ==========================================
-- GESTION DES ATTAQUES DU BOSS
-- ==========================================

local sound = script.Parent.Head.Sound
local lastAttackTime = 0
local attackCooldown = 1
local isAttacking = false
local isDead = false 
local lastPunchAnim = ""
local KICK_RANGE = 10 

local head = script.Parent:WaitForChild("Head")
local punchSounds = {
	head:WaitForChild("poing2"),
	head:WaitForChild("poing3"),
	head:WaitForChild("poing4"),
	head:WaitForChild("poing5")
}
local lastPunchSound = nil 
local missSounds = {
	head:WaitForChild("rate1"),
	head:WaitForChild("rate2"),
	head:WaitForChild("rate3")
}
local lastMissSound = nil 

local function playRandomMissSound()
	local availableSounds = {}
	for _, soundInstance in ipairs(missSounds) do
		if soundInstance ~= lastMissSound then
			table.insert(availableSounds, soundInstance)
		end
	end
	local selectedSound = availableSounds[math.random(1, #availableSounds)]
	lastMissSound = selectedSound
	selectedSound:Play()
end

local function playRandomPunchSound()
	local availableSounds = {}
	for _, soundInstance in ipairs(punchSounds) do
		if soundInstance ~= lastPunchSound then
			table.insert(availableSounds, soundInstance)
		end
	end
	local selectedSound = availableSounds[math.random(1, #availableSounds)]
	lastPunchSound = selectedSound
	selectedSound:Play()
end

function getRandomPunchAnim()
	local punchAnims = {"punch","slam"}
	local availableAnims = {}

	for _, anim in ipairs(punchAnims) do
		if anim ~= lastPunchAnim then
			table.insert(availableAnims, anim)
		end
	end

	local selectedAnim = availableAnims[math.random(1, #availableAnims)]
	lastPunchAnim = selectedAnim
	return selectedAnim
end

local function checkForNearbyTargets()
	local robotRoot = Figure:FindFirstChild("HumanoidRootPart") or Figure:FindFirstChild("Torso")
	if not robotRoot then return nil, nil end

	local players = game:GetService("Players"):GetPlayers()
	local closestPlayer = nil
	local closestDistance = math.huge

	for _, player in ipairs(players) do
		if player.Character and player.Character ~= Figure then
			local character = player.Character
			local humanoid = character:FindFirstChild("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root then
				local distance = (root.Position - robotRoot.Position).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestPlayer = character
				end
			end
		end
	end

	return closestPlayer, closestDistance
end

local Debris = game:GetService("Debris")

local function applyPunchEffect(targetCharacter)
	local robotRoot = Figure:FindFirstChild("HumanoidRootPart") or Figure:FindFirstChild("Torso")
	local playerRoot = targetCharacter:FindFirstChild("HumanoidRootPart") or targetCharacter:FindFirstChild("Torso")
	local humanoidHit = targetCharacter:FindFirstChild("Humanoid")

	if not robotRoot or not playerRoot or not humanoidHit then return false end
	if targetCharacter:GetAttribute("IsDowned") then return false end

	local diff = playerRoot.Position - robotRoot.Position
	local direction = diff.Magnitude > 0.001 and diff.Unit or Vector3.new(0, 0, 1)

	humanoidHit.PlatformStand = true

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = Vector3.new(direction.X * 25, 10, direction.Z * 25)
	bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
	bodyVelocity.Parent = playerRoot
	Debris:AddItem(bodyVelocity, 0.15)

	humanoidHit:TakeDamage(40)
	playRandomPunchSound()

	task.delay(0.15, function()
		if humanoidHit then humanoidHit.PlatformStand = false end
	end)

	return true
end

local function applyKickEffect(targetCharacter)
	local robotRoot = Figure:FindFirstChild("HumanoidRootPart") or Figure:FindFirstChild("Torso")
	local playerRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
	local humanoidHit = targetCharacter:FindFirstChild("Humanoid")

	if not robotRoot or not playerRoot or not humanoidHit then return false end
	if targetCharacter:GetAttribute("IsDowned") then return false end

	local diff = (playerRoot.Position - robotRoot.Position)
	local flatDiff = Vector3.new(diff.X, 0, diff.Z)
	local direction = flatDiff.Magnitude > 0.001 and flatDiff.Unit or Vector3.new(1, 0, 0)

	humanoidHit:TakeDamage(50)
	playRandomPunchSound()

	local bvUp = Instance.new("BodyVelocity")
	bvUp.Velocity = Vector3.new(0, 40, 0)
	bvUp.MaxForce = Vector3.new(0, 8000, 0)
	bvUp.Parent = playerRoot
	Debris:AddItem(bvUp, 0.1)

	task.delay(0.1, function()
		local bvPush = Instance.new("BodyVelocity")
		bvPush.Velocity = Vector3.new(direction.X * 140, 0, direction.Z * 140)
		bvPush.MaxForce = Vector3.new(8000, 0, 8000)
		bvPush.Parent = playerRoot
		Debris:AddItem(bvPush, 0.4)
	end)

	return true
end

local function applySlamEffect()
	local robotRoot = Figure:FindFirstChild("HumanoidRootPart") or Figure:FindFirstChild("Torso")
	if not robotRoot then return end

	local players = game:GetService("Players"):GetPlayers()
	for _, player in ipairs(players) do
		local character = player.Character
		if character and character ~= Figure then
			local playerRoot = character:FindFirstChild("HumanoidRootPart")
			local humanoidHit = character:FindFirstChild("Humanoid")
			if playerRoot and humanoidHit and humanoidHit.Health > 0 and not character:GetAttribute("IsDowned") then
				local dist = (playerRoot.Position - robotRoot.Position).Magnitude
				if dist <= SHOCKWAVE_RADIUS then
					humanoidHit:TakeDamage(30)

					local diff = (playerRoot.Position - robotRoot.Position)
					local flatDiff = Vector3.new(diff.X, 0, diff.Z)
					local direction = flatDiff.Magnitude > 0.001 and flatDiff.Unit or Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)).Unit

					local bv = Instance.new("BodyVelocity")
					bv.Velocity = Vector3.new(direction.X * 15, 100, direction.Z * 15)
					bv.MaxForce = Vector3.new(6000, 6000, 6000)
					bv.Parent = playerRoot
					Debris:AddItem(bv, 0.3)
				end
			end
		end
	end
end

local function performAttack(targetCharacter, forcedAnim)
	if isAttacking then return end
	local currentTime = tick()
	if currentTime - lastAttackTime < attackCooldown then return end

	isAttacking = true
	lastAttackTime = currentTime

	local originalSpeed = Humanoid.WalkSpeed
	Humanoid.WalkSpeed = 0

	stopAllAnimations()
	local punchAnimName = forcedAnim or getRandomPunchAnim()
	playAnimation(punchAnimName, 0, Humanoid)
	local punchTrack = currentAnimTrack

	if punchTrack then
		if punchAnimName == "slam" then
			task.spawn(function()
				task.wait(1.5)

				local slamSound = Figure:FindFirstChild("Slam_sound", true)
				if slamSound then slamSound:Play() end

				applySlamEffect()

				local shockwaveFolder = Figure:FindFirstChild("ShockWave", true)
				local bossRoot = Figure:FindFirstChild("HumanoidRootPart")
				local groundPos = bossRoot and bossRoot.Position - Vector3.new(0, 3, 0) or Vector3.new(0,0,0)

				if shockwaveFolder then
					for _, name in ipairs({"1", "2", "3"}) do
						local wave = shockwaveFolder:FindFirstChild(name)
						if wave then
							wave.CFrame = CFrame.new(groundPos)
							wave.Transparency = 0
							task.delay(0.5, function()
								if wave and wave.Parent then wave.Transparency = 1 end
							end)
						end
						task.wait(0.2)
					end
				end

				task.wait(0.8)
				local target, dist = checkForNearbyTargets()
				if target and dist and dist <= KICK_RANGE * 1.5 then
					task.wait(0.3)
					performAttack(target, "punch")
				end
			end)
		end

		local triggerTime = math.max(0, punchTrack.Length - 0.2)
		task.wait(triggerTime)

		if punchAnimName ~= "slam" then
			local _, currentDistance = checkForNearbyTargets()
			if currentDistance and currentDistance <= KICK_RANGE then
				applyKickEffect(targetCharacter)
			else
				playRandomMissSound()
			end
		end

		task.wait(0.2)
	end

	Humanoid.WalkSpeed = originalSpeed
	isAttacking = false

	if Humanoid.WalkSpeed > 0 then
		onRunning(Humanoid.WalkSpeed)
	else
		playAnimation("idle", 0.1, Humanoid)
	end
end

local function performKick(targetCharacter)
	if isAttacking then return end
	local currentTime = tick()
	if currentTime - lastAttackTime < attackCooldown then return end

	isAttacking = true
	lastAttackTime = currentTime
	local originalSpeed = Humanoid.WalkSpeed
	Humanoid.WalkSpeed = 0

	stopAllAnimations()
	playAnimation("punch", 0, Humanoid) 
	local track = currentAnimTrack

	if track then
		local triggerTime = math.max(0, track.Length - 0.2)
		task.wait(triggerTime)

		local _, currentDistance = checkForNearbyTargets()
		if currentDistance and currentDistance <= ATTACK_RANGE then
			applyKickEffect(targetCharacter)
		else
			playRandomMissSound()
		end
		task.wait(0.2)
	end

	Humanoid.WalkSpeed = originalSpeed
	isAttacking = false
	if Humanoid.WalkSpeed > 0 then onRunning(Humanoid.WalkSpeed) else playAnimation("idle", 0.1, Humanoid) end
end

local function performSlam(targetCharacter)
	if isAttacking then return end
	local currentTime = tick()
	if currentTime - lastAttackTime < attackCooldown then return end

	isAttacking = true
	lastAttackTime = currentTime
	local originalSpeed = Humanoid.WalkSpeed
	Humanoid.WalkSpeed = 0

	stopAllAnimations()
	playAnimation("slam", 0, Humanoid)
	local track = currentAnimTrack

	if track then
		task.spawn(function()
			task.wait(1.5)

			local slamSound = Figure:FindFirstChild("Slam_sound", true)
			if slamSound then slamSound:Play() end

			applySlamEffect()

			local shockwaveFolder = Figure:FindFirstChild("ShockWave", true)
			local bossRoot = Figure:FindFirstChild("HumanoidRootPart")
			local groundPos = bossRoot and bossRoot.Position - Vector3.new(0, 3, 0) or Vector3.new(0,0,0)

			if shockwaveFolder then
				for _, name in ipairs({"1", "2", "3"}) do
					local wave = shockwaveFolder:FindFirstChild(name)
					if wave then
						wave.CFrame = CFrame.new(groundPos)
						wave.Transparency = 0
						task.delay(0.5, function()
							if wave and wave.Parent then wave.Transparency = 1 end
						end)
					end
					task.wait(0.2)
				end
			end

			task.wait(0.8)
			local target, dist = checkForNearbyTargets()
			if target and dist and dist <= ATTACK_RANGE then
				performKick(target)
			end
		end)

		task.wait(track.Length)
	end

	Humanoid.WalkSpeed = originalSpeed
	isAttacking = false
	if Humanoid.WalkSpeed > 0 then onRunning(Humanoid.WalkSpeed) else playAnimation("idle", 0.1, Humanoid) end
end

local function monitorDistance()
	while Figure.Parent ~= nil do
		task.wait(0.15)
		if isDead then break end

		local targetCharacter, closestDistance = checkForNearbyTargets()
		if not targetCharacter or not closestDistance then continue end
		if isAttacking then continue end

		if closestDistance >= ATTACK_MIN_RANGE and closestDistance <= ATTACK_RANGE then
			if math.random(1, 2) == 1 then
				performKick(targetCharacter)
			else
				performSlam(targetCharacter)
			end
		end
	end
end

coroutine.wrap(monitorDistance)()

-- ==========================================
-- ETATS DU HUMANOID
-- ==========================================

function onRunning(speed)
	if isAttacking then return end

	if speed > 0.01 and not isAttacking then
		if pose ~= "Running" then
			currentMoveAnim = "walk"
		end

		local scale = 15.0
		playAnimation(currentMoveAnim, 0.1, Humanoid)
		setAnimationSpeed(speed / scale)
		pose = "Running"
	elseif not isAttacking then
		playAnimation("idle", 0.1, Humanoid)
		pose = "Standing"
	end
end

function onDied()
	isDead = true
	pose = "Dead"

	local DROP_CHANCE = 3
	if math.random(1, 100) <= DROP_CHANCE then
		local ServerStorage = game:GetService("ServerStorage")
		local choixBonus = math.random(1, 100)
		local nomDuBonusTemplate = ""

		-- NOUVEAUX POURCENTAGES :
		if choixBonus <= 30 then
			nomDuBonusTemplate = "MaxAmmoBonus"         -- 30% (de 1 à 30)
		elseif choixBonus <= 60 then
			nomDuBonusTemplate = "DoubleArgentBonus"    -- 30% (de 31 à 60)
		elseif choixBonus <= 80 then
			nomDuBonusTemplate = "InstaKillBonus"       -- 20% (de 61 à 80)
		else
			nomDuBonusTemplate = "NukeBonus"            -- 10% (de 81 à 100)
		end

		local bonusTemplate = ServerStorage:FindFirstChild(nomDuBonusTemplate) 
		if bonusTemplate and Figure:FindFirstChild("HumanoidRootPart") then
			local newBonus = bonusTemplate:Clone()
			newBonus.Position = Figure.HumanoidRootPart.Position + Vector3.new(0, 1, 0)
			newBonus.Parent = workspace
		end
	end

	stopAllAnimations()
	local partsToFade = {}

	for _, descendant in ipairs(Figure:GetDescendants()) do
		if descendant:IsA("Sound") then
			descendant:Stop()
			descendant:Destroy() 
		elseif descendant:IsA("BasePart") or descendant:IsA("Decal") then
			if descendant.Name ~= "HumanoidRootPart" then
				table.insert(partsToFade, descendant)
			end
		end
	end

	task.spawn(function()
		task.wait(1) 
		local TweenService = game:GetService("TweenService")
		local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear)
		
		for _, part in ipairs(partsToFade) do
			if part and part.Parent then
				local tween = TweenService:Create(part, fadeInfo, {Transparency = 1})
				tween:Play()
			end
		end

		task.wait(0.3)
		if Figure then
			Figure:Destroy()
		end
	end)
end

function onJumping()
	playAnimation("jump", 0.1, Humanoid)
	jumpAnimTime = jumpAnimDuration
	pose = "Jumping"
end

function onClimbing(speed)
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

function onPlatformStanding()
	pose = "PlatformStanding"
end

function move(time)
	local deltaTime = time - lastTick
	lastTick = time

	if (jumpAnimTime > 0) then
		jumpAnimTime = jumpAnimTime - deltaTime
	end

	if (pose == "FreeFall" and jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	elseif (pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "PlatformStanding") then
		stopAllAnimations()
	end
end

Humanoid.Died:Connect(onDied)
Humanoid.Running:Connect(onRunning)
Humanoid.Jumping:Connect(onJumping)
Humanoid.Climbing:Connect(onClimbing)
Humanoid.GettingUp:Connect(onGettingUp)
Humanoid.FreeFalling:Connect(onFreeFall)
Humanoid.FallingDown:Connect(onFallingDown)
Humanoid.PlatformStanding:Connect(onPlatformStanding)

preloadAllAnimations()

playAnimation("idle", 0.1, Humanoid)
pose = "Standing"

local elapsedTime = 0
while Figure.Parent ~= nil do
	local dt = task.wait(0.1)
	elapsedTime = elapsedTime + dt
	if not isDead then 
		move(elapsedTime)
	end
end