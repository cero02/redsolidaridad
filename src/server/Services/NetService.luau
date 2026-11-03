--!strict
-- Crea los Remotes declarados en Shared/Net/Remotes y protege cada uno con
-- límite de peticiones y validación de argumentos. Ver docs/SECURITY.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Check = require(ReplicatedStorage.Shared.Net.Check)
local Guard = require(ReplicatedStorage.Shared.Net.Guard)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local FOLDER_NAME = "Remotes"
-- Como máximo un aviso de rechazo por jugador y Remote cada tantos segundos.
local REJECTION_LOG_COOLDOWN = 10

local log = Log.new("NetService")

local NetService = {}

local instances: { [string]: Instance } = {}
local limiters: { [string]: RateLimiter.RateLimiter } = {}
local lastRejectionLog: { [Player]: { [string]: number } } = {}

local function getDefinition(name: string): Remotes.Definition
	local definition = Remotes[name]
	assert(definition ~= nil, `Remote desconocido: {name}`)
	return definition
end

local function logRejection(player: Player, name: string, reason: string)
	local perPlayer = lastRejectionLog[player]
	if perPlayer == nil then
		perPlayer = {}
		lastRejectionLog[player] = perPlayer
	end
	local now = os.clock()
	local last = perPlayer[name]
	if last == nil or now - last >= REJECTION_LOG_COOLDOWN then
		perPlayer[name] = now
		log:warn(`Petición rechazada de {player.UserId} en {name}: {reason}`)
	end
end

function NetService.Init(_self: typeof(NetService))
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	for name, definition in Remotes do
		local remote = Instance.new(
			if definition.kind == "UnreliableEvent" then "UnreliableRemoteEvent" else "RemoteEvent"
		)
		remote.Name = name
		remote.Parent = folder
		instances[name] = remote

		if definition.direction == "ToServer" then
			local rate = definition.rate
			assert(rate ~= nil, `{name}: los Remotes ToServer necesitan límite de peticiones`)
			assert(definition.args ~= nil, `{name}: los Remotes ToServer necesitan validadores`)
			limiters[name] = RateLimiter.new(rate.capacity, rate.perSecond)
		end
	end

	folder.Parent = ReplicatedStorage
end

function NetService.Start(_self: typeof(NetService))
	Players.PlayerRemoving:Connect(function(player: Player)
		for _, limiter in limiters do
			limiter:remove(player)
		end
		lastRejectionLog[player] = nil
	end)
end

-- Escucha un Remote ToServer. El handler solo recibe peticiones ya validadas.
function NetService.on(name: string, handler: (player: Player, ...any) -> ()): RBXScriptConnection
	local definition = getDefinition(name)
	assert(definition.direction == "ToServer", `{name} no es ToServer`)
	local validators = definition.args :: { Check.Validator }
	local limiter = limiters[name]
	local remote: any = instances[name]
	assert(remote ~= nil, "NetService.on llamado antes de Init")

	return remote.OnServerEvent:Connect(function(player: Player, ...: unknown)
		local count = select("#", ...)
		local ok, reason = Guard.check(validators, limiter, Check.args, player, count, { ... })
		if not ok then
			logRejection(player, name, reason or "?")
			return
		end
		handler(player, ...)
	end)
end

function NetService.fire(name: string, player: Player, ...: any)
	local definition = getDefinition(name)
	assert(definition.direction == "ToClient", `{name} no es ToClient`)
	local remote: any = instances[name]
	remote:FireClient(player, ...)
end

function NetService.fireAll(name: string, ...: any)
	local definition = getDefinition(name)
	assert(definition.direction == "ToClient", `{name} no es ToClient`)
	local remote: any = instances[name]
	remote:FireAllClients(...)
end

return NetService
