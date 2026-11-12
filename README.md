# COLOSSEUM: Rise of the Beasts

> Entras como gladiador. Combates como guerrero. Evolucionas como una leyenda.

Experiencia de Roblox: combates contra bestias míticas, solos o en grupo, conquistando sus
poderes. Ver la [visión de diseño](docs/VISION.md).

**Estado:** Etapa 0 (entorno). Próximo: Versión 1, combate contra la Hidra.

## Puesta en marcha (PC con Roblox Studio)

1. Instala [Rokit](https://github.com/rojo-rbx/rokit) y ejecuta `rokit install` en esta carpeta.
2. Ejecuta `wally install` (descarga ProfileStore en `ServerPackages/`).
3. Instala el plugin de Rojo en Studio (`rojo plugin install`).
4. Ejecuta `rojo serve`, abre un place vacío en Studio y pulsa **Connect** en el plugin.
5. Pulsa **Play** y sigue la [prueba de la v0.8](docs/testing/INTERNACIONAL.md): entra por la
   puerta dorada al Gran Coliseo y enfréntate a la Hidra.

## Calidad

```bash
./scripts/check.sh
```

## Historial del repositorio

Este repositorio alojaba antes la web **RedSolidaria**. Su código se conserva en la rama
`backup/redsolidaria-2026-11-03` y en el historial de git. Ver
[ADR 0005](docs/adr/0005-reutilizar-repositorio.md).

## Documentación

- [CLAUDE.md](CLAUDE.md): reglas del proyecto
- [Visión de diseño](docs/VISION.md)
- [Diseño detallado](docs/design/): combate, Hidra, armas y esencias, progresión, espectadores
- [Modelos 3D para la Hidra](docs/ARTE_3D.md)
- [Música](docs/AUDIO.md)
- [Arquitectura](docs/ARCHITECTURE.md)
- [Hoja de ruta](docs/ROADMAP.md)
- [Seguridad](docs/SECURITY.md)
- [Decisiones técnicas](docs/adr/)
