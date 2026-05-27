-- ============================================================
-- Ce script gère l'affichage dynamique et optimisé de l'interface des munitions (HUD) attachée au modèle d'arme du joueur.
-- Il met à jour les couleurs et les textes via des événements en temps réel et intègre un effet de clignotement lorsque le chargeur est vide.
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local originalColors = {}
local targetColors = {}
local colorTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local cachedHUDs = {}
local currentWeaponConnections = {} 
local renderConnection = nil 

-- Applique une transition de couleur fluide sur un objet GUI en vérifiant le cache pour éviter les redondances
local function applyColorFade(guiObject, targetColor)
	if not guiObject then return end
	if targetColors[guiObject] ~= targetColor then
		targetColors[guiObject] = targetColor
		TweenService:Create(guiObject, colorTweenInfo, {TextColor3 = targetColor}):Play()
	end
end

-- Interrompt et nettoie toutes les connexions actives liées à l'arme précédente pour prévenir les fuites de mémoire
local function cleanupConnections()
	for _, conn in ipairs(currentWeaponConnections) do
		conn:Disconnect()
	end
	table.clear(currentWeaponConnections)

	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

-- Actualise les éléments visuels du HUD (chargeur, réserve, statuts) en s'appuyant sur un système de cache des composants
local function updateHUD(tool, magValue, ammoValue)
	local vmStorage = camera:FindFirstChild("ViewmodelStorage")
	if not vmStorage then return end

	local vWeapon = vmStorage:FindFirstChild("v_" .. tool.Name)
	if not vWeapon then return end

	if not cachedHUDs[vWeapon] then
		cachedHUDs[vWeapon] = { ammoLabel = nil, storedLabel = nil, frameLabel = nil, nameLabel = nil }
		for _, objet in ipairs(vWeapon:GetDescendants()) do
			if objet.Name == "HUD" and objet.Parent then
				if objet.Parent.Name == "AmmoDisplay" then
					cachedHUDs[vWeapon].ammoLabel = objet:FindFirstChild("Ammo")
					cachedHUDs[vWeapon].storedLabel = objet:FindFirstChild("Stored")
					cachedHUDs[vWeapon].frameLabel = objet:FindFirstChild("frame")
				elseif objet.Parent.Name == "NameDisplay" then
					cachedHUDs[vWeapon].nameLabel = objet:FindFirstChild("Name") or objet:FindFirstChild("Ammo")
				end
			end
		end
	end

	local myHUD = cachedHUDs[vWeapon]
	local currentAmmoNum = magValue.Value 
	local storedAmmoNum = ammoValue.Value 

	-- Détermine dynamiquement la couleur du compteur de munitions via des seuils préfinis
	if myHUD.ammoLabel and myHUD.ammoLabel:IsA("TextLabel") then
		local lbl = myHUD.ammoLabel
		if not originalColors[lbl] then originalColors[lbl] = lbl.TextColor3 end

		local targetAmmoColor = originalColors[lbl] 
		if currentAmmoNum <= 0 then targetAmmoColor = Color3.fromRGB(255, 0, 0) 
		elseif currentAmmoNum == 1 then targetAmmoColor = Color3.fromRGB(255, 65, 0) 
		elseif currentAmmoNum == 2 then targetAmmoColor = Color3.fromRGB(255, 130, 0) 
		elseif currentAmmoNum == 3 then targetAmmoColor = Color3.fromRGB(255, 185, 0) end

		lbl.Text = tostring(currentAmmoNum)
		applyColorFade(lbl, targetAmmoColor)
	end

	if myHUD.storedLabel and myHUD.storedLabel:IsA("TextLabel") then
		local lbl = myHUD.storedLabel
		if not originalColors[lbl] then originalColors[lbl] = lbl.TextColor3 end

		local targetStoredColor = originalColors[lbl]
		if storedAmmoNum <= 0 then targetStoredColor = Color3.fromRGB(255, 0, 0) end

		lbl.Text = tostring(storedAmmoNum)
		applyColorFade(lbl, targetStoredColor)
	end

	if myHUD.frameLabel and myHUD.frameLabel:IsA("TextLabel") then
		local lbl = myHUD.frameLabel
		if not originalColors[lbl] then originalColors[lbl] = lbl.TextColor3 end

		local targetFrameColor = originalColors[lbl]
		if currentAmmoNum <= 0 and storedAmmoNum <= 0 then targetFrameColor = Color3.fromRGB(255, 0, 0) end
		applyColorFade(lbl, targetFrameColor)
	end

	if myHUD.nameLabel and myHUD.nameLabel:IsA("TextLabel") then
		local lbl = myHUD.nameLabel
		if not originalColors[lbl] then originalColors[lbl] = lbl.TextColor3 end

		-- Gère l'animation mathématique (sinusoïdale) de clignotement liée au cycle de rendu lorsque le chargeur est vide
		if currentAmmoNum <= 0 then
			lbl.Text = "[RELOAD]"
			applyColorFade(lbl, Color3.fromRGB(255, 0, 0))

			if not renderConnection then
				renderConnection = RunService.RenderStepped:Connect(function()
					lbl.TextTransparency = (math.sin(os.clock() * 12) + 1) / 2
				end)
			end
		else
			lbl.Text = "[" .. tool.Name .. "]"
			applyColorFade(lbl, originalColors[lbl])
			lbl.TextTransparency = 0 

			if renderConnection then
				renderConnection:Disconnect()
				renderConnection = nil
			end
		end
	end
end

-- Initialise le HUD lors de l'équipement d'un outil et met en place les écouteurs de propriétés
local function onToolEquipped(tool)
	cleanupConnections() 

	local handle = tool:FindFirstChild("Handle")
	if handle then
		local physicalAmmoDisplay = handle:FindFirstChild("AmmoDisplay")
		if physicalAmmoDisplay then
			physicalAmmoDisplay:Destroy()
		end
	end

	local valueFolder = tool:FindFirstChild("ValueFolder")
	if not valueFolder then return end

	local modeFolder = valueFolder:FindFirstChild("1")
	if not modeFolder then return end

	local mag = modeFolder:FindFirstChild("Mag")
	local ammo = modeFolder:FindFirstChild("Ammo")

	if not mag or not ammo then return end

	updateHUD(tool, mag, ammo)

	-- Optimisation par événementiel : la mise à jour graphique n'est déclenchée qu'au changement exact des ValueObjects
	table.insert(currentWeaponConnections, mag:GetPropertyChangedSignal("Value"):Connect(function()
		updateHUD(tool, mag, ammo)
	end))

	table.insert(currentWeaponConnections, ammo:GetPropertyChangedSignal("Value"):Connect(function()
		updateHUD(tool, mag, ammo)
	end))
end

-- Gère les événements d'ajout et de suppression d'outils liés à l'instance de personnage du joueur
local function setupCharacter(char)
	cleanupConnections()

	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.wait(0.1) 
			onToolEquipped(child)
		end
	end)

	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			cleanupConnections()
		end
	end)

	local currentTool = char:FindFirstChildOfClass("Tool")
	if currentTool then
		onToolEquipped(currentTool)
	end
end

if player.Character then
	setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)