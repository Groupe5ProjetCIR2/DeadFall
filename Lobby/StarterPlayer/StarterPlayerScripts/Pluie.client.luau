-- ============================================================
--  Ce script gère dynamiquement le rendu sonore de la pluie 
--  selon que le joueur est à l'intérieur ou à l'extérieur.
--  Il utilise des raycasts verticaux pour détecter les 
--  obstructions au-dessus de la caméra et ajuste les volumes 
--  via des tweens pour une transition fluide.
-- ============================================================

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local camera = workspace.CurrentCamera
local player = Players.LocalPlayer

-- Initialisation des ressources sonores
local pluieExt = SoundService:WaitForChild("PluieExterieur")
local pluieInt = SoundService:WaitForChild("PluieInterieur")

local RAY_DISTANCE = 150 
local TWEEN_TIME = 1.2 

-- Préparation des flux audio
pluieExt.Volume = 0
pluieInt.Volume = 0
pluieExt.Playing = true
pluieInt.Playing = true

-- Fonction de détection d'abri via raycast
local function isUnderCover()
	local raycastParams = RaycastParams.new()
	local char = player.Character
	if char then
		raycastParams.FilterDescendantsInstances = {char}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	end

	local result = workspace:Raycast(camera.CFrame.Position, Vector3.new(0, RAY_DISTANCE, 0), raycastParams)
	return result ~= nil
end

-- Lancement progressif de l'ambiance lors de l'activation cinématique
task.spawn(function()
	while not _G.CinematicActive do 
		task.wait(0.1) 
	end
	TweenService:Create(pluieExt, TweenInfo.new(3), {Volume = 0.5}):Play()
end)

-- Boucle de mise à jour des volumes selon l'exposition
RunService.Heartbeat:Connect(function()
	if not _G.CinematicActive then return end

	local covered = isUnderCover()

	if covered then
		TweenService:Create(pluieExt, TweenInfo.new(TWEEN_TIME), {Volume = 0.05}):Play()
		TweenService:Create(pluieInt, TweenInfo.new(TWEEN_TIME), {Volume = 0.4}):Play()
	else
		TweenService:Create(pluieExt, TweenInfo.new(TWEEN_TIME), {Volume = 0.4}):Play()
		TweenService:Create(pluieInt, TweenInfo.new(TWEEN_TIME), {Volume = 0}):Play()
	end
end)