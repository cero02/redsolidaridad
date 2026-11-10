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
	-- Sucesos de combate: (tipo, userId, ...). Tipos: Attack, Hit, Dodge, Defense, Telegraph.
	CombatEvent = {
		kind = "Event",
		direction = "ToClient",
	},
}

return table.freeze(Remotes)
