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
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.config/git/ignore"
    "$HOME/.gitconfig"
    "$HOME/.gitconfig-personal"
    "$HOME/.gitconfig-work"
    "$HOME/.gitconfig-cei_walle"
    "$HOME/.config/git-identities.sh"
    "$HOME/.ssh/config"
    "$HOME/.editorconfig"
    "$HOME/.claude/settings.json"
    "$HOME/.claude/CLAUDE.md"
    "$HOME/.claude/settings.local.json"
    "$HOME/.claude/plugins/installed_plugins.json"
    "$HOME/.config/oh-my-posh/themes/claude-code.omp.json"
    "$HOME/.config/ulauncher/settings.json"
    "$HOME/.config/ulauncher/shortcuts.json"
    "$HOME/.config/ulauncher/user-themes"
    "$HOME/.config/autostart/ulauncher.desktop"
    "$HOME/.config/openlogi/config.toml"
)

# Lista de paquetes instalados (solo si --remove-packages)
PACKAGES=(
    neovim
    ripgrep
    fzf
    oh-my-posh
    zoxide
    lazygit
    zsh
    eza
    age
    gh
    glab
    opencode
    aws
    claude
    ulauncher
    samba
    openlogi
)

# ==============================================================================
# HELPERS
# ==============================================================================

if [[ "${LANG:-}${LC_ALL:-}${LC_CTYPE:-}" == *[Uu][Tt][Ff]* ]]; then
    I_SECTION="▶"; I_OK="✓"; I_WARN="⚠"; I_ERROR="✗"; I_SKIP="⊘"; I_BULLET="✗"
else
    I_SECTION=">"; I_OK="[OK]"; I_WARN="[!]"; I_ERROR="[X]"; I_SKIP="[-]"; I_BULLET="*"
fi
C_RESET=$'\033[0m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERROR=$'\033[31m'
C_SKIP=$'\033[90m'; C_SECTION=$'\033[1;36m'; C_DIM=$'\033[90m'

log() {
    local msg="$1" level="${2:-INFO}"
    case "$level" in
        SECTION)
            local clean
            clean="$(printf '%s' "$msg" | sed -E 's/^[[:space:]=#-]+//; s/[[:space:]=#-]+$//')"
            [[ -z "$clean" ]] && return 0
            printf '\n%s%s %s%s\n' "$C_SECTION" "$I_SECTION" "$clean" "$C_RESET" ;;
        OK)      printf '  %s%s%s %s\n' "$C_OK"    "$I_OK"    "$C_RESET" "$msg" ;;
        WARN)    printf '  %s%s%s %s\n' "$C_WARN"  "$I_WARN"  "$C_RESET" "$msg" ;;
        ERROR)   printf '  %s%s%s %s\n' "$C_ERROR" "$I_ERROR" "$C_RESET" "$msg" ;;
        SKIP)    printf '  %s%s %s%s\n' "$C_SKIP"  "$I_SKIP"  "$msg" "$C_RESET" ;;
        *)       if [[ -z "$msg" ]]; then printf '\n'; else printf '    %s%s%s\n' "$C_DIM" "$msg" "$C_RESET"; fi ;;
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

# pkg_cmd <paquete> — comando real que provee el paquete (cuando difiere del nombre).
# Sin esto, has_cmd neovim/ripgrep da false (los binarios son nvim/rg) y nunca se
# desinstalan aunque esten presentes.
pkg_cmd() {
    case "$1" in
        neovim)  echo "nvim" ;;
        ripgrep) echo "rg" ;;
        samba)   echo "smbd" ;;
        *)       echo "$1" ;;
    esac
}

# ==============================================================================
# INICIO
# ==============================================================================

log "uninstall.sh — Desinstalacion de dotfiles" "SECTION"
[[ "$DRY_RUN" == true ]] && log "modo DryRun" "INFO"

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

# Item de preview: marca lo que se va a quitar (rojo tenue)
prev() { printf '    %s%s %s%s\n' "$C_ERROR" "$I_BULLET" "$1" "$C_RESET"; }

log "Preview — Que se va a desinstalar" "SECTION"

log "Symlinks/archivos a remover:" "INFO"
for target in "${DOTFILES_TARGETS[@]}"; do
    if [[ -e "$target" || -L "$target" ]]; then
        prev "$target"
    fi
done

log "Repositorios a borrar:" "INFO"
[[ -d "$DOTFILES_DIR" ]] && prev "$DOTFILES_DIR"
[[ -d "$VAULT_DIR" ]] && prev "$VAULT_DIR"

if [[ "$REMOVE_PACKAGES" == true ]]; then
    log "Paquetes a desinstalar (--remove-packages):" "INFO"
    for pkg in "${PACKAGES[@]}"; do
        if has_cmd "$(pkg_cmd "$pkg")"; then
            prev "$pkg"
        fi
    done
fi

if [[ -n "$LATEST_BACKUP" ]]; then
    log "Archivos a restaurar desde backup:" "INFO"
    find "$LATEST_BACKUP" -type f 2>/dev/null | sed "s|$LATEST_BACKUP|    ↺ |" | head -10
    backup_count=$(find "$LATEST_BACKUP" -type f 2>/dev/null | wc -l)
    if [[ $backup_count -gt 10 ]]; then
        log "... y $((backup_count - 10)) mas" "INFO"
    fi
fi

if [[ "$KEEP_BACKUPS" == false ]]; then
    log "Backups a borrar:" "INFO"
    prev "$BACKUPS_DIR"
fi

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

log "--- [1/5] Removiendo symlinks y archivos dotfiles ---" "SECTION"

for target in "${DOTFILES_TARGETS[@]}"; do
    if [[ -L "$target" ]]; then
        rm "$target" && log "Removido symlink: $target" "OK"
    elif [[ -f "$target" ]]; then
        rm "$target" && log "Removido archivo: $target" "OK"
    fi
done

# Apps de escritorio (Pake): no son symlinks (AppImage + .desktop + icono
# generados al compilar), por eso van aparte de DOTFILES_TARGETS.
_pake_apps_dir="$HOME/.local/share/pake-apps"
if [[ -d "$_pake_apps_dir" ]]; then
    rm -rf "$_pake_apps_dir" && log "Removido: $_pake_apps_dir (AppImages Pake)" "OK"
fi
for f in "$HOME/.local/share/applications/"pake-*.desktop "$HOME/.local/share/icons/"pake-*.png; do
    [[ -e "$f" ]] && rm -f "$f" && log "Removido: $f" "OK"
done
command -v update-desktop-database &>/dev/null && \
    update-desktop-database "$HOME/.local/share/applications" &>/dev/null || true

# Apps de escritorio (Flatpak): se desinstalan con flatpak, no borrando archivos.
# Recorre la receta (apps/flatpak-apps.txt) y quita lo que este instalado a --user.
_flatpak_recipe="$DOTFILES_DIR/apps/flatpak-apps.txt"
if command -v flatpak &>/dev/null && [[ -f "$_flatpak_recipe" ]]; then
    while IFS='|' read -r _fp_id _fp_name _fp_appid; do
        [[ "$_fp_id" =~ ^[[:space:]]*# || -z "${_fp_appid:-}" ]] && continue
        if flatpak info --user "$_fp_appid" &>/dev/null; then
            flatpak uninstall -y --user "$_fp_appid" &>/dev/null \
                && log "Removido: $_fp_appid (Flatpak)" "OK"
        fi
    done < "$_flatpak_recipe"
fi

# ==============================================================================
# 5. RESTAURAR BACKUPS
# ==============================================================================

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
                samba)
                    # Servicio: parar y deshabilitar antes de remover el paquete.
                    if has_cmd smbd; then
                        sudo systemctl disable --now smb &>/dev/null || true
                        $PKG_REMOVE samba && log "Desinstalado: samba" "OK" || log "Fallo al desinstalar samba" "WARN"
                    fi
                    ;;
                openlogi)
                    # Servicio de usuario: parar/deshabilitar antes de remover el .rpm.
                    if rpm -q openlogi &>/dev/null; then
                        systemctl --user disable --now openlogi-agent.service &>/dev/null || true
                        $PKG_REMOVE openlogi && log "Desinstalado: openlogi" "OK" || log "Fallo al desinstalar openlogi" "WARN"
                    fi
                    ;;
                *)
                    if has_cmd "$(pkg_cmd "$pkg")"; then
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

log "Desinstalacion completada" "SECTION"
log "Dotfiles desinstalados correctamente." "OK"
log "Para reinstalar, ejecuta:" "INFO"
log "curl -fsSL https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.sh | bash" "INFO"
