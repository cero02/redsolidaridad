--!strict
-- Ciclo de vida de Services y Controllers: Init() en todos y después Start() en todos.
-- Un módulo que falla NO tumba a los demás: se informa del error y ese módulo no arranca.
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
	-- A dónde enviar errores de Init (el módulo se omite). Por defecto `warn`.
	onInitError: ((name: string, err: string) -> ())?,
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
-- Devuelve nil si fue bien o el mensaje de error.
local function runInit(module: Module): string?
	local init = module.Init
	if init == nil then
		return nil
	end
	local thread = coroutine.create(init)
	local ok, err = coroutine.resume(thread, module)
	if not ok then
		return tostring(err)
	end
	if coroutine.status(thread) ~= "dead" then
		return "Init cedió (yield). Mueve el código que espera a Start()."
	end
	return nil
end

local function defaultReport(phase: string): (string, string) -> ()
	return function(name: string, err: string)
		warn(`[COLOSSEUM] {phase} de {name} falló: {err}`)
	end
end

-- Inicia todos los módulos en orden alfabético estable. Devuelve los nombres de los que
-- fallaron en Init (y por tanto no arrancaron).
function Lifecycle.run(modules: { [string]: Module }, options: Options?): { string }
	local spawn: Spawner = if options and options.spawn then options.spawn else task.spawn
	local onInitError = if options and options.onInitError
		then options.onInitError
		else defaultReport("Init")
	local onStartError = if options and options.onStartError
		then options.onStartError
		else defaultReport("Start")

	local names = sortedNames(modules)
	local failed: { string } = {}
	local healthy: { string } = {}

	for _, name in names do
		local err = runInit(modules[name])
		if err then
			table.insert(failed, name)
			onInitError(name, err)
		else
			table.insert(healthy, name)
		end
	end

	for _, name in healthy do
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
	return failed
end

return Lifecycle
