-- ============================================================
-- Ce script gère l'apparition, l'animation et le ramassage d'un bonus de double argent.
-- Il assure la synchronisation de l'effet temporaire via un attribut unique pour éviter les conflits lors de ramassages multiples.
-- ============================================================

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local doubleArgentValue = ReplicatedStorage:WaitForChild("DoubleArgentActif")

local bonus = script.Parent
local isCollected = false

task.delay(15, function()
    if not isCollected and bonus and bonus.Parent then
        bonus:Destroy()
    end
end)

local startY = bonus.Position.Y
local speed = 2
local height = 1
local rotationSpeed = 3

local connection
connection = RunService.Heartbeat:Connect(function(deltaTime)
    if not bonus or not bonus.Parent then
        connection:Disconnect()
        return
    end
    bonus.CFrame = bonus.CFrame * CFrame.Angles(0, math.rad(rotationSpeed), 0)
    local newY = startY + math.sin(tick() * speed) * height
    bonus.Position = Vector3.new(bonus.Position.X, newY, bonus.Position.Z)
end)

-- Fonction déclenchée lors du contact avec l'objet bonus
bonus.Touched:Connect(function(hit)
    if isCollected then return end

    local character = hit.Parent
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid and humanoid.Health > 0 then
        local triggeringPlayer = game.Players:GetPlayerFromCharacter(character)

        if triggeringPlayer then
            isCollected = true
            print(triggeringPlayer.Name .. " a ramassé le x2 Argent !")

            local doubleArgentSound = SoundService:FindFirstChild("x2ArgentSound")
            if doubleArgentSound then
                doubleArgentSound:Play()
            end

            -- Utilisation d'un TimeTag pour valider la session active du bonus
            local timeTag = tick()
            doubleArgentValue:SetAttribute("TimeTag", timeTag)
            doubleArgentValue.Value = true

            task.delay(30, function()
                -- Vérification que le TimeTag n'a pas été écrasé par un autre ramassage
                if doubleArgentValue:GetAttribute("TimeTag") == timeTag then
                    doubleArgentValue.Value = false
                end
            end)

            -- Désactivation visuelle des composants du bonus
            for _, part in ipairs(bonus:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("Decal") then
                    part.Transparency = 1
                    part.CanCollide = false
                elseif part:IsA("BillboardGui") or part:IsA("Light") or part:IsA("ParticleEmitter") then
                    part.Enabled = false
                end
            end

            game.Debris:AddItem(bonus, 32)
        end
    end
end)