#!/usr/bin/env bash
# aplicar-perfiles.sh - aplica la config de Firefox versionada en firefox/ a los
# perfiles "Personal" (navegador diario) y "Aplicaciones" (solo PWA). Solo Linux.
#
# Que hace, de forma idempotente:
#   1. user.js en cada perfil (Personal = user.js; Aplicaciones = user.js + el
#      espejo de interfaz de user-aplicaciones.js).
#   2. Excepciones de cookies (excepciones-cookies.txt) en permissions.sqlite.
#   3. Zoom por defecto en content-prefs.sqlite.
#   4. Override del .desktop de Firefox con -profile fijo al perfil Personal
#      (sin esto, Firefox abre el ULTIMO perfil usado y GNOME agrupa el
#      navegador con las PWA; ver docs/notas-tecnicas.md).
#
# Los perfiles se buscan por NOMBRE en "Profile Groups/*.sqlite" (las carpetas
# tienen sufijos aleatorios). Si no existen hay que crearlos UNA vez desde el
# selector de Firefox, con esos nombres exactos.
#
# Uso: aplicar-perfiles.sh [--dry-run] [--quitar]
# Salida: 0 todo aplicado | 3 algo quedo sin aplicar (perfil inexistente, Firefox
# abierto...) | 2 uso incorrecto.
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FF_DIR="${FIREFOX_DIR:-$HOME/.config/mozilla/firefox}"
NOMBRE_PERSONAL="${FIREFOX_PERFIL_PERSONAL:-Personal}"
NOMBRE_APPS="${FIREFOX_PERFIL_APPS:-Aplicaciones}"
ZOOM="${FIREFOX_ZOOM:-0.9}"
DESKTOP_SISTEMA="${FIREFOX_DESKTOP_SISTEMA:-/usr/share/applications/org.mozilla.firefox.desktop}"
DESKTOP_DEST="$HOME/.local/share/applications/org.mozilla.firefox.desktop"
MARCA_JS="// dotfiles: generado por firefox/aplicar-perfiles.sh - editar el repo, no este archivo"
MARCA_DESKTOP="X-Dotfiles-Generado=firefox"
ZOOM_CLAVE="browser.content.full-zoom"

MODO=aplicar
DRY_RUN=false
SALTADOS=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --quitar)  MODO=quitar ;;
        -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo "[firefox] argumento desconocido: $arg" >&2; exit 2 ;;
    esac
done

info()   { printf '[firefox] %s\n' "$*"; }
simula() { printf '[firefox][DryRun] %s\n' "$*"; }
# Algo quedo sin aplicar: avisa y lo cuenta para el exit 3 (no aborta el resto).
saltar() { printf '[firefox][WARN] %s\n' "$*" >&2; SALTADOS=$((SALTADOS + 1)); }

# Escapa comillas simples para interpolar en SQL.
sq() { printf '%s' "${1//\'/\'\'}"; }

# ruta_perfil <nombre> - imprime la ruta absoluta del perfil o nada.
ruta_perfil() {
    local nombre db dir
    nombre="$(sq "$1")"
    for db in "$FF_DIR/Profile Groups"/*.sqlite; do
        [[ -f "$db" ]] || continue
        dir="$(sqlite3 -readonly "$db" "SELECT path FROM Profiles WHERE name='$nombre' LIMIT 1;" 2>/dev/null)" || continue
        if [[ -n "$dir" ]]; then
            [[ "$dir" == /* ]] || dir="$FF_DIR/$dir"
            printf '%s\n' "$dir"
            return 0
        fi
    done
    return 0
}

# perfil_en_uso <dir> - 0 si hay un Firefox vivo con ese perfil (symlink 'lock' -> ip:+PID).
perfil_en_uso() {
    local lock="$1/lock" destino pid
    [[ -L "$lock" ]] || return 1
    destino="$(readlink "$lock")"
    pid="${destino##*+}"
    [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null
}

escribir_userjs() {
    local dir="$1" etiqueta="$2"; shift 2
    local destino="$dir/user.js" tmp f
    tmp="$(mktemp)"
    { printf '%s\n\n' "$MARCA_JS"; for f in "$@"; do cat "$f"; printf '\n'; done; } > "$tmp"
    if [[ -f "$destino" ]] && cmp -s "$tmp" "$destino"; then
        info "$etiqueta: user.js sin cambios"
        rm -f "$tmp"
        return 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
        simula "$etiqueta: escribiria $destino"
        rm -f "$tmp"
        return 0
    fi
    # Un user.js ajeno (sin nuestra marca) no se pisa en silencio.
    if [[ -f "$destino" ]] && ! grep -qF "$MARCA_JS" "$destino"; then
        mv "$destino" "$destino.anterior"
        info "$etiqueta: user.js propio guardado como user.js.anterior"
    fi
    mv "$tmp" "$destino"
    chmod 644 "$destino"
    info "$etiqueta: user.js escrito"
}

cargar_cookies() {
    local dir="$1" etiqueta="$2" db="$1/permissions.sqlite" lista="$AQUI/excepciones-cookies.txt"
    local ahora origen esc sql=""
    [[ -f "$lista" ]] || { saltar "$etiqueta: falta $lista"; return 0; }
    if [[ ! -f "$db" ]]; then
        saltar "$etiqueta: aun no existe permissions.sqlite (abri el perfil una vez y re-corre)"
        return 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
        simula "$etiqueta: cargaria las excepciones de cookies de $(basename "$lista")"
        return 0
    fi
    if perfil_en_uso "$dir"; then
        saltar "$etiqueta: Firefox esta abierto, no toco permissions.sqlite (cerralo y re-corre)"
        return 0
    fi
    ahora=$(( $(date +%s) * 1000 ))
    while IFS= read -r origen; do
        [[ -z "$origen" || "$origen" == \#* ]] && continue
        esc="$(sq "$origen")"
        sql+="INSERT INTO moz_perms(origin,type,permission,expireType,expireTime,modificationTime) SELECT '$esc','cookie',1,0,0,$ahora WHERE NOT EXISTS (SELECT 1 FROM moz_perms WHERE origin='$esc' AND type='cookie');"
    done < "$lista"
    if sqlite3 -cmd ".timeout 3000" "$db" "BEGIN; $sql COMMIT;" 2>/dev/null; then
        info "$etiqueta: excepciones de cookies cargadas"
    else
        saltar "$etiqueta: no pude escribir permissions.sqlite (bloqueada)"
    fi
}

fijar_zoom() {
    local dir="$1" etiqueta="$2" db="$1/content-prefs.sqlite"
    local id="(SELECT id FROM settings WHERE name='$ZOOM_CLAVE')"
    if [[ ! -f "$db" ]]; then
        saltar "$etiqueta: aun no existe content-prefs.sqlite (abri el perfil una vez y re-corre)"
        return 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
        simula "$etiqueta: fijaria el zoom global en $ZOOM"
        return 0
    fi
    if perfil_en_uso "$dir"; then
        saltar "$etiqueta: Firefox esta abierto, no toco content-prefs.sqlite (cerralo y re-corre)"
        return 0
    fi
    if sqlite3 -cmd ".timeout 3000" "$db" "
        INSERT INTO settings(name) SELECT '$ZOOM_CLAVE' WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name='$ZOOM_CLAVE');
        UPDATE prefs SET value=$ZOOM WHERE groupID IS NULL AND settingID=$id;
        INSERT INTO prefs(groupID,settingID,value,timestamp) SELECT NULL,$id,$ZOOM,CAST(strftime('%s','now') AS INTEGER)
            WHERE NOT EXISTS (SELECT 1 FROM prefs WHERE groupID IS NULL AND settingID=$id);" 2>/dev/null; then
        info "$etiqueta: zoom global en $ZOOM"
    else
        saltar "$etiqueta: no pude escribir content-prefs.sqlite (bloqueada)"
    fi
}

generar_desktop() {
    local dir="$1" tmp
    if [[ ! -f "$DESKTOP_SISTEMA" ]]; then
        saltar "no encuentro $DESKTOP_SISTEMA (Firefox no instalado por rpm?)"
        return 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
        simula "escribiria $DESKTOP_DEST con -profile $dir"
        return 0
    fi
    tmp="$(mktemp)"
    # El perfil va fijo en cada Exec (salvo el gestor de perfiles, que debe
    # seguir abriendo el selector).
    sed -e "/--ProfileManager/!s|^Exec=firefox |Exec=firefox -profile $dir |" \
        -e "0,/^\[Desktop Entry\]/s//[Desktop Entry]\n$MARCA_DESKTOP/" \
        "$DESKTOP_SISTEMA" > "$tmp"
    if [[ -f "$DESKTOP_DEST" ]] && cmp -s "$tmp" "$DESKTOP_DEST"; then
        info ".desktop sin cambios"
        rm -f "$tmp"
        return 0
    fi
    mkdir -p "$(dirname "$DESKTOP_DEST")"
    mv "$tmp" "$DESKTOP_DEST"
    chmod 644 "$DESKTOP_DEST"
    command -v update-desktop-database &>/dev/null \
        && update-desktop-database "$(dirname "$DESKTOP_DEST")" &>/dev/null || true
    info ".desktop con perfil fijo escrito ($DESKTOP_DEST)"
}

quitar() {
    local dir
    for dir in "$@"; do
        [[ -n "$dir" && -f "$dir/user.js" ]] || continue
        if grep -qF "$MARCA_JS" "$dir/user.js"; then
            if [[ "$DRY_RUN" == true ]]; then simula "quitaria $dir/user.js"; else rm -f "$dir/user.js"; info "user.js removido de $(basename "$dir")"; fi
        fi
    done
    if [[ -f "$DESKTOP_DEST" ]] && grep -qF "$MARCA_DESKTOP" "$DESKTOP_DEST"; then
        if [[ "$DRY_RUN" == true ]]; then simula "quitaria $DESKTOP_DEST"; else rm -f "$DESKTOP_DEST"; info ".desktop propio removido"; fi
    fi
}

# ------------------------------------------------------------------------------

command -v sqlite3 &>/dev/null || { echo "[firefox][WARN] falta sqlite3: no se puede resolver los perfiles" >&2; exit 3; }
[[ -d "$FF_DIR" ]] || { echo "[firefox][WARN] no existe $FF_DIR (Firefox nunca se abrio?)" >&2; exit 3; }

DIR_PERSONAL="$(ruta_perfil "$NOMBRE_PERSONAL")"
DIR_APPS="$(ruta_perfil "$NOMBRE_APPS")"

if [[ "$MODO" == quitar ]]; then
    quitar "$DIR_PERSONAL" "$DIR_APPS"
    exit 0
fi

if [[ -n "$DIR_PERSONAL" && -d "$DIR_PERSONAL" ]]; then
    escribir_userjs "$DIR_PERSONAL" "$NOMBRE_PERSONAL" "$AQUI/user.js"
    cargar_cookies  "$DIR_PERSONAL" "$NOMBRE_PERSONAL"
    fijar_zoom      "$DIR_PERSONAL" "$NOMBRE_PERSONAL"
    generar_desktop "$DIR_PERSONAL"
else
    saltar "no encuentro el perfil '$NOMBRE_PERSONAL': crealo desde el selector de perfiles de Firefox (nombre exacto) y re-corre"
fi

if [[ -n "$DIR_APPS" && -d "$DIR_APPS" ]]; then
    escribir_userjs "$DIR_APPS" "$NOMBRE_APPS" "$AQUI/user.js" "$AQUI/user-aplicaciones.js"
    cargar_cookies  "$DIR_APPS" "$NOMBRE_APPS"
    fijar_zoom      "$DIR_APPS" "$NOMBRE_APPS"
else
    saltar "no encuentro el perfil '$NOMBRE_APPS': crealo desde el selector de perfiles de Firefox (nombre exacto) y re-corre"
fi

[[ "$SALTADOS" -eq 0 ]] || exit 3
exit 0
