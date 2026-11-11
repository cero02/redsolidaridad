# Hoja de ruta de COLOSSEUM: Rise of the Beasts

Visión completa en [VISION.md](VISION.md). Diseño detallado en [design/](design/).

Cada hito termina con: `scripts/check.sh` en verde, prueba manual en Studio documentada
y aprobación del equipo antes de pasar al siguiente.

## Etapa 0 — Entorno ✅
- Repositorio, estructura, Rojo, herramientas de calidad y documentación.
- Confirmado el 2026-11-10: `rojo serve` sincroniza con Studio en el PC del equipo.

## Versión 1 — El nacimiento de COLOSSEUM

Objetivo: **un combate contra la Hidra tan bueno que den ganas de invitar a amigos.**
Se construye por hitos verticales: cada uno es jugable y se prueba antes de seguir.

| Hito | Contenido | Hecho cuando… |
|---|---|---|
| 1.0 Base técnica ✅ | Cargador de Services/Controllers, red validada, persistencia (ADR 0003), registros | Un perfil se guarda y se recupera en Studio (arranca en Studio, 2026-11-10) |
| 1.1 Sensación de combate 🔨 funciona en Studio | Una arma, ataque, esquiva y bloqueo contra un muñeco de prueba, validado en servidor. Prueba: [testing/HITO_1.1.md](testing/HITO_1.1.md) | Golpear "se siente bien" en la prueba del equipo (prueba básica superada el 2026-11-10; faltan animaciones, sonidos y ajuste fino) |
| 1.2 Hidra, fase 1 ✅ | Arena del Gran Coliseo (bloques, generada por código), Hidra con tres ataques con aviso, cortar y cauterizar cuellos. Prueba: [testing/HITO_1.2.md](testing/HITO_1.2.md) | Victoria completa conseguida en Studio (2026-11-10) |
| 1.3 Hidra completa + cooperativo 🔨 código listo | Tres fases (furia y cabeza inmortal), braseros que se apagan, caídos y reanimación, récord personal de tiempo. Prueba: [testing/HITO_1.3.md](testing/HITO_1.3.md) | Una partida de 8–12 min con amigos (pendiente de prueba en Studio) |
| 1.4 Armas, esencias y definitiva 🔨 código listo | Gladius, Hasta y Martillo; esencias Loba, Águila e Hidra; Testudo, Lluvia de pila y Terremoto; armería en el foro. Prueba: [testing/HITO_1.4.md](testing/HITO_1.4.md) | Al menos tres construcciones distintas viables (pendiente de prueba en Studio) |
| 1.5 Recompensas, progresión y pilares 🔨 código listo | XP, niveles, rangos, desbloqueos y cosméticos; títulos y Salón de Leyendas; Códice de secretos; Edicto semanal y Juegos Imperiales; Hermandad, Mentor y ofrendas. Prueba: [testing/PILARES.md](testing/PILARES.md) | Ganar abre una posibilidad nueva (pendiente de prueba en Studio) |
| 1.6 Espectadores | Gradas del Gran Coliseo, cámara de espectador, reacciones del público (solo cosméticas). Ver [design/ESPECTADORES.md](design/ESPECTADORES.md) | Ver una partida desde las gradas es divertido |
| 1.7 La presentación 🔨 código listo | Pantalla de inicio con cámara cinemática, estilo visual común, ajustes (modo ligero), primeros pasos, el Foro de mármol con calzada al coliseo e iluminación de atardecer. Prueba: [testing/PRESENTACION.md](testing/PRESENTACION.md) | La primera impresión invita a quedarse (pendiente de prueba en Studio) |
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
