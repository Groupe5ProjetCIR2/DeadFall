-- ============================================================
-- Ce script gère l'interaction avec un ProximityPrompt pour déclencher un événement de type "Roue de la fortune" en échange d'une somme d'argent.
-- Il vérifie les fonds du joueur, déduit le montant requis et envoie un signal au client pour démarrer l'animation visuelle.
-- ============================================================

local prompt = script.Parent
local RS = game:GetService("ReplicatedStorage")

-- Initialise dynamiquement le RemoteEvent s'il n'existe pas déjà dans le ReplicatedStorage pour assurer la communication client-serveur
local startSpinnerEvent = RS:FindFirstChild("StartSpinner")
if not startSpinnerEvent then
	startSpinnerEvent = Instance.new("RemoteEvent")
	startSpinnerEvent.Name = "StartSpinner"
	startSpinnerEvent.Parent = RS
end

prompt.ActionText = "Spin the wheel"
prompt.ObjectText = "1000 $"
prompt.HoldDuration = 1 
prompt.Style = Enum.ProximityPromptStyle.Custom 

local price = 1000

-- Vérifie la solvabilité du joueur avant de déduire les fonds et de notifier son client local pour lancer la roue
prompt.Triggered:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local points = leaderstats and leaderstats:FindFirstChild("Argent")

	if not points or points.Value < price then 
		print(player.Name .. " n'a pas assez d'argent pour la roue !")
		return 
	end

	points.Value -= price
	print(player.Name .. " a payé $1000 et lance la roue !")

	startSpinnerEvent:FireClient(player)
end)