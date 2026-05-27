-- ============================================================
-- Ce script agit comme un bouclier de sécurité physique pour empêcher le joueur de subir des bugs de vélocité extrême ou de corruption mathématique (NaN).
-- Il surveille en permanence les forces appliquées au personnage et le téléporte vers une position sûre en détruisant les contraintes physiques anormales.
-- ============================================================

local RunService = game:GetService("RunService")
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

humanoid.RequiresNeck = false
humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)

local lastSafeCFrame = hrp.CFrame

-- Boucle de vérification continue liée au moteur physique pour surveiller l'intégrité de la position et de la vélocité
RunService.Heartbeat:Connect(function()
	if humanoid.Health <= 0 then return end

	local pos = hrp.Position
	local vel = hrp.AssemblyLinearVelocity
	local angVel = hrp.AssemblyAngularVelocity

	-- Identifie les corruptions de type NaN (Not a Number) causées par des calculs de forces invalides
	local isNaN = (pos.X ~= pos.X) or (vel.X ~= vel.X) or (angVel.X ~= angVel.X)

	local isTooFast = false
	if not isNaN then
		isTooFast = vel.Magnitude > 1500 or angVel.Magnitude > 1500
	end

	if isNaN or isTooFast then

		-- Purge systématiquement toutes les instances de mouvement résiduelles pour éviter de relancer la force corrompue
		for _, child in ipairs(hrp:GetChildren()) do
			if child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") or child:IsA("LinearVelocity") or child:IsA("VectorForce") then
				child:Destroy()
			end
		end

		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

		if isNaN or lastSafeCFrame.Position.Y < -500 or lastSafeCFrame.Position.X ~= lastSafeCFrame.Position.X then
			hrp.CFrame = CFrame.new(0, 100, 0)
		else
			hrp.CFrame = lastSafeCFrame
		end

		warn("🛡️ PhysicsShield a purgé une force corrompue (" .. (isNaN and "NaN" or "Vitesse") .. ") !")
	else
		if pos.Y > -400 then
			lastSafeCFrame = hrp.CFrame
		end
	end
end)