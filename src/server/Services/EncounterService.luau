--!strict
-- Dirige la partida contra la bestia: quién participa, entrada a la arena, presentación,
-- combate, caídos y reanimaciones, victoria o derrota, recompensas y regreso al foro.
-- Individual o en grupo: cualquiera puede unirse por la puerta mientras dura el combate.
-- Pilares (docs/design/PILARES.md): progreso, presumir, comunidad, FOMO sano y Códice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArenaService = require(script.Parent.ArenaService)
local CodexService = require(script.Parent.CodexService)
local CombatService = require(script.Parent.CombatService)
local EventService = require(script.Parent.EventService)
local HydraService = require(script.Parent.HydraService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MatchRewards = require(ServerScriptService.Server.Meta.MatchRewards)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Progression = require(ReplicatedStorage.Shared.Meta.Progression)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local ProgressionService = require(script.Parent.ProgressionService)

local INTRO_TIME = 6
local VICTORY_TIME = 10
local DEFEAT_TIME = 5

-- Caídos (docs/design/COMBATE.md).
local DOWNED_TIME = 15
local REVIVE_HOLD_TIME = 3
local REVIVE_HEALTH = 0.4
-- En solitario, una vez por partida, el público te concede otra oportunidad.
local SECOND_CHANCE_DELAY = 3
local SECOND_CHANCE_HEALTH = 0.3

-- Hazañas con título (docs/design/PILARES.md).
local VELOX_TIME = 6 * 60
local GAMES_MULTIPLIER = 2
local MATAHIDRAS_WINS = 10
local FRATER_REVIVES = 10

type State = "Idle" | "Intro" | "Fighting" | "Ending"
type MatchStats = { parries: number, revives: number, downs: number }

local EncounterService = {}

local state: State = "Idle"
local participants: { Player } = {}
local deathConnections: { [Player]: RBXScriptConnection } = {}
local revivePrompts: { [Player]: ProximityPrompt } = {}
local matchStats: { [Player]: MatchStats } = {}
local progressText = ""
local fightStartedAt = 0
local phasesCleared = 0
local gamesDuringMatch = false
local secondChanceUsed = false
-- Cambia en cada partida: los hilos de una partida anterior se descartan.
local encounterId = 0

local progressionConfig = ProgressionConfig :: any

local function getParticipants(): { Player }
	return participants
end

local function isFighting(): boolean
	return state == "Intro" or state == "Fighting"
end

local function today(): number
	return os.time() // 86400
end

local function formatTime(seconds: number): string
	local whole = math.floor(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
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

-- Calcula, concede y envía las recompensas de un jugador.
local function reward(player: Player, won: boolean, elapsed: number)
	local data = PlayerDataService.get(player)
	local stats = matchStats[player]
	if data == nil or stats == nil then
		return
	end
	local decree = EventService.getDecree()

	-- Estadísticas guardadas.
	data.stats.matchesPlayed += 1
	data.stats.perfectParries += stats.parries
	local newRecord = false
	local firstWinOfDay = false
	if won then
		data.stats.matchesWon += 1
		data.stats.hydraKills += 1
		firstWinOfDay = data.lastWinDay ~= today()
		data.lastWinDay = today()
		data.decreeWins[decree.id] = (data.decreeWins[decree.id] or 0) + 1
		local best = data.stats.bestHydraTime
		if best <= 0 or elapsed < best then
			data.stats.bestHydraTime = elapsed
			newRecord = true
		end
	end

	-- Mentor: un veterano luchando junto a un novato.
	local novicePresent = false
	for _, other in participants do
		local otherData = if other ~= player then PlayerDataService.get(other) else nil
		if otherData and otherData.level <= ProgressionConfig.XP.NOVICE_MAX_LEVEL then
			novicePresent = true
		end
	end

	local rewardResult = MatchRewards.compute(ProgressionConfig.XP, {
		won = won,
		phasesCleared = phasesCleared,
		perfectParries = stats.parries,
		revives = stats.revives,
		firstWinOfDay = firstWinOfDay,
		allies = math.max(0, #participants - 1),
		mentor = novicePresent and data.level >= ProgressionConfig.XP.MENTOR_MIN_LEVEL,
		decreeMultiplier = decree.xpMultiplier,
		-- Si los Juegos estaban activos en algún momento de la partida, cuentan.
		eventMultiplier = if gamesDuringMatch then GAMES_MULTIPLIER else 1,
	})

	local levelBefore = data.level
	local levelResult = ProgressionService.grantXp(player, rewardResult.total)

	-- Títulos de hazañas (se conceden después de la experiencia para lucir el último).
	if won then
		ProgressionService.grantTitle(player, decree.titleId)
		if data.stats.hydraKills >= MATAHIDRAS_WINS then
			ProgressionService.grantTitle(player, "Matahidras")
		end
		if stats.downs == 0 then
			CodexService.discover(player, "Intactus")
			ProgressionService.grantTitle(player, "Intactus")
		end
		if elapsed < VELOX_TIME then
			ProgressionService.grantTitle(player, "Velox")
		end
		if gamesDuringMatch then
			ProgressionService.grantTitle(player, "Testigo")
		end
		LeaderboardService.submit(player, elapsed)
	end

	local nextLevel, nextUnlocks = Progression.nextUnlock(progressionConfig, data.level)
	NetService.fire("MatchResults", player, {
		won = won,
		time = elapsed,
		record = newRecord,
		best = data.stats.bestHydraTime,
		total = rewardResult.total,
		lines = rewardResult.lines,
		levelBefore = levelBefore,
		level = data.level,
		xp = data.xp,
		xpToNext = Progression.xpToNext(progressionConfig, data.level),
		unlocks = if levelResult then levelResult.unlocks else {},
		nextLevel = nextLevel,
		nextUnlocks = nextUnlocks,
		decree = decree.name,
	})
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
	matchStats[player] = nil
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
		local names = {}
		for _, player in participants do
			table.insert(names, player.DisplayName)
			announce(`¡VICTORIA! La Hidra yace bajo la roca. Tiempo {formatTime(elapsed)}`, VICTORY_TIME, player)
			reward(player, true, elapsed)
		end
		-- Comunidad: todo el servidor se entera y suma una ofrenda.
		EventService.news(`¡{table.concat(names, " y ")} han vencido a la Hidra en {formatTime(elapsed)}!`)
		EventService.addOffering(names[1] or "un gladiador")
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
		NetService.fire("Announce", player, "Has caído. La arena reclama otro nombre…", 5)
		reward(player, false, 0)
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
		if not validRescuer or not CombatService.isDowned(player) then
			return
		end
		revive(player, REVIVE_HEALTH)
		announce(`¡{rescuer.DisplayName} ha levantado a {player.DisplayName}!`, 3, nil)
		local stats = matchStats[rescuer]
		if stats then
			stats.revives += 1
		end
		local data = PlayerDataService.get(rescuer)
		if data then
			data.stats.revives += 1
			if data.stats.revives >= FRATER_REVIVES then
				ProgressionService.grantTitle(rescuer, "Frater")
			end
		end
		CodexService.discover(rescuer, "Frater")
	end)
end

-- Decide qué pasa cuando un gladiador llega a 0 de vida: true = queda caído.
local function onZeroHealth(player: Player): boolean
	if state ~= "Fighting" or table.find(participants, player) == nil then
		return false
	end
	local id = encounterId
	local stats = matchStats[player]
	if stats then
		stats.downs += 1
	end

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
	matchStats[player] = { parries = 0, revives = 0, downs = 0 }
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
	phasesCleared = 0
	gamesDuringMatch = EventService.isGamesActive()
	fightStartedAt = os.clock()

	local decree = EventService.getDecree()
	HydraService.spawn(getParticipants, decree)
	if not addParticipant(player) then
		reset()
		return
	end

	announce(
		`¡Ciudadanos de Roma! De los pantanos de Lerna llega… ¡LA HIDRA! · {decree.name}: {decree.description}`,
		INTRO_TIME,
		nil
	)
	EventService.news(`{player.DisplayName} desafía a la Hidra. ¡Aún puedes unirte por la puerta del coliseo!`)
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
			announce(`{player.DisplayName} entra en la arena. ¡La Hermandad crece!`, 3, nil)
		end
	else
		NetService.fire("Announce", player, "El combate está terminando. Espera un momento.", 3)
	end
end

function EncounterService.Start(_self: typeof(EncounterService))
	ArenaService.GateTriggered:Connect(onGateTriggered)
	CombatService.setZeroHealthHandler(onZeroHealth)

	CombatService.Parried:Connect(function(player: Player)
		local stats = matchStats[player]
		if stats then
			stats.parries += 1
		end
	end)

	EventService.GamesStarted:Connect(function()
		if isFighting() then
			gamesDuringMatch = true
			announce("¡Los Juegos Imperiales han comenzado! Esta victoria vale el doble.", 4, nil)
		end
	end)

	HydraService.Announcement:Connect(announce)
	HydraService.Progress:Connect(function(text: string)
		progressText = text
		sendState(nil)
	end)
	HydraService.PhaseCleared:Connect(function(phase: number)
		phasesCleared = math.max(phasesCleared, phase)
	end)
	HydraService.Feat:Connect(function(player: Player?, id: string)
		if player then
			CodexService.discover(player, id)
		else
			for _, participant in participants do
				CodexService.discover(participant, id)
			end
		end
	end)
	HydraService.Defeated:Connect(function()
		endEncounter(true)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		onParticipantLost(player, false)
	end)
end

return EncounterService
