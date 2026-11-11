--!strict
-- Decretos del César: un reto que cambia cada semana (lunes 00:00 UTC). Hace que cada
-- semana el combate sea distinto y da un título propio. Los decretos ROTAN: si te pierdes
-- uno, vuelve más adelante. Nunca se pierde nada para siempre.

export type Decree = {
	id: string,
	name: string,
	description: string,
	-- Modificadores del combate (1 = sin cambio).
	attackIntervalScale: number,
	regrowTimeScale: number,
	damageTakenScale: number,
	xpMultiplier: number,
	titleId: string,
}

local Decrees: { Decree } = {
	{
		id = "Furia",
		name = "Decreto de la Furia",
		description = "La Hidra ataca un 25 % más rápido. Experiencia ×1,5.",
		attackIntervalScale = 0.75,
		regrowTimeScale = 1,
		damageTakenScale = 1,
		xpMultiplier = 1.5,
		titleId = "DecretoFuria",
	},
	{
		id = "Clemencia",
		name = "Decreto de la Clemencia",
		description = "El César es benévolo: recibes un 20 % menos de daño. Experiencia ×1,25.",
		attackIntervalScale = 1,
		regrowTimeScale = 1,
		damageTakenScale = 0.8,
		xpMultiplier = 1.25,
		titleId = "DecretoClemencia",
	},
	{
		id = "Lerna",
		name = "Decreto de Lerna",
		description = "Las cabezas vuelven a crecer en 8 segundos. Experiencia ×1,5.",
		attackIntervalScale = 1,
		regrowTimeScale = 0.67,
		damageTakenScale = 1,
		xpMultiplier = 1.5,
		titleId = "DecretoLerna",
	},
	{
		id = "Sangre",
		name = "Decreto de Sangre",
		description = "Cada golpe duele un 30 % más. Experiencia ×1,5.",
		attackIntervalScale = 1,
		regrowTimeScale = 1,
		damageTakenScale = 1.3,
		xpMultiplier = 1.5,
		titleId = "DecretoSangre",
	},
}

return table.freeze(Decrees)
