--!strict
-- Validadores de argumentos para los Remotes. Nunca confiar en lo que envía el cliente.
-- Módulo puro para poder probarlo con Lune.

export type Validator = (value: unknown) -> (boolean, string?)

local Check = {}

export type NumberOptions = { min: number?, max: number?, integer: boolean? }

function Check.number(options: NumberOptions?): Validator
	local min = options and options.min
	local max = options and options.max
	local integer = options and options.integer
	return function(value: unknown)
		if typeof(value) ~= "number" then
			return false, "se esperaba un número"
		end
		local n = value :: number
		if n ~= n then
			return false, "NaN no permitido"
		end
		if n == math.huge or n == -math.huge then
			return false, "infinito no permitido"
		end
		if integer and n % 1 ~= 0 then
			return false, "se esperaba un entero"
		end
		if min ~= nil and n < min then
			return false, `menor que {min}`
		end
		if max ~= nil and n > max then
			return false, `mayor que {max}`
		end
		return true
	end
end

function Check.string(maxLength: number): Validator
	return function(value: unknown)
		if typeof(value) ~= "string" then
			return false, "se esperaba un texto"
		end
		if #(value :: string) > maxLength then
			return false, `texto de más de {maxLength} bytes`
		end
		return true
	end
end

function Check.boolean(): Validator
	return function(value: unknown)
		if typeof(value) ~= "boolean" then
			return false, "se esperaba un booleano"
		end
		return true
	end
end

-- El valor debe ser exactamente uno de los textos indicados.
function Check.oneOf(options: { string }): Validator
	local allowed: { [string]: boolean } = {}
	for _, option in options do
		allowed[option] = true
	end
	return function(value: unknown)
		if typeof(value) ~= "string" or not allowed[value :: string] then
			return false, "valor no permitido"
		end
		return true
	end
end

function Check.optional(validator: Validator): Validator
	return function(value: unknown)
		if value == nil then
			return true
		end
		return validator(value)
	end
end

-- Valida una lista de argumentos recibidos: número exacto y cada valor.
function Check.args(validators: { Validator }, count: number, args: { unknown }): (boolean, string?)
	if count > #validators then
		return false, `demasiados argumentos ({count})`
	end
	for index, validator in validators do
		local ok, reason = validator(args[index])
		if not ok then
			return false, `argumento {index}: {reason}`
		end
	end
	return true
end

return Check
