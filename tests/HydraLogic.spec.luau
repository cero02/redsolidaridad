--!strict
local Config = require("../src/serverOnly/Config/Hydra")
local HydraLogic = require("../src/server/Beasts/HydraLogic")
local T = require("./TestUtil")

T.suite("HydraLogic")

local function context(fields: { [string]: any }): HydraLogic.PatternContext
	local base: { [string]: any } = {
		canBite = true,
		nearCount = 0,
		farCount = 0,
		lastPattern = nil,
		repeatCount = 0,
		phase = 1,
		freeHeads = 3,
		cloudReady = false,
	}
	for key, value in fields do
		base[key] = value
	end
	return base :: any
end

local function sever(hydra: HydraLogic.Hydra, slot: number, now: number)
	T.expectEqual(hydra:damageHead(slot, Config.HEAD_HEALTH, now), "Severed")
end

T.test("empieza con tres cabezas vivas y dos huecos libres", function()
	local hydra = HydraLogic.new(Config)
	T.expectEqual(#hydra:aliveSlots(), 3)
	T.expectEqual(hydra.heads[4].status, "Empty")
	T.expectEqual(hydra.heads[5].status, "Empty")
end)

T.test("el daño parcial no corta la cabeza", function()
	local hydra = HydraLogic.new(Config)
	T.expectEqual(hydra:damageHead(1, 10, 0), "Damaged")
	T.expectEqual(hydra.heads[1].health, Config.HEAD_HEALTH - 10)
end)

T.test("no se puede dañar un hueco vacío ni una cabeza cortada", function()
	local hydra = HydraLogic.new(Config)
	T.expectEqual(hydra:damageHead(4, 50, 0), "Ignored")
	sever(hydra, 1, 0)
	T.expectEqual(hydra:damageHead(1, 50, 0), "Ignored")
	T.expectEqual(hydra:damageHead(2, -5, 0), "Ignored")
end)

T.test("córtale una cabeza y crecerán dos", function()
	local hydra = HydraLogic.new(Config)
	sever(hydra, 1, 0)
	T.expectEqual(#hydra:update(Config.REGROW_TIME - 0.1), 0, "aún no")
	local events = hydra:update(Config.REGROW_TIME)
	T.expectEqual(#events, 1)
	T.expectEqual(events[1].slot, 1)
	T.expectEqual(events[1].newSlot, 4)
	T.expectEqual(#hydra:aliveSlots(), 4)
	T.expectEqual(hydra.heads[1].health, Config.HEAD_HEALTH)
	T.expectEqual(hydra.regrowCount, 1)
end)

T.test("sin huecos libres solo vuelve la cabeza cortada", function()
	local hydra = HydraLogic.new(Config)
	sever(hydra, 1, 0)
	hydra:update(100)
	sever(hydra, 1, 100)
	hydra:update(200)
	T.expectEqual(#hydra:aliveSlots(), 5)
	sever(hydra, 1, 200)
	local events = hydra:update(300)
	T.expectEqual(events[1].newSlot, nil)
	T.expectEqual(#hydra:aliveSlots(), 5)
end)

T.test("un cuello cauterizado no vuelve a crecer", function()
	local hydra = HydraLogic.new(Config)
	sever(hydra, 2, 0)
	T.expectEqual(hydra:cauterize(2), true)
	T.expectEqual(#hydra:update(1000), 0)
	T.expectEqual(hydra.heads[2].status, "Cauterized")
	T.expectEqual(hydra.cauterizedCount, 1)
end)

T.test("solo se cauteriza un cuello cortado", function()
	local hydra = HydraLogic.new(Config)
	T.expectEqual(hydra:cauterize(1), false, "cabeza viva")
	T.expectEqual(hydra:cauterize(4), false, "hueco vacío")
	sever(hydra, 1, 0)
	hydra:cauterize(1)
	T.expectEqual(hydra:cauterize(1), false, "ya cauterizado")
	T.expectEqual(hydra.cauterizedCount, 1)
end)

T.test("la fase se supera al cauterizar los cuellos necesarios", function()
	local hydra = HydraLogic.new(Config)
	for slot = 1, Config.PHASES[1].REQUIRED do
		T.expectEqual(hydra:isPhaseCleared(), false)
		sever(hydra, slot, 0)
		hydra:cauterize(slot)
	end
	T.expectEqual(hydra:isPhaseCleared(), true)
end)

T.test("la segunda fase empieza con cinco cabezas y el contador a cero", function()
	local hydra = HydraLogic.new(Config)
	for slot = 1, 3 do
		sever(hydra, slot, 0)
		hydra:cauterize(slot)
	end
	T.expectEqual(hydra:advancePhase(), true)
	T.expectEqual(hydra.phase, 2)
	T.expectEqual(#hydra:aliveSlots(), Config.PHASES[2].HEADS)
	T.expectEqual(hydra.cauterizedCount, 0)
	T.expectEqual(hydra.requiredCount, Config.PHASES[2].REQUIRED)
	T.expectEqual(hydra:isPhaseCleared(), false)
end)

T.test("tras la última fase de cabezas no hay más fases", function()
	local hydra = HydraLogic.new(Config)
	for _ = 2, #Config.PHASES do
		T.expectEqual(hydra:advancePhase(), true)
	end
	T.expectEqual(hydra:advancePhase(), false)
	T.expectEqual(hydra.phase, #Config.PHASES)
end)

T.test("en la fase 1 nunca usa los ataques de la furia", function()
	local ctx = context({ nearCount = 1, farCount = 1, cloudReady = true })
	for i = 0, 99 do
		local pattern = HydraLogic.choosePattern(ctx, i / 100)
		assert(pattern ~= "Chain" and pattern ~= "Cloud" and pattern ~= "Dive", `eligió {pattern}`)
	end
end)

T.test("en la fase 2 se desbloquean cadena, nube e inmersión", function()
	local weights = HydraLogic.patternWeights(context({ phase = 2, cloudReady = true }))
	assert(weights.Chain > 0 and weights.Cloud > 0 and weights.Dive > 0, "faltan ataques")
end)

T.test("la cadena de mordiscos necesita dos cabezas libres y la nube su recarga", function()
	local weights = HydraLogic.patternWeights(context({ phase = 2, freeHeads = 1, cloudReady = false }))
	T.expectEqual(weights.Chain, 0)
	T.expectEqual(weights.Cloud, 0)
end)

T.test("sin cabeza disponible nunca elige mordisco", function()
	local ctx = context({ canBite = false, nearCount = 1, farCount = 1, lastPattern = nil, repeatCount = 0 })
	for i = 0, 99 do
		assert(HydraLogic.choosePattern(ctx, i / 100) ~= "Bite", "eligió mordisco")
	end
end)

T.test("sin jugadores cerca nunca elige coletazo", function()
	local ctx = context({ canBite = true, nearCount = 0, farCount = 0, lastPattern = nil, repeatCount = 0 })
	for i = 0, 99 do
		assert(HydraLogic.choosePattern(ctx, i / 100) ~= "Tail", "eligió coletazo")
	end
end)

T.test("los jugadores lejanos aumentan el veneno y los cercanos el coletazo", function()
	local base = context({ canBite = true, nearCount = 1, farCount = 0 })
	local far = context({ canBite = true, nearCount = 1, farCount = 3 })
	local near = context({ canBite = true, nearCount = 4, farCount = 0 })
	assert(HydraLogic.patternWeights(far).Spit > HydraLogic.patternWeights(base).Spit, "veneno")
	assert(HydraLogic.patternWeights(near).Tail > HydraLogic.patternWeights(base).Tail, "coletazo")
end)

T.test("nunca repite el mismo ataque tres veces seguidas", function()
	local ctx = context({ canBite = true, nearCount = 1, farCount = 0, lastPattern = "Bite", repeatCount = 2 })
	for i = 0, 99 do
		assert(HydraLogic.choosePattern(ctx, i / 100) ~= "Bite", "repitió mordisco")
	end
end)

T.test("la elección es determinista para la misma tirada", function()
	local ctx = context({ canBite = true, nearCount = 2, farCount = 1, lastPattern = nil, repeatCount = 0 })
	T.expectEqual(HydraLogic.choosePattern(ctx, 0.42), HydraLogic.choosePattern(ctx, 0.42))
end)

T.test("si no hay ningún ataque posible usa el veneno", function()
	local ctx = context({ canBite = false, nearCount = 0, farCount = 0, lastPattern = "Spit", repeatCount = 2 })
	T.expectEqual(HydraLogic.choosePattern(ctx, 0.5), "Spit")
end)

T.test("el objetivo olvidado recibe más atención y el castigado menos", function()
	local candidates = {
		{ timeSinceAttacked = 0, consecutive = 3 },
		{ timeSinceAttacked = 20, consecutive = 0 },
	}
	local counts = { 0, 0 }
	for i = 0, 99 do
		local index = HydraLogic.chooseTarget(candidates, i / 100)
		counts[index] += 1
	end
	assert(counts[2] > counts[1] * 5, `reparto injusto: {counts[1]} / {counts[2]}`)
	assert(counts[1] > 0, "el castigado aún puede ser objetivo")
end)

T.test("con un solo candidato siempre lo elige", function()
	T.expectEqual(HydraLogic.chooseTarget({ { timeSinceAttacked = 0, consecutive = 9 } }, 0.99), 1)
end)

T.finish()
