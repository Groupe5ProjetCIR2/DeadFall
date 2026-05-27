-- ============================================================
-- Ce script gère le déplacement fluide d'un train composé de plusieurs wagons le long d'un chemin prédéfini. 
-- Il utilise une interpolation linéaire (Lerp) synchronisée avec le TweenService pour animer la progression du convoi de manière continue.
-- ============================================================

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local trainPasser = workspace:WaitForChild("TrainPasser")
local train = trainPasser:WaitForChild("Train")
local sound = train:FindFirstChild("Sound", true)

local VITESSE_TRAIN = 250
local TEMPS_ATTENTE = 90

-- Purge des Motor6D existants pour s'assurer que le script a le contrôle total des positions sans interférence du moteur physique
for _, descendant in ipairs(train:GetDescendants()) do
	if descendant:IsA("Motor6D") then
		descendant:Destroy()
	end
end

local points = {}
for i = 1, 10 do
	local p = trainPasser:FindFirstChild("point" .. i) or train:FindFirstChild("point" .. i)
	if p then table.insert(points, p) end
end

local nomsWagons = {
	{nom = "HumanoidRootPart", offset = 0},
	{nom = "Head", offset = 0},
	{nom = "Neck", offset = 15},
	{nom = "Torso", offset = 30},
	{nom = "Tail1", offset = 45},
	{nom = "Tail2", offset = 60}
}

-- Référencement des parties du train avec leur espacement (offset) respectif et ancrage forcé
local wagons = {}
for _, info in ipairs(nomsWagons) do
	local morceau = train:FindFirstChild(info.nom, true)
	if morceau and (morceau:IsA("BasePart") or morceau:IsA("Model")) then
		table.insert(wagons, {modele = morceau, offset = info.offset})
		if morceau:IsA("BasePart") then
			morceau.Anchored = true
		end
	end
end

local segmentsPath = {}
local distanceTotale = 0

-- Précalcul des segments spatiaux et des distances cumulées pour optimiser les requêtes de positionnement
for i = 1, #points - 1 do
	local pointDepart = points[i]
	local pointArrivee = points[i+1]
	local distanceEntrePoints = (pointDepart.Position - pointArrivee.Position).Magnitude

	table.insert(segmentsPath, {
		debutDist = distanceTotale,
		finDist = distanceTotale + distanceEntrePoints,
		cframe1 = pointDepart.CFrame,
		cframe2 = pointArrivee.CFrame
	})

	distanceTotale = distanceTotale + distanceEntrePoints
end

-- Détermine le CFrame (position et rotation) exact sur le parcours en fonction d'une distance parcourue donnée
local function getCFrameADistance(d)
	if d <= 0 then 
		return segmentsPath[1].cframe1 * CFrame.new(0, 0, math.abs(d))
	end

	if d >= distanceTotale then 
		return segmentsPath[#segmentsPath].cframe2 
	end

	for _, segment in ipairs(segmentsPath) do
		if d >= segment.debutDist and d <= segment.finDist then
			local progression = (d - segment.debutDist) / (segment.finDist - segment.debutDist)
			return segment.cframe1:Lerp(segment.cframe2, progression)
		end
	end
	return segmentsPath[1].cframe1
end

local progressionTrajet = Instance.new("NumberValue")
progressionTrajet.Value = 0

-- Boucle de rendu qui met à jour visuellement la position de chaque wagon selon la progression en cours
local connectionAnimation = RunService.Heartbeat:Connect(function()
	for _, wagon in ipairs(wagons) do
		local distanceWagonActuelle = progressionTrajet.Value - wagon.offset
		local nouveauCFrame = getCFrameADistance(distanceWagonActuelle)

		if wagon.modele:IsA("Model") or wagon.modele:IsA("BasePart") then
			wagon.modele:PivotTo(nouveauCFrame)
		end
	end
end)

task.wait(15)

-- Cycle infini gérant l'animation du trajet (Tween), le masquage des wagons à l'arrivée et le temps de recharge
while true do
	progressionTrajet.Value = 0
	if sound then sound.Playing = true end

	local distanceCible = distanceTotale + (wagons[#wagons] and wagons[#wagons].offset or 60)
	local tempsTrajetCalcule = distanceCible / VITESSE_TRAIN

	local tweenInfo = TweenInfo.new(
		tempsTrajetCalcule,
		Enum.EasingStyle.Linear
	)

	local tween = TweenService:Create(progressionTrajet, tweenInfo, {Value = distanceCible})
	tween:Play()

	tween.Completed:Wait()
	if sound then sound.Playing = false end

	for _, wagon in ipairs(wagons) do
		local cframeCache = CFrame.new(0, -100, 0)
		if wagon.modele:IsA("Model") or wagon.modele:IsA("BasePart") then
			wagon.modele:PivotTo(cframeCache)
		end
	end

	task.wait(TEMPS_ATTENTE)
end