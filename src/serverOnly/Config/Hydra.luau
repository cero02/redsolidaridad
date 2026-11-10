--!strict
-- La Hidra de Lerna, fase 1 (hito 1.2). Diseño: docs/design/HIDRA.md.
-- Valores iniciales para equilibrar. Tiempos en segundos, distancias en studs.

return table.freeze({
	INITIAL_HEADS = 3,
	-- Huecos de cuello alrededor del cuerpo (límite de cabezas a la vez).
	MAX_SLOTS = 5,
	HEAD_HEALTH = 90,
	-- Tiempo que tarda un cuello cortado en regenerar dos cabezas.
	REGROW_TIME = 12,
	-- Cuellos cauterizados necesarios para superar la fase.
	CAUTERIZE_REQUIRED = 3,
	-- Duración del arma encendida tras usar un brasero.
	WEAPON_LIT_TIME = 10,
	-- Tras tantas regeneraciones, el anunciador da la pista del fuego.
	HINT_AFTER_REGROWS = 2,

	FIRST_ATTACK_DELAY = 2.5,
	ATTACK_INTERVAL = 2.2,

	BITE = table.freeze({
		TELEGRAPH = 1.2,
		DAMAGE = 25,
		-- Distancia máxima desde el centro a la que llega un mordisco.
		RANGE = 42,
		WIDTH = 7,
		LUNGE_TIME = 0.15,
		-- Tiempo que la cabeza queda en el suelo tras morder (ventana para golpearla).
		RECOVERY = 2.2,
		-- Tiempo en el suelo si el jugador hizo una parada perfecta.
		PARRY_STUN = 3.5,
		RETURN_TIME = 0.5,
	}),

	SPIT = table.freeze({
		TELEGRAPH = 1.0,
		RADIUS = 8,
		DURATION = 6,
		TICK = 1,
		DAMAGE_PER_TICK = 8,
	}),

	TAIL = table.freeze({
		TELEGRAPH = 1.4,
		DAMAGE = 20,
		RADIUS = 15,
		-- Un jugador está "cerca" si está a menos de esta distancia del centro.
		NEAR_RANGE = 30,
	}),

	POND_TICK = 1,
	POND_DAMAGE_PER_TICK = 10,
})
