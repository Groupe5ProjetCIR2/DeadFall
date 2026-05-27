-- ============================================================
--  Ce script implémente une mécanique de wallrun (course murale) 
--  côté serveur en utilisant des Raycasts et un LinearVelocity.
--  Il gère la physique, les temps de recharge et communique 
--  avec le client pour incliner la caméra pendant la course.
-- ============================================================

local Gravity = 3
local MaxWallrunRadius = 4.5 
local CameraTiltAmount = 10
local Cooldown = 0.75
local WallJumpCooldown = 0.6

local MinSpeed = 32
local MaxSpeed = 110
local EntryMultiplier = 0.85

local char = script.Parent
local plr = game.Players:GetPlayerFromCharacter(char)
local HRP = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")

local Attach = Instance.new("Attachment")
Attach.Parent = HRP

local Velocity = Instance.new("LinearVelocity")
Velocity.MaxForce = math.huge
Velocity.Enabled = false
Velocity.Attachment0 = Attach
Velocity.RelativeTo = Enum.ActuatorRelativeTo.World 
Velocity.Parent = HRP

local Signal = script.Parent:WaitForChild("WallrunSignal")
local RS = game:GetService("RunService")

local Wallrunning = false
local CurrentWallNormal = Vector3.new(0, 0, 0)
local WallRunDirection = Vector3.new(0, 0, 0)
local lastWallrun = 0
local lastWallSide = 0 
local lastWallNormal = Vector3.new(0, 0, 0) 
local wallJumpCooldownUntil = 0
local currentRunSpeed = 0 

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
local ignoreList = {}

-- Exécute un Raycast optimisé qui ignore récursivement le personnage et les pièces invisibles ou non ancrées
local function SmartRaycast(origin, direction)
	table.clear(ignoreList)
	table.insert(ignoreList, char)

	for i = 1, 5 do 
		rayParams.FilterDescendantsInstances = ignoreList
		local result = workspace:Raycast(origin, direction, rayParams)

		if result then
			if result.Instance.Transparency >= 1 then
				table.insert(ignoreList, result.Instance)
			elseif result.Instance.Anchored then
				return result
			else
				table.insert(ignoreList, result.Instance)
			end
		else
			return nil 
		end
	end
	return nil
end

-- Interrompt la course murale, désactive la vélocité et réinitialise la caméra du client
local function stopWallrun()
	if Wallrunning then
		Wallrunning = false
		Velocity.Enabled = false
		Signal:FireClient(plr, 0)
	end
end

-- Vérifie les conditions physiques et les temps de recharge avant d'initialiser les vecteurs de la course murale
local function startWallrun(side, wallNormal, tiltAmount)
	if tick() - lastWallrun < Cooldown then return false end

	local state = hum:GetState()
	if state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.FallingDown then return false end

	if tick() < wallJumpCooldownUntil then
		if side == lastWallSide then return false end
		if lastWallNormal.Magnitude > 0 and wallNormal:Dot(lastWallNormal) > 0.8 then 
			return false 
		end
	end

	local currentHVel = Vector3.new(HRP.AssemblyLinearVelocity.X, 0, HRP.AssemblyLinearVelocity.Z)
	currentRunSpeed = math.clamp(currentHVel.Magnitude * EntryMultiplier, MinSpeed, MaxSpeed)

	local tangent = Vector3.new(0, 1, 0):Cross(wallNormal).Unit
	if tangent:Dot(currentHVel) < 0 then
		tangent = -tangent
	end

	lastWallrun = tick()
	Wallrunning = true
	lastWallSide = side
	lastWallNormal = wallNormal
	CurrentWallNormal = wallNormal
	WallRunDirection = tangent
	Velocity.Enabled = true

	Signal:FireClient(plr, tiltAmount)
	return true
end

-- Écoute les requêtes du client (ex: saut depuis le mur) pour appliquer le temps de recharge approprié
Signal.OnServerEvent:Connect(function(player, action, direction)
	if action == "stop" then
		lastWallSide = direction
		lastWallNormal = CurrentWallNormal
		wallJumpCooldownUntil = tick() + WallJumpCooldown
		stopWallrun()
	end
end)

-- Boucle de physique principale : maintient le joueur contre le mur via la vélocité ou détecte de nouvelles surfaces
RS.Heartbeat:Connect(function(dt)
	local currentState = hum:GetState()
	local isFalling = (currentState == Enum.HumanoidStateType.Freefall or currentState == Enum.HumanoidStateType.FallingDown)

	if not isFalling then
		if Wallrunning then
			local groundCheck = SmartRaycast(HRP.Position, Vector3.new(0, -4.5, 0))
			if groundCheck then
				stopWallrun() 
				return
			end
		else
			stopWallrun()
			return
		end
	end

	if Wallrunning then
		local result = SmartRaycast(HRP.Position, -CurrentWallNormal * MaxWallrunRadius)

		if result then
			Velocity.Enabled = true

			CurrentWallNormal = result.Normal
			local tangent = Vector3.new(0, 1, 0):Cross(CurrentWallNormal).Unit
			if tangent:Dot(WallRunDirection) < 0 then
				tangent = -tangent
			end
			WallRunDirection = tangent

			-- Calcule le vecteur de vélocité final combinant la tangente du mur, la gravité et une force d'attraction
			local v = WallRunDirection * currentRunSpeed
			local pushIntoWall = -result.Normal * 1.5

			Velocity.VectorVelocity = Vector3.new(v.X + pushIntoWall.X, -Gravity, v.Z + pushIntoWall.Z)
		else
			stopWallrun()
		end
	else
		local right = SmartRaycast(HRP.Position, HRP.CFrame.RightVector * MaxWallrunRadius)
		if right then
			startWallrun(1, right.Normal, CameraTiltAmount)
		else
			local left = SmartRaycast(HRP.Position, -HRP.CFrame.RightVector * MaxWallrunRadius)
			if left then
				startWallrun(-1, left.Normal, -CameraTiltAmount)
			else
				stopWallrun()
			end
		end
	end
end)