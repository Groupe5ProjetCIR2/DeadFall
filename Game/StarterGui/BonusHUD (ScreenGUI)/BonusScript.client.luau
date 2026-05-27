-- ============================================================
-- Ce script (BonusScript) gère l'affichage des icônes de power-ups.
-- Placé dans l'interface "BonusHUD", il manipule deux conteneurs (Frames) :
-- "Frame_x2" (Double Argent) et "Frame_Insta" (Insta-Kill).
-- Ces Frames servent de boîtes de positionnement, permettant de déplacer 
-- fluidement les icônes à l'écran sans déformer les images à l'intérieur.
-- ============================================================

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local doubleArgentValue = ReplicatedStorage:WaitForChild("DoubleArgentActif")
local instaKillValue = ReplicatedStorage:WaitForChild("InstaKillActif")

-- Récupération des Frames au même niveau que le script.
-- Chaque Frame contient un ImageLabel (l'icône visuelle du bonus).
local frameX2 = script.Parent:WaitForChild("Frame_x2")
local imgX2 = frameX2:WaitForChild("ImageLabel")

local frameInsta = script.Parent:WaitForChild("Frame_Insta")
local imgInsta = frameInsta:WaitForChild("ImageLabel")

-- Force l'invisibilité des icônes au lancement
imgX2.ImageTransparency = 1
imgInsta.ImageTransparency = 1

local tweenFade = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenMove = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- L'écartement en pixels quand les deux bonus sont actifs simultanément
local ECARTEMENT = 30 

-- MISE À JOUR DE L'AFFICHAGE
local function actualiserHUD()
	local x2Actif = doubleArgentValue.Value
	local instaActif = instaKillValue.Value

	-- Gestion des fondus d'apparition et de disparition des images
	TweenService:Create(imgX2, tweenFade, {ImageTransparency = x2Actif and 0 or 1}):Play()
	TweenService:Create(imgInsta, tweenFade, {ImageTransparency = instaActif and 0 or 1}):Play()

	-- Gestion des positions avec glissement fluide des Frames entières
	if x2Actif and instaActif then
		-- Les deux sont actifs : on écarte les Frames de part et d'autre du centre
		TweenService:Create(frameX2, tweenMove, {Position = UDim2.new(0.5, -ECARTEMENT, 0, 5)}):Play()
		TweenService:Create(frameInsta, tweenMove, {Position = UDim2.new(0.5, ECARTEMENT, 0, 5)}):Play()

	elseif x2Actif then
		-- Seul le X2 est actif : sa Frame revient parfaitement au centre
		TweenService:Create(frameX2, tweenMove, {Position = UDim2.new(0.5, 0, 0, 5)}):Play()

	elseif instaActif then
		-- Seul l'Insta-Kill est actif : sa Frame revient parfaitement au centre
		TweenService:Create(frameInsta, tweenMove, {Position = UDim2.new(0.5, 0, 0, 5)}):Play()
	end
end

-- ÉCOUTE DES CHANGEMENTS
doubleArgentValue.Changed:Connect(actualiserHUD)
instaKillValue.Changed:Connect(actualiserHUD)

-- Initialisation de l'affichage au démarrage
actualiserHUD()