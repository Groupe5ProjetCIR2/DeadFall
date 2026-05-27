-- ============================================================
--  Ce script initialise le rendu 3D de l'interface des 
--  paramètres sonores.
--  Il ajuste l'ancrage de la fenêtre en bas à droite et applique 
--  une rotation constante pour un rendu 3D optimisé via le moteur.
-- ============================================================

local Players = game:GetService("Players")
local RunServ = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")

local Screen3D = require(RepStorage:WaitForChild("Screen3D"))

local player = Players.LocalPlayer

-- Identification des composants de l'interface
local Frame = script.Parent:WaitForChild("Sound")
local ScreenGui = Frame.Parent

-- Application du point d'ancrage et de la position pour un alignement en bas à droite
Frame.AnchorPoint = Vector2.new(1, 1)
Frame.Position = UDim2.new(1, -20, 1, -20)

task.wait(3)

-- Initialisation de l'objet 3D et activation du composant
local GUI3D = Screen3D.new(ScreenGui, 5)
local Frame3D = GUI3D:GetComponent3D(Frame)
Frame3D:Enable()

-- Mise à jour continue de l'orientation de l'interface 3D à chaque rendu
RunServ.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	Frame3D.offset = CFrame.Angles(0, -0.25, 0)
end)