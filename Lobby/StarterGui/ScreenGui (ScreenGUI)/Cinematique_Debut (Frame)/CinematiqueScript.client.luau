-- ============================================================
--  Ce script gère une séquence d'introduction cinématique
--  type "terminal" affichant des logs de chargement système.
--  Il coordonne l'animation du texte, les effets visuels
--  de transition, et permet aux joueurs de passer la séquence
--  via un bouton de contrôle invisible.
-- ============================================================

local frame = script.Parent

if frame.Parent and frame.Parent:IsA("ScreenGui") then
	frame.Parent.IgnoreGuiInset = true
	frame.Parent.DisplayOrder = 2000
end

frame.Transparency = 1
frame.Visible = true
frame.BackgroundTransparency = 0
frame.BackgroundColor3 = Color3.new(0, 0, 0)
frame.ZIndex = 50
frame.Size = UDim2.new(1, 0, 1, 0)
frame.Position = UDim2.new(0, 0, 0, 0)
frame.AnchorPoint = Vector2.new(0, 0)

local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")

task.spawn(function()
	local model = Workspace:WaitForChild("Model", 10)
	local head1 = model and model:WaitForChild("Head", 5)
	local sound1 = head1 and head1:WaitForChild("electricsound", 5)
	if sound1 then
		if not sound1:GetAttribute("DefaultVolume") then sound1:SetAttribute("DefaultVolume", sound1.Volume) end
		sound1.Volume = 0
	end
end)

task.spawn(function()
	local pnj = Workspace:WaitForChild("VersusPnj2", 10)
	local head2 = pnj and pnj:WaitForChild("Head", 5)
	local sound2 = head2 and head2:WaitForChild("electricsound1", 5)
	if sound2 then
		if not sound2:GetAttribute("DefaultVolume") then sound2:SetAttribute("DefaultVolume", sound2.Volume) end
		sound2.Volume = 0
	end
end)

local topBar, bottomBar
local player = Players.LocalPlayer

local function preloadSounds()
	local instancesToPreload = {}

	local terminalSound = SoundService:FindFirstChild("TerminalSound1")
	local bootSound = SoundService:FindFirstChild("TerminalSoundBoot")

	if terminalSound then
		table.insert(instancesToPreload, terminalSound)
	end

	if bootSound then
		table.insert(instancesToPreload, bootSound)
	end

	if #instancesToPreload > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(instancesToPreload)
		end)
	end

	return terminalSound, bootSound
end

local terminalSound, bootSound = preloadSounds()

local function playTerminalSound()
	if terminalSound then
		terminalSound:Play()
	else
		warn("TerminalSound1 not found in SoundService")
	end
end

local function playBootSound()
	if bootSound then
		bootSound:Play()
	else
		warn("TerminalSoundBoot not found in SoundService")
	end
end

function hideBars()
	if topBar then topBar.Visible = false end
	if bottomBar then bottomBar.Visible = false end
end

function showBars()
	if topBar then topBar.Visible = true end
	if bottomBar then bottomBar.Visible = true end
end

local juniaImage = script.Parent:FindFirstChild("JuniaOnly")
if juniaImage then
	juniaImage.ImageTransparency = 1
end

local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(1, 0, 1, 0)
textLabel.Position = UDim2.new(0, 0, 0, 0)
textLabel.BackgroundTransparency = 1
textLabel.TextColor3 = Color3.new(1, 1, 1)
textLabel.TextSize = 18
textLabel.Font = Enum.Font.Code
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.TextYAlignment = Enum.TextYAlignment.Top
textLabel.Text = ""
textLabel.Parent = frame

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingTop = UDim.new(0, 10)
padding.Parent = textLabel

local BAR_HEIGHT_RATIO = 0.13
local ANIMATION_SPEED = 0.5
local BAR_COLOR = Color3.new(0, 0, 0)

local function createCinematicBars()
	if frame:FindFirstChild("TopBar") then frame.TopBar:Destroy() end
	if frame:FindFirstChild("BottomBar") then frame.BottomBar:Destroy() end

	local barHeight = frame.AbsoluteSize.Y * BAR_HEIGHT_RATIO

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, barHeight)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = BAR_COLOR
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 10
	topBar.Parent = frame

	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.Size = UDim2.new(1, 0, 0, barHeight)
	bottomBar.Position = UDim2.new(0, 0, 1, -barHeight)
	bottomBar.BackgroundColor3 = BAR_COLOR
	bottomBar.BorderSizePixel = 0
	bottomBar.ZIndex = 10
	bottomBar.Parent = frame

	return topBar, bottomBar
end

local lines = {
	"Welcome to Zombie Smash",
	"Some leak detection enabled",
	"standard timepicking quantum is 10000 us",
	"mig_table_max_displ = 72",
	"TBC Deadline Timer supported and enabled",
	"JuniaOnlyACPiCPU: ProcessorId=1 LocalApicId=0 Enabled",
	"JuniaOnlyACPiCPU: ProcessorId=2 LocalApicId=1 Enabled",
	"JuniaOnlyACPiCPU: ProcessorId=3 LocalApicId=2 Enabled",
	"JuniaOnlyACPiCPU: ProcessorId=4 LocalApicId=3 Enabled",
	"JuniaOnlyACPiCPU: ProcessorId=5 LocalApicId=255 Enabled",
	"JuniaOnlyACPiCPU: ProcessorId=6 LocalApicId=255 Enabled",
	"JuniaOnlyACPiCPU: ProcessorId=7 LocalApicId=255 Enabled",
	"JuniaOnlyACPiCPU: ProcessorId=8 LocalApicId=255 Enabled",
	"calling mpo_policy_init for TMSafetyNet",
	"Security policy loaded: Safety net for Rollback (TMSafetyNet)",
	"calling mpo_policy_init for Sandbox",
	"Security policy loaded: Seatbelt sandbox policy (Sandbox)",
	"calling mpo_policy_init for Quarantine",
	"Security policy loaded: Quarantine policy (Quarantine)",
	"import https://JuniaOnly-teams.xyz/Release/Roblox/RobloxFpsClient.exe",
	"import https://JuniaOnly-teams.xyz/Release/Roblox/Reshade.zip",
	"import https://JuniaOnly-teams.xyz/Release/Launcher/JuniaOnly-Launcher.exe",
	"",
	"Deadfall:\\unknownuser>Boot Success!"
}

local pauseIndices = {
	[5] = 0.5,
	[13] = 0.5,
	[19] = 0.5
}

local function addLine(line)
	if textLabel.Text == "" then
		textLabel.Text = line
	else
		textLabel.Text = textLabel.Text .. "\n" .. line
	end
end

local function createWhiteRectangles()
	local rectangles = {}
	local rectangleCount = math.random(1, 2)

	for i = 1, rectangleCount do
		local rect = Instance.new("Frame")
		rect.Name = "WhiteRectangle_" .. i
		rect.Size = UDim2.new(0, 90, 0, 10)
		rect.BackgroundColor3 = Color3.new(1, 1, 1)
		rect.BackgroundTransparency = 0
		rect.BorderSizePixel = 0
		rect.ZIndex = 10
		rect.Visible = false
		rect.Parent = frame
		table.insert(rectangles, rect)
	end
	return rectangles
end

local function deleteAllWhiteRectangles()
	for _, child in ipairs(frame:GetChildren()) do
		if child.Name:find("WhiteRectangle_") then
			child:Destroy()
		end
	end
end

local function showWhiteRectangles(rectangles)
	if #rectangles == 1 then
		local randomX = math.random(10, 90) / 100
		local randomY = math.random(10, 90) / 100
		rectangles[1].Position = UDim2.new(randomX, 0, randomY, 0)
		rectangles[1].AnchorPoint = Vector2.new(0.5, 0.5)
		rectangles[1].Visible = true
	elseif #rectangles == 2 then
		local randomX1 = math.random(10, 90) / 100
		local randomY1 = math.random(10, 90) / 100
		rectangles[1].Position = UDim2.new(randomX1, 0, randomY1, 0)
		rectangles[1].AnchorPoint = Vector2.new(0.5, 0.5)
		rectangles[1].Visible = true

		local randomX2 = math.random(10, 90) / 100
		local randomY2 = math.random(10, 90) / 100
		rectangles[2].Position = UDim2.new(randomX2, 0, randomY2, 0)
		rectangles[2].AnchorPoint = Vector2.new(0.5, 0.5)
		rectangles[2].Visible = true
	end
end

local function hideWhiteRectangles(rectangles)
	for i, rect in ipairs(rectangles) do
		rect.Visible = false
	end
end

local function runWhiteRectanglesRound()
	deleteAllWhiteRectangles()
	local rectangles = createWhiteRectangles()
	task.wait(0.05)
	showWhiteRectangles(rectangles)
	task.wait(0.05)
	hideWhiteRectangles(rectangles)
	return rectangles
end

-- =======================================================
-- NOUVEAU SYSTÈME DE SKIP (BOUTON INVISIBLE INFALLIBLE)
-- =======================================================
local isSkipped = false

-- Ce bouton captera ton clic à coup sûr, car il est au-dessus de tout
local skipButton = Instance.new("TextButton")
skipButton.Name = "SkipButton"
skipButton.Size = UDim2.new(1, 0, 1, 0)
skipButton.BackgroundTransparency = 1 -- Invisible
skipButton.Text = ""
skipButton.ZIndex = 100 -- Priorité absolue
skipButton.Parent = frame

local cinematicThread = task.spawn(function()
	for i = 1, #lines do
		local delayTime = math.random(20, 60) / 1000
		task.wait(delayTime)

		addLine(lines[i])

		if i == #lines then
			playBootSound()
		else
			playTerminalSound()
		end

		if pauseIndices[i] then
			task.wait(pauseIndices[i])
		end

		if i == 23 then
			task.wait(1)
		end

		if i == #lines then
			task.wait(0.5)

			textLabel.Text = ""
			task.wait(0.3)
			if juniaImage then juniaImage.ImageTransparency = 0 end
			task.wait(0.45)
			if juniaImage then juniaImage.ImageTransparency = 1 end

			runWhiteRectanglesRound()
			runWhiteRectanglesRound()
			runWhiteRectanglesRound()
			deleteAllWhiteRectangles()

			task.wait(0.2)

			if juniaImage then
				juniaImage.ImageTransparency = 1
				juniaImage.Size = UDim2.new(0, 427, 0, 427)

				local scaleTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				local scaleTween = TweenService:Create(juniaImage, scaleTweenInfo, { Size = UDim2.new(0, 640, 0, 640) })
				scaleTween:Play()
				scaleTween.Completed:Wait()

				local fadeInTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				local fadeInTween = TweenService:Create(juniaImage, fadeInTweenInfo, { ImageTransparency = 0 })
				fadeInTween:Play()

				task.wait(1)

				local fadeOutTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				local fadeOutTween = TweenService:Create(juniaImage, fadeOutTweenInfo, { ImageTransparency = 1 })
				fadeOutTween:Play()
				fadeOutTween.Completed:Wait()
			end

			task.wait(1.4)

			local frameFadeTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
			local frameFadeTween = TweenService:Create(frame, frameFadeTweenInfo, { BackgroundTransparency = 1 })
			frameFadeTween:Play()

			topBar, bottomBar = createCinematicBars()
			showBars()

			topBar:TweenSize(
				UDim2.new(1, 0, 0, topBar.Size.Y.Offset),
				Enum.EasingDirection.InOut,
				Enum.EasingStyle.Quad,
				ANIMATION_SPEED,
				true
			)

			bottomBar:TweenSize(
				UDim2.new(1, 0, 0, bottomBar.Size.Y.Offset),
				Enum.EasingDirection.InOut,
				Enum.EasingStyle.Quad,
				ANIMATION_SPEED,
				true
			)

			frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				local newHeight = frame.AbsoluteSize.Y * BAR_HEIGHT_RATIO
				if topBar then topBar.Size = UDim2.new(1, 0, 0, newHeight) end
				if bottomBar then 
					bottomBar.Size = UDim2.new(1, 0, 0, newHeight)
					bottomBar.Position = UDim2.new(0, 0, 1, -newHeight)
				end
			end)

			frameFadeTween.Completed:Wait()
			frame.Visible = false

			-- 🟢 ENVOI DU SIGNAL NORMAL
			_G.TerminalFinished = true
			if skipButton then skipButton:Destroy() end
		end
	end
end)

-- CONNEXION AU BOUTON DE SKIP
skipButton.MouseButton1Click:Connect(function()
	if not isSkipped then
		isSkipped = true

		-- 1. On fige et annule l'exécution de la boucle en cours
		if cinematicThread then
			task.cancel(cinematicThread)
		end

		-- 2. On coupe tous les sons instantanément
		if terminalSound then terminalSound:Stop() end
		if bootSound then bootSound:Stop() end

		-- 3. On détruit les visuels
		deleteAllWhiteRectangles()
		if textLabel then textLabel:Destroy() end
		if juniaImage then juniaImage:Destroy() end

		-- 4. On crée les barres au cas où le script suivant en a besoin
		if not topBar or not bottomBar then
			topBar, bottomBar = createCinematicBars()
			showBars()
		end

		-- 5. On termine proprement
		frame.BackgroundTransparency = 1
		frame.Visible = false
		_G.TerminalFinished = true
		skipButton:Destroy()
	end
end)