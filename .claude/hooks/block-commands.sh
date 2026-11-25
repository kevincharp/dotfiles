#!/bin/bash
# Frena `git push` (lo hace el usuario) y las librerías instaladas fuera del proyecto
# (npm/pnpm -g, pip fuera de un entorno virtual). Devuelve 2 para bloquear.
input=$(cat)
if command -v jq >/dev/null 2>&1; then
    command_line=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    # Sin el texto entre comillas: un mensaje de commit que nombra un comando no lo ejecuta.
    command_line=$(printf '%s' "$command_line" | tr '\n' ' ' | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g")
else
    # Sin jq se revisa el JSON crudo: puede bloquear de más, nunca de menos.
    command_line=$input
fi

matches() { printf '%s' "$command_line" | grep -Eq "$1"; }
block() { echo "Bloqueado: $1" >&2; exit 2; }
start='(^|[^[:alnum:]_.-])'

matches "${start}git( [^|;&]*)? push([^[:alnum:]_-]|\$)" &&
    block "el push lo hace el usuario a mano."

if matches "${start}(npm|pnpm|bun)( [^|;&]*)? (-g|--global)([ =]|\$)" &&
    matches ' (install|i|add|update|upgrade)( |$)'; then
    block "no instales librerías globales; declarálas en el package.json del proyecto."
fi
matches "${start}yarn( [^|;&]*)? global add" &&
    block "no instales librerías globales; declarálas en el package.json del proyecto."

# Un pip ya activado en otro comando no se ve: hace falta la ruta del entorno en el mismo comando.
if matches "${start}(pip3?|python3? -m pip3?) install( |\$)" && [ -z "${VIRTUAL_ENV:-}" ] &&
    ! matches "venv[/\\\\](bin|Scripts)|activate|${start}uv( |\$)"; then
    block "pip fuera de un entorno virtual; usá python3 -m venv .venv y .venv/bin/pip install."
fi
exit 0
