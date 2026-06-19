#!/usr/bin/env bash
# ==============================================================================
#   statusline.sh — linea de estado de Claude Code
#   Muestra:  carpeta · rama git · cuenta · modelo
#   - Cuenta: distingue Bedrock/SMG (claude-smg setea CLAUDE_CODE_USE_BEDROCK=1)
#     de la cuenta Anthropic normal.
#   - Colores: paleta Claude Code (256-color), espejo de LS_COLORS del bashrc.
#   Claude Code ejecuta este script en cada refresco y le pasa un JSON por stdin.
#   Glyphs: requieren una Nerd Font (FiraCode Nerd Font ya esta en el bootstrap).
# ==============================================================================

input="$(cat)"

# --- Paleta (38;5;N) ---
c() { printf '\033[38;5;%sm' "$1"; }
RESET=$'\033[0m'
ORANGE=172; CYAN=73; PURPLE=141; GREEN=114; YELLOW=220; DIM=240
SEP="$(c "$DIM") · ${RESET}"

# --- Datos del JSON (jq con fallback defensivo) ---
model="$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "?"' 2>/dev/null)"
[[ -z "$model" || "$model" == "null" ]] && model="?"
cwd="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)"
[[ -z "$cwd" || "$cwd" == "null" ]] && cwd="$PWD"

# --- Carpeta (solo el nombre, ~ si es HOME) ---
if [[ "$cwd" == "$HOME" ]]; then
    dir="~"
else
    dir="$(basename "$cwd")"
fi

# --- Rama git (si estamos dentro de un repo) ---
branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
    branch="$(git -C "$cwd" branch --show-current 2>/dev/null)"
    [[ -z "$branch" ]] && branch="$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)"
fi

# --- Cuenta: Bedrock (claude-smg) vs Anthropic ---
if [[ "${CLAUDE_CODE_USE_BEDROCK:-}" == "1" ]]; then
    account="$(c "$YELLOW") ${AWS_PROFILE:-SMG}/Bedrock${RESET}"
else
    account="$(c "$PURPLE")✻ Anthropic${RESET}"
fi

# --- Construir la linea ---
line="$(c "$ORANGE") ${dir}${RESET}"
[[ -n "$branch" ]] && line+="${SEP}$(c "$GREEN") ${branch}${RESET}"
line+="${SEP}${account}"
line+="${SEP}$(c "$CYAN") ${model}${RESET}"

printf '%s' "$line"
