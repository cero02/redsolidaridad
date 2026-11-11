--!strict
-- Ajustes del jugador en este dispositivo: temblor de cámara y modo ligero (menos
-- público y sin sombras, para equipos modestos). Se guardan como atributos del jugador
-- local durante la sesión.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Settings = {}

Settings.Changed = Signal.new() :: Signal.Signal<string, boolean>

local values: { [string]: boolean } = {
	cameraShake = true,
	lightMode = false,
}

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

function Settings.get(name: string): boolean
	return values[name] == true
end

function Settings.set(name: string, value: boolean)
	values[name] = value
	Players.LocalPlayer:SetAttribute(`Setting_{name}`, value)
	if name == "lightMode" then
		applyLightMode(value)
	end
	Settings.Changed:Fire(name, value)
end

function Settings.toggle(name: string): boolean
	Settings.set(name, not Settings.get(name))
	return Settings.get(name)
end

-- Vuelve a aplicar el modo ligero (p. ej. cuando aparece el coliseo).
function Settings.reapply()
	if values.lightMode then
		applyLightMode(true)
	end
end

return Settings
