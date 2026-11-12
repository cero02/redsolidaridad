--!strict
-- Idioma activo en este cliente. Por defecto, el de la cuenta de Roblox del jugador; se
-- puede cambiar en Ajustes. Al cambiar, `Changed` avisa a la interfaz para redibujarse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage.Shared.Locale.Locale)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local I18n = {}

I18n.Changed = Signal.new() :: Signal.Signal<string>

local language = Locale.resolve("auto", Players.LocalPlayer.LocaleId)

function I18n.language(): string
	return language
end

-- `preference`: "auto", "en" o "es".
function I18n.setPreference(preference: string)
	local resolved = Locale.resolve(preference, Players.LocalPlayer.LocaleId)
	if resolved ~= language then
		language = resolved
		I18n.Changed:Fire(language)
	end
end

function I18n.t(key: string, params: { [string]: any }?): string
	return Locale.t(language, key, params)
end

-- Traduce una referencia { key, params } que llega del servidor.
function I18n.ref(ref: any): string
	if type(ref) == "table" and type(ref.key) == "string" then
		return Locale.t(language, ref.key, ref.params)
	end
	return if ref ~= nil then tostring(ref) else ""
end

return I18n
