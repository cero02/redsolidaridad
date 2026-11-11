--!strict
-- Muñeco de entrenamiento del hito 1.1. Valores de prueba.

return table.freeze({
	HEALTH = 200,
	RESPAWN_TIME = 3,
	-- Posición en el mundo (x, y, z). Pensada para la Baseplate por defecto de Studio.
	POSITION = table.freeze({ 0, 3, -20 }),

	-- El muñeco ataca para poder practicar esquiva, bloqueo y parada perfecta.
	ATTACK_INTERVAL = 4,
	TELEGRAPH_TIME = 1.0,
	ATTACK_DAMAGE = 15,
	ATTACK_RANGE = 9,

	-- Bola de fuego de práctica: la lanza a quien esté cerca pero fuera del alcance del
	-- golpe, para aprender a esquivarla o a devolverla con una parada perfecta.
	FIREBALL = table.freeze({
		RANGE = 45,
		TELEGRAPH = 1.0,
		SPEED = 22,
		-- Giro máximo en grados por segundo.
		TURN_RATE = 80,
		LIFETIME = 6,
		RADIUS = 2.6,
		HEIGHT = 3.5,
		DAMAGE = 10,
		REFLECT_SPEED = 60,
		REFLECT_DAMAGE = 30,
		REFLECT_STUN = 2,
	}),
})
