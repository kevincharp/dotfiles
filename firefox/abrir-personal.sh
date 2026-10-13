#!/usr/bin/env bash
# abrir-personal.sh - abre una URL en Firefox (perfil Personal) sin heredar la
# salida de la terminal. Pensado como $BROWSER (p. ej. para 'aws sso login'):
# Firefox, lanzado desde la terminal, vuelca sus logs ahi (ruido de Safe
# Browsing con 400, etc.) incluso despues de que el comando termino.
#
# Usa el .desktop propio que genera aplicar-perfiles.sh (lleva -profile fijo al
# perfil Personal); si no existe, cae a 'firefox' pelado.
DESKTOP="$HOME/.local/share/applications/org.mozilla.firefox.desktop"

if [[ -f "$DESKTOP" ]] && grep -qF "X-Dotfiles-Generado=firefox" "$DESKTOP" && command -v gio &>/dev/null; then
    nohup gio launch "$DESKTOP" "$@" >/dev/null 2>&1 &
else
    nohup firefox "$@" >/dev/null 2>&1 &
fi
