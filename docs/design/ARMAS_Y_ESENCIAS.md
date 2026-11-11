# Diseño: Armas, esencias y definitivas (Versión 1)

Tres armas y tres esencias. Combinaciones posibles: 3 × 3 = **9 construcciones**, y ninguna
es la mejor en todo.

## Armas

### Gladius y escudo — el equilibrado
*El arma del gladiador clásico.*

| Ligero (×3) | Pesado | Especial | Definitiva |
|---|---|---|---|
| 12 / 12 / 18 de daño, rápido | Golpe de escudo: 15 + aturde 0,8 s | Parada perfecta más amplia (0,3 s) | **Testudo:** tú y los aliados a menos de 14 studs sois inmunes 4 s |

Bueno en: defensa y aturdir la cabeza inmortal. Débil en: daño en área.

### Hasta (lanza) — el alcance
*La lanza de la infantería romana.*

| Ligero (×3) | Pesado | Especial | Definitiva |
|---|---|---|---|
| 10 / 10 / 14, alcance largo (9–10 studs) | Estocada a la carrera: 28 y avanza | Esquiva más barata (20 de aguante) | **Lluvia de pila:** 6 jabalinas en una zona, 20 c/u |

Bueno en: atacar cabezas desde lejos y moverse. Débil en: bloqueo (solo el 50 %).

### Martillo del Coloso — el destructor
*Tan pesado que solo los campeones lo levantan.*

| Ligero (×3) | Pesado | Especial | Definitiva |
|---|---|---|---|
| 18 / 18 / 30, lento | Golpe al suelo: 35 + onda de 4 m | Rompe guardias y aturde más | **Terremoto:** 3 ondas expansivas, 30 c/u, derriba |

Bueno en: daño y romper cadenas (fase 3). Débil en: velocidad y aguante (esquiva cuesta 35).

## Esencias

Una esencia equipada en la Versión 1 (más ranuras en versiones posteriores).

| Esencia | Cómo se obtiene | Poder (tecla Z) | Pasiva |
|---|---|---|---|
| **Loba de Roma** | Inicial | *Instinto:* 4 s de +30 % velocidad y esquiva sin coste. Recarga 18 s | +10 % aguante |
| **Águila imperial** | Nivel 5 | *Picado:* salto alto y caída con daño 25 en área. Recarga 14 s | *Garras:* los ataques pesados hacen +20 % de daño |
| **Hidra** | Vencer a la Hidra | *Veneno:* 6 s de +30 % de daño. Recarga 20 s | Regeneras 1 de vida/s si llevas 5 s sin recibir daño |

## Construcciones de ejemplo

| Nombre | Arma + esencia | Estilo |
|---|---|---|
| El Muro | Gladius + Loba | Aguanta, para y aturde |
| El Cazador | Hasta + Águila | Se mueve, salta y castiga desde lejos |
| El Verdugo | Martillo + Hidra | Lento pero imparable, se cura entre peleas |

## Equilibrio

- Cada arma debe poder vencer a la Hidra en individual y Normal.
- Objetivo: ningún arma con más de un 40 % de uso en las victorias Heroicas.
- Telemetría desde el principio: arma, esencia, duración, caídas y resultado de cada
  partida (`AnalyticsService` cuando se implemente; POR VERIFICAR las funciones exactas).

## Controles (hito 1.4)

| Acción | PC | Mando | Móvil |
|---|---|---|---|
| Poder de la esencia | **Z** | X / Cuadrado | Botón «Esencia» |
| Definitiva (medidor lleno) | **R** | Y / Triángulo | Botón «Definitiva» |

La tecla E queda libre para interactuar (puertas, braseros, reanimar).

## Decisiones del hito 1.4

- **Águila:** la pasiva «ver avisos antes» cambiaría el ritmo de la Hidra para un solo
  jugador en partidas de grupo; se sustituye por *Garras* (+20 % al pesado).
- **Hidra:** el veneno por segundo sobre cabezas que se cortan y regeneran era confuso; se
  simplifica a un bonus de daño claro y visible.
- **Testudo:** protege también a los aliados cercanos (pilar comunidad: la formación romana).
