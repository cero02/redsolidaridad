--!strict
-- La Hidra de Lerna: tres fases (hito 1.3). Diseño: docs/design/HIDRA.md.
-- Valores iniciales para equilibrar. Tiempos en segundos, distancias en studs.

return table.freeze({
	-- Huecos de cuello alrededor del cuerpo (límite de cabezas a la vez).
	MAX_SLOTS = 5,
	HEAD_HEALTH = 90,
	-- Tiempo que tarda un cuello cortado en regenerar dos cabezas.
	REGROW_TIME = 12,
	-- Fases con cabezas mortales: cabezas al empezar y cuellos que hay que cauterizar.
	-- Después llega la fase de la cabeza inmortal.
	PHASES = table.freeze({
		table.freeze({ HEADS = 3, REQUIRED = 3 }),
		table.freeze({ HEADS = 5, REQUIRED = 3 }),
	}),
	-- Pausa entre fases (la Hidra se sumerge).
	PHASE_TRANSITION_TIME = 4,
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

	-- Fase 2: tres mordiscos seguidos de cabezas distintas.
	CHAIN_GAP = 0.4,

	-- Fase 2: niebla venenosa en media arena.
	CLOUD = table.freeze({
		TELEGRAPH = 1.5,
		DURATION = 6,
		TICK = 1,
		DAMAGE_PER_TICK = 5,
		COOLDOWN = 18,
	}),

	-- Fase 2: la Hidra emerge bajo un jugador.
	DIVE = table.freeze({
		TELEGRAPH = 1.3,
		DAMAGE = 35,
		RADIUS = 7,
	}),

	-- Fases 2 y 3: bolas de fuego que persiguen al gladiador. Giran despacio: se esquivan
	-- cambiando de rumbo o con la esquiva. Una parada perfecta las devuelve a la Hidra.
	FIREBALL = table.freeze({
		TELEGRAPH = 1.0,
		COUNT = 3,
		GAP = 0.45,
		SPEED = 26,
		-- Giro máximo en grados por segundo.
		TURN_RATE = 80,
		LIFETIME = 6,
		RADIUS = 2.6,
		HEIGHT = 3.5,
		DAMAGE = 18,
		COOLDOWN = 12,
		-- Bola devuelta con una parada perfecta.
		REFLECT_SPEED = 70,
		REFLECT_DAMAGE = 45,
		-- Tras tantas andanadas, el anunciador insinúa el secreto.
		HINT_AFTER = 3,
	}),

	-- Fase 2: cada tanto la Hidra apaga un brasero (siempre queda al menos uno).
	EXTINGUISH_INTERVAL = 20,

	-- Fase 3: la cabeza dorada. No se puede cortar: hay que aturdirla (parada perfecta o
	-- golpe pesado cuando está en el suelo) y romper las cadenas de la roca.
	IMMORTAL = table.freeze({
		TELEGRAPH = 1.0,
		DAMAGE = 40,
		RANGE = 42,
		WIDTH = 8,
		LUNGE_TIME = 0.15,
		RECOVERY = 1.8,
		PARRY_STUN = 6,
		RETURN_TIME = 0.5,
		STUN = 6,
		CHAIN_COUNT = 3,
		CHAIN_HEALTH = 30,
		CHAIN_RADIUS = 32,
		ROCK_HEIGHT = 46,
	}),

	POND_TICK = 1,
	POND_DAMAGE_PER_TICK = 10,
})
