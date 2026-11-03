# 0006 — La Versión 1 es PvE contra la Hidra

**Estado:** Aceptado (2026-11-03). Sustituye el objetivo "v0.1: 1 contra 1 y espectadores".

## Contexto
La dirección creativa define COLOSSEUM: Rise of the Beasts (ver `VISION.md`). El corazón del
juego son las bestias, no los duelos entre jugadores.

## Decisión
- La Versión 1 es un combate contra la Hidra, individual y cooperativo (1–4 jugadores),
  con tres armas, tres esencias y progresión.
- El PvP pasa a la Versión 3 (Arena de campeones).
- Los espectadores entran en la Versión 1 como hito 1.6 (gradas del Gran Coliseo,
  reacciones solo cosméticas). Confirmado por el equipo.
- Se construye por hitos verticales jugables (ROADMAP 1.0–1.6).

## Consecuencias
- `BeastService` y `EncounterService` pasan a ser el núcleo de la v1; `MatchService`
  (cola 1v1) desaparece por ahora.
- El riesgo técnico principal pasa a ser la IA y sincronización de una bestia grande con
  varias partes (cabezas), en lugar del duelo entre jugadores.
- La v1 es más grande que el prototipo anterior; los hitos permiten parar y validar.
