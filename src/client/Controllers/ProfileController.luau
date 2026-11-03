--!strict
-- Recibe el resumen público del perfil del jugador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local log = Log.new("ProfileController")

local ProfileController = {}

ProfileController.Changed = Signal.new() :: Signal.Signal<any>
ProfileController.profile = nil :: any

function ProfileController.Start(_self: typeof(ProfileController))
	NetClient.on("ProfileReady", function(profile: any)
		ProfileController.profile = profile
		log:info(`Perfil recibido: nivel {profile.level}, arma {profile.loadout.weapon}`)
		ProfileController.Changed:Fire(profile)
	end)
	-- Avisar después de conectar para no perder la respuesta.
	NetClient.fire("ClientReady")
end

return ProfileController
