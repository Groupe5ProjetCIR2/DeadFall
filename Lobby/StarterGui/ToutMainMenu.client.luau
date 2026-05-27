-- ============================================================
--  Ce script gère l'interface utilisateur complexe du menu
--  principal et la séquence d'introduction cinématique.
--  Il coordonne les transitions de caméra, les animations
--  de fondu et la logique de gestion des lobbies en temps réel.
-- ============================================================

local ts = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
UserInputService.MouseIconEnabled = false

local player = Players.LocalPlayer
if not player then
	player = Players:WaitForChild(Players.LocalPlayer.Name, 10)
end

local playerGui = player:WaitForChild("PlayerGui", 10)

local introGui = Instance.new("ScreenGui")
introGui.Name = "IntroSequenceGui"
introGui.IgnoreGuiInset = true
introGui.DisplayOrder = 1000
introGui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
bg.BackgroundTransparency = 0
bg.Parent = introGui

local mainMenuCyborg = playerGui:WaitForChild("MainMenuCyborg", 10)

local getLobbyPlayersFunc = ReplicatedStorage:WaitForChild("GetMyLobbyPlayers")

local function SetOtherPlayersVisibility(isVisible)
	if isVisible then
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer ~= player and otherPlayer.Character then
				for _, part in ipairs(otherPlayer.Character:GetDescendants()) do
					if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
						part.Transparency = 0
					elseif part:IsA("Decal") then 
						part.Transparency = 0
					elseif part:IsA("BillboardGui") then 
						part.Enabled = true
					end
				end
			end
		end
		return
	end

	local myLobbyPlayers = getLobbyPlayersFunc:InvokeServer()

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			local isTeammate = table.find(myLobbyPlayers, otherPlayer)

			for _, part in ipairs(otherPlayer.Character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Transparency = isTeammate and 0 or 1
				elseif part:IsA("Decal") then 
					part.Transparency = isTeammate and 0 or 1
				elseif part:IsA("BillboardGui") then 
					part.Enabled = isTeammate and true or false
				end
			end
		end
	end
end

local camera = Workspace.CurrentCamera
if not camera then
	camera = Workspace:WaitForChild("CurrentCamera", 10)
end
camera.CameraType = Enum.CameraType.Scriptable

local camFolder = Workspace:WaitForChild("Cameras", 10)
if not camFolder then return end

local cam1 = camFolder:WaitForChild("cam1", 10)
local cam2 = camFolder:WaitForChild("cam2", 10)
local cam3 = camFolder:WaitForChild("cam3", 10)
local cam4 = camFolder:WaitForChild("cam4", 10)
local cam5 = camFolder:WaitForChild("cam5", 10)
local cam6 = camFolder:WaitForChild("cam6", 10)
local cam7 = camFolder:WaitForChild("cam7", 10)
local cam8 = camFolder:WaitForChild("cam8", 10)

local hangarTP = Workspace:WaitForChild("HangarTP", 10)
local tp1 = hangarTP and hangarTP:WaitForChild("TP1", 10)

local tp5 = Workspace:WaitForChild("TP5", 10)

local workspaceModel = Workspace:WaitForChild("Model", 10)
local head = workspaceModel and workspaceModel:WaitForChild("Head", 10)
local electricSound = head and head:WaitForChild("electricsound", 10)
local defaultVolume = electricSound and electricSound.Volume or 0.5 

local hoverSound = SoundService:WaitForChild("hover", 10)

local targetImageLabels = {}
local targetPartNames = {"Part7", "Part8", "Part9", "Part10", "Part11", "Part12"}

for _, partName in ipairs(targetPartNames) do
	local part = Workspace:FindFirstChild(partName) or Workspace:WaitForChild(partName, 5)
	if part then
		local surfaceGui = part:WaitForChild("SurfaceGui", 5)
		if surfaceGui then
			local frame = surfaceGui:WaitForChild("Frame", 5)
			if frame then
				local imgLabel = frame:WaitForChild("ImageLabel", 5)
				if imgLabel then table.insert(targetImageLabels, imgLabel) end
			end
		end
	end
end

local targetPhysicalParts = {}
local physicalPartNames = {"test", "test2", "test3"}

for _, partName in ipairs(physicalPartNames) do
	local part = Workspace:FindFirstChild(partName) or Workspace:WaitForChild(partName, 5)
	if part and part:IsA("BasePart") then
		table.insert(targetPhysicalParts, part)
	end
end

local lobbySystem = Workspace:WaitForChild("LobbySystem", 10)
local partySurfaceGui = lobbySystem and lobbySystem:WaitForChild("SurfaceGui", 5)
local partyFrame = partySurfaceGui and partySurfaceGui:WaitForChild("PartyFrame", 5)
local mainLobby = partySurfaceGui and partySurfaceGui.PartyFrame.Main.Panel.LobbyText.Lobby.MainLobby

local savedTransparencies = {}

local function SaveTransparencies(mainElement)
	if not mainElement then return end
	savedTransparencies[mainElement] = {
		bg = mainElement:IsA("GuiObject") and mainElement.BackgroundTransparency or nil,
		txt = (mainElement:IsA("TextLabel") or mainElement:IsA("TextButton") or mainElement:IsA("TextBox")) and mainElement.TextTransparency or nil,
		img = (mainElement:IsA("ImageLabel") or mainElement:IsA("ImageButton")) and mainElement.ImageTransparency or nil,
		stroke = mainElement:IsA("UIStroke") and mainElement.Transparency or nil
	}
	for _, element in ipairs(mainElement:GetDescendants()) do
		if element:IsA("GuiObject") or element:IsA("UIStroke") then
			savedTransparencies[element] = {
				bg = element:IsA("GuiObject") and element.BackgroundTransparency or nil,
				txt = (element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox")) and element.TextTransparency or nil,
				img = (element:IsA("ImageLabel") or element:IsA("ImageButton")) and element.ImageTransparency or nil,
				stroke = element:IsA("UIStroke") and element.Transparency or nil
			}
		end
	end
end

local function PlayFade(mainElement, isFadingIn, duration)
	if not mainElement then return end
	local ti = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local elementsToFade = mainElement:GetDescendants()
	table.insert(elementsToFade, mainElement)

	for _, element in ipairs(elementsToFade) do
		if savedTransparencies[element] then
			local data = savedTransparencies[element]
			local tweenProps = {}

			if data.bg ~= nil then tweenProps.BackgroundTransparency = isFadingIn and data.bg or 1 end
			if data.txt ~= nil then tweenProps.TextTransparency = isFadingIn and data.txt or 1 end
			if data.img ~= nil then tweenProps.ImageTransparency = isFadingIn and data.img or 1 end
			if data.stroke ~= nil then tweenProps.Transparency = isFadingIn and data.stroke or 1 end

			if next(tweenProps) ~= nil then
				ts:Create(element, ti, tweenProps):Play()
			end
		end
	end
end

if partyFrame then
	SaveTransparencies(partyFrame)
	PlayFade(partyFrame, false, 0)
	partyFrame.Visible = false
end

local startTravelingCFrame = CFrame.new(519.880798, 98.4646683, 533.809937, -0.998532355, 0.00593823614, 0.0538324043, 4.65661287e-10, 0.993970871, -0.109644614, -0.0541589372, -0.109483697, -0.992512047)

local quickTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
local audioTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local uiTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local blinkTweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local baseCFrame = Instance.new("CFrameValue")
baseCFrame.Value = startTravelingCFrame
local currentTween = nil

local MaxRotation = math.rad(6)
local MaxRotationZ = math.rad(4)
local Smoothness = 0.08
local CurrentX, CurrentY, CurrentZ = 0, 0, 0

local function TransitionTo(targetCam)
	if currentTween then currentTween:Cancel() end
	currentTween = ts:Create(baseCFrame, quickTweenInfo, {Value = targetCam.CFrame})
	currentTween:Play()
end

local mouse = player:GetMouse()
if not mouse or mouse.ViewSizeX == 0 then
	repeat task.wait(); mouse = player:GetMouse() until mouse and mouse.ViewSizeX ~= 0
end

RunService.RenderStepped:Connect(function()
	local viewportSize = camera.ViewportSize
	local centerX = viewportSize.X / 2
	local centerY = viewportSize.Y / 2
	local normX = math.clamp((mouse.X - centerX) / centerX, -1, 1)
	local normY = math.clamp((mouse.Y - centerY) / centerY, -1, 1)

	local targetX = -normX * MaxRotation
	local targetY = -normY * MaxRotation
	local targetZ = (normX + normY) / 2 * MaxRotationZ

	CurrentX = CurrentX + (targetX - CurrentX) * Smoothness
	CurrentY = CurrentY + (targetY - CurrentY) * Smoothness
	CurrentZ = CurrentZ + (targetZ - CurrentZ) * Smoothness

	camera.CFrame = baseCFrame.Value * CFrame.Angles(CurrentY, CurrentX, CurrentZ)
end)

local cyborgMode = mainMenuCyborg and mainMenuCyborg:WaitForChild("CyborgMode", 10)
local versusMode = mainMenuCyborg and mainMenuCyborg:WaitForChild("VersusMode", 10)
local createCyborgMode = mainMenuCyborg and mainMenuCyborg:WaitForChild("CreateCyborgMode", 10)
local createPersonnageCyborgMode = mainMenuCyborg and mainMenuCyborg:WaitForChild("CreatePersonnageCyborgMode", 10)
local joinCyborgMode = mainMenuCyborg and mainMenuCyborg:WaitForChild("JoinCyborgMode", 10)
local createCyborgModeCeluiJoin = mainMenuCyborg and mainMenuCyborg:WaitForChild("CreateCyborgModeCeluiJoin", 10)

if createCyborgMode then createCyborgMode.Visible = false end
if createPersonnageCyborgMode then createPersonnageCyborgMode.Visible = false end
if joinCyborgMode then joinCyborgMode.Visible = false end
if createCyborgModeCeluiJoin then createCyborgModeCeluiJoin.Visible = false end

local joinCyborgBackBtn = joinCyborgMode and joinCyborgMode:WaitForChild("Back", 10)
local guestLeaveBtn = createCyborgModeCeluiJoin and createCyborgModeCeluiJoin:WaitForChild("Leave", 10)

local zektonFont = Font.new("rbxasset://fonts/families/Zekton.json")

local devLabel = versusMode and versusMode:WaitForChild("Dev", 10)

if devLabel then
	devLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	devLabel.Position = UDim2.new(0.5, 0, 0.5, 0) 
	devLabel.Size = UDim2.new(0, 240, 0, 28) 

	devLabel.Text = "IN DEVELOPMENT"
	devLabel.FontFace = Font.new("rbxasset://fonts/families/Zekton.json", Enum.FontWeight.Bold)
	devLabel.TextScaled = true 
	devLabel.TextColor3 = Color3.fromRGB(255, 255, 255) 
	devLabel.TextXAlignment = Enum.TextXAlignment.Center 
	devLabel.BackgroundTransparency = 1
	devLabel.ZIndex = 11

	local stroke = devLabel:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = devLabel
	end
	stroke.Color = Color3.fromRGB(255, 255, 255) 
	stroke.Thickness = 1.2
	stroke.Transparency = 0.6

	local pulseInfo = TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	ts:Create(devLabel, pulseInfo, {TextTransparency = 0.2}):Play()
	ts:Create(stroke, pulseInfo, {Transparency = 0.9}):Play()
end

local skipStep = 0
local stage1Thread
local stage2Thread

local skipButton = Instance.new("TextButton")
skipButton.Name = "CinematicSkipButton"
skipButton.Size = UDim2.new(1, 0, 1, 0)
skipButton.BackgroundTransparency = 1
skipButton.Text = ""
skipButton.ZIndex = 100
skipButton.Parent = introGui

local deadFallLogo
local introSound = script:FindFirstChild("IntroSound")

local activeCamBase = cam4

local function HideMenus()
	if mainMenuCyborg then
		if mainMenuCyborg:IsA("LayerCollector") then mainMenuCyborg.Enabled = false end
		for _, child in ipairs(mainMenuCyborg:GetDescendants()) do
			if child:IsA("LayerCollector") then child.Enabled = false end
		end
	end
end

local function finishStage2()
	if currentTween then 
		currentTween:Cancel() 
	end

	baseCFrame.Value = cam1.CFrame
	camera.CFrame = cam1.CFrame

	if introGui then introGui:Destroy() end 

	if electricSound then
		local defRange = electricSound:GetAttribute("DefaultRange")
		if defRange then
			ts:Create(electricSound, TweenInfo.new(1), {RollOffMaxDistance = defRange}):Play()
		end
	end

	local versusSound = Workspace:FindFirstChild("VersusPnj2") and Workspace.VersusPnj2:FindFirstChild("Head") and Workspace.VersusPnj2.Head:FindFirstChild("electricsound1")
	if versusSound then
		local defVol = versusSound:GetAttribute("DefaultVolume") or 0.5
		ts:Create(versusSound, TweenInfo.new(1), {Volume = defVol}):Play()
	end

	if mainMenuCyborg then
		if mainMenuCyborg:IsA("LayerCollector") then mainMenuCyborg.Enabled = true end
		for _, child in ipairs(mainMenuCyborg:GetDescendants()) do
			if child:IsA("LayerCollector") then child.Enabled = true end
		end
	end
	UserInputService.MouseIconEnabled = true
end

local function runStage2()
	local startPullBackCFrame = CFrame.new(551.434082, 14.7636604, 518.570923, 0.998996794, -0.00202641403, -0.044736851, 2.32830644e-10, 0.998975754, -0.0452499054, 0.0447827205, 0.045204509, 0.997973502)
	baseCFrame.Value = startPullBackCFrame

	HideMenus()

	local fadeOutBg = ts:Create(bg, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
	fadeOutBg:Play()

	if electricSound then
		local defVol = electricSound:GetAttribute("DefaultVolume") or 0.5
		if not electricSound:GetAttribute("DefaultRange") then
			electricSound:SetAttribute("DefaultRange", electricSound.RollOffMaxDistance)
		end
		local targetRange = electricSound:GetAttribute("DefaultRange") * 2
		ts:Create(electricSound, TweenInfo.new(1.5), {Volume = defVol, RollOffMaxDistance = targetRange}):Play()
	end

	local panSpeed = 1
	local flashSpeed = 0.35

	local function moveTo(target, speed, style)
		if currentTween then currentTween:Cancel() end
		currentTween = ts:Create(baseCFrame, TweenInfo.new(speed, style or Enum.EasingStyle.Linear), {Value = (typeof(target) == "CFrame" and target or target.CFrame)})
		currentTween:Play()
		currentTween.Completed:Wait()
	end

	activeCamBase = cam4
	moveTo(cam4, 2.2, Enum.EasingStyle.Sine)

	activeCamBase = cam3
	moveTo(cam3, flashSpeed, Enum.EasingStyle.Sine)
	moveTo(cam3.CFrame * CFrame.new(3,0,0), panSpeed)

	activeCamBase = cam7
	moveTo(cam7, flashSpeed, Enum.EasingStyle.Sine)
	moveTo(cam7.CFrame * CFrame.new(3,0,0), panSpeed)

	activeCamBase = cam2
	moveTo(cam2, flashSpeed, Enum.EasingStyle.Sine)
	moveTo(cam2.CFrame * CFrame.new(3,0,0), panSpeed)

	activeCamBase = cam1
	moveTo(cam1, 0.6, Enum.EasingStyle.Quart)

	if skipStep < 2 then
		skipStep = 2
		finishStage2()
	end
end

local function finishStage1()
	if deadFallLogo then deadFallLogo:Destroy() end
	if introSound then introSound:Stop() end

	stage2Thread = task.spawn(runStage2)
end

local function runStage1()
	HideMenus()

	repeat task.wait() until _G.TerminalFinished == true

	HideMenus()

	bg.BackgroundTransparency = 0

	if currentTween then currentTween:Cancel() end
	baseCFrame.Value = startTravelingCFrame
	camera.CFrame = startTravelingCFrame

	deadFallLogo = script:WaitForChild("DeadFall"):Clone()
	deadFallLogo.AnchorPoint = Vector2.new(0.5, 0.5)
	deadFallLogo.Position = UDim2.new(0.5, 0, 0.5, 0)
	deadFallLogo.Size = UDim2.new(0.8, 0, 0.8, 0)
	deadFallLogo.ScaleType = Enum.ScaleType.Fit
	deadFallLogo.BackgroundTransparency = 1
	deadFallLogo.ImageTransparency = 1
	deadFallLogo.Parent = bg

	local blackMask = Instance.new("Frame")
	blackMask.Name = "FallMask"
	blackMask.Size = UDim2.new(0.5, 0, 1, 0)
	blackMask.Position = UDim2.new(0.52, 0, 0, 0)
	blackMask.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	blackMask.BorderSizePixel = 0
	blackMask.Parent = deadFallLogo

	ts:Create(deadFallLogo, TweenInfo.new(0.05), {ImageTransparency = 0}):Play()
	if introSound then introSound:Play() end

	task.wait(1.5)

	blackMask.Visible = false
	if introSound then introSound.TimePosition = 0; introSound:Play() end

	task.wait(2)

	ts:Create(deadFallLogo, TweenInfo.new(0.5), {ImageTransparency = 1}):Play()
	task.wait(0.5)

	if skipStep == 0 then
		skipStep = 1
		finishStage1()
	end
end

local function PlayIntroSequence()
	stage1Thread = task.spawn(runStage1)
end

skipButton.MouseButton1Click:Connect(function()
	if skipStep == 0 then
		skipStep = 1
		if stage1Thread then task.cancel(stage1Thread) end
		finishStage1()

	elseif skipStep == 1 then
		skipStep = 2
		if stage2Thread then task.cancel(stage2Thread) end
		finishStage2()
	end
end)

local templateLosange = createPersonnageCyborgMode and createPersonnageCyborgMode:WaitForChild("Losange", 10)
if templateLosange then
	templateLosange.Visible = false
	templateLosange.Active = true 
end

local updateLobbyUIEvent = ReplicatedStorage:WaitForChild("UpdateLobbyUIEvent")

updateLobbyUIEvent.OnClientEvent:Connect(function(lobbyPlayersList, kickCounts)
	kickCounts = kickCounts or {}

	if not player:GetAttribute("IsHost") then return end

	if createPersonnageCyborgMode then
		for _, child in ipairs(createPersonnageCyborgMode:GetChildren()) do
			if child.Name == "ClonedLosange" then
				child:Destroy()
			end
		end
	end

	if not templateLosange then return end

	local hostLosangeSize = templateLosange.Size
	local smallLosangeSize = UDim2.new(hostLosangeSize.X.Scale * 0.8, hostLosangeSize.X.Offset * 0.8, hostLosangeSize.Y.Scale * 0.8, hostLosangeSize.Y.Offset * 0.8)

	local hostAvatarSize = UDim2.new(0, 40, 0, 40)
	local smallAvatarSize = UDim2.new(0, 32, 0, 32)

	for _, lobbyPlayer in ipairs(lobbyPlayersList) do
		local isHostLosange = (lobbyPlayer == player)

		local newLosange = templateLosange:Clone()
		newLosange.Name = "ClonedLosange"
		newLosange.Visible = true
		newLosange.Parent = createPersonnageCyborgMode
		newLosange.Size = isHostLosange and hostLosangeSize or smallLosangeSize

		local playerHeadImage = Instance.new("ImageLabel")
		playerHeadImage.Name = "PlayerHead"
		playerHeadImage.Size = isHostLosange and hostAvatarSize or smallAvatarSize
		playerHeadImage.AnchorPoint = Vector2.new(0.5, 0.5)
		playerHeadImage.Position = UDim2.new(0.5, 0, 0.5, 0)
		playerHeadImage.BackgroundTransparency = 1 
		playerHeadImage.Rotation = -templateLosange.Rotation 
		playerHeadImage.Parent = newLosange
		playerHeadImage.ZIndex = 2

		task.spawn(function()
			local content, isReady = Players:GetUserThumbnailAsync(lobbyPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			if isReady then playerHeadImage.Image = content end
		end)

		if not isHostLosange then
			local previousKicks = kickCounts[tostring(lobbyPlayer.UserId)] or kickCounts[lobbyPlayer.UserId] or 0
			local actionWord = (previousKicks >= 1) and "Ban " or "Kick "

			local kickLabel = Instance.new("TextLabel")
			kickLabel.Name = "KickLabel"
			kickLabel.Text = actionWord .. lobbyPlayer.Name
			kickLabel.FontFace = zektonFont
			kickLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
			kickLabel.BackgroundTransparency = 1
			kickLabel.Size = UDim2.new(4, 0, 0.8, 0)
			kickLabel.AnchorPoint = Vector2.new(0.5, 1)
			kickLabel.Position = UDim2.new(0.5, 0, -0.3, 0)
			kickLabel.TextScaled = true
			kickLabel.Rotation = 0
			kickLabel.Visible = false
			kickLabel.ZIndex = 3
			kickLabel.Parent = playerHeadImage

			local hoverSize = UDim2.new(smallLosangeSize.X.Scale * 1.15, smallLosangeSize.X.Offset * 1.15, smallLosangeSize.Y.Scale * 1.15, smallLosangeSize.Y.Offset * 1.15)
			local hoverAvatarSize = UDim2.new(0, 37, 0, 37)
			local defColor = newLosange.ImageColor3
			local hoverColor = Color3.fromRGB(255, 0, 0)

			newLosange.MouseEnter:Connect(function()
				if hoverSound then hoverSound:Play() end
				kickLabel.Visible = true
				ts:Create(newLosange, uiTweenInfo, {Size = hoverSize, ImageColor3 = hoverColor}):Play()
				ts:Create(playerHeadImage, uiTweenInfo, {Size = hoverAvatarSize}):Play()
			end)

			newLosange.MouseLeave:Connect(function()
				kickLabel.Visible = false
				ts:Create(newLosange, uiTweenInfo, {Size = smallLosangeSize, ImageColor3 = defColor}):Play()
				ts:Create(playerHeadImage, uiTweenInfo, {Size = smallAvatarSize}):Play()
			end)

			newLosange.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					local kickEvent = ReplicatedStorage:WaitForChild("KickPlayerFromLobby")
					kickEvent:FireServer(lobbyPlayer.UserId)
				end
			end)
		end
	end
end)

local startBtn = createCyborgMode and createCyborgMode:WaitForChild("Start", 10)
local leaveBtn = createCyborgMode and createCyborgMode:WaitForChild("Leave", 10)
local playButton = cyborgMode and cyborgMode:WaitForChild("Play", 10)
local multiplayerButton = cyborgMode and cyborgMode:WaitForChild("Multiplayer", 10)
local cyborgCreateBtn = cyborgMode and cyborgMode:WaitForChild("Create", 10)
local cyborgJoinBtn = cyborgMode and cyborgMode:WaitForChild("Join", 10)
local cyborgBackBtn = cyborgMode and cyborgMode:WaitForChild("Back", 10)

if cyborgCreateBtn then cyborgCreateBtn.Visible = false end
if cyborgJoinBtn then cyborgJoinBtn.Visible = false end
if cyborgBackBtn then cyborgBackBtn.Visible = false end

local playVersusButton = versusMode and versusMode:WaitForChild("Create2", 10)
local multiplayerVersusButton = versusMode and versusMode:WaitForChild("Join", 10)
local soundFrame = mainMenuCyborg and mainMenuCyborg:WaitForChild("Sound", 10)
local soundButton = soundFrame and soundFrame:WaitForChild("Son", 10)
local modeSelection = mainMenuCyborg and mainMenuCyborg:WaitForChild("ModeSelection", 10)
local btnVersus = modeSelection and modeSelection:WaitForChild("ButtonVersus", 10)
local btnCyborg = modeSelection and modeSelection:WaitForChild("ButtonCyborg", 10)

local arrow1 = modeSelection and modeSelection:FindFirstChild("Arrow1")
local arrow2 = modeSelection and modeSelection:FindFirstChild("Arrow2")
local buttonProfile = modeSelection and modeSelection:FindFirstChild("ButtonProfile")
local buttonShop = modeSelection and modeSelection:FindFirstChild("ButtonShop")

local modeSelectionElements = {}
if arrow1 then table.insert(modeSelectionElements, arrow1) end
if arrow2 then table.insert(modeSelectionElements, arrow2) end
if btnCyborg then table.insert(modeSelectionElements, btnCyborg) end
if buttonProfile then table.insert(modeSelectionElements, buttonProfile) end
if buttonShop then table.insert(modeSelectionElements, buttonShop) end
if btnVersus then table.insert(modeSelectionElements, btnVersus) end

local selectedModeButton = nil
local originalSizes = {}
local originalTransparencies = {}

for _, element in ipairs(modeSelectionElements) do
	originalSizes[element] = element.Size
	originalTransparencies[element] = element.ImageTransparency
end

local function UpdateModeSelectionState(selectedButton)
	for _, element in ipairs(modeSelectionElements) do
		if element == btnCyborg or element == btnVersus then
			local defSize = originalSizes[element]
			local defTrans = originalTransparencies[element]

			if element == selectedButton then
				local targetSize = UDim2.new(
					defSize.X.Scale * 1.2, defSize.X.Offset * 1.2,
					defSize.Y.Scale * 1.2, defSize.Y.Offset * 1.2
				)
				ts:Create(element, uiTweenInfo, {Size = targetSize, ImageTransparency = 0}):Play()
			else
				ts:Create(element, uiTweenInfo, {Size = defSize, ImageTransparency = defTrans}):Play()
			end
		end
	end
end

selectedModeButton = btnCyborg
UpdateModeSelectionState(btnCyborg)

local scaleMultiplier = 1.05
local moveXOffset = 0.02

local buttonData = {}
if playButton then buttonData[playButton] = { cam = cam1, defPos = playButton.Position, defSize = playButton.Size, defTrans = playButton.ImageTransparency, normalImg = playButton.Image, hoverImg = playButton.HoverImage } end
if multiplayerButton then buttonData[multiplayerButton] = { cam = cam2, defPos = multiplayerButton.Position, defSize = multiplayerButton.Size, defTrans = multiplayerButton.ImageTransparency, normalImg = multiplayerButton.Image, hoverImg = multiplayerButton.HoverImage } end
if cyborgCreateBtn then buttonData[cyborgCreateBtn] = { cam = cam5, defPos = cyborgCreateBtn.Position, defSize = cyborgCreateBtn.Size, defTrans = cyborgCreateBtn.ImageTransparency, normalImg = cyborgCreateBtn.Image, hoverImg = cyborgCreateBtn.HoverImage } end
if cyborgJoinBtn then buttonData[cyborgJoinBtn] = { cam = cam7, defPos = cyborgJoinBtn.Position, defSize = cyborgJoinBtn.Size, defTrans = cyborgJoinBtn.ImageTransparency, normalImg = cyborgJoinBtn.Image, hoverImg = cyborgJoinBtn.HoverImage } end
if cyborgBackBtn then buttonData[cyborgBackBtn] = { cam = nil, defPos = cyborgBackBtn.Position, defSize = cyborgBackBtn.Size, defTrans = cyborgBackBtn.ImageTransparency, normalImg = cyborgBackBtn.Image, hoverImg = cyborgBackBtn.HoverImage } end
if playVersusButton then buttonData[playVersusButton] = { cam = cam3, defPos = playVersusButton.Position, defSize = playVersusButton.Size, defTrans = playVersusButton.ImageTransparency, normalImg = playVersusButton.Image, hoverImg = playVersusButton.HoverImage } end
if multiplayerVersusButton then buttonData[multiplayerVersusButton] = { cam = cam4, defPos = multiplayerVersusButton.Position, defSize = multiplayerVersusButton.Size, defTrans = multiplayerVersusButton.ImageTransparency, normalImg = multiplayerVersusButton.Image, hoverImg = multiplayerVersusButton.HoverImage } end

task.spawn(function()
	local instancesToPreload = {mainMenuCyborg} 
	local function addImageToPreload(imageId)
		if imageId and typeof(imageId) == "string" and imageId ~= "" then
			local tempLabel = Instance.new("ImageLabel")
			tempLabel.Image = imageId
			table.insert(instancesToPreload, tempLabel)
		end
	end
	for _, data in pairs(buttonData) do
		addImageToPreload(data.hoverImg)
		addImageToPreload(data.normalImg)
	end
	if guestLeaveBtn then
		addImageToPreload(guestLeaveBtn.Image)
		if guestLeaveBtn:IsA("ImageButton") then addImageToPreload(guestLeaveBtn.HoverImage) end
	end
	pcall(function() ContentProvider:PreloadAsync(instancesToPreload) end)
end)

for btn, _ in pairs(buttonData) do
	if btn:IsA("ImageButton") then btn.HoverImage = "" end
end

local function SetButtonState(button, isSelected)
	local data = buttonData[button]
	if not data then return end

	local targetPos, targetSize, targetTrans
	if isSelected then
		targetPos = data.defPos + UDim2.new(moveXOffset, 0, 0, 0)
		targetSize = UDim2.new(data.defSize.X.Scale * scaleMultiplier, data.defSize.X.Offset * scaleMultiplier, data.defSize.Y.Scale * scaleMultiplier, data.defSize.Y.Offset * scaleMultiplier)
		targetTrans = 0
		button.Image = data.hoverImg
	else
		targetPos = data.defPos
		targetSize = data.defSize
		targetTrans = data.defTrans
		button.Image = data.normalImg
	end
	ts:Create(button, uiTweenInfo, { Position = targetPos, Size = targetSize, ImageTransparency = targetTrans }):Play()
end

local currentSelectedButton = playButton
local creationModeActive = false 

local function SelectMenu(selectedButton, jouerSon)
	if creationModeActive then return end 
	if selectedButton ~= currentSelectedButton then
		if jouerSon and hoverSound then hoverSound:Play() end
		currentSelectedButton = selectedButton
	end
	for button, data in pairs(buttonData) do
		if button == selectedButton then
			SetButtonState(button, true)
			if data.cam and mainMenuCyborg and mainMenuCyborg.Enabled then TransitionTo(data.cam) end
		else
			SetButtonState(button, false)
		end
	end
end

for btn, _ in pairs(buttonData) do
	btn.MouseEnter:Connect(function()
		if btn.Visible and btn.Parent.Visible then SelectMenu(btn, true) end
	end)
end

SelectMenu(playButton, false)
PlayIntroSequence()

if multiplayerButton then
	multiplayerButton.MouseButton1Click:Connect(function()
		playButton.Visible = false
		multiplayerButton.Visible = false
		cyborgCreateBtn.Visible = true
		cyborgJoinBtn.Visible = true
		cyborgBackBtn.Visible = true
		SelectMenu(cyborgCreateBtn, true)
	end)
end

if cyborgBackBtn then
	cyborgBackBtn.MouseButton1Click:Connect(function()
		cyborgCreateBtn.Visible = false
		cyborgJoinBtn.Visible = false
		cyborgBackBtn.Visible = false
		playButton.Visible = true
		multiplayerButton.Visible = true
		SelectMenu(multiplayerButton, true)
	end)
end

if playButton then
	playButton.MouseButton1Click:Connect(function()
		if creationModeActive then return end
		creationModeActive = true

		local joinEvent = ReplicatedStorage:WaitForChild("JoinCyborgMode")
		joinEvent:FireServer()

		task.wait(0.3)

		local startGameEvent = ReplicatedStorage:WaitForChild("StartGame")
		startGameEvent:FireServer()
	end)
end

local function CreateAndPlayTransition(callbackMidway)
	local transitionGui = Instance.new("ScreenGui")
	transitionGui.Name = "TransitionGui"
	transitionGui.DisplayOrder = 100
	transitionGui.IgnoreGuiInset = true
	transitionGui.Parent = playerGui

	local transitionFrame = Instance.new("Frame")
	transitionFrame.Size = UDim2.new(1, 0, 1, 0)
	transitionFrame.Position = UDim2.new(-1, 0, 0, 0)
	transitionFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	transitionFrame.BorderSizePixel = 0
	transitionFrame.Parent = transitionGui

	local transitionTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local tweenIn = ts:Create(transitionFrame, transitionTweenInfo, {Position = UDim2.new(0, 0, 0, 0)})
	tweenIn:Play()

	tweenIn.Completed:Connect(function()
		if callbackMidway then callbackMidway() end
		local tweenOut = ts:Create(transitionFrame, transitionTweenInfo, {Position = UDim2.new(1, 0, 0, 0)})
		tweenOut:Play()
		tweenOut.Completed:Connect(function() transitionGui:Destroy() end)
	end)
end

if cyborgCreateBtn then
	cyborgCreateBtn.MouseButton1Click:Connect(function()
		if creationModeActive then return end
		creationModeActive = true 

		CreateAndPlayTransition(function()
			if cyborgMode then cyborgMode.Visible = false end
			if modeSelection then modeSelection.Visible = false end
			if soundFrame then soundFrame.Visible = false end

			if createCyborgMode then createCyborgMode.Visible = true end
			if createPersonnageCyborgMode then createPersonnageCyborgMode.Visible = true end

			if currentTween then currentTween:Cancel() end
			baseCFrame.Value = cam6.CFrame
			camera.CFrame = cam6.CFrame

			local joinEvent = ReplicatedStorage:WaitForChild("JoinCyborgMode")
			joinEvent:FireServer()

			local character = player.Character or player.CharacterAdded:Wait()
			local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)

			if humanoidRootPart and tp1 then
				humanoidRootPart.CFrame = tp1.CFrame
				SetOtherPlayersVisibility(false)
			end
		end)
	end)
end

if cyborgJoinBtn then
	cyborgJoinBtn.MouseButton1Click:Connect(function()
		if creationModeActive then return end
		creationModeActive = true 

		if cyborgMode then cyborgMode.Visible = false end
		if modeSelection then modeSelection.Visible = false end
		if soundFrame then soundFrame.Visible = false end

		if joinCyborgMode then joinCyborgMode.Visible = true end

		TransitionTo(cam8)

		if #targetImageLabels > 0 or #targetPhysicalParts > 0 then
			task.spawn(function()
				if partyFrame then partyFrame.Visible = true end

				for _, label in ipairs(targetImageLabels) do ts:Create(label, blinkTweenInfo, {ImageTransparency = 1}):Play() end
				for _, part in ipairs(targetPhysicalParts) do ts:Create(part, blinkTweenInfo, {Transparency = 1}):Play() end
				if partyFrame then PlayFade(partyFrame, true, blinkTweenInfo.Time) end
				task.wait(blinkTweenInfo.Time)

				for _, label in ipairs(targetImageLabels) do ts:Create(label, blinkTweenInfo, {ImageTransparency = 0}):Play() end
				for _, part in ipairs(targetPhysicalParts) do ts:Create(part, blinkTweenInfo, {Transparency = 0}):Play() end
				if partyFrame then PlayFade(partyFrame, false, blinkTweenInfo.Time) end
				task.wait(blinkTweenInfo.Time)

				for _, label in ipairs(targetImageLabels) do ts:Create(label, blinkTweenInfo, {ImageTransparency = 1}):Play() end
				for _, part in ipairs(targetPhysicalParts) do ts:Create(part, blinkTweenInfo, {Transparency = 1}):Play() end
				if partyFrame then PlayFade(partyFrame, true, blinkTweenInfo.Time) end
			end)
		end
	end)
end

if joinCyborgBackBtn then
	joinCyborgBackBtn.Active = true 
	local joinBackDefSize = joinCyborgBackBtn.Size
	local joinBackDefTrans = joinCyborgBackBtn.ImageTransparency

	if joinBackDefTrans == 0 then joinBackDefTrans = 0.4; joinCyborgBackBtn.ImageTransparency = joinBackDefTrans end

	joinCyborgBackBtn.MouseEnter:Connect(function()
		if hoverSound then hoverSound:Play() end
		local targetSize = UDim2.new(joinBackDefSize.X.Scale * scaleMultiplier, joinBackDefSize.X.Offset * scaleMultiplier, joinBackDefSize.Y.Scale * scaleMultiplier, joinBackDefSize.Y.Offset * scaleMultiplier)
		ts:Create(joinCyborgBackBtn, uiTweenInfo, {Size = targetSize, ImageTransparency = 0}):Play()
	end)
	joinCyborgBackBtn.MouseLeave:Connect(function() ts:Create(joinCyborgBackBtn, uiTweenInfo, {Size = joinBackDefSize, ImageTransparency = joinBackDefTrans}):Play() end)

	joinCyborgBackBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if not creationModeActive then return end
			creationModeActive = false 

			if joinCyborgMode then joinCyborgMode.Visible = false end
			if cyborgMode then cyborgMode.Visible = true end
			if modeSelection then modeSelection.Visible = true end
			if soundFrame then soundFrame.Visible = true end

			SelectMenu(cyborgJoinBtn, false)

			if partyFrame then
				PlayFade(partyFrame, false, 0.15)
				task.delay(0.15, function() partyFrame.Visible = false end)
			end

			ts:Create(joinCyborgBackBtn, uiTweenInfo, {Size = joinBackDefSize, ImageTransparency = joinBackDefTrans}):Play()

			for _, label in ipairs(targetImageLabels) do ts:Create(label, blinkTweenInfo, {ImageTransparency = 0}):Play() end
			for _, part in ipairs(targetPhysicalParts) do ts:Create(part, blinkTweenInfo, {Transparency = 0}):Play() end
		end
	end)
end

local function ExecuteGuestLeave()
	CreateAndPlayTransition(function()
		creationModeActive = false

		if createCyborgModeCeluiJoin then createCyborgModeCeluiJoin.Visible = false end
		if cyborgMode then cyborgMode.Visible = true end
		if modeSelection then modeSelection.Visible = true end
		if soundFrame then soundFrame.Visible = true end

		if playButton then playButton.Visible = false end
		if multiplayerButton then multiplayerButton.Visible = false end
		if cyborgCreateBtn then cyborgCreateBtn.Visible = true end
		if cyborgJoinBtn then cyborgJoinBtn.Visible = true end
		if cyborgBackBtn then cyborgBackBtn.Visible = true end

		if currentTween then currentTween:Cancel() end

		baseCFrame.Value = cam7.CFrame
		camera.CFrame = cam7.CFrame

		SelectMenu(cyborgJoinBtn, false)
		SetOtherPlayersVisibility(true)

		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart and tp5 then humanoidRootPart.CFrame = tp5.CFrame end
		end

		for _, label in ipairs(targetImageLabels) do ts:Create(label, blinkTweenInfo, {ImageTransparency = 0}):Play() end
		for _, part in ipairs(targetPhysicalParts) do ts:Create(part, blinkTweenInfo, {Transparency = 0}):Play() end
	end)
end

local kickedEvent = ReplicatedStorage:WaitForChild("KickedFromLobbyEvent")
kickedEvent.OnClientEvent:Connect(function()
	ExecuteGuestLeave()
end)

local bannedFromLobbyEvent = ReplicatedStorage:WaitForChild("BannedFromLobbyEvent")
bannedFromLobbyEvent.OnClientEvent:Connect(function(hostId)
	if mainLobby then
		local lobbyFrame = mainLobby:FindFirstChild("Lobby_" .. hostId)
		if lobbyFrame then
			lobbyFrame.BackgroundColor3 = Color3.fromRGB(160, 80, 80) 
			local joinButton = lobbyFrame:FindFirstChild("JoinButton")
			if joinButton then
				joinButton.Text = "BANNED"
				joinButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
				joinButton.TextColor3 = Color3.fromRGB(200, 200, 200)
				joinButton.Active = false 
			end
		end
	end
end)

if guestLeaveBtn then
	local guestLeaveDefSize = guestLeaveBtn.Size
	guestLeaveBtn.MouseEnter:Connect(function()
		if hoverSound then hoverSound:Play() end
		local targetSize = UDim2.new(guestLeaveDefSize.X.Scale * scaleMultiplier, guestLeaveDefSize.X.Offset * scaleMultiplier, guestLeaveDefSize.Y.Scale * scaleMultiplier, guestLeaveDefSize.Y.Offset * scaleMultiplier)
		ts:Create(guestLeaveBtn, uiTweenInfo, {Size = targetSize}):Play()
	end)
	guestLeaveBtn.MouseLeave:Connect(function() ts:Create(guestLeaveBtn, uiTweenInfo, {Size = guestLeaveDefSize}):Play() end)

	guestLeaveBtn.MouseButton1Click:Connect(function()
		local leaveEvent = ReplicatedStorage:WaitForChild("LeaveCyborgMode")
		leaveEvent:FireServer()
		ExecuteGuestLeave()
	end)
end

local soundDefSize = soundButton and soundButton.Size
local isSoundMuted = false 
if soundButton then
	soundButton.MouseEnter:Connect(function()
		if hoverSound then hoverSound:Play() end
		local targetSize = UDim2.new(soundDefSize.X.Scale * 1.15, soundDefSize.X.Offset * 1.15, soundDefSize.Y.Scale * 1.15, soundDefSize.Y.Offset * 1.15)
		ts:Create(soundButton, uiTweenInfo, {Size = targetSize}):Play()
	end)
	soundButton.MouseLeave:Connect(function() ts:Create(soundButton, uiTweenInfo, {Size = soundDefSize}):Play() end)
	soundButton.MouseButton1Click:Connect(function()
		isSoundMuted = not isSoundMuted 
		local targetVolume = isSoundMuted and 0 or defaultVolume 
		ts:Create(soundButton, quickTweenInfo, {ImageTransparency = isSoundMuted and 0.6 or 0}):Play()
		if electricSound then ts:Create(electricSound, audioTweenInfo, {Volume = targetVolume}):Play() end
	end)
end

if startBtn and leaveBtn then
	local startDefSize = startBtn.Size
	local leaveDefSize = leaveBtn.Size

	startBtn.MouseEnter:Connect(function()
		if hoverSound then hoverSound:Play() end
		ts:Create(startBtn, uiTweenInfo, {Size = UDim2.new(startDefSize.X.Scale * scaleMultiplier, startDefSize.X.Offset * scaleMultiplier, startDefSize.Y.Scale * scaleMultiplier, startDefSize.Y.Offset * scaleMultiplier)}):Play()
	end)
	startBtn.MouseLeave:Connect(function() ts:Create(startBtn, uiTweenInfo, {Size = startDefSize}):Play() end)

	startBtn.MouseButton1Click:Connect(function()
		if not creationModeActive then return end

		local startGameEvent = ReplicatedStorage:WaitForChild("StartGame")
		startGameEvent:FireServer()
	end)

	leaveBtn.MouseEnter:Connect(function()
		if hoverSound then hoverSound:Play() end
		ts:Create(leaveBtn, uiTweenInfo, {Size = UDim2.new(leaveDefSize.X.Scale * scaleMultiplier, leaveDefSize.X.Offset * scaleMultiplier, leaveDefSize.Y.Scale * scaleMultiplier, leaveDefSize.Y.Offset * scaleMultiplier)}):Play()
	end)
	leaveBtn.MouseLeave:Connect(function() ts:Create(leaveBtn, uiTweenInfo, {Size = leaveDefSize}):Play() end)

	leaveBtn.MouseButton1Click:Connect(function()
		if not creationModeActive then return end 
		CreateAndPlayTransition(function()
			creationModeActive = false 
			if createCyborgMode then createCyborgMode.Visible = false end
			if createPersonnageCyborgMode then createPersonnageCyborgMode.Visible = false end

			if cyborgMode then cyborgMode.Visible = true end
			if modeSelection then modeSelection.Visible = true end
			if soundFrame then soundFrame.Visible = true end

			if playButton then playButton.Visible = false end
			if multiplayerButton then multiplayerButton.Visible = false end
			if cyborgCreateBtn then cyborgCreateBtn.Visible = true end
			if cyborgJoinBtn then cyborgJoinBtn.Visible = true end
			if cyborgBackBtn then cyborgBackBtn.Visible = true end

			if currentTween then currentTween:Cancel() end
			baseCFrame.Value = cam5.CFrame
			camera.CFrame = cam5.CFrame

			SelectMenu(cyborgCreateBtn, false)
			SetOtherPlayersVisibility(true)

			local character = player.Character
			if character then
				local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
				if humanoidRootPart and tp5 then humanoidRootPart.CFrame = tp5.CFrame end
			end

			for _, label in ipairs(targetImageLabels) do ts:Create(label, blinkTweenInfo, {ImageTransparency = 0}):Play() end
			for _, part in ipairs(targetPhysicalParts) do ts:Create(part, blinkTweenInfo, {Transparency = 0}):Play() end

			local leaveEvent = ReplicatedStorage:WaitForChild("LeaveCyborgMode")
			leaveEvent:FireServer()
		end)
	end)
end

local modeSelectionScale = 1.2
for _, element in ipairs(modeSelectionElements) do
	local defSize = originalSizes[element]
	local defTrans = originalTransparencies[element]
	if element then
		element.MouseEnter:Connect(function()
			if element.Name == "Arrow1" or element.Name == "Arrow2" then return end
			if hoverSound then hoverSound:Play() end
			if element ~= selectedModeButton then
				ts:Create(element, uiTweenInfo, {Size = UDim2.new(defSize.X.Scale * modeSelectionScale, defSize.X.Offset * modeSelectionScale, defSize.Y.Scale * modeSelectionScale, defSize.Y.Offset * modeSelectionScale), ImageTransparency = 0}):Play()
			end
		end)
		element.MouseLeave:Connect(function()
			if element.Name == "Arrow1" or element.Name == "Arrow2" then return end
			if element ~= selectedModeButton then ts:Create(element, uiTweenInfo, {Size = defSize, ImageTransparency = defTrans}):Play() end
		end)
	end
end

if btnVersus then
	btnVersus.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			selectedModeButton = btnVersus
			UpdateModeSelectionState(btnVersus)
			if cyborgMode then cyborgMode.Visible = false end
			if versusMode then versusMode.Visible = true end
			if playVersusButton then SelectMenu(playVersusButton, true) end
		end
	end)
end

if btnCyborg then
	btnCyborg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			selectedModeButton = btnCyborg
			UpdateModeSelectionState(btnCyborg)
			if versusMode then versusMode.Visible = false end
			if cyborgMode then cyborgMode.Visible = true end
			if playButton then playButton.Visible = true end
			if multiplayerButton then multiplayerButton.Visible = true end
			if cyborgCreateBtn then cyborgCreateBtn.Visible = false end
			if cyborgJoinBtn then cyborgJoinBtn.Visible = false end
			if cyborgBackBtn then cyborgBackBtn.Visible = false end
			SelectMenu(playButton, true)
		end
	end)
end

local requestJoinEvent = ReplicatedStorage:WaitForChild("RequestJoinLobby")
local joinLobbyClientEvent = ReplicatedStorage:WaitForChild("JoinLobbyClientEvent")
local hostLeftEvent = ReplicatedStorage:WaitForChild("HostLeftEvent")

if mainLobby then
	mainLobby.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("TextButton") and descendant.Name == "JoinButton" then
			descendant.MouseButton1Click:Connect(function()
				local hostIdValue = descendant:FindFirstChild("HostID")
				if hostIdValue and descendant.Active then 
					requestJoinEvent:FireServer(hostIdValue.Value) 
				end
			end)
		end
	end)
	for _, descendant in ipairs(mainLobby:GetDescendants()) do
		if descendant:IsA("TextButton") and descendant.Name == "JoinButton" then
			descendant.MouseButton1Click:Connect(function()
				local hostIdValue = descendant:FindFirstChild("HostID")
				if hostIdValue and descendant.Active then 
					requestJoinEvent:FireServer(hostIdValue.Value) 
				end
			end)
		end
	end
end

joinLobbyClientEvent.OnClientEvent:Connect(function(tpName)
	if tpName == "UPDATE_VISIBILITY" then
		SetOtherPlayersVisibility(false)
		return
	end

	CreateAndPlayTransition(function()
		if joinCyborgMode then joinCyborgMode.Visible = false end
		if createCyborgModeCeluiJoin then createCyborgModeCeluiJoin.Visible = true end

		if currentTween then currentTween:Cancel() end
		baseCFrame.Value = cam6.CFrame
		camera.CFrame = cam6.CFrame

		if partyFrame then partyFrame.Visible = false end

		local targetTP = nil
		if hangarTP then targetTP = hangarTP:FindFirstChild(tpName) end

		local character = player.Character or player.CharacterAdded:Wait()
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)

		if humanoidRootPart and targetTP then
			humanoidRootPart.CFrame = targetTP.CFrame
			SetOtherPlayersVisibility(false)
		else
			warn("TP cible non trouvé : " .. tostring(tpName))
		end
	end)
end)

hostLeftEvent.OnClientEvent:Connect(function()
	ExecuteGuestLeave()
end)

local gameStartingEvent = ReplicatedStorage:WaitForChild("GameStartingEvent")
local deagleSound = script:WaitForChild("deagle_01")
local electric_sound_lobby = game:GetService("Workspace").Map.Main4.electricsound
local helico_sound = game:GetService("Workspace").Helicopter2.soundPart.helicopter

gameStartingEvent.OnClientEvent:Connect(function()
	if electricSound then
		ts:Create(electricSound, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Volume = 0}):Play()
	end

	local loadingGui = Instance.new("ScreenGui")
	loadingGui.Name = "FlashTransition"
	loadingGui.IgnoreGuiInset = true
	loadingGui.DisplayOrder = 999
	loadingGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.Parent = loadingGui

	deagleSound:Play()
	electric_sound_lobby:Stop()
	helico_sound:Stop()
	task.wait(0.3)

	local colorTween = ts:Create(frame, TweenInfo.new(5.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	})
	colorTween:Play()

	colorTween.Completed:Connect(function()
		print("🚀 Écran noir atteint")
	end)
end)