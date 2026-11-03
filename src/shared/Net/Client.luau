--!strict
-- Acceso a los Remotes desde el cliente. Solo busca las instancias que crea NetService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Parent.Remotes)

local FOLDER_NAME = "Remotes"

local NetClient = {}

local function getRemote(name: string): Instance
	local definition = Remotes[name]
	assert(definition ~= nil, `Remote desconocido: {name}`)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name)
end

function NetClient.fire(name: string, ...: any)
	local definition = Remotes[name]
	assert(definition and definition.direction == "ToServer", `{name} no es ToServer`)
	local remote: any = getRemote(name) -- RemoteEvent o UnreliableRemoteEvent
	remote:FireServer(...)
end

function NetClient.on(name: string, handler: (...any) -> ()): RBXScriptConnection
	local definition = Remotes[name]
	assert(definition and definition.direction == "ToClient", `{name} no es ToClient`)
	local remote: any = getRemote(name) -- RemoteEvent o UnreliableRemoteEvent
	return remote.OnClientEvent:Connect(handler)
end

return NetClient
