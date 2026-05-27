-- ============================================================
--  Ce script a pour but de créer et de gérer l'interface 
--  visuelle (HUD) indiquant le numéro de la manche (Round) 
--  en cours. Il s'occupe de générer dynamiquement les 
--  éléments graphiques et d'animer les transitions de texte, 
--  de position et de couleur à chaque changement de manche.
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RoundHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local COLOR_WHITE = Color3.fromRGB(255, 255, 255)
local COLOR_ORANGE = Color3.fromRGB(255, 136, 0)

local SHADOW_COLOR = Color3.fromRGB(0, 0, 0)
local SHADOW_OFFSET = UDim2.new(0, 3, 0, 3)
local SHADOW_TRANSPARENCY = 0

local STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local STROKE_THICKNESS = 2 

local ORIGINAL_POSITION = UDim2.new(0, 15, 0, 15) 

local container = Instance.new("Frame")
container.Name = "RoundContainer"
container.Size = UDim2.new(0, 150, 0, 90)
container.Position = ORIGINAL_POSITION 
container.AnchorPoint = Vector2.new(0, 0)
container.BackgroundTransparency = 1 
container.BorderSizePixel = 0
container.Parent = screenGui

local titleFrame = Instance.new("Frame")
titleFrame.Name = "TitleFrame"
titleFrame.Size = UDim2.new(1, 0, 0.4, 0)
titleFrame.Position = UDim2.new(0, 0, 0.4, 0) 
titleFrame.BackgroundTransparency = 1
titleFrame.Parent = container

local titleShadow = Instance.new("TextLabel")
titleShadow.Name = "Shadow"
titleShadow.Size = UDim2.new(1, 0, 1, 0)
titleShadow.Position = SHADOW_OFFSET
titleShadow.BackgroundTransparency = 1
titleShadow.Text = "ROUND"
titleShadow.TextColor3 = SHADOW_COLOR
titleShadow.FontFace = Font.new("rbxasset://fonts/families/Zekton.json")
titleShadow.TextSize = 22
titleShadow.TextTransparency = 1 
titleShadow.TextXAlignment = Enum.TextXAlignment.Center
titleShadow.TextYAlignment = Enum.TextYAlignment.Center
titleShadow.ZIndex = 1 
titleShadow.Parent = titleFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "MainText"
titleLabel.Size = UDim2.new(1, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 0, 0, 0) 
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "ROUND"
titleLabel.TextColor3 = COLOR_WHITE
titleLabel.FontFace = titleShadow.FontFace
titleLabel.TextSize = 22
titleLabel.TextTransparency = 1 
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.TextYAlignment = Enum.TextYAlignment.Center
titleLabel.ZIndex = 2 
titleLabel.Parent = titleFrame

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = STROKE_COLOR
titleStroke.Thickness = STROKE_THICKNESS
titleStroke.Transparency = 1 
titleStroke.Parent = titleLabel

local numeralContainer = Instance.new("Frame")
numeralContainer.Name = "NumeralContainer"
numeralContainer.Size = UDim2.new(1, 0, 0.6, 0)
numeralContainer.Position = UDim2.new(0.5, 0, 0.5, 0) 
numeralContainer.AnchorPoint = Vector2.new(0.5, 0.5) 
numeralContainer.BackgroundTransparency = 1
numeralContainer.Parent = container

local currentRound = -1
local currentText = ""
local charFrames = {} 
local X_OFFSET = 27 
local titleAnimCounter = 0 

-- Crée une structure UI complète (texte principal, ombre et contour) pour afficher un chiffre individuel
local function createCharLabel(char)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 50, 1, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1

	local shadow = Instance.new("TextLabel")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 0, 1, 0)
	shadow.Position = SHADOW_OFFSET
	shadow.BackgroundTransparency = 1
	shadow.Text = char
	shadow.TextColor3 = SHADOW_COLOR
	shadow.FontFace = Font.new("rbxasset://fonts/families/DenkOne.json") 
	shadow.TextSize = 65 
	shadow.TextTransparency = 1 
	shadow.TextXAlignment = Enum.TextXAlignment.Center
	shadow.TextYAlignment = Enum.TextYAlignment.Center
	shadow.ZIndex = 1
	shadow.Parent = frame

	local lbl = Instance.new("TextLabel")
	lbl.Name = "MainText"
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = char
	lbl.TextColor3 = COLOR_WHITE 
	lbl.FontFace = shadow.FontFace 
	lbl.TextSize = 65 
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	lbl.TextTransparency = 1
	lbl.ZIndex = 2
	lbl.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = STROKE_COLOR
	stroke.Thickness = STROKE_THICKNESS
	stroke.Transparency = 1 
	stroke.Parent = lbl

	return frame
end

-- Alterne brièvement la couleur d'un chiffre (orange puis blanc) pour attirer l'attention du joueur lors d'un changement
local function pulseColor(frame)
	if not frame then return end
	local lbl = frame:FindFirstChild("MainText")
	if not lbl then return end

	local tweenToOrange = TweenService:Create(lbl, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextColor3 = COLOR_ORANGE})
	tweenToOrange:Play()
	task.delay(0.5, function()
		if lbl and lbl.Parent then
			local tweenToWhite = TweenService:Create(lbl, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextColor3 = COLOR_WHITE})
			tweenToWhite:Play()
		end
	end)
end

-- Gère l'apparition fluide du texte "ROUND" (et ses contours/ombres) puis son effacement automatique après un court délai
local function animateTitleText()
	titleAnimCounter += 1
	local currentAnim = titleAnimCounter

	titleFrame.Position = UDim2.new(0, 0, 0.4, 0)
	titleLabel.TextTransparency = 1
	titleStroke.Transparency = 1 
	titleShadow.TextTransparency = 1

	TweenService:Create(titleFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	}):Play()

	TweenService:Create(titleLabel, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0
	}):Play()
	TweenService:Create(titleStroke, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Transparency = 0
	}):Play()
	TweenService:Create(titleShadow, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = SHADOW_TRANSPARENCY
	}):Play()

	TweenService:Create(numeralContainer, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.75, 0) 
	}):Play()

	task.delay(2.5, function()
		if titleAnimCounter == currentAnim then
			TweenService:Create(titleFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Position = UDim2.new(0, 0, 0.4, 0)
			}):Play()
			TweenService:Create(titleLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				TextTransparency = 1
			}):Play()
			TweenService:Create(titleStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Transparency = 1
			}):Play()
			TweenService:Create(titleShadow, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				TextTransparency = 1
			}):Play()

			TweenService:Create(numeralContainer, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Position = UDim2.new(0.5, 0, 0.5, 0) 
			}):Play()
		end
	end)
end

local HUD = {}

-- Compare l'ancien numéro de manche au nouveau pour animer, ajouter, réagencer ou supprimer individuellement chaque chiffre
function HUD.setRound(n)
	local num = tonumber(n)
	if not num then return end

	if num == currentRound then return end
	currentRound = num

	container.Position = ORIGINAL_POSITION

	local newText = tostring(num)
	local L_new = #newText
	local L_old = #currentText

	local newFrames = {}
	local maxLen = math.max(L_new, L_old)

	local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local fadeOutInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local duplicateFadeInInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	animateTitleText()

	-- Détermine la position de chaque chiffre pour que l'ensemble du nombre reste parfaitement centré
	for i = 1, maxLen do
		local char_old = string.sub(currentText, i, i)
		local char_new = string.sub(newText, i, i)

		local targetPos = UDim2.new(0.5, (i - 1 - (L_new - 1) / 2) * X_OFFSET, 0.5, 0)
		local oldFrame = charFrames[i]

		if char_old == char_new and char_old ~= "" then
			TweenService:Create(oldFrame, tweenInfo, {Position = targetPos}):Play()
			newFrames[i] = oldFrame

		elseif char_new == "" then
			local fallBackPos = UDim2.new(0.5, (math.min(i, L_new) - 1 - (L_new - 1) / 2) * X_OFFSET, 0.5, 0)
			TweenService:Create(oldFrame, fadeOutInfo, {Position = fallBackPos}):Play()
			TweenService:Create(oldFrame.MainText, fadeOutInfo, {TextTransparency = 1}):Play()
			if oldFrame.MainText:FindFirstChild("Stroke") then
				TweenService:Create(oldFrame.MainText.Stroke, fadeOutInfo, {Transparency = 1}):Play()
			end
			TweenService:Create(oldFrame.Shadow, fadeOutInfo, {TextTransparency = 1}):Play()
			task.delay(0.4, function() oldFrame:Destroy() end)

		elseif char_old == "" then
			local newFrame = createCharLabel(char_new)
			newFrame.Parent = numeralContainer

			local spawnIndex = math.max(1, i - 1)
			local spawnPos = UDim2.new(0.5, (spawnIndex - 1 - (L_old - 1) / 2) * X_OFFSET, 0.5, 0)
			if L_old == 0 then spawnPos = UDim2.new(0.5, 0, 0.5, 0) end

			newFrame.Position = spawnPos

			TweenService:Create(newFrame, tweenInfo, {Position = targetPos}):Play()
			TweenService:Create(newFrame.MainText, duplicateFadeInInfo, {TextTransparency = 0}):Play()
			if newFrame.MainText:FindFirstChild("Stroke") then
				TweenService:Create(newFrame.MainText.Stroke, duplicateFadeInInfo, {Transparency = 0}):Play()
			end
			TweenService:Create(newFrame.Shadow, duplicateFadeInInfo, {TextTransparency = SHADOW_TRANSPARENCY}):Play()

			newFrames[i] = newFrame

		else
			if oldFrame then
				TweenService:Create(oldFrame.MainText, fadeOutInfo, {TextTransparency = 1}):Play()
				if oldFrame.MainText:FindFirstChild("Stroke") then
					TweenService:Create(oldFrame.MainText.Stroke, fadeOutInfo, {Transparency = 1}):Play()
				end
				TweenService:Create(oldFrame.Shadow, fadeOutInfo, {TextTransparency = 1}):Play()
				task.delay(0.4, function() oldFrame:Destroy() end)
			end

			local newFrame = createCharLabel(char_new)
			newFrame.Parent = numeralContainer
			newFrame.Position = targetPos

			TweenService:Create(newFrame.MainText, fadeOutInfo, {TextTransparency = 0}):Play()
			if newFrame.MainText:FindFirstChild("Stroke") then
				TweenService:Create(newFrame.MainText.Stroke, fadeOutInfo, {Transparency = 0}):Play()
			end
			TweenService:Create(newFrame.Shadow, fadeOutInfo, {TextTransparency = SHADOW_TRANSPARENCY}):Play()
			newFrames[i] = newFrame
		end
	end

	for _, frame in pairs(newFrames) do
		pulseColor(frame)
	end

	charFrames = newFrames
	currentText = newText
end

function HUD.setWaveTimer(seconds, total) end
function HUD.showPause(seconds) end

RS:WaitForChild("HUD_Round").OnClientEvent:Connect(HUD.setRound)
RS:WaitForChild("HUD_Wave").OnClientEvent:Connect(HUD.setWaveTimer)
RS:WaitForChild("HUD_Pause").OnClientEvent:Connect(HUD.showPause)