--!strict
-- Señales entre pantallas del cliente (evita que se requieran unas a otras en círculo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Bus = {}

-- Abrir la pantalla de inicio.
Bus.OpenMenu = Signal.new() :: Signal.Signal<()>
-- La pantalla de inicio se abrió (true) o se cerró (false).
Bus.MenuVisibility = Signal.new() :: Signal.Signal<boolean>
-- Último perfil público recibido.
Bus.Profile = Signal.new() :: Signal.Signal<any>

return Bus
