--!strict
-- Carga todos los ModuleScripts de una carpeta y los arranca con Lifecycle.

local Lifecycle = require(script.Parent.Lifecycle)
local Log = require(script.Parent.Log)

local Loader = {}

function Loader.collect(folder: Instance): { [string]: Lifecycle.Module }
	local modules: { [string]: Lifecycle.Module } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			modules[child.Name] = require(child) :: any
		end
	end
	return modules
end

function Loader.start(folder: Instance, label: string)
	local log = Log.new(label)
	local modules = Loader.collect(folder)
	Lifecycle.run(modules, {
		onStartError = function(name: string, err: string)
			log:error(`Start de {name} falló: {err}`)
		end,
	})
	local count = 0
	for _ in modules do
		count += 1
	end
	log:info(`{count} módulos iniciados`)
end

return Loader
