-- ============================================================
--  Ce script déclenche une animation spécifique lors de 
--  l'atterrissage du personnage au sol.
--  Il écoute les changements d'état du Humanoid et joue 
--  l'animation chargée via l'identifiant fourni pendant 
--  une durée fixe.
-- ============================================================

local anim = Instance.new("Animation") 
anim.AnimationId = "rbxassetid://100496812000890" 
local playAnim = script.Parent.Humanoid:LoadAnimation(anim)

-- Surveillance des changements d'état physique du personnage
script.Parent.Humanoid.StateChanged:Connect(function(_, state)
	-- Vérifie si l'état actuel correspond à la fin d'une chute (atterrissage)
	if state == Enum.HumanoidStateType.Landed then
		playAnim:Play()
		task.wait(1)
		playAnim:Stop()
	end
end)