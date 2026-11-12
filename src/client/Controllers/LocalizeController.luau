--!strict
-- Traduce los textos del mundo (carteles, letreros, avisos de interacción). El servidor
-- los marca con la etiqueta "Localized" y atributos L_<Propiedad> (clave) y
-- L_<Propiedad>_Params (parámetros en JSON); aquí se muestran en el idioma del jugador.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local I18n = require(script.Parent.Parent.UI.I18n)

local TAG = "Localized"

local LocalizeController = {}

-- Propiedades ya vigiladas por instancia (para no conectar dos veces).
local watched: { [Instance]: { [string]: boolean } } = {}

local function translated(instance: Instance, property: string): string?
	local key = instance:GetAttribute(`L_{property}`)
	if typeof(key) ~= "string" then
		return nil
	end
	local params = nil
	local raw = instance:GetAttribute(`L_{property}_Params`)
	if typeof(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		params = if ok then decoded else nil
	end
	return I18n.t(key, params)
end

local function applyProperty(instance: Instance, property: string)
	local text = translated(instance, property)
	if text ~= nil and (instance :: any)[property] ~= text then
		(instance :: any)[property] = text
	end
end

local function watch(instance: Instance, property: string)
	local properties = watched[instance]
	if properties == nil then
		properties = {}
		watched[instance] = properties
	end
	if properties[property] then
		return
	end
	properties[property] = true
	-- Si llega del servidor el texto en inglés después de la traducción, se vuelve a traducir.
	instance:GetPropertyChangedSignal(property):Connect(function()
		applyProperty(instance, property)
	end)
end

local function applyAll(instance: Instance)
	for name in instance:GetAttributes() do
		if string.sub(name, 1, 2) == "L_" and string.sub(name, -7) ~= "_Params" then
			local property = string.sub(name, 3)
			watch(instance, property)
			applyProperty(instance, property)
		end
	end
end

local function track(instance: Instance)
	-- Tras el lote de replicación, para que atributos y propiedad ya hayan llegado.
	task.defer(applyAll, instance)
	instance.AttributeChanged:Connect(function(name: string)
		if string.sub(name, 1, 2) == "L_" then
			task.defer(applyAll, instance)
		end
	end)
	instance.Destroying:Connect(function()
		watched[instance] = nil
	end)
end

function LocalizeController.Start(_self: typeof(LocalizeController))
	for _, instance in CollectionService:GetTagged(TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)

	I18n.Changed:Connect(function()
		for _, instance in CollectionService:GetTagged(TAG) do
			applyAll(instance)
		end
	end)
end

return LocalizeController
