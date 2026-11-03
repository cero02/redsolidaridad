# Arquitectura de COLOSSEUM

## Principios

1. **Servidor autoritativo.** El cliente pide, el servidor decide.
2. **Módulos pequeños con una sola responsabilidad.**
3. **Datos de diseño separados de la lógica** (`Config`).
4. **Dependencias mínimas y aisladas** detrás de adaptadores propios.
5. **Decisiones documentadas** en `docs/adr/`.

## Mapa Rojo → Roblox

| Carpeta | Destino en Roblox | Visible para el cliente |
|---|---|---|
| `src/server` | `ServerScriptService.Server` | No |
| `src/serverOnly` | `ServerStorage.ServerOnly` | No |
| `src/shared` | `ReplicatedStorage.Shared` | Sí |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Sí |

Definido en `default.project.json`. Cuando se aprueben paquetes de Wally se añadirán
`ReplicatedStorage.Packages` y `ServerStorage.ServerPackages`.

## Estructura

```
src/
├─ server/
│  ├─ Main.server.luau        arranque: carga y ejecuta los Services
│  └─ Services/               un ModuleScript por servicio
├─ serverOnly/                modelos y tablas que el cliente no debe ver
├─ shared/
│  ├─ Net/                    declaración central de Remotes + validadores
│  ├─ Config/                 armas, arenas, tiempos (datos, no lógica)
│  ├─ Types/                  tipos Luau compartidos
│  ├─ Util/                   utilidades puras (testeables con Lune)
│  └─ Version.luau
└─ client/
   ├─ Main.client.luau        arranque: carga y ejecuta los Controllers
   ├─ Controllers/            input, cámara, combate (visual), espectador, UI
   └─ UI/                     componentes de interfaz
```

## Ciclo de vida

`Main` hace `require` de todos los módulos de `Services/` (o `Controllers/`) y luego:

1. Llama a `Init()` de cada uno: preparar estado interno. **No cede ni usa otros servicios.**
2. Llama a `Start()` de cada uno en un hilo propio: conectar eventos, usar otros servicios.

Se usa un cargador propio de pocas líneas en lugar de un framework externo
(ver `adr/0002-cargador-propio.md`).

## Services previstos (servidor)

| Service | Responsabilidad | Etapa |
|---|---|---|
Columna "Hito": ver `ROADMAP.md`.

| Service | Responsabilidad | Hito |
|---|---|---|
| `PlayerDataService` | Cargar y guardar perfiles; esquema versionado | 1.0 |
| `NetService` | Crear Remotes desde `Shared/Net`, validar, limitar peticiones | 1.0 |
| `CombatService` | Validar ataques, esquivas y bloqueos; calcular golpes y daño | 1.1 |
| `ArenaService` | Estado del Gran Coliseo, puntos de aparición | 1.2 |
| `EncounterService` | Partida: grupo, inicio, fases, victoria o derrota, 8–12 min | 1.2 |
| `BeastService` | Bestias en el servidor: máquina de estados, fases, patrones adaptativos | 1.2 |
| `LoadoutService` | Arma, armadura, esencias y habilidad definitiva del jugador | 1.4 |
| `ProgressionService` | Experiencia, niveles, desbloqueos | 1.5 |
| `SpectatorService` | Gradas y cámara de espectador | 1.6 (propuesto) |
| `LootService` | Cofres y tablas de botín (solo jugando) | v2 |
| `QuestService` | Misiones | v2 |
| `LeaderboardService` | Clasificaciones, Salón de leyendas | v2 |
| `EventService` | Eventos imperiales | v3 |
| `NavalService` | Batallas navales | v4 |
| `MonetizationService` | Game Passes, Developer Products, `ProcessReceipt` | por decidir |

## Controllers previstos (cliente)

`InputController`, `CameraController`, `CombatController` (animaciones, efectos y
predicción visual; nunca decide daño), `SpectatorController`, `UIController`.

## Red

- Todos los Remotes se declaran en `Shared/Net` con nombre, dirección, tipos de
  argumentos y límite de peticiones.
- `NetService` crea las instancias en el servidor. El cliente solo las busca.
- Flujo de un ataque:
  1. El cliente reproduce la animación de inmediato (sensación de respuesta).
  2. Envía `AttackRequest(slot)`.
  3. El servidor comprueba tipos, límite de peticiones, estado del combate, cooldown y
     distancia, y calcula el golpe con consultas espaciales propias
     (`Workspace:GetPartBoundsInBox`, `Workspace:Raycast`, etc.).
  4. El servidor aplica el daño y replica el resultado a luchadores y espectadores.
- Para datos frecuentes y no críticos (efectos) se puede usar `UnreliableRemoteEvent`.

## Datos persistentes

- Acceso a `DataStoreService` encapsulado en `PlayerDataService`.
- Bloqueo de sesión obligatorio para evitar duplicación de objetos entre servidores.
- Esquema con número de versión y migraciones.
- Biblioteca: ProfileStore, **en evaluación** (ver `adr/0003-persistencia-profilestore.md`).
  El resto del código nunca la usa directamente, solo a través de `PlayerDataService`.

## Bestias

- Cada bestia es un módulo de datos en `src/serverOnly/Beasts/` (fases, ataques, puntos
  débiles, pesos de patrones) y la lógica común vive en `BeastService`.
- **Máquina de estados en el servidor:** fase → elegir patrón → telegrafiar (aviso al
  cliente) → ejecutar → recuperación (ventana para castigar).
- **Patrones adaptativos:** pesos ajustados por reglas según dificultad y grupo
  (tamaño, armas, rol). Deterministas a partir de una semilla para poder reproducir y
  equilibrar. Sin aprendizaje automático.
- El servidor mantiene la propiedad de red de las bestias (`BasePart:SetNetworkOwner(nil)`).
- Los golpes de la bestia se resuelven en el servidor con consultas espaciales y dejan
  margen por latencia: si el cliente vio el aviso a tiempo, esquivar debe funcionar.

## Espectadores (hito 1.6, propuesto)

- Los espectadores están en el mismo servidor que el combate, en las gradas.
- No pueden interactuar con los luchadores; el servidor ignora cualquier petición de
  combate de un jugador que no sea luchador activo.
- La cámara de espectador es local (`CameraController`) y solo usa datos replicados.
- Más adelante, espectar entre servidores (`MessagingService` / `MemoryStoreService`) se
  evaluará en un ADR propio.

## Pruebas

- **Lune** (`tests/`): lógica pura de `Shared/Util` y validadores.
- **Studio** (manual): todo lo que depende del motor. Cada PR incluye pasos de prueba.
- `scripts/check.sh`: formato, lint y build. Obligatorio antes de cada commit.
