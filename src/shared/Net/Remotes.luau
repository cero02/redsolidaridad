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
	CombatBlock = {
		kind = "Event",
		direction = "ToServer",
		args = { Check.boolean() },
		rate = { capacity = 10, perSecond = 8 },
	},

	-- Estado autoritativo del propio luchador: { health, stamina, ultimate, blocking }.
	CombatState = {
		kind = "Event",
		direction = "ToClient",
	},
	-- Sucesos de combate: (tipo, userId, ...). Tipos: Attack, Hit, Dodge, Defense,
	-- Telegraph, Block, Downed, Revived.
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
	-- Noticias del servidor para todos: (texto).
	WorldNews = {
		kind = "Event",
		direction = "ToClient",
	},
	-- Estado de los eventos: { decree, decreeRemaining, gamesRemaining, offerings, goal }.
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

	-- Mensaje del anunciador del coliseo: (texto, segundos).
	Announce = {
		kind = "Event",
		direction = "ToClient",
	},
	-- Estado del combate contra la bestia: (estado, texto de progreso).
	EncounterState = {
		kind = "Event",
		direction = "ToClient",
	},
}

return table.freeze(Remotes)
