-- ============================================================
-- Ce script transforme le personnage en "Ragdoll" lors de sa mort.
-- Il clone le modèle, le nettoie, et utilise des BallSocketConstraints pour simuler une physique 
-- réaliste des articulations.
-- ============================================================

local camera = workspace.CurrentCamera
local char = script.Parent
local cleanUpTime = 9999999999999999

-- Données de configuration pour relier les membres au Torse
local AttactmentData = {
	["RA"] = {"Right Arm", CFrame.new(0, 0.5, 0), CFrame.new(1.5, 0.5, 0), CFrame.new(1.5, 0, 0)},
	["LA"] = {"Left Arm", CFrame.new(0, 0.5, 0), CFrame.new(-1.5, 0.5, 0), CFrame.new(-1.5, 0, 0)},
	["RL"] = {"Right Leg", CFrame.new(0, 0.5, 0), CFrame.new(0.5, -1.5, 0), CFrame.new(0.5, -2, 0)},
	["LL"] = {"Left Leg", CFrame.new(0, 0.5, 0), CFrame.new(-0.5, -1.5, 0), CFrame.new(-0.5, -2, 0)},
}

local collision_part = Instance.new("Part")
collision_part.Name = "CP"
collision_part.Size = Vector3.new(1, 1.5, 1)
collision_part.Transparency = 1

-- Crée une jointure physique entre deux objets
local function CreateJoint(j_type, p0, p1, c0, c1)
	local nj = Instance.new(j_type)
	nj.Part0 = p0
	nj.part1 = p1
	if c0 then nj.C0 = c0 end
	if c1 then nj.C1 = c1 end
	nj.Parent = p0
end

-- Fonction principale : crée le ragdoll au moment de la mort
function RagdollV3()
	char.Archivable = true
	local ragdoll = char:clone()
	char.Archivable = false

	-- Vide le personnage original pour ne garder que le Humanoid
	for _, obj in pairs(char:GetChildren()) do 
		if not obj:IsA("Humanoid") then obj:destroy() end
	end

	-- Supprime les scripts et contraintes inutiles du clone (ragdoll)
	local function scan(ch)
		for i = 1, #ch do
			scan(ch[i]:GetChildren())
			if (ch[i]:IsA("ForceField") or ch[i].Name == "HumanoidRootPart") or ((ch[i]:IsA("Weld") or ch[i]:IsA("Motor6D")) and ch[i].Name ~= "HeadWeld" and ch[i].Name ~= "AttachementWeld") then
				ch[i]:destroy()
			end
		end
	end
	scan(ragdoll:GetChildren())

	local function scanc(ch)
		for _, obj in pairs(ch:GetChildren()) do
			scanc(obj)
			if obj:IsA("Script") or obj:IsA("LocalScript") or ((obj:IsA("Weld") or obj:IsA("Motor6D")) and obj.Name ~= "AttachementWeld") or obj:IsA("ForceField") or (obj:IsA("Snap") and obj.Parent.Name == "Torso") or obj:IsA("ParticleEmitter") then
				obj:destroy()
			elseif obj:IsA("BasePart") then
				obj.Velocity, obj.RotVelocity = Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)
				if obj.Parent:IsA("Accessory") then obj.CanCollide = false end
			end
		end
	end
	scanc(ragdoll)

	local fhum = ragdoll:FindFirstChild("Humanoid")
	fhum.HealthDisplayType, fhum.DisplayDistanceType = Enum.HumanoidHealthDisplayType.AlwaysOff, Enum.HumanoidDisplayDistanceType.None
	fhum.PlatformStand = true
	fhum.Name = "RagdollHumanoid"

	local Torso = ragdoll:FindFirstChild("Torso")
	if Torso then
		Torso.Velocity = Vector3.new(math.random(), 0.0000001, math.random()).unit * 5 + Vector3.new(0, 0.15, 0)

		local Head = ragdoll:FindFirstChild("Head")
		if Head then
			camera.CameraSubject = Head
			CreateJoint("Weld", Torso, Head, CFrame.new(0, 1.5, 0))
		end

		-- Crée les articulations (BallSocket) pour chaque membre
		for att_tag, att_data in pairs(AttactmentData) do
			local get_limb = ragdoll:FindFirstChild(att_data[1])
			if get_limb then
				local att1 = Instance.new("Attachment", get_limb)
				att1.Name, att1.CFrame = att_tag, att_data[2]

				local att2 = Instance.new("Attachment", Torso)
				att2.Name, att2.CFrame = att_tag, att_data[3]

				local socket = Instance.new("BallSocketConstraint", Torso)
				socket.Name, socket.Attachment0, socket.Attachment1 = att_tag .. "_SOCKET", att2, att1
				socket.Radius = 0

				get_limb.CanCollide = false

				local cp = collision_part:Clone()
				local cp_weld = Instance.new("Weld", cp)
				cp_weld.C0, cp_weld.Part0, cp_weld.Part1 = CFrame.new(0, -0.25, 0), get_limb, cp
				cp.Parent = ragdoll
			end
		end
	end

	ragdoll.Parent = workspace
	game:GetService("Debris"):AddItem(ragdoll, cleanUpTime)
end

char.Humanoid.Died:connect(RagdollV3)