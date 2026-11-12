--!strict
-- El Códice (pilar sentirse inteligente, docs/design/PILARES.md): cuando un jugador
-- descubre por sí mismo una mecánica, se le revela su nombre latino, gana experiencia y
-- queda escrita en su Códice. Al completarlo obtiene el título «Erudito de Lerna».

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaService = require(script.Parent.ArenaService)
local Codex = require(ReplicatedStorage.Shared.Config.Codex)
local CombatService = require(script.Parent.CombatService)
local EventService = require(script.Parent.EventService)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)

local CodexService = {}

local byId: { [string]: Codex.Discovery } = {}
for _, discovery in Codex do
	byId[discovery.id] = discovery
end

local function countDiscovered(codex: { [string]: boolean }): number
	local count = 0
	for _, discovery in Codex do
		if codex[discovery.id] then
			count += 1
		end
	end
	return count
end

-- ¿Ya conoce este secreto? (para dar pistas solo a quien no lo sabe).
function CodexService.knows(player: Player, id: string): boolean
	local data = PlayerDataService.get(player)
	return data ~= nil and data.codex[id] == true
end

-- Registra un descubrimiento. Devuelve true si era nuevo.
function CodexService.discover(player: Player, id: string): boolean
	local data = PlayerDataService.get(player)
	local discovery = byId[id]
	if data == nil or discovery == nil or data.codex[id] then
		return false
	end
	data.codex[id] = true
	local count = countDiscovered(data.codex)

	NetService.fire("Discovery", player, id, count, #Codex)
	EventService.news("news.discovery", { name = player.DisplayName, count = count, total = #Codex })
	ProgressionService.grantXp(player, discovery.xp)

	if count >= #Codex then
		ProgressionService.grantTitle(player, "Erudito")
	end
	return true
end

function CodexService.Start(_self: typeof(CodexService))
	-- Secretos que se pueden descubrir en cualquier combate.
	CombatService.Parried:Connect(function(player: Player)
		CodexService.discover(player, "ParmaPerfecta")
	end)
	ArenaService.BrazierRelit:Connect(function(player: Player)
		CodexService.discover(player, "IgnisRenatus")
	end)
	-- Al cargar el perfil se comprueba si ya merece el título del Códice completo.
	PlayerDataService.Loaded:Connect(function(player: Player, data)
		if countDiscovered(data.codex) >= #Codex then
			ProgressionService.grantTitle(player, "Erudito")
		end
	end)
end

return CodexService
