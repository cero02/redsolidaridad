# 0003 — Persistencia de datos: ProfileStore

**Estado:** Aceptado (2026-11-03), en prueba durante el hito 1.0. Aprobado por el equipo.

## Contexto
Necesitamos guardar perfiles con bloqueo de sesión (evitar duplicación de objetos entre
servidores), autoguardado y guardado al cerrar. Hacerlo bien sobre `DataStoreService` es
delicado.

## Revisión realizada (2026-11-03)

| Criterio | Resultado |
|---|---|
| Autor | loleris (MadStudio), autor también de ProfileService, su predecesor muy usado |
| Repositorio | `MadStudioRoblox/ProfileStore`, no archivado |
| Licencia | Apache-2.0 |
| Documentación | https://madstudioroblox.github.io/ProfileStore/ y hilo del DevForum |
| Versión oficial en Wally | `lm-loleris/profilestore` **1.0.3** (realm `server`) |
| Actividad | Pocos cambios recientes. En el DevForum el autor responde con poca frecuencia desde 2025; varias preguntas quedan sin respuesta |
| Compatibilidad | Hay varias *forks* en Wally cuyo motivo declarado es que los tipos dan error con el **nuevo solucionador de tipos de Luau**. Indica posibles avisos de tipos en modo estricto (POR VERIFICAR en Studio) |
| Riesgos conocidos | En Team Test puede quedarse esperando por `MessagingService`; el autor recomienda el modo mock en pruebas. La opción `Steal` no está pensada para producción |

**Valoración:** biblioteca madura y estable, con mantenimiento bajo, pero el problema que
resuelve no cambia a menudo. El riesgo principal es la compatibilidad de tipos y la falta
de soporte activo.

## Propuesta
1. Adoptar `lm-loleris/profilestore@1.0.3` (versión exacta) **solo** a través de
   `PlayerDataService`. Ningún otro módulo la usa directamente.
2. Antes de aceptar, en la Etapa 1:
   - Revisar el código fuente de la versión fijada.
   - Probar en Studio: carga, guardado, salida del jugador, `BindToClose` y dos servidores
     con el mismo jugador.
   - Comprobar los avisos de tipos con `--!strict`.
3. Alternativa si falla: implementación propia de bloqueo de sesión sobre `DataStoreService`
   (más trabajo y más riesgo de errores). No se recomienda usar *forks* de terceros.

## Consecuencias
- Si se acepta: añadir Wally a `default.project.json` (`ServerStorage.ServerPackages`).
- El adaptador permite cambiar de biblioteca sin tocar el resto del juego.

## Revisión del código fuente (2026-11-03)

- Paquete `lm-loleris/profilestore@1.0.3` descargado con Wally: un único archivo
  `ProfileStore.luau` (2 242 líneas), licencia Apache-2.0, sin dependencias.
- Servicios que usa: `DataStoreService`, `MessagingService`, `RunService` y
  `HttpService:GenerateGUID` (solo genera identificadores; **no hace peticiones HTTP**).
  Sin `loadstring`, sin `require` externos.
- El paquete incluye `ProfileStoreTest.server.luau`, pero su `default.project.json` solo
  exporta `ProfileStore.luau`: el script de pruebas **no entra** en el place (verificado
  con `rojo build`).
- En Studio sin acceso a la API, ProfileStore lo detecta y no guarda. Aun así usamos
  `.Mock` en Studio por defecto (`DataConfig.USE_LIVE_DATA_IN_STUDIO`), lo que evita el
  bloqueo conocido de `MessagingService` en Team Test.
- Constantes por defecto: autoguardado cada 300 s, robo de sesión tras 40 s de conflicto.

## Uso en COLOSSEUM

`src/server/Services/PlayerDataService.luau` es el único módulo que lo usa: sesión por
`UserId`, `AddUserId` (GDPR), `Reconcile`, migraciones propias (`Data/Migrations.luau`),
expulsión si la sesión se pierde y `EndSession` al salir.
