# Hoja de ruta de COLOSSEUM: Rise of the Beasts

Visión completa en [VISION.md](VISION.md). Diseño detallado en [design/](design/).

Cada hito termina con: `scripts/check.sh` en verde, prueba manual en Studio documentada
y aprobación del equipo antes de pasar al siguiente.

## Etapa 0 — Entorno ✅
- Repositorio, estructura, Rojo, herramientas de calidad y documentación.
- **Pendiente:** confirmar en un PC con Studio que `rojo serve` sincroniza y que aparecen
  los mensajes `[COLOSSEUM]` al pulsar Play.

## Versión 1 — El nacimiento de COLOSSEUM

Objetivo: **un combate contra la Hidra tan bueno que den ganas de invitar a amigos.**
Se construye por hitos verticales: cada uno es jugable y se prueba antes de seguir.

| Hito | Contenido | Hecho cuando… |
|---|---|---|
| 1.0 Base técnica 🔨 código listo | Cargador de Services/Controllers, red validada, persistencia (ADR 0003), registros | Un perfil se guarda y se recupera en Studio (pendiente de prueba) |
| 1.1 Sensación de combate | Una arma, ataque, esquiva y bloqueo contra un muñeco de prueba, validado en servidor | Golpear "se siente bien" en la prueba del equipo |
| 1.2 Hidra, fase 1 | Arena del Gran Coliseo (greybox), Hidra con ataques telegrafiados y punto débil, modo individual | Se puede ganar y perder de forma justa |
| 1.3 Hidra completa + cooperativo | Tres fases, regeneración de cabezas, grupo de 1–4 jugadores, patrones según el grupo | Una partida de 8–12 min con amigos |
| 1.4 Armas, esencias y definitiva | Tres armas, tres esencias, habilidad definitiva que se carga | Al menos tres construcciones distintas viables |
| 1.5 Recompensas y progresión | Experiencia, niveles, desbloqueos, pantalla de resultados | Ganar abre una posibilidad nueva |
| 1.6 Espectadores | Gradas del Gran Coliseo, cámara de espectador, reacciones del público (solo cosméticas). Ver [design/ESPECTADORES.md](design/ESPECTADORES.md) | Ver una partida desde las gradas es divertido |
| **Lanzamiento v1** | Pulido, rendimiento, anti-exploits, beta cerrada, cuestionario de madurez | Aprobación del equipo |

## Versión 2 — La gloria
Cofres (solo jugando), inventario, Forja y mejoras de armas, misiones, clasificaciones y
Salón de leyendas.

## Versión 3 — El Imperio
Nuevas bestias (León de ceniza, Minotauro, Dragón imperial), torneos PvP en la Arena de
campeones, eventos imperiales y esencias combinables.

## Versión 4 — Expansión
Batallas navales (Puerto imperial, Kraken), Catacumbas, criaturas legendarias y nuevos
territorios.

## Monetización
Cosméticos y efectos visuales con productos oficiales de Roblox. Se planifica cuando el
juego sea divertido; nunca antes de la v1.
