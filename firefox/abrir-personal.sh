#!/usr/bin/env bash
# abrir-personal.sh - abre una URL en Firefox (perfil Personal) como $BROWSER.
# Desacoplado de la terminal: lanzado directo, Firefox vuelca ahi sus logs.
# Usa el .desktop que genera aplicar-perfiles.sh; si no existe, 'firefox' pelado.
DESKTOP="$HOME/.local/share/applications/org.mozilla.firefox.desktop"

if [[ -f "$DESKTOP" ]] && grep -qF "X-Dotfiles-Generado=firefox" "$DESKTOP" && command -v gio &>/dev/null; then
    nohup gio launch "$DESKTOP" "$@" >/dev/null 2>&1 &
else
    nohup firefox "$@" >/dev/null 2>&1 &
fi
