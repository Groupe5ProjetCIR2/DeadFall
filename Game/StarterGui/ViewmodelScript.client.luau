-- ============================================================
-- Ce script est un contrôleur complet de Viewmodel FPS (Vue à la première personne).
-- Il gère le comportement des bras et de l'arme à l'écran en utilisant un système de 
-- "Springs" (ressorts physiques) pour rendre tous les mouvements fluides : 
-- le balancement en marchant (bobbing), le recul de l'arme, la visée (ADS), 
-- ainsi que les secousses de la caméra quand on prend des dégâts ou qu'on chute.
-- ============================================================

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid", 1)
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 1)
local LeftArm = Character:FindFirstChild("Left Arm") or Character:FindFirstChild("LeftHand")
local RightArm = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightHand")
local Camera = Workspace.CurrentCamera

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Events = ReplicatedStorage:FindFirstChild("Events")

-- Importation des modules mathématiques et physiques (les Springs simulent des mouvements élastiques/fluides)
local Utilities = require(Modules.Utilities)
local Spring = Utilities.Spring
local Thread = Utilities.Thread
local Math = Utilities.Math

local InitViewmodel
local RecoilViewmodel
if Events then
	InitViewmodel = Events:FindFirstChild("initViewmodel")
	RecoilViewmodel = Events:FindFirstChild("recoilViewmodel")
end

local ViewmodelStorage = Camera:FindFirstChild("ViewmodelStorage")
if not ViewmodelStorage then
	ViewmodelStorage = Instance.new("Folder")
	ViewmodelStorage.Name = "ViewmodelStorage"
	ViewmodelStorage.Parent = Camera
end

Player.CharacterAdded:connect(function(c)
	Humanoid = c:WaitForChild("Humanoid", 1)
	HumanoidRootPart = c:WaitForChild("HumanoidRootPart", 1)
	LeftArm = c:FindFirstChild("Left Arm") or c:FindFirstChild("LeftHand")
	RightArm = c:FindFirstChild("Right Arm") or c:FindFirstChild("RightHand")
end)

local AimCFrame = CFrame.new()

-- Configuration globale des effets visuels de la caméra et de l'arme
local GeneralSettings = {
	CanSwing = true;
	CanBobble = true;
	CanAim = true;
	CanRecoil = true;

	FpsCam = true;
	CamBobble = false;
	CamImpact = true;
	CamHurt = true;

	LowestFallHeight = 20;
	MaxFallHeight = 30;

	RecoilYRotMax = 16;
	RecoilZPosMax = 1;
	RecoilYPosMax = 0.5;
}

-- Initialisation de tous les "Springs" (ressorts) pour chaque type de mouvement
-- légendes : [s]: speed, [d]: damper (amortissement), [t]: target, [p]: position, [v]: velocity
local SpeedSpring = Spring.spring.new()
SpeedSpring.s = 16
local SwaySpring = Spring.spring.new(0)
SwaySpring.s = 4
SwaySpring.d = 1
local SwaySpeed = Spring.spring.new(0)
SwaySpeed.s = 6
SwaySpeed.d = 1
SwaySpeed.t = 1
local DamageSpring = Spring.spring.new(Vector3.new())
DamageSpring.s = 20
DamageSpring.d = 0.75
local ImpactSpring = Spring.spring.new(Vector3.new())
ImpactSpring.s	= 15
ImpactSpring.d	= 1
local VelocitySpring = Spring.spring.new(Vector3.new())
VelocitySpring.s = 16
VelocitySpring.t = Vector3.new()
VelocitySpring.p = Vector3.new()
local AimSpring = Spring.spring.new()
AimSpring.s = 15
AimSpring.d = 0.9
AimSpring.t = 1
local SwingSpring = Spring.spring.new(Vector3.new())
SwingSpring.s = 10
SwingSpring.d = 0.75

local OffStates = {"Jumping", "PlatformStanding", "Ragdoll", "Seated", "FallingDown", "FreeFalling", "GettingUp", "Swimming", "Climbing"}
local OnStates = {"Running"}

local velocity = Vector3.new()
local speed = 0
local distance = 0
local swayT = 0
local lastHealth = Humanoid.Health
local isFalling = false
local debounce = false
local active = false

local recoilPower = 0
local yAngle = 0
local xAngle = 0
local zAngle = 0
local yPos = 0
local zPos = 0
local recoilCFrame = CFrame.new()

-- Désactive le mouvement des bras si le joueur saute, nage, etc.
for _, state in pairs(OffStates) do
	Humanoid[state]:Connect(function()
		active = false
	end)
end

-- Active le mouvement des bras uniquement si le joueur court/marche
for _, state in pairs(OnStates) do
	Humanoid[state]:Connect(function(speed)
		active = (speed > 1)
	end)
end

-- Impulsion physique sur la caméra quand on prend un coup
local function GetHit(d)
	local l = CFrame.new():VectorToObjectSpace(d)
	DamageSpring:Accelerate(Vector3.new(l.Z, 0, -l.X) * 0.25)
	Thread:Wait(0.03)
	DamageSpring:Accelerate(Vector3.new(-l.Z, 0, 0) * 0.25)
end

-- Mathématiques complexes (Sinus/Cosinus) pour simuler les pas et le balancement de l'arme en marchant
local function GunBob(a, r, baseWalkSpeed)
	local a, r = a or 1, r or 1
	local d, s, v = distance * 6.28318 * 3 / 4, speed, -velocity
	--if s < baseWalkSpeed then
	local w = Vector3.new(r * math.sin(d / 4 - 1) / 256 + r * (math.sin(d / 64) - r * v.Z / 4) / 512, r * math.cos(d / 128) / 128 - r * math.cos(d / 8) / 256, r * math.sin(d / 8) / 128 + r * v.X / 1024) * s / 20 * 6.28318
	return CFrame.new(r * math.cos(d / 8 - 1) * s / 196, 1.25 * a * math.sin(d / 4) * s / 512, 0) * Math.FromAxisAngle(w)
	--else
	--local w = Vector3.new((r * math.sin(d / 4 - 1) / 256 + r * (math.sin(d / 64) - r * v.Z / 4) / 512) * s / 20 * 6.28318, (r * math.cos(d / 128) / 128 - r * math.cos(d / 8) / 256) * s / 20 * 6.28318, r * math.sin(d / 8) / 128 * (5 * s - 56) / 20 * 6.28318 + r * v.X / 1024)
	--return CFrame.new(r * math.cos(d / 8 - 1) * (5 * s - 56) / 196, 1.25 * a * math.sin(d / 4) * s / 512, 0) * Math.FromAxisAngle(w)
	--end
end

-- Simulation de la respiration et de l'inertie de l'arme à l'arrêt
local function GunSway(a)
	local d, s = os.clock() * 6, 2 * (1.2 - a)
	return CFrame.new(math.cos(d / 8) * s / 128, -math.sin(d / 4) * s / 128, math.sin(d / 16) * s / 64)
end

-- Calcule la direction de la source des dégâts pour secouer la caméra du bon côté
local function HealthChanged(health)
	if lastHealth > health and lastHealth - health >= 5 then
		if Humanoid.Health ~= Humanoid.MaxHealth then
			local damageDealt = lastHealth - health
			Thread:Spawn(function()
				local dir = Vector3.new(0, 0, 0)
				if Humanoid:FindFirstChild("creator") then
					local killer = Humanoid.creator
					local killerChar = killer.Value.Character
					local killerHum = killerChar:FindFirstChildOfClass("Humanoid")
					local killerHRP = killerChar:FindFirstChild("HumanoidRootPart")
					if killerChar and killerHRP and killerHum and killerHum.Health > 0 then
						dir = (Camera.CFrame.p - killerHRP.Position).Unit
					else
						dir = (Camera.CFrame.p - HumanoidRootPart.Position).Unit
					end
				else
					dir = (Camera.CFrame.p - HumanoidRootPart.Position).Unit
				end
				GetHit((-damageDealt / 12 + 4.166666666666667) * dir)
			end)
		end
	end
	lastHealth = health
end

-- Calcule la distance de chute pour secouer l'écran au moment de l'impact au sol
Humanoid.FreeFalling:Connect(function(falling)
	isFalling = falling
	if isFalling and not debounce then
		debounce = true
		local maxHeight, lowHeight = 0, math.huge
		while isFalling do
			local height = HumanoidRootPart.Position.Y
			if height > maxHeight then
				maxHeight = height
			end
			if height < lowHeight then
				lowHeight = height
			end
			Thread:Wait()
		end
		local fallHeight = maxHeight - lowHeight
		local impactHeight = fallHeight - GeneralSettings.LowestFallHeight
		if impactHeight > 0 then
			--local damage = impactHeight * (humanoid.MaxHealth / GeneralSettings.MaxFallHeight)
			--humanoid:TakeDamage(damage)
			ImpactSpring:Accelerate(Vector3.new(0, 0, math.random(-impactHeight, impactHeight) / 5))
		end
		debounce = false
	end
end)

if RecoilViewmodel then
	RecoilViewmodel.Event:Connect(function(value)
		recoilPower = value
	end)	
end

-- Détermine où l'arme doit se placer sur l'écran pendant la visée (ADS)
if InitViewmodel then
	InitViewmodel.Event:Connect(function(arms)
		if arms then
			if arms:FindFirstChild("AimPoint") then
				AimCFrame = arms.PrimaryPart.CFrame:ToObjectSpace(arms.AimPoint.CFrame):Inverse()
			end		
		end
	end)	
end

-- Boucle principale qui tourne à chaque frame pour dessiner le Viewmodel
RunService:BindToRenderStep("UpdateViewmodel", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if Character and HumanoidRootPart and Humanoid then
		local MouseDelta = UserInputService:GetMouseDelta()
		recoilPower = recoilPower > 0.1 and Math.Lerp(recoilPower, 0, dt * 11) or 0
		local A = VelocitySpring.v

		-- Mise à jour des forces des ressorts selon les mouvements de souris et du joueur
		SwingSpring.t = Vector3.new(A.Z / 1024 / 32 + A.Y / 1024 / 16 + (MouseDelta.Y / 10) / 1024 * 3 / 2, A.X / 1024 / 32 + (MouseDelta.X / 10) / 1024 * 3 / 2, -(MouseDelta.X / 10) / 1024 * 3 / 2)
		local Aim = AimSpring.p
		local RelativeVelocity = CFrame.new().VectorToObjectSpace(HumanoidRootPart.CFrame, HumanoidRootPart.Velocity)
		SpeedSpring.t = (active and Humanoid.Health > 0) and (Vector3.new(1, 0, 1) * RelativeVelocity).Magnitude or 0
		VelocitySpring.t = RelativeVelocity
		speed = SpeedSpring.p
		distance = distance + dt * SpeedSpring.p
		velocity = VelocitySpring.p
		swayT = swayT + dt * SwaySpeed.p

		-- Applique les effets directement sur la caméra (dégâts, chutes, head bobbing)
		if GeneralSettings.FpsCam then
			local CF = CFrame.new()
			CF = Camera.CoordinateFrame
			local T = swayT
			local S, D = 0.5 * speed, distance * 6.28318 / 4 * 3 / 4
			local SS = SwaySpring.p
			local BobAngles = Math.FromAxisAngle(S * math.cos(D + 2) / 2048, S * math.cos(D / 2) / 2048, S * math.cos(D / 2 + 2) / 4096) * Math.FromAxisAngle(SS * math.cos(2 * T + 2) / 2048, SS * math.cos(2 * T / 2) / 2048, SS * math.cos(2 * T / 2 - 2) / 4096)
			local DamageAngles = Math.FromAxisAngle(DamageSpring.p)
			local ImpactAngles = Math.FromAxisAngle(ImpactSpring.p)
			if GeneralSettings.CamBobble then
				CF = CF * BobAngles
			end
			if GeneralSettings.CamHurt then
				CF = CF * DamageAngles
			end
			if GeneralSettings.CamImpact then
				CF = CF * ImpactAngles
			end
			Camera.CoordinateFrame = CF
		end

		if Humanoid.Health > 0 and Camera and Camera:FindFirstChild("Arms") and Camera.Arms.PrimaryPart then
			if Camera.Arms:FindFirstChild("VMArms") then
				if Camera.Arms and Character and LeftArm and RightArm then
					-- Copie la couleur de peau et les vêtements du joueur sur les bras virtuels
					Camera.Arms.VMArms["Left Arm"].Transparency = 0
					Camera.Arms.VMArms["Right Arm"].Transparency = 0
					if Character:FindFirstChild("Shirt") then
						Camera.Arms.VMArms["Left Arm"].Shirt.Texture = Character.Shirt.ShirtTemplate
						Camera.Arms.VMArms["Right Arm"].Shirt.Texture = Character.Shirt.ShirtTemplate						
					end
					Camera.Arms.VMArms["Left Arm"].Color = LeftArm.Color
					Camera.Arms.VMArms["Right Arm"].Color = RightArm.Color
				end
			end

			-- Génère un recul aléatoire interpolé (Lerp) pour simuler la dispersion de l'arme
			yAngle = Math.Lerp(yAngle, GeneralSettings.RecoilYRotMax * recoilPower, recoilPower == 0 and dt * 7 or dt * 6) + Math.Lerp(xAngle, Math.Randomize(2) * recoilPower, recoilPower == 0 and dt * 7 or dt / 2)
			xAngle = Math.Lerp(xAngle, Math.Randomize(1.3) * recoilPower, recoilPower == 0 and dt * 7 or dt * 3)
			zAngle = Math.Lerp(zAngle, Math.Randomize(5) * recoilPower, recoilPower == 0 and dt * 7 or dt / 3)
			yPos = Math.Lerp(yPos, GeneralSettings.RecoilYPosMax * recoilPower, recoilPower == 0 and dt * 7 or dt * 0.4)
			zPos = Math.Lerp(zPos, GeneralSettings.RecoilZPosMax * recoilPower, recoilPower == 0 and dt * 7 or dt * 0.9)
			recoilCFrame = CFrame.new(0, yPos, zPos) * CFrame.Angles(math.rad(yAngle), xAngle, zAngle)

			local CF = CFrame.new()
			CF = Camera.CoordinateFrame * CFrame.new(0, 0, (Camera.FieldOfView / 90 - 1) * 0.3)

			-- Transition fluide entre la position de hanche (Hipfire) et la visée (Aiming)
			if Camera.Arms:FindFirstChild("isAiming") and Camera.Arms:FindFirstChild("aimSteady") then
				if Camera.Arms.isAiming.Value then
					MouseDelta = MouseDelta * 0.75
					AimSpring.t = Camera.Arms.aimSteady.aim.Value
				else
					AimSpring.t = Camera.Arms.aimSteady.noAim.Value
				end
			else
				AimSpring.t = 0
			end

			-- Combine toutes les modifications calculées pour positionner les bras
			if GeneralSettings.CanSwing then
				CF = CF * Math.FromAxisAngle(SwingSpring.v)
			end
			if GeneralSettings.CanBobble then
				CF = CF * GunBob(0.7 - 0.3 * AimSpring.p, 1 - 0.8 * AimSpring.p, Humanoid.WalkSpeed) * GunSway(Aim)
			end
			if GeneralSettings.CanAim then
				if Camera.Arms:FindFirstChild("AimPoint") then
					local AimCF = Math.Interpolator(AimCFrame)
					CF = CF * AimCF(Aim)
				end
			end
			if GeneralSettings.CanRecoil then
				CF = CF * recoilCFrame
			end

			local Offset = Camera.Arms:FindFirstChild("offset") and require(Camera.Arms.offset) or CFrame.new(0, 0, 0)
			local Offst = Math.Interpolator(Offset)
			CF = CF * Offst(1 - Aim)

			-- Applique le résultat final aux bras du Viewmodel
			Camera.Arms.PrimaryPart.Anchored = true
			if Camera.CameraType == Enum.CameraType.Custom then
				local CamOffset = -Humanoid.CameraOffset
				Camera.Arms.PrimaryPart.CFrame = CF * CFrame.new(CamOffset.X * 0.5, CamOffset.Y * 0.5, CamOffset.Z * 0.5)
			end
		end
	end
end)

Humanoid.HealthChanged:Connect(HealthChanged)

-- Nettoyage de la boucle si le joueur meurt pour éviter les bugs de caméra
Humanoid.Died:Connect(function()
	HealthChanged(20)
	RunService:UnbindFromRenderStep("UpdateViewmodel")
end)

Humanoid.AncestryChanged:Connect(function()
	if not Humanoid:IsDescendantOf(game) then
		RunService:UnbindFromRenderStep("UpdateViewmodel")
	end
end)

HealthChanged(Humanoid.Health)