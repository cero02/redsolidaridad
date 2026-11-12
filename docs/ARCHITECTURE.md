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

| `ServerPackages` (Wally) | `ServerStorage.ServerPackages` | No |

Definido en `default.project.json`. `ServerPackages/` se genera con `wally install` y no se
sube a git (sí `wally.lock`).

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
| `SpectatorService` | Gradas y cámara de espectador | 1.6 |
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

## Espectadores (hito 1.6)

- Los espectadores están en el mismo servidor que el combate, en las gradas.
- No pueden interactuar con los luchadores; el servidor ignora cualquier petición de
  combate de un jugador que no sea luchador activo.
- La cámara de espectador es local (`CameraController`) y solo usa datos replicados.
- Más adelante, espectar entre servidores (`MessagingService` / `MemoryStoreService`) se
  evaluará en un ADR propio.

## Implementado (hito 1.0)

| Módulo | Ubicación | Qué hace |
|---|---|---|
| `Lifecycle` | `shared/Util` | `Init` (sin ceder) → `Start` (cada uno en su hilo) |
| `Loader` | `shared/Util` | Carga los ModuleScripts de una carpeta y los arranca |
| `Signal`, `Log`, `RateLimiter` | `shared/Util` | Utilidades sin dependencias |
| `Remotes` | `shared/Net` | Declaración central de Remotes (dirección, validadores, límites) |
| `Check`, `Guard` | `shared/Net` | Validadores de argumentos y decisión de aceptar una petición |
| `Client` | `shared/Net` | Acceso a los Remotes desde el cliente |
| `NetService` | `server/Services` | Crea los Remotes y filtra cada petición |
| `PlayerDataService` | `server/Services` | Perfiles con ProfileStore, migraciones |
| `Schema`, `Migrations`, `DataConfig` | `server/Data` | Esquema versionado del perfil |
| `ProfileController` | `client/Controllers` | Recibe el perfil público |

### Hito 1.1 (combate)

| Módulo | Ubicación | Qué hace |
|---|---|---|
| `FighterState` | `shared/Combat` | Reglas puras del luchador: combo, aguante, esquiva, bloqueo, parada, definitiva. Lo usan el servidor (autoridad) y el cliente (predicción) |
| `Combat`, `Weapons` | `shared/Config` | Números de diseño |
| `CombatService` | `server/Services` | Valida acciones, calcula golpes con `GetPartBoundsInBox`, resuelve golpes recibidos con margen de latencia. `registerTarget` y `hitPlayer` son la interfaz para bestias |
| `TrainingDummyService` | `server/Services` | Muñeco provisional que recibe golpes y ataca con aviso |
| `CombatController`, `CombatHud` | `client` | Entrada (PC, mando, móvil), predicción e interfaz mínima |
| `Health` (vacío) | `StarterCharacterScripts` | Desactiva la regeneración de vida por defecto de Roblox |

### Hito 1.2 (arena e Hidra, fase 1)

| Módulo | Ubicación | Qué hace |
|---|---|---|
| `HydraLogic` | `server/Beasts` | Reglas puras: cabezas, cortar, regenerar, cauterizar, elección adaptativa de ataque y de objetivo |
| `Hydra`, `Arena` | `serverOnly/Config` | Números de diseño (el cliente no los ve) |
| `ArenaService` | `server/Services` | Genera el coliseo, los braseros y la puerta del foro |
| `HydraService` | `server/Services` | Modelo de bloques, ataques con aviso (mordisco, veneno, coletazo), muñones y fuego |
| `EncounterService` | `server/Services` | Partida: participantes, presentación, victoria o derrota, regreso |
| `EncounterController` | `client/Controllers` | Anunciador y progreso |
| `HydraViewController` | `client/Controllers` | Dibuja los cuellos (solo visual) |

### Hito 1.3 (Hidra completa y cooperativo)

- `HydraLogic` gestiona varias fases de cabezas (`PHASES` en la configuración) y desbloquea
  ataques nuevos desde la fase 2 (cadena de mordiscos, nube tóxica, inmersión).
- `HydraService` añade la cabeza inmortal, la roca y las cadenas. Cada cambio de fase
  cancela los ataques en curso (`runId`) y reanuda el combate tras una pausa.
- `CombatService` distingue **caído** de muerto: quien decide es un manejador que registra
  `EncounterService` (`setZeroHealthHandler`). Reanimar: `ProximityPrompt` sobre el caído,
  validado en el servidor.
- `EncounterService` mide el tiempo y guarda el récord personal (`stats.bestHydraTime`).

### Aspecto provisional (v0.4.1)

- `EquipmentService` (servidor): gladius y escudo de bloques soldados al personaje.
- `CharacterAnimator` (cliente): animación por código con `Motor6D.Transform` en
  `RunService.Stepped`. El jugador local se anima al instante; los demás, con `CombatEvent`.
- Cuando existan animaciones y modelos de artista, sustituyen a estos dos módulos.

### Pilares de retención (v0.5.0)

| Módulo | Ubicación | Qué hace |
|---|---|---|
| `Progression`, `DecreeCalendar` | `shared/Meta` | Cálculos puros: niveles, rangos, desbloqueos; edicto activo |
| `Progression`, `Titles`, `Codex`, `Decrees` | `shared/Config` | Datos de diseño |
| `MatchRewards` | `server/Meta` | Experiencia de una partida con desglose (puro) |
| `ProgressionService` | `server/Services` | XP, niveles, títulos, placa sobre la cabeza, `leaderstats` |
| `CodexService` | `server/Services` | Descubrimientos del Códice |
| `EventService` | `server/Services` | Edicto semanal, Juegos Imperiales, ofrendas, noticias |
| `LeaderboardService` | `server/Services` | Salón de Leyendas (OrderedDataStore o local en Studio) |
| `EquipmentService` | `server/Services` | Ahora también los cosméticos desbloqueados |
| `MetaController` | `client/Controllers` | Interfaz de todo lo anterior |

`HydraService.Feat` y `CombatService.Parried` avisan de hazañas; `EncounterService` reparte
recompensas al terminar. El perfil pasa a la versión 2 del esquema (migración en
`Data/Migrations.luau`).

### Hito 1.4 (armas, esencias y definitivas)

- `Weapons` y `Essences` (`shared/Config`): tres armas con definitiva y tres esencias.
- `FighterState` añade inmunidad, esquivas gratis, bonus de daño, curación, aguante extra
  y `tryUltimate`.
- `LoadoutService` (servidor): armería; valida desbloqueos y bloquea cambios en la arena
  (atributo `InArena` que pone `EncounterService`).
- `CombatService`: crea el luchador con el equipo del perfil, ejecuta esencias (Z) y
  definitivas (R) con daño en zona (`GetPartBoundsInRadius`) y la regeneración de la Hidra.
- `EquipmentService` construye el arma elegida; `CharacterAnimator` anima cada una.

### v0.7 La presentación

| Módulo | Ubicación | Qué hace |
|---|---|---|
| `Theme` | `client/UI` | Paleta "bronce imperial", tipografías y componentes (panel, botón, texto) |
| `Settings` | `client/UI` | Temblor de cámara y modo ligero (sin sombras ni público) |
| `MainMenuController` | `client/Controllers` | Pantalla de inicio: cámara cinemática, ficha, edicto, botones |
| `OnboardingController` | `client/Controllers` | Primeros pasos para jugadores nuevos |
| `LobbyService` | `server/Services` | El Foro (plaza, columnata, ludus, calzada) e iluminación |

### v0.8 Internacional

| Módulo | Ubicación | Qué hace |
|---|---|---|
| `Translate` | `shared/Locale` | Traducción pura: `{marcadores}`, referencias anidadas, idioma por defecto |
| `Locale`, `Strings/En`, `Strings/Es` | `shared/Locale` | Diccionarios y elección de idioma |
| `ServerText` | `server/Localization` | Traducción por jugador (expulsiones) y textos del mundo traducibles |
| `SettingsService` | `server/Services` | Guarda los ajustes en el perfil y el idioma como atributo |
| `I18n`, `Settings`, `Bus` | `client/UI` | Idioma activo, ajustes guardados, señales entre pantallas |
| `LocalizeController` | `client/Controllers` | Traduce carteles y avisos del mundo |
| `MusicController` | `client/Controllers` | Música por momentos con fundidos (Config/Audio) |

Flujo de carga: el jugador entra → `PlayerDataService` inicia su sesión → el cliente envía
`ClientReady` cuando ya escucha → el servidor responde `ProfileReady` con el perfil público.

## Pruebas

- **Lune** (`tests/`): lógica pura de `Shared/Util` y validadores.
- **Studio** (manual): todo lo que depende del motor. Cada PR incluye pasos de prueba.
- `scripts/check.sh`: formato, lint y build. Obligatorio antes de cada commit.
