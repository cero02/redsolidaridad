--!strict
-- Guiado de proyectiles: gira una dirección hacia el objetivo sin superar un ángulo máximo
-- por paso. Así una bola de fuego persigue al jugador pero se puede esquivar cambiando de
-- rumbo a tiempo. Módulo puro (vectores como x, y, z) para probarlo con Lune.

export type Vec = { x: number, y: number, z: number }

local Homing = {}

local function length(v: Vec): number
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

function Homing.normalize(v: Vec): Vec
	local len = length(v)
	if len < 1e-9 then
		return { x = 0, y = 0, z = -1 }
	end
	return { x = v.x / len, y = v.y / len, z = v.z / len }
end

local function dot(a: Vec, b: Vec): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end

local function cross(a: Vec, b: Vec): Vec
	return {
		x = a.y * b.z - a.z * b.y,
		y = a.z * b.x - a.x * b.z,
		z = a.x * b.y - a.y * b.x,
	}
end

-- Ángulo en radianes entre dos direcciones.
function Homing.angleBetween(a: Vec, b: Vec): number
	return math.acos(math.clamp(dot(Homing.normalize(a), Homing.normalize(b)), -1, 1))
end

-- Gira `current` hacia `desired` como mucho `maxAngle` radianes. Devuelve una dirección
-- unitaria. Si el giro necesario es menor que maxAngle, devuelve `desired` directamente.
function Homing.steer(current: Vec, desired: Vec, maxAngle: number): Vec
	local from = Homing.normalize(current)
	local to = Homing.normalize(desired)
	local angle = math.acos(math.clamp(dot(from, to), -1, 1))
	if angle <= maxAngle or angle < 1e-6 then
		return to
	end

	local sinAngle = math.sin(angle)
	if sinAngle < 1e-6 then
		-- Direcciones opuestas: se gira sobre un eje perpendicular cualquiera.
		local axis = cross(from, { x = 0, y = 1, z = 0 })
		if length(axis) < 1e-6 then
			axis = cross(from, { x = 1, y = 0, z = 0 })
		end
		axis = Homing.normalize(axis)
		local perpendicular = Homing.normalize(cross(axis, from))
		local c, s = math.cos(maxAngle), math.sin(maxAngle)
		return Homing.normalize({
			x = from.x * c + perpendicular.x * s,
			y = from.y * c + perpendicular.y * s,
			z = from.z * c + perpendicular.z * s,
		})
	end

	-- Interpolación esférica: avanza exactamente maxAngle sobre el arco.
	local t = maxAngle / angle
	local a = math.sin((1 - t) * angle) / sinAngle
	local b = math.sin(t * angle) / sinAngle
	return Homing.normalize({
		x = from.x * a + to.x * b,
		y = from.y * a + to.y * b,
		z = from.z * a + to.z * b,
	})
end

return Homing
