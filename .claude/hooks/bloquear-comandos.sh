#!/bin/bash
# Frena `git push` (lo hace el usuario) y las librerías instaladas fuera del proyecto
# (npm/pnpm -g, pip fuera de un entorno virtual). Devuelve 2 para bloquear.
entrada=$(cat)
if command -v jq >/dev/null 2>&1; then
    comando=$(printf '%s' "$entrada" | jq -r '.tool_input.command // empty')
    # Sin el texto entre comillas: un mensaje de commit que nombra un comando no lo ejecuta.
    comando=$(printf '%s' "$comando" | tr '\n' ' ' | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g")
else
    # Sin jq se revisa el JSON crudo: puede bloquear de más, nunca de menos.
    comando=$entrada
fi

coincide() { printf '%s' "$comando" | grep -Eq "$1"; }
bloquear() { echo "Bloqueado: $1" >&2; exit 2; }
inicio='(^|[^[:alnum:]_.-])'

coincide "${inicio}git( [^|;&]*)? push([^[:alnum:]_-]|\$)" &&
    bloquear "el push lo hace el usuario a mano."

if coincide "${inicio}(npm|pnpm|bun)( [^|;&]*)? (-g|--global)([ =]|\$)" &&
    coincide ' (install|i|add|update|upgrade)( |$)'; then
    bloquear "no instales librerías globales; declarálas en el package.json del proyecto."
fi
coincide "${inicio}yarn( [^|;&]*)? global add" &&
    bloquear "no instales librerías globales; declarálas en el package.json del proyecto."

# Un pip ya activado en otro comando no se ve: hace falta la ruta del entorno en el mismo comando.
if coincide "${inicio}(pip3?|python3? -m pip3?) install( |\$)" && [ -z "${VIRTUAL_ENV:-}" ] &&
    ! coincide "venv[/\\\\](bin|Scripts)|activate|${inicio}uv( |\$)"; then
    bloquear "pip fuera de un entorno virtual; usá python3 -m venv .venv y .venv/bin/pip install."
fi
exit 0
