--!strict
-- Declaración central de TODOS los Remotes del juego.
-- Regla: ningún módulo crea Remotes por su cuenta. Ver docs/SECURITY.md.

local Check = require(script.Parent.Check)

export type Direction = "ToServer" | "ToClient"
export type Kind = "Event" | "UnreliableEvent"

export type Definition = {
	kind: Kind,
	direction: Direction,
	-- Solo ToServer: validadores de cada argumento (en orden).
	args: { Check.Validator }?,
	-- Solo ToServer: ráfaga máxima y fichas recuperadas por segundo, por jugador.
	rate: { capacity: number, perSecond: number }?,
}

local Remotes: { [string]: Definition } = {
	-- El cliente avisa de que ya escucha. El servidor responde con ProfileReady.
	ClientReady = {
		kind = "Event",
		direction = "ToServer",
		args = {},
		rate = { capacity = 3, perSecond = 0.2 },
	},

	-- Resumen público del perfil (nunca datos internos).
	ProfileReady = {
		kind = "Event",
		direction = "ToClient",
	},

	-- Combate: el cliente solo pide acciones; el servidor decide el resultado.
	CombatAttack = {
		kind = "Event",
		direction = "ToServer",
		args = { Check.oneOf({ "Light", "Heavy" }) },
		rate = { capacity = 8, perSecond = 6 },
	},
	CombatDodge = {
		kind = "Event",
		direction = "ToServer",
		args = {},
		rate = { capacity = 4, perSecond = 3 },
	},
	-- Poder de la esencia equipada (tecla Z).
	CombatEssence = {
		kind = "Event",
		direction = "ToServer",
		args = {},
		rate = { capacity = 3, perSecond = 1 },
	},
	-- Habilidad definitiva del arma (tecla R).
	CombatUltimate = {
		kind = "Event",
		direction = "ToServer",
		args = {},
		rate = { capacity = 3, perSecond = 1 },
	},
	-- Elegir arma y esencia en la armería (el servidor comprueba que estén desbloqueadas).
	SetLoadout = {
		kind = "Event",
		direction = "ToServer",
		args = { Check.string(16), Check.string(16) },
		rate = { capacity = 4, perSecond = 1 },
	},
	CombatBlock = {
		kind = "Event",
		direction = "ToServer",
		args = { Check.boolean() },
		rate = { capacity = 10, perSecond = 8 },
	},

	-- Estado autoritativo del propio luchador: { health, stamina, maxStamina, ultimate,
	-- blocking, weapon, essence, essenceReadyIn }.
	CombatState = {
		kind = "Event",
		direction = "ToClient",
	},
	-- Sucesos de combate: (tipo, userId, ...). Tipos: Attack, Hit, Dodge, Defense,
	-- Telegraph, Block, Downed, Revived, Ultimate, Essence.
	CombatEvent = {
		kind = "Event",
		direction = "ToClient",
	},

	-- Pilares (docs/design/PILARES.md) ------------------------------------------------
	-- Perfil público actualizado (nivel, experiencia, títulos, códice…).
	ProgressUpdate = {
		kind = "Event",
		direction = "ToClient",
	},
	-- Resultado de una partida: { won, time, record, total, lines, level, unlocks… }.
	MatchResults = {
		kind = "Event",
		direction = "ToClient",
	},
	-- Descubrimiento del Códice: (id, descubiertos, total).
	Discovery = {
		kind = "Event",
		direction = "ToClient",
	},
	-- Noticias del servidor para todos: (clave, parámetros).
	WorldNews = {
		kind = "Event",
		direction = "ToClient",
	},
	-- Estado de los eventos: { decreeId, decreeRemaining, gamesRemaining, offerings, goal }.
	WorldEvents = {
		kind = "Event",
		direction = "ToClient",
	},
	-- El jugador elige qué título lucir (el servidor comprueba que lo tiene).
	EquipTitle = {
		kind = "Event",
		direction = "ToServer",
		args = { Check.string(32) },
		rate = { capacity = 4, perSecond = 1 },
	},

	-- Ajustes del jugador: (idioma, volumen de música 0..1, temblor de cámara, modo ligero).
	SaveSettings = {
		kind = "Event",
		direction = "ToServer",
		args = {
			Check.oneOf({ "auto", "en", "es" }),
			Check.number({ min = 0, max = 1 }),
			Check.boolean(),
			Check.boolean(),
		},
		rate = { capacity = 5, perSecond = 2 },
	},
	-- Unirse a la arena desde el menú o tras una partida ("¡Otra vez!").
	QuickJoin = {
		kind = "Event",
		direction = "ToServer",
		args = {},
		rate = { capacity = 2, perSecond = 0.5 },
	},

	-- Los textos viajan como claves de idioma (Shared/Locale) y los traduce el cliente.
	-- Mensaje del anunciador del coliseo: (clave, parámetros, segundos).
	Announce = {
		kind = "Event",
		direction = "ToClient",
	},
	-- Estado del combate contra la bestia: (estado, clave de progreso, parámetros).
	EncounterState = {
		kind = "Event",
		direction = "ToClient",
	},
}

return table.freeze(Remotes)
