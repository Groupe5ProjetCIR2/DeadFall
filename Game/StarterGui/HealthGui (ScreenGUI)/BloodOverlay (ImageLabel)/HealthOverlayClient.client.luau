-- ============================================================
-- Ce script (HealthOverlayClient) gère l'effet de sang à l'écran.
-- Il est placé en tant qu'enfant de l'ImageLabel "BloodOverlay".
-- L'opacité du sang augmente au fur et à mesure que le joueur perd 
-- de la vie, et devient totalement visible s'il tombe à terre.
-- ============================================================

local plr = game.Players.LocalPlayer
local character = plr.Character or plr.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local TweenService = game:GetService("TweenService")

-- Le script étant dans l'ImageLabel, on cible directement son parent
local bloodOverlay = script.Parent

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpectateEvent = ReplicatedStorage:WaitForChild("StartSpectate")

-- Masque l'effet de sang avec un fondu lorsque le joueur passe en mode spectateur
SpectateEvent.OnClientEvent:Connect(function()
	TweenService:Create(bloodOverlay, TweenInfo.new(0.5), {ImageTransparency = 1}):Play()
end)

-- MISE À JOUR DE L'EFFET DE SANG
-- Calcule la transparence de l'image en fonction de la santé ou de l'état du joueur
local function updateOverlay()
	local char = plr.Character
	if not char then return end

	local hum = char:FindFirstChild("Humanoid")
	local isDowned = char:GetAttribute("IsDowned")
	local targetTransparency = 1

	if isDowned then
		-- Le joueur est à terre : le sang est totalement visible (0)
		targetTransparency = 0
	elseif hum then
		-- La transparence s'adapte à la vie restante (ex: 100 HP = 1 invisible, 50 HP = 0.5 mi-visible)
		targetTransparency = math.clamp(hum.Health / 100, 0, 1)
	end

	-- Applique le changement avec une transition fluide
	TweenService:Create(bloodOverlay, TweenInfo.new(0.3), {ImageTransparency = targetTransparency}):Play()
end

-- INITIALISATION DU PERSONNAGE
-- Lie la mise à jour visuelle aux variations de vie et au statut "à terre"
local function setupCharacter(char)
	local hum = char:WaitForChild("Humanoid")

	hum.HealthChanged:Connect(updateOverlay)
	char:GetAttributeChangedSignal("IsDowned"):Connect(updateOverlay)

	updateOverlay()
end

plr.CharacterAdded:Connect(setupCharacter)
if plr.Character then setupCharacter(plr.Character) end