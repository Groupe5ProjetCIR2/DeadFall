-- ============================================================
--  Ce script gère un système de jauge d'endurance (Stamina)
--  avec fonctions de consommation directe, de drainage continu,
--  et un mécanisme de récupération automatique après un délai.
--  Il intègre également un état d'épuisement bloquant les actions.
-- ============================================================

local RunService = game:GetService("RunService")

local StaminaManager = {}

StaminaManager.Max = 100
StaminaManager.Current = 100
StaminaManager.RegenDelay = 1.75

StaminaManager.RegenRate = 100

StaminaManager.LastUse = 0
StaminaManager.IsExhausted = false

-- Soustraction instantanée d'une quantité fixe d'endurance (ex: saut ou esquive)
function StaminaManager:Consume(amount)
	if self.IsExhausted then return false end

	if self.Current >= amount then
		self.Current = self.Current - amount
		self.LastUse = tick()

		if self.Current <= 0 then
			self.Current = 0
			self.IsExhausted = true
		end

		return true
	end
	return false
end

-- Diminution progressive de l'endurance par seconde liée au temps delta (ex: course ou jetpack)
function StaminaManager:Drain(ratePerSecond, dt)
	if self.IsExhausted then return false end

	if self.Current > 0 then
		self.Current = math.max(0, self.Current - (ratePerSecond * dt))
		self.LastUse = tick()

		if self.Current <= 0 then
			self.Current = 0
			self.IsExhausted = true
			return false 
		end

		return true
	end
	return false
end

-- Boucle de rafraîchissement physique calculant la temporisation et la régénération passive de la jauge
RunService.Heartbeat:Connect(function(dt)
	if tick() - StaminaManager.LastUse >= StaminaManager.RegenDelay then
		if StaminaManager.Current < StaminaManager.Max then
			StaminaManager.Current = math.min(StaminaManager.Max, StaminaManager.Current + (StaminaManager.RegenRate * dt))

			if StaminaManager.Current >= StaminaManager.Max then
				StaminaManager.IsExhausted = false
			end
		end
	end
end)

return StaminaManager