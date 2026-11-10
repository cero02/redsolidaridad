--!strict
-- Gran Coliseo (versión de bloques, hito 1.2). Posiciones como {x, y, z}.

return table.freeze({
	-- Centro de la arena, lejos del punto de aparición.
	CENTER = table.freeze({ 0, 0, -200 }),
	-- Altura de la superficie de la arena.
	FLOOR_Y = 1,
	RADIUS = 60,
	POND_RADIUS = 14,
	BRAZIER_RADIUS = 46,
	WALL_HEIGHT = 12,
	-- Distancia del centro a la que aparecen los gladiadores.
	ENTRY_DISTANCE = 48,

	-- Puerta del foro (zona de inicio) para entrar al coliseo.
	LOBBY_GATE = table.freeze({ 16, 0, -8 }),
	-- Dónde vuelven los jugadores al terminar.
	LOBBY_RETURN = table.freeze({ 0, 6, 10 }),

	CROWD_SIZE = 220,
})
