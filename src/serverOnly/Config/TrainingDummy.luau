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
})
