#!/usr/bin/env bash
# ==============================================================================
#   statusline.sh — linea de estado de Claude Code
#   Muestra:  carpeta · rama git · cuenta · modelo · effort · fast · thinking ·
#             contexto (% + tokens) · estilo · costo
#   - Carpeta: el PROYECTO de la sesion y, si /cd movio el cwd afuera, tambien
#     el cwd (ver "Carpeta" mas abajo). No son lo mismo: /cd mueve el cwd pero
#     la memoria, el historial y el CLAUDE.md de proyecto siguen siendo los del
#     directorio desde el que se lanzo `claude`.
#   - Cuenta: distingue Bedrock/SMG (claude-smg setea CLAUDE_CODE_USE_BEDROCK=1)
#     de la cuenta Anthropic normal.
#   - Colores: paleta Claude Code (256-color), espejo de LS_COLORS del bashrc.
#   Claude Code ejecuta este script en cada refresco y le pasa un JSON por stdin.
#   Iconos: emoji a color, NO glyphs de Nerd Font. Linux los resuelve con Noto
#   Color Emoji (lo prioriza el fontconfig/ de este repo) y Windows con Segoe UI
#   Emoji; el set se cambia en el bloque "Iconos" de abajo. Ocupan dos columnas,
#   asi que la linea es mas ancha que con glyphs.
# ==============================================================================

input="$(cat)"

# --- Paleta (38;5;N) ---
c() { printf '\033[38;5;%sm' "$1"; }
RESET=$'\033[0m'
ORANGE=172; CYAN=73; PURPLE=141; GREEN=114; YELLOW=220; RED=203; DIM=240
SEP="$(c "$DIM") · ${RESET}"

# --- Iconos (editar aca para cambiar el set) ---
# Los emoji traen su propio color: no se les aplica SGR (lo ignoran las fuentes
# COLRv1), el color queda solo en el texto que los sigue.
I_DIR="📁"; I_DRIFT="⚠️"; I_BRANCH="🌿"; I_MODEL="🤖"
I_ANTHROPIC="✨"; I_BEDROCK="☁️"; I_CTX="📊"; I_STYLE="🎨"
I_FAST="🚀"; I_THINKING="🧠"; I_COST="💰"

# --- Lectura del JSON ---
# Usa jq si esta disponible; si no (ej. Git Bash en Windows, donde jq no suele
# estar), cae a un parser con grep/sed. Asi el statusline funciona en cualquier
# maquina sin depender de jq.
# Las claves se escriben estilo jq SIN el punto inicial ("model.display_name").
# En el modo sin jq el parser recorta el JSON en cada padre antes de buscar la
# hija: hace falta porque hay nombres repetidos (`name` esta en output_style,
# agent y worktree; `used_percentage` tambien en rate_limits).
_json_get() {
    # $1 = str|num|bool, $2 = json, $3... = claves candidatas (por preferencia)
    # bool: fast_mode/thinking.enabled llegan como true/false SIN comillas (no
    # son strings) - el regex de "str" nunca los matchea y el campo queda
    # vacio en el modo sin jq, sin importar el valor real (visto en Windows).
    local kind="$1" json="$2"; shift 2
    local key val frag part re
    if command -v jq &>/dev/null; then
        for key in "$@"; do
            val="$(printf '%s' "$json" | jq -r ".${key} // empty" 2>/dev/null)"
            [[ -n "$val" && "$val" != "null" ]] && { printf '%s' "$val"; return; }
        done
        return
    fi
    if [[ "$kind" == "num" ]]; then re='-\?[0-9][0-9.eE+-]*'
    elif [[ "$kind" == "bool" ]]; then re='true\|false'
    else re='"[^"]*"'; fi
    for key in "$@"; do
        frag="$json"
        while [[ "$key" == *.* ]]; do
            part="${key%%.*}"; key="${key#*.}"
            [[ "$frag" == *"\"${part}\""* ]] || { frag=""; break; }
            frag="${frag#*\"${part}\"}"
        done
        [[ -z "$frag" ]] && continue
        # El sed anda con valores que contienen ":" (rutas C:/... de Windows):
        # el ancla ^[^:]* solo puede comerse el nombre de la clave.
        val="$(printf '%s' "$frag" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*${re}" | head -1 | sed -E 's/^[^:]*:[[:space:]]*//; s/^"//; s/"$//')"
        [[ -n "$val" ]] && { printf '%s' "$val"; return; }
    done
}

model="$(_json_get str "$input" 'model.display_name' 'model.id')"
cwd="$(_json_get str "$input" 'workspace.current_dir' 'cwd')"
project="$(_json_get str "$input" 'workspace.project_dir')"
effort="$(_json_get str "$input" 'effort.level')"
style="$(_json_get str "$input" 'output_style.name')"
ctx="$(_json_get num "$input" 'context_window.used_percentage')"
tok_in="$(_json_get num "$input" 'context_window.total_input_tokens')"
tok_out="$(_json_get num "$input" 'context_window.total_output_tokens')"
fast="$(_json_get bool "$input" 'fast_mode')"
thinking="$(_json_get bool "$input" 'thinking.enabled')"
cost="$(_json_get num "$input" 'cost.total_cost_usd')"
[[ -z "$model" ]] && model="?"
[[ -z "$cwd" ]] && cwd="$PWD"

# --- Carpeta ---
# El JSON trae por separado el cwd de la sesion (workspace.current_dir, que /cd
# mueve) y el proyecto (workspace.project_dir, fijo: de ahi salen la memoria, el
# historial y el CLAUDE.md de proyecto). Se muestran los dos cuando difieren
# para que el /cd no pase desapercibido:
#   iguales           →  proyecto
#   cwd bajo proyecto →  proyecto/ruta/relativa
#   cwd afuera        →  proyecto ⚠️ cwd   (el cwd en amarillo)
# Sin project_dir (Claude Code viejo) cae al comportamiento historico: solo cwd.
_norm_path() {  # backslashes de Windows a /, sin barras repetidas ni barra final
    # Sin jq los backslashes llegan escapados (C:\\Users), asi que la conversion
    # deja // y hay que colapsarlas para que la comparacion de prefijo funcione.
    local p="${1//\\//}"
    while [[ "$p" == *//* ]]; do p="${p//\/\//\/}"; done
    [[ "$p" != "/" ]] && p="${p%/}"
    printf '%s' "$p"
}
_display_dir() {  # nombre corto de una ruta: ~ si es HOME, si no el basename
    local p="$1"
    if [[ "$p" == "$(_norm_path "$HOME")" ]]; then
        printf '~'
    else
        printf '%s' "${p##*/}"
    fi
}

cwd_n="$(_norm_path "$cwd")"
proj_n="$(_norm_path "$project")"

if [[ -z "$proj_n" || "$proj_n" == "$cwd_n" ]]; then
    dir="$(c "$ORANGE")$(_display_dir "$cwd_n")${RESET}"
elif [[ "$cwd_n" == "$proj_n"/* ]]; then
    dir="$(c "$ORANGE")$(_display_dir "$proj_n")/${cwd_n#"$proj_n"/}${RESET}"
else
    dir="$(c "$ORANGE")$(_display_dir "$proj_n")${RESET}"
    dir+=" ${I_DRIFT} $(c "$YELLOW")$(_display_dir "$cwd_n")${RESET}"
fi

# --- Rama git (si estamos dentro de un repo) ---
branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
    branch="$(git -C "$cwd" branch --show-current 2>/dev/null)"
    [[ -z "$branch" ]] && branch="$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)"
fi

# --- Cuenta: Bedrock (claude-smg) vs Anthropic ---
if [[ "${CLAUDE_CODE_USE_BEDROCK:-}" == "1" ]]; then
    account="${I_BEDROCK} $(c "$YELLOW")${AWS_PROFILE:-SMG}/Bedrock${RESET}"
else
    account="${I_ANTHROPIC} $(c "$PURPLE")Anthropic${RESET}"
fi

# --- Contexto usado (context_window.used_percentage + total_*_tokens) ---
# Redondeo con LC_ALL=C: el locale es_AR usa coma decimal y rompe el %.0f de un
# valor como 12.3456.
# Los tokens son los del CONTEXTO ACTUAL (lo que se reenvia cada turno), no un
# acumulado historico de toda la sesion - ese campo no existe en el payload
# (cost.* solo trae USD/duracion/lineas, sin tokens). Es el numero honesto
# disponible: coincide con el % de arriba, en unidades absolutas.
_fmt_tokens() {  # entero -> "577k" / "1.2M" (aritmetica entera, sin awk/bc)
    local n="$1"
    if   (( n >= 1000000 )); then printf '%d.%dM' $((n / 1000000)) $(( (n % 1000000) / 100000 ))
    elif (( n >= 1000 ));    then printf '%dk' $((n / 1000))
    else                          printf '%d' "$n"
    fi
}
ctx_seg=""
if [[ "$ctx" =~ ^[0-9] ]]; then
    ctx_pct="$(LC_ALL=C printf '%.0f' "$ctx" 2>/dev/null)"
    if [[ -n "$ctx_pct" ]]; then
        if   (( ctx_pct >= 85 )); then ctx_color=$RED
        elif (( ctx_pct >= 60 )); then ctx_color=$YELLOW
        else                           ctx_color=$DIM
        fi
        ctx_seg="${I_CTX} $(c "$ctx_color")${ctx_pct}%${RESET}"
        if [[ "$tok_in" =~ ^[0-9]+$ ]]; then
            tok_out_n=0
            [[ "$tok_out" =~ ^[0-9]+$ ]] && tok_out_n="$tok_out"
            tok_total=$(( tok_in + tok_out_n ))
            ctx_seg+=" $(c "$DIM")($(_fmt_tokens "$tok_total"))${RESET}"
        fi
    fi
fi

# --- Construir la linea ---
line="${I_DIR} ${dir}"
[[ -n "$branch" ]] && line+="${SEP}${I_BRANCH} $(c "$GREEN")${branch}${RESET}"
line+="${SEP}${account}"
line+="${SEP}${I_MODEL} $(c "$CYAN")${model}${RESET}"
# effort solo viene si el modelo lo soporta; el output style, solo si no es el default
[[ -n "$effort" ]] && line+="$(c "$DIM") ${effort}${RESET}"
[[ "$fast" == "true" ]] && line+=" ${I_FAST}"
[[ "$thinking" == "true" ]] && line+=" ${I_THINKING}"
[[ -n "$ctx_seg" ]] && line+="${SEP}${ctx_seg}"
if [[ -n "$style" ]] && [[ "$(printf '%s' "$style" | tr '[:upper:]' '[:lower:]')" != "default" ]]; then
    line+="${SEP}${I_STYLE} $(c "$DIM")${style}${RESET}"
fi
# Costo: si esta disponible, mostrarlo en gris (siempre crece, no necesita color de alarma)
if [[ "$cost" =~ ^[0-9] ]]; then
    cost_fmt="$(LC_ALL=C printf '%.2f' "$cost" 2>/dev/null)"
    [[ -n "$cost_fmt" ]] && line+="${SEP}${I_COST} $(c "$DIM")\$${cost_fmt}${RESET}"
fi

printf '%s' "$line"
