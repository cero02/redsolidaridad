--!strict
-- Carga y guarda el perfil de cada jugador con ProfileStore (bloqueo de sesión).
-- Es el ÚNICO módulo que usa ProfileStore: el resto del juego pasa por aquí.
-- Decisión: docs/adr/0003-persistencia-profilestore.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local DataConfig = require(ServerScriptService.Server.Data.DataConfig)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Migrations = require(ServerScriptService.Server.Data.Migrations)
local NetService = require(script.Parent.NetService)
local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local Schema = require(ServerScriptService.Server.Data.Schema)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local KICK_LOAD_FAILED = "No se pudieron cargar tus datos. Vuelve a entrar en unos minutos."
local KICK_SESSION_ENDED = "Tu partida se abrió en otro servidor. Vuelve a entrar si no fuiste tú."

local log = Log.new("PlayerDataService")

local PlayerDataService = {}

-- Se dispara cuando el perfil de un jugador está listo: (player, data).
PlayerDataService.Loaded = Signal.new() :: Signal.Signal<Player, Schema.ProfileData>
-- El cliente ya escucha sus mensajes: buen momento para enviarle su estado.
PlayerDataService.ClientReady = Signal.new() :: Signal.Signal<Player>

local store: any
local profiles: { [Player]: any } = {}
local clientReady: { [Player]: boolean } = {}

local function sendProfileIfReady(player: Player)
	local profile = profiles[player]
	if profile ~= nil and clientReady[player] then
		NetService.fire("ProfileReady", player, Schema.toPublic(profile.Data))
	end
end

local function loadProfile(player: Player)
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Rechazado o cancelado (el jugador salió mientras cargaba).
		if player.Parent == Players then
			player:Kick(KICK_LOAD_FAILED)
		end
		return
	end

	profile:AddUserId(player.UserId) -- cumplimiento del derecho al olvido (GDPR)
	profile:Reconcile() -- añade los campos nuevos del template sin tocar los existentes

	local ok, err = pcall(Migrations.apply, profile.Data, Schema.VERSION)
	if not ok then
		log:error(`Migración fallida para {player.UserId}: {err}`)
		profile:EndSession()
		player:Kick(KICK_LOAD_FAILED)
		return
	end

	-- La sesión terminó sin que el jugador saliera (p. ej. otro servidor la tomó):
	-- ya no se guardaría nada, así que se le expulsa para no perder progreso.
	profile.OnSessionEnd:Connect(function()
		if profiles[player] == profile then
			profiles[player] = nil
			if player.Parent == Players then
				player:Kick(KICK_SESSION_ENDED)
			end
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	PlayerDataService.Loaded:Fire(player, profile.Data)
	sendProfileIfReady(player)
end

function PlayerDataService.Init(_self: typeof(PlayerDataService))
	store = ProfileStore.New(DataConfig.STORE_NAME, Schema.template)
	if RunService:IsStudio() and not DataConfig.USE_LIVE_DATA_IN_STUDIO then
		store = store.Mock
		log:info("Studio: usando datos simulados (ProfileStore.Mock)")
	end
end

function PlayerDataService.Start(_self: typeof(PlayerDataService))
	ProfileStore.OnError:Connect(function(message: string, storeName: string, key: string)
		log:warn(`Error de DataStore en {storeName}/{key}: {message}`)
	end)

	NetService.on("ClientReady", function(player: Player)
		clientReady[player] = true
		sendProfileIfReady(player)
		PlayerDataService.ClientReady:Fire(player)
	end)

	Players.PlayerAdded:Connect(loadProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		clientReady[player] = nil
		local profile = profiles[player]
		if profile ~= nil then
			profiles[player] = nil -- antes de EndSession: salida normal, no expulsar
			profile:EndSession()
		end
	end)
end

-- Datos del jugador o nil si aún no han cargado. Modificar solo desde el servidor.
function PlayerDataService.get(player: Player): Schema.ProfileData?
	local profile = profiles[player]
	return if profile ~= nil then profile.Data else nil
end

-- Guarda inmediatamente (solo para momentos críticos, p. ej. compras).
function PlayerDataService.saveNow(player: Player)
	local profile = profiles[player]
	if profile ~= nil then
		profile:Save()
	end
end

return PlayerDataService
