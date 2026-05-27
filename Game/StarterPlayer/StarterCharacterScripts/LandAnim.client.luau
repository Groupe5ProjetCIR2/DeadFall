-- ============================================================
-- Ce script charge et joue une animation spécifique lorsque le personnage atterrit sur le sol.
-- L'animation est déclenchée lors de l'impact et s'arrête automatiquement au bout d'une seconde.
-- ============================================================

local anim = Instance.new("Animation") anim.AnimationId = "rbxassetid://100496812000890" 
local playAnim = script.Parent.Humanoid:LoadAnimation(anim)

-- Détecte les transitions d'état du moteur physique pour réagir au moment précis de l'atterrissage
script.Parent.Humanoid.StateChanged:Connect(function(_,state)
	if state == Enum.HumanoidStateType.Landed then
		playAnim:Play()
		wait(1)
		playAnim:Stop()
	end

end)