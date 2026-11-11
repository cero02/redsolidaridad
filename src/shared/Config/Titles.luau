--!strict
-- Títulos que se muestran sobre el gladiador. Cada uno cuenta cómo se consiguió:
-- presumir es contar una historia. Ninguno se compra.

export type Title = { name: string, how: string, color: { number } }

local GOLD = { 255, 210, 90 }
local SILVER = { 220, 220, 230 }
local PURPLE = { 200, 140, 255 }
local RED = { 255, 110, 90 }
local GREEN = { 140, 230, 140 }

local Titles: { [string]: Title } = {
	-- Rangos (por nivel).
	Tiro = { name = "Tiro", how = "Todo gladiador empieza aquí.", color = SILVER },
	Veteranus = { name = "Veteranus", how = "Alcanzar el nivel 5.", color = SILVER },
	PrimusPalus = { name = "Primus Palus", how = "Alcanzar el nivel 10.", color = GOLD },
	Campeon = { name = "Campeón", how = "Alcanzar el nivel 15.", color = GOLD },
	Rudiarius = { name = "Rudiarius", how = "Alcanzar el nivel 20.", color = GOLD },

	-- Hazañas.
	Matahidras = { name = "Matahidras", how = "Vencer a la Hidra 10 veces.", color = GREEN },
	Intactus = { name = "Intactus", how = "Vencer a la Hidra sin caer ni una vez.", color = GOLD },
	Velox = { name = "Velox", how = "Vencer a la Hidra en menos de 6 minutos.", color = RED },
	Erudito = { name = "Erudito de Lerna", how = "Completar el Códice de la Hidra.", color = PURPLE },
	Frater = { name = "Hermano de Armas", how = "Reanimar a 10 compañeros.", color = GREEN },
	Testigo = { name = "Testigo de los Juegos", how = "Vencer durante unos Juegos Imperiales.", color = PURPLE },

	-- Decretos del César (vuelven cuando su decreto regresa).
	DecretoFuria = { name = "Domador de la Furia", how = "Vencer bajo el Decreto de la Furia.", color = RED },
	DecretoSangre = { name = "Sangre de Hierro", how = "Vencer bajo el Decreto de Sangre.", color = RED },
	DecretoLerna = { name = "Señor del Fuego", how = "Vencer bajo el Decreto de Lerna.", color = RED },
	DecretoClemencia = {
		name = "Favorito del Pueblo",
		how = "Vencer bajo el Decreto de la Clemencia.",
		color = RED,
	},
}

return table.freeze(Titles)
