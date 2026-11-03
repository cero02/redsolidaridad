--!strict
-- Punto de entrada único del servidor.
-- Etapa 0: solo comprueba que Rojo sincroniza. El cargador de Services
-- (Init -> Start) llega en la Etapa 1; ver docs/ARCHITECTURE.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage.Shared.Version)

print(`[COLOSSEUM] servidor v{Version}`)
