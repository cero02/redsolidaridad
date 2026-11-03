--!strict
-- Ciclo de vida de Services y Controllers: Init() en todos y después Start() en todos.
-- Módulo puro (sin APIs de Roblox) para poder probarlo con Lune.

export type Module = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
	[any]: any,
}

export type Spawner = (fn: () -> ()) -> ()

export type Options = {
	-- Cómo lanzar cada Start en su propio hilo. Por defecto `task.spawn`.
	spawn: Spawner?,
	-- A dónde enviar errores de Start. Por defecto `warn`.
	onStartError: ((name: string, err: string) -> ())?,
}

local Lifecycle = {}

local function sortedNames(modules: { [string]: Module }): { string }
	local names = {}
	for name in modules do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- Ejecuta Init() sin permitir que ceda: Init solo prepara estado interno.
local function runInit(name: string, module: Module)
	local init = module.Init
	if init == nil then
		return
	end

	local thread = coroutine.create(init)
	local ok, err = coroutine.resume(thread, module)
	if not ok then
		error(`Init de {name} falló: {err}`, 0)
	end
	if coroutine.status(thread) ~= "dead" then
		error(`Init de {name} cedió (yield). Mueve el código que espera a Start().`, 0)
	end
end

-- Inicia todos los módulos en orden alfabético estable.
-- Un error en Init detiene el arranque; un error en Start solo afecta a ese módulo.
function Lifecycle.run(modules: { [string]: Module }, options: Options?)
	local spawn: Spawner = if options and options.spawn then options.spawn else task.spawn
	local onStartError = if options and options.onStartError
		then options.onStartError
		else function(name: string, err: string)
			warn(`[COLOSSEUM] Start de {name} falló: {err}`)
		end

	local names = sortedNames(modules)

	for _, name in names do
		runInit(name, modules[name])
	end

	for _, name in names do
		local module = modules[name]
		local start = module.Start
		if start ~= nil then
			spawn(function()
				local ok, err = xpcall(start, debug.traceback, module)
				if not ok then
					onStartError(name, tostring(err))
				end
			end)
		end
	end
end

return Lifecycle
