--!strict
local Homing = require("../src/server/Beasts/Homing")
local T = require("./TestUtil")

T.suite("Homing")

local function near(a: number, b: number, message: string)
	assert(math.abs(a - b) < 1e-6, `{message}: {a} ≠ {b}`)
end

local FORWARD = { x = 0, y = 0, z = -1 }
local RIGHT = { x = 1, y = 0, z = 0 }
local BACK = { x = 0, y = 0, z = 1 }

T.test("si el giro cabe en el máximo, apunta directamente al objetivo", function()
	local result = Homing.steer(FORWARD, { x = 0.1, y = 0, z = -1 }, math.rad(30))
	near(Homing.angleBetween(result, { x = 0.1, y = 0, z = -1 }), 0, "ángulo")
end)

T.test("nunca gira más del ángulo máximo por paso", function()
	local maxAngle = math.rad(10)
	local result = Homing.steer(FORWARD, RIGHT, maxAngle)
	near(Homing.angleBetween(FORWARD, result), maxAngle, "giro")
	assert(result.x > 0, "debe girar hacia el objetivo")
end)

T.test("el resultado siempre es unitario", function()
	local result = Homing.steer({ x = 3, y = 4, z = 0 }, { x = 0, y = 0, z = 9 }, math.rad(25))
	near(math.sqrt(result.x ^ 2 + result.y ^ 2 + result.z ^ 2), 1, "longitud")
end)

T.test("con el objetivo justo detrás también gira (sin quedarse atascado)", function()
	local result = Homing.steer(FORWARD, BACK, math.rad(20))
	near(Homing.angleBetween(FORWARD, result), math.rad(20), "giro")
end)

T.test("girando paso a paso acaba alcanzando la dirección deseada", function()
	local direction = FORWARD
	for _ = 1, 20 do
		direction = Homing.steer(direction, RIGHT, math.rad(10))
	end
	near(Homing.angleBetween(direction, RIGHT), 0, "alineado")
end)

T.test("con giro lento, un objetivo que cambia de lado a tiempo no es alcanzado de golpe", function()
	-- 80°/s durante un fotograma de 1/60 s: apenas 1,3° de giro.
	local result = Homing.steer(FORWARD, RIGHT, math.rad(80) / 60)
	assert(Homing.angleBetween(result, RIGHT) > math.rad(85), "giró demasiado rápido")
end)

T.finish()
