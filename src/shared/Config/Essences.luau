--!strict
-- Esencias: poderes arrancados a las bestias. Una equipada a la vez (hito 1.4).
-- Cada una tiene un poder activo con recarga (tecla Z) y una pasiva siempre activa.
-- Diseño: docs/design/ARMAS_Y_ESENCIAS.md.

export type Essence = {
	id: "Loba" | "Aguila" | "Hidra",
	name: string,
	power: string,
	passive: string,
	how: string,
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
		name = "Esencia de la Loba de Roma",
		power = "Instinto: 4 s de +30 % de velocidad y esquivas sin coste.",
		passive = "+10 % de aguante máximo.",
		how = "Inicial.",
		cooldown = 18,
		duration = 4,
		speedMultiplier = 1.3,
		staminaBonus = 0.1,
	}),
	Aguila = table.freeze({
		id = "Aguila",
		name = "Esencia del Águila imperial",
		power = "Picado: saltas muy alto y caes golpeando la zona (25 de daño).",
		passive = "Garras: los ataques pesados hacen +20 % de daño.",
		how = "Alcanza el nivel 5.",
		cooldown = 14,
		duration = 0,
		slamDamage = 25,
		slamRadius = 8,
		slamDelay = 0.9,
		heavyBonus = 0.2,
	}),
	Hidra = table.freeze({
		id = "Hidra",
		name = "Esencia de la Hidra",
		power = "Veneno: durante 6 s tus golpes hacen +30 % de daño.",
		passive = "Regeneras 1 de vida por segundo si llevas 5 s sin recibir daño.",
		how = "Vence a la Hidra por primera vez.",
		cooldown = 20,
		duration = 6,
		damageBonus = 0.3,
		regenPerSecond = 1,
		regenDelay = 5,
	}),
}

return table.freeze(Essences)
