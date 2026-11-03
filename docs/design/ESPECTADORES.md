# Diseño: Espectadores (hito 1.6, incluido en la Versión 1)

El coliseo es un espectáculo: ver jugar a otros debe ser divertido y dar ganas de bajar a
la arena.

## Cómo funciona

- El servidor tiene un **foro** (lobby) y el **Gran Coliseo**. Mientras un grupo lucha,
  cualquiera del foro puede subir a las **gradas**.
- Desde las gradas: cámara libre limitada a las gradas, o cámara que sigue a un luchador
  (cambiar con Q/E o deslizando en móvil).
- Interfaz de espectador: vida de la Hidra por fase, luchadores con su arma y su vida, y
  tiempo de combate.

## Participación del público (solo cosmética)

- **Pulgar arriba / abajo**, aplausos y vítores: animaciones y sonido del público.
- Cuando muchos espectadores aplauden, el anunciador lo menciona y suena el rugido del público.
- **No afecta al combate**: ni daño, ni vida, ni recompensas. Así no hay abusos ni
  ventajas injustas.

## Reglas técnicas

- Los espectadores no pueden enviar acciones de combate: el servidor las ignora.
- El límite de peticiones de las reacciones es estricto (1 cada 2 s por jugador).
- Si el servidor va cargado, el número de espectadores se limita.
