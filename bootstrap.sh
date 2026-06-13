#!/usr/bin/env bash
# ==============================================================================
#   bootstrap.sh — Setup completo de entorno de desarrollo (Linux / bash)
#   Autor: Kevin Charpentier
#   Uso:   bash bootstrap.sh [--with-aws] [--dry-run] [--skip-packages]
# ==============================================================================

set -euo pipefail

# ==============================================================================
# PARAMETROS
# ==============================================================================

WITH_AWS=false
DRY_RUN=false
SKIP_PACKAGES=false

for arg in "$@"; do
    case "$arg" in
        --with-aws)       WITH_AWS=true ;;
        --dry-run)        DRY_RUN=true ;;
        --skip-packages)  SKIP_PACKAGES=true ;;
        *)
            echo "Uso: bash bootstrap.sh [--with-aws] [--dry-run] [--skip-packages]"
            exit 1
            ;;
    esac
done

# ==============================================================================
# CONFIGURACION
# ==============================================================================

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
# Vault privado con lo sensible (ssh, identidades git, bookmarks).
# install.sh lo clona en ~/.dotfiles-vault; si no esta, se saltean esos pasos.
VAULT_DIR="${VAULT_DIR:-$HOME/.dotfiles-vault}"
LOG_DIR="$HOME/.local/logs"
LOG_FILE="$LOG_DIR/bootstrap-$(date +%Y%m%d-%H%M%S).log"
ERRORS=()
WARNINGS=()
BACKUP_TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.local/backups/bootstrap/$BACKUP_TS"

# ==============================================================================
# HELPERS
# ==============================================================================

log() {
    local level="${2:-INFO}"
    local ts
    ts="$(date +%H:%M:%S)"
    local line="[$ts][$level] $1"

    case "$level" in
        OK)      echo -e "\033[32m$line\033[0m" ;;
        WARN)    echo -e "\033[33m$line\033[0m" ;;
        ERROR)   echo -e "\033[31m$line\033[0m" ;;
        SKIP)    echo -e "\033[90m$line\033[0m" ;;
        SECTION) echo -e "\033[36m$line\033[0m" ;;
        *)       echo "$line" ;;
    esac

    echo "$line" >> "$LOG_FILE" 2>/dev/null || true
}

run_step() {
    local name="$1"
    shift
    if [[ "$DRY_RUN" == true ]]; then
        log "[DryRun] $name" "SKIP"
        return
    fi
    if "$@"; then
        log "$name" "OK"
    else
        log "$name → fallo" "ERROR"
        ERRORS+=("$name")
    fi
}

has_cmd() {
    command -v "$1" &>/dev/null
}

# ==============================================================================
# INICIO
# ==============================================================================

mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

log "======================================================" "SECTION"
log "  bootstrap.sh — Inicio: $(date '+%Y-%m-%d %H:%M:%S')" "SECTION"
log "  DryRun: $DRY_RUN" "SECTION"
log "======================================================" "SECTION"

# ==============================================================================
# 1. VERIFICAR REQUISITOS
# ==============================================================================

log "--- [1/7] Verificando requisitos ---" "SECTION"

if ! has_cmd git; then
    log "Git no esta instalado" "ERROR"
    exit 1
fi
log "git $(git --version | cut -d' ' -f3) OK" "OK"

# Detectar distro
if has_cmd apt; then
    PKG_MANAGER="apt"
    PKG_INSTALL="sudo apt install -y"
    PKG_UPDATE="sudo apt update"
elif has_cmd dnf; then
    PKG_MANAGER="dnf"
    PKG_INSTALL="sudo dnf install -y"
    PKG_UPDATE="sudo dnf check-update || true"
elif has_cmd pacman; then
    PKG_MANAGER="pacman"
    PKG_INSTALL="sudo pacman -S --noconfirm"
    PKG_UPDATE="sudo pacman -Sy"
else
    log "Package manager no detectado (apt/dnf/pacman)" "WARN"
    PKG_MANAGER="none"
fi
log "Package manager: $PKG_MANAGER" "OK"

# ==============================================================================
# 2. INSTALAR PAQUETES
# ==============================================================================

log "--- [2/7] Instalando paquetes ---" "SECTION"

if [[ "$SKIP_PACKAGES" == true ]]; then
    log "skip-packages activado, saltando" "SKIP"
elif [[ "$PKG_MANAGER" == "none" ]]; then
    log "Sin package manager, saltando paquetes" "WARN"
    WARNINGS+=("Instalar paquetes manualmente: neovim, ripgrep, fzf, zoxide, lazygit")
else
    if [[ "$DRY_RUN" == false ]]; then
        log "Actualizando fuentes..." "INFO"
        $PKG_UPDATE 2>&1 | tail -1
    fi

    # Paquetes basicos (nombres para apt, ajustar si usas otra distro)
    PACKAGES=(
        neovim
        ripgrep
        fzf
        git
        curl
        wget
        unzip
        bash-completion
    )

    for pkg in "${PACKAGES[@]}"; do
        if dpkg -l "$pkg" &>/dev/null 2>&1 || rpm -q "$pkg" &>/dev/null 2>&1 || pacman -Q "$pkg" &>/dev/null 2>&1; then
            log "$pkg ya instalado" "SKIP"
        else
            run_step "Instalar $pkg" $PKG_INSTALL "$pkg"
        fi
    done

    # oh-my-posh (binario unico)
    if ! has_cmd oh-my-posh; then
        run_step "Instalar oh-my-posh" bash -c 'curl -s https://ohmyposh.dev/install.sh | bash -s'
    else
        log "oh-my-posh ya instalado" "SKIP"
    fi

    # zoxide
    if ! has_cmd zoxide; then
        run_step "Instalar zoxide" bash -c 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
    else
        log "zoxide ya instalado" "SKIP"
    fi

    # lazygit — Fedora: COPR | Arch: repos | Debian: binario
    if ! has_cmd lazygit; then
        if [[ "$PKG_MANAGER" == "dnf" ]]; then
            run_step "Instalar lazygit (COPR)" bash -c '
                sudo dnf install -y dnf-plugins-core
                sudo dnf copr enable -y atim/lazygit
                sudo dnf install -y lazygit
            '
        elif [[ "$PKG_MANAGER" == "pacman" ]]; then
            run_step "Instalar lazygit" sudo pacman -S --noconfirm lazygit
        else
            # apt y otros: binario desde GitHub releases
            run_step "Instalar lazygit (binario)" bash -c '
                LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po "\"tag_name\": \"v\K[^\"]*")
                curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
                tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
                sudo install /tmp/lazygit /usr/local/bin
                rm -f /tmp/lazygit /tmp/lazygit.tar.gz
            '
        fi
    else
        log "lazygit ya instalado" "SKIP"
    fi

    # eza (reemplazo moderno de ls)
    if ! has_cmd eza; then
        if [[ "$PKG_MANAGER" == "apt" ]]; then
            run_step "Instalar eza" bash -c '
                sudo mkdir -p /etc/apt/keyrings
                wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
                echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
                sudo apt update && sudo apt install -y eza
            '
        elif [[ "$PKG_MANAGER" == "dnf" ]]; then
            run_step "Instalar eza" sudo dnf install -y eza
        elif [[ "$PKG_MANAGER" == "pacman" ]]; then
            run_step "Instalar eza" sudo pacman -S --noconfirm eza
        else
            log "eza: instalar manualmente — https://github.com/eza-community/eza#installation" "WARN"
            WARNINGS+=("eza no instalado")
        fi
    else
        log "eza ya instalado" "SKIP"
    fi

    # Node.js LTS — nativo por distro
    if ! has_cmd node; then
        if [[ "$PKG_MANAGER" == "dnf" ]]; then
            run_step "Instalar Node.js" sudo dnf install -y nodejs npm
        elif [[ "$PKG_MANAGER" == "pacman" ]]; then
            run_step "Instalar Node.js" sudo pacman -S --noconfirm nodejs npm
        elif [[ "$PKG_MANAGER" == "apt" ]]; then
            # apt: el repo de Debian trae una version vieja, usamos NodeSource para LTS
            run_step "Instalar Node.js LTS" bash -c '
                curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
                sudo apt install -y nodejs
            '
        else
            log "Sin package manager para Node.js — instalar manualmente" "WARN"
            WARNINGS+=("Node.js no instalado")
        fi
    else
        log "Node.js $(node --version) ya instalado" "SKIP"
    fi

    # Codex CLI (OpenAI)
    if ! has_cmd codex; then
        if has_cmd node; then
            run_step "Instalar Codex CLI" sudo npm install -g @openai/codex
        else
            log "Node.js no disponible, no se puede instalar Codex CLI" "WARN"
            WARNINGS+=("Codex CLI no instalado — requiere Node.js")
        fi
    else
        log "Codex CLI ya instalado" "SKIP"
    fi
    log "  Nota: para instalar Codex Desktop ejecuta 'codex app' (descarga el instalador automaticamente)" "INFO"

    # Claude Code CLI
    if ! has_cmd claude; then
        run_step "Instalar Claude Code CLI" bash -c 'curl -fsSL https://claude.ai/download/linux | bash'
    else
        log "Claude Code ya instalado" "SKIP"
    fi

    # opencode (SST)
    if ! has_cmd opencode; then
        run_step "Instalar opencode" bash -c 'curl -fsSL https://opencode.ai/install | bash'
    else
        log "opencode ya instalado" "SKIP"
    fi

    # AWS CLI (requerido para claude-smg con Bedrock)
    if ! has_cmd aws; then
        run_step "Instalar AWS CLI" bash -c '
            curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
            unzip -qo /tmp/awscliv2.zip -d /tmp
            sudo /tmp/aws/install --update
            rm -rf /tmp/aws /tmp/awscliv2.zip
        '
    else
        log "AWS CLI ya instalado" "SKIP"
    fi

    # glab (GitLab CLI) — Fedora/Arch: repos | Debian: binario
    if ! has_cmd glab; then
        if [[ "$PKG_MANAGER" == "dnf" || "$PKG_MANAGER" == "pacman" ]]; then
            run_step "Instalar glab" $PKG_INSTALL glab
        else
            # apt y otros: binario desde GitLab releases
            run_step "Instalar glab (binario)" bash -c '
                GLAB_VERSION=$(curl -s "https://api.github.com/repos/profclems/glab/releases/latest" | grep -Po "\"tag_name\": \"v\K[^\"]*")
                curl -Lo /tmp/glab.tar.gz "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_Linux_x86_64.tar.gz"
                tar xf /tmp/glab.tar.gz -C /tmp
                sudo install /tmp/bin/glab /usr/local/bin
                rm -rf /tmp/glab /tmp/bin /tmp/glab.tar.gz
            '
        fi
    else
        log "glab ya instalado" "SKIP"
    fi

    # age (encriptacion de claves SSH) — nativo en repos de Fedora/Debian/Arch
    if ! has_cmd age; then
        if [[ "$PKG_MANAGER" == "dnf" || "$PKG_MANAGER" == "apt" || "$PKG_MANAGER" == "pacman" ]]; then
            run_step "Instalar age" $PKG_INSTALL age
        else
            # Fallback: binario desde GitHub releases
            run_step "Instalar age (binario)" bash -c '
                AGE_VERSION=$(curl -s "https://api.github.com/repos/FiloSottile/age/releases/latest" | grep -Po "\"tag_name\": \"v\K[^\"]*")
                curl -Lo /tmp/age.tar.gz "https://github.com/FiloSottile/age/releases/latest/download/age-v${AGE_VERSION}-linux-amd64.tar.gz"
                tar xf /tmp/age.tar.gz -C /tmp
                sudo install /tmp/age/age /usr/local/bin
                sudo install /tmp/age/age-keygen /usr/local/bin
                rm -rf /tmp/age /tmp/age.tar.gz
            '
        fi
    else
        log "age ya instalado" "SKIP"
    fi

    # Nerd Fonts (FiraCode como default)
    if ! fc-list | grep -qi "FiraCode Nerd Font"; then
        run_step "Instalar FiraCode Nerd Font" bash -c '
            FONT_DIR="$HOME/.local/share/fonts"
            mkdir -p "$FONT_DIR"
            NERD_FONTS_VERSION=$(curl -s "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" | grep -Po "\"tag_name\": \"v\K[^\"]*")
            curl -Lo /tmp/FiraCode.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
            unzip -qo /tmp/FiraCode.zip -d "$FONT_DIR"
            rm /tmp/FiraCode.zip
            fc-cache -fv > /dev/null
        '
    else
        log "FiraCode Nerd Font ya instalado" "SKIP"
    fi
fi

# ==============================================================================
# 3. CREAR ESTRUCTURA DE CARPETAS
# ==============================================================================

log "--- [3/7] Creando estructura de carpetas ---" "SECTION"

DIRS=(
    "$HOME/.config/git"
    "$HOME/.config/lazygit"
    "$HOME/.local/bin"
    "$HOME/.local/logs"
    "$HOME/.cache"
    "$HOME/.ssh"
    "$HOME/repositorios/personal"
    "$HOME/repositorios/work"
    "$HOME/repositorios/cei_walle"
)

for dir in "${DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        log "$dir ya existe" "SKIP"
    else
        run_step "Crear $dir" mkdir -p "$dir"
    fi
done

# Permisos seguros para .ssh
run_step "Permisos ~/.ssh" chmod 700 "$HOME/.ssh"

# Permisos seguros para .env (solo tu usuario puede leerlo)
if [[ -f "$HOME/.env" ]]; then
    run_step "Permisos ~/.env" chmod 600 "$HOME/.env"
else
    log "~/.env no existe — crealo manualmente con tus tokens" "WARN"
    WARNINGS+=("~/.env no encontrado — crealo y volve a ejecutar el bootstrap para asegurar permisos")
fi

# ==============================================================================
# 4. MIGRAR BACKUPS VIEJOS (.bak-*) → BACKUP_DIR
# ==============================================================================

log "--- [4/7] Migrando backups viejos ---" "SECTION"

migrate_old_backups() {
    local dst="$1"
    local dst_dir
    dst_dir="$(dirname "$dst")"
    local dst_name
    dst_name="$(basename "$dst")"

    # Buscar archivos .bak-* que correspondan a este dotfile
    for old_bak in "$dst_dir/$dst_name".bak-* "$dst".bak-*; do
        [[ -f "$old_bak" ]] || continue
        local rel_path="${dst#$HOME/}"
        local bak_name
        bak_name="$(basename "$old_bak")"
        # Extraer timestamp del nombre (yyyyMMdd-HHmmss)
        local ts
        ts=$(echo "$bak_name" | grep -oP '\d{8}-\d{6}' | tail -1)
        local target_dir="$BACKUP_DIR/_migrated${ts:+/$ts}"
        local target_file="$target_dir/$rel_path"
        local target_parent
        target_parent="$(dirname "$target_file")"
        [[ -d "$target_parent" ]] || mkdir -p "$target_parent"
        run_step "Migrar $old_bak → $target_file" mv "$old_bak" "$target_file"
    done
}

BAK_DESTINATIONS=(
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.gitconfig"
    "$HOME/.gitconfig-personal"
    "$HOME/.gitconfig-work"
    "$HOME/.gitconfig-cei_walle"
    "$HOME/.config/git/ignore"
    "$HOME/.ssh/config"
    "$HOME/.editorconfig"
    "$HOME/.claude/settings.json"
    "$HOME/.claude/settings.local.json"
    "$HOME/.claude/plugins/installed_plugins.json"
)

if [[ "$DRY_RUN" == true ]]; then
    log "[DryRun] Migrar backups viejos" "SKIP"
else
    found_old=0
    for dst in "${BAK_DESTINATIONS[@]}"; do
        migrate_old_backups "$dst"
    done
    # Contar si se migro algo
    if [[ -d "$BACKUP_DIR/_migrated" ]]; then
        migrated_count=$(find "$BACKUP_DIR/_migrated" -type f | wc -l)
        log "Migrados $migrated_count backups viejos a $BACKUP_DIR/_migrated/" "OK"
    else
        log "No se encontraron backups viejos para migrar" "SKIP"
    fi
fi

# ==============================================================================
# 5. COPIAR DOTFILES
# ==============================================================================

log "--- [5/7] Copiando dotfiles ---" "SECTION"

copy_dotfile() {
    # $1 relativo → se resuelve contra $REPO_ROOT; $1 absoluto (ej. del vault) → se usa tal cual
    local src
    if [[ "$1" == /* ]]; then
        src="$1"
    else
        src="$REPO_ROOT/$1"
    fi
    local dst="$2"
    local mode="${3:-copy}"  # copy | link

    if [[ ! -f "$src" ]]; then
        log "Origen no encontrado: $src" "WARN"
        WARNINGS+=("$src no encontrado")
        return
    fi

    # Backup si ya existe (archivo real, no symlink) → centralizado en BACKUP_DIR
    if [[ -f "$dst" && ! -L "$dst" ]]; then
        local rel_path="${dst#$HOME/}"
        local bak_dst="$BACKUP_DIR/$rel_path"
        local bak_dir
        bak_dir="$(dirname "$bak_dst")"
        [[ -d "$bak_dir" ]] || mkdir -p "$bak_dir"
        run_step "Backup $dst → $bak_dst" cp "$dst" "$bak_dst"
    fi

    local dst_dir
    dst_dir="$(dirname "$dst")"
    [[ -d "$dst_dir" ]] || mkdir -p "$dst_dir"

    if [[ "$mode" == "link" ]]; then
        [[ -e "$dst" || -L "$dst" ]] && rm -f "$dst"
        run_step "Symlink $1 → $dst" ln -s "$src" "$dst"
    else
        run_step "Copiar $1 → $dst" cp "$src" "$dst"
    fi
}

# Shell (symlinks: editar en el repo se ve al instante)
copy_dotfile "shell/bashrc"         "$HOME/.bashrc"        "link"
copy_dotfile "shell/bash_profile"   "$HOME/.bash_profile"  "link"

# Git ignore (publico)
copy_dotfile "git/ignore"           "$HOME/.config/git/ignore"    "link"

# Git config principal + identidades (vault privado): contiene namespaces y emails
if [[ -d "$VAULT_DIR/git" ]]; then
    copy_dotfile "$VAULT_DIR/git/config"           "$HOME/.gitconfig"            "link"
    copy_dotfile "$VAULT_DIR/git/config-personal"  "$HOME/.gitconfig-personal"   "link"
    copy_dotfile "$VAULT_DIR/git/config-work"      "$HOME/.gitconfig-work"       "link"
    copy_dotfile "$VAULT_DIR/git/config-cei_walle" "$HOME/.gitconfig-cei_walle"  "link"
else
    log "Vault no encontrado en $VAULT_DIR — saltando git config e identidades" "WARN"
    WARNINGS+=("~/.gitconfig e identidades no aplicados — falta el vault")
fi

# Identidades para el shell bash (gclone/gset-profile) — desde el vault
if [[ -f "$VAULT_DIR/shell/git-identities.sh" ]]; then
    copy_dotfile "$VAULT_DIR/shell/git-identities.sh"  "${XDG_CONFIG_HOME:-$HOME/.config}/git-identities.sh"
fi

# SSH config (vault privado)
if [[ -f "$VAULT_DIR/ssh/config" ]]; then
    copy_dotfile "$VAULT_DIR/ssh/config"  "$HOME/.ssh/config"
    run_step "Permisos ~/.ssh/config" chmod 600 "$HOME/.ssh/config"
else
    log "Vault no encontrado — saltando ssh/config" "WARN"
    WARNINGS+=("~/.ssh/config no aplicado — falta el vault")
fi

# SSH keys (encriptadas con age, en el vault privado)
SSH_KEYS_DIR="$VAULT_DIR/ssh/keys"
if [[ -d "$SSH_KEYS_DIR" ]] && ls "$SSH_KEYS_DIR"/*.age &>/dev/null; then
    if has_cmd age; then
        log "Desencriptando claves SSH (se pide passphrase una sola vez)..." "INFO"
        read -s -p "Passphrase para claves SSH: " AGE_PASSPHRASE
        echo ""

        for age_file in "$SSH_KEYS_DIR"/*.age; do
            key_name="$(basename "$age_file" .age)"
            dst_key="$HOME/.ssh/$key_name"

            if [[ -f "$dst_key" ]]; then
                log "~/.ssh/$key_name ya existe, saltando" "SKIP"
            elif [[ "$DRY_RUN" == true ]]; then
                log "[DryRun] Desencriptar $key_name → ~/.ssh/$key_name" "SKIP"
            else
                if printf '%s' "$AGE_PASSPHRASE" | age -d -o "$dst_key" "$age_file" 2>/dev/null; then
                    chmod 600 "$dst_key"
                    log "Desencriptado $key_name → ~/.ssh/$key_name" "OK"
                else
                    log "Error desencriptando $key_name (passphrase incorrecta?)" "ERROR"
                    ERRORS+=("Desencriptar SSH key $key_name")
                fi
            fi
        done
        unset AGE_PASSPHRASE

        # Copiar claves publicas
        for pub_file in "$SSH_KEYS_DIR"/*.pub; do
            [[ -f "$pub_file" ]] || continue
            pub_name="$(basename "$pub_file")"
            dst_pub="$HOME/.ssh/$pub_name"
            if [[ -f "$dst_pub" ]]; then
                log "~/.ssh/$pub_name ya existe, saltando" "SKIP"
            else
                run_step "Copiar $pub_name → ~/.ssh/" cp "$pub_file" "$dst_pub"
                chmod 644 "$dst_pub"
            fi
        done
    else
        log "age no instalado — no se pueden desencriptar las claves SSH" "WARN"
        WARNINGS+=("Instalar age para desencriptar claves SSH: curl -sSf https://dl.filippo.io/age/latest?for=linux/amd64 | tar xz")
    fi
else
    log "No hay claves .age en ssh/keys/, saltando" "SKIP"
fi

# Editorconfig
copy_dotfile ".editorconfig"        "$HOME/.editorconfig"        "link"

# Claude Code
copy_dotfile ".claude/settings.json"         "$HOME/.claude/settings.json"
copy_dotfile ".claude/settings.local.json"   "$HOME/.claude/settings.local.json"
mkdir -p "$HOME/.claude/plugins"
copy_dotfile ".claude/plugins/installed_plugins.json" "$HOME/.claude/plugins/installed_plugins.json"

# Tema oh-my-posh claude-code
_omp_themes_dst="${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-posh/themes"
_omp_src="$REPO_ROOT/shell/themes/claude-code.omp.json"
if [[ -f "$_omp_src" ]]; then
    mkdir -p "$_omp_themes_dst"
    run_step "Copiar tema claude-code.omp.json → oh-my-posh themes" \
        cp "$_omp_src" "$_omp_themes_dst/claude-code.omp.json"
fi
unset _omp_themes_dst _omp_src

# ==============================================================================
# 5. CONFIGURAR AWS SSO (OPCIONAL)
# ==============================================================================

log "--- [6/7] Configuracion AWS SSO ---" "SECTION"

if [[ "$WITH_AWS" != true ]]; then
    log "Saltando configuracion AWS SSO (usa --with-aws para incluirla)" "SKIP"
    log "  Nota: AWS CLI ya esta instalado para claude-smg, pero SSO requiere --with-aws" "INFO"
else
    if has_cmd aws; then
        log "Para completar la configuracion de AWS SSO ejecuta manualmente:" "WARN"
        log "  aws configure sso" "WARN"
        log "  SSO start URL : https://<tu-org>.awsapps.com/start/#" "WARN"
        log "  SSO region    : us-east-1" "WARN"
    else
        log "AWS CLI no disponible — error inesperado" "ERROR"
        WARNINGS+=("AWS CLI deberia estar instalado pero no se encuentra")
    fi
fi

# ==============================================================================
# 6. RESUMEN FINAL
# ==============================================================================

# ==============================================================================
# VALIDACION POST-BOOTSTRAP
# ==============================================================================

log "" "INFO"
log "--- Ejecutando validaciones post-bootstrap ---" "SECTION"

TEST_SCRIPT="$REPO_ROOT/test-bootstrap.sh"
if [[ -f "$TEST_SCRIPT" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        log "[DryRun] bash $TEST_SCRIPT" "SKIP"
    else
        bash "$TEST_SCRIPT"
        TEST_EXIT=$?
        if [[ $TEST_EXIT -ne 0 ]]; then
            log "Validaciones post-bootstrap: hay fallos (exit $TEST_EXIT)" "WARN"
            WARNINGS+=("Validaciones post-bootstrap con fallos — revisar output arriba")
        else
            log "Validaciones post-bootstrap: todo OK" "OK"
        fi
    fi
else
    log "test-bootstrap.sh no encontrado en $REPO_ROOT" "WARN"
fi

# ==============================================================================
# 6. RESUMEN FINAL
# ==============================================================================

log "" "INFO"
log "======================================================" "SECTION"
log "  RESUMEN FINAL" "SECTION"
log "======================================================" "SECTION"

if [[ ${#ERRORS[@]} -eq 0 && ${#WARNINGS[@]} -eq 0 ]]; then
    log "Bootstrap completado sin errores." "OK"
else
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        log "Advertencias (${#WARNINGS[@]}):" "WARN"
        for w in "${WARNINGS[@]}"; do
            log "  - $w" "WARN"
        done
    fi
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        log "Errores (${#ERRORS[@]}):" "ERROR"
        for e in "${ERRORS[@]}"; do
            log "  - $e" "ERROR"
        done
    fi
fi

log "" "INFO"
log "Backups almacenados en: $BACKUP_DIR" "INFO"
log "Log completo en: $LOG_FILE" "INFO"
log "" "INFO"
log "Proximos pasos:" "SECTION"
log "  1. Abri una terminal nueva para recargar el profile" "INFO"
log "  2. Verifica tus claves SSH: ssh -T git@github.com-kevincharp" "INFO"
if [[ "$WITH_AWS" == true ]]; then
    log "  3. Ejecuta: aws configure sso" "INFO"
fi
log "======================================================" "SECTION"
