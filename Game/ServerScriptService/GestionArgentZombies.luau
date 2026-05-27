-- ============================================================
-- Ce module gère l'attribution d'argent aux joueurs lorsqu'ils blessent ou tuent des zombies.
-- Il intègre un système d'économie dynamique basé sur l'arme utilisée et les zones touchées.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Initialisation dynamique des événements et valeurs globales
local AfficherGainEvent = ReplicatedStorage:FindFirstChild("AfficherGainArgent")
if not AfficherGainEvent then
	AfficherGainEvent = Instance.new("RemoteEvent")
	AfficherGainEvent.Name = "AfficherGainArgent"
	AfficherGainEvent.Parent = ReplicatedStorage
end

local ActiverFeverEvent = ReplicatedStorage:FindFirstChild("ActiverFever")
if not ActiverFeverEvent then
	ActiverFeverEvent = Instance.new("RemoteEvent")
	ActiverFeverEvent.Name = "ActiverFever"
	ActiverFeverEvent.Parent = ReplicatedStorage
end

local doubleArgentValue = ReplicatedStorage:FindFirstChild("DoubleArgentActif")
if not doubleArgentValue then
	doubleArgentValue = Instance.new("BoolValue")
	doubleArgentValue.Name = "DoubleArgentActif"
	doubleArgentValue.Value = false
	doubleArgentValue.Parent = ReplicatedStorage
end

local instaKillValue = ReplicatedStorage:FindFirstChild("InstaKillActif")
if not instaKillValue then
	instaKillValue = Instance.new("BoolValue")
	instaKillValue.Name = "InstaKillActif"
	instaKillValue.Value = false
	instaKillValue.Parent = ReplicatedStorage
end

local ModuleArgent = {}
local joueursFever = {}

-- ============================================================
-- 🔫 TABLE D'ÉQUILIBRAGE DES ARMES
-- ============================================================
-- Hit      : Balle non fatale
-- KillBody : Coup fatal dans le corps (torso, bras, jambes)
-- KillHead : Coup fatal dans la tête (Headshot)

local ValeurArmes = {
	["Snizer"]         = { Hit = 80, KillBody = 80, KillHead = 120 },
	["Desert Eagle 2"] = { Hit = 10, KillBody = 10, KillHead = 20  },
	["AK-207"]         = { Hit = 15, KillBody = 15, KillHead = 25  },
	["FAMAS-3"]        = { Hit = 20, KillBody = 25, KillHead = 50  },
	["GT-505"]         = { Hit = 40, KillBody = 40, KillHead = 50  },
	["DF-1008"]        = { Hit = 20, KillBody = 20, KillHead = 50  }, 
	["Galax-4"]        = { Hit = 10, KillBody = 10, KillHead = 20  }, 
	["P-240"]          = { Hit = 7, KillBody = 7, KillHead = 14  }, 
	["ShotRun"]        = { Hit = 20,  KillBody = 20, KillHead = 30  }, 
	["Default"]        = { Hit = 10, KillBody = 10, KillHead = 20  } 
}
-- ============================================================

ActiverFeverEvent.OnServerEvent:Connect(function(player)
	joueursFever[player.UserId] = os.time() + 5
end)

-- ⚠️ ATTENTION : La fonction demande maintenant le 'nomArme' (String)
function ModuleArgent.DonnerPoints(joueur, zombieHumanoid, partieToucher, degats, nomArme)
	if not zombieHumanoid or zombieHumanoid.Health <= 0 or not joueur then return end

	local statsArgent = joueur:FindFirstChild("leaderstats") and joueur.leaderstats:FindFirstChild("Argent")
	if not statsArgent then return end

	-- On récupère les valeurs de l'arme, ou celles par défaut si le nom est introuvable
	local statsArme = ValeurArmes[nomArme] or ValeurArmes["Default"]

	local coupFatal = (zombieHumanoid.Health - degats) <= 0
	local nomPartie = partieToucher.Name:lower()
	local gain = 0 

	-- Logique de distribution adaptée à l'arme
	if not coupFatal and instaKillValue.Value == false then
		-- Balle classique qui ne tue pas
		gain = statsArme.Hit
	else
		if nomPartie:match("head") then 
			gain = statsArme.KillHead
		else 
			gain = statsArme.KillBody 
		end
	end

	if gain > 0 then
		-- Multiplicateur individuel (Fever)
		local finFever = joueursFever[joueur.UserId]
		if finFever and os.time() < finFever then
			gain = gain * 2
		end

		-- Multiplicateur global (Double Argent)
		if doubleArgentValue.Value == true then
			gain = gain * 2
		end

		statsArgent.Value += gain
		AfficherGainEvent:FireClient(joueur, gain)
	end
end

return ModuleArgent