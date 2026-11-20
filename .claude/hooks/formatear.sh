#!/bin/bash
# Formatea el archivo recién editado si el proyecto ya trae un formateador
# configurado. Mejor esfuerzo: nunca bloquea (siempre sale con 0).
entrada=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
archivo=$(printf '%s' "$entrada" | jq -r '.tool_input.file_path // empty')
[ -n "$archivo" ] && [ -f "$archivo" ] || exit 0

raiz=$(git -C "$(dirname "$archivo")" rev-parse --show-toplevel 2>/dev/null) || exit 0

case "$archivo" in
*.js | *.jsx | *.ts | *.tsx | *.json | *.css | *.md)
    { [ -f "$raiz/.prettierrc" ] || [ -f "$raiz/.prettierrc.json" ] ||
        grep -q '"prettier"' "$raiz/package.json" 2>/dev/null; } &&
        command -v npx >/dev/null 2>&1 &&
        npx --no-install prettier --write "$archivo" >/dev/null 2>&1
    ;;
*.py)
    grep -q '\[tool.ruff\]' "$raiz/pyproject.toml" 2>/dev/null &&
        command -v ruff >/dev/null 2>&1 &&
        ruff format "$archivo" >/dev/null 2>&1
    ;;
*.rs)
    [ -f "$raiz/Cargo.toml" ] &&
        command -v rustfmt >/dev/null 2>&1 &&
        rustfmt "$archivo" >/dev/null 2>&1
    ;;
esac
exit 0
