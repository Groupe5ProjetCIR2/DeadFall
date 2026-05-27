-- ============================================================
--  Ce script initialise le rendu 3D de l'interface de 
--  sélection des modes de jeu.
--  Il convertit la sélection 2D en objet 3D manipulable et 
--  synchronise une inclinaison spécifique via une rotation CFrame.
-- ============================================================

local Players = game:GetService("Players")
local RunServ = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")

local Screen3D = require(RepStorage:WaitForChild("Screen3D"))

local player = Players.LocalPlayer

-- Identification des composants de l'interface
local Frame = script.Parent:WaitForChild("ModeSelection")
local ScreenGui = Frame.Parent

task.wait(3)

-- Initialisation du moteur de rendu 3D pour cet élément
local GUI3D = Screen3D.new(ScreenGui, 5)
local Frame3D = GUI3D:GetComponent3D(Frame)
Frame3D:Enable()

-- Mise à jour continue de l'orientation de l'interface 3D à chaque rendu
RunServ.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	Frame3D.offset = CFrame.Angles(0, 0.15, 0)
end)