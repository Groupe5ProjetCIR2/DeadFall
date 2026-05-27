-- ============================================================
-- Ce script est similaire au script de la porte laser classique
-- Ici il débloque d'autres barrières simultanément.
-- ============================================================

local prompt = script.Parent
local hitbox = prompt.Parent
local modeleBarriere = hitbox
local TweenService = game:GetService("TweenService")

local PRIX_PORTE = hitbox:GetAttribute("Price") or 10
local TEMPS_ANIMATION = 0.8

local PORTES_LIEES = {"PorteLaserJumpPolice1", "PorteLaserJumpPolice2"}

prompt.Style = Enum.ProximityPromptStyle.Custom
prompt.ActionText = "UNLOCK THE DOOR"
prompt.ObjectText = tostring(PRIX_PORTE) .. " $"

-- Écoute l'interaction du joueur, vérifie ses fonds et déclenche l'animation d'ouverture synchronisée sur toutes les portes liées
prompt.Triggered:Connect(function(joueur)
	local statsArgent = joueur:FindFirstChild("leaderstats") and joueur.leaderstats:FindFirstChild("Argent")

	if statsArgent and statsArgent.Value >= PRIX_PORTE then
		statsArgent.Value -= PRIX_PORTE
		prompt.Enabled = false
		hitbox:SetAttribute("isOpen", true)

		local portesAAnimer = {modeleBarriere}
		for _, nomPorte in ipairs(PORTES_LIEES) do
			local porteLiee = workspace:FindFirstChild(nomPorte, true)
			if porteLiee then
				table.insert(portesAAnimer, porteLiee)
			end
		end

		local tweenInfo = TweenInfo.new(TEMPS_ANIMATION, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

		for _, porte in ipairs(portesAAnimer) do
			for _, objet in ipairs(porte:GetDescendants()) do
				if objet:IsA("Beam") then
					local att0 = objet.Attachment0
					local att1 = objet.Attachment1

					-- Calcule le point central entre les deux attaches pour interpoler la réduction visuelle du faisceau laser
					if att0 and att1 then
						local centre = (att0.WorldPosition + att1.WorldPosition) / 2
						TweenService:Create(att0, tweenInfo, {WorldPosition = centre}):Play()
						TweenService:Create(att1, tweenInfo, {WorldPosition = centre}):Play()
					end
				elseif objet:IsA("PointLight") then
					TweenService:Create(objet, tweenInfo, {Brightness = 0}):Play()
				end
			end
		end

		task.wait(TEMPS_ANIMATION)

		-- Purge les propriétés physiques et rend les éléments invisibles une fois l'animation de rétractation terminée
		for _, porte in ipairs(portesAAnimer) do
			if porte:IsA("BasePart") then
				porte.Transparency = 1
				porte.CanCollide = false
			end

			for _, objet in ipairs(porte:GetDescendants()) do
				if objet:IsA("BasePart") then
					objet.Transparency = 1
					objet.CanCollide = false
				elseif objet:IsA("Beam") or objet:IsA("PointLight") then
					objet.Enabled = false
				elseif objet:IsA("Texture") or objet:IsA("Decal") then
					objet.Transparency = 1
				end
			end
		end

	else
		local ancienAction = prompt.ActionText
		local ancienObject = prompt.ObjectText

		prompt.ActionText = "Not enough money!"
		prompt.ObjectText = ""

		task.wait(1.5)

		prompt.ActionText = ancienAction
		prompt.ObjectText = ancienObject
		prompt.Enabled = true
	end
end)