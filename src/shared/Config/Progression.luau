--!strict
-- Progresión: experiencia, niveles, rangos y desbloqueos. Diseño: docs/design/PROGRESION.md
-- y docs/design/PILARES.md. Valores iniciales para equilibrar.

export type Unlock = {
	kind: "Weapon" | "Essence" | "Cosmetic" | "Title" | "Feature",
	id: string,
	name: string,
}

export type Rank = { minLevel: number, id: string, name: string }

return table.freeze({
	MAX_LEVEL = 20,
	-- Experiencia para pasar del nivel n al n+1: BASE + STEP × (n − 1).
	XP_BASE = 100,
	XP_STEP = 50,

	-- Experiencia de cada partida.
	XP = table.freeze({
		COMPLETE = 50,
		VICTORY = 100,
		PER_PHASE = 25,
		PER_PARRY = 2,
		PARRY_CAP = 30,
		PER_REVIVE = 15,
		FIRST_WIN_OF_DAY = 100,
		-- Bonus de Hermandad por cada aliado en la partida, con tope.
		BROTHERHOOD_PER_ALLY = 0.15,
		BROTHERHOOD_CAP = 0.45,
		-- Un veterano que lucha junto a un novato recibe este extra.
		MENTOR = 50,
		MENTOR_MIN_LEVEL = 8,
		NOVICE_MAX_LEVEL = 3,
	}),

	RANKS = table.freeze({
		table.freeze({ minLevel = 1, id = "Tiro", name = "Tiro" }),
		table.freeze({ minLevel = 5, id = "Veteranus", name = "Veteranus" }),
		table.freeze({ minLevel = 10, id = "PrimusPalus", name = "Primus Palus" }),
		table.freeze({ minLevel = 15, id = "Campeon", name = "Campeón" }),
		table.freeze({ minLevel = 20, id = "Rudiarius", name = "Rudiarius" }),
	}) :: { Rank },

	-- Lo que se desbloquea al ALCANZAR cada nivel.
	UNLOCKS = table.freeze({
		[2] = { { kind = "Weapon", id = "Hasta", name = "Hasta (lanza)" } },
		[3] = { { kind = "Cosmetic", id = "ShieldEmblem", name = "Emblema del águila en el escudo" } },
		[4] = { { kind = "Weapon", id = "Martillo", name = "Martillo del Coloso" } },
		[5] = {
			{ kind = "Essence", id = "Aguila", name = "Esencia del Águila imperial" },
			{ kind = "Title", id = "Veteranus", name = "Título: Veteranus" },
		},
		[6] = { { kind = "Cosmetic", id = "BronzeHelmet", name = "Casco de bronce" } },
		[8] = { { kind = "Feature", id = "Heroic", name = "Dificultad Heroica (próximamente)" } },
		[10] = {
			{ kind = "Cosmetic", id = "RedCape", name = "Capa roja" },
			{ kind = "Title", id = "PrimusPalus", name = "Título: Primus Palus" },
		},
		[12] = { { kind = "Cosmetic", id = "Plume", name = "Penacho de campeón" } },
		[15] = {
			{ kind = "Cosmetic", id = "ChampionArmor", name = "Armadura de campeón" },
			{ kind = "Title", id = "Campeon", name = "Título: Campeón" },
		},
		[18] = { { kind = "Cosmetic", id = "EmberBlade", name = "Hoja en brasas" } },
		[20] = {
			{ kind = "Cosmetic", id = "RudisSword", name = "Rudis: la espada de madera de los libres" },
			{ kind = "Title", id = "Rudiarius", name = "Título: Rudiarius" },
		},
	}) :: { [number]: { Unlock } },
})
