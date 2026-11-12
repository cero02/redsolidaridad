--!strict
-- Calcula la experiencia de una partida con su desglose. Módulo puro (probado con Lune).
-- Diseño: docs/design/PROGRESION.md y docs/design/PILARES.md.

export type Summary = {
	won: boolean,
	phasesCleared: number,
	perfectParries: number,
	revives: number,
	-- Primera victoria del día natural (UTC). Es un regalo, nunca una penalización.
	firstWinOfDay: boolean,
	-- Aliados que terminaron la partida contigo.
	allies: number,
	-- Este jugador es veterano y había un novato en el grupo.
	mentor: boolean,
	decreeMultiplier: number,
	-- Juegos Imperiales en curso (x2) u otro evento.
	eventMultiplier: number,
}

-- Cada línea es una clave de idioma con sus parámetros (la traduce el cliente).
export type Line = { key: string, params: { [string]: any }?, amount: number }
export type Reward = { total: number, lines: { Line } }

type XpConfig = {
	COMPLETE: number,
	VICTORY: number,
	PER_PHASE: number,
	PER_PARRY: number,
	PARRY_CAP: number,
	PER_REVIVE: number,
	FIRST_WIN_OF_DAY: number,
	BROTHERHOOD_PER_ALLY: number,
	BROTHERHOOD_CAP: number,
	MENTOR: number,
	[string]: any,
}

local MatchRewards = {}

function MatchRewards.compute(xp: XpConfig, summary: Summary): Reward
	local lines: { Line } = {}
	local base = 0
	local function add(key: string, params: { [string]: any }?, amount: number)
		if amount > 0 then
			table.insert(lines, { key = key, params = params, amount = amount })
			base += amount
		end
	end

	add("reward.complete", nil, xp.COMPLETE)
	if summary.won then
		add("reward.victory", nil, xp.VICTORY)
	end
	add("reward.phases", { count = summary.phasesCleared }, summary.phasesCleared * xp.PER_PHASE)
	add(
		"reward.parries",
		{ count = summary.perfectParries },
		math.min(xp.PARRY_CAP, summary.perfectParries * xp.PER_PARRY)
	)
	add("reward.revives", { count = summary.revives }, summary.revives * xp.PER_REVIVE)
	if summary.won and summary.firstWinOfDay then
		add("reward.firstWin", nil, xp.FIRST_WIN_OF_DAY)
	end

	-- Multiplicadores sobre la base.
	local brotherhood = math.min(xp.BROTHERHOOD_CAP, summary.allies * xp.BROTHERHOOD_PER_ALLY)
	local multiplier = summary.decreeMultiplier * summary.eventMultiplier * (1 + brotherhood)
	local total = math.floor(base * multiplier + 0.5)
	if brotherhood > 0 then
		table.insert(lines, { key = "reward.brotherhood", params = { percent = math.floor(brotherhood * 100 + 0.5) }, amount = 0 })
	end
	if summary.decreeMultiplier ~= 1 then
		table.insert(lines, { key = "reward.decree", params = { mult = summary.decreeMultiplier }, amount = 0 })
	end
	if summary.eventMultiplier ~= 1 then
		table.insert(lines, { key = "reward.games", params = { mult = summary.eventMultiplier }, amount = 0 })
	end
	if summary.mentor then
		table.insert(lines, { key = "reward.mentor", amount = xp.MENTOR })
		total += xp.MENTOR
	end

	return { total = total, lines = lines }
end

return MatchRewards
