--!strict
-- Textos desde el servidor:
--   · t(player, ...) traduce al idioma del jugador (expulsiones, mensajes directos).
--   · setWorld(...) marca un texto del mundo (carteles, avisos de interacción, letreros)
--     con su clave para que cada cliente lo muestre en su idioma (LocalizeController).
--     El texto por defecto queda en inglés por si el cliente aún no lo ha traducido.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage.Shared.Locale.Locale)

local TAG = "Localized"

local ServerText = {}

-- Atributo del jugador con su preferencia de idioma ("auto", "en", "es").
ServerText.LANGUAGE_ATTRIBUTE = "Language"

function ServerText.languageOf(player: Player): string
	local preference = player:GetAttribute(ServerText.LANGUAGE_ATTRIBUTE)
	return Locale.resolve(if typeof(preference) == "string" then preference else nil, player.LocaleId)
end

function ServerText.t(player: Player, key: string, params: { [string]: any }?): string
	return Locale.t(ServerText.languageOf(player), key, params)
end

-- Fija un texto traducible en una propiedad (`Text`, `ActionText`, `ObjectText`…).
function ServerText.setWorld(instance: Instance, property: string, key: string, params: { [string]: any }?)
	instance:SetAttribute(`L_{property}`, key)
	instance:SetAttribute(`L_{property}_Params`, if params then HttpService:JSONEncode(params) else nil)
	if not CollectionService:HasTag(instance, TAG) then
		CollectionService:AddTag(instance, TAG)
	end
	;(instance :: any)[property] = Locale.t("en", key, params)
end

return ServerText
