# Diseño: La Hidra de Lerna

> «Córtale una cabeza y crecerán dos. Así aprendió Hércules que no todo se vence con fuerza.»

Primera bestia de COLOSSEUM y corazón de la Versión 1. La pelea cuenta su mito: el jugador
descubre que cortar cabezas no basta, que hay que **cauterizarlas**, y que la última cabeza
es inmortal y hay que **enterrarla bajo una roca**.

Duración objetivo: **6–9 minutos** de combate dentro de una partida de 8–12.

## La arena

Gran Coliseo con el suelo inundado parcialmente (pantano de Lerna):
- **Estanque central:** la Hidra emerge de él. No se puede entrar (daño por veneno).
- **4 braseros** en el borde: sirven para encender el arma y cauterizar cuellos.
- **Roca suspendida** sobre el estanque, sujeta por 3 cadenas (fase 3).
- **Gradas** con público (y espectadores reales en el hito 1.6).

## Partes de la Hidra

| Parte | Vida (individual, Normal) | Notas |
|---|---|---|
| Cuerpo | No se daña directamente | La vida total es la suma de las cabezas cortadas |
| Cabeza mortal | 120 cada una | Al llegar a 0 se corta: queda un cuello sangrante |
| Cuello sangrante | — | En **10 s** crecen 2 cabezas, salvo que se cauterice |
| Cabeza inmortal | No se puede cortar | Solo aparece en fase 3 |

**Cauterizar:** golpear el cuello con el arma **encendida** en un brasero (dura 8 s) o con
la Esencia de León (versiones posteriores). Es el "descubrimiento" de la pelea: la primera
vez, el anunciador da una pista si el jugador ha dejado crecer cabezas dos veces.

## Fases

### Fase 1 — Las tres cabezas (100 %–60 %)
Empieza con 3 cabezas. Objetivo: aprender a cortar y cauterizar.

| Ataque | Aviso | Efecto | Cómo evitarlo |
|---|---|---|---|
| Mordisco | La cabeza se echa atrás y brillan los ojos (1,2 s) | 25 de daño en línea | Esquivar de lado |
| Escupitajo de veneno | Garganta hinchada y verde (1,0 s) | Charco 6 s, 8/s | Salir del círculo marcado |
| Barrido de cola | La cola asoma del agua (1,4 s) | 20 de daño y derriba, en semicírculo | Saltar o esquivar hacia la Hidra |

**Pasa a fase 2** cuando se han cortado y cauterizado 3 cabezas en total.

### Fase 2 — La furia (60 %–25 %)
La Hidra se sumerge, el agua se agita y emerge con **5 cabezas**.

Ataques nuevos:

| Ataque | Aviso | Efecto | Cómo evitarlo |
|---|---|---|---|
| Nube tóxica | Todas las cabezas inhalan (1,5 s) | Niebla en media arena, 5/s | Ir a la mitad limpia |
| Mordisco en cadena | Las cabezas se alinean (1,0 s + 0,4 s entre mordiscos) | 3 mordiscos seguidos | Esquivar con ritmo |
| Inmersión | Burbujas bajo un jugador (1,3 s) | Emerge bajo él, 35 de daño | Moverse |

Los braseros se apagan uno a uno durante 20 s (la Hidra los salpica): hay que **reencenderlos**
con una interacción de 2 s. En cooperativo crea un rol natural.

**Pasa a fase 3** al cortar 4 cabezas más.

### Fase 3 — La cabeza inmortal (25 %–0 %)
Las cabezas restantes se retiran y emerge la **cabeza dorada inmortal**.

1. La cabeza inmortal ataca con fuerza (mordiscos dorados de 40 de daño, aviso de 1,0 s).
2. Cada **parada perfecta** o golpe pesado en el ojo la aturde 3 s.
3. Mientras está aturdida, los jugadores **rompen una de las 3 cadenas** de la roca.
4. Rota la tercera cadena, la roca cae y **entierra la cabeza**. Victoria.

En individual, romper una cadena exige un aturdimiento. En cooperativo, dos jugadores pueden
romper dos cadenas a la vez si coordinan el aturdimiento: es el **momento memorable** que
queremos que la gente cuente.

## Patrones adaptativos

La Hidra elige el siguiente ataque por pesos. Los pesos cambian según la situación:

| Situación detectada | Ajuste |
|---|---|
| Todos los jugadores muy cerca | + Barrido de cola |
| Jugadores dispersos | + Escupitajo, + Inmersión |
| Un jugador lleva 20 s sin recibir ataques | + peso de atacarle a él |
| Un jugador ha recibido 3 ataques seguidos | − peso de atacarle (reparto justo) |
| Mismo ataque usado 2 veces seguidas | No se repite una tercera vez |
| Dificultad Heroica | Desbloquea combinaciones (escupitajo + mordisco) |

Reglas deterministas a partir de una semilla por partida: se pueden reproducir para
depurar y equilibrar.

## Recompensas

| Recompensa | Condición |
|---|---|
| **Esencia de Hidra** | Primera victoria (garantizada) |
| Escamas de Hidra (material) | Cada victoria, 3–5 |
| Experiencia | Ver `PROGRESION.md` |
| Título «Matahidras» | 10 victorias |
| Efecto cosmético «Sangre dorada» en el arma | Victoria en Heroica sin que caiga nadie |

## Audio y anunciador

El anunciador del coliseo narra los momentos clave: entrada de la Hidra, primera cabeza
cortada, cabezas que vuelven a crecer (con pista), cambio de fase, cabeza inmortal y
victoria. Frases cortas, en el idioma del jugador.
