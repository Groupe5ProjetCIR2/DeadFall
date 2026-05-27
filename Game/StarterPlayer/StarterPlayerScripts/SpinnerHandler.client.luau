-- ============================================================
--  Ce script gère visuellement et logiquement une roue de la chance 
--  côté client, incluant ses animations de flottaison et de rotation. 
--  Il s'occupe également de générer dynamiquement la disposition des 
--  récompenses sans doublons et de gérer la disparition de la roue.
-- ============================================================

local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService") 
local RunS = game:GetService("RunService")

local player = game.Players.LocalPlayer
local assets = RS:WaitForChild("SpinnerAssets")
local sounds = assets:WaitForChild("Sounds")
local giveWeaponEvent = RS:WaitForChild("GiveSpinnerWeapon")
local startSpinnerEvent = RS:WaitForChild("StartSpinner")

local spinnermodel = game.Workspace:WaitForChild("Spinner")
local spinnerroot = spinnermodel:WaitForChild("Root")
local segments = spinnermodel:WaitForChild("Segments")

local wheelSpawns = workspace:WaitForChild("WheelSpawns")
local lastSpawnPart = nil

local dart = spinnermodel:WaitForChild("Dart")
local dartAttachment = dart:WaitForChild("Attachment")
local shockwaveParticle = dartAttachment:WaitForChild("Shockwave1")

local segmentstable = {}
local originalData = {}
local selectedsegments = nil

local wheelState = "Idle" 
local spinAngle = Instance.new("NumberValue")
spinAngle.Value = 0

local fadeTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local hiddenImageId = "rbxassetid://119224209911532"
local hiddenColor = Color3.fromRGB(50, 50, 50) 

local originalTransparencies = {}
local dartOffset = nil

local floatTime = 0
local BASE_HEIGHT = 4         
local FLOAT_AMPLITUDE = 0.4  
local FLOAT_SPEED = 1.2      
local SWAY_AMPLITUDE = 0.7   
local SWAY_SPEED = 1.5       
local TILT_AMPLITUDE = 8     
local TILT_SPEED = 1.2       
local SWAY_TILT_AMPLITUDE = 6

local currentFloatAlpha = 0
local startupDelay = 2
local gameStartTime = tick()

local finalSelectedSegment = nil

local MOOV_COUNT = 3

-- Configuration des récompenses disponibles avec gestion de la rareté et de la présence garantie
local WeaponsDict = {
	["Epic"] = {
		{name = "DF-1008", image = "rbxassetid://100246987485045", color = Color3.fromRGB(255, 105, 180), text = "Epic", textSize = 23, AlwaysThere = false}
	},
	["Rare"] = {
		{name = "Galax-4", image = "rbxassetid://100762335182413", color = Color3.fromRGB(0, 150, 255), text = "Rare", textSize = 23, AlwaysThere = false}
	},
	["Uncommon"] = {
		{name = "FAMAS-3", image = "rbxassetid://127678184438441", color = Color3.fromRGB(50, 255, 50), text = "Good", textSize = 20, AlwaysThere = false},
		{name = "AK-207", image = "rbxassetid://130152604935944", color = Color3.fromRGB(50, 255, 50), text = "Good", textSize = 20, AlwaysThere = false},
		{name = "GT-505", image = "rbxassetid://97306265276468", color = Color3.fromRGB(50, 255, 50), text = "Good", textSize = 20, AlwaysThere = false}

	},
	["Common"] = {
		{name = "Desert Eagle 2", image = "rbxassetid://125265396705724", color = Color3.fromRGB(200, 200, 200), text = "Common", textSize = 13, AlwaysThere = false},
		{name = "ShotRun", image = "rbxassetid://72973622240777", color = Color3.fromRGB(200, 200, 200), text = "Common", textSize = 13, AlwaysThere = false},
		{name = "P-240", image = "rbxassetid://129204293316318", color = Color3.fromRGB(200, 200, 200), text = "Common", textSize = 13, AlwaysThere = false},
		{name = "Snizer", image = "rbxassetid://85383001155607", color = Color3.fromRGB(200, 200, 200), text = "Common", textSize = 13, AlwaysThere = false}

	}
}

local AllWeaponsFlatList = {}
for _, rarityGroup in pairs(WeaponsDict) do
	for _, weapon in ipairs(rarityGroup) do
		table.insert(AllWeaponsFlatList, weapon)
	end
end

-- Sélectionne aléatoirement un point d'apparition valide pour la roue
local function getRandomSpawnPart()
	local parts = {}
	for _, child in ipairs(wheelSpawns:GetChildren()) do
		if child.Name == "SpawnWheel" and child ~= lastSpawnPart then
			table.insert(parts, child)
		end
	end
	if #parts == 0 then return lastSpawnPart end
	return parts[math.random(1, #parts)]
end

local moveWheelEvent = RS:WaitForChild("MoveWheelEvent")
local currentSpawnValue = spinnermodel:WaitForChild("CurrentSpawn")

-- Demande au serveur de déplacer physiquement la roue vers un nouveau point d'apparition
currentSpawnValue.Changed:Connect(function(newSpawn)
	if newSpawn then
		lastSpawnPart = newSpawn
	end
end)
lastSpawnPart = currentSpawnValue.Value

local function moveWheelToSpawn(spawnPart)
	if not spawnPart then return end
	moveWheelEvent:FireServer(spawnPart)
end

-- Génère dynamiquement une nouvelle disposition pour la roue via un système de pioche sans remise
local function applyNewWheelLayout()
	local numSegments = #segmentstable
	local newLayout = {}

	for i = 1, MOOV_COUNT do
		if #newLayout < numSegments then
			table.insert(newLayout, {
				name = "Moov", 
				image = "rbxassetid://111580712679164", 
				color = Color3.fromRGB(255, 0, 0),
				text = "Moove", 
				textSize = 17,
				textColor = Color3.fromRGB(255, 255, 255)
			})
		end
	end

	local availableWeapons = {}
	local mandatoryWeapons = {}

	for _, weapon in ipairs(AllWeaponsFlatList) do
		if weapon.AlwaysThere then
			table.insert(mandatoryWeapons, weapon)
		else
			table.insert(availableWeapons, weapon)
		end
	end

	for _, weapon in ipairs(mandatoryWeapons) do
		if #newLayout < numSegments then
			table.insert(newLayout, weapon)
		end
	end

	while #newLayout < numSegments and #availableWeapons > 0 do
		local randomIndex = math.random(1, #availableWeapons)
		local selectedWeapon = availableWeapons[randomIndex]

		table.insert(newLayout, selectedWeapon)
		table.remove(availableWeapons, randomIndex)
	end

	for i = #newLayout, 2, -1 do
		local j = math.random(1, i)
		newLayout[i], newLayout[j] = newLayout[j], newLayout[i]
	end

	for i, segment in ipairs(segmentstable) do
		local w = newLayout[i]
		if not w then break end 

		if not originalData[segment] then
			originalData[segment] = { isVisible = true }
		end
		local data = originalData[segment]

		data.color = w.color
		data.image = w.image
		data.text = w.text
		data.name = w.name
		data.textSize = w.textSize
		data.textColor = w.textColor

		if data.isVisible then
			segment.Color = data.color
			local sg = segment:FindFirstChild("SurfaceGui")
			if sg then
				local img = sg:FindFirstChild("ImageLabel")
				local txt = sg:FindFirstChild("TextLabel")
				if img then img.Image = data.image end
				if txt then
					txt.Text = data.text
					txt.TextColor3 = data.textColor or data.color
					txt.TextSize = data.textSize
				end
			end
		end
	end
end

-- Met à jour l'état du ProximityPrompt selon le cooldown du joueur
local function update_proximityprompt()
	local enabled = not player:GetAttribute("SpinDebounce")
	spinnerroot.ProximityPrompt.Enabled = enabled
end

-- Extrait numériquement l'index d'un segment à partir de son identifiant textuel
local function getSegmentIndex(segment)
	return tonumber(string.match(segment.Name, "%d+"))
end

-- Gère l'animation de transition (fondu enchaîné) pour révéler ou cacher un segment
local function transitionSegment(segment, makeVisible)
	local data = originalData[segment]
	if data.isVisible == makeVisible then return end

	data.isVisible = makeVisible

	local sg = segment:FindFirstChild("SurfaceGui")
	local img = sg and sg:FindFirstChild("ImageLabel")
	local txt = sg and sg:FindFirstChild("TextLabel")

	local targetPartColor = makeVisible and data.color or hiddenColor

	TS:Create(segment, fadeTweenInfo, {Color = targetPartColor}):Play()

	if img and txt then
		local fadeOutImg = TS:Create(img, fadeTweenInfo, {ImageTransparency = 1})
		local fadeOutTxt = TS:Create(txt, fadeTweenInfo, {TextTransparency = 1})

		fadeOutImg.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed and data.isVisible == makeVisible then
				img.Image = makeVisible and data.image or hiddenImageId
				txt.Text = makeVisible and data.text or ""

				if makeVisible then
					txt.TextColor3 = data.textColor or data.color
					txt.TextScaled = false
					txt.TextSize = data.textSize
				end

				TS:Create(img, fadeTweenInfo, {ImageTransparency = 0}):Play()
				TS:Create(txt, fadeTweenInfo, {TextTransparency = 0}):Play()
			end
		end)

		fadeOutImg:Play()
		fadeOutTxt:Play()
	end
end

-- Initialise et exécute la rotation de la roue, attribue la récompense et gère les événements post-spin
local function spin()
	wheelState = "Spinning" 
	spinAngle.Value = 0
	sounds.activate:Play()

	applyNewWheelLayout()

	local tween = TS:Create(spinAngle, TweenInfo.new(10, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
		Value = 1000
	})

	finalSelectedSegment = nil

	tween:Play()

	tween.Completed:Connect(function()
		wheelState = "Idle"
		finalSelectedSegment = selectedsegments
		sounds.reward:Play()

		shockwaveParticle:Emit(1)

		local willTeleport = false

		if finalSelectedSegment and originalData[finalSelectedSegment] then
			local wonWeaponName = originalData[finalSelectedSegment].name

			if wonWeaponName == "Moov" then
				willTeleport = true 
			else
				giveWeaponEvent:FireServer(wonWeaponName) 
			end
		end

		local segmentsToReveal = {}
		for _, seg in pairs(segmentstable) do
			if not originalData[seg].isVisible then
				table.insert(segmentsToReveal, seg)
			end
		end

		local delayPerSegment = 0.5 / math.max(1, #segmentsToReveal)
		for _, seg in ipairs(segmentsToReveal) do
			transitionSegment(seg, true)
			task.wait(delayPerSegment)
		end

		task.wait(1.5)
		player:SetAttribute("SpinDebounce", false)

		if willTeleport then
			task.wait(0.5)
			local newSpawn = getRandomSpawnPart()
			if newSpawn then
				spinnerroot.ProximityPrompt.Enabled = false

				local teleportSound = spinnerroot:FindFirstChild("Teleport")
				if teleportSound then
					teleportSound.RollOffMaxDistance = 50
					teleportSound.RollOffMinDistance = 10
					teleportSound:Play()
				end

				local fadeInfo = TweenInfo.new(1, Enum.EasingStyle.Sine)

				-- Itération optimisée sur le cache des transparences pour éclipser l'ensemble du modèle
				for desc, _ in pairs(originalTransparencies) do
					if desc:IsA("BasePart") then
						TS:Create(desc, fadeInfo, {Transparency = 1}):Play()
					elseif desc:IsA("ImageLabel") then
						TS:Create(desc, fadeInfo, {ImageTransparency = 1}):Play()
					elseif desc:IsA("TextLabel") then
						TS:Create(desc, fadeInfo, {TextTransparency = 1}):Play()
					end
				end

				task.wait(1)

				moveWheelToSpawn(newSpawn)

				local fadeInInfo = TweenInfo.new(1, Enum.EasingStyle.Sine)

				for desc, originalTrans in pairs(originalTransparencies) do
					if desc:IsA("BasePart") then
						TS:Create(desc, fadeInInfo, {Transparency = originalTrans}):Play()
					elseif desc:IsA("ImageLabel") then
						TS:Create(desc, fadeInInfo, {ImageTransparency = originalTrans}):Play()
					elseif desc:IsA("TextLabel") then
						TS:Create(desc, fadeInInfo, {TextTransparency = originalTrans}):Play()
					end
				end

				task.wait(1)
				spinnerroot.ProximityPrompt.Enabled = not player:GetAttribute("SpinDebounce")
			end
		end
	end)
end

player:GetAttributeChangedSignal("SpinDebounce"):Connect(function()
	update_proximityprompt()
end)

-- Intercepte la commande de lancement du serveur et prépare visuellement les segments
startSpinnerEvent.OnClientEvent:Connect(function()
	player:SetAttribute("SpinDebounce", true)
	wheelState = "Preparing"

	local currentIndex = getSegmentIndex(selectedsegments)
	local maxSegments = #segmentstable
	local leftIndex = currentIndex - 1
	if leftIndex < 1 then leftIndex = maxSegments end
	local rightIndex = currentIndex + 1
	if rightIndex > maxSegments then rightIndex = 1 end

	local allowedIndices = {[currentIndex] = true, [leftIndex] = true, [rightIndex] = true}
	local segmentsToHide = {}

	for _, seg in pairs(segmentstable) do
		local idx = getSegmentIndex(seg)
		if not allowedIndices[idx] then
			table.insert(segmentsToHide, seg)
		end
	end

	local delayPerSegment = 0.5 / math.max(1, #segmentsToHide)
	for _, seg in ipairs(segmentsToHide) do
		transitionSegment(seg, false)
		task.wait(delayPerSegment)
	end

	task.wait(0.1)
	spin() 
end)

task.wait(3)
dartOffset = spinnerroot.CFrame:ToObjectSpace(dart.CFrame)

local closestSpawn = nil
local minDistance = math.huge

for _, spawnPart in ipairs(wheelSpawns:GetChildren()) do
	local dist = (spinnerroot.Position - spawnPart.Position).Magnitude
	if dist < minDistance then
		minDistance = dist
		closestSpawn = spawnPart
	end
end

if minDistance < 15 and closestSpawn then
	lastSpawnPart = currentSpawnValue.Value
else
	local initialSpawn = wheelSpawns:FindFirstChild("ParkingSpawnWheel")
	if not initialSpawn then
		initialSpawn = getRandomSpawnPart()
	end
	moveWheelToSpawn(initialSpawn)
end

update_proximityprompt()

local flottingSound = spinnerroot:FindFirstChild("Flotting")  or spinnermodel:FindFirstChild("Flotting")
if flottingSound then
	flottingSound.Looped = true
	flottingSound.RollOffMaxDistance = 50
	flottingSound.RollOffMinDistance = 1
	flottingSound.Volume = 0 
	flottingSound:Play()
	TS:Create(flottingSound, TweenInfo.new(2, Enum.EasingStyle.Sine), {Volume = 0.25}):Play()
end

for _, desc in ipairs(spinnermodel:GetDescendants()) do
	if desc:IsA("BasePart") then
		originalTransparencies[desc] = desc.Transparency
	elseif desc:IsA("ImageLabel") then
		originalTransparencies[desc] = desc.ImageTransparency
	elseif desc:IsA("TextLabel") then
		originalTransparencies[desc] = desc.TextTransparency
	end
end

for i, v in pairs(segments:GetChildren()) do
	if v.Name ~= "Root" and v:IsA("BasePart") then
		local highlight = assets:WaitForChild("SegmentHighlight"):Clone()
		highlight.Parent = v
		highlight.Enabled = false
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		table.insert(segmentstable, v)
	end
end

applyNewWheelLayout()

local currentFloatAlpha = 1

-- Boucle de rendu frame par frame gérant la cinématique de flottaison (sinusoïdes) et l'analyse de distance du curseur
RunS.Heartbeat:Connect(function(dt)
	local character = player.Character
	if character and character.PrimaryPart then
		local dist = (spinnerroot.Position - character.PrimaryPart.Position).Magnitude
		if dist > 150 and wheelState == "Idle" then
			return
		end
	end

	floatTime += dt
	local timeElapsed = tick() - gameStartTime

	if lastSpawnPart then
		local targetAlpha = 0
		if timeElapsed > startupDelay and wheelState == "Idle" then
			targetAlpha = 1
		end

		currentFloatAlpha = currentFloatAlpha + (targetAlpha - currentFloatAlpha) * 0.1

		local basePos = lastSpawnPart.Position + Vector3.new(0, BASE_HEIGHT, 0)
		local swayValue = math.sin(floatTime * SWAY_SPEED)

		local floatOffset = ((lastSpawnPart.CFrame.RightVector * (swayValue * SWAY_AMPLITUDE)) 
			+ Vector3.new(0, math.sin(floatTime * FLOAT_SPEED) * FLOAT_AMPLITUDE, 0)) * currentFloatAlpha

		local tiltAngle = (math.sin(floatTime * TILT_SPEED) * math.rad(TILT_AMPLITUDE)) * currentFloatAlpha
		local swayTilt = (-swayValue * math.rad(SWAY_TILT_AMPLITUDE)) * currentFloatAlpha

		local baseRotation = lastSpawnPart.CFrame.Rotation * CFrame.Angles(math.rad(90), 0, 0)
		local tiltRotation = CFrame.Angles(0, tiltAngle, swayTilt)

		spinnerroot.CFrame = CFrame.new(basePos + floatOffset) * baseRotation * tiltRotation

		if dartOffset then
			dart.CFrame = spinnerroot.CFrame * dartOffset
		end
	end

	segments:PivotTo(spinnerroot.CFrame * CFrame.Angles(0, math.rad(spinAngle.Value), 0))

	if wheelState == "Spinning" or not selectedsegments then
		local highestSegment = nil
		local minDistance = math.huge 

		for _, segment in pairs(segmentstable) do
			local dist = (segment.Position - dart.Position).Magnitude

			if dist < minDistance then
				minDistance = dist
				highestSegment = segment
			end
		end

		if highestSegment and selectedsegments ~= highestSegment then
			if selectedsegments then
				selectedsegments.SegmentHighlight.Enabled = false
			end
			selectedsegments = highestSegment
			selectedsegments.SegmentHighlight.Enabled = true

			if wheelState == "Spinning" then
				sounds.select:Play()

				local currentIndex = getSegmentIndex(selectedsegments)
				local maxSegments = #segmentstable
				local leftIndex = currentIndex - 1
				if leftIndex < 1 then leftIndex = maxSegments end
				local rightIndex = currentIndex + 1
				if rightIndex > maxSegments then rightIndex = 1 end

				local allowedIndices = {[currentIndex] = true, [leftIndex] = true, [rightIndex] = true}

				for _, seg in pairs(segmentstable) do
					local idx = getSegmentIndex(seg)
					local shouldBeVisible = allowedIndices[idx] or false
					transitionSegment(seg, shouldBeVisible)
				end
			end
		end
	end
end)