# COLOSSEUM

Experiencia multijugador de Roblox inspirada en los espectáculos de la Antigua Roma.

**Estado:** Etapa 0 (entorno). Objetivo v0.1: coliseo con combates 1 contra 1 y espectadores.

## Puesta en marcha (PC con Roblox Studio)

1. Instala [Rokit](https://github.com/rojo-rbx/rokit) y ejecuta `rokit install` en esta carpeta.
2. Instala el plugin de Rojo en Studio (`rojo plugin install`).
3. Ejecuta `rojo serve`, abre un place vacío en Studio y pulsa **Connect** en el plugin.
4. Pulsa **Play**: en la consola deben aparecer `[COLOSSEUM] servidor v0.0.1` y
   `[COLOSSEUM] cliente v0.0.1`.

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
- [Arquitectura](docs/ARCHITECTURE.md)
- [Hoja de ruta](docs/ROADMAP.md)
- [Seguridad](docs/SECURITY.md)
- [Decisiones técnicas](docs/adr/)
