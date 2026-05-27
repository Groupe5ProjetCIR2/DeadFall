-- ============================================================
--  Ce script gère la vue à la première personne (FPS) en ajustant 
--  dynamiquement le décalage de la caméra via des raycasts. Il gère 
--  également la visibilité du corps avec un système d'anti-clipping 
--  optimisé par une mise en cache des éléments du personnage.
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Suspend l'exécution du script de manière asynchrone jusqu'à la fin de la cinématique
if not player:GetAttribute("CinematicFinished") then
	player:GetAttributeChangedSignal("CinematicFinished"):Wait()
end

local RENDER_STEP_OFFSET = "FPS_CameraOffset"
local RENDER_STEP_VISIBILITY = "FPS_Visibility"

-- Fonctions utilitaires pour identifier rapidement les parties du corps et le ViewModel
local function isArm(partName)
	return string.find(partName, "Arm") or string.find(partName, "Hand")
end

local function isHead(partName)
	return partName == "Head" or string.find(partName, "Neck")
end

local function isViewModel(part)
	local current = part
	while current and current ~= workspace and current ~= game do
		if string.find(string.lower(current.Name), "viewmodel") then
			return true
		end
		current = current.Parent
	end
	return false
end

-- Initialise la caméra, le système de cache et les boucles de rendu à l'apparition du personnage
local function setupCharacter(char)
	local humanoid = char:WaitForChild("Humanoid")
	local head = char:WaitForChild("Head")
	local rootPart = char:WaitForChild("HumanoidRootPart")

	RunService:UnbindFromRenderStep(RENDER_STEP_OFFSET)
	RunService:UnbindFromRenderStep(RENDER_STEP_VISIBILITY)

	local defaultOffset = Vector3.new(0, 0, -1.4)

	local camOffsetProxy = humanoid:FindFirstChild("CamOffsetProxy")
	if not camOffsetProxy then
		camOffsetProxy = Instance.new("Vector3Value")
		camOffsetProxy.Name = "CamOffsetProxy"
		camOffsetProxy.Value = defaultOffset
		camOffsetProxy.Parent = humanoid
	end

	-- Configuration du Raycast pour ignorer spécifiquement le joueur et sa propre caméra
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {char, workspace.CurrentCamera}
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- Mise en cache des BaseParts pour optimiser la boucle de visibilité sans utiliser GetDescendants en continu
	local cachedParts = {}

	for _, v in ipairs(char:GetDescendants()) do
		if v:IsA("BasePart") then
			table.insert(cachedParts, v)
		end
	end

	local addedConn = char.DescendantAdded:Connect(function(v)
		if v:IsA("BasePart") then
			table.insert(cachedParts, v)
		end
	end)

	local removingConn = char.DescendantRemoving:Connect(function(v)
		if v:IsA("BasePart") then
			local index = table.find(cachedParts, v)
			if index then
				table.remove(cachedParts, index)
			end
		end
	end)

	humanoid.Died:Connect(function()
		addedConn:Disconnect()
		removingConn:Disconnect()
	end)

	-- Boucle de rendu gérant le déplacement fluide de la caméra et la prévention des collisions avec le décor
	RunService:BindToRenderStep(RENDER_STEP_OFFSET, Enum.RenderPriority.Camera.Value - 1, function(dt)
		if not humanoid or humanoid.Health <= 0 or not head or not rootPart then 
			RunService:UnbindFromRenderStep(RENDER_STEP_OFFSET)
			return 
		end

		local targetOffset = camOffsetProxy.Value
		local targetY = targetOffset.Y
		local targetZ = targetOffset.Z

		local rayDir = (targetZ > 0) and -rootPart.CFrame.LookVector or rootPart.CFrame.LookVector
		local checkDist = math.max(math.abs(targetZ), 2)

		local result = workspace:Raycast(head.Position, rayDir * checkDist, params)
		local finalZ = targetZ

		if result then
			local hitDist = (head.Position - result.Position).Magnitude
			if targetZ > 0 then
				finalZ = math.min(targetZ, hitDist - 0.2)
			else
				finalZ = math.max(targetZ, -(hitDist - 0.2))
			end
		end

		local targetVector = Vector3.new(0, targetY, finalZ)
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(targetVector, math.min(dt * 15, 1))
	end)

	-- Boucle de rendu gérant l'anti-clipping dynamique et la disparition conditionnelle des membres
	RunService:BindToRenderStep(RENDER_STEP_VISIBILITY, Enum.RenderPriority.Camera.Value + 1, function()
		if not humanoid or humanoid.Health <= 0 then 
			RunService:UnbindFromRenderStep(RENDER_STEP_VISIBILITY)
			return 
		end

		local cam = workspace.CurrentCamera
		if not cam then return end
		local camPos = cam.CFrame.Position

		local equippedTool = char:FindFirstChildOfClass("Tool")

		for _, v in ipairs(cachedParts) do
			if v.Parent and not isViewModel(v) then
				local expected = 0 

				if isHead(v.Name) or (v.Parent and v.Parent:IsA("Accessory")) then
					expected = 1
				elseif equippedTool and (v:IsDescendantOf(equippedTool) or isArm(v.Name)) then
					expected = 1
				else
					local distance = (v.Position - camPos).Magnitude
					local threshold = 0.8 

					if string.find(v.Name, "Torso") then
						threshold = 1.0 
					end

					if distance < threshold then
						expected = 1
					end
				end

				if v.LocalTransparencyModifier ~= expected then
					v.LocalTransparencyModifier = expected
				end
			end
		end
	end)
end

if player.Character then
	setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)