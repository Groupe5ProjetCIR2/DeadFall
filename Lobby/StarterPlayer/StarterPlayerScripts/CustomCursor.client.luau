-- ============================================================
--  Ce script personnalise l'icône du curseur de la souris 
--  en remplaçant l'image par défaut par une ressource spécifique.
--  Il utilise l'UserInputService pour garantir l'affichage 
--  et définir l'identifiant de l'image.
-- ============================================================

local Player = game.Players.LocalPlayer

-- Attente de la disponibilité du joueur local
repeat task.wait() until Player

local PlayerMouse = Player:GetMouse()
PlayerMouse.Icon = "rbxassetid://115308505781924"

local UserInputService = game:GetService("UserInputService")

-- Activation de l'affichage du curseur
UserInputService.MouseIconEnabled = true

-- Application de l'identifiant de l'image personnalisée pour le curseur
UserInputService.MouseIcon = "rbxassetid://115308505781924"