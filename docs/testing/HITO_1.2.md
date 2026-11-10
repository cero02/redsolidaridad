# Prueba manual — Hito 1.2: el Gran Coliseo y la Hidra (fase 1)

## Preparación

1. En PowerShell, dentro de la carpeta `colosseum`: `git pull`.
2. `rojo serve` en marcha y Studio conectado (lugar con Baseplate).
3. Pulsa **Jugar** (F5).

## Qué aparece solo

- Junto al punto de aparición: el muñeco de entrenamiento y una **puerta dorada** con el
  cartel «GRAN COLISEO».
- A lo lejos (200 studs): el coliseo con gradas, público, estanque central y 4 braseros.

## Cómo se juega

1. Acércate a la puerta dorada y mantén **E** («Entrar a la arena»).
2. Apareces en la arena. El anunciador presenta a la Hidra: 5 segundos para prepararte.
3. **La Hidra ataca siempre con aviso:**
   - **Franja roja** en el suelo y cabeza naranja → mordisco. Sal de la franja, esquiva (Q)
     o bloquea. Con parada perfecta la cabeza queda aturdida (amarilla) más tiempo.
   - **Círculo verde** → escupitajo: deja un charco de veneno 6 s. No lo pises.
   - **Círculo rojo junto al estanque** → coletazo. Sal, esquiva o **salta**.
   - El **estanque** está envenenado: no entres.
4. **Tras morder, la cabeza queda en el suelo ~2 s.** Es el momento de golpearla
   (90 de vida; el número sobre ella lo indica).
5. Al cortarla aparece un **muñón rojo** al borde del estanque con una cuenta atrás de 12 s.
   Si llega a cero: **vuelve la cabeza y nace otra**.
6. Para impedirlo: ve a un **brasero**, mantén **E** («Encender arma», dura 10 s) y
   **golpea el muñón** con el arma en llamas. Queda negro: «Cauterizado».
7. **Cauteriza 3 cuellos** para vencer. Vuelves al foro a los 9 s.

## Lista de comprobación

- [ ] El coliseo, la puerta, los braseros con fuego y el público aparecen.
- [ ] La puerta te lleva a la arena y sale el texto del anunciador.
- [ ] La Hidra tiene 3 cabezas con cuello y ojos amarillos. Los cuellos siguen a las cabezas.
- [ ] Mordisco: franja roja → la cabeza se lanza → queda en el suelo → vuelve.
- [ ] Golpear una cabeza en el suelo le quita vida (parpadea en blanco).
- [ ] Parada perfecta contra el mordisco: cabeza amarilla y más tiempo en el suelo.
- [ ] Escupitajo: círculo verde, daña 8 por segundo al pisarlo.
- [ ] Coletazo: círculo rojo, no daña si saltas o esquivas a tiempo.
- [ ] Cortar una cabeza: muñón rojo con cuenta atrás.
- [ ] Dejar pasar la cuenta atrás: vuelven dos cabezas y el anunciador lo dice.
- [ ] Brasero: sale fuego en la mano y el aviso «¡Arma en llamas!».
- [ ] Golpear el muñón **sin** fuego: aviso de que necesitas un brasero.
- [ ] Golpear el muñón **con** fuego: «Cauterizado» y sube el contador de arriba.
- [ ] Tercer cuello cauterizado: «¡VICTORIA!» y vuelta al foro.
- [ ] Morir: reapareces en el foro y puedes volver a entrar tras unos segundos.
- [ ] Dos jugadores: el segundo puede entrar por la puerta durante el combate.

## Qué queremos saber

1. ¿Se entiende qué hay que hacer sin leer esta guía? ¿Dónde te perdiste?
2. ¿Los avisos dan tiempo a reaccionar? ¿Algún ataque parece injusto?
3. ¿Da tiempo a ir del brasero al muñón (10 s de fuego, 12 s de cuenta atrás)?
4. ¿Cuánto dura la pelea? (objetivo de la fase 1: 3–4 minutos en individual)
5. ¿Las cabezas se mueven a saltos o con fluidez?

Números en `src/serverOnly/Config/Hydra.luau` y `Arena.luau`.

## Limitaciones conocidas

- Todo es de bloques: sin modelos, animaciones ni sonidos todavía.
- Las cabezas se mueven desde el servidor y pueden verse algo entrecortadas.
- Solo la fase 1. Las fases 2 y 3 (furia y cabeza inmortal) llegan en el hito 1.3.
- No hay reanimación de compañeros ni recompensas de experiencia todavía (1.3 y 1.5).
