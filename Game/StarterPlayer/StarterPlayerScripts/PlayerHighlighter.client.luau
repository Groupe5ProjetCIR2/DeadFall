-- ============================================================
--  Ce script a pour but d'afficher une surbrillance (Highlight) 
--  autour des autres joueurs pour les voir à travers les murs. 
--  Il récupère dynamiquement la couleur assignée à chaque joueur 
--  via un attribut et met à jour l'effet visuel en temps réel 
--  si cette couleur vient à changer.
-- ============================================================

local client = game.Players.LocalPlayer

local configuration = {
	USE_CUSTOM_COLOURS = true, 

	ALLY_FILL_TRANSPARENCY = 0.95, 
	ALLY_OUTLINE_TRANSPARENCY = 0, 
}

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)

-- Récupère la couleur personnalisée attribuée au joueur via ses attributs ou applique une couleur par défaut
local function getPlayerColor(plr)
	local tabColor = plr:GetAttribute("TabColor")
	if tabColor then
		return tabColor
	else
		return DEFAULT_COLOR
	end
end

-- Configure l'objet Highlight pour qu'il soit visible à travers les murs (AlwaysOnTop) et lui applique les couleurs
local function handleHighlight(highlightObject, plr)
	highlightObject.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

	highlightObject.FillTransparency = configuration.ALLY_FILL_TRANSPARENCY
	highlightObject.OutlineTransparency = configuration.ALLY_OUTLINE_TRANSPARENCY

	if configuration.USE_CUSTOM_COLOURS then
		local playerColor = getPlayerColor(plr)
		highlightObject.FillColor = playerColor
		highlightObject.OutlineColor = playerColor
	end
end

-- Crée, attache ou met à jour l'objet Highlight directement sur le modèle 3D du personnage
local function handleChar(plr)
	local char = plr.Character or plr.CharacterAdded:Wait()

	local highlightObject = char:FindFirstChild("TEAM HIGHLIGHTER") or Instance.new("Highlight")
	highlightObject.Name = "TEAM HIGHLIGHTER"

	handleHighlight(highlightObject, plr)

	highlightObject.Parent = char
end

-- Gère les événements liés au joueur, comme l'apparition de son personnage et le changement en direct de sa couleur
local function handlePlr(plr)
	-- Empêche le joueur local d'avoir un Highlight visible sur son propre écran
	if plr == client then return end

	if plr.Character then
		handleChar(plr)
	end

	plr.CharacterAdded:Connect(function(char)
		task.wait(0.1) 
		handleChar(plr)
	end)

	-- Écoute activement les modifications de l'attribut de couleur pour rafraîchir l'affichage instantanément
	plr:GetAttributeChangedSignal("TabColor"):Connect(function()
		if plr.Character then
			handleChar(plr)
		end
	end)
end

game.Players.PlayerAdded:Connect(handlePlr)

-- Lance le traitement pour tous les joueurs déjà connectés via un thread séparé (task.spawn) pour ne pas bloquer le script
for _, plr in pairs(game.Players:GetPlayers()) do
	task.spawn(function()
		handlePlr(plr)
	end)
end