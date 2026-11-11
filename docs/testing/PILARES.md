# Prueba manual — Los cinco pilares (v0.5.0)

## Preparación
`git pull` en PowerShell (dentro de `colosseum`), `rojo serve` en marcha, Studio conectado
y **Jugar**. En Studio los datos son simulados: el progreso se reinicia al parar.

## Al aparecer, en el foro
- [ ] Arriba a la izquierda: **Nv 1 · Tiro**, barra de XP y «Nv 2: Hasta (lanza)».
- [ ] Botones **Título: «Tiro» ▸** y **Códice 0/11**.
- [ ] Caja del **Edicto del César** con el decreto de esta semana y «termina en …».
- [ ] Sobre tu personaje: «Tiro» y «Nv 1 · Tiro».
- [ ] Arriba a la derecha (tabla de Roblox): columnas **Nivel** y **Victorias**.
- [ ] Junto a la puerta: lápida clara **EDICTO DEL CÉSAR** y lápida oscura **SALÓN DE LEYENDAS**.
- [ ] **Códice:** se abre un libro con 11 acertijos «???».

## Descubrimientos (pilar inteligencia)
- [ ] Parada perfecta contra el muñeco (clic derecho justo antes de su golpe):
      aviso morado **¡DESCUBRIMIENTO! PARMA PERFECTA**, +50 XP, Códice 1/11.
- [ ] Abajo a la derecha aparece la noticia «… ha descubierto un secreto de la Hidra».
- [ ] En la Hidra: cauterizar (Ignis Purgat), saltar el coletazo (Saltus), dejar que
      crezcan 5 cabezas (Hydra Multiplex), reavivar un brasero (Ignis Renatus), aturdir la
      cabeza dorada (Caput Aureum), dejar caer la roca (Saxum Cadit).

## Al terminar una partida (pilares progreso y presumir)
- [ ] Pantalla de **resultados**: tiempo, récord, desglose de XP, total, subida de nivel,
      desbloqueos y «Próximo: …». Botón «¡Otra vez!».
- [ ] Noticia al servidor: «¡… han vencido a la Hidra en 7:12!».
- [ ] Título del Edicto conseguido y equipado; la placa sobre la cabeza cambia.
- [ ] El tiempo aparece en el **Salón de Leyendas**.
- [ ] «Ofrendas al templo: 1/5» en la lápida y en la caja del Edicto.
- [ ] Al subir de nivel aparecen **cosméticos**: nivel 3 emblema en el escudo, nivel 6 casco.
- [ ] El botón de título cambia entre los títulos conseguidos.

## Comunidad (con 2 jugadores: Prueba → Iniciar con 2 jugadores)
- [ ] El segundo ve la noticia «… desafía a la Hidra. ¡Aún puedes unirte!».
- [ ] Al ganar juntos, el desglose muestra **Hermandad (+15 %)**.
- [ ] Reanimar a un compañero: +XP y descubrimiento **Frater**.

## Juegos Imperiales (FOMO sano)
Surgen solos cada 15–25 minutos o con 5 Hidras vencidas en el servidor. Para probar
rápido, baja `OFFERING_GOAL` a 1 en `src/server/Services/EventService.luau`.
- [ ] Noticia **¡ALERTA IMPERIAL!**, banner dorado parpadeante «¡JUEGOS IMPERIALES! XP ×2».
- [ ] Ganar durante los Juegos: XP doble y título «Testigo de los Juegos».

## Qué queremos saber
1. ¿La pantalla de resultados da ganas de jugar otra?
2. ¿Te dieron ganas de descubrir los acertijos del Códice?
3. ¿Se lee bien la interfaz en tu pantalla o tapa el combate?
4. ¿Las noticias del servidor son útiles o demasiadas?
