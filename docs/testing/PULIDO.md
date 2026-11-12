# Prueba manual — v0.9 Pulido

## Preparación
`git pull`, `rojo serve`, Studio conectado y **Jugar**. Vale cualquier lugar (incluso la
plantilla Baseplate): el juego crea su propio mundo.

## Si algo falla: panel rojo
Solo en Studio, arriba al centro aparece un **panel rojo con los errores** del cliente y
del servidor. Si sale, **haz una captura y envíala**: con eso se corrige en minutos.

## Lo primero que ves
- [ ] Ya **no** hay cuadrícula gris ni el punto de aparición de Studio: suelo de tierra,
      colinas en el horizonte, cipreses, la plaza de mármol del Foro y luz de atardecer.
- [ ] La **pantalla de inicio** aparece sola con la cámara sobrevolando el coliseo.
- [ ] El **muñeco ya no existe**. En su lugar, una **estatua de bronce** de un gladiador
      con el gladius en alto.

## La Hidra
- [ ] **DESAFIAR A LA HIDRA** → apareces en la arena.
- [ ] La Hidra **emerge del estanque** (unos 3 s) y la cámara **tiembla**.
- [ ] El público **salta** con la presentación.
- [ ] Las cabezas **te siguen con la mirada** mientras no atacan y se balancean.
- [ ] A los ~5 s de empezar ya llega la primera **andanada de bolas de fuego** que te
      persiguen (en todas las fases).
- [ ] Los ataques llegan más seguidos que antes.
- [ ] El público salta al cortar una cabeza, cauterizar, romper una cadena o con una
      parada perfecta.

## Sonido
- [ ] Suena un **tajo** al atacar y otro más fuerte en el golpe pesado.
- [ ] Suena al **golpear** una cabeza y al hacer una **parada perfecta**.
- Si alguno no suena, dímelo: son sonidos que trae Roblox y alguno puede haber cambiado
  de ruta (se sustituye en `src/shared/Config/Audio.luau`).

## Primeros pasos (ahora dentro de la arena)
- [ ] Lista: desafiar a la Hidra, esquivar con Q, parada perfecta, cortar una cabeza,
      cauterizar un cuello. Se marcan solos.

## Qué queremos saber
1. ¿Se siente vivo ahora? ¿Qué sigue pareciendo "de prueba"?
2. ¿Las cabezas que te miran dan sensación de amenaza?
3. ¿Las bolas de fuego desde el principio son divertidas o demasiado?
