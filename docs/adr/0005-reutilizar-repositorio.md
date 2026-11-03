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
- `firebase-config.js` (configuración del proyecto Firebase `red-solidaridad`) también se
  elimina, por decisión del equipo. Sigue en el historial y en la rama de respaldo.
- La web publicada en GitHub Pages se retira: se eliminan sus archivos de `main`.

## Consecuencias
- La web RedSolidaria deja de estar online. Conviene desactivar también GitHub Pages en
  Settings → Pages para que no publique el contenido de COLOSSEUM.
- El proyecto Firebase `red-solidaridad` sigue existiendo en Firebase; este repositorio ya
  no lo usa.
- La web se puede recuperar en cualquier momento desde la rama de respaldo.
