# Prueba manual — Hito 1.3: la Hidra completa

## Preparación

1. En una segunda ventana de PowerShell: `cd Documents\colosseum` y `git pull`.
2. `rojo serve` en marcha y Studio conectado. Pulsa **Jugar** (F5).

## Novedades visuales (v0.4.1)

- [ ] El personaje lleva **gladius** en la mano derecha y **escudo** rojo en el brazo izquierdo.
- [ ] Al atacar, el brazo sube y baja, y la espada deja una **estela** blanca.
- [ ] El golpe pesado empuja con el **escudo** (brazo izquierdo).
- [ ] Al bloquear, el brazo del escudo se levanta.
- [ ] La cámara tiembla un poco al golpear y más al recibir daño.
- [ ] Los cuellos de la Hidra **ondulan**.
- Si la espada apunta en una dirección rara o un brazo gira al revés, dímelo: depende del
  tipo de avatar (R15 o R6) y se corrige con un número.

## La pelea completa

### Fase I — Las tres cabezas (igual que antes)
Corta cabezas cuando quedan en el suelo tras morder, enciende el arma en un brasero y
cauteriza **3 cuellos**.

### Fase II — La furia
La Hidra se hunde 4 segundos y vuelve con **5 cabezas**. Novedades:

| Aviso | Ataque | Cómo evitarlo |
|---|---|---|
| Varias franjas rojas seguidas | Cadena de mordiscos (hasta 3) | Esquiva con ritmo; deja 3 cabezas en el suelo: ¡aprovecha! |
| Media arena en verde | Nube tóxica (6 s) | Cruza a la otra mitad |
| Círculo azul claro bajo tus pies | Inmersión (35 de daño) | Muévete o esquiva |
| «¡La Hidra ha apagado un brasero!» | Un brasero sin fuego | Mantén **E** 2 s para reavivarlo |
| Cabezas naranjas y 3 bolas de fuego | Te persiguen (18 de daño cada una) | Cambia de rumbo en el último momento o esquiva con **Q**. Secreto: una parada perfecta las devuelve |

Cauteriza **3 cuellos** más.

### Fase III — La cabeza inmortal
Emerge una **cabeza dorada** que no se puede cortar.

1. Su mordisco hace 40 de daño. Tras morder queda en el suelo ~2 s.
2. **Atúrdela**: con una **parada perfecta** (bloquear justo antes del mordisco) o con un
   **golpe pesado** (mantener clic y soltar) mientras está en el suelo. Se pone gris: «ATURDIDA» (6 s).
3. Mientras está aturdida, corre a uno de los **3 postes de hierro** y golpéalo hasta
   romper la cadena (2–3 golpes).
4. Repite hasta romper las **3 cadenas**: la roca cae y la entierra. **¡VICTORIA!**

Al ganar verás tu **tiempo** y si has batido tu **récord personal**.

## Bolas de fuego (v0.5.1)

Aparecen en la fase II y con la cabeza inmortal.

- [ ] Las cabezas se ponen naranjas y salen 3 bolas de fuego, una tras otra.
- [ ] Te siguen, pero si corres en línea recta y giras de golpe, pasan de largo.
- [ ] Esquivar (Q) justo al tocarte: «¡Esquivado!», sin daño.
- [ ] Si te alcanzan: explosión y 18 de daño.
- [ ] **Secreto:** bloquear justo antes del impacto (parada perfecta) la devuelve en dorado
      contra una cabeza: le quita 45 de vida. Contra la cabeza dorada, la **aturde**.
      Descubrimiento **Ignis Reflexus**.
- [ ] Tras la tercera andanada sin descubrirlo, el anunciador da una pista.

## Caídos y reanimación

- **En solitario:** la primera vez que llegues a 0 de vida, el público te levanta a los
  3 s con el 30 % de vida. La segunda vez, mueres.
- **En grupo:** quien llega a 0 queda **caído** 15 s sin poder moverse. Un compañero lo
  levanta manteniendo **E** 3 s junto a él (vuelve con el 40 %). Si cae el último, todos mueren.

## Lista de comprobación

- [ ] Tras 3 cuellos cauterizados: la Hidra se hunde y vuelve con 5 cabezas.
- [ ] El título de arriba cambia a «Fase II».
- [ ] Cadena de mordiscos, nube tóxica e inmersión aparecen y dañan como se describe.
- [ ] Se apaga un brasero y se puede reavivar. Nunca se apagan todos.
- [ ] Tras 3 cuellos más: aparece la cabeza dorada y la roca con cadenas ya estaba arriba.
- [ ] Golpe normal a la cabeza dorada: aviso de que el acero rebota.
- [ ] Parada perfecta o golpe pesado en el suelo: «ATURDIDA».
- [ ] Golpear un poste sin aturdirla: aviso. Aturdida: la cadena se rompe.
- [ ] Tercera cadena: la roca cae, «¡VICTORIA!» con tiempo y récord.
- [ ] Segunda victoria más lenta: muestra «Tu récord: …». Más rápida: «NUEVO RÉCORD».
- [ ] Solitario: te levantas una vez; la segunda mueres y vuelves al foro.
- [ ] Dos jugadores: caer, ser reanimado, y que caigan ambos.

## Qué queremos saber

1. ¿Cuánto dura la pelea entera? (objetivo: 6–9 minutos)
2. ¿Se descubre solo cómo vencer a la cabeza inmortal, con las pistas del anunciador?
3. ¿Da tiempo a llegar a una cadena en los 6 s de aturdimiento?
4. ¿Qué fase es la más divertida y cuál la más frustrante?
5. ¿Va fluido en tu equipo? (ahora hay menos público y sin sombras en las gradas)

Números en `src/serverOnly/Config/Hydra.luau`.

## Grupo de 1 a 4 (máximo por partida)

En Studio: **Prueba → Clientes y servidores**, elige **5 jugadores** e **Iniciar**.

- [ ] Los cuatro primeros que pulsan **Desafiar a la Hidra** entran en la misma partida.
- [ ] El quinto **no entra**: ve «La arena está llena (4 gladiadores)…» y se queda en el Foro.
- [ ] Al terminar el combate, el quinto puede desafiar a la Hidra con normalidad.
- [ ] Con más gladiadores las cabezas aguantan más golpes: ×1,7 con 2, ×2,3 con 3 y
      ×2,9 con 4 (`GROUP_HEALTH` en `src/serverOnly/Config/Hydra.luau`). Si alguien entra
      o sale a mitad de partida, el cambio se nota en los golpes siguientes.

## Limitaciones conocidas

- Todo sigue siendo de bloques. Las animaciones son provisionales, hechas por código
  (brazos al atacar y bloquear, estela de la espada, temblor de cámara). Sin sonidos.
- Aún no hay experiencia ni desbloqueos (hito 1.5) ni más armas (hito 1.4).
- El récord se guarda en el perfil; en Studio los datos son simulados y se pierden al parar.
