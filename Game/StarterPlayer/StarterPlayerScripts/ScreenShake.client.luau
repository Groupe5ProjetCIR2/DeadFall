-- ============================================================
--  Ce script crée un effet de tremblement de caméra (camera shake) 
--  lorsque le joueur subit des dégâts. Il calcule dynamiquement 
--  l'intensité en fonction des dégâts et gère l'atténuation de la secousse.
-- ============================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local DAMAGE_DIVIDER = 5
local DECAY_RATE = 5
local FREQUENCY = 20

local shaking = false
local amplitude = 0
local timeElapsed = 0

local globalTime = 0

-- Initialise les variables d'état pour déclencher le tremblement de la caméra
local function startShake(power)
	shaking = true
	amplitude = power
	timeElapsed = 0
end

-- Boucle de rendu frame-par-frame pour appliquer dynamiquement les rotations à la caméra
RunService.RenderStepped:Connect(function(dt)
	globalTime += dt

	if not shaking then return end

	timeElapsed += dt

	-- Calcule l'atténuation exponentielle de la secousse au fil du temps
	local decay = math.exp(-DECAY_RATE * timeElapsed)
	local currentAmplitude = amplitude * decay

	if currentAmplitude < 0.01 then
		shaking = false
		return
	end

	-- Génère des oscillations lissées basées sur le temps cumulé
	local angleX = math.sin(globalTime * FREQUENCY) * currentAmplitude
	local angleY = math.cos(globalTime * FREQUENCY * 0.9) * currentAmplitude

	local rotation = CFrame.Angles(math.rad(angleX), math.rad(angleY), 0)

	camera.CFrame = camera.CFrame * rotation
end)

-- Initialise la surveillance du joueur à son apparition
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	local lastHealth = humanoid.Health

	-- Écoute les changements de santé du joueur pour détecter les dégâts subis
	humanoid.HealthChanged:Connect(function(newHealth)
		if newHealth < lastHealth then
			local damage = lastHealth - newHealth

			-- Restreint la puissance du tremblement entre 1 et 5 pour éviter des mouvements extrêmes
			local shakePower = damage / DAMAGE_DIVIDER
			if shakePower < 1 then shakePower = 1 end
			if shakePower > 5 then shakePower = 5 end

			startShake(shakePower)
		end
		lastHealth = newHealth
	end)
end

if player.Character then
	onCharacterAdded(player.Character)
end

player.CharacterAdded:Connect(onCharacterAdded)