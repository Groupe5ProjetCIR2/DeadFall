-- ============================================================
-- Ce script gère l'ouverture et la fermeture fluides d'une porte de panneau électrique via une interaction de type ProximityPrompt.
-- Il utilise un TweenService couplé à un objet CFrameValue pour animer dynamiquement la rotation du modèle autour de son point de pivot.
-- ============================================================

local TweenService = game:GetService("TweenService")
local doorModel = script.Parent

local doorOpen = doorModel:WaitForChild("open")
local Hinge = doorModel:WaitForChild("Hinge")
local soundOpen = Hinge:WaitForChild("door_open")
local soundClose = Hinge:WaitForChild("door_close")

local prompt = doorModel:FindFirstChildWhichIsA("ProximityPrompt", true)

local changingState = false
local tweenDuration = 0.5 

local pivotValue = Instance.new("CFrameValue")
pivotValue.Value = doorModel:GetPivot()

-- Relie dynamiquement le pivot global du modèle aux variations de la CFrameValue pour permettre l'animation interpolée
pivotValue.Changed:Connect(function(newCFrame)
	doorModel:PivotTo(newCFrame)
end)

-- Alterne l'état d'ouverture en calculant la nouvelle rotation cible et applique un verrouillage temporel pour éviter le spam d'interaction
local function toggleDoor()
	if changingState then return end 
	changingState = true

	local currentPivot = doorModel:GetPivot()
	local targetPivot

	if doorOpen.Value == true then
		if soundClose then soundClose:Play() end
		targetPivot = currentPivot * CFrame.Angles(0, math.rad(-100), 0)
		doorOpen.Value = false
		if prompt then prompt.ActionText = "Open" end
	else
		if soundOpen then soundOpen:Play() end
		targetPivot = currentPivot * CFrame.Angles(0, math.rad(100), 0)
		doorOpen.Value = true
		if prompt then prompt.ActionText = "Close" end
	end

	local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(pivotValue, tweenInfo, {Value = targetPivot})

	tween:Play()
	tween.Completed:Wait()

	changingState = false
end

if prompt then
	prompt.Triggered:Connect(toggleDoor)
	prompt.ActionText = doorOpen.Value and "Close" or "Open"
	prompt.ObjectText = "Electric Panel"
	prompt.Style = Enum.ProximityPromptStyle.Custom
else
	warn("⚠️ Aucun ProximityPrompt trouvé dans le modèle !")
end