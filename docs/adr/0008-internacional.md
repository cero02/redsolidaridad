# 0008 — Juego internacional: inglés como base y español completo

**Estado:** Aceptado (2026-11-12)

## Contexto
COLOSSEUM debe ser un juego internacional. Todos los textos estaban en español y fijos en
el código. Roblox puede traducir automáticamente desde el idioma base, pero los textos
dinámicos (con números, nombres o claves) necesitan un sistema propio.

## Decisión
- **Inglés es el idioma base** del juego; **español** completo. Estructura lista para más.
- Todos los textos visibles viven en `src/shared/Locale/Strings/{En,Es}.luau` con
  marcadores `{nombre}`. Los archivos de configuración guardan solo identificadores.
- El servidor **no envía frases**: envía claves y parámetros (anunciador, noticias,
  resultados, progreso) y cada cliente las traduce a su idioma.
- Textos del mundo (carteles, avisos de interacción, letreros): el servidor los marca con
  atributos `L_<Propiedad>` y la etiqueta `Localized`; `LocalizeController` los traduce.
- Idioma por defecto: el de la cuenta de Roblox del jugador; se puede cambiar en Ajustes
  y se guarda en el perfil (`settings.language`), junto con música, temblor y modo ligero.
- `tests/Locale.spec.luau` falla si falta una clave en algún idioma, si los marcadores no
  coinciden o si un título, secreto, edicto, arma, esencia o desbloqueo no tiene texto.

## Consecuencias
- Regla nueva en CLAUDE.md: ningún texto visible escrito directamente en el código.
- Añadir un idioma = un archivo `Strings/Xx.luau` y una línea en `Locale.luau`.
- Recomendado: activar en el Creator Dashboard la traducción automática de Roblox para
  otros idiomas a partir del inglés.
