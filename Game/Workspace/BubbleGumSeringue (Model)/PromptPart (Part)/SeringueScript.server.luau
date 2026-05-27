-- ============================================================
-- Ce script gère l'achat de l'atout "MedicMix" à travers une interaction de type ProximityPrompt sur un distributeur.
-- La fin de l'animation (destruction + effet) est gérée par un RemoteEvent
-- qui est appelé par le Viewmodel du Gum.
-- ============================================================

local prompt = script.Parent
local machinePart = prompt.Parent

local gumName = "MedicMix" 
local price = 1000

-- 🎨 CONFIGURATION DU PROMPT
prompt.ActionText = "Buy Medic-Mix"
prompt.ObjectText = tostring(price) .. " $"
prompt.Style = Enum.ProximityPromptStyle.Custom

prompt:SetAttribute("GumName", gumName)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local giveGumEvent = ReplicatedStorage:WaitForChild("GiveGumEvent")
local ServerStorage = game:GetService("ServerStorage")

-- ========================================================
-- ÉCOUTEUR DE FIN D'ANIMATION (CRÉÉ AUTOMATIQUEMENT SI BESOIN)
-- Ce bloc peut exister dans plusieurs machines, il ne se créera qu'une fois
-- ========================================================
local consumeGumEvent = ReplicatedStorage:FindFirstChild("ConsumeGumEvent")
if not consumeGumEvent then
	consumeGumEvent = Instance.new("RemoteEvent")
	consumeGumEvent.Name = "ConsumeGumEvent"
	consumeGumEvent.Parent = ReplicatedStorage

	consumeGumEvent.OnServerEvent:Connect(function(player, gumNameStr)
		-- Sécurité anti-triche : On s'assure que le joueur était bien en train de consommer un gum
		if player:GetAttribute("PendingGum_" .. gumNameStr) == true then
			player:SetAttribute("PendingGum_" .. gumNameStr, nil) -- On nettoie la vérification

			-- On valide l'atout sur le joueur
			player:SetAttribute(gumNameStr, true)
			print(player.Name .. " a consommé " .. gumNameStr .. " !")

			-- On envoie le signal à l'interface (GumHUD)
			giveGumEvent:FireClient(player, gumNameStr)
		end

		-- On détruit instantanément le Gum que le joueur a dans les mains
		local char = player.Character
		if char then
			for _, item in pairs(char:GetChildren()) do
				if item:IsA("Tool") and string.find(item.Name, "Gum") then
					item:Destroy()
				end
			end
		end

		-- Sécurité supplémentaire : On le retire de l'inventaire caché
		local bp = player:FindFirstChild("Backpack")
		if bp then
			for _, item in pairs(bp:GetChildren()) do
				if item:IsA("Tool") and string.find(item.Name, "Gum") then
					item:Destroy()
				end
			end
		end
	end)
end
-- ========================================================

-- Vérifie l'alimentation de la machine, valide la transaction et attribue l'attribut au joueur tout en notifiant le client
prompt.Triggered:Connect(function(player)
	-- Sécurité Courant
	local machineModel = script:FindFirstAncestorWhichIsA("Model")
	if machineModel and machineModel:GetAttribute("PowerOn") == false then 
		return 
	end

	-- Anti-spam
	if not prompt.Enabled then return end
	prompt.Enabled = false

	-- 1. Vérification si le joueur a déjà l'atout
	if player:GetAttribute(gumName) == true then
		local oldText = prompt.ActionText
		prompt.ActionText = "Already Owned!"
		task.wait(1.5)
		prompt.ActionText = oldText
		prompt.Enabled = true
		return
	end

	-- 2. Vérification de l'argent
	local leaderstats = player:FindFirstChild("leaderstats")
	local argent = leaderstats and leaderstats:FindFirstChild("Argent")

	if not argent or argent.Value < price then
		local oldText = prompt.ActionText
		prompt.ActionText = "Not enough money!"
		task.wait(1.5)
		prompt.ActionText = oldText
		prompt.Enabled = true
		return
	end

	-- 3. Paiement
	argent.Value = argent.Value - price

	-- 4. Sécurité pour s'assurer que le joueur a le droit de recevoir l'atout
	player:SetAttribute("PendingGum_" .. gumName, true)

	-- 5. On donne le Tool "Gum" pour lancer l'animation
	-- ICI on charge bien le GumRose
	local gumTemplate = ServerStorage:WaitForChild("Toute_Les_Armes"):FindFirstChild("GumRose")
	if gumTemplate then
		local newGum = gumTemplate:Clone()
		newGum:SetAttribute("GumType", gumName) 

		newGum.Parent = player.Backpack

		-- Forcer l'équipement de l'outil
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:EquipTool(newGum)
		end
	else
		warn("Le Tool 'GumRose' n'a pas été trouvé dans ServerStorage !")
	end

	-- Fin du cooldown de la machine (elle redevient utilisable par un autre joueur)
	task.wait(1)
	prompt.Enabled = true
end)