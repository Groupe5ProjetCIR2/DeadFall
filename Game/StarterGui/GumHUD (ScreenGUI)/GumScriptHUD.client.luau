-- ============================================================
-- Ce script (GumScriptHUD) gère l'affichage des atouts (Gums) à l'écran.
-- Il est placé dans l'interface "GumHUD" au même niveau que "GumContainer".
-- Le "GumContainer" est une Frame qui sert de boîte de rangement visuelle : 
-- elle permet d'aligner et de regrouper les icônes des atouts obtenus par le joueur.
-- Ce script gère l'ajout d'icônes avec une animation, le nettoyage de l'interface 
-- lors d'une mort, et l'effet visuel spécifique de la réanimation (Phoenix Pop).
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local giveGumEvent = ReplicatedStorage:WaitForChild("GiveGumEvent")
local container = script.Parent:WaitForChild("GumContainer")
local gumTemplate = ReplicatedStorage:WaitForChild("GumTemplate")

local PhoenixEffectEvent = ReplicatedStorage:WaitForChild("PhoenixEffectEvent")
local SoundService = game:GetService("SoundService")

-- TABLE DES ATOUTS
-- Associe le nom de chaque atout à l'ID de son image correspondante
local gumImages = {
	["BouncyBubble"] = "rbxassetid://112789725463863",
	["TitanJawbreaker"] = "rbxassetid://120200775052920",
	["PhoenixPop"] = "rbxassetid://120859962015522",
	["MedicMix"] = "rbxassetid://83821234663487",
	["SonicMint"] = "rbxassetid://104718962850064"
}

-- AJOUT D'UN ATOUT
-- Reçoit l'ordre du serveur d'afficher un nouvel atout dans le GumContainer
giveGumEvent.OnClientEvent:Connect(function(gumName)
	print("Le client a bien reçu le signal pour afficher :", gumName)

	-- Empêche la création d'une icône en double si le joueur possède déjà l'atout
	if container:FindFirstChild(gumName) then return end

	-- Vérifie que l'atout existe bien dans la liste avant de continuer
	local imageId = gumImages[gumName]
	if not imageId then return end

	-- Crée l'icône à partir du modèle (Template) stocké dans le ReplicatedStorage
	local newGumIcon = gumTemplate:Clone()
	newGumIcon.Name = gumName
	newGumIcon.Image = imageId

	-- Prépare l'animation d'apparition "pop" en initialisant la taille à 0
	local finalSize = newGumIcon.Size
	newGumIcon.Size = UDim2.new(0, 0, 0, 0)
	newGumIcon.Parent = container

	-- Anime la taille de 0 à la taille finale avec un effet de rebond (Back)
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(newGumIcon, tweenInfo, {Size = finalSize}):Play()
end)


local clearGumsEvent = ReplicatedStorage:WaitForChild("ClearAllGums")

-- NETTOYAGE DES ATOUTS
-- Déclenché quand le joueur tombe KO ou consomme un Phoenix Pop
clearGumsEvent.OnClientEvent:Connect(function()
	-- Parcourt le GumContainer et supprime tous les éléments visuels qu'il contient
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ImageLabel") or child:IsA("Frame") then
			child:Destroy()
		end
	end
end)


-- EFFET PHOENIX POP
-- Gère le flash visuel et sonore lors de la réanimation automatique
PhoenixEffectEvent.OnClientEvent:Connect(function()

	local sonPhoenix = SoundService:FindFirstChild("PhoenixPopSound")
	if sonPhoenix then
		sonPhoenix:Play()
	end

	-- Génère un écran coloré (cyan) qui recouvre toute l'interface
	local flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.new(1, 0, 1, 0)
	flashFrame.Position = UDim2.new(0, 0, 0, 0)
	flashFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 255) 
	flashFrame.BorderSizePixel = 0
	flashFrame.BackgroundTransparency = 1
	flashFrame.ZIndex = 100 

	local gui = script:FindFirstAncestorOfClass("ScreenGui")
	if gui then flashFrame.Parent = gui end

	-- Séquence d'animation : apparition très rapide suivie d'une dissipation lente
	local tweenIn = TweenService:Create(flashFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
	local tweenOut = TweenService:Create(flashFrame, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 1})

	tweenIn:Play() 

	-- Enchaîne la disparition dès que le flash est à son maximum
	tweenIn.Completed:Connect(function()
		tweenOut:Play() 
	end)

	-- Détruit le composant une fois l'effet terminé pour libérer la mémoire
	tweenOut.Completed:Connect(function()
		flashFrame:Destroy() 
	end)
end)