-- ============================================================
--  Ce script configure un groupe de collision pour désactiver 
--  les interactions physiques entre les joueurs.
--  Il assigne récursivement chaque partie du corps des joueurs 
--  au groupe spécifié dès leur apparition dans la partie.
-- ============================================================

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local Group = "Players"
PhysicsService:RegisterCollisionGroup(Group)
PhysicsService:CollisionGroupSetCollidable(Group, Group, false)

-- Assigne le groupe de collision à un objet spécifique s'il s'agit d'un composant physique
local function ChangeGroups(Part)
	if Part:IsA("BasePart") then
		Part.CollisionGroup = Group
	end
end

-- Parcourt l'intégralité du personnage pour appliquer le groupe de collision à ses composants
local function HandleCharacterAdded(Character)
	for _, Part in ipairs(Character:GetDescendants()) do
		ChangeGroups(Part)
	end
end

Players.PlayerAdded:Connect(function(Player)
	Player.CharacterAdded:Connect(function(Character)
		HandleCharacterAdded(Character)

		-- Surveille l'ajout dynamique d'objets au personnage pour leur appliquer le groupe
		Character.ChildAdded:Connect(function(Object)
			ChangeGroups(Object)
		end)
	end)
end)