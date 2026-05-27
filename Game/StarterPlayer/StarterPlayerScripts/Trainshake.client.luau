-- ============================================================
--  Ce script simule un tremblement de caméra (camera shake) 
--  lorsque le joueur se trouve à proximité d'un train. L'intensité 
--  de la secousse est calculée dynamiquement et s'amplifie 
--  au fur et à mesure que le joueur se rapproche de la source.
-- ============================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local trainPasser = workspace:WaitForChild("TrainPasser")
local train = trainPasser:WaitForChild("Train")

local SHAKE_DISTANCE = 120 
local MAX_INTENSITY = 0.02 

-- Boucle de rendu frame-par-frame pour vérifier en continu la position du joueur par rapport au train
RunService.RenderStepped:Connect(function()
	if not train.PrimaryPart then return end

	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local distance = (train.PrimaryPart.Position - rootPart.Position).Magnitude

	-- Calcule un ratio d'intensité inversé basé sur la distance, puis applique des angles de secousse aléatoires
	if distance < SHAKE_DISTANCE then
		local ratio = 1 - (distance / SHAKE_DISTANCE)
		local currentIntensity = MAX_INTENSITY * ratio

		local shakeX = (math.random() - 0.5) * currentIntensity
		local shakeY = (math.random() - 0.5) * currentIntensity
		local shakeZ = (math.random() - 0.5) * currentIntensity

		camera.CFrame = camera.CFrame * CFrame.Angles(shakeX, shakeY, shakeZ)
	end
end)