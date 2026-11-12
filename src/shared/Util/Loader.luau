--!strict
-- Carga todos los ModuleScripts de una carpeta y los arranca con Lifecycle. Si un módulo
-- falla al cargarse o al arrancar, se informa y los demás siguen funcionando.

local Lifecycle = require(script.Parent.Lifecycle)
local Log = require(script.Parent.Log)

local Loader = {}

function Loader.collect(folder: Instance, log: Log.Logger?): { [string]: Lifecycle.Module }
	local modules: { [string]: Lifecycle.Module } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok and type(result) == "table" then
				modules[child.Name] = result :: any
			elseif log then
				log:error(`No se pudo cargar {child.Name}: {result}`)
			end
		end
	end
	return modules
end

function Loader.start(folder: Instance, label: string)
	local log = Log.new(label)
	local modules = Loader.collect(folder, log)
	local failed = Lifecycle.run(modules, {
		onInitError = function(name: string, err: string)
			log:error(`Init de {name} falló: {err}`)
		end,
		onStartError = function(name: string, err: string)
			log:error(`Start de {name} falló: {err}`)
		end,
	})
	local count = 0
	for _ in modules do
		count += 1
	end
	log:info(`{count - #failed} módulos iniciados` .. (if #failed > 0 then ` ({#failed} con errores)` else ""))
end

return Loader
