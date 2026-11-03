--!strict
-- Registro con prefijo común: [COLOSSEUM][Ámbito] mensaje.

export type Logger = {
	info: (self: Logger, message: string) -> (),
	warn: (self: Logger, message: string) -> (),
	error: (self: Logger, message: string) -> (),
}

local Log = {}

function Log.new(scope: string): Logger
	local prefix = `[COLOSSEUM][{scope}]`
	local logger = {} :: Logger

	function logger.info(_self: Logger, message: string)
		print(`{prefix} {message}`)
	end

	function logger.warn(_self: Logger, message: string)
		warn(`{prefix} {message}`)
	end

	-- No lanza: registra como error sin detener el hilo.
	function logger.error(_self: Logger, message: string)
		warn(`{prefix} ERROR: {message}`)
	end

	return logger
end

return Log
