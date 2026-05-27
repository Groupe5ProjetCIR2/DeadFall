-- ============================================================
-- Ce script gère l'interface et les effets audiovisuels lorsqu'un joueur
-- tombe à terre (état "IsDowned"). Il gère l'affichage du timer, les 
-- palpitations à l'écran, les distorsions sonores, et déclenche 
-- aléatoirement une voiceline spécifique lorsque le joueur est réanimé.
-- ============================================================

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local SpectateEvent = ReplicatedStorage:WaitForChild("StartSpectate")

local player = Players.LocalPlayer
local gui = script.Parent

-- Chemins vers les dossiers de sons
local replicatedStorage_folder_voiceslines = ReplicatedStorage:WaitForChild("VoiceLines")
local replicatedStorage_folder_eventvoiceslines = ReplicatedStorage:WaitForChild("EventVoices")

-- Nettoyage de sécurité : on supprime les éléments UI existants pour éviter les doublons
for _, child in ipairs(gui:GetChildren()) do
	if child:IsA("TextLabel") or child:IsA("ImageLabel") or child:IsA("Frame") then
		child:Destroy()
	end
end

-- ============================================================
-- CHARGEMENT DES SONS EN ARRIÈRE-PLAN
-- ============================================================
task.spawn(function()
	local soundsToLoad = {}
	for _, categoryFolder in ipairs(replicatedStorage_folder_voiceslines:GetChildren()) do
		for _, sound in ipairs(categoryFolder:GetChildren()) do
			if sound:IsA("Sound") then
				table.insert(soundsToLoad, sound)
			end
		end
	end
	if #soundsToLoad > 0 then
		ContentProvider:PreloadAsync(soundsToLoad)
		print("[System] Voicelines préchargées.")
	end
end)

-- ============================================================
-- FONCTION POUR JOUER LA VOICELINE DE REVIVE
-- ============================================================
local function playRevivedVoice()
	local revivedFolder = replicatedStorage_folder_voiceslines:FindFirstChild("Revived")

	if revivedFolder then
		local sounds = revivedFolder:GetChildren()

		if #sounds > 0 then
			local randomSound = sounds[math.random(1, #sounds)]
			local soundClone = randomSound:Clone()
			soundClone.Parent = SoundService
			soundClone:Play()

			soundClone.Ended:Connect(function()
				soundClone:Destroy()
			end)
		end
	end

	local revivedEvent = replicatedStorage_folder_eventvoiceslines:FindFirstChild("Revived")
	if revivedEvent then
		revivedEvent:FireServer()
	end
end

-- ============================================================
-- 1. DESIGN DE L'INTERFACE
-- ============================================================
local textContainer = Instance.new("Frame")
textContainer.Name = "TextContainer"
textContainer.Size = UDim2.new(0, 400, 0, 150)
textContainer.Position = UDim2.new(0.5, 0, 0.8, 0)
textContainer.AnchorPoint = Vector2.new(0.5, 0.5)
textContainer.BackgroundTransparency = 1
textContainer.Visible = false
textContainer.Parent = gui

local shadow = Instance.new("TextLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 0, 1, 0)
shadow.Position = UDim2.new(0, 2, 0, 2)
shadow.BackgroundTransparency = 1
shadow.TextColor3 = Color3.fromRGB(0, 0, 0)
shadow.Font = Enum.Font.Michroma
shadow.TextSize = 55
shadow.TextTransparency = 1
shadow.Text = ""
shadow.Parent = textContainer

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(1, 0, 1, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.Font = Enum.Font.Michroma 
timerLabel.TextSize = 55
timerLabel.TextTransparency = 1
timerLabel.Text = ""
timerLabel.ZIndex = 2
timerLabel.Parent = textContainer

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 0, 0)
stroke.Thickness = 4
stroke.Transparency = 1
stroke.Parent = timerLabel

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 50))
})
gradient.Parent = timerLabel

local vignette = Instance.new("ImageLabel")
vignette.Name = "Vignette"
vignette.Size = UDim2.new(1, 0, 1, 0)
vignette.BackgroundTransparency = 1
vignette.Image = "rbxassetid://13112003009"
vignette.ImageColor3 = Color3.fromRGB(0, 0, 0)
vignette.ImageTransparency = 1
vignette.Visible = false 
vignette.ZIndex = 0
vignette.Parent = gui

-- ============================================================
-- 2. LOGIQUE VISUELLE ET SONORE
-- ============================================================
local blur = Lighting:FindFirstChild("DownedBlur") or Instance.new("BlurEffect", Lighting)
blur.Name = "DownedBlur"
blur.Size = 0

-- Application de filtres sur tout le jeu (étouffe le son)
local equalizer = SoundService:FindFirstChild("DownedEqualizer") or Instance.new("EqualizerSoundEffect", SoundService)
local compressor = SoundService:FindFirstChild("DownedCompressor") or Instance.new("CompressorSoundEffect", SoundService)
local reverb = SoundService:FindFirstChild("DownedReverb") or Instance.new("ReverbSoundEffect", SoundService)

reverb.DecayTime = 1.2
reverb.Enabled = false

local heartbeatConn = nil

-- Gère les pulsations du chrono et le flou (s'accélère au fur et à mesure)
local function heartbeatUpdate()
	local char = player.Character
	if not char or not char:GetAttribute("IsDowned") then return end

	local timeLeft = char:GetAttribute("DownedTimer") or 20
	local t = tick()

	-- Le rythme s'accélère à mesure que le temps diminue
	local timerSpeed = math.clamp(1 + ((20 - timeLeft) / 20) * 4, 1, 5)
	local timerPulse = math.abs(math.sin(t * (4 * timerSpeed)))

	local zoom = 1 + (timerPulse * 0.2)
	textContainer.Size = UDim2.new(0, 400 * zoom, 0, 150 * zoom)
	stroke.Transparency = 0.2 + (0.8 * (1 - timerPulse))
	shadow.TextTransparency = timerLabel.TextTransparency

	local blurPulse = (math.sin(t * 1.5) + 1) / 2 
	blur.Size = 8 + (blurPulse * 12) 
end

-- Active ou désactive l'ambiance "à terre" (Filtres sonores, vignette noire)
local function applyEffects(isDowned)
	local vignetteAlpha = isDowned and 0.15 or 1 
	local soundTarget = isDowned and -45 or 0
	local textAlpha = isDowned and 0 or 1

	-- Garde en mémoire si le joueur était à terre
	local wasDowned = textContainer.Visible

	textContainer.Visible = isDowned
	vignette.Visible = isDowned

	TweenService:Create(vignette, TweenInfo.new(1.5), {ImageTransparency = vignetteAlpha}):Play()
	TweenService:Create(equalizer, TweenInfo.new(1.5), {HighGain = soundTarget, MidGain = soundTarget/1.5}):Play()
	TweenService:Create(compressor, TweenInfo.new(1.5), {Ratio = isDowned and 15 or 1}):Play()

	reverb.Enabled = isDowned
	reverb.DryLevel = isDowned and -10 or 0

	TweenService:Create(timerLabel, TweenInfo.new(0.5), {TextTransparency = textAlpha}):Play()
	TweenService:Create(shadow, TweenInfo.new(0.5), {TextTransparency = textAlpha}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.5), {Transparency = textAlpha + 0.2}):Play()

	if isDowned then
		if not heartbeatConn then
			heartbeatConn = RunService.RenderStepped:Connect(heartbeatUpdate)
		end
	else
		if heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
		blur.Size = 0

		-- DÉCLENCHEMENT DE LA VOICELINE
		-- Si l'interface était visible (wasDowned) et ne l'est plus, c'est qu'il vient d'être réanimé.
		if wasDowned then
			playRevivedVoice()
		end
	end
end

-- Lie l'interface aux propriétés du personnage 
local function setupCharacter(char)
	char:GetAttributeChangedSignal("IsDowned"):Connect(function()
		applyEffects(char:GetAttribute("IsDowned"))
	end)

	char:GetAttributeChangedSignal("DownedTimer"):Connect(function()
		if char:GetAttribute("IsDowned") then
			local timeVal = char:GetAttribute("DownedTimer")
			timerLabel.Text = timeVal .. "s"
			shadow.Text = timeVal .. "s"
		end
	end)

	applyEffects(char:GetAttribute("IsDowned") or false)
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then setupCharacter(player.Character) end

-- Restaure l'état normal si le joueur passe en mode Spectateur
SpectateEvent.OnClientEvent:Connect(function()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	blur.Size = 0
	textContainer.Visible = false
	vignette.Visible = false
	reverb.Enabled = false
	TweenService:Create(equalizer, TweenInfo.new(0.5), {HighGain = 0, MidGain = 0}):Play()
	TweenService:Create(compressor, TweenInfo.new(0.5), {Ratio = 1}):Play()
end)