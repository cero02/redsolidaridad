--!strict
-- Estado de combate de un luchador: vida, aguante, combo, esquiva, bloqueo y medidor
-- de la definitiva. Módulo puro: el tiempo llega como parámetro (`now`), así el
-- servidor lo usa con su reloj, el cliente lo usa para predecir y Lune lo prueba.
-- Diseño: docs/design/COMBATE.md.

export type CombatConfig = {
	MAX_HEALTH: number,
	MAX_STAMINA: number,
	STAMINA_REGEN_PER_SECOND: number,
	STAMINA_REGEN_DELAY: number,
	COMBO_RESET: number,
	DODGE_INVULNERABLE_TIME: number,
	DODGE_COOLDOWN: number,
	BLOCK_STAMINA_PER_HIT: number,
	ACTION_LATENCY_GRACE: number,
	DEFENSE_LATENCY_GRACE: number,
	ULTIMATE_MAX: number,
	ULTIMATE_PER_DAMAGE: number,
	ULTIMATE_PER_PARRY: number,
	ULTIMATE_PER_CLOSE_DODGE: number,
	CLOSE_DODGE_WINDOW: number,
	[string]: any,
}

type Attack = {
	damage: number,
	windup: number,
	active: number,
	recovery: number,
	stun: number,
	[string]: any,
}

export type Weapon = {
	light: { Attack },
	heavy: Attack,
	parryWindow: number,
	blockReduction: number,
	dodgeCost: number,
	[string]: any,
}

export type AttackKind = "Light" | "Heavy"

export type AttackPlan = {
	kind: AttackKind,
	-- Golpe del combo (1..n) para ataques ligeros; 1 para pesados.
	step: number,
	attack: Attack,
}

export type DefenseResult = "Dodged" | "Parried" | "Blocked" | "GuardBroken" | "Hit"

export type HitOutcome = {
	result: DefenseResult,
	damageTaken: number,
	closeDodge: boolean,
}

export type Snapshot = {
	health: number,
	stamina: number,
	ultimate: number,
	blocking: boolean,
}

export type FighterState = {
	health: number,
	stamina: number,
	ultimate: number,
	blocking: boolean,
	weapon: Weapon,

	tryAttack: (self: FighterState, kind: AttackKind, now: number) -> (AttackPlan?, string?),
	tryDodge: (self: FighterState, now: number) -> (boolean, string?),
	setBlocking: (self: FighterState, blocking: boolean, now: number) -> (),
	receiveHit: (self: FighterState, damage: number, impactTime: number, now: number) -> HitOutcome,
	addDamageDealt: (self: FighterState, amount: number) -> (),
	stun: (self: FighterState, duration: number, now: number) -> (),
	isStunned: (self: FighterState, now: number) -> boolean,
	isDead: (self: FighterState) -> boolean,
	snapshot: (self: FighterState, now: number) -> Snapshot,
	applySnapshot: (self: FighterState, snapshot: Snapshot, now: number) -> (),
}

local FighterState = {}

function FighterState.new(weapon: Weapon, config: CombatConfig, now: number): FighterState
	local state = {
		health = config.MAX_HEALTH,
		stamina = config.MAX_STAMINA,
		ultimate = 0,
		blocking = false,
		weapon = weapon,
	} :: FighterState

	-- Estado interno (no se replica).
	local busyUntil = -math.huge
	local stunnedUntil = -math.huge
	local lastAttackEndsAt = -math.huge
	local comboStep = 0
	local lastStaminaSpendAt = -math.huge
	local staminaUpdatedAt = now
	local dodgeStartedAt = -math.huge
	local nextDodgeAt = -math.huge
	local blockStartedAt = -math.huge

	-- Recupera aguante de forma perezosa hasta `t`.
	local function regen(t: number)
		local regenFrom = math.max(staminaUpdatedAt, lastStaminaSpendAt + config.STAMINA_REGEN_DELAY)
		if t > regenFrom then
			state.stamina =
				math.min(config.MAX_STAMINA, state.stamina + (t - regenFrom) * config.STAMINA_REGEN_PER_SECOND)
		end
		staminaUpdatedAt = math.max(staminaUpdatedAt, t)
	end

	local function spendStamina(amount: number, t: number)
		regen(t)
		state.stamina = math.max(0, state.stamina - amount)
		lastStaminaSpendAt = t
		staminaUpdatedAt = t
	end

	local function addUltimate(amount: number)
		state.ultimate = math.min(config.ULTIMATE_MAX, state.ultimate + amount)
	end

	function state.isDead(self: FighterState): boolean
		return self.health <= 0
	end

	function state.isStunned(_self: FighterState, t: number): boolean
		return t < stunnedUntil
	end

	function state.tryAttack(self: FighterState, kind: AttackKind, t: number): (AttackPlan?, string?)
		if self:isDead() then
			return nil, "muerto"
		end
		if self:isStunned(t) then
			return nil, "aturdido"
		end
		-- El margen tolera que la petición llegue algo antes por la latencia.
		if t < busyUntil - config.ACTION_LATENCY_GRACE then
			return nil, "ocupado"
		end

		local attack: Attack
		local step: number
		if kind == "Light" then
			local comboContinues = t - lastAttackEndsAt <= config.COMBO_RESET
			step = if comboContinues and comboStep < #self.weapon.light then comboStep + 1 else 1
			attack = self.weapon.light[step]
			comboStep = step
		else
			step = 1
			attack = self.weapon.heavy
			comboStep = 0
		end

		-- Atacar baja la guardia.
		self.blocking = false

		local start = math.max(t, busyUntil)
		busyUntil = start + attack.windup + attack.active + attack.recovery
		lastAttackEndsAt = busyUntil
		return { kind = kind, step = step, attack = attack }, nil
	end

	function state.tryDodge(self: FighterState, t: number): (boolean, string?)
		if self:isDead() then
			return false, "muerto"
		end
		if self:isStunned(t) then
			return false, "aturdido"
		end
		if t < nextDodgeAt - config.ACTION_LATENCY_GRACE then
			return false, "recarga"
		end
		regen(t)
		if self.stamina < self.weapon.dodgeCost then
			return false, "sin aguante"
		end
		spendStamina(self.weapon.dodgeCost, t)
		self.blocking = false
		dodgeStartedAt = t
		nextDodgeAt = t + config.DODGE_COOLDOWN
		-- Esquivar cancela la recuperación de un ataque (se siente más ágil).
		busyUntil = math.min(busyUntil, t + config.DODGE_INVULNERABLE_TIME)
		comboStep = 0
		return true, nil
	end

	function state.setBlocking(self: FighterState, blocking: boolean, t: number)
		if blocking and (self:isDead() or self:isStunned(t)) then
			return
		end
		if blocking and not self.blocking then
			blockStartedAt = t
		end
		self.blocking = blocking
	end

	-- Resuelve un golpe enemigo que impacta en `impactTime`. Se llama en `now`, que debe
	-- ser al menos impactTime + DEFENSE_LATENCY_GRACE para que el margen funcione.
	function state.receiveHit(self: FighterState, damage: number, impactTime: number, t: number): HitOutcome
		if self:isDead() then
			return { result = "Hit", damageTaken = 0, closeDodge = false }
		end
		local grace = config.DEFENSE_LATENCY_GRACE

		-- Esquiva: empezó antes del impacto (dentro de la invulnerabilidad) o justo después
		-- dentro del margen de latencia.
		local dodgeDelta = impactTime - dodgeStartedAt
		if dodgeDelta <= config.DODGE_INVULNERABLE_TIME and dodgeDelta >= -grace then
			local closeDodge = dodgeDelta <= config.CLOSE_DODGE_WINDOW
			if closeDodge then
				addUltimate(config.ULTIMATE_PER_CLOSE_DODGE)
			end
			return { result = "Dodged", damageTaken = 0, closeDodge = closeDodge }
		end

		if self.blocking then
			local blockDelta = impactTime - blockStartedAt
			if blockDelta <= self.weapon.parryWindow and blockDelta >= -grace then
				addUltimate(config.ULTIMATE_PER_PARRY)
				return { result = "Parried", damageTaken = 0, closeDodge = false }
			end

			regen(t)
			if self.stamina >= config.BLOCK_STAMINA_PER_HIT then
				spendStamina(config.BLOCK_STAMINA_PER_HIT, t)
				local taken = damage * (1 - self.weapon.blockReduction)
				self.health = math.max(0, self.health - taken)
				return { result = "Blocked", damageTaken = taken, closeDodge = false }
			end

			-- Sin aguante: la guardia se rompe y el golpe entra entero.
			spendStamina(self.stamina, t)
			self.blocking = false
			self.health = math.max(0, self.health - damage)
			return { result = "GuardBroken", damageTaken = damage, closeDodge = false }
		end

		self.health = math.max(0, self.health - damage)
		return { result = "Hit", damageTaken = damage, closeDodge = false }
	end

	function state.addDamageDealt(_self: FighterState, amount: number)
		addUltimate(amount * config.ULTIMATE_PER_DAMAGE)
	end

	function state.stun(self: FighterState, duration: number, t: number)
		stunnedUntil = math.max(stunnedUntil, t + duration)
		self.blocking = false
		comboStep = 0
	end

	function state.snapshot(self: FighterState, t: number): Snapshot
		regen(t)
		return {
			health = self.health,
			stamina = self.stamina,
			ultimate = self.ultimate,
			blocking = self.blocking,
		}
	end

	-- El cliente corrige su predicción con la copia autoritativa del servidor.
	function state.applySnapshot(self: FighterState, snapshot: Snapshot, t: number)
		self.health = snapshot.health
		self.stamina = snapshot.stamina
		self.ultimate = snapshot.ultimate
		self.blocking = snapshot.blocking
		staminaUpdatedAt = t
	end

	return state
end

return FighterState
