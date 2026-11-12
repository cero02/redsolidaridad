--!strict
-- Migraciones del perfil guardado. Cada función lleva los datos de la versión N a la N+1.
-- Nunca borrar ni reescribir una migración ya publicada: añadir una nueva.
-- Módulo puro para poder probarlo con Lune.

export type Migration = (data: { [string]: any }) -> ()

local Migrations = {}

-- Migraciones del juego: [versión de origen] = función.
Migrations.list = {
	-- v1 → v2: títulos, códice y decretos. Reconcile ya añade los campos vacíos; aquí se
	-- conceden los títulos de rango que el jugador ya merecía por su nivel.
	[1] = function(data: { [string]: any })
		local titles = data.unlockedTitles or {}
		titles.Tiro = true
		local level = if typeof(data.level) == "number" then data.level else 1
		for _, rank in
			{ { 5, "Veteranus" }, { 10, "PrimusPalus" }, { 15, "Campeon" }, { 20, "Rudiarius" } }
		do
			if level >= rank[1] then
				titles[rank[2]] = true
			end
		end
		data.unlockedTitles = titles
		if typeof(data.equippedTitle) ~= "string" or data.equippedTitle == "" then
			data.equippedTitle = "Tiro"
		end
	end,
} :: { [number]: Migration }

-- Aplica en orden todas las migraciones necesarias hasta targetVersion.
-- Devuelve la lista de versiones aplicadas. Lanza error si falta una migración o si los
-- datos son de una versión más nueva (servidor desactualizado): no se deben tocar.
function Migrations.apply(
	data: { [string]: any },
	targetVersion: number,
	list: { [number]: Migration }?
): { number }
	local migrations = list or Migrations.list
	local version = data.schemaVersion
	if typeof(version) ~= "number" then
		version = 1
	end

	if version > targetVersion then
		error(`Perfil con versión {version} más nueva que la del servidor ({targetVersion})`, 0)
	end

	local applied = {}
	while version < targetVersion do
		local migration = migrations[version]
		if migration == nil then
			error(`Falta la migración desde la versión {version}`, 0)
		end
		migration(data)
		table.insert(applied, version)
		version += 1
		data.schemaVersion = version
	end
	return applied
end

return Migrations
