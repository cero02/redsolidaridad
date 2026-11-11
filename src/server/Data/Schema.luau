--!strict
-- Esquema del perfil guardado de cada jugador (versión actual: SCHEMA_VERSION).
-- Reglas de ProfileStore: sin Instances, sin userdata (Vector3, CFrame…), sin funciones,
-- sin tablas mixtas ni listas con huecos. Para cambios: subir la versión y añadir una
-- migración en Migrations.luau. Diseño: docs/design/PROGRESION.md.

local SCHEMA_VERSION = 2

export type Stats = {
	matchesPlayed: number,
	matchesWon: number,
	hydraKills: number,
	perfectParries: number,
	revives: number,
	headsSevered: number,
	-- Mejor tiempo contra la Hidra en segundos (0 = aún sin victoria).
	bestHydraTime: number,
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
	-- v2: títulos, códice y decretos (docs/design/PILARES.md).
	unlockedTitles: { [string]: boolean },
	equippedTitle: string,
	codex: { [string]: boolean },
	-- Día (UTC, días desde 1970) de la última victoria: para el bonus diario.
	lastWinDay: number,
	-- Victorias por decreto (id -> número).
	decreeWins: { [string]: number },
}

-- Lo que el cliente puede ver de su propio perfil.
export type PublicProfile = {
	level: number,
	xp: number,
	loadout: Loadout,
	equippedTitle: string,
	unlockedTitles: { string },
	codex: { string },
	bestHydraTime: number,
	hydraKills: number,
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
		bestHydraTime = 0,
	}),
	unlockedWeapons = table.freeze({ Gladius = true }),
	unlockedEssences = table.freeze({ Loba = true }),
	unlockedCosmetics = table.freeze({}),
	loadout = table.freeze({ weapon = "Gladius", essence = "Loba" }),
	settings = table.freeze({ damageNumbers = true }),
	unlockedTitles = table.freeze({ Tiro = true }),
	equippedTitle = "Tiro",
	codex = table.freeze({}),
	lastWinDay = 0,
	decreeWins = table.freeze({}),
}) :: ProfileData

local function keys(set: { [string]: boolean }): { string }
	local list = {}
	for key, value in set do
		if value then
			table.insert(list, key)
		end
	end
	table.sort(list)
	return list
end

function Schema.toPublic(data: ProfileData): PublicProfile
	return {
		level = data.level,
		xp = data.xp,
		loadout = { weapon = data.loadout.weapon, essence = data.loadout.essence },
		equippedTitle = data.equippedTitle,
		unlockedTitles = keys(data.unlockedTitles),
		codex = keys(data.codex),
		bestHydraTime = data.stats.bestHydraTime,
		hydraKills = data.stats.hydraKills,
	}
end

return Schema
