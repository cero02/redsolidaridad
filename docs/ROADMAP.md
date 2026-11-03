# Hoja de ruta de COLOSSEUM

Cada etapa termina con: `scripts/check.sh` en verde, prueba manual en Studio documentada
y aprobación del equipo antes de pasar a la siguiente.

## Etapa 0 — Entorno ✅ en curso
- Repositorio, estructura de carpetas, Rojo y herramientas de calidad.
- CLAUDE.md, ARCHITECTURE.md, SECURITY.md, ROADMAP.md y ADRs iniciales.
- **Hecho cuando:** `rojo serve` sincroniza con Studio en el PC del equipo y aparecen los
  mensajes `[COLOSSEUM] servidor` y `[COLOSSEUM] cliente` al pulsar Play.

## Etapa 1 — Base técnica
- Cargador de Services y Controllers (`Init` → `Start`).
- Capa de red central: declaración, validación de tipos, límite de peticiones.
- `PlayerDataService` (tras decidir el ADR 0003) con esquema versionado.
- Registro de eventos y errores del servidor.
- Tests Lune de validadores.

## Etapa 2 — Arena y combate 1 contra 1
- Arena de prueba (greybox) con dos puntos de aparición y gradas.
- Cola simple: los dos primeros jugadores en cola luchan.
- Rondas: cuenta atrás, combate, victoria por derrota o tiempo, regreso al lobby.
- Combate cuerpo a cuerpo básico (un arma, ataque y bloqueo) validado en el servidor.

## Etapa 3 — Espectadores → **v0.1 prototipo**
- Jugadores que no luchan aparecen en las gradas.
- Cámara de espectador (seguir a un luchador o vista general).
- Interfaz: vida de ambos luchadores, tiempo y marcador.
- **Hito v0.1:** prototipo funcional del coliseo con 1 contra 1 y espectadores,
  probado con varios jugadores en Studio (Team Test o servidor local).

## Etapa 4 — Progresión y personalización
- Estadísticas (victorias, derrotas, rachas), niveles y recompensas.
- Cosméticos (armaduras, cascos) sin ventaja en combate.

## Etapa 5 — Bestias
- Bestias controladas por el servidor (`PathfindingService`), animales y criaturas mitológicas.
- Límites de NPC por servidor por rendimiento.

## Etapa 6 — Batallas navales
- Prototipo de física de barcos controlado por el servidor (etapa de mayor riesgo técnico).

## Etapa 7 — Monetización
- Game Passes y Developer Products cosméticos o de comodidad.
- `ProcessReceipt` idempotente, `PolicyService`, sin mecánicas de azar de pago.

## Etapa 8 — Pulido y lanzamiento
- Rendimiento, anti-exploits, analíticas, beta cerrada, cuestionario de madurez y lanzamiento.
