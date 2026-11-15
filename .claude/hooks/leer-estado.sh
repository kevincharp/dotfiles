#!/bin/bash
# Pone el STATUS.local.md del proyecto en el contexto al abrir o compactar la sesión.
estado="${CLAUDE_PROJECT_DIR:-$PWD}/STATUS.local.md"
[ -f "$estado" ] && cat "$estado"
exit 0
