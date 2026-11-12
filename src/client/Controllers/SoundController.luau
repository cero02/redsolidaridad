--!strict
-- Efectos de sonido locales (tajos, golpes, paradas). Los sonidos se configuran en
-- Config/Audio.SFX; si alguno no existe, simplemente no suena.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)

local SoundController = {}

local sounds: { [string]: Sound } = {}

-- Reproduce un efecto. `pitch` varía el tono para que no suene siempre igual.
function SoundController.play(name: string, pitch: number?)
	local sound = sounds[name]
	if sound == nil then
		return
	end
	sound.PlaybackSpeed = pitch or (0.92 + math.random() * 0.16)
	SoundService:PlayLocalSound(sound)
end

function SoundController.Init(_self: typeof(SoundController))
	for name, id in Audio.SFX do
		if id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = `SFX_{name}`
			sound.SoundId = id
			sound.Volume = Audio.SFX_VOLUME
			sound.Parent = SoundService
			sounds[name] = sound
		end
	end
end

return SoundController
