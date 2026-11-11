# CLAUDE.md — Reglas del proyecto COLOSSEUM: Rise of the Beasts

Experiencia de Roblox: un gladiador desconocido que se convierte en leyenda combatiendo
bestias míticas y conquistando sus poderes.

Lee también: `docs/VISION.md` (visión), `docs/design/` (diseño detallado), `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/ROADMAP.md` y `docs/adr/`.

## Objetivo actual

**Versión 1 — El nacimiento:** combate contra la Hidra, individual y cooperativo, con tres
armas, tres esencias y progresión. Se construye por hitos (ver `docs/ROADMAP.md`).
Antes de trabajar fuera del hito en curso, pide aprobación.

## Regla de diseño

Cinco pilares de retención (ver `docs/design/PILARES.md` y ADR 0007): progreso, presumir,
FOMO sano (todo vuelve, nada se castiga, nada de pago), sentirse inteligente y comunidad.

Cada recompensa abre una posibilidad nueva, cada bestia cuenta una historia y cada combate
produce un momento memorable. Mejor un sistema excelente que diez mediocres.

## Reglas obligatorias

### APIs y fuentes
- No inventes APIs de Roblox. Usa solo lo documentado en https://create.roblox.com/docs.
- Si no puedes verificar una API, una propiedad o un límite, márcalo en el código y en el PR
  como `-- POR VERIFICAR:` y avisa al equipo.
- No uses APIs marcadas como obsoletas (Selene lo bloquea con `deprecated = "deny"`).

### Seguridad del servidor (ver docs/SECURITY.md)
- El servidor es la autoridad. El cliente solo envía **intenciones**, nunca resultados
  (nunca "hice 30 de daño", sí "quiero atacar").
- Todo Remote nuevo se declara en `src/shared/Net`, con validador de tipos y límite de
  peticiones por jugador. No se crean Remotes sueltos en otros módulos.
- No se usa `RemoteFunction` de servidor a cliente (`InvokeClient`): un cliente puede
  bloquear el hilo del servidor.
- Lógica, datos y tablas sensibles van en `ServerScriptService` o `ServerStorage`,
  nunca en `ReplicatedStorage`.
- Las compras se conceden solo en `MarketplaceService.ProcessReceipt`, que debe ser
  idempotente.

### Monetización y azar
- **Prohibido**: apuestas, cajas de botín de pago, ruletas o cualquier mecánica de azar
  con Robux u objetos que tengan valor monetario.
- Solo mecanismos oficiales: Game Passes, Developer Products, servidores privados y
  otros que Roblox documente. Consultar `PolicyService` cuando proceda.
- Nada de pagar para ganar: la monetización es cosmética (apariencia, efectos visuales).
- Los cofres solo se obtienen jugando. Nunca se venden, ni directa ni indirectamente
  (llaves, tiradas extra, multiplicadores o monedas canjeables por cofres).
- Sin presión para volver: nada de castigos por desconectarse, rachas que se pierden ni
  temporizadores que obliguen a entrar cada pocas horas.

### Código
- Lenguaje: Luau, con `--!strict` en todos los módulos.
- Un único `Main.server.luau` y un único `Main.client.luau`. El resto son ModuleScripts.
- Servidor: `Services` con ciclo `Init()` → `Start()`. Cliente: `Controllers` con el mismo ciclo.
- `Init()` no debe ceder (yield) ni llamar a otros Services; `Start()` sí puede.
- Valores de diseño (daño, tiempos, precios) en `src/shared/Config` o `src/serverOnly`,
  nunca escritos dentro de la lógica.
- Nombres: `PascalCase` para módulos y tipos, `camelCase` para variables y funciones,
  `UPPER_SNAKE_CASE` para constantes.
- Cada módulo empieza con un comentario breve que explica su responsabilidad.

### Calidad
- Antes de cada commit: `./scripts/check.sh` (StyLua, Selene y `rojo build`) debe pasar.
- La lógica pura (cálculos, validadores) lleva tests en `tests/` (Lune).
- Lo que no se puede probar fuera de Studio se documenta con pasos de prueba manual en el PR.

### Dependencias
- **No instales herramientas ni paquetes sin autorización del equipo.**
- Versiones siempre fijadas (`rokit.toml`, `wally.toml`, `scripts/install-tools.sh`).
- Cada dependencia nueva requiere un ADR en `docs/adr/`.

### Decisiones
- Toda decisión técnica relevante se documenta como ADR (`docs/adr/NNNN-titulo.md`).
- Si una decisión cambia, se escribe un ADR nuevo que sustituye al anterior.

### Contenido
- Recursos (modelos, sonidos, texturas, nombres) propios o con licencia válida. Las imágenes
  de referencia solo marcan el tono; no se copian diseños de otros juegos o películas.
- Todo texto escrito por jugadores se filtra con `TextService` o `TextChatService`.
- El nivel de violencia (sangre, etc.) debe respetar la calificación de madurez que el
  equipo decida en Roblox; no añadir contenido gráfico sin aprobación.

## Entorno de desarrollo

- El código se edita fuera de Studio y se sincroniza con **Rojo** (`rojo serve` + plugin).
- Roblox Studio solo funciona en Windows/macOS: las pruebas de juego se hacen en el PC
  del equipo. En el contenedor de Claude solo se ejecutan lint, formato, build y tests Lune.
- Herramientas: ver `rokit.toml`. Instalación sin GitHub: `scripts/install-tools.sh`.

## Comandos

```bash
wally install                           # paquetes (ProfileStore)
./scripts/check.sh                      # formato, lint, build y tests
stylua src tests                        # formatear
selene src tests                        # lint
rojo build -o build/colosseum.rbxl      # generar el place
lune run tests/Version.spec.luau        # un test concreto
rojo serve                              # sincronizar con Studio (en tu PC)
```
