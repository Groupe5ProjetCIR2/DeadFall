-- ============================================================
--  Ce script a pour but de gérer dynamiquement les sons 
--  de pas, de saut et d'atterrissage des joueurs en 
--  fonction du matériau du sol. Il inclut des optimisations 
--  de performance (distance, fréquence de raycasting) 
--  et désactive intelligemment les bruits de pas lorsque le 
--  personnage est en train de glisser (slide).
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local DefaultWalkspeed = StarterPlayer.CharacterWalkSpeed
local MaxFPS = 1/10 
local FootstepsPerSecond = 2.5
local MaxDistance = 250 

local LocalPlayer = Players.LocalPlayer

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FootstepModule = require(Modules:WaitForChild("FootstepModule"))

local FootstepsSoundGroup = SoundService:WaitForChild("Main").Character.Footsteps
local LandingSoundGroup = SoundService:WaitForChild("Main").Character.Landing
local JumpingSoundGroup = SoundService:WaitForChild("Main").Character.Jumping

local CachedFootsteps = FootstepModule:GetCached(FootstepsSoundGroup, "Footsteps")
local CachedLanding = FootstepModule:GetCached(LandingSoundGroup, "Landing")
local CachedJumping = FootstepModule:GetCached(JumpingSoundGroup, "Jumping")

local isSliding = false

local ValidStates = {
	Enum.HumanoidStateType.Running,
	Enum.HumanoidStateType.Climbing
}

-- Lit l'attribut du joueur pour déterminer s'il effectue actuellement une glissade
local function CheckIfSliding(Character)
	local humanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		return humanoidRootPart:GetAttribute("IsSliding") or false
	end
	return false
end

-- Sélectionne un élément au hasard dans le tableau fourni (utilisé pour varier les sons joués)
local function GetRandomFromTable(Table:{any})
	return Table[math.random(#Table)]
end

-- Clone, configure (pitch, volume, portée) et joue un son de manière indépendante avant de le détruire pour libérer la mémoire
local function PlayRandomSound(Directory:Folder,PlayAt:BasePart|Attachment,Speed:number)
	local Sound:Sound = GetRandomFromTable(Directory)

	if Sound.IsLoaded then
		Sound = Sound:Clone()
	else
		return
	end

	local IsBass = Sound:GetAttribute("IsBass")
	local DefaultPitch = Sound:GetAttribute("DefaultPitch")
	local DefaultVolume = Sound:GetAttribute("DefaultVolume")
	local DefaultRolloff = Sound:GetAttribute("DefaultRolloff")

	local Speed = Speed or 1
	local function influencemult(num,influence)
		return ((1-influence)+(num*influence))
	end

	local Pitch = DefaultPitch*(math.random(950,1050)/1000)*influencemult(Speed,0.5)
	local Volume = DefaultVolume*(IsBass and math.max((Speed-0.5),0.2) or Speed)
	local Rolloff = DefaultRolloff*influencemult(Speed,0.1)

	Sound.PlaybackSpeed *= Pitch
	Sound.Volume = Volume
	Sound.RollOffMinDistance = Rolloff

	Sound.Parent = PlayAt or SoundService

	Sound:Play()
	Sound.Ended:Once(function()
		Sound:Destroy()
	end)
end

-- Initialise la détection physique et la gestion sonore pour chaque nouveau personnage apparaissant en jeu
local function OnCharacterAdded(Character:Model)
	if Character:GetAttribute("SetUp") then return end
	Character:SetAttribute("SetUp",true)

	if not Character:GetAttribute("Set") then
		Character:SetAttribute("Set","Default")
	end

	local Humanoid:Humanoid = Character:WaitForChild("Humanoid")
	local HRP = Character:WaitForChild("HumanoidRootPart") 

	local Stride = "Left"
	local LastFloorRay = nil
	local LastRayFrame, LastLand = time(), time()
	local ElapsedSinceLastFootstep = 0

	local FootstepsDirectory, LandingDirectory, JumpingDirectory = CachedFootsteps[Character:GetAttribute("Set")], CachedLanding[Character:GetAttribute("Set")], CachedJumping[Character:GetAttribute("Set")]

	local Connection
	local Connections = {}

	local FootstepTimer = DefaultWalkspeed/FootstepsPerSecond
	local Velocity, MoveDirection, FloorMaterial, HumanoidState, LastFloorMaterial

	HumanoidState = Humanoid:GetState()

	local RayParams = RaycastParams.new()
	RayParams.CollisionGroup = "SoundRays" 
	RayParams.IgnoreWater = true
	RayParams.RespectCanCollide = true
	RayParams.FilterDescendantsInstances = {workspace.CurrentCamera,Character} 
	RayParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Coupe l'exécution des calculs si le personnage distant est trop éloigné du joueur local (optimisation des performances)
	local function IsWithinRange()
		if LocalPlayer.Character ~= Character and HRP and (HRP.Position-workspace.Camera.CFrame.Position).Magnitude > MaxDistance then return false end
		return true
	end

	local function Raycast(a,b)
		return workspace:Raycast(a,b,RayParams)
	end

	local function GetHipHeightFromHRP()
		return ((HRP.Size.Y/2)+(Humanoid.HipHeight+2)+2)
	end

	-- Projette un rayon sous le personnage pour identifier de manière fiable la matière du sol sur lequel il se trouve
	local function GetFloorMaterial()
		local ray = workspace:Raycast(HRP.Position, -HRP.CFrame.UpVector*GetHipHeightFromHRP(),RayParams)
		if ray and ray.Instance then
			return ray.Material
		end
	end

	-- Met à jour la vélocité, la direction et les informations de sol en limitant la fréquence d'appel des Raycasts via MaxFPS pour éviter de saturer la mémoire
	local function UpdateCommon()
		local floorray = nil
		if time()-LastRayFrame >= MaxFPS then
			floorray = Raycast(HRP.Position,-HRP.CFrame.UpVector*GetHipHeightFromHRP())
			LastFloorRay = floorray
			LastRayFrame = time()
		else
			floorray = LastFloorRay
		end

		local floor:BasePart = (floorray and floorray.Instance)
		if floor and floor:IsA("Terrain") then floor = nil end

		Velocity = floor and HRP.AssemblyLinearVelocity-floor:GetVelocityAtPosition(floorray.Position) or HRP.AssemblyLinearVelocity
		MoveDirection = Humanoid.MoveDirection
		LastFloorMaterial = FloorMaterial ~= Enum.Material.Air and FloorMaterial or LastFloorMaterial
		FloorMaterial = Humanoid.FloorMaterial

		isSliding = CheckIfSliding(Character)
	end

	local function IsFooted()
		if (table.find(ValidStates,HumanoidState)) or (FloorMaterial and FloorMaterial ~= Enum.Material.Air) then
			return true
		end
	end

	local function MovingCheck()
		if MoveDirection.Magnitude > 0 then
			return true
		else
			return false
		end
	end

	local function GetFootstepSpeed()
		return (math.min(Velocity.Magnitude,DefaultWalkspeed*2)/DefaultWalkspeed)^1.01
	end

	local function UpdateTimestep(dt)
		ElapsedSinceLastFootstep += dt*math.max(Velocity.Magnitude,7) 
	end

	local function step(MaterialSounds)
		local IsRight = Stride == "Right"
		local Speed = GetFootstepSpeed()
		PlayRandomSound(MaterialSounds,HRP,Speed*(IsRight and 1.05 or 0.95))
		if Character == LocalPlayer.Character then
			PlayRandomSound(FootstepsDirectory["Bass"],HRP,Speed)
		end
		ElapsedSinceLastFootstep = 0
	end

	-- Récupère et déclenche le son de pas correspondant au type de surface touchée (ou échelle si le joueur grimpe)
	local function Footstep()
		local IsClimbing = HumanoidState == Enum.HumanoidStateType.Climbing
		local Type = IsClimbing and "Ladder" or FootstepModule.MaterialMap[FloorMaterial]
		local MaterialSounds = FootstepsDirectory[Type]
		if MaterialSounds then
			step(MaterialSounds)
		end
	end

	local function Land(mat)
		local IsRight = Stride == "Right"
		local Speed = GetFootstepSpeed()
		local MaterialSounds = LandingDirectory[FootstepModule.MaterialMap[mat]] or LandingDirectory[FootstepModule.MaterialMap[FloorMaterial]]

		PlayRandomSound(MaterialSounds,HRP,Speed*(IsRight and 1.05 or 0.95))
		if Character == LocalPlayer.Character then
			PlayRandomSound(LandingDirectory["Bass"],HRP,Speed)
		end
	end

	local function Jump()
		local MaterialSounds = JumpingDirectory[FootstepModule.MaterialMap[FloorMaterial]]
		PlayRandomSound(MaterialSounds,HRP)
	end

	-- Autorise le bruit de pas uniquement si le joueur touche le sol, bouge, et qu'il n'est pas en train de glisser
	local function CanFootstep()
		if isSliding then return false end

		return IsFooted() and Velocity.Magnitude > .1 and MovingCheck()
	end

	-- Surveille activement l'état de l'avatar (ex: fin de saut, course à chute libre) pour déclencher les sons d'atterrissage ou d'impulsion
	local function StateChanged(old,new)
		HumanoidState = new
		FloorMaterial = Humanoid.FloorMaterial

		if IsWithinRange() then

			if 
				new == Enum.HumanoidStateType.Landed
				or 
				(Character ~= LocalPlayer.Character 
					and (FloorMaterial == Enum.Material.Air
						and new == Enum.HumanoidStateType.Running)
				)
			then
				if LastLand > time() then return end
				LastLand = time() + .1
				local materialToUse = GetFloorMaterial() or LastFloorMaterial or Humanoid.FloorMaterial
				if materialToUse == Enum.Material.Air then return end
				Land(materialToUse)

			elseif 
				(Character == LocalPlayer.Character 
					and new == Enum.HumanoidStateType.Jumping) 
				or 
				(Character ~= LocalPlayer.Character 
					and new == Enum.HumanoidStateType.Freefall 
					and old == Enum.HumanoidStateType.Running) 
			then

				FloorMaterial = GetFloorMaterial() or Humanoid.FloorMaterial
				if FloorMaterial == Enum.Material.Air then return end
				Jump()
			end
		end
	end

	local function AttributeChanged(Attr)
		if Attr == "Set" then
			FootstepsDirectory = CachedFootsteps[Character:GetAttribute("Set")]
			LandingDirectory = CachedLanding[Character:GetAttribute("Set")]
			JumpingDirectory = CachedJumping[Character:GetAttribute("Set")]
		end
	end

	-- Boucle de mise à jour reliée au Heartbeat du jeu : rafraîchit en permanence l'état du personnage et détruit proprement les connexions à la mort
	local function Initialize()
		table.insert(Connections, HRP:GetAttributeChangedSignal("IsSliding"):Connect(function()
			isSliding = HRP:GetAttribute("IsSliding") or false
		end))

		table.insert(Connections,RunService.Heartbeat:Connect(function(dt)
			if not IsWithinRange() then return end

			UpdateCommon()
			if CanFootstep() then
				UpdateTimestep(dt)
				if ElapsedSinceLastFootstep >= FootstepTimer then
					Footstep()
				end
			end
		end))

		table.insert(Connections,Humanoid.StateChanged:Connect(StateChanged))
		table.insert(Connections,Character.AttributeChanged:Connect(AttributeChanged))

		local function destroy()
			for _, con in Connections do
				con:Disconnect()
			end
			Connections = nil
			ElapsedSinceLastFootstep = nil
			Stride = nil
			HumanoidState = nil
			HRP = nil
			Humanoid = nil
			Velocity = nil
			task.cancel(Connection)
		end

		table.insert(Connections,Humanoid.Died:Connect(destroy))
		table.insert(Connections,Character.Destroying:Connect(destroy))
	end

	Connection = task.spawn(Initialize)
end

-- Applique la logique de son à tout joueur déjà présent ou rejoignant le serveur
local function OnPlayerAdded(Plr:Player)
	Plr.CharacterAdded:Connect(OnCharacterAdded)
	if Plr.Character then
		OnCharacterAdded(Plr.Character)
	end
end

for _, plr in Players:GetPlayers() do
	OnPlayerAdded(plr)
end

Players.PlayerAdded:Connect(OnPlayerAdded)