-- ============================================================
-- Ce script gère l'apparition, l'animation et le ramassage d'un bonus de munitions maximales.
-- Il parcourt l'inventaire et l'équipement actif de tous les joueurs pour réinitialiser les munitions aux valeurs maximales définies dans les configurations.
-- ============================================================

local bonus = script.Parent
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- Gestion de l'animation de flottaison et rotation
local startY = bonus.Position.Y
local connection
connection = RunService.Heartbeat:Connect(function()
	if not bonus or not bonus.Parent then connection:Disconnect() return end
	bonus.CFrame = bonus.CFrame * CFrame.Angles(0, math.rad(3), 0)
	bonus.Position = Vector3.new(bonus.Position.X, startY + math.sin(tick() * 2) * 1, bonus.Position.Z)
end)

local isCollected = false

-- Destruction automatique si le bonus n'est pas ramassé dans les 15 secondes
task.delay(15, function()
	if not isCollected and bonus and bonus.Parent then bonus:Destroy() end
end)

-- Fonction déclenchée lors du contact avec l'objet bonus
bonus.Touched:Connect(function(hit)
	if isCollected then return end
	local character = hit.Parent
	local humanoid = character and character:FindFirstChild("Humanoid")

	if humanoid and humanoid.Health > 0 then
		local triggeringPlayer = game.Players:GetPlayerFromCharacter(character)
		if triggeringPlayer then
			isCollected = true

			local maxAmmoSound = SoundService:FindFirstChild("MaxAmmoSound")
			if maxAmmoSound then maxAmmoSound:Play() end

			-- Parcours de tous les joueurs connectés pour appliquer le rechargement
			for _, player in ipairs(game.Players:GetPlayers()) do
				local plrChar = player.Character
				local plrBackpack = player:FindFirstChild("Backpack")

				-- Fonction locale pour réinitialiser les valeurs de munitions d'une arme spécifique
				local function refillWeapon(weapon)
					if not weapon:IsA("Tool") or not weapon:FindFirstChild("Setting") then return end

					local setting1 = weapon.Setting:FindFirstChild("1")
					if not setting1 then return end

					local settings = require(setting1)
					local mainSettings = require(weapon.Setting)

					local maxMag = settings.AmmoPerMag
					local maxStock = settings.MaxAmmo

					-- Mise à jour des valeurs sur le serveur
					local valueFolder = weapon:FindFirstChild("ValueFolder")
					if valueFolder then
						if valueFolder:FindFirstChild("1") then
							local folder1 = valueFolder:FindFirstChild("1")
							if folder1:FindFirstChild("Mag") then folder1.Mag.Value = maxMag end
							if folder1:FindFirstChild("Ammo") then folder1.Ammo.Value = maxStock end
						end

						if mainSettings.UniversalAmmoEnabled and valueFolder:FindFirstChild("Ammo") then
							valueFolder.Ammo.Value = maxStock
						end
					end

					-- Synchronisation de l'affichage (HUD) sur le client
					local syncEvent = weapon:FindFirstChild("SyncWeaponEvent")
					if syncEvent then
						syncEvent:FireClient(player, "SetAmmo", {Mag = maxMag, Ammo = maxStock})
					end
				end

				-- Application sur l'arme équipée
				if plrChar then
					local equippedWeapon = plrChar:FindFirstChildOfClass("Tool")
					if equippedWeapon then refillWeapon(equippedWeapon) end
				end

				-- Application sur les armes dans le sac à dos
				if plrBackpack then
					for _, tool in ipairs(plrBackpack:GetChildren()) do
						refillWeapon(tool)
					end
				end
			end

			-- Désactivation visuelle des composants du bonus
			for _, part in ipairs(bonus:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("Decal") then 
					part.Transparency = 1 
					part.CanCollide = false
				elseif part:IsA("BillboardGui") or part:IsA("Light") or part:IsA("ParticleEmitter") then 
					part.Enabled = false 
				end
			end

			game.Debris:AddItem(bonus, 2)
		end
	end
end)