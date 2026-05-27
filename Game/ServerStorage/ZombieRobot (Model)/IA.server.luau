-- ============================================================
-- Ce script gère l'intelligence artificielle de navigation d'un zombie, utilisant un système hybride de pathfinding natif et de pistage par traces.
-- Il intègre également une logique d'évitement et de saut d'obstacles (Vault) pour garantir une poursuite fluide et sans blocage.
-- ============================================================

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local zombie = script.Parent
local rootPart = zombie:WaitForChild("HumanoidRootPart")
local humanoid = zombie:WaitForChild("Zombie")
rootPart:SetNetworkOwner(nil)

local STOP_DISTANCE = 3      
local CHECK_INTERVAL = 0.1    

local TELEPORT_TIME = 3.5    
local TELEPORT_RADIUS = 6.0    
local JUMP_STUCK_TIME = 0.6    

local PATHFINDING_LIMIT = 150    
local TARGET_MOVED_DIST = 4.0    

local teleportAnchor = rootPart.Position
local teleportTimer = 0
local lastPos = rootPart.Position
local stuckTimer = 0
local lastJumpTime = 0

local currentWaypoints = {}
local waypointIndex = 2
local lastComputedTarget = nil
local isComputing = false
local isJumping = false

local teleportEvent = game:GetService("ServerStorage"):WaitForChild("TeleportZombie")

local swarmOffset = Vector3.new(
	math.random(-30, 30) / 10,
	0,
	math.random(-30, 30) / 10
)

-- Configuration de l'agent Pathfinding avec priorité sur le franchissement d'obstacles
local path = PathfindingService:CreatePath({
	AgentCanJump = true,
	AgentHeight = 5,
	AgentRadius = 4,
	AgentMaxSlope = 45,
	Costs = { 
		Jump = 30,
		ZoneInterdite = math.huge
	} 
})

path.Blocked:Connect(function(blockedIdx)
	if blockedIdx >= waypointIndex then
		currentWaypoints = {}
		lastComputedTarget = nil
	end
end)

local function getXZDistance(pos1, pos2)
	return (Vector3.new(pos1.X, 0, pos1.Z) - Vector3.new(pos2.X, 0, pos2.Z)).Magnitude
end

-- Vérifie si le zombie possède une ligne de vue dégagée vers la cible en ignorant les obstacles
local function canMoveDirectly(target)
	local origin = rootPart.Position
	local direction = (target.Position - origin)
	if math.abs(direction.Y) > 12 then return false end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {zombie}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, direction, rayParams)

	if not result then return true end
	if result.Instance:IsDescendantOf(target.Parent) then return true end

	local part = result.Instance
	local parent = part.Parent
	local grandparent = parent and parent.Parent

	if CollectionService:HasTag(part, "Vaultable") 
		or (parent and CollectionService:HasTag(parent, "Vaultable")) 
		or (grandparent and CollectionService:HasTag(grandparent, "Vaultable")) then
		return true
	end

	return false -- vrai mur solide
end

local function checkVaultableObstacle(targetPos)
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {zombie}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local dir = (targetPos - rootPart.Position)
	local dirXZ = Vector3.new(dir.X, 0, dir.Z)
	if dirXZ.Magnitude > 0 then dirXZ = dirXZ.Unit end

	local result = workspace:Raycast(rootPart.Position, dirXZ * 5.0, rayParams)
	if result then
		local part = result.Instance
		local parent = part.Parent
		local grandparent = parent and parent.Parent

		if CollectionService:HasTag(part, "Vaultable") 
			or (parent and CollectionService:HasTag(parent, "Vaultable")) 
			or (grandparent and CollectionService:HasTag(grandparent, "Vaultable")) then
			return true
		end
	end
	return false
end

local function isObstacleVaultable(target)
	local origin = rootPart.Position
	local direction = (target.Position - origin)

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {zombie}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, direction, rayParams)
	if result then
		local part = result.Instance
		local parent = part.Parent
		local grandparent = parent and parent.Parent

		if CollectionService:HasTag(part, "Vaultable") 
			or (parent and CollectionService:HasTag(parent, "Vaultable")) 
			or (grandparent and CollectionService:HasTag(grandparent, "Vaultable")) then
			return true
		end
	end
	return false
end

local function findNearestTarget(pos)
	local best, bestDist = nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and not char:GetAttribute("IsDowned") then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChild("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local d = (hrp.Position - pos).Magnitude
				if d < bestDist then 
					best = hrp 
					bestDist = d 
				end
			end
		end
	end
	return best, bestDist
end

local function computePathAsync(targetPos)
	if isComputing then return end
	isComputing = true
	task.spawn(function()
		local ok = pcall(function() path:ComputeAsync(rootPart.Position, targetPos) end)
		if ok and path.Status == Enum.PathStatus.Success then
			currentWaypoints = path:GetWaypoints()
			waypointIndex = 2
			lastComputedTarget = targetPos
		else
			currentWaypoints = {}
		end
		isComputing = false
	end)
end

local function followPath()
	if #currentWaypoints == 0 or waypointIndex > #currentWaypoints then return false end

	local waypoint = currentWaypoints[waypointIndex]
	local distXZ = getXZDistance(rootPart.Position, waypoint.Position)

	if distXZ < 4.5 then
		waypointIndex += 1
		if waypointIndex > #currentWaypoints then return false end
		waypoint = currentWaypoints[waypointIndex]
	end

	humanoid:MoveTo(waypoint.Position)
	if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
	return true
end

local function performVaultJump(targetPos)
	if isJumping or (os.clock() - lastJumpTime) < 1.0 then return end
	isJumping = true
	lastJumpTime = os.clock()

	humanoid.UseJumpPower = true
	humanoid.JumpPower = 70
	humanoid.Jump = true

	local dir = (targetPos - rootPart.Position)
	local horizontalDir = Vector3.new(dir.X, 0, dir.Z)
	if horizontalDir.Magnitude > 0 then horizontalDir = horizontalDir.Unit end

	rootPart.AssemblyLinearVelocity = Vector3.new(
		horizontalDir.X * 22, 
		42, 
		horizontalDir.Z * 22
	)

	task.delay(0.6, function()
		if humanoid and humanoid.Parent then humanoid.JumpPower = 50 end
		isJumping = false
	end)
end

local function getSmartBreadcrumbTarget(targetPlayer)
	local trail = _G.PlayerTrails and _G.PlayerTrails[targetPlayer]
	if not trail or #trail == 0 then return nil end

	local bestIdx = 1
	local minSearchDist = 30

	for i = #trail, 1, -1 do
		local dist = (rootPart.Position - trail[i]).Magnitude
		if dist < minSearchDist then
			bestIdx = i
			break
		end
	end
	if bestIdx == 1 then
		local closestDist = math.huge
		for i = 1, #trail do
			local dist = (rootPart.Position - trail[i]).Magnitude
			if dist < closestDist then
				closestDist = dist
				bestIdx = i
			end
		end
	end
	local targetIdx = math.min(bestIdx + 3, #trail)
	return trail[targetIdx]
end

local function followBreadcrumbs(targetPlayer)
	local trailTarget = getSmartBreadcrumbTarget(targetPlayer)
	if trailTarget then
		humanoid:MoveTo(trailTarget)
		return true
	end
	return false
end

while true do
	local dt = task.wait(CHECK_INTERVAL)
	if not humanoid or humanoid.Health <= 0 then break end

	if isJumping then
		teleportAnchor = rootPart.Position
		lastPos = rootPart.Position
		stuckTimer = 0
		continue
	end

	if humanoid.WalkSpeed == 0 then
		teleportAnchor = rootPart.Position
		lastPos = rootPart.Position
		continue
	end

	local target, distance = findNearestTarget(rootPart.Position)
	if not target then continue end
	local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)

	if (rootPart.Position - teleportAnchor).Magnitude < TELEPORT_RADIUS then
		teleportTimer += dt
		if teleportTimer >= TELEPORT_TIME then
			teleportTimer = 0
			teleportAnchor = rootPart.Position
			currentWaypoints = {}
			teleportEvent:Fire(zombie)
			continue
		end
	else
		teleportAnchor = rootPart.Position
		teleportTimer = 0
	end

	local movedDistFrame = (rootPart.Position - lastPos).Magnitude
	if movedDistFrame < 0.2 then
		stuckTimer += dt
	else
		stuckTimer = 0
	end
	lastPos = rootPart.Position

	local xzDistance = getXZDistance(rootPart.Position, target.Position)
	local yDiff = target.Position.Y - rootPart.Position.Y

	local isCloseAndBelow = (xzDistance < 4 and yDiff > 2.5 and yDiff < 15)
	local isVaultable = checkVaultableObstacle(target.Position)

	if stuckTimer >= JUMP_STUCK_TIME or (isCloseAndBelow and stuckTimer >= 0.3) or isVaultable then
		currentWaypoints = {}
		lastComputedTarget = nil
		performVaultJump(target.Position)
		stuckTimer = 0
		continue
	end

	local isAboveTarget = (yDiff < -4 and yDiff > -25)
	if isAboveTarget then
		humanoid:MoveTo(target.Position + swarmOffset)
		currentWaypoints = {}
		continue
	end
	if isCloseAndBelow then
		humanoid:MoveTo(target.Position + swarmOffset)
		currentWaypoints = {}

	elseif distance <= STOP_DISTANCE then
		humanoid:MoveTo(target.Position + swarmOffset)
		currentWaypoints = {}

	elseif canMoveDirectly(target) then
		humanoid:MoveTo(target.Position + swarmOffset)
		currentWaypoints = {}

	elseif isObstacleVaultable(target) then
		humanoid:MoveTo(target.Position + swarmOffset)
		currentWaypoints = {}

	else
		local navTarget = target.Position
		local forceBreadcrumb = false

		if stuckTimer >= 0.5 then
			forceBreadcrumb = true
		end

		if distance > 40 and (distance > PATHFINDING_LIMIT or forceBreadcrumb) and targetPlayer then
			local trailTarget = getSmartBreadcrumbTarget(targetPlayer)
			if trailTarget then
				navTarget = trailTarget
			end
		end

		local needsRecompute = false
		if forceBreadcrumb or not lastComputedTarget or (navTarget - lastComputedTarget).Magnitude > TARGET_MOVED_DIST or #currentWaypoints == 0 then
			needsRecompute = true
		end

		if needsRecompute and not isComputing then
			computePathAsync(navTarget)
			if forceBreadcrumb then
				stuckTimer = 0
			end
		end

		local isFollowing = followPath()

		if not isFollowing then
			if distance <= 40 then
				humanoid:MoveTo(target.Position + swarmOffset)
			elseif targetPlayer then
				followBreadcrumbs(targetPlayer)
			end
		end
	end
end