--!strict
-- Punto de entrada único del cliente: carga y arranca todos los Controllers.
-- Ver docs/ARCHITECTURE.md (ciclo Init -> Start).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Util.Loader)
local Version = require(ReplicatedStorage.Shared.Version)

print(`[COLOSSEUM] cliente v{Version}`)
Loader.start(script.Parent.Controllers, "Cliente")
