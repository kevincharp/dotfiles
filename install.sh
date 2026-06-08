#!/usr/bin/env bash
# ==============================================================================
#   install.sh — Instalacion/actualizacion de dotfiles (modelo 2 repos)
#   Autor: Kevin Charpentier
#
#   Arquitectura:
#     - dotfiles        (PUBLICO)  → scripts + configs no sensibles  [este repo]
#     - dotfiles-vault  (PRIVADO)  → ssh keys, identidades git, bookmarks
#
#   Instalacion inicial (sin SSH, repo publico via curl):
#     curl -fsSL https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.sh | bash
#
#   Actualizacion (con el repo ya clonado):
#     bash ~/.dotfiles/install.sh
#
#   Opciones:
#     --with-aws       Incluir configuracion AWS
#     --dry-run        Simular sin ejecutar
#     --skip-packages  Saltear instalacion de paquetes
#     --skip-vault     No clonar/aplicar el vault privado (solo lo publico)
#     --update-only    Solo actualizar repos, no ejecutar bootstrap
#     --vault-auth=X   Metodo de auth no interactivo: gh | ssh | skip
# ==============================================================================

set -euo pipefail

# ==============================================================================
# CONFIGURACION
# ==============================================================================

GH_USER="kevincharp"
PUBLIC_HTTPS="https://github.com/${GH_USER}/dotfiles.git"
PUBLIC_SSH="git@github.com:${GH_USER}/dotfiles.git"
VAULT_HTTPS="https://github.com/${GH_USER}/dotfiles-vault.git"
VAULT_SSH="git@github.com:${GH_USER}/dotfiles-vault.git"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
VAULT_DIR="${VAULT_DIR:-$HOME/.dotfiles-vault}"
BRANCH="${DOTFILES_BRANCH:-main}"

WITH_AWS=false
DRY_RUN=false
SKIP_PACKAGES=false
SKIP_VAULT=false
UPDATE_ONLY=false
VAULT_AUTH=""   # gh | ssh | skip | "" (interactivo)

for arg in "$@"; do
    case "$arg" in
        --with-aws)       WITH_AWS=true ;;
        --dry-run)        DRY_RUN=true ;;
        --skip-packages)  SKIP_PACKAGES=true ;;
        --skip-vault)     SKIP_VAULT=true ;;
        --update-only)    UPDATE_ONLY=true ;;
        --vault-auth=*)   VAULT_AUTH="${arg#*=}" ;;
        *)
            echo "Uso: bash install.sh [--with-aws] [--dry-run] [--skip-packages] [--skip-vault] [--update-only] [--vault-auth=gh|ssh|skip]"
            exit 1
            ;;
    esac
done

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
        SECTION) echo -e "\033[36m[$ts] $1\033[0m" ;;
        *)       echo "[$ts] $1" ;;
    esac
}

has_cmd() { command -v "$1" &>/dev/null; }

# Lee input del usuario incluso bajo 'curl | bash' (stdin = pipe).
# Usa /dev/tty si esta disponible; si no, devuelve el default.
ask() {
    local prompt="$1" default="${2:-}" reply
    if [[ -r /dev/tty ]]; then
        read -r -p "$prompt" reply < /dev/tty || reply=""
    else
        reply=""
    fi
    echo "${reply:-$default}"
}

# ==============================================================================
# 1. VERIFICAR / INSTALAR GIT
# ==============================================================================

log "Verificando requisitos..." "SECTION"

if ! has_cmd git; then
    log "Git no esta instalado — instalando..." "WARN"
    if has_cmd dnf;      then sudo dnf install -y git
    elif has_cmd apt;    then sudo apt update && sudo apt install -y git
    elif has_cmd pacman; then sudo pacman -S --noconfirm git
    else log "Package manager no detectado — instala git manualmente" "ERROR"; exit 1
    fi
fi
has_cmd git || { log "Git no se pudo instalar" "ERROR"; exit 1; }
log "git $(git --version | cut -d' ' -f3) OK" "OK"

# ==============================================================================
# 2. CLONAR / ACTUALIZAR REPO PUBLICO
# ==============================================================================

log "Repositorio publico (dotfiles)..." "SECTION"

if [[ -d "$DOTFILES_DIR/.git" ]]; then
    log "Ya existe en $DOTFILES_DIR — actualizando" "OK"
    cd "$DOTFILES_DIR"
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log "Cambios locales detectados — stash automatico" "WARN"
        git stash push -m "auto-stash install $(date +%Y%m%d-%H%M%S)" >/dev/null
    fi
    git pull --rebase --autostash origin "$BRANCH" || { log "Error al actualizar publico" "ERROR"; exit 1; }
else
    # Repo PUBLICO: HTTPS funciona sin credenciales. SSH si esta disponible.
    if git clone "$PUBLIC_SSH" "$DOTFILES_DIR" 2>/dev/null; then
        log "Clonado publico via SSH" "OK"
    elif git clone "$PUBLIC_HTTPS" "$DOTFILES_DIR"; then
        log "Clonado publico via HTTPS" "OK"
    else
        log "Error al clonar el repo publico" "ERROR"; exit 1
    fi
fi

# ==============================================================================
# 3. CLONAR / ACTUALIZAR VAULT PRIVADO (interactivo)
# ==============================================================================

clone_vault() {
    # Decide metodo de auth: flag, o pregunta interactiva.
    local method="$VAULT_AUTH"
    if [[ -z "$method" ]]; then
        log "El vault privado (dotfiles-vault) contiene tus claves SSH e identidades." "INFO"
        log "Como queres autenticarte para clonarlo?" "INFO"
        echo "    1) gh (GitHub CLI, login por navegador)  [recomendado]"
        echo "    2) SSH (si ya tenes una clave cargada)"
        echo "    3) Saltar por ahora (instalo solo lo publico)"
        local choice
        choice="$(ask 'Opcion [1/2/3]: ' '3')"
        case "$choice" in
            1) method="gh" ;;
            2) method="ssh" ;;
            *) method="skip" ;;
        esac
    fi

    if [[ "$method" == "skip" ]]; then
        log "Vault saltado. Lo podes aplicar luego con: bash $DOTFILES_DIR/install.sh" "WARN"
        return 1
    fi

    if [[ "$method" == "gh" ]]; then
        if ! has_cmd gh; then
            log "gh no instalado — instalando..." "INFO"
            if has_cmd dnf;      then sudo dnf install -y gh
            elif has_cmd apt;    then sudo apt install -y gh
            elif has_cmd pacman; then sudo pacman -S --noconfirm github-cli
            fi
        fi
        if ! gh auth status &>/dev/null; then
            log "Autenticando con GitHub (seguí las instrucciones)..." "INFO"
            gh auth login < /dev/tty || { log "Login con gh fallo" "ERROR"; return 1; }
        fi
        gh repo clone "${GH_USER}/dotfiles-vault" "$VAULT_DIR" && return 0
        log "Error clonando vault con gh" "ERROR"; return 1
    fi

    if [[ "$method" == "ssh" ]]; then
        git clone "$VAULT_SSH" "$VAULT_DIR" && return 0
        log "Error clonando vault via SSH (tenes la clave cargada?)" "ERROR"; return 1
    fi
}

VAULT_OK=false
if [[ "$SKIP_VAULT" == true ]]; then
    log "--skip-vault: omitiendo vault privado" "WARN"
elif [[ -d "$VAULT_DIR/.git" ]]; then
    log "Vault ya existe en $VAULT_DIR — actualizando" "OK"
    ( cd "$VAULT_DIR" && git pull --rebase --autostash origin "$BRANCH" ) \
        && VAULT_OK=true || log "No se pudo actualizar el vault" "WARN"
else
    log "Vault privado (dotfiles-vault)..." "SECTION"
    if clone_vault; then VAULT_OK=true; fi
fi

# ==============================================================================
# 4. EJECUTAR BOOTSTRAP
# ==============================================================================

if [[ "$UPDATE_ONLY" == true ]]; then
    log "--update-only: repos actualizados, no ejecuto bootstrap" "OK"
    exit 0
fi

log "Ejecutando bootstrap..." "SECTION"

BOOTSTRAP_ARGS=()
[[ "$WITH_AWS" == true ]]       && BOOTSTRAP_ARGS+=(--with-aws)
[[ "$DRY_RUN" == true ]]        && BOOTSTRAP_ARGS+=(--dry-run)
[[ "$SKIP_PACKAGES" == true ]]  && BOOTSTRAP_ARGS+=(--skip-packages)

if [[ -f "$DOTFILES_DIR/bootstrap.sh" ]]; then
    # Exporto VAULT_DIR para que bootstrap.sh encuentre lo sensible
    VAULT_DIR="$VAULT_DIR" bash "$DOTFILES_DIR/bootstrap.sh" "${BOOTSTRAP_ARGS[@]}"
else
    log "bootstrap.sh no encontrado en $DOTFILES_DIR" "ERROR"; exit 1
fi

# ==============================================================================
# RESUMEN
# ==============================================================================

log "" "INFO"
log "======================================================" "SECTION"
log "  INSTALACION COMPLETADA" "SECTION"
log "======================================================" "SECTION"
log "Publico: $DOTFILES_DIR" "OK"
if [[ "$VAULT_OK" == true ]]; then
    log "Vault:   $VAULT_DIR" "OK"
else
    log "Vault:   NO aplicado — claves SSH e identidades git pendientes" "WARN"
    log "  Para aplicarlo luego: bash $DOTFILES_DIR/install.sh" "INFO"
fi
log "" "INFO"
log "Proximos pasos:" "INFO"
log "  1. Abri una terminal nueva para recargar el profile" "INFO"
log "  2. Si clonaste por HTTPS, cambia a SSH para no pedir credenciales:" "INFO"
log "     cd $DOTFILES_DIR && git remote set-url origin $PUBLIC_SSH" "INFO"
log "======================================================" "SECTION"
