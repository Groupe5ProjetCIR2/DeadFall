-- ============================================================
-- Ce script simule l'effet d'un lampadaire défectueux en créant des cycles aléatoires d'éclairage, de pannes et de clignotements.
-- Il agit en même temps sur un SpotLight et un Beam.
-- ============================================================

local streetLight = script.Parent

local spotLight = streetLight.Part.SpotLight
local beam = streetLight.lightbeam.bem.Beam

-- Fonction utilitaire permettant d'activer ou de désactiver simultanément tous les composants lumineux de la structure
local function setLumiere(etat)
	spotLight.Enabled = etat
	beam.Enabled = etat
end

-- Boucle procédurale principale régissant le comportement temporel : phases stables, glitchs rapides et coupures prolongées
while true do
	setLumiere(true)
	task.wait(math.random(10, 50) / 10) 

	local nbClignotements = math.random(2, 6)

	for i = 1, nbClignotements do
		setLumiere(false)
		task.wait(math.random(2, 8) / 100) 

		setLumiere(true)
		task.wait(math.random(2, 8) / 100) 
	end

	if math.random(1, 3) == 1 then
		setLumiere(false)
		task.wait(math.random(5, 20) / 10) 
	end
end