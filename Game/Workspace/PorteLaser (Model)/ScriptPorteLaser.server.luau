-- ============================================================
--  Ce script permet d’ouvrir une barrière via un
--  ProximityPrompt avec vérification de l’argent du joueur,
--  animation des effets visuels et désactivation des collisions.
-- ============================================================

local prompt = script.Parent
local hitbox = prompt.Parent
local modeleBarriere = hitbox

local TweenService = game:GetService("TweenService")

local PRIX_PORTE = hitbox:GetAttribute("Price") or 10
local TEMPS_ANIMATION = 0.8

prompt.Style = Enum.ProximityPromptStyle.Custom
prompt.ActionText = "UNLOCK THE DOOR"
prompt.ObjectText = tostring(PRIX_PORTE) .. " $"

-- Gestion de l'interaction avec le ProximityPrompt
prompt.Triggered:Connect(function(joueur)

	-- Récupération des statistiques d'argent du joueur
	local statsArgent = joueur:FindFirstChild("leaderstats")
		and joueur.leaderstats:FindFirstChild("Argent")

	-- Vérifie si le joueur possède assez d'argent
	if statsArgent and statsArgent.Value >= PRIX_PORTE then
		statsArgent.Value -= PRIX_PORTE

		prompt.Enabled = false
		hitbox:SetAttribute("isOpen", true)

		-- Création des paramètres d'animation
		local tweenInfo = TweenInfo.new(
			TEMPS_ANIMATION,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out
		)

		-- Animation des effets visuels présents dans la barrière
		for _, objet in ipairs(modeleBarriere:GetDescendants()) do

			-- Réduction progressive des Beams vers leur centre
			if objet:IsA("Beam") then
				local att0 = objet.Attachment0
				local att1 = objet.Attachment1

				if att0 and att1 then
					local centre = (att0.WorldPosition + att1.WorldPosition) / 2

					TweenService:Create(att0, tweenInfo, {
						WorldPosition = centre
					}):Play()

					TweenService:Create(att1, tweenInfo, {
						WorldPosition = centre
					}):Play()
				end

				-- Extinction progressive des lumières
			elseif objet:IsA("PointLight") then
				TweenService:Create(objet, tweenInfo, {
					Brightness = 0
				}):Play()
			end
		end

		task.wait(TEMPS_ANIMATION)

		-- Désactivation de la hitbox principale
		if modeleBarriere:IsA("BasePart") then
			modeleBarriere.Transparency = 1
			modeleBarriere.CanCollide = false
		end

		-- Désactivation complète des collisions et effets visuels
		for _, objet in ipairs(modeleBarriere:GetDescendants()) do

			if objet:IsA("BasePart") then
				objet.Transparency = 1
				objet.CanCollide = false

			elseif objet:IsA("Beam") or objet:IsA("PointLight") then
				objet.Enabled = false

			elseif objet:IsA("Texture") or objet:IsA("Decal") then
				objet.Transparency = 1
			end
		end

	else

		-- Affichage temporaire d'un message si le joueur manque d'argent
		local ancienAction = prompt.ActionText
		local ancienObject = prompt.ObjectText

		prompt.ActionText = "Not enough money!"
		prompt.ObjectText = ""

		task.wait(1.5)

		-- Restauration du texte d'origine du prompt
		prompt.ActionText = ancienAction
		prompt.ObjectText = ancienObject
		prompt.Enabled = true
	end
end)