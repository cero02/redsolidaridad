--!strict
local Lifecycle = require("../src/shared/Util/Lifecycle")
local T = require("./TestUtil")

T.suite("Lifecycle")

local function immediate(fn: () -> ())
	fn()
end

T.test("llama a todos los Init antes que a cualquier Start", function()
	local order = {}
	local modules = {
		B = {
			Init = function()
				table.insert(order, "B.Init")
			end,
			Start = function()
				table.insert(order, "B.Start")
			end,
		},
		A = {
			Init = function()
				table.insert(order, "A.Init")
			end,
			Start = function()
				table.insert(order, "A.Start")
			end,
		},
	}
	Lifecycle.run(modules, { spawn = immediate })
	T.expectEqual(table.concat(order, ","), "A.Init,B.Init,A.Start,B.Start", "orden")
end)

T.test("un Init que cede (yield) se informa y ese módulo no arranca", function()
	local started = false
	local reported: string? = nil
	local failed = Lifecycle.run({
		Lento = {
			Init = function()
				coroutine.yield()
			end,
			Start = function()
				started = true
			end,
		},
	}, {
		spawn = immediate,
		onInitError = function(_name: string, err: string)
			reported = err
		end,
	})
	T.expectEqual(started, false)
	T.expectEqual(failed[1], "Lento")
	assert(reported and string.find(reported, "cedió", 1, true), "debe explicar que cedió")
end)

T.test("un error en Init no impide arrancar a los demás", function()
	local otherStarted = false
	local reported: string? = nil
	local failed = Lifecycle.run({
		Roto = {
			Init = function()
				error("fallo")
			end,
		},
		Sano = {
			Start = function()
				otherStarted = true
			end,
		},
	}, {
		spawn = immediate,
		onInitError = function(name: string)
			reported = name
		end,
	})
	T.expectEqual(reported, "Roto")
	T.expectEqual(otherStarted, true)
	T.expectEqual(#failed, 1)
end)

T.test("un error en Start no impide arrancar los demás", function()
	local started = false
	local reported: string? = nil
	Lifecycle.run({
		A = {
			Start = function()
				error("boom")
			end,
		},
		B = {
			Start = function()
				started = true
			end,
		},
	}, {
		spawn = immediate,
		onStartError = function(name: string)
			reported = name
		end,
	})
	T.expectEqual(started, true, "B arrancó")
	T.expectEqual(reported, "A", "error informado")
end)

T.test("módulos sin Init ni Start son válidos", function()
	Lifecycle.run({ Vacio = {} }, { spawn = immediate })
end)

T.finish()
