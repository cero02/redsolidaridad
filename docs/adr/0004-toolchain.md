# 0004 — Toolchain y versiones fijadas

**Estado:** Aceptado (2026-11-03)

## Decisión

| Herramienta | Versión | Para qué |
|---|---|---|
| Rojo | 7.7.1 | Sincronizar y compilar el proyecto |
| Selene | 0.31.0 | Lint |
| StyLua | 2.6.0 | Formato |
| Wally | 0.3.2 | Gestor de paquetes (sin paquetes todavía) |
| Lune | 0.11.1 | Ejecutar tests de lógica pura fuera de Studio |

- Verificadas en crates.io el 2026-11-03: publicadas hace más de dos semanas, no retiradas,
  instaladas con `cargo install --locked` (dependencias fijadas por el autor y suma de
  verificación de crates.io).
- En los PCs del equipo: **Rokit** con `rokit.toml` (descarga los binarios oficiales).
- En el contenedor del asistente o en CI sin acceso a GitHub Releases:
  `scripts/install-tools.sh` (compila desde crates.io).
- Editor recomendado: VS Code con las extensiones de `.vscode/extensions.json`
  (Rojo, luau-lsp, StyLua, Selene).

## Nota: definiciones de Roblox para Selene

Selene necesita `roblox.yml` (generado, no se sube a git). Normalmente basta con
`selene generate-roblox-std`, que descarga el API dump de
`raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker`.

En el contenedor del asistente esa descarga falla: el cliente HTTP de Selene no acepta el
certificado del proxy corporativo. Solución usada (sin desactivar TLS): descargar el dump
con `curl` y generar `roblox.yml` con el mismo código de Selene 0.31.0 compilado para leer
un archivo local. En los PCs del equipo y en CI normal no hace falta.

## Consecuencias
- Cambiar una versión requiere aprobación y actualizar `rokit.toml`,
  `scripts/install-tools.sh` y este ADR a la vez.
