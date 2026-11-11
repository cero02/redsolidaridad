--!strict
-- Definición de armas. Diseño: docs/design/ARMAS_Y_ESENCIAS.md.
-- Tiempos en segundos, distancias en studs. Valores iniciales para equilibrar.
-- Ninguna es la mejor en todo: el Gladius defiende, la Hasta alcanza y el Martillo rompe.

export type Attack = {
	damage: number,
	-- Preparación antes de que el golpe sea activo.
	windup: number,
	-- Tiempo en que el golpe puede impactar (la comprobación se hace al inicio).
	active: number,
	-- Tiempo hasta poder actuar de nuevo.
	recovery: number,
	-- Zona de impacto: caja delante del personaje.
	reach: number,
	width: number,
	height: number,
	-- Aturdimiento que causa al objetivo (0 = ninguno).
	stun: number,
	-- Impulso hacia delante del atacante al golpear (studs/s; 0 = ninguno). Solo visual
	-- en el cliente: el servidor calcula el golpe con la posición que conoce.
	lunge: number?,
}

export type Ultimate = {
	id: "Testudo" | "Pila" | "Terremoto",
	name: string,
	description: string,
}

export type Weapon = {
	id: string,
	displayName: string,
	description: string,
	light: { Attack },
	heavy: Attack,
	-- Ventana de parada perfecta (segundos desde que empieza el bloqueo).
	parryWindow: number,
	-- Fracción del daño que absorbe el bloqueo.
	blockReduction: number,
	dodgeCost: number,
	ultimate: Ultimate,
	-- Nivel al que se desbloquea (coherente con Config/Progression).
	unlockLevel: number,
}

local function attack(fields: Attack): Attack
	return table.freeze(fields)
end

local Weapons: { [string]: Weapon } = {
	Gladius = table.freeze({
		id = "Gladius",
		displayName = "Gladius y escudo",
		description = "Equilibrado. Paradas perfectas más fáciles y golpe de escudo que aturde.",
		light = table.freeze({
			attack({ damage = 12, windup = 0.12, active = 0.1, recovery = 0.22, reach = 6, width = 6, height = 5, stun = 0 }),
			attack({ damage = 12, windup = 0.12, active = 0.1, recovery = 0.22, reach = 6, width = 6, height = 5, stun = 0 }),
			attack({ damage = 18, windup = 0.18, active = 0.12, recovery = 0.4, reach = 6.5, width = 7, height = 5, stun = 0.3 }),
		}),
		heavy = attack({ damage = 15, windup = 0.25, active = 0.12, recovery = 0.5, reach = 5, width = 5, height = 5, stun = 0.8 }),
		parryWindow = 0.3,
		blockReduction = 0.7,
		dodgeCost = 25,
		ultimate = table.freeze({
			id = "Testudo",
			name = "Testudo",
			description = "Tú y los aliados cercanos sois inmunes al daño durante 4 s.",
		}),
		unlockLevel = 1,
	}),

	Hasta = table.freeze({
		id = "Hasta",
		displayName = "Hasta (lanza)",
		description = "Alcance largo y estocada a la carrera. Bloquea peor.",
		light = table.freeze({
			attack({ damage = 10, windup = 0.14, active = 0.1, recovery = 0.22, reach = 9.5, width = 3.5, height = 5, stun = 0 }),
			attack({ damage = 10, windup = 0.14, active = 0.1, recovery = 0.22, reach = 9.5, width = 3.5, height = 5, stun = 0 }),
			attack({ damage = 14, windup = 0.18, active = 0.12, recovery = 0.35, reach = 10.5, width = 4, height = 5, stun = 0 }),
		}),
		heavy = attack({
			damage = 28,
			windup = 0.3,
			active = 0.15,
			recovery = 0.45,
			reach = 11,
			width = 4,
			height = 5,
			stun = 0.4,
			lunge = 45,
		}),
		parryWindow = 0.25,
		blockReduction = 0.5,
		dodgeCost = 20,
		ultimate = table.freeze({
			id = "Pila",
			name = "Lluvia de pila",
			description = "Seis jabalinas caen sobre la zona de delante: 20 de daño cada una.",
		}),
		unlockLevel = 2,
	}),

	Martillo = table.freeze({
		id = "Martillo",
		displayName = "Martillo del Coloso",
		description = "Lento y devastador. Su golpe pesado crea una onda que aturde.",
		light = table.freeze({
			attack({ damage = 18, windup = 0.3, active = 0.12, recovery = 0.4, reach = 6.5, width = 7, height = 6, stun = 0.2 }),
			attack({ damage = 18, windup = 0.3, active = 0.12, recovery = 0.4, reach = 6.5, width = 7, height = 6, stun = 0.2 }),
			attack({ damage = 30, windup = 0.42, active = 0.15, recovery = 0.6, reach = 7, width = 8, height = 6, stun = 0.6 }),
		}),
		heavy = attack({ damage = 35, windup = 0.55, active = 0.15, recovery = 0.7, reach = 9, width = 12, height = 6, stun = 1.0 }),
		parryWindow = 0.2,
		blockReduction = 0.75,
		dodgeCost = 35,
		ultimate = table.freeze({
			id = "Terremoto",
			name = "Terremoto",
			description = "Tres ondas expansivas a tu alrededor: 30 de daño cada una.",
		}),
		unlockLevel = 4,
	}),
}

return table.freeze(Weapons)
