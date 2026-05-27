-- ============================================================
--  Ce script initialise les références vers les dossiers contenant
--  les lignes de dialogue audio et événementielles. Ces dossiers
--  sont stockés dans le ReplicatedStorage pour être accessibles partout.
-- ============================================================

-- Récupération des dossiers répliqués entre le client et le serveur pour y puiser les assets audio
local replicatedStorage_folder_voiceslines = game:GetService("ReplicatedStorage").VoiceLines
local replicatedStorage_folder_eventvoiceslines = game:GetService("ReplicatedStorage").EventVoices