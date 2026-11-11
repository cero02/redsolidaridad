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

export type Line = { label: string, amount: number }
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
	local function add(label: string, amount: number)
		if amount > 0 then
			table.insert(lines, { label = label, amount = amount })
			base += amount
		end
	end

	add("Combate completado", xp.COMPLETE)
	if summary.won then
		add("Victoria", xp.VICTORY)
	end
	add(`Fases superadas ({summary.phasesCleared})`, summary.phasesCleared * xp.PER_PHASE)
	add(
		`Paradas perfectas ({summary.perfectParries})`,
		math.min(xp.PARRY_CAP, summary.perfectParries * xp.PER_PARRY)
	)
	add(`Compañeros reanimados ({summary.revives})`, summary.revives * xp.PER_REVIVE)
	if summary.won and summary.firstWinOfDay then
		add("Primera victoria del día", xp.FIRST_WIN_OF_DAY)
	end

	-- Multiplicadores sobre la base.
	local brotherhood = math.min(xp.BROTHERHOOD_CAP, summary.allies * xp.BROTHERHOOD_PER_ALLY)
	local multiplier = summary.decreeMultiplier * summary.eventMultiplier * (1 + brotherhood)
	local total = math.floor(base * multiplier + 0.5)
	if brotherhood > 0 then
		table.insert(lines, { label = `Hermandad (+{math.floor(brotherhood * 100 + 0.5)} %)`, amount = 0 })
	end
	if summary.decreeMultiplier ~= 1 then
		table.insert(lines, { label = `Decreto del César (×{summary.decreeMultiplier})`, amount = 0 })
	end
	if summary.eventMultiplier ~= 1 then
		table.insert(lines, { label = `Juegos Imperiales (×{summary.eventMultiplier})`, amount = 0 })
	end
	if summary.mentor then
		table.insert(lines, { label = "Mentor de un novato", amount = xp.MENTOR })
		total += xp.MENTOR
	end

	return { total = total, lines = lines }
end

return MatchRewards
