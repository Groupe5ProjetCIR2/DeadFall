-- ============================================================
--  Ce script a pour but de gérer l'état "à terre" (KO) d'un 
--  joueur, en limitant ses mouvements, en modifiant sa caméra 
--  et en masquant son interface. Il s'occupe également de le 
--  restaurer à la normale avec un effet visuel lors de sa réanimation.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local currentAnimationTrack = nil
local ANIMATION_ID = 79339566435840

local CAMERA_DOWN_OFFSET = Vector3.new(0, -1.8, 1.2)
local CAMERA_RESET_OFFSET = Vector3.new(0, 0, -1.4) 

local TWEEN_TIME = 0.5

local hiddenScreenGuis = {}
local savedMapProps = {}

local minimapConfig = {
	GuiName = "MinimapGUI",
	SurfaceChild = "SurfaceGui",
	MapObjectName = "MiniMap",
	HiddenSize = UDim2.new(0, 0, 0, 0),
}

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- Déséquipe automatiquement tout outil que le joueur tenterait de prendre en main s'il est au sol
local function SetupToolBlocker(char)
	char.ChildAdded:Connect(function(child)
		if char:GetAttribute("IsDowned") and child:IsA("Tool") then
			task.defer(function()
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum:UnequipTools()
				end
			end)
		end
	end)
end

-- Masque ou affiche la minimap en sauvegardant ses proportions d'origine
local function toggleHUD(isVisible)
	local minimapGui = playerGui:FindFirstChild(minimapConfig.GuiName)
	if not minimapGui then return end

	local surfaceGui = minimapGui:FindFirstChild(minimapConfig.SurfaceChild)
	if not surfaceGui then return end

	local miniMap = surfaceGui:FindFirstChild(minimapConfig.MapObjectName)
	if not miniMap then return end

	if not isVisible then
		savedMapProps.Size = miniMap.Size
		savedMapProps.Visible = miniMap.Visible
		miniMap.Size = minimapConfig.HiddenSize
	else
		if savedMapProps.Size then
			miniMap.Size = savedMapProps.Size
			miniMap.Visible = savedMapProps.Visible
		end
	end
end

-- Désactive et stocke les interfaces inutiles (boussole, inventaire, santé) lors du KO, puis les restaure à la réanimation
local function toggleKOUI(isDowned)
	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")

	if isDowned then
		if hum then hum:UnequipTools() end
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

		toggleHUD(false)

		local guisToHide = {"CompassGui", "CustomInventoryGui", "SeringueGui"}
		for _, name in pairs(guisToHide) do
			local gui = playerGui:FindFirstChild(name)
			if gui and gui:IsA("ScreenGui") then
				gui.Enabled = false 
				table.insert(hiddenScreenGuis, gui)
			end
		end

		local customHealthBar = playerGui:FindFirstChild("CustomHealthBar")
		if customHealthBar then
			local frame = customHealthBar:FindFirstChild("SurfaceGui") and customHealthBar.SurfaceGui:FindFirstChild("Frame")
			if frame then
				frame.Visible = false
				table.insert(hiddenScreenGuis, frame)
			end
		end
	else
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

		toggleHUD(true)

		for _, obj in pairs(hiddenScreenGuis) do
			if obj:IsA("ScreenGui") then 
				obj.Enabled = true 
			elseif obj:IsA("Frame") then
				obj.Visible = true
			end
		end

		table.clear(hiddenScreenGuis)
	end
end

-- Charge et joue l'animation de blessure en boucle sur le personnage
local function playDownedAnimation(humanoid)
	if not humanoid then return end
	local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. ANIMATION_ID
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track:Play()
	return track
end

-- Configure les réactions du personnage à son apparition et écoute les changements de son état "IsDowned"
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	SetupToolBlocker(character)

	local function updateView()
		local isDowned = character:GetAttribute("IsDowned")
		local targetOffset = isDowned and CAMERA_DOWN_OFFSET or CAMERA_RESET_OFFSET
		local proxy = humanoid:FindFirstChild("CamOffsetProxy")

		-- Transition fluide de la caméra (Tween) pour simuler la chute ou la levée du joueur
		if proxy then
			TweenService:Create(proxy, TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = targetOffset}):Play()
		else
			humanoid.CameraOffset = targetOffset
		end
		ProximityPromptService.Enabled = not isDowned

		toggleKOUI(isDowned)

		if isDowned then
			humanoid.WalkSpeed = 4
			humanoid.JumpPower = 0
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			character:SetAttribute("IsCrouching", true)
			game:GetService("UserInputService").MouseIconEnabled = false
		else
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			character:SetAttribute("IsCrouching", false)
			game:GetService("UserInputService").MouseIconEnabled = true

			local flashGui = Instance.new("ScreenGui")
			flashGui.Name = "ReviveFlashGui"
			flashGui.IgnoreGuiInset = true
			flashGui.Parent = playerGui

			local flashFrame = Instance.new("Frame")
			flashFrame.Size = UDim2.new(1, 0, 1, 0)
			flashFrame.BackgroundColor3 = Color3.fromRGB(134, 255, 138)
			flashFrame.BackgroundTransparency = 1
			flashFrame.BorderSizePixel = 0
			flashFrame.Parent = flashGui

			local fadeIn = TweenService:Create(flashFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.6})
			local fadeOut = TweenService:Create(flashFrame, TweenInfo.new(1.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 1})

			fadeIn:Play()
			fadeIn.Completed:Connect(function()
				fadeOut:Play()
			end)

			Debris:AddItem(flashGui, 2)
		end

		if isDowned then
			if not currentAnimationTrack then
				currentAnimationTrack = playDownedAnimation(humanoid)
			end
		else
			if currentAnimationTrack then
				currentAnimationTrack:Stop()
				currentAnimationTrack:Destroy()
				currentAnimationTrack = nil
			end
		end
	end

	character:GetAttributeChangedSignal("IsDowned"):Connect(updateView)

	-- Bloque l'axe vertical de la caméra (Pitch) à chaque frame pour forcer le joueur à regarder droit devant lui quand il est au sol
	RunService:BindToRenderStep("DownedCameraClamp", Enum.RenderPriority.Camera.Value + 3, function()
		if not character:GetAttribute("IsDowned") then return end
		local cf = Camera.CFrame
		local pos = cf.Position
		local yaw = math.atan2(-cf.LookVector.X, -cf.LookVector.Z)
		Camera.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	end)

	updateView()
end

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)