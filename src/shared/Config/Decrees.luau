--!strict
-- Edictos del César (textos: decree.<id>.name y decree.<id>.desc): un reto que cambia cada semana (lunes 00:00 UTC). Hace que cada
-- semana el combate sea distinto y da un título propio. Los decretos ROTAN: si te pierdes
-- uno, vuelve más adelante. Nunca se pierde nada para siempre.

export type Decree = {
	id: string,
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
		attackIntervalScale = 0.75,
		regrowTimeScale = 1,
		damageTakenScale = 1,
		xpMultiplier = 1.5,
		titleId = "DecretoFuria",
	},
	{
		id = "Clemencia",
		attackIntervalScale = 1,
		regrowTimeScale = 1,
		damageTakenScale = 0.8,
		xpMultiplier = 1.25,
		titleId = "DecretoClemencia",
	},
	{
		id = "Lerna",
		attackIntervalScale = 1,
		regrowTimeScale = 0.67,
		damageTakenScale = 1,
		xpMultiplier = 1.5,
		titleId = "DecretoLerna",
	},
	{
		id = "Sangre",
		attackIntervalScale = 1,
		regrowTimeScale = 1,
		damageTakenScale = 1.3,
		xpMultiplier = 1.5,
		titleId = "DecretoSangre",
	},
}

return table.freeze(Decrees)
