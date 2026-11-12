--!strict
-- El Códice: secretos de la Hidra que el jugador descubre jugando. La lección y el
-- acertijo de cada uno están en los idiomas: codex.<id>.lesson y codex.<id>.riddle. Nadie se los explica:
-- al descubrirlos recibe el nombre latino, experiencia y una entrada en su Códice.
-- Así aprender una mecánica se siente como un logro propio.

export type Discovery = {
	id: string,
	-- Nombre latino que se revela al descubrirlo.
	name: string,
	xp: number,
}

local Codex: { Discovery } = {
	{
		id = "ParmaPerfecta",
		name = "Parma Perfecta",
		xp = 50,
	},
	{
		id = "IgnisPurgat",
		name = "Ignis Purgat",
		xp = 75,
	},
	{
		id = "HydraMultiplex",
		name = "Hydra Multiplex",
		xp = 40,
	},
	{
		id = "Saltus",
		name = "Saltus",
		xp = 40,
	},
	{
		id = "DuplexSigillum",
		name = "Duplex Sigillum",
		xp = 75,
	},
	{
		id = "IgnisRenatus",
		name = "Ignis Renatus",
		xp = 40,
	},
	{
		id = "CaputAureum",
		name = "Caput Aureum",
		xp = 75,
	},
	{
		id = "SaxumCadit",
		name = "Saxum Cadit",
		xp = 100,
	},
	{
		id = "IgnisReflexus",
		name = "Ignis Reflexus",
		xp = 75,
	},
	{
		id = "Frater",
		name = "Frater",
		xp = 50,
	},
	{
		id = "Intactus",
		name = "Intactus",
		xp = 150,
	},
}

return table.freeze(Codex)
