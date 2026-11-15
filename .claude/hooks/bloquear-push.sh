#!/bin/bash
# Bloquea `git push`, también `git -C dir push` y similares: el push lo hace el usuario.
entrada=$(cat)
if command -v jq >/dev/null 2>&1; then
    comando=$(printf '%s' "$entrada" | jq -r '.tool_input.command // empty')
    # Sin el texto entre comillas: un mensaje de commit que nombra "git push" no es un push.
    comando=$(printf '%s' "$comando" | tr '\n' ' ' | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g")
else
    # Sin jq se revisa el JSON crudo: puede bloquear de más, nunca de menos.
    comando=$entrada
fi
patron='(^|[^[:alnum:]_.-])git( [^|;&]*)? push([^[:alnum:]_-]|$)'
if printf '%s' "$comando" | grep -Eq "$patron"; then
    echo "Bloqueado: el push lo hace el usuario a mano." >&2
    exit 2
fi
exit 0
