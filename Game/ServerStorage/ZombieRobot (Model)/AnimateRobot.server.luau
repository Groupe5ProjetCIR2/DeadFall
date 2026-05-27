-- ============================================================
-- Ce script gère l'IA complète d'un zombie : personnalisation 
-- physique (vêtements, couleur, casque), système d'animations 
-- avancées, logique d'attaque (recul, dégâts, sons) et gestion 
-- de la mort avec effet de disparition progressive.
-- ============================================================

local lastTick = 0
local jumpAnimTime = 0
local jumpAnimDuration = 0.31
local fallTransitionTime = 0.2
local Figure = script.Parent

-- Fonction utilitaire pour attendre l'apparition d'un enfant dans l'objet parent.
function waitForChild(parent, childName)
	local child = parent:findFirstChild(childName)
	if child then return child end
	while true do
		child = parent.ChildAdded:wait()
		if child.Name==childName then return child end
	end
end

local Humanoid = waitForChild(Figure, "Zombie")
local pose = "Standing"
local currentMoveAnim = "walk" 

-- ==========================================
-- SYSTÈME DE VÊTEMENTS ALÉATOIRES
-- ==========================================
local ServerStorage = game:GetService("ServerStorage")
local clothesFolder = ServerStorage:FindFirstChild("ZombieClothes")

if clothesFolder then
	local randomStyle = math.random(1, 10)
	local targetName = "Clothing" .. randomStyle

	for _, child in ipairs(Figure:GetChildren()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end

	for _, item in ipairs(clothesFolder:GetChildren()) do
		if item.Name == targetName and (item:IsA("Shirt") or item:IsA("Pants")) then
			item:Clone().Parent = Figure
		end
	end
else
	warn("⚠️ Le dossier 'ZombieClothes' est introuvable dans ServerStorage !")
end

-- ==========================================
-- COULEUR DE PEAU ALÉATOIRE (Tons de vert)
-- ==========================================
local greenTones = {
	Color3.fromRGB(105, 165, 102), 
	Color3.fromRGB(127, 142, 100), 
	Color3.fromRGB(75, 151, 75),   
	Color3.fromRGB(86, 124, 70),   
	Color3.fromRGB(164, 189, 71)   
}

local head = Figure:FindFirstChild("Head")
if head then
	local randomSkinColor = greenTones[math.random(1, #greenTones)]
	head.Color = randomSkinColor

	local bodyColors = Figure:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor3 = randomSkinColor
		bodyColors.LeftArmColor3 = randomSkinColor
		bodyColors.RightArmColor3 = randomSkinColor
	end
end

-- ==========================================
-- SYSTÈME DE CASQUE ALÉATOIRE (95% de chance)
-- ==========================================
local helmetsFolder = ServerStorage:FindFirstChild("ZombieHelmets")

if helmetsFolder then
	if math.random(1, 100) <= 95 then
		local randomHelmetNum = math.random(1, 11)
		local targetHelmetName = "Helmet" .. randomHelmetNum
		local helmetToEquip = helmetsFolder:FindFirstChild(targetHelmetName)

		if helmetToEquip and helmetToEquip:IsA("Accessory") then
			helmetToEquip:Clone().Parent = Figure
		else
			warn("Casque introuvable ou ce n'est pas un Accessory : " .. targetHelmetName)
		end
	end
else
	warn("Le dossier 'ZombieHelmets' est introuvable dans ServerStorage !")
end

Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

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
	punch = { { id = "http://www.roblox.com/asset/?id=507777823", weight = 10 } }, 
	punch1 = { { id = "http://www.roblox.com/asset/?id=507777824", weight = 10 } }, 
	punch2 = { { id = "http://www.roblox.com/asset/?id=507777825", weight = 10 } }, 
	punch3 = { { id = "http://www.roblox.com/asset/?id=507777826", weight = 10 } }, 
	punch4 = { { id = "http://www.roblox.com/asset/?id=507777827", weight = 10 } }, 
	punch5 = { { id = "http://www.roblox.com/asset/?id=507767829", weight = 10 } }, 
	run = { { id = "http://www.roblox.com/asset/?id=507767718", weight = 10 } }, 
	run2 = { { id = "http://www.roblox.com/asset/?id=507435072", weight = 10 } }, 
	jump = { { id = "http://www.roblox.com/asset/?id=507765000", weight = 10 } }, 
	climb = { { id = "http://www.roblox.com/asset/?id=507765644", weight = 10 } },
	barrierjump = { { id = "http://www.roblox.com/asset/?id=132351098787961", weight = 10 } }
}

math.randomseed(tick())

-- Configuration et chargement des ensembles d'animations en mémoire.
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

local msgValue = script:FindFirstChild("msg")
if msgValue then
	msgValue.Changed:connect(function(newAnim)
		if newAnim == "" then return end
		if animTable[newAnim] and animTable[newAnim].count > 0 then
			playAnimation(newAnim, 0.1, Humanoid)
		else
			warn("⚠️ Animation inconnue : " .. newAnim)
		end

		task.delay(0.1, function()
			if msgValue then msgValue.Value = "" end
		end)
	end)
else
	warn("⚠️ StringValue 'msg' manquant dans AnimateRobot !")
end

-- Précharge les animations pour éviter les saccades lors du premier déclenchement.
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

-- Système de lecture d'animation avec pondération (probabilités).
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
-- LOGIQUE D'ATTAQUE ET IA ZOMBIE
-- ==========================================
local isAttacking = false
local isDead = false 
local lastPunchAnim = ""
local attackRange = 3
local lastAttackTime = 0
local attackCooldown = 1

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
	local punchAnims = {"punch", "punch1", "punch2", "punch3", "punch4", "punch5"}
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

-- Scan pour détecter les joueurs proches via leurs parties physiques.
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
			if humanoid and humanoid.Health > 0 then
				for _, part in pairs(character:GetChildren()) do
					if part:IsA("BasePart") then
						local distance = (part.Position - robotRoot.Position).Magnitude
						if distance < closestDistance then
							closestDistance = distance
							closestPlayer = character
						end
					end
				end
			end
		end
	end
	return closestPlayer, closestDistance
end

-- Applique le recul (knockback) et les dégâts lors d'un coup réussi.
local function applyPunchEffect(targetCharacter)
	local robotRoot = Figure:FindFirstChild("HumanoidRootPart") or Figure:FindFirstChild("Torso")
	local playerRoot = targetCharacter:FindFirstChild("HumanoidRootPart") or targetCharacter:FindFirstChild("Torso")
	local humanoidHit = targetCharacter:FindFirstChild("Humanoid")

	if not robotRoot or not playerRoot or not humanoidHit then return false end

	if targetCharacter:GetAttribute("EstImmunise") == false then
		targetCharacter:SetAttribute("EstImmunise", true)

		local diff = playerRoot.Position - robotRoot.Position
		local direction = (diff.Magnitude > 0.001) and diff.Unit or Vector3.new(0, 0, 1)

		humanoidHit.PlatformStand = true
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Velocity = Vector3.new(direction.X * 25, 10, direction.Z * 25)
		bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
		bodyVelocity.Parent = playerRoot

		local dynamicDamage = Figure:GetAttribute("CurrentDamage") or 40
		humanoidHit:TakeDamage(dynamicDamage)
		playRandomPunchSound()

		task.delay(0.15, function()
			if bodyVelocity then bodyVelocity:Destroy() end
			if humanoidHit then humanoidHit.PlatformStand = false end
		end)
		return true
	end
	return false
end

-- Gère la séquence d'attaque : animation -> délai -> impact.
local function performAttack(targetCharacter)
	if isAttacking then return end
	local currentTime = tick()
	if currentTime - lastAttackTime < attackCooldown then return end

	isAttacking = true
	lastAttackTime = currentTime

	local oldAnim = stopAllAnimations()
	local punchAnimName = getRandomPunchAnim()
	playAnimation(punchAnimName, 0, Humanoid)
	local punchTrack = currentAnimTrack

	if punchTrack then
		local triggerTime = math.max(0, punchTrack.Length - 0.2)
		task.wait(triggerTime)

		local _, currentDistance = checkForNearbyTargets()
		if currentDistance and currentDistance <= attackRange then
			applyPunchEffect(targetCharacter)
		else
			playRandomMissSound()
		end
		task.wait(0.2)
	end

	isAttacking = false
	if Humanoid.WalkSpeed > 0 then
		onRunning(Humanoid.WalkSpeed)
	else
		playAnimation("idle", 0.1, Humanoid)
	end
end

-- Boucle de surveillance des cibles en continu.
local function monitorDistance()
	while Figure.Parent ~= nil do
		task.wait(0.1)
		if isDead then break end 

		local targetCharacter, closestDistance = checkForNearbyTargets()
		if targetCharacter and closestDistance and closestDistance <= attackRange and not isAttacking then
			performAttack(targetCharacter)
		end
	end
end

coroutine.wrap(monitorDistance)()

-- ==========================================
-- GESTION DES ETATS DU HUMANOID
-- ==========================================
function onRunning(speed)
	if speed > 0.01 and not isAttacking then
		if pose ~= "Running" then
			local moves = {"walk", "run", "run2"}
			currentMoveAnim = moves[math.random(1, #moves)]
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

	-- Gestion du loot aléatoire à la mort.
	local DROP_CHANCE = 3
	if math.random(1, 100) <= DROP_CHANCE then
		local ServerStorage = game:GetService("ServerStorage")
		local choixBonus = math.random(1, 100)
		local nomDuBonusTemplate = (choixBonus <= 30 and "MaxAmmoBonus") or (choixBonus <= 60 and "DoubleArgentBonus") or (choixBonus <= 90 and "InstaKillBonus") or "NukeBonus"

		local bonusTemplate = ServerStorage:FindFirstChild(nomDuBonusTemplate) 
		if bonusTemplate and Figure:FindFirstChild("HumanoidRootPart") then
			local newBonus = bonusTemplate:Clone()
			newBonus.Position = Figure.HumanoidRootPart.Position + Vector3.new(0, 1, 0)
			newBonus.Parent = workspace
		end
	end

	stopAllAnimations()

	-- Effet de disparition (fade) des pièces.
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
				TweenService:Create(part, fadeInfo, {Transparency = 1}):Play()
			end
		end

		task.wait(0.3)
		if Figure then Figure:Destroy() end
	end)
end

function onJumping()
	playAnimation("jump", 0.1, Humanoid)
	jumpAnimTime = jumpAnimDuration
	pose = "Jumping"
end

function onClimbing(speed) pose = "Climbing" end
function onGettingUp() pose = "GettingUp" end
function onPlatformStanding() pose = "PlatformStanding" end

function move(time)
	local deltaTime = time - lastTick
	lastTick = time

	if (jumpAnimTime > 0) then jumpAnimTime = jumpAnimTime - deltaTime end

	if (pose == "FreeFall" and jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	elseif (pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "PlatformStanding") then
		stopAllAnimations()
	end
end

Humanoid.Died:connect(onDied)
Humanoid.Running:connect(onRunning)
Humanoid.Jumping:connect(onJumping)
Humanoid.Climbing:connect(onClimbing)
Humanoid.GettingUp:connect(onGettingUp)
Humanoid.PlatformStanding:connect(onPlatformStanding)

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