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
| `PlayerDataService` | Cargar y guardar perfiles; esquema versionado | 1 |
| `NetService` | Crear Remotes desde `Shared/Net`, validar, limitar peticiones | 1 |
| `ArenaService` | Estado de la arena, puntos de aparición, gradas | 2 |
| `MatchService` | Cola 1v1, rondas, cuenta atrás, ganador | 2 |
| `CombatService` | Validar ataques, calcular golpes y daño | 2 |
| `SpectatorService` | Quién observa, a qué combate, datos públicos del combate | 3 |
| `ProgressionService` | Estadísticas, niveles, cosméticos | 4 |
| `BeastService` | IA de bestias (servidor) | 5 |
| `NavalService` | Barcos y batallas navales | 6 |
| `MonetizationService` | Game Passes, Developer Products, `ProcessReceipt` | 7 |

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

## Espectadores (v0.1)

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
