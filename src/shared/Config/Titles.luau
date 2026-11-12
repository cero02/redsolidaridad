--!strict
-- Títulos que se muestran sobre el gladiador. Cada uno cuenta cómo se consiguió:
-- presumir es contar una historia. Ninguno se compra.

-- Nombre y explicación de cada título: claves title.<id>.name y title.<id>.how.
export type Title = { color: { number } }

local GOLD = { 255, 210, 90 }
local SILVER = { 220, 220, 230 }
local PURPLE = { 200, 140, 255 }
local RED = { 255, 110, 90 }
local GREEN = { 140, 230, 140 }

local Titles: { [string]: Title } = {
	-- Rangos (por nivel).
	Tiro = { color = SILVER },
	Veteranus = { color = SILVER },
	PrimusPalus = { color = GOLD },
	Campeon = { color = GOLD },
	Rudiarius = { color = GOLD },

	-- Hazañas.
	Matahidras = { color = GREEN },
	Intactus = { color = GOLD },
	Velox = { color = RED },
	Erudito = { color = PURPLE },
	Frater = { color = GREEN },
	Testigo = { color = PURPLE },

	-- Decretos del César (vuelven cuando su decreto regresa).
	DecretoFuria = { color = RED },
	DecretoSangre = { color = RED },
	DecretoLerna = { color = RED },
	DecretoClemencia = { color = RED },
}

return table.freeze(Titles)
