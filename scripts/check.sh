#!/usr/bin/env bash
# Comprobaciones de calidad. Ejecutar antes de cada commit.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== StyLua (formato)"
stylua --check src tests

echo "== Selene (lint)"
selene src tests

echo "== Rojo (el proyecto compila a un place)"
mkdir -p build
rojo build default.project.json --output build/colosseum.rbxl

echo "== Lune (tests)"
for spec in tests/*.spec.luau; do
	lune run "$spec"
done

echo "Todo correcto."
