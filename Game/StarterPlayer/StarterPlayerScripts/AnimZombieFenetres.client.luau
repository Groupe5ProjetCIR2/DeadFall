-- ============================================================
--  Ce script a pour but de réceptionner un signal du serveur 
--  pour déclencher une animation spécifique sur un 
--  zombie-cyborg, comme frapper à une fenêtre. Il s'assure 
--  d'abord que le monstre est bien valide dans le jeu, puis 
--  force le lancement de l'animation en modifiant une variable 
--  de son script interne AnimateRobot.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playAnimEvent = ReplicatedStorage:WaitForChild("AnimZombieFenetres", 10)

if not playAnimEvent then
	return
end

-- S'exécute à la réception du signal serveur : vérifie la validité du zombie et prépare le lancement de l'animation
playAnimEvent.OnClientEvent:Connect(function(zombie, animName)

	if not zombie or not zombie.Parent then
		return
	end

	local animateScript = zombie:FindFirstChild("AnimateRobot")
	if not animateScript then
		return
	end

	local msgValue = animateScript:FindFirstChild("msg")
	if not msgValue then
		return
	end

	-- On vide la valeur puis on attend une frame (task.wait) avant de mettre la nouvelle.
	-- Cela force le script AnimateRobot à détecter un changement de valeur (.Changed), même si la même animation est jouée deux fois de suite.
	msgValue.Value = ""
	task.wait()
	msgValue.Value = animName
end)