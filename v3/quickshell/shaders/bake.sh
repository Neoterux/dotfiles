#!/bin/sh
# Recompiles every .frag in this directory to its .qsb bundle.
# Quickshell only reloads .qml on save, not .qsb -- restart the shell
# (or touch any .qml) after baking to pick up the new shader.
set -e

cd "$(dirname "$0")"

QSB=$(command -v qsb || echo /usr/lib/qt6/bin/qsb)
if [ ! -x "$QSB" ]; then
    echo "bake.sh: qsb not found (package qt6-shadertools)" >&2
    exit 1
fi

for frag in *.frag; do
    echo "baking $frag -> $frag.qsb"
    "$QSB" --qt6 -o "$frag.qsb" "$frag"
done
