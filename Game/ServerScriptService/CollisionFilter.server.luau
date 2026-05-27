-- ============================================================
-- Ce script configure les groupes de collision pour gérer la physique
-- Il empêche les objets de se rentrer dedans, comme les armes ou les objets de la map
-- ============================================================

local PhysicsService = game:GetService("PhysicsService")

-- Fonction utilitaire pour créer un groupe s'il n'existe pas encore
function _G.CreateCollisionGroup(CollisionGroupName)
	local CreatedGroups = PhysicsService:GetRegisteredCollisionGroups()
	local ExistingCollisionGroups = {} do
		for _, CreatedGroup in pairs(CreatedGroups) do
			ExistingCollisionGroups[CreatedGroup.name] = true
		end
	end

	if not ExistingCollisionGroups[CollisionGroupName] then
		PhysicsService:RegisterCollisionGroup(CollisionGroupName)
	end
end

-- Configuration du groupe "Debris" : aucun choc entre objets de ce groupe
_G.CreateCollisionGroup("Debris")
PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)

-- Configuration du groupe "Viewmodel" : pas de collision avec lui-même ni avec le reste du monde (Default)
_G.CreateCollisionGroup("Viewmodel")
PhysicsService:CollisionGroupSetCollidable("Viewmodel", "Viewmodel", false)
PhysicsService:CollisionGroupSetCollidable("Viewmodel", "Default", false)