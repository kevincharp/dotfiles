#!/bin/bash
# Formatea el archivo recién editado solo si el proyecto ya exige ese formato
# (su CI, sus scripts o sus hooks lo corren): si no, reformatear el archivo
# entero mete ruido en el diff. Mejor esfuerzo: nunca bloquea (sale con 0).
input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$file" ] && [ -f "$file" ] || exit 0

root=$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null) || exit 0

# Busca el comando en los lugares donde un proyecto fija sus chequeos.
requires() {
    grep -rqsE -- "$1" \
        "$root/.gitlab-ci.yml" "$root/.github/workflows" \
        "$root/.pre-commit-config.yaml" "$root/lefthook.yml" "$root/.husky" \
        "$root/Makefile" "$root/justfile" "$root/scripts" \
        "$root"/package.json "$root"/*/package.json
}

case "$file" in
*.js | *.jsx | *.ts | *.tsx | *.json | *.css | *.md)
    requires 'prettier (--check|-c|--list-different|-l)' &&
        command -v npx >/dev/null 2>&1 &&
        npx --no-install prettier --write "$file" >/dev/null 2>&1
    ;;
*.py)
    requires 'ruff format' &&
        command -v ruff >/dev/null 2>&1 &&
        ruff format "$file" >/dev/null 2>&1
    ;;
*.rs)
    requires 'cargo fmt|rustfmt' &&
        command -v rustfmt >/dev/null 2>&1 &&
        rustfmt "$file" >/dev/null 2>&1
    ;;
esac
exit 0
