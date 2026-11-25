#!/bin/bash
# Pone el STATUS.local.md del proyecto en el contexto al abrir o compactar la sesión.
status_file="${CLAUDE_PROJECT_DIR:-$PWD}/STATUS.local.md"
[ -f "$status_file" ] && cat "$status_file"
exit 0
