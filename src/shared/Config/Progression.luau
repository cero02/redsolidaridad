--!strict
-- Progresión: experiencia, niveles, rangos y desbloqueos (los textos, en Shared/Locale). Diseño: docs/design/PROGRESION.md
-- y docs/design/PILARES.md. Valores iniciales para equilibrar.

-- El texto de cada desbloqueo está en los idiomas (Shared/Locale): ver Progression.unlockRef.
export type Unlock = {
	kind: "Weapon" | "Essence" | "Cosmetic" | "Title" | "Feature",
	id: string,
}

export type Rank = { minLevel: number, id: string }

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
		table.freeze({ minLevel = 1, id = "Tiro" }),
		table.freeze({ minLevel = 5, id = "Veteranus" }),
		table.freeze({ minLevel = 10, id = "PrimusPalus" }),
		table.freeze({ minLevel = 15, id = "Campeon" }),
		table.freeze({ minLevel = 20, id = "Rudiarius" }),
	}) :: { Rank },

	-- Lo que se desbloquea al ALCANZAR cada nivel.
	UNLOCKS = table.freeze({
		[2] = { { kind = "Weapon", id = "Hasta" } },
		[3] = { { kind = "Cosmetic", id = "ShieldEmblem" } },
		[4] = { { kind = "Weapon", id = "Martillo" } },
		[5] = {
			{ kind = "Essence", id = "Aguila" },
			{ kind = "Title", id = "Veteranus" },
		},
		[6] = { { kind = "Cosmetic", id = "BronzeHelmet" } },
		[8] = { { kind = "Feature", id = "Heroic" } },
		[10] = {
			{ kind = "Cosmetic", id = "RedCape" },
			{ kind = "Title", id = "PrimusPalus" },
		},
		[12] = { { kind = "Cosmetic", id = "Plume" } },
		[15] = {
			{ kind = "Cosmetic", id = "ChampionArmor" },
			{ kind = "Title", id = "Campeon" },
		},
		[18] = { { kind = "Cosmetic", id = "EmberBlade" } },
		[20] = {
			{ kind = "Cosmetic", id = "RudisSword" },
			{ kind = "Title", id = "Rudiarius" },
		},
	}) :: { [number]: { Unlock } },
})
