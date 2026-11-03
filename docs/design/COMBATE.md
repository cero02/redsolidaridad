# Diseño: Combate

Objetivo del hito 1.1: **que golpear se sienta bien** antes de construir ninguna bestia.

Todos los números son **valores iniciales**: se ajustan en `src/shared/Config/Combat.luau`
tras cada prueba con jugadores.

## Principios

1. **Legible:** todo ataque enemigo se anuncia antes de golpear (telegrafiado).
2. **Justo:** si viste el aviso y reaccionaste a tiempo, te salvas, aunque tengas lag.
3. **Con peso:** cada golpe tiene sonido, pausa de impacto y reacción visible.
4. **Decisiones:** atacar, esquivar o bloquear siempre tiene un coste (aguante o tiempo).

## Acciones del gladiador

| Acción | PC | Mando | Móvil | Coste | Notas |
|---|---|---|---|---|---|
| Ataque ligero | Clic izq. | R1/RB | Botón | — | Combo de 3 golpes |
| Ataque pesado | Mantener clic izq. | R2/RT | Mantener botón | — | Carga 0,6 s, rompe guardia |
| Esquiva | Q / Espacio doble | Círculo/B | Botón | 25 aguante | Invulnerable 0,35 s |
| Bloqueo | Clic der. (mantener) | L1/LB | Botón | aguante por golpe | Reduce el daño un 70 % |
| Parada perfecta | Bloquear justo antes del golpe | — | — | — | Ventana 0,2 s: sin daño, aturde |
| Esencia | E | L2/LT | Botón | Recarga | Poder de la esencia equipada |
| Definitiva | R (con medidor lleno) | L3+R3 / Y | Botón | Medidor | Ver armas |

Controles con `ContextActionService` para soportar PC, mando y móvil con la misma lógica.

## Recursos

| Recurso | Valor inicial | Regla |
|---|---|---|
| Vida | 100 | Sin regeneración en combate (salvo esencias) |
| Aguante | 100 | Se recupera 30/s tras 0,8 s sin gastar |
| Medidor definitivo | 0–100 | +1 por cada 10 de daño causado, +15 por parada perfecta, +5 por esquiva ajustada |

## Sensación de impacto ("game feel")

- **Pausa de impacto:** 50 ms (ligero) y 90 ms (pesado), solo en el cliente que golpea.
- **Vibración de cámara** breve en golpes pesados y al recibir daño.
- **Sonido por material:** carne, escama, piedra y metal.
- **Números de daño** opcionales (ajuste del jugador).
- **Animación de reacción** del objetivo en cada golpe.

## Autoridad y latencia

El cliente reproduce la animación al instante. El servidor decide el resultado.

1. El cliente envía `CombatAction(action, comboStep)`.
2. El servidor valida:
   - tipos y límite de peticiones;
   - estado: vivo, en partida, sin aturdimiento;
   - ritmo: tiempo mínimo entre acciones según el arma (más un margen de 80 ms por latencia);
   - aguante suficiente.
3. **Golpes del jugador:** el servidor calcula la zona de impacto delante del personaje
   (`Workspace:GetPartBoundsInBox` con `OverlapParams`) en el momento activo del ataque.
4. **Golpes de la bestia:** al final del aviso, el servidor comprueba quién está en la zona.
   Si un jugador inició la esquiva antes del final del aviso (tiempo del servidor + margen
   de 150 ms), se libra.
5. El servidor replica el resultado a todos (`CombatEvent`): daño, aturdimiento, efectos.

## Dificultad

| Modo | Vida de la bestia | Daño recibido | Avisos |
|---|---|---|---|
| Normal | ×1,0 | ×1,0 | 0,9–1,4 s |
| Heroica (tras primera victoria) | ×1,4 | ×1,5 | 0,6–1,0 s, más patrones |

## Escalado por grupo (1–4 jugadores)

| Jugadores | Vida de la bestia | Notas |
|---|---|---|
| 1 | ×1,0 | Patrones más lentos |
| 2 | ×1,7 | |
| 3 | ×2,3 | |
| 4 | ×2,9 | La bestia reparte ataques entre objetivos |

## Caídos y reanimación (cooperativo)

- Con 0 de vida el jugador queda **caído** 15 s.
- Un compañero lo reanima manteniendo la interacción 3 s (vuelve con 40 % de vida).
- Si todos caen, la partida se pierde. En individual, una vez por partida te levantas
  solo con el 30 % de vida ("el público te concede otra oportunidad").
