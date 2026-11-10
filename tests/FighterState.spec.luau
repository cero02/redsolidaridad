--!strict
local Combat = require("../src/shared/Config/Combat")
local FighterState = require("../src/shared/Combat/FighterState")
local T = require("./TestUtil")
local Weapons = require("../src/shared/Config/Weapons")

T.suite("FighterState")

local gladius = Weapons.Gladius

local function newFighter(t: number?)
	return FighterState.new(gladius, Combat, t or 0)
end

local function attackDuration(a: any): number
	return a.windup + a.active + a.recovery
end

T.test("empieza con vida y aguante al máximo", function()
	local f = newFighter()
	T.expectEqual(f.health, Combat.MAX_HEALTH)
	T.expectEqual(f.stamina, Combat.MAX_STAMINA)
	T.expectEqual(f.ultimate, 0)
end)

T.test("el combo ligero avanza 1-2-3 y vuelve a 1", function()
	local f = newFighter()
	local t = 0
	local steps = {}
	for _ = 1, 4 do
		local plan = f:tryAttack("Light", t)
		assert(plan, "ataque rechazado")
		table.insert(steps, plan.step)
		t += attackDuration(plan.attack)
	end
	T.expectEqual(table.concat(steps, ","), "1,2,3,1")
end)

T.test("el combo se reinicia si pasa demasiado tiempo", function()
	local f = newFighter()
	local plan = f:tryAttack("Light", 0)
	assert(plan, "ataque rechazado")
	local nextT = attackDuration(plan.attack) + Combat.COMBO_RESET + 0.01
	local second = f:tryAttack("Light", nextT)
	assert(second, "ataque rechazado")
	T.expectEqual(second.step, 1)
end)

T.test("no se puede atacar durante otro ataque (más allá del margen)", function()
	local f = newFighter()
	assert(f:tryAttack("Light", 0), "ataque rechazado")
	local plan, reason = f:tryAttack("Light", 0.05)
	T.expectEqual(plan, nil)
	T.expectEqual(reason, "ocupado")
end)

T.test("el margen de latencia acepta una petición que llega un poco antes", function()
	local f = newFighter()
	local first = f:tryAttack("Light", 0)
	assert(first, "ataque rechazado")
	local endsAt = attackDuration(first.attack)
	local plan = f:tryAttack("Light", endsAt - Combat.ACTION_LATENCY_GRACE / 2)
	assert(plan, "debería aceptarse dentro del margen")
end)

T.test("el ataque pesado usa el golpe pesado del arma", function()
	local f = newFighter()
	local plan = f:tryAttack("Heavy", 0)
	assert(plan, "ataque rechazado")
	T.expectEqual(plan.kind, "Heavy")
	T.expectEqual(plan.attack.damage, gladius.heavy.damage)
end)

T.test("esquivar gasta aguante y tiene recarga", function()
	local f = newFighter()
	T.expectEqual((f:tryDodge(0)), true)
	T.expectEqual(f.stamina, Combat.MAX_STAMINA - gladius.dodgeCost)
	local ok, reason = f:tryDodge(0.1)
	T.expectEqual(ok, false)
	T.expectEqual(reason, "recarga")
end)

T.test("sin aguante no se puede esquivar", function()
	local f = newFighter()
	local t = 0
	local dodges = 0
	while f:tryDodge(t) do
		dodges += 1
		t += Combat.DODGE_COOLDOWN
	end
	T.expectEqual(dodges, 4, "100 de aguante / 25 por esquiva")
	local _, reason = f:tryDodge(t)
	T.expectEqual(reason, "sin aguante")
end)

T.test("el aguante se recupera tras el retraso", function()
	local f = newFighter()
	f:tryDodge(0)
	local before = f:snapshot(Combat.STAMINA_REGEN_DELAY).stamina
	T.expectEqual(before, Combat.MAX_STAMINA - gladius.dodgeCost, "aún sin recuperar")
	local after = f:snapshot(Combat.STAMINA_REGEN_DELAY + 0.5).stamina
	T.expectEqual(after, before + 0.5 * Combat.STAMINA_REGEN_PER_SECOND)
	T.expectEqual(f:snapshot(100).stamina, Combat.MAX_STAMINA, "no supera el máximo")
end)

T.test("un golpe sin defensa quita la vida completa del daño", function()
	local f = newFighter()
	local outcome = f:receiveHit(15, 1, 1.2)
	T.expectEqual(outcome.result, "Hit")
	T.expectEqual(f.health, Combat.MAX_HEALTH - 15)
end)

T.test("esquivar justo antes del impacto evita el daño y es ajustada", function()
	local f = newFighter()
	f:tryDodge(0.9)
	local outcome = f:receiveHit(15, 1, 1.2)
	T.expectEqual(outcome.result, "Dodged")
	T.expectEqual(outcome.closeDodge, true)
	T.expectEqual(f.health, Combat.MAX_HEALTH)
	T.expectEqual(f.ultimate, Combat.ULTIMATE_PER_CLOSE_DODGE)
end)

T.test("esquivar justo después del impacto, dentro del margen de latencia, cuenta", function()
	local f = newFighter()
	f:tryDodge(1 + Combat.DEFENSE_LATENCY_GRACE - 0.01)
	T.expectEqual(f:receiveHit(15, 1, 1.2).result, "Dodged")
end)

T.test("esquivar demasiado pronto no protege", function()
	local f = newFighter()
	f:tryDodge(0)
	T.expectEqual(f:receiveHit(15, 1, 1.2).result, "Hit")
end)

T.test("bloquear justo a tiempo es parada perfecta", function()
	local f = newFighter()
	f:setBlocking(true, 0.9)
	local outcome = f:receiveHit(15, 1, 1.2)
	T.expectEqual(outcome.result, "Parried")
	T.expectEqual(f.health, Combat.MAX_HEALTH)
	T.expectEqual(f.ultimate, Combat.ULTIMATE_PER_PARRY)
end)

T.test("bloquear con antelación reduce el daño y gasta aguante", function()
	local f = newFighter()
	f:setBlocking(true, 0)
	local outcome = f:receiveHit(20, 1, 1.2)
	T.expectEqual(outcome.result, "Blocked")
	T.expectEqual(outcome.damageTaken, 20 * (1 - gladius.blockReduction))
	T.expectEqual(f.stamina, Combat.MAX_STAMINA - Combat.BLOCK_STAMINA_PER_HIT)
end)

T.test("sin aguante la guardia se rompe y entra todo el daño", function()
	local f = newFighter()
	f:setBlocking(true, 0)
	local t = 1
	-- Agota el aguante bloqueando golpes seguidos (sin tiempo para recuperarse).
	for _ = 1, 5 do
		f:receiveHit(1, t, t)
		t += 0.01
	end
	local outcome = f:receiveHit(20, t, t)
	T.expectEqual(outcome.result, "GuardBroken")
	T.expectEqual(f.blocking, false)
end)

T.test("aturdido no puede atacar ni esquivar", function()
	local f = newFighter()
	f:stun(1, 0)
	T.expectEqual((f:tryAttack("Light", 0.5)), nil)
	T.expectEqual((f:tryDodge(0.5)), false)
	assert(f:tryAttack("Light", 1.01), "tras el aturdimiento puede atacar")
end)

T.test("hacer daño carga la definitiva sin pasar del máximo", function()
	local f = newFighter()
	f:addDamageDealt(100)
	T.expectEqual(f.ultimate, 100 * Combat.ULTIMATE_PER_DAMAGE)
	f:addDamageDealt(100000)
	T.expectEqual(f.ultimate, Combat.ULTIMATE_MAX)
end)

T.test("la vida no baja de 0 y un luchador caído no actúa", function()
	local f = newFighter()
	f:receiveHit(1000, 1, 1.2)
	T.expectEqual(f.health, 0)
	T.expectEqual(f:isDead(), true)
	T.expectEqual((f:tryAttack("Light", 2)), nil)
end)

T.test("applySnapshot sustituye la predicción por el estado del servidor", function()
	local f = newFighter()
	f:applySnapshot({ health = 40, stamina = 10, ultimate = 55, blocking = true }, 5)
	local s = f:snapshot(5)
	T.expectEqual(s.health, 40)
	T.expectEqual(s.stamina, 10)
	T.expectEqual(s.ultimate, 55)
	T.expectEqual(s.blocking, true)
end)

T.test("todas las armas tienen ataques con tiempos y daños positivos", function()
	for id, weapon in Weapons do
		assert(#weapon.light >= 1, `{id}: sin ataques ligeros`)
		for i, a in weapon.light do
			assert(a.damage > 0 and a.windup >= 0 and a.recovery > 0, `{id} ligero {i}`)
		end
		assert(weapon.heavy.damage > 0, `{id}: pesado sin daño`)
		assert(weapon.blockReduction > 0 and weapon.blockReduction < 1, `{id}: blockReduction`)
	end
end)

T.test("takeDamage ignora esquiva y bloqueo y no baja de 0", function()
	local f = newFighter()
	f:setBlocking(true, 0)
	f:tryDodge(0)
	f:takeDamage(30)
	T.expectEqual(f.health, Combat.MAX_HEALTH - 30)
	f:takeDamage(-50)
	T.expectEqual(f.health, Combat.MAX_HEALTH - 30, "el daño negativo no cura")
	f:takeDamage(1000)
	T.expectEqual(f.health, 0)
end)

T.finish()
