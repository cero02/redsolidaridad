--!strict
local Codex = require("../src/shared/Config/Codex")
local Decrees = require("../src/shared/Config/Decrees")
local En = require("../src/shared/Locale/Strings/En")
local Es = require("../src/shared/Locale/Strings/Es")
local Essences = require("../src/shared/Config/Essences")
local Progression = require("../src/shared/Config/Progression")
local T = require("./TestUtil")
local Titles = require("../src/shared/Config/Titles")
local Translate = require("../src/shared/Locale/Translate")
local Weapons = require("../src/shared/Config/Weapons")

T.suite("Idiomas")

local tables = { en = En :: any, es = Es :: any }
local LANGUAGES = { "en", "es" }

local function has(key: string)
	for _, language in LANGUAGES do
		assert(tables[language][key] ~= nil, `falta "{key}" en {language}`)
	end
end

T.test("inglés y español tienen exactamente las mismas claves", function()
	for key in En do
		assert(Es[key] ~= nil, `falta en español: {key}`)
	end
	for key in Es do
		assert(En[key] ~= nil, `sobra en español (no existe en inglés): {key}`)
	end
end)

T.test("cada traducción usa los mismos marcadores {x} que el inglés", function()
	for key, text in En do
		local english = Translate.placeholders(text)
		local spanish = Translate.placeholders(Es[key] or "")
		for name in english do
			assert(spanish[name], `"{key}": falta {"{"}{name}{"}"} en español`)
		end
		for name in spanish do
			assert(english[name], `"{key}": sobra {"{"}{name}{"}"} en español`)
		end
	end
end)

T.test("ningún texto está vacío", function()
	for _, language in LANGUAGES do
		for key, text in tables[language] do
			assert(#text > 0, `"{key}" vacío en {language}`)
		end
	end
end)

T.test("format sustituye parámetros y traduce referencias anidadas", function()
	local text = Translate.format(tables, "es", "news.title", {
		name = "Ana",
		title = { key = "title.Matahidras.name" },
	})
	T.expectEqual(text, "Ana ha obtenido el título «Matahidras».")
	local english = Translate.format(tables, "en", "news.title", {
		name = "Ana",
		title = { key = "title.Matahidras.name" },
	})
	T.expectEqual(english, "Ana earned the title “Hydraslayer”.")
end)

T.test("format respeta números y deja intactos los marcadores sin valor", function()
	T.expectEqual(Translate.format(tables, "en", "hud.xp", { xp = 150, needed = 200 }), "150/200 XP")
	T.expectEqual(Translate.format(tables, "en", "hud.xp", { xp = 1 }), "1/{needed} XP")
end)

T.test("una clave inexistente cae al inglés y, si no, se muestra la clave", function()
	local partial = { en = { ["solo.en"] = "only english" }, es = {} }
	T.expectEqual(Translate.format(partial, "es", "solo.en"), "only english")
	T.expectEqual(Translate.format(partial, "es", "no.existe"), "no.existe")
end)

T.test("resolve: preferencia explícita, idioma de la cuenta o inglés", function()
	T.expectEqual(Translate.resolve(LANGUAGES, "es", "en-us"), "es")
	T.expectEqual(Translate.resolve(LANGUAGES, "auto", "es-mx"), "es")
	T.expectEqual(Translate.resolve(LANGUAGES, "auto", "ES-ES"), "es")
	T.expectEqual(Translate.resolve(LANGUAGES, "auto", "pt-br"), "en")
	T.expectEqual(Translate.resolve(LANGUAGES, nil, nil), "en")
	T.expectEqual(Translate.resolve(LANGUAGES, "fr", "en-us"), "en")
end)

T.test("cada rango y título tiene nombre y explicación", function()
	for _, rank in Progression.RANKS do
		has(`rank.{rank.id}`)
	end
	for id in Titles do
		has(`title.{id}.name`)
		has(`title.{id}.how`)
	end
end)

T.test("cada secreto del Códice tiene lección y acertijo", function()
	for _, discovery in Codex do
		has(`codex.{discovery.id}.lesson`)
		has(`codex.{discovery.id}.riddle`)
	end
end)

T.test("cada edicto, arma, definitiva y esencia tiene sus textos", function()
	for _, decree in Decrees do
		has(`decree.{decree.id}.name`)
		has(`decree.{decree.id}.desc`)
	end
	for id, weapon in Weapons do
		has(`weapon.{id}.name`)
		has(`weapon.{id}.desc`)
		has(`ultimate.{weapon.ultimate.id}.name`)
		has(`ultimate.{weapon.ultimate.id}.desc`)
	end
	for id in Essences do
		for _, field in { "name", "power", "passive", "how" } do
			has(`essence.{id}.{field}`)
		end
	end
end)

T.test("cada desbloqueo por nivel tiene texto", function()
	for _, unlocks in Progression.UNLOCKS do
		for _, unlock in unlocks do
			if unlock.kind == "Weapon" then
				has(`weapon.{unlock.id}.name`)
			elseif unlock.kind == "Essence" then
				has(`essence.{unlock.id}.name`)
			elseif unlock.kind == "Cosmetic" then
				has(`cosmetic.{unlock.id}`)
			elseif unlock.kind == "Title" then
				has(`title.{unlock.id}.name`)
			else
				has(`feature.{unlock.id}`)
			end
		end
	end
end)

T.finish()
