--!strict
-- Punto de entrada único del servidor: carga y arranca todos los Services.
-- Ver docs/ARCHITECTURE.md (ciclo Init -> Start).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Util.Loader)
local Version = require(ReplicatedStorage.Shared.Version)

print(`[COLOSSEUM] servidor v{Version}`)
Loader.start(script.Parent.Services, "Servidor")
