#!/usr/bin/env bash
# ==============================================================================
#   uninstall.sh — Desinstalar dotfiles y restaurar estado previo
#   Autor: Kevin Charpentier
#   Uso:   bash uninstall.sh [--remove-packages] [--keep-backups] [--dry-run] [--force]
# ==============================================================================

set -euo pipefail

# ==============================================================================
# PARAMETROS
# ==============================================================================

REMOVE_PACKAGES=false
KEEP_BACKUPS=false
DRY_RUN=false
FORCE=false

for arg in "$@"; do
    case "$arg" in
        --remove-packages) REMOVE_PACKAGES=true ;;
        --keep-backups)    KEEP_BACKUPS=true ;;
        --dry-run)         DRY_RUN=true ;;
        --force)           FORCE=true ;;
        *)
            echo "Uso: bash uninstall.sh [--remove-packages] [--keep-backups] [--dry-run] [--force]"
            echo ""
            echo "Opciones:"
            echo "  --remove-packages  Desinstalar paquetes instalados por bootstrap"
            echo "  --keep-backups     No borrar ~/.local/backups/bootstrap/"
            echo "  --dry-run          Mostrar qué haría sin ejecutar"
            echo "  --force            No pedir confirmación (peligroso)"
            exit 1
            ;;
    esac
done

# ==============================================================================
# CONFIGURACION
# ==============================================================================

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
VAULT_DIR="${VAULT_DIR:-$HOME/.dotfiles-vault}"
BACKUPS_DIR="$HOME/.local/backups/bootstrap"

# Lista de symlinks/archivos creados por el bootstrap
DOTFILES_TARGETS=(
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.config/git/ignore"
    "$HOME/.gitconfig"
    "$HOME/.gitconfig-personal"
    "$HOME/.gitconfig-work"
    "$HOME/.gitconfig-cei_walle"
    "$HOME/.config/git-identities.sh"
    "$HOME/.ssh/config"
    "$HOME/.editorconfig"
    "$HOME/.claude/settings.json"
    "$HOME/.claude/settings.local.json"
    "$HOME/.claude/plugins/installed_plugins.json"
    "$HOME/.config/oh-my-posh/themes/claude-code.omp.json"
)

# Lista de paquetes instalados (solo si --remove-packages)
PACKAGES=(
    neovim
    ripgrep
    fzf
    oh-my-posh
    zoxide
    lazygit
    eza
    age
    glab
    opencode
    aws
    claude
)

# ==============================================================================
# HELPERS
# ==============================================================================

log() {
    local level="${2:-INFO}"
    local ts
    ts="$(date +%H:%M:%S)"
    case "$level" in
        OK)      echo -e "\033[32m[$ts] $1\033[0m" ;;
        WARN)    echo -e "\033[33m[$ts] $1\033[0m" ;;
        ERROR)   echo -e "\033[31m[$ts] $1\033[0m" ;;
        SKIP)    echo -e "\033[90m[$ts] $1\033[0m" ;;
        SECTION) echo -e "\033[36m$1\033[0m" ;;
        *)       echo "[$ts] $1" ;;
    esac
}

ask_confirmation() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    local prompt="$1"
    read -p "$prompt [y/N]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

has_cmd() {
    command -v "$1" &>/dev/null
}

# ==============================================================================
# INICIO
# ==============================================================================

log "======================================================" "SECTION"
log "  uninstall.sh — Desinstalación de dotfiles" "SECTION"
log "  DryRun: $DRY_RUN" "SECTION"
log "======================================================" "SECTION"
echo ""

# ==============================================================================
# 1. VERIFICAR QUE EXISTEN LOS REPOS
# ==============================================================================

if [[ ! -d "$DOTFILES_DIR" && ! -d "$VAULT_DIR" ]]; then
    log "No se encontraron dotfiles instalados en:" "ERROR"
    log "  - $DOTFILES_DIR" "ERROR"
    log "  - $VAULT_DIR" "ERROR"
    log "Nada que desinstalar." "INFO"
    exit 0
fi

# ==============================================================================
# 2. ENCONTRAR BACKUP MAS RECIENTE
# ==============================================================================

LATEST_BACKUP=""
if [[ -d "$BACKUPS_DIR" ]]; then
    LATEST_BACKUP=$(ls -t "$BACKUPS_DIR" 2>/dev/null | head -1)
    if [[ -n "$LATEST_BACKUP" ]]; then
        LATEST_BACKUP="$BACKUPS_DIR/$LATEST_BACKUP"
        log "Backup más reciente encontrado: $LATEST_BACKUP" "OK"
    else
        log "No se encontraron backups en $BACKUPS_DIR" "WARN"
    fi
else
    log "Directorio de backups no existe: $BACKUPS_DIR" "WARN"
fi

# ==============================================================================
# 3. MOSTRAR PREVIEW Y PEDIR CONFIRMACION
# ==============================================================================

echo ""
log "======================================================" "SECTION"
log "  PREVIEW — Qué se va a desinstalar:" "SECTION"
log "======================================================" "SECTION"
echo ""

echo "Symlinks/archivos a remover:"
for target in "${DOTFILES_TARGETS[@]}"; do
    if [[ -e "$target" || -L "$target" ]]; then
        echo "  ✗ $target"
    fi
done

echo ""
echo "Repositorios a borrar:"
[[ -d "$DOTFILES_DIR" ]] && echo "  ✗ $DOTFILES_DIR"
[[ -d "$VAULT_DIR" ]] && echo "  ✗ $VAULT_DIR"

if [[ "$REMOVE_PACKAGES" == true ]]; then
    echo ""
    echo "Paquetes a desinstalar (--remove-packages):"
    for pkg in "${PACKAGES[@]}"; do
        if has_cmd "$pkg"; then
            echo "  ✗ $pkg"
        fi
    done
fi

if [[ -n "$LATEST_BACKUP" ]]; then
    echo ""
    echo "Archivos a restaurar desde backup:"
    find "$LATEST_BACKUP" -type f 2>/dev/null | sed "s|$LATEST_BACKUP|  ← |" | head -10
    backup_count=$(find "$LATEST_BACKUP" -type f 2>/dev/null | wc -l)
    if [[ $backup_count -gt 10 ]]; then
        echo "  ... y $((backup_count - 10)) más"
    fi
fi

if [[ "$KEEP_BACKUPS" == false ]]; then
    echo ""
    echo "Backups a borrar:"
    echo "  ✗ $BACKUPS_DIR"
fi

echo ""
log "======================================================" "SECTION"

if [[ "$DRY_RUN" == true ]]; then
    log "[DRY RUN] No se ejecutará ninguna acción destructiva." "SKIP"
    exit 0
fi

echo ""
if ! ask_confirmation "¿Continuar con la desinstalación?"; then
    log "Desinstalación cancelada por el usuario." "WARN"
    exit 0
fi

# ==============================================================================
# 4. REMOVER SYMLINKS Y ARCHIVOS
# ==============================================================================

echo ""
log "--- [1/5] Removiendo symlinks y archivos dotfiles ---" "SECTION"

for target in "${DOTFILES_TARGETS[@]}"; do
    if [[ -L "$target" ]]; then
        rm "$target" && log "Removido symlink: $target" "OK"
    elif [[ -f "$target" ]]; then
        rm "$target" && log "Removido archivo: $target" "OK"
    fi
done

# ==============================================================================
# 5. RESTAURAR BACKUPS
# ==============================================================================

echo ""
log "--- [2/5] Restaurando backups ---" "SECTION"

if [[ -n "$LATEST_BACKUP" && -d "$LATEST_BACKUP" ]]; then
    restored_count=0
    while IFS= read -r backup_file; do
        relative_path="${backup_file#$LATEST_BACKUP/}"
        dest="$HOME/$relative_path"
        dest_dir="$(dirname "$dest")"

        mkdir -p "$dest_dir"
        cp "$backup_file" "$dest" && ((restored_count++))
    done < <(find "$LATEST_BACKUP" -type f)

    log "Restaurados $restored_count archivos desde backup" "OK"
else
    log "No hay backups para restaurar, saltando" "SKIP"
fi

# ==============================================================================
# 6. DESINSTALAR PAQUETES (OPCIONAL)
# ==============================================================================

echo ""
log "--- [3/5] Desinstalando paquetes ---" "SECTION"

if [[ "$REMOVE_PACKAGES" != true ]]; then
    log "Saltando desinstalación de paquetes (usa --remove-packages)" "SKIP"
else
    # Detectar package manager
    if has_cmd dnf; then
        PKG_MANAGER="dnf"
        PKG_REMOVE="sudo dnf remove -y"
    elif has_cmd apt; then
        PKG_MANAGER="apt"
        PKG_REMOVE="sudo apt remove -y"
    elif has_cmd pacman; then
        PKG_MANAGER="pacman"
        PKG_REMOVE="sudo pacman -R --noconfirm"
    else
        log "Package manager no detectado, saltando" "WARN"
        PKG_MANAGER="none"
    fi

    if [[ "$PKG_MANAGER" != "none" ]]; then
        for pkg in "${PACKAGES[@]}"; do
            # Saltar paquetes que son scripts (no paquetes del sistema)
            case "$pkg" in
                oh-my-posh|zoxide|opencode|claude)
                    log "Saltando $pkg (instalado como binario, no paquete)" "SKIP"
                    ;;
                aws)
                    log "Saltando aws (instalador custom, desinstalar manualmente)" "SKIP"
                    ;;
                *)
                    if has_cmd "$pkg"; then
                        $PKG_REMOVE "$pkg" && log "Desinstalado: $pkg" "OK" || log "Fallo al desinstalar $pkg" "WARN"
                    fi
                    ;;
            esac
        done
    fi
fi

# ==============================================================================
# 7. BORRAR REPOSITORIOS
# ==============================================================================

echo ""
log "--- [4/5] Borrando repositorios ---" "SECTION"

if [[ -d "$DOTFILES_DIR" ]]; then
    rm -rf "$DOTFILES_DIR" && log "Borrado: $DOTFILES_DIR" "OK"
fi

if [[ -d "$VAULT_DIR" ]]; then
    rm -rf "$VAULT_DIR" && log "Borrado: $VAULT_DIR" "OK"
fi

# ==============================================================================
# 8. BORRAR BACKUPS (OPCIONAL)
# ==============================================================================

echo ""
log "--- [5/5] Borrando backups ---" "SECTION"

if [[ "$KEEP_BACKUPS" == true ]]; then
    log "Conservando backups en $BACKUPS_DIR (--keep-backups)" "SKIP"
else
    if [[ -d "$BACKUPS_DIR" ]]; then
        rm -rf "$BACKUPS_DIR" && log "Borrado: $BACKUPS_DIR" "OK"
    else
        log "No hay backups para borrar" "SKIP"
    fi
fi

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================

echo ""
log "======================================================" "SECTION"
log "  DESINSTALACIÓN COMPLETADA" "SECTION"
log "======================================================" "SECTION"
echo ""
log "Dotfiles desinstalados correctamente." "OK"
echo ""
log "Para reinstalar, ejecutá:" "INFO"
log "  curl -fsSL https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.sh | bash" "INFO"
echo ""
log "======================================================" "SECTION"
