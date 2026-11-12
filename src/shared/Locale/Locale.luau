--!strict
-- Idiomas del juego. Inglés como idioma base (juego internacional) y español completo.
-- Para añadir un idioma: crea Strings/Xx.luau con todas las claves de En.luau y añádelo
-- aquí. Los textos que falten en un idioma se muestran en inglés.

local Translate = require(script.Parent.Translate)

local Locale = {}

Locale.LANGUAGES = table.freeze({ "en", "es" })

local tables: Translate.Tables = {
	en = require(script.Parent.Strings.En) :: any,
	es = require(script.Parent.Strings.Es) :: any,
}

function Locale.t(language: string, key: string, params: Translate.Params?): string
	return Translate.format(tables, language, key, params)
end

-- Idioma de un jugador: su preferencia ("auto", "en", "es") o el de su cuenta de Roblox.
function Locale.resolve(preference: string?, localeId: string?): string
	return Translate.resolve(Locale.LANGUAGES :: any, preference, localeId)
end

-- Referencia a un texto traducible para enviarla por red: el cliente la traduce.
function Locale.ref(
	key: string,
	params: Translate.Params?
): { key: string, params: Translate.Params? }
	return { key = key, params = params }
end

return Locale
