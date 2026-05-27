-- ============================================================
-- Ce script gère l'apparition, l'animation et l'effet de ramassage d'un bonus "Nuke".
-- Il déclenche un flash visuel, élimine instantanément tous les zombies présents et distribue une récompense monétaire à tous les joueurs.
-- ============================================================

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local AfficherGainEvent = ReplicatedStorage:FindFirstChild("AfficherGainArgent")
local bonus = script.Parent
local isCollected = false

-- Animation de flottaison et rotation du bonus
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

-- Auto-destruction après 15s si le bonus n'est pas ramassé
task.delay(15, function()
	if not isCollected and bonus and bonus.Parent then
		bonus:Destroy()
	end
end)

-- Logique de ramassage et exécution de l'effet Nuke
bonus.Touched:Connect(function(hit)
	if isCollected then return end

	local character = hit.Parent
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health > 0 then
		local player = game.Players:GetPlayerFromCharacter(character)

		if player then
			isCollected = true

			-- 1. Effets sonores et visuels (Flash lumineux)
			local nukeSound = SoundService:FindFirstChild("NukeSound")
			if nukeSound then
				nukeSound:Play()
			end

			local flash = Instance.new("ColorCorrectionEffect")
			flash.Brightness = 2
			flash.Parent = Lighting

			local fadeInfo = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local fadeTween = TweenService:Create(flash, fadeInfo, {Brightness = 0})
			fadeTween:Play()
			fadeTween.Completed:Connect(function()
				flash:Destroy()
			end)

			-- 2. Élimination des ennemis et calcul des gains
			local zombiesTues = 0

			for _, objet in ipairs(workspace:GetDescendants()) do
				if objet:IsA("Model") and objet.Name == "ZombieRobot" then
					local targetHumanoid = objet:FindFirstChildOfClass("Humanoid")

					if targetHumanoid and targetHumanoid.Health > 0 then
						zombiesTues = zombiesTues + 1
						targetHumanoid.Health = 0 
					end
				end
			end

			if zombiesTues > 0 then
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local killsStat = leaderstats:FindFirstChild("Kills") 
					if killsStat then
						killsStat.Value = killsStat.Value + zombiesTues
					end
				end
			end

			local baseArgent = zombiesTues * 20
			local argentGagne = baseArgent

			-- Vérification du multiplicateur "Double Argent" global
			local doubleArgentValue = game:GetService("ReplicatedStorage"):FindFirstChild("DoubleArgentActif")
			if doubleArgentValue and doubleArgentValue.Value == true then
				argentGagne = baseArgent * 2
			end

			-- 3. Distribution de l'argent à tous les joueurs
			if argentGagne > 0 then
				for _, plr in ipairs(game.Players:GetPlayers()) do
					local leaderstats = plr:FindFirstChild("leaderstats")
					if leaderstats then
						local argent = leaderstats:FindFirstChild("Argent") 
						if argent then
							argent.Value = argent.Value + argentGagne

							if AfficherGainEvent then
								AfficherGainEvent:FireClient(plr, argentGagne)
							end
						end
					end
				end
			end

			-- 4. Nettoyage visuel et suppression de l'objet bonus
			for _, part in ipairs(bonus:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("Decal") then
					part.Transparency = 1
					part.CanCollide = false
				elseif part:IsA("BillboardGui") or part:IsA("Light") then
					part.Enabled = false
				end
			end

			game.Debris:AddItem(bonus, 0.25)
		end
	end
end)