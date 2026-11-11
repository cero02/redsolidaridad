# Diseño: los cinco pilares de la retención

Decisión de producto (2026-11-11): COLOSSEUM debe tener bien arraigados cinco motivos para
jugar y volver. Este documento dice cómo se cumple cada uno **sin trucos que dañen al
jugador**. La mayoría del público de Roblox es menor de edad.

| Pilar | Qué siente el jugador | Cómo lo construimos |
|---|---|---|
| **Progreso** | «Cada partida me acerca a algo» | Nivel, rango, barra de XP siempre visible con el **próximo desbloqueo**; pantalla de resultados con desglose |
| **Presumir** | «Los demás ven lo que he logrado» | Títulos con historia sobre la cabeza, cosméticos visibles, Salón de Leyendas, tabla de jugadores, noticias del servidor |
| **FOMO sano** | «Algo especial pasa *ahora*» | Edicto semanal del César y Juegos Imperiales en vivo. **Todo vuelve**: nada se pierde para siempre |
| **Sentirse inteligente** | «Lo he descubierto yo» | El Códice: 11 secretos que nadie explica; al descubrirlos se revela su nombre latino |
| **Comunidad** | «Con otros es mejor» | Hermandad (+XP en grupo), Mentor, reanimar, ofrendas comunes que desatan Juegos para todo el servidor |

## 1. Progreso

- Experiencia por partida: ver `PROGRESION.md` y `src/shared/Config/Progression.luau`.
- **Siempre hay un "próximo"**: la barra de XP muestra qué se desbloquea y en qué nivel.
- Cada nivel del 2 al 20 tiene algo, salvo pocos de respiro; los rangos (Tiro → Rudiarius)
  marcan los grandes saltos.
- **Primera victoria del día:** +100 XP. Es un regalo, no una obligación: no hay rachas,
  no se pierde nada por no entrar.

## 2. Presumir

- **Títulos** (`Titles.luau`): cada uno cuenta *cómo* se ganó (Matahidras, Intactus,
  Velox, Hermano de Armas, Erudito de Lerna, los del Edicto…). Un título nuevo se equipa solo.
- **Placa sobre la cabeza:** «Título» + «Nv 12 · Primus Palus», visible para todos.
- **Cosméticos por nivel:** emblema, casco, penacho, capa, armadura de campeón, hoja en
  brasas y la *rudis* (espada de madera de los gladiadores libres).
- **Salón de Leyendas:** lápida en el foro con los 10 mejores tiempos contra la Hidra
  (compartida entre servidores con un OrderedDataStore).
- **Noticias:** victorias, ascensos, títulos y entradas al podio se anuncian al servidor.

## 3. FOMO sano

Reglas que **no** se rompen (ver ADR 0007):

1. Nada se pierde para siempre: los edictos rotan y vuelven; sus títulos se pueden ganar
   cuando regresan.
2. No se castiga no estar: sin rachas, sin temporizadores de "vuelve en 4 horas o pierdes".
3. Nada de pago: ningún evento se compra ni se acelera con Robux.

Mecánicas:

- **Edicto del César (semanal, lunes 00:00 UTC):** cambia el combate (Furia, Clemencia,
  Lerna, Sangre), multiplica la XP y da un título propio. Muestra cuánto le queda.
- **Juegos Imperiales:** XP ×2 durante 4 minutos para todo el servidor. Surgen solos cada
  15–25 minutos o cuando la comunidad completa las ofrendas.

## 4. Sentirse inteligente: el Códice

- 11 secretos (`Codex.luau`). Antes de descubrirlos, el Códice muestra un **acertijo**.
- Al descubrir uno: aviso «✦ ¡DESCUBRIMIENTO! ✦», nombre latino, lección, XP y entrada
  en el Códice. El servidor anuncia que alguien descubrió *un* secreto (sin revelarlo).
- El anunciador sigue dando pistas cuando alguien se atasca, pero el premio es para quien
  lo descubre.
- Completar el Códice: título «Erudito de Lerna».

## 5. Comunidad

- **Hermandad:** +15 % de XP por cada aliado (máx. +45 %).
- **Mentor:** un jugador de nivel 8+ con un novato (nivel 1–3) en el grupo gana +50 XP.
- **Reanimar** da XP, cuenta para el título «Hermano de Armas» y es un secreto del Códice.
- **Ofrendas al templo:** cada Hidra vencida en el servidor suma; con 5, Juegos Imperiales
  para todos. El que falta para la meta tiene una razón para ayudar.
- **Unirse en caliente:** cuando alguien desafía a la Hidra, el servidor lo anuncia e
  invita a entrar por la puerta.

## Medir (cuando haya jugadores)

Duración de sesión, partidas por sesión, % que vuelve al día siguiente y a los 7 días,
% de partidas en grupo y cuántos descubren cada secreto sin pista. Se añadirá con
`AnalyticsService` (POR VERIFICAR las funciones exactas).
