-- ============================================================
--  Ce script ajoute un léger balancement (sway) à la caméra 
--  en fonction des mouvements horizontaux de la souris. Il se met 
--  en attente de la fin de la cinématique initiale avant de s'activer.
-- ============================================================

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- Met l'exécution du script en pause de manière asynchrone jusqu'à ce que la cinématique soit déclarée terminée
if not LocalPlayer:GetAttribute("CinematicFinished") then
	LocalPlayer:GetAttributeChangedSignal("CinematicFinished"):Wait()
end

local Camera = workspace.CurrentCamera
local Turn = 0

-- Fonction d'interpolation linéaire pour adoucir les transitions mathématiques
local Lerp = function(a, b, t)
	return a + (b - a) * t
end;

-- Injecte le calcul du balancement juste après la mise à jour de la caméra par défaut de Roblox (RenderPriority.Camera + 1)
RunService:BindToRenderStep("CameraSway", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
	local MouseDelta = UserInputService:GetMouseDelta()

	-- Interpole la rotation en limitant (clamp) l'impact brut de la souris pour éviter des secousses extrêmes
	Turn = Lerp(Turn, math.clamp(MouseDelta.X, -2, 2), (4 * deltaTime))

	Camera.CFrame = Camera.CFrame * CFrame.Angles(0, 0, math.rad(Turn))
end)