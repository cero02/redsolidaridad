--!strict
-- Definición de armas. Diseño: docs/design/ARMAS_Y_ESENCIAS.md.
-- Tiempos en segundos, distancias en studs. Valores iniciales para equilibrar.
-- Hito 1.1: solo el Gladius. Lanza y Martillo llegan en el hito 1.4.

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
}

export type Weapon = {
	id: string,
	displayName: string,
	light: { Attack },
	heavy: Attack,
	-- Ventana de parada perfecta (segundos desde que empieza el bloqueo).
	parryWindow: number,
	-- Fracción del daño que absorbe el bloqueo.
	blockReduction: number,
	dodgeCost: number,
}

local function attack(fields: Attack): Attack
	return table.freeze(fields)
end

local Weapons: { [string]: Weapon } = {
	Gladius = table.freeze({
		id = "Gladius",
		displayName = "Gladius y escudo",
		light = table.freeze({
			attack({
				damage = 12,
				windup = 0.12,
				active = 0.1,
				recovery = 0.22,
				reach = 6,
				width = 6,
				height = 5,
				stun = 0,
			}),
			attack({
				damage = 12,
				windup = 0.12,
				active = 0.1,
				recovery = 0.22,
				reach = 6,
				width = 6,
				height = 5,
				stun = 0,
			}),
			attack({
				damage = 18,
				windup = 0.18,
				active = 0.12,
				recovery = 0.4,
				reach = 6.5,
				width = 7,
				height = 5,
				stun = 0.3,
			}),
		}),
		heavy = attack({
			damage = 15,
			windup = 0.25,
			active = 0.12,
			recovery = 0.5,
			reach = 5,
			width = 5,
			height = 5,
			stun = 0.8,
		}),
		parryWindow = 0.3,
		blockReduction = 0.7,
		dodgeCost = 25,
	}),
}

return table.freeze(Weapons)
