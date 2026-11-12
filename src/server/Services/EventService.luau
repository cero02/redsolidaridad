--!strict
-- Eventos del mundo (pilares FOMO sano y comunidad, docs/design/PILARES.md):
--   · Decreto del César: reto semanal que cambia el combate y da un título. Rota y vuelve.
--   · Juegos Imperiales: ventana de experiencia ×2 que surge en el servidor de vez en cuando
--     o cuando la comunidad completa las ofrendas al templo.
--   · Ofrendas: cada Hidra vencida en el servidor suma a una meta común.
--   · Noticias: lo que hacen los demás gladiadores se anuncia a todo el servidor.
-- Ningún evento castiga a quien no está: solo premia a quien está.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DecreeCalendar = require(ReplicatedStorage.Shared.Meta.DecreeCalendar)
local Decrees = require(ReplicatedStorage.Shared.Config.Decrees)
local Locale = require(ReplicatedStorage.Shared.Locale.Locale)
local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ServerText = require(game:GetService("ServerScriptService").Server.Localization.ServerText)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local GAMES_DURATION = 4 * 60
local GAMES_MULTIPLIER = 2
-- Los Juegos surgen solos cada 15–25 minutos de servidor.
local GAMES_MIN_INTERVAL = 15 * 60
local GAMES_MAX_INTERVAL = 25 * 60
local OFFERING_GOAL = 5
local NEWS_HISTORY = 6
local BROADCAST_INTERVAL = 30
local BOARD_POSITION = Vector3.new(-18, 0, -8)

local EventService = {}

-- Empiezan unos Juegos Imperiales.
EventService.GamesStarted = Signal.new() :: Signal.Signal<()>

local gamesUntil = 0
local nextGamesAt = 0
local offerings = 0
local recentNews: { { key: string, params: { [string]: any }? } } = {}
local boardLabel: TextLabel? = nil
local random = Random.new()

local function decree(): (Decrees.Decree, number)
	local index, remaining = DecreeCalendar.current(os.time(), #Decrees)
	return Decrees[index], remaining
end

local function gamesRemaining(): number
	return math.max(0, gamesUntil - os.clock())
end

local function snapshot()
	local current, remaining = decree()
	return {
		decreeId = current.id,
		decreeRemaining = remaining,
		gamesRemaining = gamesRemaining(),
		offerings = offerings,
		goal = OFFERING_GOAL,
	}
end

local function refreshBoard()
	local label = boardLabel
	if label == nil then
		return
	end
	local current, remaining = decree()
	local games = gamesRemaining()
	local gamesLine = if games > 0
		then Locale.ref(
			"board.gamesActive",
			{ mult = GAMES_MULTIPLIER, minutes = math.ceil(games / 60) }
		)
		else Locale.ref("board.offerings", { count = offerings, goal = OFFERING_GOAL })
	ServerText.setWorld(label, "Text", "board.edict", {
		decree = Locale.ref(`decree.{current.id}.name`),
		desc = Locale.ref(`decree.{current.id}.desc`),
		remaining = DecreeCalendar.formatRemaining(remaining),
		games = gamesLine,
	})
end

local function broadcast(player: Player?)
	local data = snapshot()
	if player then
		NetService.fire("WorldEvents", player, data)
	else
		NetService.fireAll("WorldEvents", data)
	end
	refreshBoard()
end

local function buildBoard()
	local board = Instance.new("Part")
	board.Name = "EdictoDelCesar"
	board.Anchored = true
	board.Size = Vector3.new(12, 9, 1)
	board.CFrame = CFrame.lookAt(BOARD_POSITION + Vector3.new(0, 5, 0), Vector3.new(0, 5, 10))
	board.Color = Color3.fromRGB(200, 190, 165)
	board.Material = Enum.Material.Marble
	board.Parent = Workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.RichText = true
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.Antique
	label.TextColor3 = Color3.fromRGB(60, 35, 20)
	label.Parent = gui
	boardLabel = label
end

local function scheduleNextGames()
	nextGamesAt = os.clock() + random:NextNumber(GAMES_MIN_INTERVAL, GAMES_MAX_INTERVAL)
end

-- Envía una noticia (clave de idioma) a todo el servidor y la guarda en el historial
-- reciente, que reciben los jugadores al entrar (menú de inicio: "Desde la arena").
function EventService.news(key: string, params: { [string]: any }?)
	table.insert(recentNews, { key = key, params = params })
	while #recentNews > NEWS_HISTORY do
		table.remove(recentNews, 1)
	end
	NetService.fireAll("WorldNews", key, params)
end

-- `reason` es una referencia de idioma (Locale.ref).
function EventService.startGames(reason: { key: string, params: { [string]: any }? })
	if gamesRemaining() > 0 then
		return
	end
	gamesUntil = os.clock() + GAMES_DURATION
	scheduleNextGames()
	EventService.news("news.gamesStart", {
		reason = reason,
		mult = GAMES_MULTIPLIER,
		minutes = GAMES_DURATION // 60,
	})
	EventService.GamesStarted:Fire()
	broadcast(nil)
end

function EventService.isGamesActive(): boolean
	return gamesRemaining() > 0
end

function EventService.getXpMultiplier(): number
	return if gamesRemaining() > 0 then GAMES_MULTIPLIER else 1
end

function EventService.getDecree(): Decrees.Decree
	return (decree())
end

-- Una Hidra vencida en el servidor: ofrenda para la meta común.
function EventService.addOffering(byName: string)
	if gamesRemaining() > 0 then
		return
	end
	offerings += 1
	if offerings >= OFFERING_GOAL then
		offerings = 0
		EventService.startGames(Locale.ref("news.reasonOfferings", { name = byName }))
	else
		EventService.news(
			"news.offerings",
			{ count = offerings, goal = OFFERING_GOAL, left = OFFERING_GOAL - offerings }
		)
		broadcast(nil)
	end
end

function EventService.Init(_self: typeof(EventService))
	buildBoard()
end

function EventService.Start(_self: typeof(EventService))
	scheduleNextGames()
	PlayerDataService.ClientReady:Connect(function(player: Player)
		broadcast(player)
		-- Las últimas noticias, para que el menú de inicio no empiece vacío.
		for _, item in recentNews do
			NetService.fire("WorldNews", player, item.key, item.params)
		end
	end)
	refreshBoard()

	local lastDecreeId = EventService.getDecree().id
	while true do
		task.wait(BROADCAST_INTERVAL)
		local current = EventService.getDecree()
		if current.id ~= lastDecreeId then
			lastDecreeId = current.id
			EventService.news("news.newDecree", {
				decree = Locale.ref(`decree.{current.id}.name`),
				desc = Locale.ref(`decree.{current.id}.desc`),
			})
		end
		if os.clock() >= nextGamesAt and #Players:GetPlayers() > 0 then
			EventService.startGames(Locale.ref("news.reasonCaesar"))
		else
			broadcast(nil)
		end
	end
end

return EventService
