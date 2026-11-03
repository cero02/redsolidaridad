#!/usr/bin/env bash
# Instala el toolchain con versiones fijadas compilando desde crates.io.
# Alternativa a Rokit para entornos sin acceso a GitHub Releases (p. ej. CI o
# contenedores). Mantener sincronizado con rokit.toml.
set -euo pipefail

TOOLS=(
	"stylua 2.6.0"
	"selene 0.31.0"
	"rojo 7.7.1"
	"wally 0.3.2"
	"lune 0.11.1"
)

for entry in "${TOOLS[@]}"; do
	read -r name version <<<"$entry"
	if command -v "$name" >/dev/null && "$name" --version 2>/dev/null | grep -q "$version"; then
		echo "ok    $name $version"
		continue
	fi
	echo "build $name $version"
	cargo install --locked "$name" --version "=$version"
done
