-- ============================================================
--  Ce script gère la santé du joueur, incluant une régénération 
--  passive, un effet sonore de battements de cœur et une mécanique d'invincibilité.
--  Il intègre également un système de soin rapide déclenché 
--  par un RemoteEvent qui surpasse le délai de guérison standard.
-- ============================================================

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

local healEvent = ReplicatedStorage:FindFirstChild("SyringeHealEvent")
if not healEvent then
	healEvent = Instance.new("RemoteEvent")
	healEvent.Name = "SyringeHealEvent"
	healEvent.Parent = ReplicatedStorage
end

local isSyringeHealing = false

-- Intercepte le déclenchement de la seringue pour forcer la régénération accélérée du personnage
healEvent.OnServerEvent:Connect(function(player)
	if player.Character == character then
		isSyringeHealing = true
	end
end)

local sonCoeur = SoundService:WaitForChild("fastcoeur")

if not sonCoeur.IsLoaded then
	sonCoeur.Loaded:Wait()
end

local volumeMax = sonCoeur.Volume 
local vitesseOriginale = sonCoeur.PlaybackSpeed
sonCoeur.Looped = true
local tweenFondu = nil 

local TEMPS_REGEN_MAX = 10      
local DELAI_AVANT_REGEN = 10    
local TEMPS_IMMUNITE = 1

local tempsDernierDegat = 0
local viePrecedente = humanoid.Health
local estImmunise = false       

-- Module le volume et la vitesse de lecture du son de cœur en fonction des seuils critiques de santé
humanoid.HealthChanged:Connect(function(nouvelleVie)
	if nouvelleVie > 0 and nouvelleVie < 50 then
		if tweenFondu then
			tweenFondu:Cancel()
			tweenFondu = nil
		end

		if not sonCoeur.IsPlaying then
			sonCoeur.Volume = volumeMax
			sonCoeur.PlaybackSpeed = vitesseOriginale

			local tempsMaxDepart = math.max(0, sonCoeur.TimeLength - 15)

			sonCoeur.TimePosition = math.random() * tempsMaxDepart
			sonCoeur:Play()
		else
			sonCoeur.Volume = volumeMax 
			sonCoeur.PlaybackSpeed = vitesseOriginale
		end

	elseif nouvelleVie >= 50 or nouvelleVie <= 0 then
		if sonCoeur.IsPlaying and not tweenFondu then
			local infoFondu = TweenInfo.new(1, Enum.EasingStyle.Linear)
			tweenFondu = TweenService:Create(sonCoeur, infoFondu, {
				Volume = 0, 
				PlaybackSpeed = 0.25
			})

			tweenFondu.Completed:Connect(function(etat)
				if etat == Enum.PlaybackState.Completed then
					sonCoeur:Stop()
					tweenFondu = nil
				end
			end)

			tweenFondu:Play()
		end
	end
end)

character:SetAttribute("EstImmunise", false)

-- Gère le délai d'invulnérabilité (i-frames) de manière asynchrone pour éviter les dégâts consécutifs rapides
character:GetAttributeChangedSignal("EstImmunise"):Connect(function()
	if character:GetAttribute("EstImmunise") == true then
		task.delay(TEMPS_IMMUNITE, function()
			if character and humanoid.Health > 0 then
				character:SetAttribute("EstImmunise", false)
			end
		end)
	end
end)

-- Met à jour les chronomètres de régénération lors de la réception de dégâts effectifs
humanoid.HealthChanged:Connect(function(nouvelleVie)
	if nouvelleVie < viePrecedente then
		tempsDernierDegat = os.clock()

		if character:GetAttribute("EstImmunise") == false then
			character:SetAttribute("EstImmunise", true)
		end
	end
	viePrecedente = humanoid.Health
end)

-- Boucle de calcul de la santé, appliquant une interpolation de guérison standard ou un multiplicateur de seringue
RunService.Heartbeat:Connect(function(deltaTime)
	if humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then

		if isSyringeHealing then
			local soinParSeconde = (humanoid.MaxHealth / TEMPS_REGEN_MAX) * 10
			local nouveauSoin = humanoid.Health + (soinParSeconde * deltaTime)
			humanoid.Health = math.min(humanoid.MaxHealth, nouveauSoin)

			if humanoid.Health >= humanoid.MaxHealth then
				isSyringeHealing = false
			end

		elseif (os.clock() - tempsDernierDegat) >= DELAI_AVANT_REGEN then
			local soinParSeconde = humanoid.MaxHealth / TEMPS_REGEN_MAX
			local nouveauSoin = humanoid.Health + (soinParSeconde * deltaTime)
			humanoid.Health = math.min(humanoid.MaxHealth, nouveauSoin)
		end

	else
		isSyringeHealing = false
	end
end)