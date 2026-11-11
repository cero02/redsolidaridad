--!strict
local Migrations = require("../src/server/Data/Migrations")
local Schema = require("../src/server/Data/Schema")
local T = require("./TestUtil")

T.suite("Schema y Migrations")

T.test("el template tiene la versión actual del esquema", function()
	T.expectEqual(Schema.template.schemaVersion, Schema.VERSION)
end)

T.test("el template empieza con Gladius y Loba desbloqueados y equipados", function()
	T.expectEqual(Schema.template.unlockedWeapons.Gladius, true)
	T.expectEqual(Schema.template.unlockedEssences.Loba, true)
	T.expectEqual(Schema.template.loadout.weapon, "Gladius")
	T.expectEqual(Schema.template.loadout.essence, "Loba")
end)

T.test("el template no contiene tipos que ProfileStore no puede guardar", function()
	local function walk(value: any, path: string)
		local kind = type(value)
		assert(
			kind == "table" or kind == "string" or kind == "number" or kind == "boolean",
			`{path}: tipo no guardable ({kind})`
		)
		if kind == "table" then
			for key, child in value do
				assert(type(key) == "string", `{path}: clave no textual`)
				walk(child, `{path}.{key}`)
			end
		end
	end
	walk(Schema.template, "template")
end)

T.test("toPublic solo expone datos públicos", function()
	local public = Schema.toPublic(Schema.template)
	local keys = {}
	for key in public :: any do
		table.insert(keys, key)
	end
	table.sort(keys)
	T.expectEqual(
		table.concat(keys, ","),
		"bestHydraTime,codex,equippedTitle,hydraKills,level,loadout,unlockedTitles,xp"
	)
end)

T.test("sin migraciones pendientes no cambia nada", function()
	local data = { schemaVersion = 1 }
	local applied = Migrations.apply(data, 1, {})
	T.expectEqual(#applied, 0)
	T.expectEqual(data.schemaVersion, 1)
end)

T.test("aplica migraciones en orden hasta la versión objetivo", function()
	local data: { [string]: any } = { schemaVersion = 1, gold = 10 }
	local list = {
		[1] = function(d: { [string]: any })
			d.coins = d.gold
			d.gold = nil
		end,
		[2] = function(d: { [string]: any })
			d.coins *= 2
		end,
	}
	local applied = Migrations.apply(data, 3, list)
	T.expectEqual(#applied, 2)
	T.expectEqual(data.schemaVersion, 3)
	T.expectEqual(data.coins, 20)
	T.expectEqual(data.gold, nil)
end)

T.test("falla si falta una migración", function()
	T.expectError(function()
		Migrations.apply({ schemaVersion = 1 }, 3, { [1] = function() end })
	end, "Falta la migración desde la versión 2")
end)

T.test("no toca perfiles de una versión más nueva", function()
	T.expectError(function()
		Migrations.apply({ schemaVersion = 5 }, 1, {})
	end, "más nueva")
end)

T.test("la lista de migraciones del juego cubre hasta la versión actual", function()
	for version = 1, Schema.VERSION - 1 do
		assert(Migrations.list[version] ~= nil, `falta Migrations.list[{version}]`)
	end
end)

T.test("la migración 1→2 concede los títulos de rango merecidos", function()
	local data: { [string]: any } = { schemaVersion = 1, level = 11 }
	Migrations.apply(data, 2)
	T.expectEqual(data.schemaVersion, 2)
	T.expectEqual(data.unlockedTitles.Tiro, true)
	T.expectEqual(data.unlockedTitles.Veteranus, true)
	T.expectEqual(data.unlockedTitles.PrimusPalus, true)
	T.expectEqual(data.unlockedTitles.Campeon, nil)
	T.expectEqual(data.equippedTitle, "Tiro")
end)

T.test("la migración 1→2 respeta un título ya equipado", function()
	local data: { [string]: any } = { schemaVersion = 1, level = 1, equippedTitle = "Matahidras" }
	Migrations.apply(data, 2)
	T.expectEqual(data.equippedTitle, "Matahidras")
end)

T.finish()
