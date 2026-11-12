--!strict
-- Solo en Studio: reenvía a los clientes los errores del servidor para que el panel de
-- diagnóstico los muestre en pantalla (más fácil que buscarlos en la ventana Salida).
-- En el juego publicado no hace nada.

local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

local NetService = require(script.Parent.NetService)

local MAX_LENGTH = 300
-- Mensajes esperados en Studio que no son fallos del juego:
--   · ProfileStore prueba a escribir en un DataStore para saber si hay acceso a la API.
--     Sin "Enable Studio Access to API Services" Roblox registra ese intento como error,
--     pero el juego usa datos simulados en Studio (DataConfig.USE_LIVE_DATA_IN_STUDIO).
local IGNORED = { "StudioAccessToApisNotAllowed" }

local DevLogService = {}

local function isProblem(message: string, messageType: Enum.MessageType): boolean
	for _, pattern in IGNORED do
		if string.find(message, pattern, 1, true) ~= nil then
			return false
		end
	end
	if messageType == Enum.MessageType.MessageError then
		return true
	end
	return messageType == Enum.MessageType.MessageWarning
		and string.find(message, "ERROR", 1, true) ~= nil
end

function DevLogService.Start(_self: typeof(DevLogService))
	if not RunService:IsStudio() then
		return
	end
	-- Errores que ocurrieron antes de que este servicio arrancara.
	local history = {}
	for _, entry in LogService:GetLogHistory() do
		if isProblem(entry.message, entry.messageType) then
			table.insert(history, string.sub(entry.message, 1, MAX_LENGTH))
		end
	end
	LogService.MessageOut:Connect(function(message: string, messageType: Enum.MessageType)
		if isProblem(message, messageType) then
			local text = string.sub(message, 1, MAX_LENGTH)
			table.insert(history, text)
			NetService.fireAll("DevLog", `[server] {text}`)
		end
	end)
	-- Quien entra recibe los errores anteriores.
	game:GetService("Players").PlayerAdded:Connect(function(player: Player)
		task.delay(4, function()
			for _, text in history do
				NetService.fire("DevLog", player, `[server] {text}`)
			end
		end)
	end)
	for _, player in game:GetService("Players"):GetPlayers() do
		for _, text in history do
			NetService.fire("DevLog", player, `[server] {text}`)
		end
	end
end

return DevLogService
