--!strict
-- Configuración de la persistencia.

return table.freeze({
	-- Nombre del DataStore. Cambiarlo equivale a empezar con datos vacíos: no tocar.
	STORE_NAME = "PlayerProfiles_v1",

	-- En Studio se usan datos simulados (ProfileStore.Mock) salvo que esto sea true.
	-- Requiere "Enable Studio Access to API Services" y un place publicado.
	USE_LIVE_DATA_IN_STUDIO = false,
})
