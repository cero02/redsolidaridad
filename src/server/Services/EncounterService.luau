--!strict
-- Dirige la partida contra la bestia: quién participa, entrada a la arena, presentación,
-- combate, caídos y reanimaciones, victoria o derrota y regreso al foro. Individual o en
-- grupo: cualquiera puede unirse por la puerta mientras dura el combate.

local Players = game:GetService("Players")

local ArenaService = require(script.Parent.ArenaService)
local CombatService = require(script.Parent.CombatService)
local HydraService = require(script.Parent.HydraService)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local INTRO_TIME = 5
local VICTORY_TIME = 9
local DEFEAT_TIME = 5

-- Caídos (docs/design/COMBATE.md).
local DOWNED_TIME = 15
local REVIVE_HOLD_TIME = 3
local REVIVE_HEALTH = 0.4
-- En solitario, una vez por partida, el público te concede otra oportunidad.
local SECOND_CHANCE_DELAY = 3
local SECOND_CHANCE_HEALTH = 0.3

type State = "Idle" | "Intro" | "Fighting" | "Ending"

local EncounterService = {}

local state: State = "Idle"
local participants: { Player } = {}
local deathConnections: { [Player]: RBXScriptConnection } = {}
local revivePrompts: { [Player]: ProximityPrompt } = {}
local progressText = ""
local fightStartedAt = 0
local secondChanceUsed = false
-- Cambia en cada partida: los hilos de una partida anterior se descartan.
local encounterId = 0

local function getParticipants(): { Player }
	return participants
end

local function isFighting(): boolean
	return state == "Intro" or state == "Fighting"
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
		NetService.fire("EncounterState", player, state, progressText)
		return
	end
	for _, participant in participants do
		NetService.fire("EncounterState", participant, state, progressText)
	end
end

local function setState(newState: State)
	state = newState
	sendState(nil)
end

local function formatTime(seconds: number): string
	local whole = math.floor(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- Guarda el resultado. Devuelve true si el jugador ha batido su récord personal.
local function recordResult(player: Player, won: boolean, elapsed: number): boolean
	local data = PlayerDataService.get(player)
	if data == nil then
		return false
	end
	data.stats.matchesPlayed += 1
	if not won then
		return false
	end
	data.stats.matchesWon += 1
	data.stats.hydraKills += 1
	local best = data.stats.bestHydraTime
	if best <= 0 or elapsed < best then
		data.stats.bestHydraTime = elapsed
		return true
	end
	return false
end

local function clearRevivePrompt(player: Player)
	local prompt = revivePrompts[player]
	if prompt then
		prompt:Destroy()
		revivePrompts[player] = nil
	end
end

local function removeParticipant(player: Player)
	local index = table.find(participants, player)
	if index == nil then
		return
	end
	table.remove(participants, index)
	clearRevivePrompt(player)
	local connection = deathConnections[player]
	if connection then
		connection:Disconnect()
		deathConnections[player] = nil
	end
	if player.Parent == Players then
		NetService.fire("EncounterState", player, "Idle", "")
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
	if character == nil then
		return
	end
	if CombatService.isDowned(player) then
		CombatService.revive(player, 1)
	end
	if CombatService.isAlive(player) then
		character:PivotTo(ArenaService.getLobbyCFrame())
		CombatService.resetFighter(player)
	end
end

local function endEncounter(won: boolean)
	if not isFighting() then
		return
	end
	encounterId += 1
	local id = encounterId
	local elapsed = os.clock() - fightStartedAt
	setState("Ending")

	if won then
		for _, player in participants do
			local newRecord = recordResult(player, true, elapsed)
			local data = PlayerDataService.get(player)
			local best = if data then data.stats.bestHydraTime else elapsed
			local text = `¡VICTORIA! La Hidra yace bajo la roca. Tiempo {formatTime(elapsed)}`
			if newRecord then
				text ..= " · ¡NUEVO RÉCORD PERSONAL!"
			else
				text ..= ` · Tu récord: {formatTime(best)}`
			end
			NetService.fire("Announce", player, text, VICTORY_TIME)
		end
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
	if died and isFighting() then
		recordResult(player, false, 0)
		NetService.fire("Announce", player, "Has caído. La arena reclama otro nombre…", 5)
	end
	removeParticipant(player)

	if #participants == 0 and isFighting() then
		endEncounter(false)
	elseif died then
		announce(`{player.DisplayName} ha muerto en la arena.`, 3, nil)
	end
end

local function revive(player: Player, healthFraction: number)
	clearRevivePrompt(player)
	CombatService.revive(player, healthFraction)
end

-- Un compañero puede levantar al caído manteniendo la interacción.
local function addRevivePrompt(player: Player)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Reanimar"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = REVIVE_HOLD_TIME
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	revivePrompts[player] = prompt

	prompt.Triggered:Connect(function(rescuer: Player)
		local validRescuer = rescuer ~= player
			and table.find(participants, rescuer) ~= nil
			and CombatService.isAlive(rescuer)
		if validRescuer and CombatService.isDowned(player) then
			revive(player, REVIVE_HEALTH)
			announce(`¡{rescuer.DisplayName} ha levantado a {player.DisplayName}!`, 3, nil)
			local data = PlayerDataService.get(rescuer)
			if data then
				data.stats.revives += 1
			end
		end
	end)
end

-- Decide qué pasa cuando un gladiador llega a 0 de vida: true = queda caído.
local function onZeroHealth(player: Player): boolean
	if state ~= "Fighting" or table.find(participants, player) == nil then
		return false
	end
	local id = encounterId

	local othersStanding = false
	for _, other in participants do
		if other ~= player and CombatService.isAlive(other) then
			othersStanding = true
			break
		end
	end

	if othersStanding then
		announce(`¡{player.DisplayName} ha caído! Reanimadlo antes de {DOWNED_TIME} s.`, 4, nil)
		-- El aviso se crea un instante después, cuando el jugador ya consta como caído.
		task.defer(addRevivePrompt, player)
		task.delay(DOWNED_TIME, function()
			if encounterId == id and CombatService.isDowned(player) then
				clearRevivePrompt(player)
				CombatService.finishOff(player)
			end
		end)
		return true
	end

	if #participants == 1 and not secondChanceUsed then
		secondChanceUsed = true
		NetService.fire("Announce", player, "El público ruge tu nombre… ¡LEVÁNTATE, GLADIADOR!", SECOND_CHANCE_DELAY)
		task.delay(SECOND_CHANCE_DELAY, function()
			if encounterId == id and CombatService.isDowned(player) then
				revive(player, SECOND_CHANCE_HEALTH)
			end
		end)
		return true
	end

	-- Era el último en pie: los caídos que esperaban ya no tienen quien los levante.
	for _, other in participants do
		if other ~= player and CombatService.isDowned(other) then
			clearRevivePrompt(other)
			task.defer(CombatService.finishOff, other)
		end
	end
	return false
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
	secondChanceUsed = false
	fightStartedAt = os.clock()
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
		fightStartedAt = os.clock()
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
	elseif isFighting() then
		if addParticipant(player) then
			announce(`{player.DisplayName} entra en la arena.`, 3, nil)
		end
	else
		NetService.fire("Announce", player, "El combate está terminando. Espera un momento.", 3)
	end
end

function EncounterService.Start(_self: typeof(EncounterService))
	ArenaService.GateTriggered:Connect(onGateTriggered)
	CombatService.setZeroHealthHandler(onZeroHealth)

	HydraService.Announcement:Connect(announce)
	HydraService.Progress:Connect(function(text: string)
		progressText = text
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
