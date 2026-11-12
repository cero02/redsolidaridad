--!strict
-- Ajustes del jugador: idioma, volumen de la música, temblor de cámara y modo ligero
-- (menos público y sin sombras, para equipos modestos). Se guardan en el perfil del
-- servidor (SaveSettings) y se recuperan al entrar.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local I18n = require(script.Parent.I18n)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local SAVE_DELAY = 1
local LANGUAGE_OPTIONS = { "auto", "en", "es" }
local MUSIC_OPTIONS = { 0, 0.35, 0.7, 1 }

local Settings = {}

Settings.Changed = Signal.new() :: Signal.Signal<string, any>
Settings.LANGUAGE_OPTIONS = LANGUAGE_OPTIONS
Settings.MUSIC_OPTIONS = MUSIC_OPTIONS

local values: { [string]: any } = {
	language = "auto",
	music = 0.7,
	cameraShake = true,
	lightMode = false,
}
local loaded = false
local saveToken = 0

local function applyLightMode(enabled: boolean)
	-- Las sombras globales y el público son lo que más carga en equipos modestos.
	Lighting.GlobalShadows = not enabled
	local arena = Workspace:FindFirstChild("GranColiseo")
	if arena then
		for _, part in arena:GetChildren() do
			if part.Name == "Spectator" and part:IsA("BasePart") then
				part.LocalTransparencyModifier = if enabled then 1 else 0
			end
		end
	end
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") then
			effect.Enabled = not enabled
		end
	end
end

local function apply(name: string, value: any)
	if name == "lightMode" then
		applyLightMode(value == true)
	elseif name == "language" then
		I18n.setPreference(value)
	end
end

-- Guarda en el servidor un momento después del último cambio (agrupa clics seguidos).
local function scheduleSave()
	saveToken += 1
	local token = saveToken
	task.delay(SAVE_DELAY, function()
		if token == saveToken then
			NetClient.fire(
				"SaveSettings",
				values.language,
				values.music,
				values.cameraShake,
				values.lightMode
			)
		end
	end)
end

function Settings.get(name: string): any
	return values[name]
end

function Settings.set(name: string, value: any)
	values[name] = value
	apply(name, value)
	Settings.Changed:Fire(name, value)
	scheduleSave()
end

function Settings.toggle(name: string): boolean
	Settings.set(name, not values[name])
	return values[name]
end

-- Pasa a la siguiente opción de una lista (idioma, volumen).
function Settings.cycle(name: string, options: { any }): any
	local index = table.find(options, values[name]) or 0
	Settings.set(name, options[(index % #options) + 1])
	return values[name]
end

-- Ajustes guardados en el perfil (llegan con el primer ProgressUpdate).
function Settings.load(saved: { [string]: any }?)
	if loaded or saved == nil then
		return
	end
	loaded = true
	for name, value in saved do
		if values[name] ~= nil and typeof(value) == typeof(values[name]) then
			values[name] = value
			apply(name, value)
			Settings.Changed:Fire(name, value)
		end
	end
end

-- Vuelve a aplicar el modo ligero (p. ej. cuando aparece el coliseo).
function Settings.reapply()
	if values.lightMode then
		applyLightMode(true)
	end
end

return Settings
