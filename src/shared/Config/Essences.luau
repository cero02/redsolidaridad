--!strict
-- Esencias: poderes arrancados a las bestias. Una equipada a la vez (hito 1.4).
-- Cada una tiene un poder activo con recarga (tecla Z) y una pasiva siempre activa.
-- Diseño: docs/design/ARMAS_Y_ESENCIAS.md. Textos: essence.<id>.name/power/passive/how.

export type Essence = {
	id: "Loba" | "Aguila" | "Hidra",
	cooldown: number,
	-- Parámetros del poder y de la pasiva.
	duration: number,
	speedMultiplier: number?,
	staminaBonus: number?,
	slamDamage: number?,
	slamRadius: number?,
	slamDelay: number?,
	heavyBonus: number?,
	damageBonus: number?,
	regenPerSecond: number?,
	regenDelay: number?,
}

local Essences: { [string]: Essence } = {
	Loba = table.freeze({
		id = "Loba",
		cooldown = 18,
		duration = 4,
		speedMultiplier = 1.3,
		staminaBonus = 0.1,
	}),
	Aguila = table.freeze({
		id = "Aguila",
		cooldown = 14,
		duration = 0,
		slamDamage = 25,
		slamRadius = 8,
		slamDelay = 0.9,
		heavyBonus = 0.2,
	}),
	Hidra = table.freeze({
		id = "Hidra",
		cooldown = 20,
		duration = 6,
		damageBonus = 0.3,
		regenPerSecond = 1,
		regenDelay = 5,
	}),
}

return table.freeze(Essences)
