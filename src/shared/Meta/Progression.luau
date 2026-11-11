--!strict
-- Cálculos puros de progresión: experiencia por nivel, subidas de nivel, rangos y
-- desbloqueos. Lo usan el servidor (autoridad) y el cliente (interfaz). Probado con Lune.

type Unlock = { kind: string, id: string, name: string }
type Rank = { minLevel: number, id: string, name: string }

export type Config = {
	MAX_LEVEL: number,
	XP_BASE: number,
	XP_STEP: number,
	RANKS: { Rank },
	UNLOCKS: { [number]: { Unlock } },
	[string]: any,
}

export type LevelResult = {
	level: number,
	xp: number,
	levelsGained: number,
	unlocks: { Unlock },
}

local Progression = {}

-- Experiencia necesaria para pasar del nivel `level` al siguiente (0 en el máximo).
function Progression.xpToNext(config: Config, level: number): number
	if level >= config.MAX_LEVEL then
		return 0
	end
	return config.XP_BASE + config.XP_STEP * (level - 1)
end

-- Suma experiencia y resuelve las subidas de nivel con sus desbloqueos.
function Progression.addXp(config: Config, level: number, xp: number, amount: number): LevelResult
	local result: LevelResult = { level = level, xp = xp + math.max(0, math.floor(amount)), levelsGained = 0, unlocks = {} }
	while result.level < config.MAX_LEVEL do
		local needed = Progression.xpToNext(config, result.level)
		if result.xp < needed then
			break
		end
		result.xp -= needed
		result.level += 1
		result.levelsGained += 1
		for _, unlock in config.UNLOCKS[result.level] or {} do
			table.insert(result.unlocks, unlock)
		end
	end
	if result.level >= config.MAX_LEVEL then
		result.xp = 0
	end
	return result
end

function Progression.rankFor(config: Config, level: number): Rank
	local current = config.RANKS[1]
	for _, rank in config.RANKS do
		if level >= rank.minLevel then
			current = rank
		end
	end
	return current
end

-- Próximo nivel con algo que desbloquear y qué es (para motivar: "a 2 niveles de…").
function Progression.nextUnlock(config: Config, level: number): (number?, { Unlock }?)
	for nextLevel = level + 1, config.MAX_LEVEL do
		local unlocks = config.UNLOCKS[nextLevel]
		if unlocks and #unlocks > 0 then
			return nextLevel, unlocks
		end
	end
	return nil, nil
end

-- Todo lo desbloqueado hasta un nivel (para reparar perfiles o mostrar colecciones).
function Progression.unlocksUpTo(config: Config, level: number): { Unlock }
	local all = {}
	for current = 2, math.min(level, config.MAX_LEVEL) do
		for _, unlock in config.UNLOCKS[current] or {} do
			table.insert(all, unlock)
		end
	end
	return all
end

return Progression
