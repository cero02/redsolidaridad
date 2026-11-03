# 0002 — Cargador propio de Services/Controllers

**Estado:** Aceptado (2026-11-03)

## Contexto
Frameworks comunitarios como Knit popularizaron el patrón Services/Controllers, pero
Knit ya no se desarrolla activamente y añade una capa de red propia que queremos controlar.

## Decisión
Un cargador propio de pocas líneas (Etapa 1) que:
1. hace `require` de cada ModuleScript de `Services/` (o `Controllers/`),
2. llama a `Init()` en todos (sin ceder),
3. llama a `Start()` en todos, cada uno en su propio hilo (`task.spawn`).

La red se gestiona aparte, en `Shared/Net` + `NetService`.

## Consecuencias
- Sin dependencias externas para la estructura del juego.
- Tenemos que mantener nosotros el cargador (bajo coste).
