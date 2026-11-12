--!strict
-- La armería: el jugador elige arma y esencia entre las que ha desbloqueado. Solo fuera de
-- la arena. Los cambios se guardan en el perfil y avisan al combate y al equipamiento.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Essences = require(ReplicatedStorage.Shared.Config.Essences)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

-- Atributo que EncounterService pone en los jugadores que están en la arena.
local IN_ARENA = "InArena"

local LoadoutService = {}

-- Cambió el arma o la esencia de un jugador.
LoadoutService.Changed = Signal.new() :: Signal.Signal<Player>

-- Equipamiento válido del jugador (si el perfil tiene algo bloqueado o inexistente, se
-- corrige al equipamiento inicial).
function LoadoutService.get(player: Player): (string, string)
	local data = PlayerDataService.get(player)
	if data == nil then
		return "Gladius", "Loba"
	end
	local weapon = data.loadout.weapon
	local essence = data.loadout.essence
	if Weapons[weapon] == nil or not data.unlockedWeapons[weapon] then
		weapon = "Gladius"
	end
	if Essences[essence] == nil or not data.unlockedEssences[essence] then
		essence = "Loba"
	end
	return weapon, essence
end

function LoadoutService.Start(_self: typeof(LoadoutService))
	NetService.on("SetLoadout", function(player: Player, weapon: string, essence: string)
		local data = PlayerDataService.get(player)
		if data == nil then
			return
		end
		if player:GetAttribute(IN_ARENA) == true then
			NetService.fire("Announce", player, "ann.noLoadoutInArena", nil, 3)
			return
		end
		if Weapons[weapon] == nil or not data.unlockedWeapons[weapon] then
			return
		end
		if Essences[essence] == nil or not data.unlockedEssences[essence] then
			return
		end
		if data.loadout.weapon == weapon and data.loadout.essence == essence then
			return
		end
		data.loadout.weapon = weapon
		data.loadout.essence = essence
		ProgressionService.refresh(player)
		LoadoutService.Changed:Fire(player)
	end)

	-- Al cargar el perfil, el combate y el equipamiento usan lo guardado.
	PlayerDataService.Loaded:Connect(function(player: Player)
		LoadoutService.Changed:Fire(player)
	end)
end

return LoadoutService
