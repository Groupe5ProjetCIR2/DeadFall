-- ============================================================
--  Ce script a pour but de gérer l'affichage des effets 
--  visuels (VFX) lorsqu'un joueur subit des dégâts. Il fait 
--  apparaître l'effet "smack" instantanément sur l'écran du 
--  joueur touché, puis communique avec le serveur pour que 
--  l'effet soit également visible par tous les autres joueurs.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local damageEvent = ReplicatedStorage:WaitForChild("DamageVFXEvent")

-- Clone, positionne et joue le modèle VFX sur le personnage du joueur local
local function spawnVFX(character)
	local vfxFolder = Workspace:FindFirstChild("VFX")
	if not vfxFolder then return end

	local smack = vfxFolder:FindFirstChild("smack")
	if not smack then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local clone = smack:Clone()
	clone.Parent = Workspace

	if clone:IsA("BasePart") then
		clone.CFrame = rootPart.CFrame
		clone.Transparency = 1
		clone.CanCollide = false
		clone.Anchored = true
	else
		clone:PivotTo(rootPart.CFrame)
	end

	-- Utilisation de la récursivité pour trouver et activer tous les ParticleEmitters imbriqués
	local function emitParticles(obj)
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = true
			obj:Emit(1)
		end
		for _, child in pairs(obj:GetChildren()) do
			emitParticles(child)
		end
	end
	emitParticles(clone)

	task.delay(0.25, function()
		clone:Destroy()
	end)
end

-- Surveille la vie du joueur pour détecter une perte de points de vie et déclencher le VFX
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	local lastHealth = humanoid.Health

	humanoid.HealthChanged:Connect(function(currentHealth)
		if currentHealth < lastHealth then
			spawnVFX(character)
			damageEvent:FireServer()
		end
		lastHealth = currentHealth
	end)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

local vfxForOthersEvent = ReplicatedStorage:WaitForChild("VFXForOthersEvent")

-- S'exécute quand le serveur signale qu'un autre joueur a pris des dégâts pour afficher son propre VFX
vfxForOthersEvent.OnClientEvent:Connect(function(position, lookVector)
	local vfxFolder = Workspace:FindFirstChild("VFX")
	if not vfxFolder then return end

	local smack = vfxFolder:FindFirstChild("smack")
	if not smack then return end

	local clone = smack:Clone()
	clone.Parent = Workspace

	local spawnPos = position
	local cframe = CFrame.new(spawnPos)

	if clone:IsA("BasePart") then
		clone.CFrame = cframe
		clone.Transparency = 1
		clone.CanCollide = false
		clone.Anchored = true
	else
		clone:PivotTo(cframe)
	end

	local function emitParticles(obj)
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = true
			obj:Emit(1)
		end
		for _, child in pairs(obj:GetChildren()) do
			emitParticles(child)
		end
	end
	emitParticles(clone)

	task.delay(0.25, function()
		clone:Destroy()
	end)
end)