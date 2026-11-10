--!strict
-- Reglas de la Hidra: cabezas, cuellos cortados, regeneración, cauterización y elección
-- adaptativa de ataques. Módulo puro (sin APIs de Roblox) para probarlo con Lune.
-- Diseño: docs/design/HIDRA.md.

export type HeadStatus = "Empty" | "Alive" | "Severed" | "Cauterized"

export type Head = {
	slot: number,
	status: HeadStatus,
	health: number,
	-- Solo si está cortada: momento en que volverá a crecer.
	regrowAt: number,
}

export type Config = {
	INITIAL_HEADS: number,
	MAX_SLOTS: number,
	HEAD_HEALTH: number,
	REGROW_TIME: number,
	CAUTERIZE_REQUIRED: number,
	[string]: any,
}

export type RegrowEvent = { slot: number, newSlot: number? }
export type DamageResult = "Ignored" | "Damaged" | "Severed"
export type Pattern = "Bite" | "Spit" | "Tail"

export type PatternContext = {
	-- Hay una cabeza libre y algún jugador a su alcance.
	canBite: boolean,
	-- Jugadores cerca del cuerpo y jugadores fuera del alcance del mordisco.
	nearCount: number,
	farCount: number,
	lastPattern: Pattern?,
	-- Veces seguidas que se ha usado lastPattern.
	repeatCount: number,
}

export type TargetInfo = {
	-- Segundos desde que este jugador fue objetivo por última vez.
	timeSinceAttacked: number,
	-- Ataques seguidos dirigidos a este jugador.
	consecutive: number,
}

export type Hydra = {
	heads: { Head },
	cauterizedCount: number,
	regrowCount: number,

	damageHead: (self: Hydra, slot: number, damage: number, now: number) -> DamageResult,
	cauterize: (self: Hydra, slot: number) -> boolean,
	update: (self: Hydra, now: number) -> { RegrowEvent },
	aliveSlots: (self: Hydra) -> { number },
	isDefeated: (self: Hydra) -> boolean,
}

local HydraLogic = {}

function HydraLogic.new(config: Config): Hydra
	local hydra = {
		heads = {},
		cauterizedCount = 0,
		regrowCount = 0,
	} :: Hydra

	for slot = 1, config.MAX_SLOTS do
		local alive = slot <= config.INITIAL_HEADS
		hydra.heads[slot] = {
			slot = slot,
			status = if alive then "Alive" else "Empty",
			health = if alive then config.HEAD_HEALTH else 0,
			regrowAt = 0,
		}
	end

	function hydra.damageHead(self: Hydra, slot: number, damage: number, now: number): DamageResult
		local head = self.heads[slot]
		if head == nil or head.status ~= "Alive" or damage <= 0 then
			return "Ignored"
		end
		head.health = math.max(0, head.health - damage)
		if head.health > 0 then
			return "Damaged"
		end
		head.status = "Severed"
		head.regrowAt = now + config.REGROW_TIME
		return "Severed"
	end

	-- Cierra un cuello cortado para siempre. Devuelve false si no estaba cortado.
	function hydra.cauterize(self: Hydra, slot: number): boolean
		local head = self.heads[slot]
		if head == nil or head.status ~= "Severed" then
			return false
		end
		head.status = "Cauterized"
		self.cauterizedCount += 1
		return true
	end

	-- Regenera los cuellos cuyo tiempo ha vencido: vuelve su cabeza y nace otra en un
	-- hueco libre (si queda alguno).
	function hydra.update(self: Hydra, now: number): { RegrowEvent }
		local events = {}
		for _, head in self.heads do
			if head.status == "Severed" and now >= head.regrowAt then
				head.status = "Alive"
				head.health = config.HEAD_HEALTH
				self.regrowCount += 1

				local newSlot: number? = nil
				for _, other in self.heads do
					if other.status == "Empty" then
						other.status = "Alive"
						other.health = config.HEAD_HEALTH
						newSlot = other.slot
						break
					end
				end
				table.insert(events, { slot = head.slot, newSlot = newSlot })
			end
		end
		return events
	end

	function hydra.aliveSlots(self: Hydra): { number }
		local slots = {}
		for _, head in self.heads do
			if head.status == "Alive" then
				table.insert(slots, head.slot)
			end
		end
		return slots
	end

	function hydra.isDefeated(self: Hydra): boolean
		return self.cauterizedCount >= config.CAUTERIZE_REQUIRED
	end

	return hydra
end

local PATTERN_ORDER: { Pattern } = { "Bite", "Spit", "Tail" }

-- Pesos de cada ataque según la situación. Reglas deterministas: mismo contexto y misma
-- tirada (`roll` en [0, 1)) dan siempre el mismo resultado.
function HydraLogic.patternWeights(context: PatternContext): { [Pattern]: number }
	local weights: { [Pattern]: number } = {
		Bite = if context.canBite then 5 else 0,
		-- Los jugadores lejanos atraen el veneno.
		Spit = 2 + 3 * context.farCount,
		-- Los jugadores pegados al cuerpo atraen el coletazo.
		Tail = if context.nearCount > 0 then 1 + 3 * context.nearCount else 0,
	}
	-- Nunca el mismo ataque tres veces seguidas.
	if context.lastPattern ~= nil and context.repeatCount >= 2 then
		weights[context.lastPattern] = 0
	end
	return weights
end

function HydraLogic.choosePattern(context: PatternContext, roll: number): Pattern
	local weights = HydraLogic.patternWeights(context)
	local total = 0
	for _, pattern in PATTERN_ORDER do
		total += weights[pattern]
	end
	if total <= 0 then
		return "Spit"
	end
	local threshold = roll * total
	for _, pattern in PATTERN_ORDER do
		threshold -= weights[pattern]
		if threshold < 0 then
			return pattern
		end
	end
	return "Spit"
end

-- Elige objetivo repartiendo la atención: quien lleva tiempo sin ser atacado pesa más y
-- quien ha recibido tres ataques seguidos pesa mucho menos. Devuelve el índice elegido.
function HydraLogic.chooseTarget(candidates: { TargetInfo }, roll: number): number
	assert(#candidates > 0, "sin candidatos")
	local weights = {}
	local total = 0
	for index, info in candidates do
		local weight = 1 + math.min(info.timeSinceAttacked, 20) / 5
		if info.consecutive >= 3 then
			weight *= 0.2
		end
		weights[index] = weight
		total += weight
	end
	local threshold = roll * total
	for index, weight in weights do
		threshold -= weight
		if threshold < 0 then
			return index
		end
	end
	return #candidates
end

return HydraLogic
