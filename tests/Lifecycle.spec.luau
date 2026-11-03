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

T.test("un Init que cede (yield) detiene el arranque", function()
	local modules = {
		Lento = {
			Init = function()
				coroutine.yield()
			end,
		},
	}
	T.expectError(function()
		Lifecycle.run(modules, { spawn = immediate })
	end, "cedió")
end)

T.test("un error en Init detiene el arranque", function()
	T.expectError(function()
		Lifecycle.run({
			Roto = {
				Init = function()
					error("fallo")
				end,
			},
		}, { spawn = immediate })
	end, "Init de Roto")
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
