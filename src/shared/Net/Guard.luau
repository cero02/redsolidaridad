--!strict
-- Decide si una petición del cliente se acepta: primero el límite de peticiones y
-- después los argumentos. Módulo puro (recibe sus dependencias) para probarlo con Lune.

type Validator = (value: unknown) -> (boolean, string?)
type Limiter = { consume: (self: any, key: any) -> boolean }
type ArgsChecker = (
	validators: { Validator },
	count: number,
	args: { unknown }
) -> (boolean, string?)

local Guard = {}

function Guard.check(
	validators: { Validator },
	limiter: Limiter,
	checkArgs: ArgsChecker,
	key: any,
	count: number,
	args: { unknown }
): (boolean, string?)
	if not limiter:consume(key) then
		return false, "límite de peticiones superado"
	end
	return checkArgs(validators, count, args)
end

return Guard
