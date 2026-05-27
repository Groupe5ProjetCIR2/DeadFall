-- ============================================================
--  Ce script sert de pont de communication côté client pour
--  gérer les actions liées au viewmodel (bras et arme en vue FPS).
--  Il intercepte les événements et fonctions distantes pour les 
--  rediriger vers le module d'exécution central ViewmodelHandler.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local viewmodelEvent = Events.viewmodelEvent
local viewmodelFunction = Events.viewmodelFunction

local LoadViewmodelAppearance = Remotes.LoadViewmodelAppearance

local ViewmodelHandler = require(Modules.ViewmodelHandler)
local Utilities = require(Modules.Utilities)
local Thread = Utilities.Thread

-- Routeur d'événements locaux pour déclencher les animations et états du viewmodel
viewmodelEvent.Event:Connect(function(EventName, ...)
	if EventName == "RecoilViewmodel" then
		ViewmodelHandler:RecoilViewmodel(...)
	elseif EventName == "SetAimEnabled" then
		ViewmodelHandler:SetAimEnabled(...)
	elseif EventName == "SetViewmodelTransparent" then
		ViewmodelHandler:SetViewmodelTransparent(...)
	elseif EventName == "CullViewmodel" then
		ViewmodelHandler:CullViewmodel(...)
	elseif EventName == "DestroyViewmodel" then
		ViewmodelHandler:DestroyViewmodel(ViewmodelHandler.CurrentViewmodel)
	end
end)

-- Intercepte les requêtes synchrones (BindableFunction) nécessitant le retour d'une valeur
viewmodelFunction.OnInvoke = function(EventName, ...)
	if EventName == "SetUpViewmodel" then
		return ViewmodelHandler.SetUpViewmodel(...)
	end
end

-- Écoute le serveur pour synchroniser ou forcer le chargement de l'apparence des bras du joueur
LoadViewmodelAppearance.OnClientEvent:Connect(function()
	ViewmodelHandler:LoadAppearance()
end)

local CleanupViewmodel = Events:WaitForChild("CleanupViewmodel")

-- Relais pour détruire proprement le modèle local lorsqu'un signal de nettoyage serveur est reçu
CleanupViewmodel.OnClientEvent:Connect(function()
	viewmodelEvent:Fire("DestroyViewmodel")
end)