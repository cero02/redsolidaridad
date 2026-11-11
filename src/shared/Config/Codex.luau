--!strict
-- El Códice: secretos de la Hidra que el jugador descubre jugando. Nadie se los explica:
-- al descubrirlos recibe el nombre latino, experiencia y una entrada en su Códice.
-- Así aprender una mecánica se siente como un logro propio.

export type Discovery = {
	id: string,
	-- Nombre latino que se revela al descubrirlo.
	name: string,
	-- Qué ha aprendido el jugador (se muestra al descubrirlo).
	lesson: string,
	-- Pista críptica visible en el Códice antes de descubrirlo.
	riddle: string,
	xp: number,
}

local Codex: { Discovery } = {
	{
		id = "ParmaPerfecta",
		name = "Parma Perfecta",
		lesson = "Bloquear justo antes del golpe lo anula y aturde al atacante.",
		riddle = "El escudo que llega tarde sufre; el que llega justo, castiga.",
		xp = 50,
	},
	{
		id = "IgnisPurgat",
		name = "Ignis Purgat",
		lesson = "El fuego de los braseros sella los cuellos de la Hidra para siempre.",
		riddle = "Lo que el hierro corta, otra cosa debe cerrarlo.",
		xp = 75,
	},
	{
		id = "HydraMultiplex",
		name = "Hydra Multiplex",
		lesson = "Cada cuello que no se sella devuelve su cabeza… y una más.",
		riddle = "A veces la derrota también enseña. Deja que crezca.",
		xp = 40,
	},
	{
		id = "Saltus",
		name = "Saltus",
		lesson = "Un salto a tiempo libra el coletazo de la Hidra.",
		riddle = "Lo que barre el suelo no alcanza el aire.",
		xp = 40,
	},
	{
		id = "DuplexSigillum",
		name = "Duplex Sigillum",
		lesson = "Dos cuellos sellados en diez segundos: el fuego bien administrado.",
		riddle = "Un brasero, dos heridas, una sola llama.",
		xp = 75,
	},
	{
		id = "IgnisRenatus",
		name = "Ignis Renatus",
		lesson = "Los braseros apagados se pueden reavivar.",
		riddle = "Ni el agua de Lerna apaga lo que el gladiador enciende.",
		xp = 40,
	},
	{
		id = "CaputAureum",
		name = "Caput Aureum",
		lesson = "La cabeza inmortal se aturde con una parada perfecta o un golpe pesado.",
		riddle = "Lo que no puede morir, aún puede tambalearse.",
		xp = 75,
	},
	{
		id = "SaxumCadit",
		name = "Saxum Cadit",
		lesson = "La roca de las cadenas entierra lo que el acero no puede matar.",
		riddle = "Hércules no la mató. La enterró.",
		xp = 100,
	},
	{
		id = "IgnisReflexus",
		name = "Ignis Reflexus",
		lesson = "Una parada perfecta devuelve las bolas de fuego a quien las lanzó.",
		riddle = "El fuego que viene hacia ti también sabe volver.",
		xp = 75,
	},
	{
		id = "Frater",
		name = "Frater",
		lesson = "Un compañero caído se levanta si lo sostienes a tiempo.",
		riddle = "En la arena nadie cae solo si alguien se queda.",
		xp = 50,
	},
	{
		id = "Intactus",
		name = "Intactus",
		lesson = "Vencer a la Hidra sin caer ni una vez.",
		riddle = "La gloria más pura no tiene cicatrices.",
		xp = 150,
	},
}

return table.freeze(Codex)
