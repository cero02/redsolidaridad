# 0007 — Retención: cinco pilares y FOMO sano

**Estado:** Aceptado (2026-11-11)

## Contexto
El equipo quiere que el juego tenga bien arraigados cinco motivos para volver: progreso,
presumir, FOMO, sentirse inteligente y comunidad. El FOMO (miedo a perderse algo) es
eficaz pero, mal usado, es un patrón oscuro, y el público de Roblox es mayoritariamente
menor de edad. CLAUDE.md ya prohíbe castigos por desconectarse, rachas que se pierden y
temporizadores que obligan a entrar.

## Decisión
- Se implementan los cinco pilares (diseño en `docs/design/PILARES.md`).
- El FOMO se limita a **"está pasando ahora"** y **"esta semana es especial"**:
  Edicto semanal rotativo y Juegos Imperiales en vivo.
- Tres reglas fijas: **todo vuelve** (nada exclusivo para siempre), **no se castiga la
  ausencia** y **nada de pago** en eventos.

## Consecuencias
- Las reglas de CLAUDE.md sobre monetización y presión siguen vigentes sin cambios.
- Si en el futuro se quiere un evento con premio irrepetible, requiere un ADR nuevo y la
  aprobación explícita del equipo.
