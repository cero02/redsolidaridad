--!strict
-- Valores de combate comunes a todas las armas. Diseño: docs/design/COMBATE.md.
-- Son valores iniciales: se ajustan tras cada prueba con jugadores.
-- Solo números y textos (sin tipos de Roblox) para poder probarlo con Lune.

return table.freeze({
	MAX_HEALTH = 100,

	MAX_STAMINA = 100,
	STAMINA_REGEN_PER_SECOND = 30,
	-- Segundos sin gastar aguante antes de empezar a recuperarlo.
	STAMINA_REGEN_DELAY = 0.8,

	-- Combo: si pasan más de estos segundos tras un ataque, el combo vuelve al golpe 1.
	COMBO_RESET = 0.9,
	-- Un ataque pesado se lanza al mantener el botón al menos este tiempo.
	HEAVY_HOLD_TIME = 0.35,

	DODGE_INVULNERABLE_TIME = 0.35,
	-- Duración del impulso de movimiento de la esquiva.
	DODGE_DURATION = 0.2,
	DODGE_COOLDOWN = 0.45,
	-- Velocidad horizontal del impulso de esquiva (studs/s).
	DODGE_SPEED = 55,

	BLOCK_STAMINA_PER_HIT = 20,
	WALK_SPEED = 16,
	-- Velocidad al caminar bloqueando (la normal de Roblox es 16).
	BLOCK_WALK_SPEED = 8,

	-- Margen por latencia al validar el ritmo de las acciones del jugador.
	ACTION_LATENCY_GRACE = 0.08,
	-- Margen por latencia al resolver golpes enemigos: si el jugador esquivó o bloqueó
	-- hasta este tiempo después del impacto (en el reloj del servidor), cuenta.
	DEFENSE_LATENCY_GRACE = 0.15,

	ULTIMATE_MAX = 100,
	ULTIMATE_PER_DAMAGE = 0.1,
	ULTIMATE_PER_PARRY = 15,
	ULTIMATE_PER_CLOSE_DODGE = 5,
	-- Una esquiva es "ajustada" si empezó como mucho tanto antes del impacto.
	CLOSE_DODGE_WINDOW = 0.2,
	-- Aturdimiento que sufre el atacante cuando le hacen una parada perfecta.
	PARRY_STUN = 1.0,
})
