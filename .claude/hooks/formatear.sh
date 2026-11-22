#!/bin/bash
# Formatea el archivo recién editado solo si el proyecto ya exige ese formato
# (su CI, sus scripts o sus hooks lo corren): si no, reformatear el archivo
# entero mete ruido en el diff. Mejor esfuerzo: nunca bloquea (sale con 0).
entrada=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
archivo=$(printf '%s' "$entrada" | jq -r '.tool_input.file_path // empty')
[ -n "$archivo" ] && [ -f "$archivo" ] || exit 0

raiz=$(git -C "$(dirname "$archivo")" rev-parse --show-toplevel 2>/dev/null) || exit 0

# Busca el comando en los lugares donde un proyecto fija sus chequeos.
exige() {
    grep -rqsE -- "$1" \
        "$raiz/.gitlab-ci.yml" "$raiz/.github/workflows" \
        "$raiz/.pre-commit-config.yaml" "$raiz/lefthook.yml" "$raiz/.husky" \
        "$raiz/Makefile" "$raiz/justfile" "$raiz/scripts" \
        "$raiz"/package.json "$raiz"/*/package.json
}

case "$archivo" in
*.js | *.jsx | *.ts | *.tsx | *.json | *.css | *.md)
    exige 'prettier (--check|-c|--list-different|-l)' &&
        command -v npx >/dev/null 2>&1 &&
        npx --no-install prettier --write "$archivo" >/dev/null 2>&1
    ;;
*.py)
    exige 'ruff format' &&
        command -v ruff >/dev/null 2>&1 &&
        ruff format "$archivo" >/dev/null 2>&1
    ;;
*.rs)
    exige 'cargo fmt|rustfmt' &&
        command -v rustfmt >/dev/null 2>&1 &&
        rustfmt "$archivo" >/dev/null 2>&1
    ;;
esac
exit 0
