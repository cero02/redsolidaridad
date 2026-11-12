# Música de COLOSSEUM

El tema principal, **«Steel Against Stone»** (3:01), está en
`assets/audio/Steel_Against_Stone.mp3`. Suena:

| Momento | Volumen |
|---|---|
| Pantalla de inicio | Alto |
| El Foro | De fondo |
| La arena | Medio-alto |
| Victoria | Sube |

Cambia con fundidos suaves y cada jugador ajusta el volumen en **Ajustes** (0 %, 35 %,
70 % o 100 %; se guarda en su perfil).

## Activarla (una sola vez)

Roblox solo reproduce audio subido a Roblox:

1. Abre tu lugar en Studio.
2. **Ventana → Administrador de recursos** (Asset Manager) → botón **Importar**
   (Bulk Import) → elige `assets/audio/Steel_Against_Stone.mp3`.
3. Cuando termine, clic derecho sobre el audio → **Copiar ID de recurso**.
   Es un número, por ejemplo `1234567890`.
4. Abre `src/shared/Config/Audio.luau` y pon ese número en `MAIN_THEME`:
   ```lua
   MAIN_THEME = 1234567890,
   ```
5. Guarda. Con `rojo serve` en marcha, pulsa **Jugar**: la música suena en el menú.

Si más adelante hay una pista distinta para la arena, súbela igual y pon su número en
`ARENA_THEME`.

## Derechos

Roblox exige tener derechos sobre el audio que se sube. Si la música se ha creado con
una IA de música (Suno, Udio…), comprobad que vuestro plan permite **uso comercial**;
en muchos servicios, el plan gratuito no lo permite.
