-- ============================================================
-- Ce script gère l'apparition, l'animation et le ramassage d'un bonus d'Insta-Kill. (pour tuer instantanément les zombies en une balle)
-- Il utilise un système de TimeTag pour garantir que l'effet expire correctement, même si plusieurs bonus sont ramassés successivement.
-- ============================================================

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local instaKillValue = ReplicatedStorage:WaitForChild("InstaKillActif")

local bonus = script.Parent
local isCollected = false

task.delay(15, function()
	if not isCollected and bonus and bonus.Parent then
		bonus:Destroy()
	end
end)

local startY = bonus.Position.Y
local speed = 2
local height = 1
local rotationSpeed = 3

local connection
connection = RunService.Heartbeat:Connect(function(deltaTime)
	if not bonus or not bonus.Parent then
		connection:Disconnect()
		return
	end
	bonus.CFrame = bonus.CFrame * CFrame.Angles(0, math.rad(rotationSpeed), 0)
	local newY = startY + math.sin(tick() * speed) * height
	bonus.Position = Vector3.new(bonus.Position.X, newY, bonus.Position.Z)
end)

-- Fonction de gestion des collisions pour le ramassage du bonus
bonus.Touched:Connect(function(hit)
	if isCollected then return end

	local character = hit.Parent
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health > 0 then
		local triggeringPlayer = game.Players:GetPlayerFromCharacter(character)

		if triggeringPlayer then
			isCollected = true

			local sound = SoundService:FindFirstChild("InstaKillSound")
			if sound then sound:Play() end

			print(triggeringPlayer.Name .. " a ramassé l'Insta-Kill !")

			-- Mise à jour de l'état global et génération d'un TimeTag technique
			local timeTag = tick()
			instaKillValue:SetAttribute("TimeTag", timeTag)
			instaKillValue.Value = true

			task.delay(15, function()
				-- Vérification de l'intégrité du TimeTag avant de désactiver l'effet
				if instaKillValue:GetAttribute("TimeTag") == timeTag then
					instaKillValue.Value = false
				end
			end)

			-- Nettoyage visuel des composants du bonus
			for _, part in ipairs(bonus:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("Decal") then
					part.Transparency = 1
					part.CanCollide = false
				elseif part:IsA("BillboardGui") or part:IsA("Light") or part:IsA("ParticleEmitter") then
					part.Enabled = false
				end
			end

			game.Debris:AddItem(bonus, 17)
		end
	end
end)