-- ============================================================
-- Ce script serveur réceptionne l'événement de dégâts d'un joueur et le relaie dynamiquement à tous les autres clients connectés.
-- Cela permet d'afficher les effets visuels (VFX) d'impact sur l'écran des autres joueurs afin d'optimiser les performances du serveur.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local damageEvent = ReplicatedStorage:WaitForChild("DamageVFXEvent")

-- Vérification et création dynamique du RemoteEvent s'il n'a pas été préalablement instancié dans le ReplicatedStorage
local vfxForOthersEvent = ReplicatedStorage:FindFirstChild("VFXForOthersEvent")
if not vfxForOthersEvent then
	vfxForOthersEvent = Instance.new("RemoteEvent")
	vfxForOthersEvent.Name = "VFXForOthersEvent"
	vfxForOthersEvent.Parent = ReplicatedStorage
end

-- Intercepte le signal du joueur ayant subi des dégâts pour extraire ses données spatiales (position et orientation)
damageEvent.OnServerEvent:Connect(function(player)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Diffusion sélective des coordonnées du VFX à tous les clients, en excluant la victime qui gère déjà son propre effet localement
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			vfxForOthersEvent:FireClient(otherPlayer, rootPart.Position, rootPart.CFrame.LookVector)
		end
	end
end)