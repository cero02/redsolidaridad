--!strict
-- Punto de entrada único del cliente.
-- Etapa 0: solo comprueba que Rojo sincroniza. El cargador de Controllers
-- llega en la Etapa 1; ver docs/ARCHITECTURE.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Version = require(ReplicatedStorage.Shared.Version)

print(`[COLOSSEUM] cliente v{Version}`)
