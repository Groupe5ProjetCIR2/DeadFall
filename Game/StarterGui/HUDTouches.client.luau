-- ============================================================
-- Ce script crée l'interface des contrôles (HUD) à l'écran (Sprint, Saut, Recharge).
-- Il affiche dynamiquement l'option "Glissade" (Slide) uniquement quand le joueur court,
-- et change la couleur des touches à l'écran lorsqu'elles sont physiquement pressées.
-- ============================================================

-- Place ce script dans un LocalScript (ex: StarterPlayerScripts ou StarterGui)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MovementHUDGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainContainer = Instance.new("Frame")
mainContainer.Name = "HUDContainer"
mainContainer.Size = UDim2.new(0, 200, 0, 200) 
mainContainer.Position = UDim2.new(1, -30, 0.5, 0) 
mainContainer.AnchorPoint = Vector2.new(1, 0.5) 
mainContainer.BackgroundTransparency = 1
mainContainer.Parent = screenGui

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 8)
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
listLayout.Parent = mainContainer

-- Fonction réutilisable pour générer l'UI de chaque touche de manière uniforme sans répéter de code
local function createKeyRow(keyText, actionText, layoutOrder)
	local row = Instance.new("Frame")
	row.Name = actionText .. "Row"
	row.Size = UDim2.new(1, 0, 0, 32)
	row.BackgroundTransparency = 1
	row.LayoutOrder = layoutOrder

	local alignmentFrame = Instance.new("Frame")
	alignmentFrame.Name = "AlignmentFrame"
	alignmentFrame.Size = UDim2.new(1, 0, 1, 0)
	alignmentFrame.BackgroundTransparency = 1
	alignmentFrame.Parent = row

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 12)
	rowLayout.Parent = alignmentFrame

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "ActionLabel"
	actionLabel.Size = UDim2.new(0, 100, 1, 0) 
	actionLabel.BackgroundTransparency = 1
	actionLabel.Font = Enum.Font.Michroma
	actionLabel.Text = string.upper(actionText)
	actionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionLabel.TextSize = 13
	actionLabel.TextXAlignment = Enum.TextXAlignment.Right 
	actionLabel.Parent = alignmentFrame

	local keyBox = Instance.new("Frame")
	keyBox.Name = "KeyBox"
	keyBox.Size = UDim2.new(0, 45, 0, 32) 
	keyBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	keyBox.BorderSizePixel = 0
	keyBox.BackgroundTransparency = 0.5
	keyBox.Parent = alignmentFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = keyBox

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyLabel"
	keyLabel.Size = UDim2.new(1, 0, 1, 0)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Font = Enum.Font.Michroma
	keyLabel.Text = string.upper(keyText)
	keyLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	keyLabel.TextSize = 10
	keyLabel.Parent = keyBox

	row.Parent = mainContainer
	return row
end

local sprintRow = createKeyRow("Shift", "Sprint", 1)
local jumpRow = createKeyRow("Space", "Jump", 2)
local reloadRow = createKeyRow("R", "Reload", 3)
local slideRow = createKeyRow("C", "Slide", 4)

slideRow.Visible = false
slideRow.Size = UDim2.new(1, 0, 0, 0)

local slideVisible = false

-- Gère l'apparition et la disparition fluides de la ligne "Slide"
local function setSlideVisibility(visible)
	if slideVisible == visible then return end
	slideVisible = visible

	if visible then
		slideRow.Visible = true
		TweenService:Create(slideRow, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 0, 32)
		}):Play()
	else
		local tween = TweenService:Create(slideRow, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(1, 0, 0, 0)
		})
		tween:Play()
		tween.Completed:Connect(function()
			if not slideVisible then
				slideRow.Visible = false
			end
		end)
	end
end

-- Boucle exécutée à chaque frame (Heartbeat) pour vérifier en continu si le joueur remplit les conditions de la glissade
-- Boucle exécutée à chaque frame pour vérifier les conditions d'affichage
RunService.Heartbeat:Connect(function()
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")

		if humanoid and humanoid.Health > 0 and rootPart then
			-- Vérifier si le joueur est au sol (si FloorMaterial est vide, il est en l'air)
			local isGrounded = humanoid.FloorMaterial ~= Enum.Material.Air

			-- Gestion Sprint et Slide (cachés si en l'air)
			if isGrounded then
				local isPressingSprint = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) 
					or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
					or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2)

				local isMoving = humanoid.MoveDirection.Magnitude > 0

				-- Afficher le sprint
				sprintRow.Visible = true

				-- Afficher le slide seulement si on court ET qu'on bouge
				if isPressingSprint and isMoving then
					setSlideVisibility(true)
				else
					setSlideVisibility(false)
				end
			else
				-- Si on est en l'air, on cache tout ce qui ne sert pas
				sprintRow.Visible = false
				setSlideVisibility(false)
			end
		else
			sprintRow.Visible = false
			setSlideVisibility(false)
		end
	end
end)


-- Relie l'UI à l'appui physique des touches pour appliquer un retour visuel (changement de couleur)
local function setupKeyFeedback(row, key)
	local alignmentFrame = row:FindFirstChild("AlignmentFrame")
	local keyBox = alignmentFrame and alignmentFrame:FindFirstChild("KeyBox")
	local keyLabel = keyBox and keyBox:FindFirstChild("KeyLabel")

	if not keyBox or not keyLabel then return end

	local function updateVisual(pressed)
		local targetColor = pressed and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(255, 255, 255)
		local targetTextColor = pressed and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)

		TweenService:Create(keyBox, TweenInfo.new(0.08), {BackgroundColor3 = targetColor}):Play()
		TweenService:Create(keyLabel, TweenInfo.new(0.08), {TextColor3 = targetTextColor}):Play()
	end

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == key or (key == Enum.KeyCode.LeftShift and input.KeyCode == Enum.KeyCode.ButtonL2) then
			updateVisual(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == key or (key == Enum.KeyCode.LeftShift and input.KeyCode == Enum.KeyCode.ButtonL2) then
			updateVisual(false)
		end
	end)
end

setupKeyFeedback(sprintRow, Enum.KeyCode.LeftShift)
setupKeyFeedback(jumpRow, Enum.KeyCode.Space)
setupKeyFeedback(reloadRow, Enum.KeyCode.R)
setupKeyFeedback(slideRow, Enum.KeyCode.C)