--!strict
-- Música del juego. Roblox solo reproduce audio subido a Roblox: sube el archivo desde
-- Studio (guía: docs/AUDIO.md) y pega aquí su número de recurso.
-- 0 = sin música (el juego funciona igual).

return table.freeze({
	-- "Steel Against Stone" (assets/audio/Steel_Against_Stone.mp3).
	MAIN_THEME = 0,
	-- Música de la arena. 0 = usar el tema principal.
	ARENA_THEME = 0,

	-- Volumen de cada momento (se multiplica por el ajuste del jugador).
	VOLUME = table.freeze({
		Menu = 0.6,
		Forum = 0.22,
		Arena = 0.45,
		Victory = 0.7,
	}),
	FADE_TIME = 1.6,

	-- Efectos de sonido. Sonidos que trae Roblox de serie (rbxasset://) o recursos subidos
	-- ("rbxassetid://123…"). Cadena vacía = sin sonido.
	-- POR VERIFICAR: rutas de los sonidos de serie (las de la espada clásica de Roblox).
	SFX = table.freeze({
		swing = "rbxasset://sounds/swordslash.wav",
		heavy = "rbxasset://sounds/swordlunge.wav",
		hit = "rbxasset://sounds/swordslash.wav",
		parry = "rbxasset://sounds/unsheath.wav",
		equip = "rbxasset://sounds/unsheath.wav",
	}),
	SFX_VOLUME = 0.6,
})
