-- ============================================================
--  Ce script gère la lecture aléatoire de sons d'ambiance lointains
--  autour du joueur pour renforcer l'immersion. Il positionne 
--  dynamiquement les sources audio à grande distance et applique des 
--  filtres (égaliseur, réverbération) ainsi qu'un fondu en fermeture.
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local DISTANT_SOUNDS = {
	"rbxassetid://114860634353331",
	"rbxassetid://112638152510385",
	"rbxassetid://137610556129147",
	"rbxassetid://92773048044849",
}

local DELAI_MIN = 20 
local DELAI_MAX = 30  
local DISTANCE_SPAWN = 2000 

local player = Players.LocalPlayer
local lastSoundId = nil

-- Lance une boucle asynchrone infinie pour générer les événements sonores à intervalles aléatoires
task.spawn(function()
	while true do
		task.wait(math.random(DELAI_MIN, DELAI_MAX))

		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end

		local randomSoundId
		if #DISTANT_SOUNDS > 1 then
			repeat
				randomSoundId = DISTANT_SOUNDS[math.random(1, #DISTANT_SOUNDS)]
			until randomSoundId ~= lastSoundId
		else
			randomSoundId = DISTANT_SOUNDS[1]
		end
		lastSoundId = randomSoundId

		-- Calcule des coordonnées polaires aléatoires pour placer le son en arc de cercle autour du joueur
		local angle = math.random() * math.pi * 2
		local offsetX = math.cos(angle) * DISTANCE_SPAWN
		local offsetZ = math.sin(angle) * DISTANCE_SPAWN
		local soundPos = hrp.Position + Vector3.new(offsetX, 50, offsetZ) 

		local emitter = Instance.new("Attachment")
		emitter.WorldPosition = soundPos
		emitter.Parent = workspace.Terrain

		local sound = Instance.new("Sound")
		sound.SoundId = randomSoundId
		sound.Volume = 2
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound.RollOffMaxDistance = DISTANCE_SPAWN * 1.5 
		sound.RollOffMinDistance = 10 

		-- Ajoute des filtres pour étouffer les hautes fréquences et simuler l'absorption atmosphérique due à la distance
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = -80
		eq.MidGain = -50
		eq.LowGain = 0
		eq.Parent = sound

		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime = 2.5
		reverb.Density = 1
		reverb.DryLevel = -20
		reverb.WetLevel = 5
		reverb.Parent = sound

		sound.Parent = emitter

		-- Mécanisme de sécurité (timeout) pour éviter de jouer un son qui n'a pas fini de se télécharger côté client
		if not sound.IsLoaded then
			local timeout = 0
			while not sound.IsLoaded and timeout < 30 do 
				task.wait(0.1)
				timeout += 1
			end

			if not sound.IsLoaded then
				emitter:Destroy()
				continue 
			end
		end

		sound:Play()

		local endedConnection
		endedConnection = sound.Ended:Connect(function()
			if endedConnection then endedConnection:Disconnect() end
			if emitter.Parent then emitter:Destroy() end
		end)

		-- Force un fondu (fade-out) après 6.5 secondes pour éviter des coupures audio brutales avant la fin réelle
		task.delay(6.5, function()
			if sound.Parent and sound.IsPlaying then
				local fadeOutInfo = TweenInfo.new(1.5, Enum.EasingStyle.Linear)
				local fadeOut = TweenService:Create(sound, fadeOutInfo, {Volume = 0})

				fadeOut:Play()
				fadeOut.Completed:Wait()

				sound:Stop()
				if endedConnection then endedConnection:Disconnect() end
				if emitter.Parent then emitter:Destroy() end
			end
		end)
	end
end)