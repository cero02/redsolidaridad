# 0009 — Streaming de instancias: coliseo e Hidra como modelos persistentes

**Estado:** Aceptado (2026-11-12)

## Contexto
Los lugares nuevos de Roblox (también la plantilla Baseplate) tienen
`Workspace.StreamingEnabled` activado. Con streaming, el cliente solo recibe las piezas
cercanas al jugador. El jugador aparece en el Foro, lejos del Gran Coliseo, así que:
- la cámara del menú de inicio sobrevolaba un coliseo que el cliente aún no tenía;
- `CrowdController` buscaba al público al arrancar y no encontraba a nadie;
- los cuellos y la mirada de la Hidra (`HydraViewController`) dependen de que el cliente
  tenga las cabezas completas.

## Decisión
- El servidor marca `GranColiseo` y `Hydra` (y sus submodelos de cabezas, muñones y
  cadenas) con `Model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent`: se envían
  completos y nunca se descargan.
- No se desactiva el streaming del lugar: el resto del mundo (Foro, colinas) puede seguir
  cargándose por cercanía, y la solución funciona en cualquier place sin depender de cómo
  esté configurado en Studio.

## Consecuencias
- El cliente puede usar `WaitForChild("GranColiseo")` y encontrar todo su contenido.
- Coste: el coliseo (~340 piezas) y la Hidra (~550) siempre están en memoria del cliente.
  Es aceptable para el tamaño actual; revisar si el mundo crece mucho.
- Lo que el cliente necesite completo en el futuro debe marcarse también como `Persistent`.
