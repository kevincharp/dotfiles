#!/usr/bin/env bash
# ==============================================================================
#   uninstall.sh — Desinstalar dotfiles
#   Uso:   bash uninstall.sh [--remove-packages] [--dry-run] [--force]
# ==============================================================================

set -euo pipefail

# ==============================================================================
# PARAMETROS
# ==============================================================================

REMOVE_PACKAGES=false
DRY_RUN=false
FORCE=false

for arg in "$@"; do
    case "$arg" in
        --remove-packages) REMOVE_PACKAGES=true ;;
        --dry-run)         DRY_RUN=true ;;
        --force)           FORCE=true ;;
        *)
            echo "Uso: bash uninstall.sh [--remove-packages] [--dry-run] [--force]"
            echo ""
            echo "Opciones:"
            echo "  --remove-packages  Desinstalar paquetes instalados por bootstrap"
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

# Lista de symlinks/archivos creados por el bootstrap
DOTFILES_TARGETS=(
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.config/git/ignore"
    "$HOME/.gitconfig"
    "$HOME/.config/git-identities.sh"
    "$HOME/.ssh/config"
    "$HOME/.editorconfig"
    "$HOME/.config/fontconfig/fonts.conf"
    "$HOME/.claude/settings.json"
    "$HOME/.claude/CLAUDE.md"
    "$HOME/.claude/agents"
    # settings.local.json no va: es per-maquina y el bootstrap no lo crea.
    "$HOME/.config/oh-my-posh/themes/claude-code.omp.json"
    "$HOME/.config/ulauncher/settings.json"
    "$HOME/.config/ulauncher/shortcuts.json"
    "$HOME/.config/ulauncher/user-themes"
    "$HOME/.config/autostart/ulauncher.desktop"
    "$HOME/.config/openlogi/config.toml"
    # Override generado (no symlink) para que los lanzadores abran Ptyxis en
    # ventana nueva; sin el, vuelve a regir el .desktop del sistema.
    "$HOME/.local/share/applications/org.gnome.Ptyxis.desktop"
    "$HOME/.config/yazi/yazi.toml"
    "$HOME/.config/nvim"
    "$HOME/.codex/AGENTS.md"
    "$HOME/.config/opencode/AGENTS.md"
    # Copia del vault con el token de iCloud: no debe quedar huerfana.
    "$HOME/.config/rclone/rclone.conf"
)

for _s in personal work cei_walle; do DOTFILES_TARGETS+=("$HOME/.gitconfig-$_s"); done
unset _s

# Catalogo de herramientas (TOOLS_CATALOG): de ahi salen los paquetes a quitar.
source "$(dirname "${BASH_SOURCE[0]}")/catalogo.sh"

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

# pkg_presente <id> <comando> <paquete> - 0 si --remove-packages tiene algo que quitar.
pkg_presente() {
    case "$1" in
        lazyssh|lazysql) [[ -f "$HOME/.local/bin/$1" ]] ;;
        samba)           has_cmd smbd ;;
        openlogi)        rpm -q openlogi &>/dev/null ;;
        chrome)          rpm -q google-chrome-stable &>/dev/null ;;
        obsidian)        has_cmd flatpak && flatpak info md.obsidian.Obsidian &>/dev/null ;;
        *)               [[ -n "$3" ]] && has_cmd "$2" ;;
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
# 2. MOSTRAR PREVIEW Y PEDIR CONFIRMACION
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
    for entry in "${TOOLS_CATALOG[@]}"; do
        IFS='|' read -r id _ cmd pkg _ <<< "$entry"
        if pkg_presente "$id" "$cmd" "$pkg"; then
            prev "$id"
        fi
    done
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
# 3. REMOVER SYMLINKS Y ARCHIVOS
# ==============================================================================

log "--- [1/3] Removiendo symlinks y archivos dotfiles ---" "SECTION"

for target in "${DOTFILES_TARGETS[@]}"; do
    if [[ -L "$target" ]]; then
        rm "$target" && log "Removido symlink: $target" "OK"
    elif [[ -f "$target" ]]; then
        rm "$target" && log "Removido archivo: $target" "OK"
    fi
done

# Firefox: user.js de cada perfil y el .desktop que fija el perfil. No son
# destinos fijos (las carpetas de perfil son aleatorias), los resuelve el script
# del repo, y solo borra lo que lleva su marca. Los perfiles y sus datos no se tocan.
if [[ -x "$DOTFILES_DIR/firefox/aplicar-perfiles.sh" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        "$DOTFILES_DIR/firefox/aplicar-perfiles.sh" --quitar --dry-run || true
    else
        "$DOTFILES_DIR/firefox/aplicar-perfiles.sh" --quitar || true
    fi
fi

# ==============================================================================
# 4. DESINSTALAR PAQUETES (OPCIONAL)
# ==============================================================================

log "--- [2/3] Desinstalando paquetes ---" "SECTION"

if [[ "$REMOVE_PACKAGES" != true ]]; then
    log "Saltando desinstalación de paquetes (usa --remove-packages)" "SKIP"
else
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
        for entry in "${TOOLS_CATALOG[@]}"; do
            IFS='|' read -r id _ cmd pkg _ <<< "$entry"
            # Override local de Chrome que genera el bootstrap: se quita aunque no este el paquete.
            [[ "$id" == chrome ]] && rm -f "$HOME/.local/share/applications/com.google.Chrome.desktop"
            pkg_presente "$id" "$cmd" "$pkg" || continue
            case "$id" in
                lazyssh|lazysql)
                    rm -f "$HOME/.local/bin/$id" && log "Removido: $id (~/.local/bin)" "OK"
                    ;;
                samba)
                    sudo systemctl disable --now smb &>/dev/null || true
                    $PKG_REMOVE samba && log "Desinstalado: samba" "OK" || log "Fallo al desinstalar samba" "WARN"
                    ;;
                openlogi)
                    systemctl --user disable --now openlogi-agent.service &>/dev/null || true
                    $PKG_REMOVE openlogi && log "Desinstalado: openlogi" "OK" || log "Fallo al desinstalar openlogi" "WARN"
                    ;;
                obsidian)
                    sudo flatpak uninstall -y md.obsidian.Obsidian \
                        && log "Desinstalado: obsidian (Flatpak)" "OK" \
                        || log "Fallo al desinstalar obsidian" "WARN"
                    ;;
                chrome)
                    $PKG_REMOVE google-chrome-stable \
                        && log "Desinstalado: google-chrome-stable" "OK" \
                        || log "Fallo al desinstalar google-chrome-stable" "WARN"
                    sudo rm -f /etc/yum.repos.d/google-chrome.repo \
                        && log "Removido: repo de Google" "OK"
                    ;;
                *)
                    $PKG_REMOVE "$pkg" && log "Desinstalado: $pkg" "OK" || log "Fallo al desinstalar $pkg" "WARN"
                    ;;
            esac
        done
        log "No se desinstalan (instaladas fuera del gestor): oh-my-posh, zoxide, opencode, claude, aws" "SKIP"
    fi
fi

# ==============================================================================
# 5. BORRAR REPOSITORIOS
# ==============================================================================

log "--- [3/3] Borrando repositorios ---" "SECTION"

if [[ -d "$DOTFILES_DIR" ]]; then
    rm -rf "$DOTFILES_DIR" && log "Borrado: $DOTFILES_DIR" "OK"
fi

if [[ -d "$VAULT_DIR" ]]; then
    rm -rf "$VAULT_DIR" && log "Borrado: $VAULT_DIR" "OK"
fi

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================

log "Desinstalacion completada" "SECTION"
log "Dotfiles desinstalados correctamente." "OK"
log "Para reinstalar, ejecuta:" "INFO"
log "curl -fsSL https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.sh | bash" "INFO"
