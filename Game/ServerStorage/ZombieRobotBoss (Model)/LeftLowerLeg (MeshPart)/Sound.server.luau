-- ==========================================
-- 🔊 RÉGLAGE DU VOLUME DES PAS
-- ==========================================
local VOLUME_GLOBAL = 0.5-- Change cette valeur ! (0.1 = très faible, 1 = très fort)
-- ==========================================

local npc = script.Parent.Parent
local humanoid = npc:WaitForChild("Zombie", 3)
local rootPart = npc:WaitForChild("HumanoidRootPart", 3)

if not humanoid or not rootPart then return end

local s1 = script.Parent:WaitForChild("marche", 2)
if not s1 then return end

local sounds = {
	s1,
	script.Parent:WaitForChild("marche1", 1),
	script.Parent:WaitForChild("marche2", 1),
	script.Parent:WaitForChild("marche3", 1)
}

for _, sound in ipairs(sounds) do
	if sound then
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound.RollOffMinDistance = 6
		sound.RollOffMaxDistance = 50
		sound.Volume = VOLUME_GLOBAL
	end
end

local lastSound = nil

local function playRandomSound()
	local validSounds = {}
	for _, s in ipairs(sounds) do
		if s and s.Parent then table.insert(validSounds, s) end
	end

	if #validSounds == 0 then return end

	local chosen
	repeat
		chosen = validSounds[math.random(1, #validSounds)]
	until chosen ~= lastSound or #validSounds == 1

	lastSound = chosen

	-- Variation de pitch (vitesse)
	chosen.PlaybackSpeed = math.random(85, 115) / 100

	-- Variation de volume naturelle (+/- 10% autour de ton VOLUME_GLOBAL)
	chosen.Volume = VOLUME_GLOBAL * (0.9 + (math.random() * 0.2))

	if not chosen.IsPlaying then
		chosen:Play()
	end
end

while npc and npc.Parent and humanoid.Health > 0 do
	local velocity = rootPart.AssemblyLinearVelocity
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	if horizontalSpeed > 1 then
		playRandomSound()
		task.wait(0.5)
	else
		task.wait(0.1)
	end
end