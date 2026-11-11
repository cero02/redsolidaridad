--!strict
local Codex = require("../src/shared/Config/Codex")
local DecreeCalendar = require("../src/shared/Meta/DecreeCalendar")
local Decrees = require("../src/shared/Config/Decrees")
local MatchRewards = require("../src/server/Meta/MatchRewards")
local Progression = require("../src/shared/Meta/Progression")
local ProgressionConfig = require("../src/shared/Config/Progression")
local T = require("./TestUtil")
local Titles = require("../src/shared/Config/Titles")

T.suite("Progresión, recompensas, decretos y códice")

local config = ProgressionConfig :: any
local XP = ProgressionConfig.XP

local function summary(fields: { [string]: any }): MatchRewards.Summary
	local base: { [string]: any } = {
		won = false,
		phasesCleared = 0,
		perfectParries = 0,
		revives = 0,
		firstWinOfDay = false,
		allies = 0,
		mentor = false,
		decreeMultiplier = 1,
		eventMultiplier = 1,
	}
	for key, value in fields do
		base[key] = value
	end
	return base :: any
end

-- Progresión ---------------------------------------------------------------

T.test("la experiencia por nivel sigue 100 + 50 × (n − 1)", function()
	T.expectEqual(Progression.xpToNext(config, 1), 100)
	T.expectEqual(Progression.xpToNext(config, 2), 150)
	T.expectEqual(Progression.xpToNext(config, 10), 550)
	T.expectEqual(Progression.xpToNext(config, ProgressionConfig.MAX_LEVEL), 0)
end)

T.test("sumar experiencia sin llegar al siguiente nivel", function()
	local result = Progression.addXp(config, 1, 0, 60)
	T.expectEqual(result.level, 1)
	T.expectEqual(result.xp, 60)
	T.expectEqual(result.levelsGained, 0)
end)

T.test("subir varios niveles a la vez acumula los desbloqueos", function()
	-- 100 (1→2) + 150 (2→3) + 200 (3→4) = 450
	local result = Progression.addXp(config, 1, 0, 460)
	T.expectEqual(result.level, 4)
	T.expectEqual(result.xp, 10)
	T.expectEqual(result.levelsGained, 3)
	local ids = {}
	for _, unlock in result.unlocks do
		table.insert(ids, unlock.id)
	end
	T.expectEqual(table.concat(ids, ","), "Hasta,ShieldEmblem,Martillo")
end)

T.test("en el nivel máximo no se acumula experiencia", function()
	local result = Progression.addXp(config, ProgressionConfig.MAX_LEVEL - 1, 0, 1000000)
	T.expectEqual(result.level, ProgressionConfig.MAX_LEVEL)
	T.expectEqual(result.xp, 0)
end)

T.test("la experiencia negativa se ignora", function()
	local result = Progression.addXp(config, 3, 50, -500)
	T.expectEqual(result.level, 3)
	T.expectEqual(result.xp, 50)
end)

T.test("los rangos cambian en los niveles 5, 10, 15 y 20", function()
	T.expectEqual(Progression.rankFor(config, 1).name, "Tiro")
	T.expectEqual(Progression.rankFor(config, 4).name, "Tiro")
	T.expectEqual(Progression.rankFor(config, 5).name, "Veteranus")
	T.expectEqual(Progression.rankFor(config, 14).name, "Primus Palus")
	T.expectEqual(Progression.rankFor(config, 20).name, "Rudiarius")
end)

T.test("siempre hay un próximo desbloqueo hasta el nivel máximo", function()
	for level = 1, ProgressionConfig.MAX_LEVEL - 1 do
		local nextLevel = Progression.nextUnlock(config, level)
		assert(nextLevel ~= nil and nextLevel > level, `nivel {level} sin próximo desbloqueo`)
	end
	T.expectEqual((Progression.nextUnlock(config, ProgressionConfig.MAX_LEVEL)), nil)
end)

T.test("cada rango tiene su título y todos los títulos de desbloqueo existen", function()
	for _, rank in ProgressionConfig.RANKS do
		assert(Titles[rank.id] ~= nil, `falta el título del rango {rank.id}`)
	end
	for level, unlocks in ProgressionConfig.UNLOCKS do
		for _, unlock in unlocks do
			if unlock.kind == "Title" then
				assert(Titles[unlock.id] ~= nil, `nivel {level}: título {unlock.id} inexistente`)
			end
		end
	end
end)

-- Recompensas -------------------------------------------------------------

T.test("una derrota sin nada más da la experiencia de participar", function()
	local reward = MatchRewards.compute(XP, summary({}))
	T.expectEqual(reward.total, XP.COMPLETE)
end)

T.test("una victoria completa suma todas las partes", function()
	local reward = MatchRewards.compute(
		XP,
		summary({ won = true, phasesCleared = 3, perfectParries = 4, revives = 1, firstWinOfDay = true })
	)
	local expected = XP.COMPLETE + XP.VICTORY + 3 * XP.PER_PHASE + 4 * XP.PER_PARRY + XP.PER_REVIVE + XP.FIRST_WIN_OF_DAY
	T.expectEqual(reward.total, expected)
end)

T.test("las paradas perfectas tienen tope", function()
	local reward = MatchRewards.compute(XP, summary({ perfectParries = 1000 }))
	T.expectEqual(reward.total, XP.COMPLETE + XP.PARRY_CAP)
end)

T.test("la primera victoria del día solo cuenta si se gana", function()
	local reward = MatchRewards.compute(XP, summary({ firstWinOfDay = true }))
	T.expectEqual(reward.total, XP.COMPLETE)
end)

T.test("la Hermandad premia jugar en grupo, con tope", function()
	local two = MatchRewards.compute(XP, summary({ allies = 1 }))
	local many = MatchRewards.compute(XP, summary({ allies = 10 }))
	T.expectEqual(two.total, math.floor(XP.COMPLETE * (1 + XP.BROTHERHOOD_PER_ALLY) + 0.5))
	T.expectEqual(many.total, math.floor(XP.COMPLETE * (1 + XP.BROTHERHOOD_CAP) + 0.5))
end)

T.test("decreto y juegos multiplican; el mentor suma aparte", function()
	local reward = MatchRewards.compute(
		XP,
		summary({ won = true, decreeMultiplier = 1.5, eventMultiplier = 2, mentor = true })
	)
	local base = XP.COMPLETE + XP.VICTORY
	T.expectEqual(reward.total, math.floor(base * 1.5 * 2 + 0.5) + XP.MENTOR)
end)

-- Decretos ---------------------------------------------------------------

T.test("el decreto cambia los lunes a las 00:00 UTC", function()
	-- 2026-11-09 fue lunes: 1 794 182 400 s.
	local monday = 1794182400
	local before = DecreeCalendar.current(monday - 1, #Decrees)
	local after, remaining = DecreeCalendar.current(monday, #Decrees)
	assert(before ~= after, "el decreto debería cambiar el lunes")
	T.expectEqual(remaining, DecreeCalendar.WEEK)
end)

T.test("todo decreto vuelve en un ciclo de semanas", function()
	local seen = {}
	local t = 1794182400
	for week = 0, #Decrees - 1 do
		local index = DecreeCalendar.current(t + week * DecreeCalendar.WEEK, #Decrees)
		seen[index] = true
	end
	for index = 1, #Decrees do
		assert(seen[index], `el decreto {index} no aparece en un ciclo completo`)
	end
end)

T.test("el tiempo restante se muestra legible", function()
	T.expectEqual(DecreeCalendar.formatRemaining(3 * 86400 + 4 * 3600 + 59), "3 d 4 h")
	T.expectEqual(DecreeCalendar.formatRemaining(5 * 3600 + 12 * 60), "5 h 12 min")
	T.expectEqual(DecreeCalendar.formatRemaining(10), "1 min")
end)

T.test("cada decreto tiene un título existente y modificadores positivos", function()
	for _, decree in Decrees do
		assert(Titles[decree.titleId] ~= nil, `{decree.id}: título inexistente`)
		assert(decree.attackIntervalScale > 0 and decree.regrowTimeScale > 0, decree.id)
		assert(decree.damageTakenScale > 0 and decree.xpMultiplier >= 1, decree.id)
	end
end)

-- Códice -----------------------------------------------------------------

T.test("los descubrimientos tienen identificadores únicos y experiencia", function()
	local ids = {}
	for _, discovery in Codex do
		assert(ids[discovery.id] == nil, `id repetido: {discovery.id}`)
		ids[discovery.id] = true
		assert(discovery.xp > 0, discovery.id)
		assert(#discovery.riddle > 0 and #discovery.lesson > 0, discovery.id)
	end
end)

T.finish()
