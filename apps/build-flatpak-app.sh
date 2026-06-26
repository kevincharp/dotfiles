#!/usr/bin/env bash
# ==============================================================================
#   build-flatpak-app.sh — Instala UNA app de Flathub desde apps/flatpak-apps.txt
#
#   Uso:   bash build-flatpak-app.sh <id>
#          (tambien via la funcion de shell 'flatpak-app <id>')
#
#   Flatpak no compila nada: baja el binario ya armado de Flathub y crea la
#   entrada de menu (.desktop) solo. El uninstall se hace con 'flatpak uninstall',
#   no borrando archivos a mano.
#
#   El remote 'flathub' se agrega COMPLETO a nivel usuario (el de Fedora viene
#   'filtered' y no lista todas las apps, p.ej. teams-for-linux).
# ==============================================================================
set -euo pipefail

# --- Rutas base --------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECIPE="$SCRIPT_DIR/flatpak-apps.txt"

# --- Logging minimo ----------------------------------------------------------
_info() { printf '  \033[2m%s\033[0m\n' "$*"; }
_ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
_err()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

# --- Validaciones ------------------------------------------------------------
APP_ID="${1:-}"
if [[ -z "$APP_ID" ]]; then
    _err "Falta el id de la app. Uso: build-flatpak-app.sh <id>"
    exit 1
fi
if [[ ! -f "$RECIPE" ]]; then
    _err "No existe la receta: $RECIPE"
    exit 1
fi
command -v flatpak &>/dev/null || { _err "Falta 'flatpak' (instala el paquete flatpak)"; exit 1; }

# --- Buscar la linea de la receta (id|Nombre|app-id) --------------------------
# Ignora comentarios (#) y lineas vacias; matchea el primer campo exacto.
line="$(grep -vE '^[[:space:]]*#' "$RECIPE" | awk -F'|' -v id="$APP_ID" '$1==id {print; exit}')"
if [[ -z "$line" ]]; then
    _err "No hay una app con id '$APP_ID' en $RECIPE"
    exit 1
fi

IFS='|' read -r r_id r_name r_appid <<< "$line"
if [[ -z "${r_appid:-}" ]]; then
    _err "La receta de '$r_id' no tiene app-id de Flathub"
    exit 1
fi

# --- Asegurar el remote flathub COMPLETO a nivel usuario ----------------------
# El de Fedora viene 'filtered'; agregamos el oficial a --user para no tocar
# el sistema ni requerir sudo.
if ! flatpak remotes --user 2>/dev/null | grep -q '^flathub'; then
    _info "Agregando remote flathub (completo, a nivel usuario)..."
    flatpak remote-add --if-not-exists --user \
        flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

# --- Instalar --------------------------------------------------------------
_info "Instalando '$r_name' ($r_appid) desde Flathub..."
flatpak install -y --user flathub "$r_appid"

_ok "'$r_name' instalada — deberia aparecer en el menu de aplicaciones."
