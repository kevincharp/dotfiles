#!/usr/bin/env bash
# ==============================================================================
#   build-pake-app.sh — Compila UNA app de escritorio desde apps/pake-apps.txt
#   y la integra al menu de GNOME (AppImage + .desktop + icono).
#
#   Uso:   bash build-pake-app.sh <id>
#          (tambien via la funcion de shell 'pake-app <id>')
#
#   Requisitos (los asegura el bootstrap con _ensure_pake_deps): Node, Rust y las
#   dependencias de sistema de Tauri (webkit2gtk4.1-devel, etc.). pake-cli se usa
#   con 'npx' (no requiere instalacion global).
#
#   Salida (convencion XDG, no son symlinks → uninstall.sh los borra en su bloque):
#     ~/.local/share/pake-apps/<id>.AppImage
#     ~/.local/share/icons/pake-<id>.png
#     ~/.local/share/applications/pake-<id>.desktop
# ==============================================================================
set -euo pipefail

# --- Rutas base --------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECIPE="$SCRIPT_DIR/pake-apps.txt"

APPS_DIR="$HOME/.local/share/pake-apps"
ICONS_DIR="$HOME/.local/share/icons"
DESKTOP_DIR="$HOME/.local/share/applications"

# --- Logging minimo ----------------------------------------------------------
_info() { printf '  \033[2m%s\033[0m\n' "$*"; }
_ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
_err()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

# --- Cargar cargo al PATH si esta (rustup deja el env aca) --------------------
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# --- Validaciones ------------------------------------------------------------
APP_ID="${1:-}"
if [[ -z "$APP_ID" ]]; then
    _err "Falta el id de la app. Uso: build-pake-app.sh <id>"
    exit 1
fi
if [[ ! -f "$RECIPE" ]]; then
    _err "No existe la receta: $RECIPE"
    exit 1
fi
for cmd in node npx; do
    command -v "$cmd" &>/dev/null || { _err "Falta '$cmd' (instala la herramienta 'node')"; exit 1; }
done
command -v cargo &>/dev/null || { _err "Falta Rust/cargo (lo instala el bootstrap con _ensure_pake_deps)"; exit 1; }

# --- Buscar la linea de la receta (id|Nombre|URL|icono[|flags]) ---------------
# Ignora comentarios (#) y lineas vacias; matchea el primer campo exacto.
line="$(grep -vE '^[[:space:]]*#' "$RECIPE" | awk -F'|' -v id="$APP_ID" '$1==id {print; exit}')"
if [[ -z "$line" ]]; then
    _err "No hay una app con id '$APP_ID' en $RECIPE"
    exit 1
fi

IFS='|' read -r r_id r_name r_url r_icon r_flags <<< "$line"

# Icono: ruta relativa a apps/ → absoluta. Puede no existir (Pake usa default).
icon_src=""
if [[ -n "${r_icon:-}" ]]; then
    icon_abs="$SCRIPT_DIR/$r_icon"
    if [[ -f "$icon_abs" ]]; then
        icon_src="$icon_abs"
    else
        _info "Icono no encontrado ($r_icon) — Pake usara el generico"
    fi
fi

# --- Compilar con Pake en un tmpdir ------------------------------------------
mkdir -p "$APPS_DIR" "$ICONS_DIR" "$DESKTOP_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

_info "Compilando '$r_name' ($r_url) — esto compila con Rust, puede tardar varios minutos..."

# Argumentos de pake-cli. El icono y los flags extra son opcionales.
pake_args=("$r_url" --name "$r_name")
[[ -n "$icon_src" ]] && pake_args+=(--icon "$icon_src")
# shellcheck disable=SC2206  # queremos que los flags extra se separen por palabras
[[ -n "${r_flags:-}" ]] && pake_args+=(${r_flags})

( cd "$tmp" && npx --yes pake-cli "${pake_args[@]}" )

# --- Localizar el AppImage generado (Pake lo deja en el cwd del build) --------
appimage="$(find "$tmp" -maxdepth 1 -iname '*.AppImage' | head -n1)"
if [[ -z "$appimage" ]]; then
    _err "Pake no genero un AppImage para '$r_name'"
    exit 1
fi

# --- Instalar AppImage --------------------------------------------------------
dest_app="$APPS_DIR/$r_id.AppImage"
mv -f "$appimage" "$dest_app"
chmod +x "$dest_app"
_ok "AppImage: $dest_app"

# --- Instalar icono (si lo hay) y resolver el Icon= del .desktop --------------
icon_field="$r_id"   # fallback: nombre de icono generico
if [[ -n "$icon_src" ]]; then
    cp -f "$icon_src" "$ICONS_DIR/pake-$r_id.png"
    icon_field="$ICONS_DIR/pake-$r_id.png"
fi

# --- Generar el lanzador .desktop --------------------------------------------
desktop="$DESKTOP_DIR/pake-$r_id.desktop"
cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$r_name
Exec=$dest_app %U
Icon=$icon_field
Terminal=false
Categories=Network;
StartupNotify=true
Comment=$r_name (web envuelta con Pake)
EOF
chmod +x "$desktop"
_ok "Lanzador: $desktop"

# --- Refrescar el menu de GNOME ----------------------------------------------
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" &>/dev/null || true
fi

_ok "'$r_name' lista — deberia aparecer en el menu de aplicaciones."
