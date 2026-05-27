-- ============================================================
-- Ce script gère l'interface et la logique du mini-jeu des câbles électriques (côté client).
-- Il s'occupe du système de glisser-déposer pour relier les fils, gère les animations du menu,
-- valide les connexions, et annule automatiquement la partie si le joueur bouge.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local REMOTES_FOLDER_NAME = "SkillCheckRemotes"
local GUI_NAME = "MinigameGui"
local WIRE_LAYER_NAME = "WireRuntime"
local LEFT_BUTTON_NAMES = { "LW1", "LW2", "LW3", "LW4" }
local RIGHT_BUTTON_NAMES = { "RW1", "RW2", "RW3", "RW4" }

local COLOR_MAP = {
	Red = Color3.fromRGB(255, 84, 84),
	Green = Color3.fromRGB(101, 223, 118),
	Blue = Color3.fromRGB(78, 161, 255),
	Yellow = Color3.fromRGB(255, 212, 74),
}

local DEFAULT_BUTTON_COLOR = Color3.fromRGB(52, 52, 52)
local MATCHED_TRANSPARENCY = 0.35
local DRAG_LINE_THICKNESS = 10
local MATCHED_LINE_THICKNESS = 12

local remotesFolder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME)
local startSkillCheckRemote = remotesFolder:WaitForChild("StartSkillCheck")
local submitAttemptRemote = remotesFolder:WaitForChild("SubmitSkillCheckAttempt")
local skillCheckStateRemote = remotesFolder:WaitForChild("SkillCheckState")

local gui = playerGui:WaitForChild(GUI_NAME)
local mainFrame = gui:WaitForChild("Main")

-- Définit les positions de l'interface pour les animations d'apparition/disparition
local OPEN_POSITION = mainFrame.Position
local CLOSED_POSITION = UDim2.new(
	OPEN_POSITION.X.Scale, OPEN_POSITION.X.Offset,
	OPEN_POSITION.Y.Scale + 1.5, OPEN_POSITION.Y.Offset
)

gui.Enabled = false
mainFrame.Position = CLOSED_POSITION
if mainFrame:IsA("CanvasGroup") then mainFrame.GroupTransparency = 1 end

local wireLayer = mainFrame:FindFirstChild(WIRE_LAYER_NAME)

local startSound = playerGui:FindFirstChild("StartSound", true)
local grabSound = playerGui:FindFirstChild("GrabSound", true)
local missSound = playerGui:FindFirstChild("MissSound", true)
local successSound = playerGui:FindFirstChild("SuccessSound", true)
local winSound = playerGui:FindFirstChild("WinSound", true)

local leftButtons = {}
local rightButtons = {}
local boardState = {
	active = false,
	leftColors = {},
	rightColors = {},
	matched = {},
}

local permanentLines = {}
local dragState = {
	buttonName = nil,
	colorName = nil,
	color = nil,
	pointerPosition = nil,
	hoveredRightButton = nil,
	missedButtons = {},
}

local activeDragLine
local dragConnection

-- Bouton invisible en arrière-plan utilisé uniquement pour forcer le déverrouillage de la souris du joueur
local modalSinker = Instance.new("TextButton")
modalSinker.Name = "MouseUnlocker"
modalSinker.Size = UDim2.fromScale(1, 1)
modalSinker.Position = UDim2.fromScale(0, 0)
modalSinker.BackgroundTransparency = 1
modalSinker.Text = ""
modalSinker.ZIndex = -100 
modalSinker.Visible = false
modalSinker.Parent = gui

local function setMouseLocked(isLocked)
	if isLocked then
		modalSinker.Visible = false
		modalSinker.Modal = false
		UserInputService.MouseIconEnabled = false
	else
		modalSinker.Visible = true
		modalSinker.Modal = true
		UserInputService.MouseIconEnabled = true
	end
end

local function playSound(sound)
	if sound and sound:IsA("Sound") and sound.SoundId ~= "" and sound.SoundId ~= "rbxassetid://0" then
		sound:Play()
	end
end

-- Gère l'affichage de l'interface avec des animations fluides (TweenService) selon la situation (Victoire, Miss, etc.)
local function setGuiVisible(isVisible, animationType)
	if isVisible then
		gui.Enabled = true
		mainFrame.Position = CLOSED_POSITION

		local isCanvasGroup = mainFrame:IsA("CanvasGroup")
		if isCanvasGroup then mainFrame.GroupTransparency = 1 end

		local tInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		local props = {Position = OPEN_POSITION}
		if isCanvasGroup then props.GroupTransparency = 0 end

		TweenService:Create(mainFrame, tInfo, props):Play()
	else
		if animationType == "Win" or animationType == "Fade" then
			local tInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local props = {Position = CLOSED_POSITION}
			local isCanvasGroup = mainFrame:IsA("CanvasGroup")
			if isCanvasGroup then props.GroupTransparency = 1 end

			local closeTween = TweenService:Create(mainFrame, tInfo, props)
			closeTween:Play()

			closeTween.Completed:Once(function()
				if not boardState.active then
					gui.Enabled = false
				end
			end)
		else
			mainFrame.Position = CLOSED_POSITION
			if mainFrame:IsA("CanvasGroup") then mainFrame.GroupTransparency = 1 end
			gui.Enabled = false
		end
	end
end

local function clearContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		child:Destroy()
	end
end

local function ensureWireLayer()
	if wireLayer and wireLayer.Parent then
		return wireLayer
	end

	wireLayer = Instance.new("Frame")
	wireLayer.Name = WIRE_LAYER_NAME
	wireLayer.BackgroundTransparency = 1
	wireLayer.BorderSizePixel = 0
	wireLayer.Size = UDim2.fromScale(1, 1)
	wireLayer.Position = UDim2.fromScale(0, 0)
	wireLayer.ZIndex = 5
	wireLayer.Active = false
	wireLayer.Parent = mainFrame 

	return wireLayer
end

local function getButtonCenter(button)
	local absolutePosition = button.AbsolutePosition
	local absoluteSize = button.AbsoluteSize

	return Vector2.new(
		absolutePosition.X + (absoluteSize.X * 0.5),
		absolutePosition.Y + (absoluteSize.Y * 0.5)
	)
end

local function toContainerPoint(screenPoint)
	local containerPosition = ensureWireLayer().AbsolutePosition

	return Vector2.new(
		screenPoint.X - containerPosition.X,
		screenPoint.Y - containerPosition.Y
	)
end

local function createLine(name, color, thickness)
	local line = Instance.new("Frame")
	line.Name = name
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = color
	line.BorderSizePixel = 0
	line.Size = UDim2.fromOffset(0, thickness)
	line.ZIndex = 6
	line.Parent = ensureWireLayer()

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = line

	return line
end

-- Mathématiques complexes : Calcule la distance et l'angle exacts pour tracer une ligne entre deux points à l'écran
local function updateLine(line, startScreenPoint, endScreenPoint, thickness)
	local startPoint = toContainerPoint(startScreenPoint)
	local endPoint = toContainerPoint(endScreenPoint)
	local delta = endPoint - startPoint
	local midpoint = startPoint + (delta * 0.5)
	local distance = delta.Magnitude
	local angle = math.deg(math.atan2(delta.Y, delta.X))

	line.Position = UDim2.fromOffset(midpoint.X, midpoint.Y)
	line.Size = UDim2.fromOffset(distance, thickness)
	line.Rotation = angle
end

local function setButtonAppearance(button, colorName, isMatched)
	button.BackgroundColor3 = COLOR_MAP[colorName] or DEFAULT_BUTTON_COLOR
	button.Text = ""
	button.AutoButtonColor = not isMatched
	button.Active = not isMatched
	button.BackgroundTransparency = isMatched and MATCHED_TRANSPARENCY or 0
end

local function resetBoardVisuals()
	clearContainer(ensureWireLayer())
	table.clear(permanentLines)

	for _, button in pairs(leftButtons) do
		button.BackgroundColor3 = DEFAULT_BUTTON_COLOR
		button.BackgroundTransparency = 0
		button.Text = ""
		button.Active = true
		button.AutoButtonColor = true
	end

	for _, button in pairs(rightButtons) do
		button.BackgroundColor3 = DEFAULT_BUTTON_COLOR
		button.BackgroundTransparency = 0
		button.Text = ""
		button.Active = true
		button.AutoButtonColor = true
	end
end

local function applyBoardState()
	for buttonName, button in pairs(leftButtons) do
		local colorName = boardState.leftColors[buttonName]
		setButtonAppearance(button, colorName, boardState.matched[buttonName] ~= nil)
	end

	for buttonName, button in pairs(rightButtons) do
		local colorName = boardState.rightColors[buttonName]
		local matchedLeft = boardState.matched[buttonName]
		setButtonAppearance(button, colorName, matchedLeft ~= nil)
	end
end

local function redrawPermanentLines()
	clearContainer(ensureWireLayer())
	table.clear(permanentLines)

	for leftButtonName, rightButtonName in pairs(boardState.matched) do
		if leftButtons[leftButtonName] and rightButtons[rightButtonName] then
			local colorName = boardState.leftColors[leftButtonName]
			local line = createLine(leftButtonName .. "_Match", COLOR_MAP[colorName], MATCHED_LINE_THICKNESS)
			updateLine(
				line,
				getButtonCenter(leftButtons[leftButtonName]),
				getButtonCenter(rightButtons[rightButtonName]),
				MATCHED_LINE_THICKNESS
			)
			permanentLines[leftButtonName] = line
		end
	end
end

local function stopDrag()
	if dragConnection then
		dragConnection:Disconnect()
		dragConnection = nil
	end

	if activeDragLine then
		activeDragLine:Destroy()
		activeDragLine = nil
	end

	dragState.buttonName = nil
	dragState.colorName = nil
	dragState.color = nil
	dragState.pointerPosition = nil
	dragState.hoveredRightButton = nil
	table.clear(dragState.missedButtons)
end

-- Annule proprement le mini-jeu, prévient le serveur et ferme l'interface en douceur
local function cancelMiniGame()
	if not boardState.active then return end

	submitAttemptRemote:FireServer("Cancel", "Cancel") 
	boardState.active = false
	setGuiVisible(false, "Fade")
	setMouseLocked(true)
	stopDrag()
end

local function findRightButtonAtPosition(screenPosition)
	for buttonName, button in pairs(rightButtons) do
		local pos = button.AbsolutePosition
		local size = button.AbsoluteSize

		if screenPosition.X >= pos.X and screenPosition.X <= pos.X + size.X then
			if screenPosition.Y >= pos.Y and screenPosition.Y <= pos.Y + size.Y then
				return buttonName
			end
		end
	end
	return nil
end

-- Coeur du jeu : Vérifie en permanence où se trouve le fil tiré par le joueur pour valider ou faire échouer la connexion
local function updateDragLine()
	if not activeDragLine or not dragState.buttonName or not dragState.pointerPosition then
		return
	end

	local startButton = leftButtons[dragState.buttonName]
	if not startButton then
		return
	end

	updateLine(activeDragLine, getButtonCenter(startButton), dragState.pointerPosition, DRAG_LINE_THICKNESS)

	local hoveredRightButton = findRightButtonAtPosition(dragState.pointerPosition)
	if not hoveredRightButton then
		dragState.hoveredRightButton = nil
		return
	end

	if boardState.matched[hoveredRightButton] or dragState.missedButtons[hoveredRightButton] then
		return
	end

	dragState.hoveredRightButton = hoveredRightButton
	local leftColor = dragState.colorName
	local rightColor = boardState.rightColors[hoveredRightButton]

	-- Si le joueur connecte les mauvaises couleurs : Echec du mini-jeu
	if leftColor ~= rightColor then
		dragState.missedButtons[hoveredRightButton] = true
		playSound(missSound)

		boardState.active = false
		setGuiVisible(false, "Miss")
		setMouseLocked(true)

		submitAttemptRemote:FireServer("Cancel", "Cancel")
		stopDrag()
		return
	end

	-- Si c'est bon, on sauvegarde la paire connectée
	boardState.matched[dragState.buttonName] = hoveredRightButton
	boardState.matched[hoveredRightButton] = dragState.buttonName

	local totalMatches = 0
	for _, _ in pairs(boardState.matched) do
		totalMatches = totalMatches + 1
	end
	local pairsConnected = totalMatches / 2

	-- Victoire si les 4 câbles sont reliés
	if pairsConnected >= 4 then
		playSound(winSound)
		boardState.active = false
		setGuiVisible(false, "Win")
		setMouseLocked(true)
	end

	submitAttemptRemote:FireServer(dragState.buttonName, hoveredRightButton)
	stopDrag()
end

local function beginDrag(leftButtonName, inputObject)
	if not boardState.active then return end
	if boardState.matched[leftButtonName] then return end

	local colorName = boardState.leftColors[leftButtonName]
	if not colorName then return end

	stopDrag()

	dragState.buttonName = leftButtonName
	dragState.colorName = colorName
	dragState.color = COLOR_MAP[colorName]
	dragState.pointerPosition = Vector2.new(inputObject.Position.X, inputObject.Position.Y)
	activeDragLine = createLine(leftButtonName .. "_Drag", dragState.color, DRAG_LINE_THICKNESS)
	playSound(grabSound)

	dragConnection = RunService.RenderStepped:Connect(updateDragLine)
	updateDragLine()
end

local function releaseDrag()
	stopDrag()
end

local function bindLeftButton(buttonName, button)
	button.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1
			and inputObject.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		beginDrag(buttonName, inputObject)
	end)
end

local function connectInputTracking()
	UserInputService.InputChanged:Connect(function(inputObject)
		if not dragState.buttonName then return end

		if inputObject.UserInputType ~= Enum.UserInputType.MouseMovement
			and inputObject.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		dragState.pointerPosition = Vector2.new(inputObject.Position.X, inputObject.Position.Y)
	end)

	UserInputService.InputEnded:Connect(function(inputObject)
		if not dragState.buttonName then return end

		if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1
			and inputObject.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		releaseDrag()
	end)
end

local function loadReferences()
	for _, buttonName in ipairs(LEFT_BUTTON_NAMES) do
		local button = mainFrame:WaitForChild(buttonName)
		leftButtons[buttonName] = button
		bindLeftButton(buttonName, button)
	end

	for _, buttonName in ipairs(RIGHT_BUTTON_NAMES) do
		rightButtons[buttonName] = mainFrame:WaitForChild(buttonName)
	end

	local closeButton = mainFrame:WaitForChild("CloseButton", 5)
	if closeButton and closeButton:IsA("GuiButton") then
		closeButton.MouseButton1Click:Connect(function()
			cancelMiniGame()
		end)
	end

	connectInputTracking()
end

local function resetBoardState()
	boardState.active = false
	table.clear(boardState.leftColors)
	table.clear(boardState.rightColors)
	table.clear(boardState.matched)
	stopDrag()
	resetBoardVisuals()
end

-- Initialise le mini-jeu à la réception de l'ordre du serveur avec les couleurs aléatoires générées
local function applyStartPayload(payload)
	resetBoardState()
	boardState.active = true

	for buttonName, colorName in pairs(payload.leftColors or {}) do
		boardState.leftColors[buttonName] = colorName
	end

	for buttonName, colorName in pairs(payload.rightColors or {}) do
		boardState.rightColors[buttonName] = colorName
	end

	applyBoardState()
	redrawPermanentLines()
	setGuiVisible(true, "Open")

	setMouseLocked(false)
	playSound(startSound)

	-- Sécurité : empêche de lancer le jeu si le joueur est en plein mouvement
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		if hum and hum.MoveDirection.Magnitude > 0 then
			cancelMiniGame()
		end
	end
end

-- Met à jour l'état du jeu selon les réponses du serveur (validation de connexion, défaite, victoire)
local function applyStatePayload(payload)
	if typeof(payload) ~= "table" then return end

	if not boardState.active and (payload.result == "win" or payload.result == "matched" or payload.result == "miss") then
		return
	end

	table.clear(boardState.matched)

	for leftButtonName, rightButtonName in pairs(payload.matched or {}) do
		boardState.matched[leftButtonName] = rightButtonName
		boardState.matched[rightButtonName] = leftButtonName
	end

	applyBoardState()
	redrawPermanentLines()

	if payload.result == "matched" then
		playSound(successSound)
	elseif payload.result == "miss" then
		playSound(missSound)
		boardState.active = false
		setGuiVisible(false, "Miss")
		setMouseLocked(true)
	elseif payload.result == "win" then
		playSound(winSound)
		boardState.active = false
		setGuiVisible(false, "Win")
		setMouseLocked(true)
	elseif payload.result == "cancelled" then
		boardState.active = false
		setGuiVisible(false, "Miss")
		setMouseLocked(true)
	end
end

resetBoardState()
loadReferences()

startSkillCheckRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	applyStartPayload(payload)
end)

skillCheckStateRemote.OnClientEvent:Connect(applyStatePayload)

-- Tracker de mouvement : Annule automatiquement l'interface si le joueur se met à marcher pendant le mini-jeu
local function setupMovementTracking(character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if boardState.active and humanoid.MoveDirection.Magnitude > 0 then
			cancelMiniGame()
		end
	end)
end

if player.Character then
	setupMovementTracking(player.Character)
end
player.CharacterAdded:Connect(setupMovementTracking)