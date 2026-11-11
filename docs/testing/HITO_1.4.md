# Prueba manual — Hito 1.4: armas, esencias y definitivas (v0.6.0)

## Preparación
`git pull`, `rojo serve`, Studio conectado y **Jugar**. En Studio el progreso se reinicia
al parar: para probar armas bloqueadas, sube de nivel venciendo a la Hidra o, solo para
pruebas, baja `unlockLevel` y los niveles de `UNLOCKS` en la configuración.

## Armería
- [ ] Arriba a la izquierda, botón **Armería** junto al Códice.
- [ ] Panel «ARMERÍA DEL LUDUS» con 3 armas y 3 esencias. Lo bloqueado sale con 🔒 y
      dice cómo conseguirlo (nivel 2 Hasta, nivel 4 Martillo, nivel 5 Águila, vencer a la
      Hidra para su esencia).
- [ ] Al elegir otra arma, el personaje cambia de arma en la mano al instante.
- [ ] Dentro de la arena no deja cambiar («En plena arena no se cambia de equipo»).

## Armas (contra el muñeco)
- [ ] **Gladius:** como antes; el pesado es golpe de escudo.
- [ ] **Hasta:** lanza larga sin escudo. Llega más lejos (≈10 studs). El pesado avanza
      con una estocada (28 de daño).
- [ ] **Martillo:** lento; 18/18/30. El pesado (35) deja una onda en el suelo y aturde.

## Esencias (tecla Z)
- [ ] Abajo, junto a las barras: «Z · Esencia…: lista» y la cuenta atrás tras usarla.
- [ ] **Loba:** 4 s más rápido y esquivas sin gastar aguante. Barra de aguante algo mayor.
- [ ] **Águila:** saltas muy alto y al caer golpeas la zona (onda azul, 25 de daño).
- [ ] **Hidra:** luz verde en la mano; 6 s de +30 % de daño. Se cura sola fuera de peligro.

## Definitivas (tecla R, con la barra amarilla llena)
- [ ] «R · …: ¡LISTA!» en dorado cuando está cargada.
- [ ] **Testudo (Gladius):** cúpula dorada; inmune 4 s («¡Testudo!» al recibir golpes).
      Con 2 jugadores, el aliado cercano también queda protegido.
- [ ] **Lluvia de pila (Hasta):** 6 jabalinas doradas caen delante.
- [ ] **Terremoto (Martillo):** 3 ondas a tu alrededor; aturden.

## Qué queremos saber
1. ¿Las tres armas se sienten distintas? ¿Alguna claramente mejor o peor?
2. ¿Qué combinación arma + esencia te gustó más contra la Hidra?
3. ¿La definitiva se carga demasiado rápido o demasiado lento?
4. ¿El salto del Águila es divertido o incómodo?
