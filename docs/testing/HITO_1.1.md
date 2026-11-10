# Prueba manual — Hito 1.1: sensación de combate

Este hito no se puede probar fuera de Roblox Studio. Sigue estos pasos y anota lo que no
funcione o no se sienta bien.

## Preparación

1. `git pull`, `rokit install`, `wally install`.
2. `rojo serve`, abre en Studio un place con la **Baseplate** por defecto y conecta el plugin.
3. Pulsa **Play**.

## Qué debe aparecer

- En Output: `[COLOSSEUM] servidor v0.2.0`, `[COLOSSEUM][Servidor] 4 módulos iniciados`,
  `[COLOSSEUM] cliente v0.2.0`, `[COLOSSEUM][Cliente] 2 módulos iniciados` y
  `Perfil recibido: nivel 1, arma Gladius`. Sin errores en rojo.
- Abajo a la izquierda: tres barras (vida roja, aguante verde, definitiva amarilla, vacía).
- Un **muñeco** marrón a unos 20 studs del origen con el texto `Muñeco 200/200`.
  Si tu punto de aparición está lejos, cambia `POSITION` en
  `src/serverOnly/Config/TrainingDummy.luau`.

## Controles

| Acción | PC | Mando | Móvil |
|---|---|---|---|
| Ataque ligero | Clic izquierdo | R1 / RB | Botón «Atacar» |
| Ataque pesado | Mantener clic izquierdo (0,35 s) y soltar | Mantener R1 | Mantener «Atacar» |
| Bloquear | Clic derecho o F (mantener) | L1 / LB | «Bloquear» |
| Esquivar | Q | B / Círculo | «Esquivar» |

## Lista de comprobación

- [ ] **Ataque ligero:** aparece una caja blanca delante (zona de golpe provisional), el
      muñeco parpadea en blanco y pierde 12 de vida. Sale `-12` en pantalla.
- [ ] **Combo:** tres clics seguidos hacen 12, 12 y 18. Tras una pausa vuelve a 12.
- [ ] **Ataque pesado:** caja naranja, 15 de daño y el muñeco se pone amarillo (aturdido).
- [ ] **Definitiva:** la barra amarilla sube al hacer daño.
- [ ] **Derrotar al muñeco:** se pone gris, «Derrotado», y reaparece a los 3 s.
- [ ] **Ataque del muñeco:** cerca de él, cada ~4 s se pone **rojo** 1 s («¡Cuidado!») y golpea.
  - [ ] Sin hacer nada: «¡Golpeado!», −15 de vida.
  - [ ] Esquivar (Q) justo antes del golpe: «¡Esquivado!», sin daño, baja el aguante.
  - [ ] Bloquear desde antes: «Bloqueado», −4,5 de vida y −20 de aguante.
  - [ ] Bloquear justo antes del golpe (0,3 s): «¡PARADA PERFECTA!», sin daño, el muñeco
        queda aturdido (amarillo) y sube la definitiva.
- [ ] **Aguante:** tras 4 esquivas seguidas no deja esquivar; se recupera al esperar.
- [ ] **Bloqueando** caminas más lento.
- [ ] **Morir:** con 0 de vida el personaje muere y reaparece con todo al máximo.
- [ ] **Dos jugadores** (Test → Start con 2 jugadores): cada uno ve su propia interfaz y
      ambos pueden golpear al muñeco.

## Qué queremos saber (lo más importante)

1. ¿El ritmo de los ataques se siente rápido, lento o bien?
2. ¿La esquiva recorre la distancia adecuada? ¿Se siente ágil?
3. ¿El aviso de 1 s del muñeco da tiempo a reaccionar? ¿La parada perfecta es alcanzable?
4. ¿Algún retraso molesto entre pulsar y ver el resultado?

Todos los números están en `src/shared/Config/Combat.luau` y `Weapons.luau`: se ajustan
sin tocar la lógica.

## Limitaciones conocidas de este hito

- **Sin animaciones ni sonidos:** necesitan recursos creados o subidos en Studio. La caja
  de colores es un sustituto temporal.
- El ataque ligero se lanza al **soltar** el botón (para distinguirlo del pesado).
- El servidor todavía no vigila la velocidad de movimiento del jugador (anti-trampas de
  movimiento): se añadirá antes del lanzamiento.
- Los jugadores no pueden golpearse entre sí (el PvP llega en la Versión 3).
