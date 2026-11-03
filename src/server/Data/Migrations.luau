--!strict
-- Migraciones del perfil guardado. Cada función lleva los datos de la versión N a la N+1.
-- Nunca borrar ni reescribir una migración ya publicada: añadir una nueva.
-- Módulo puro para poder probarlo con Lune.

export type Migration = (data: { [string]: any }) -> ()

local Migrations = {}

-- Migraciones del juego: [versión de origen] = función. Vacío en la versión 1.
Migrations.list = {} :: { [number]: Migration }

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
