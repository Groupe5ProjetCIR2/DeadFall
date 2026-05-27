-- ============================================================
-- IA d'un Boss Zombie : Gère le déplacement intelligent vers le 
-- joueur le plus proche avec un système de pathfinding (évitement d'obstacles)
-- et une logique de téléportation si le boss est coincé ou trop loin.
-- ============================================================

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local zombie = script.Parent
local rootPart = zombie:WaitForChild("HumanoidRootPart")
local humanoid = zombie:WaitForChild("Zombie")
local spawnFolder = workspace:FindFirstChild("CyborgSpawns")
rootPart:SetNetworkOwner(nil)

-- ============================================================
-- CONFIGURATION
-- ============================================================
local STOP_DISTANCE      = 8
local CHECK_INTERVAL     = 0.15
local RECOMPUTE_INTERVAL = 1.2

-- Téléportation en dernier recours (15s bloqué, 100m+ du joueur)
local TELEPORT_STUCK_TIME   = 5.0
local TELEPORT_MIN_DIST     = 100.0

-- Détection de blocage
local STUCK_DIST        = 0.5
local STUCK_TIME_REPATH = 2.0   -- Recalcul du chemin après 2s bloqué
local STUCK_TIME_DIRECT = 5.0   -- Tentative chemin direct après 5s bloqué

local lastPos    = rootPart.Position
local stuckTimer = 0

local currentWaypoints = {}
local waypointIndex    = 2
local currentTarget    = nil
local isComputing      = false

-- ============================================================
-- PATHFINDING (Boss double taille, ne saute pas)
-- ============================================================
local path = PathfindingService:CreatePath({
	AgentCanJump    = false,
	AgentHeight     = 6, 
	AgentRadius     = 4,
	AgentCanClimb   = false,
	WaypointSpacing = 3,
	Costs = {
		ZoneInterdite = math.huge,
	}
})

local teleportEvent = game:GetService("ServerStorage"):WaitForChild("TeleportZombie")


-- ============================================================
-- UTILITAIRES
-- ============================================================
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
					best     = hrp
					bestDist = d
				end
			end
		end
	end
	return best, bestDist
end

local function tryTeleport()
	if not spawnFolder then return end

	local target, _ = findNearestTarget(rootPart.Position)
	if not target then return end

	local spawnParts = spawnFolder:GetChildren()
	local validParts = {}

	for _, part in ipairs(spawnParts) do
		local dist = (part.Position - target.Position).Magnitude
		if dist >= 100 and dist <= 150 then
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = {zombie}
			rayParams.FilterType = Enum.RaycastFilterType.Exclude

			local dir = (part.Position - target.Position)
			local result = workspace:Raycast(target.Position, dir, rayParams)

			if result then
				table.insert(validParts, part)
			end
		end
	end
	if #validParts == 0 then
		for _, part in ipairs(spawnParts) do
			local dist = (part.Position - target.Position).Magnitude
			if dist >= 100 and dist <= 150 then
				table.insert(validParts, part)
			end
		end
	end
	if #validParts == 0 then
		local best, bestDist = nil, math.huge
		for _, part in ipairs(spawnParts) do
			local dist = (part.Position - target.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				best = part
			end
		end
		if best then table.insert(validParts, best) end
	end

	if #validParts > 0 then
		local chosen = validParts[math.random(1, #validParts)]
		zombie:PivotTo(CFrame.new(chosen.Position + Vector3.new(0, 10, 0)))
		stuckTimer = 0
		currentWaypoints = {}
		currentTarget = nil
	end
end

-- Ligne de vue directe (pas de hauteur excessive)
local function canSeeTarget(target)
	local origin    = rootPart.Position
	local direction = target.Position - origin
	if direction.Y > 5 then return false end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {zombie}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, direction, rayParams)
	if not result then return true end
	if result.Instance:IsDescendantOf(target.Parent) then return true end

	return false
end

-- ============================================================
-- PATHFINDING INTERNE
-- ============================================================

local function computePath(target)
	if isComputing then return false end
	isComputing = true

	local ok = pcall(function()
		path:ComputeAsync(rootPart.Position, target.Position)
	end)

	isComputing = false

	if ok and path.Status == Enum.PathStatus.Success then
		currentWaypoints = path:GetWaypoints()
		waypointIndex    = 2
		currentTarget    = target
		return true
	end
	currentWaypoints = {}
	humanoid:MoveTo(target.Position)
	return false
end

path.Blocked:Connect(function(blockedIdx)
	if blockedIdx >= waypointIndex then
		currentWaypoints = {}
		currentTarget    = nil
	end
end)

local function followPath()
	if waypointIndex > #currentWaypoints then return false end

	local waypoint = currentWaypoints[waypointIndex]
	local dist     = (rootPart.Position - waypoint.Position).Magnitude

	if dist < 5 then
		waypointIndex += 1
		if waypointIndex > #currentWaypoints then return false end
		waypoint = currentWaypoints[waypointIndex]
	end

	humanoid:MoveTo(waypoint.Position)
	return true
end

-- ============================================================
-- BOUCLE PRINCIPALE
-- ============================================================
local recomputeTimer = 0

while true do
	task.wait(CHECK_INTERVAL)
	if not humanoid or humanoid.Health <= 0 then break end

	local target, distance = findNearestTarget(rootPart.Position)
	if not target then continue end

	-- Arrêt au corps à corps
	if distance <= STOP_DISTANCE then
		humanoid:MoveTo(rootPart.Position)
		currentWaypoints = {}
		stuckTimer = 0
		lastPos    = rootPart.Position
		continue
	end

	local movedDist = (rootPart.Position - lastPos).Magnitude
	if movedDist < STUCK_DIST then
		stuckTimer += CHECK_INTERVAL
	else
		stuckTimer = 0
		lastPos    = rootPart.Position
	end

	if distance >= 300 then
		tryTeleport()
		continue
	end

	-- Recalcul forcé si bloqué depuis 2s
	if stuckTimer >= TELEPORT_STUCK_TIME then
		tryTeleport()
		continue
	end

	recomputeTimer += CHECK_INTERVAL

	-- === LIGNE DE VUE DIRECTE ===
	if canSeeTarget(target) then
		humanoid:MoveTo(target.Position)
		currentWaypoints = {}
		recomputeTimer   = 0
		continue
	end

	-- === PATHFINDING ===
	if recomputeTimer >= RECOMPUTE_INTERVAL or currentTarget ~= target then
		recomputeTimer = 0
		computePath(target)
	end

	if not followPath() then
		computePath(target)
	end
end