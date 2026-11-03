--!strict
-- Esquema del perfil guardado de cada jugador (versión actual: SCHEMA_VERSION).
-- Reglas de ProfileStore: sin Instances, sin userdata (Vector3, CFrame…), sin funciones,
-- sin tablas mixtas ni listas con huecos. Para cambios: subir la versión y añadir una
-- migración en Migrations.luau. Diseño: docs/design/PROGRESION.md.

local SCHEMA_VERSION = 1

export type Stats = {
	matchesPlayed: number,
	matchesWon: number,
	hydraKills: number,
	perfectParries: number,
	revives: number,
	headsSevered: number,
}

export type Loadout = {
	weapon: string,
	essence: string,
}

export type ProfileData = {
	schemaVersion: number,
	level: number,
	xp: number,
	stats: Stats,
	-- Diccionarios id -> true (no listas, para poder añadir sin huecos).
	unlockedWeapons: { [string]: boolean },
	unlockedEssences: { [string]: boolean },
	unlockedCosmetics: { [string]: boolean },
	loadout: Loadout,
	settings: {
		damageNumbers: boolean,
	},
}

-- Lo que el cliente puede ver de su propio perfil.
export type PublicProfile = {
	level: number,
	xp: number,
	loadout: Loadout,
}

local Schema = {}

Schema.VERSION = SCHEMA_VERSION

Schema.template = table.freeze({
	schemaVersion = SCHEMA_VERSION,
	level = 1,
	xp = 0,
	stats = table.freeze({
		matchesPlayed = 0,
		matchesWon = 0,
		hydraKills = 0,
		perfectParries = 0,
		revives = 0,
		headsSevered = 0,
	}),
	unlockedWeapons = table.freeze({ Gladius = true }),
	unlockedEssences = table.freeze({ Loba = true }),
	unlockedCosmetics = table.freeze({}),
	loadout = table.freeze({ weapon = "Gladius", essence = "Loba" }),
	settings = table.freeze({ damageNumbers = true }),
}) :: ProfileData

function Schema.toPublic(data: ProfileData): PublicProfile
	return {
		level = data.level,
		xp = data.xp,
		loadout = { weapon = data.loadout.weapon, essence = data.loadout.essence },
	}
end

return Schema
