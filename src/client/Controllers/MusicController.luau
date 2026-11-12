--!strict
-- Música: tema principal a todo volumen en la pantalla de inicio, de fondo en el Foro y
-- con fuerza en la arena; sube en la victoria. Fundidos suaves entre momentos y volumen
-- ajustable en Ajustes. Si no hay música configurada (Config/Audio), no hace nada.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local NetClient = require(ReplicatedStorage.Shared.Net.Client)
local Settings = require(script.Parent.Parent.UI.Settings)

export type Context = "Menu" | "Forum" | "Arena" | "Victory"

local localPlayer = Players.LocalPlayer

local MusicController = {}

local mainSound: Sound? = nil
local arenaSound: Sound? = nil
local context: Context = "Menu"
local menuOpen = true

local function makeSound(name: string, id: number): Sound?
	if id <= 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = `rbxassetid://{id}`
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	return sound
end

local function fadeTo(sound: Sound?, volume: number)
	if sound == nil then
		return
	end
	if volume > 0 and not sound.IsPlaying then
		sound:Play()
	end
	local tween = TweenService:Create(sound, TweenInfo.new(Audio.FADE_TIME), { Volume = volume })
	tween:Play()
	if volume <= 0 then
		tween.Completed:Once(function()
			if sound.Volume <= 0.001 then
				sound:Pause()
			end
		end)
	end
end

local function refresh()
	local level = (Audio.VOLUME :: any)[context] * (Settings.get("music") or 0)
	-- La arena usa su propia pista si existe; si no, el tema principal.
	local useArena = arenaSound ~= nil and (context == "Arena" or context == "Victory")
	fadeTo(mainSound, if useArena then 0 else level)
	fadeTo(arenaSound, if useArena then level else 0)
end

local function computeContext(): Context
	if menuOpen then
		return "Menu"
	end
	if localPlayer:GetAttribute("InArena") == true then
		return if context == "Victory" then "Victory" else "Arena"
	end
	return "Forum"
end

local function update()
	local nextContext = computeContext()
	if nextContext ~= context then
		context = nextContext
	end
	refresh()
end

-- Lo llama la pantalla de inicio al abrirse y cerrarse.
function MusicController.setMenuOpen(open: boolean)
	menuOpen = open
	update()
end

function MusicController.Init(_self: typeof(MusicController))
	mainSound = makeSound("MainTheme", Audio.MAIN_THEME)
	arenaSound = makeSound("ArenaTheme", Audio.ARENA_THEME)
end

function MusicController.Start(_self: typeof(MusicController))
	localPlayer:GetAttributeChangedSignal("InArena"):Connect(function()
		if localPlayer:GetAttribute("InArena") ~= true and context == "Victory" then
			context = "Forum"
		end
		update()
	end)
	NetClient.on("MatchResults", function(results: any)
		if results.won then
			context = "Victory"
			refresh()
		end
	end)
	Settings.Changed:Connect(function(name: string)
		if name == "music" then
			refresh()
		end
	end)
	update()
end

return MusicController
