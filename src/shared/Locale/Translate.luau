--!strict
-- Traducción pura (sin APIs de Roblox, probada con Lune).
-- Las cadenas usan marcadores {nombre}. Un parámetro puede ser texto, número o una tabla
-- { key = "clave", params = {...} } que se traduce a su vez (p. ej. el nombre de un título).

export type Params = { [string]: any }
export type Tables = { [string]: { [string]: string } }

local Translate = {}

Translate.DEFAULT = "en"

local function resolveParam(tables: Tables, language: string, value: any): string
	if type(value) == "table" and type(value.key) == "string" then
		return Translate.format(tables, language, value.key, value.params)
	end
	return tostring(value)
end

-- Traduce `key` al idioma pedido. Si falta, usa el idioma por defecto; si tampoco existe,
-- devuelve la propia clave (para que se note en las pruebas).
function Translate.format(tables: Tables, language: string, key: string, params: Params?): string
	local text = (tables[language] and tables[language][key]) or (tables[Translate.DEFAULT] and tables[Translate.DEFAULT][key])
	if text == nil then
		return key
	end
	if params == nil then
		return text
	end
	return (string.gsub(text, "{(%w+)}", function(name: string): string?
		local value = params[name]
		if value == nil then
			return nil
		end
		return resolveParam(tables, language, value)
	end))
end

-- Idioma a usar: la preferencia explícita del jugador o, si es "auto", su idioma de Roblox.
function Translate.resolve(available: { string }, preference: string?, localeId: string?): string
	if preference and preference ~= "auto" and table.find(available, preference) then
		return preference
	end
	local prefix = string.lower(string.sub(localeId or "", 1, 2))
	if table.find(available, prefix) then
		return prefix
	end
	return Translate.DEFAULT
end

-- Claves que usan marcadores {x}: sirve para comprobar que las traducciones los respetan.
function Translate.placeholders(text: string): { [string]: boolean }
	local found = {}
	for name in string.gmatch(text, "{(%w+)}") do
		found[name] = true
	end
	return found
end

return Translate
