--!strict
local RateLimiter = require("../src/shared/Util/RateLimiter")
local T = require("./TestUtil")

T.suite("RateLimiter")

local now = 0
local function clock()
	return now
end

T.test("permite la ráfaga y después bloquea", function()
	now = 0
	local limiter = RateLimiter.new(3, 1, clock)
	T.expectEqual(limiter:consume("p"), true)
	T.expectEqual(limiter:consume("p"), true)
	T.expectEqual(limiter:consume("p"), true)
	T.expectEqual(limiter:consume("p"), false, "cuarta petición")
end)

T.test("recupera fichas con el tiempo", function()
	now = 0
	local limiter = RateLimiter.new(1, 2, clock)
	T.expectEqual(limiter:consume("p"), true)
	T.expectEqual(limiter:consume("p"), false)
	now = 0.5
	T.expectEqual(limiter:consume("p"), true, "tras 0,5 s a 2/s")
end)

T.test("no supera la capacidad aunque pase mucho tiempo", function()
	now = 0
	local limiter = RateLimiter.new(2, 1, clock)
	limiter:consume("p")
	now = 1000
	T.expectEqual(limiter:consume("p"), true)
	T.expectEqual(limiter:consume("p"), true)
	T.expectEqual(limiter:consume("p"), false)
end)

T.test("cada clave tiene su propio límite", function()
	now = 0
	local limiter = RateLimiter.new(1, 1, clock)
	T.expectEqual(limiter:consume("a"), true)
	T.expectEqual(limiter:consume("b"), true)
	T.expectEqual(limiter:consume("a"), false)
end)

T.test("remove reinicia la clave", function()
	now = 0
	local limiter = RateLimiter.new(1, 1, clock)
	limiter:consume("a")
	limiter:remove("a")
	T.expectEqual(limiter:consume("a"), true)
end)

T.test("un reloj que retrocede no regala fichas", function()
	now = 10
	local limiter = RateLimiter.new(1, 1, clock)
	limiter:consume("a")
	now = 5
	T.expectEqual(limiter:consume("a"), false)
end)

T.finish()
