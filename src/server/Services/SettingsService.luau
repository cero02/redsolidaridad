--!strict
-- Guarda en el perfil los ajustes del jugador (idioma, música, temblor de cámara y modo
-- ligero) y publica su idioma como atributo para que el servidor le hable en él.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local NetService = require(script.Parent.NetService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ServerText = require(ServerScriptService.Server.Localization.ServerText)

local SettingsService = {}

local function applyLanguage(player: Player, language: string)
	player:SetAttribute(ServerText.LANGUAGE_ATTRIBUTE, language)
end

function SettingsService.Start(_self: typeof(SettingsService))
	NetService.on(
		"SaveSettings",
		function(
			player: Player,
			language: string,
			music: number,
			cameraShake: boolean,
			lightMode: boolean
		)
			local data = PlayerDataService.get(player)
			if data == nil then
				return
			end
			data.settings.language = language
			data.settings.music = music
			data.settings.cameraShake = cameraShake
			data.settings.lightMode = lightMode
			applyLanguage(player, language)
		end
	)

	PlayerDataService.Loaded:Connect(function(player: Player, data)
		applyLanguage(player, data.settings.language)
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		-- Hasta que cargue el perfil, el idioma de su cuenta de Roblox.
		if player:GetAttribute(ServerText.LANGUAGE_ATTRIBUTE) == nil then
			applyLanguage(player, "auto")
		end
	end)
end

return SettingsService
