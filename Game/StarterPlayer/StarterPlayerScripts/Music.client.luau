-- ============================================================
--  Ce script a pour but de gérer la lecture aléatoire d'une 
--  playlist de musiques de fond. Il s'assure que toutes les 
--  pistes sont configurées avec le bon volume, sélectionne 
--  une nouvelle musique en évitant de rejouer la précédente, 
--  et boucle la lecture indéfiniment de manière autonome.
-- ============================================================

local SoundService = game:GetService("SoundService")

local VOLUME_LEGER = 0.60
local bgMusicFolder = SoundService:WaitForChild("bgMusic")

local lastSong = nil

-- Parcourt le dossier cible pour s'assurer que chaque piste audio possède le bon volume et ne boucle pas sur elle-même
local function setupMusics()
	for _, song in ipairs(bgMusicFolder:GetChildren()) do
		if song:IsA("Sound") then
			song.Volume = VOLUME_LEGER
			song.Looped = false
		end
	end
end

-- Filtre la dernière musique jouée pour éviter les répétitions immédiates, puis sélectionne aléatoirement la prochaine piste
local function getNextSong()
	local allSongs = bgMusicFolder:GetChildren()
	local availableSongs = {}

	for _, song in ipairs(allSongs) do
		if song:IsA("Sound") and song ~= lastSong then
			table.insert(availableSongs, song)
		end
	end

	if #availableSongs == 0 then
		return allSongs[1]
	end

	local randomSong = availableSongs[math.random(1, #availableSongs)]
	return randomSong
end

-- Boucle indéfiniment en mettant le script en pause (.Ended:Wait()) jusqu'à la fin de la musique en cours avant de lancer la suivante
local function startPlaylist()
	setupMusics()

	while true do
		local currentSong = getNextSong()

		if currentSong then
			lastSong = currentSong
			print("🎵 En cours de lecture : " .. currentSong.Name)

			currentSong:Play()
			currentSong.Ended:Wait()
		else
			task.wait(2) 
		end
	end
end

-- Lance la boucle de la playlist sur un thread séparé (task.spawn) pour s'assurer de ne pas bloquer l'exécution du reste du jeu
task.spawn(startPlaylist)