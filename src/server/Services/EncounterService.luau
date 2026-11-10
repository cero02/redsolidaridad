--!strict
-- Dirige la partida contra la bestia: quién participa, entrada a la arena, presentación,
-- combate, victoria o derrota y regreso al foro. Hito 1.2: individual o en grupo
-- (cualquiera puede unirse por la puerta mientras dura el combate).

local Players = game:GetService("Players")

local ArenaService = require(script.Parent.ArenaService)
local CombatService = require(script.Parent.CombatService)
local HydraService = require(script.Parent.HydraService)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local INTRO_TIME = 5
local VICTORY_TIME = 9
local DEFEAT_TIME = 5

type State = "Idle" | "Intro" | "Fighting" | "Ending"

local EncounterService = {}

local state: State = "Idle"
local participants: { Player } = {}
local deathConnections: { [Player]: RBXScriptConnection } = {}
local progress = { cauterized = 0, required = 0 }
-- Cambia en cada partida: los hilos de una partida anterior se descartan.
local encounterId = 0

local function getParticipants(): { Player }
	return participants
end

local function announce(text: string, seconds: number, player: Player?)
	if player ~= nil then
		NetService.fire("Announce", player, text, seconds)
		return
	end
	for _, participant in participants do
		NetService.fire("Announce", participant, text, seconds)
	end
end

local function sendState(player: Player?)
	if player ~= nil then
		NetService.fire("EncounterState", player, state, progress.cauterized, progress.required)
		return
	end
	for _, participant in participants do
		NetService.fire("EncounterState", participant, state, progress.cauterized, progress.required)
	end
end

local function setState(newState: State)
	state = newState
	sendState(nil)
end

local function recordResult(player: Player, won: boolean)
	local data = PlayerDataService.get(player)
	if data == nil then
		return
	end
	data.stats.matchesPlayed += 1
	if won then
		data.stats.matchesWon += 1
		data.stats.hydraKills += 1
	end
end

local function removeParticipant(player: Player)
	local index = table.find(participants, player)
	if index == nil then
		return
	end
	table.remove(participants, index)
	local connection = deathConnections[player]
	if connection then
		connection:Disconnect()
		deathConnections[player] = nil
	end
	if player.Parent == Players then
		NetService.fire("EncounterState", player, "Idle", 0, 0)
	end
end

local function reset()
	for _, player in table.clone(participants) do
		removeParticipant(player)
	end
	HydraService.despawn()
	state = "Idle"
end

local function sendToLobby(player: Player)
	local character = player.Character
	if character and CombatService.isAlive(player) then
		character:PivotTo(ArenaService.getLobbyCFrame())
		CombatService.resetFighter(player)
	end
end

local function endEncounter(won: boolean)
	if state ~= "Intro" and state ~= "Fighting" then
		return
	end
	encounterId += 1
	local id = encounterId
	setState("Ending")

	if won then
		for _, player in participants do
			recordResult(player, true)
		end
		announce("¡VICTORIA! La Hidra se hunde en las aguas de Lerna… por ahora.", VICTORY_TIME, nil)
	end

	task.delay(if won then VICTORY_TIME else DEFEAT_TIME, function()
		if encounterId ~= id then
			return
		end
		for _, player in table.clone(participants) do
			sendToLobby(player)
		end
		reset()
	end)
end

local function onParticipantLost(player: Player, died: boolean)
	if table.find(participants, player) == nil then
		return
	end
	if died and (state == "Intro" or state == "Fighting") then
		recordResult(player, false)
		NetService.fire("Announce", player, "Has caído. La arena reclama otro nombre…", 5)
	end
	removeParticipant(player)

	if #participants == 0 and (state == "Intro" or state == "Fighting") then
		endEncounter(false)
	elseif died then
		announce(`{player.DisplayName} ha caído.`, 3, nil)
	end
end

local function addParticipant(player: Player): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end

	table.insert(participants, player)
	deathConnections[player] = humanoid.Died:Connect(function()
		onParticipantLost(player, true)
	end)

	CombatService.resetFighter(player)
	character:PivotTo(ArenaService.getEntryCFrame(#participants))
	sendState(player)
	return true
end

local function startEncounter(player: Player)
	encounterId += 1
	local id = encounterId
	state = "Intro"
	HydraService.spawn(getParticipants)
	if not addParticipant(player) then
		reset()
		return
	end

	announce("¡Ciudadanos de Roma! De los pantanos de Lerna llega… ¡LA HIDRA!", INTRO_TIME, nil)
	task.delay(INTRO_TIME, function()
		if encounterId ~= id or state ~= "Intro" then
			return
		end
		setState("Fighting")
		announce("¡Que comience el combate!", 2.5, nil)
		HydraService.begin()
	end)
end

local function onGateTriggered(player: Player)
	if table.find(participants, player) ~= nil then
		return
	end
	if state == "Idle" then
		startEncounter(player)
	elseif state == "Intro" or state == "Fighting" then
		if addParticipant(player) then
			announce(`{player.DisplayName} entra en la arena.`, 3, nil)
		end
	else
		NetService.fire("Announce", player, "El combate está terminando. Espera un momento.", 3)
	end
end

function EncounterService.Start(_self: typeof(EncounterService))
	ArenaService.GateTriggered:Connect(onGateTriggered)

	HydraService.Announcement:Connect(announce)
	HydraService.Progress:Connect(function(cauterized: number, required: number)
		progress.cauterized = cauterized
		progress.required = required
		sendState(nil)
	end)
	HydraService.Defeated:Connect(function()
		endEncounter(true)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		onParticipantLost(player, false)
	end)
end

return EncounterService
