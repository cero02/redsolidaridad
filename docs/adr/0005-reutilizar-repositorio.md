# 0005 — Reutilizar el repositorio `redsolidaridad`

**Estado:** Aceptado (2026-11-03)

## Contexto
El equipo decidió reutilizar el repositorio `cero02/redsolidaridad` para COLOSSEUM, sin
crear otro ni cambiar el remoto. Contenía la web **RedSolidaria** (React + Firebase), que
sigue publicada en GitHub Pages desde `main`.

## Decisión
- Se conserva todo el historial de git. No se reescribe ni se hace force push.
- Copia de seguridad: rama `backup/redsolidaria-2026-11-03` (commit `22d2e60`).
- Se eliminan `index.html` y `admin.html` (web RedSolidaria) en la rama de trabajo.
- `firebase-config.js` (configuración del proyecto Firebase `red-solidaridad`) **se
  conserva** hasta que el equipo confirme qué hacer con él; no lo usa COLOSSEUM.

## Consecuencias
- Al fusionar en `main`, la web de GitHub Pages dejará de funcionar. Antes hay que decidir
  si se traslada a otro sitio o se desactiva Pages.
- La web se puede recuperar en cualquier momento desde la rama de respaldo.
