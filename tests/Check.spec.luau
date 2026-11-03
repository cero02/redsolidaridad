--!strict
local Check = require("../src/shared/Net/Check")
local Guard = require("../src/shared/Net/Guard")
local RateLimiter = require("../src/shared/Util/RateLimiter")
local T = require("./TestUtil")

T.suite("Check y Guard")

T.test("number rechaza NaN, infinito y tipos incorrectos", function()
	local v = Check.number()
	T.expectEqual((v(0 / 0)), false, "NaN")
	T.expectEqual((v(math.huge)), false, "inf")
	T.expectEqual((v(-math.huge)), false, "-inf")
	T.expectEqual((v("5")), false, "texto")
	T.expectEqual((v(nil)), false, "nil")
	T.expectEqual((v(5)), true)
end)

T.test("number aplica min, max y entero", function()
	local v = Check.number({ min = 1, max = 3, integer = true })
	T.expectEqual((v(0)), false)
	T.expectEqual((v(4)), false)
	T.expectEqual((v(2.5)), false)
	T.expectEqual((v(2)), true)
end)

T.test("string limita la longitud", function()
	local v = Check.string(4)
	T.expectEqual((v("hola")), true)
	T.expectEqual((v("hola!")), false)
	T.expectEqual((v(1)), false)
end)

T.test("oneOf solo acepta valores de la lista", function()
	local v = Check.oneOf({ "Light", "Heavy" })
	T.expectEqual((v("Light")), true)
	T.expectEqual((v("Ultimate")), false)
	T.expectEqual((v(1)), false)
end)

T.test("optional acepta nil", function()
	local v = Check.optional(Check.boolean())
	T.expectEqual((v(nil)), true)
	T.expectEqual((v(true)), true)
	T.expectEqual((v("true")), false)
end)

T.test("args rechaza argumentos de más", function()
	local ok = Check.args({ Check.boolean() }, 2, { true, true })
	T.expectEqual(ok, false)
end)

T.test("args rechaza argumentos de más aunque sean nil al final", function()
	-- select("#") cuenta los nil: el cliente no puede colar argumentos extra.
	local ok = Check.args({}, 1, {})
	T.expectEqual(ok, false)
end)

T.test("args valida cada argumento en orden", function()
	local validators = { Check.oneOf({ "Light" }), Check.number({ min = 1, max = 3 }) }
	T.expectEqual((Check.args(validators, 2, { "Light", 2 })), true)
	local ok, reason = Check.args(validators, 2, { "Light", 9 })
	T.expectEqual(ok, false)
	T.expectEqual(string.find(reason or "", "argumento 2", 1, true) ~= nil, true, "motivo")
end)

T.test("Guard aplica primero el límite de peticiones", function()
	local now = 0
	local limiter = RateLimiter.new(1, 1, function()
		return now
	end)
	local validators = { Check.boolean() }
	T.expectEqual((Guard.check(validators, limiter, Check.args, "p", 1, { true })), true)
	local ok, reason = Guard.check(validators, limiter, Check.args, "p", 1, { true })
	T.expectEqual(ok, false)
	T.expectEqual(reason, "límite de peticiones superado")
end)

T.test("Guard rechaza argumentos inválidos", function()
	local limiter = RateLimiter.new(5, 1)
	local ok = Guard.check({ Check.boolean() }, limiter, Check.args, "p", 1, { "x" })
	T.expectEqual(ok, false)
end)

T.finish()
