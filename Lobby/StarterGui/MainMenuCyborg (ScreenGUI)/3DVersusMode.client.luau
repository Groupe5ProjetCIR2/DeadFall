-- ============================================================
--  Ce script initialise le rendu 3D de l'interface principale 
--  du mode Versus.
--  Il active la transformation 3D de la fenêtre parente et 
--  applique une rotation constante pour aligner le rendu.
-- ============================================================

local Players = game:GetService("Players")
local RunServ = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")

local Screen3D = require(RepStorage:WaitForChild("Screen3D"))

local player = Players.LocalPlayer

-- Identification des composants de l'interface
local Frame = script.Parent:WaitForChild("VersusMode")
local ScreenGui = Frame.Parent

task.wait(3)

-- Initialisation de l'objet 3D et activation du composant
local GUI3D = Screen3D.new(ScreenGui, 5)
local Frame3D = GUI3D:GetComponent3D(Frame)
Frame3D:Enable()

-- Mise à jour continue de l'orientation de l'interface 3D à chaque rendu
RunServ.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	Frame3D.offset = CFrame.Angles(0, 0.25, 0)
end)