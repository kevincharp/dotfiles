#!/usr/bin/env bash
# ==============================================================================
#   update.sh — Actualizacion rapida de dotfiles (publico + vault)
#   Autor: Kevin Charpentier
#
#   Uso:
#     bash ~/.dotfiles/update.sh [--with-aws] [--skip-packages]
#
#   Delega en install.sh, que actualiza ambos repos (publico y vault privado)
#   y vuelve a correr el bootstrap. Para solo actualizar sin bootstrap usa:
#     bash ~/.dotfiles/install.sh --update-only
# ==============================================================================

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    echo "Error: $DOTFILES_DIR no es un repositorio git"
    echo "Instalacion inicial:"
    echo "  curl -fsSL https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.sh | bash"
    exit 1
fi

exec bash "$DOTFILES_DIR/install.sh" "$@"
