-- ============================================================
-- Ce script crée un événement distant pour permettre la rotation ou le déplacement d'un modèle (Spinner) depuis le client.
-- Il écoute les requêtes des joueurs et met à jour instantanément la position du modèle sur le serveur selon le CFrame reçu.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local spinnermodel = workspace:WaitForChild("Spinner")
local wheelSpawns = workspace:WaitForChild("WheelSpawns")

local currentSpawn = Instance.new("ObjectValue")
currentSpawn.Name = "CurrentSpawn"
currentSpawn.Value = wheelSpawns:WaitForChild("ParkingSpawnWheel")
currentSpawn.Parent = spinnermodel

local moveWheelEvent = Instance.new("RemoteEvent")
moveWheelEvent.Name = "MoveWheelEvent"
moveWheelEvent.Parent = ReplicatedStorage

moveWheelEvent.OnServerEvent:Connect(function(player, spawnPart)
	if spawnPart and spawnPart:IsA("BasePart") then
		currentSpawn.Value = spawnPart
		spinnermodel:PivotTo(
			CFrame.new(spawnPart.Position + Vector3.new(0, 4, 0)) * spawnPart.CFrame.Rotation * CFrame.Angles(math.rad(90), 0, 0)
		)
	end
end)