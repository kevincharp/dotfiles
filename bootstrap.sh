#!/usr/bin/env bash
# ==============================================================================
#   bootstrap.sh — Setup completo de entorno de desarrollo (Linux / bash)
#   Autor: Kevin Charpentier
#   Uso:   bash bootstrap.sh [--with-aws] [--dry-run] [--skip-packages]
#                             [--all-tools] [--tools=id1,id2,...]
# ==============================================================================

set -euo pipefail

# ==============================================================================
# PARAMETROS
# ==============================================================================

WITH_AWS=false
DRY_RUN=false
SKIP_PACKAGES=false
ALL_TOOLS=false
TOOLS_ARG=""

_usage="Uso: bash bootstrap.sh [--with-aws] [--dry-run] [--skip-packages] [--all-tools] [--tools=id1,id2,...]"

for arg in "$@"; do
    case "$arg" in
        --with-aws)       WITH_AWS=true ;;
        --dry-run)        DRY_RUN=true ;;
        --skip-packages)  SKIP_PACKAGES=true ;;
        --all-tools)      ALL_TOOLS=true ;;
        --tools=*)        TOOLS_ARG="${arg#*=}" ;;
        *)
            echo "$_usage"
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
# ESTILO / ICONOS
# ------------------------------------------------------------------------------
# Iconos para la salida en pantalla. Si la terminal no es UTF-8 se cae a ASCII.
# ==============================================================================

if [[ "${LANG:-}${LC_ALL:-}${LC_CTYPE:-}" == *[Uu][Tt][Ff]* ]]; then
    I_SECTION="▶"; I_OK="✓"; I_WARN="⚠"; I_ERROR="✗"; I_SKIP="⊘"; I_INFO="·"
else
    I_SECTION=">"; I_OK="[OK]"; I_WARN="[!]"; I_ERROR="[X]"; I_SKIP="[-]"; I_INFO="-"
fi

# Colores ANSI
C_RESET=$'\033[0m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERROR=$'\033[31m'
C_SKIP=$'\033[90m'; C_SECTION=$'\033[1;36m'; C_DIM=$'\033[90m'; C_BOLD=$'\033[1m'

# ==============================================================================
# HELPERS
# ==============================================================================

log() {
    local msg="$1" level="${2:-INFO}"
    local ts; ts="$(date +%H:%M:%S)"

    # Al archivo siempre con timestamp y nivel (traza completa)
    echo "[$ts][$level] $msg" >> "$LOG_FILE" 2>/dev/null || true

    # A pantalla: iconos + jerarquia (seccion a col 0, items indentados)
    case "$level" in
        SECTION)
            # Colapsa banners: quita bordes (= - # espacios). Si no queda texto, es separador -> se omite.
            local clean
            clean="$(printf '%s' "$msg" | sed -E 's/^[[:space:]=#-]+//; s/[[:space:]=#-]+$//')"
            [[ -z "$clean" ]] && return 0
            printf '\n%s%s %s%s\n' "$C_SECTION" "$I_SECTION" "$clean" "$C_RESET" ;;
        OK)      printf '  %s%s%s %s\n' "$C_OK"    "$I_OK"    "$C_RESET" "$msg" ;;
        WARN)    printf '  %s%s%s %s\n' "$C_WARN"  "$I_WARN"  "$C_RESET" "$msg" ;;
        ERROR)   printf '  %s%s%s %s\n' "$C_ERROR" "$I_ERROR" "$C_RESET" "$msg" ;;
        SKIP)    printf '  %s%s %s%s\n' "$C_SKIP"  "$I_SKIP"  "$msg" "$C_RESET" ;;
        *)       # INFO: vacio -> linea en blanco; con texto -> indentado tenue
                 if [[ -z "$msg" ]]; then printf '\n'; else printf '    %s%s%s\n' "$C_DIM" "$msg" "$C_RESET"; fi ;;
    esac
}

# banner <titulo> [subtitulo] — encabezado destacado (inicio / resumen final)
banner() {
    local title="$1" sub="${2:-}"
    echo "[$(date +%H:%M:%S)] === $title ${sub:+- $sub} ===" >> "$LOG_FILE" 2>/dev/null || true
    printf '\n%s%s %s%s\n' "$C_SECTION" "$I_SECTION" "$title" "$C_RESET"
    [[ -n "$sub" ]] && printf '  %s%s%s\n' "$C_DIM" "$sub" "$C_RESET"
    return 0
}

# Modo silencioso: cuando _QUIET_STEPS=1, los run_step exitosos NO se imprimen
# (solo al log) y se cuentan en _QUIET_OK. Los fallos SIEMPRE se muestran. Sirve
# para colapsar pasos verbosos (symlinks, carpetas) a una linea de resumen.
_QUIET_STEPS=0
_QUIET_OK=0
run_step() {
    local name="$1"
    shift
    if [[ "$DRY_RUN" == true ]]; then
        if [[ "$_QUIET_STEPS" == 1 ]]; then
            echo "[$(date +%H:%M:%S)][SKIP] [DryRun] $name" >> "$LOG_FILE" 2>/dev/null || true
            _QUIET_OK=$((_QUIET_OK + 1))
        else
            log "[DryRun] $name" "SKIP"
        fi
        return
    fi
    if "$@"; then
        if [[ "$_QUIET_STEPS" == 1 ]]; then
            echo "[$(date +%H:%M:%S)][OK] $name" >> "$LOG_FILE" 2>/dev/null || true
            _QUIET_OK=$((_QUIET_OK + 1))
        else
            log "$name" "OK"
        fi
    else
        log "$name → fallo" "ERROR"   # los fallos siempre se muestran
        ERRORS+=("$name")
    fi
}

has_cmd() {
    command -v "$1" &>/dev/null
}

# progress_bar <actual> <total> <etiqueta> — barra ▰▱ que se reescribe in-place.
# Solo dibuja si la salida es una terminal (si es pipe/log, no ensucia). El caller
# debe imprimir un '\n' al terminar. Ancho fijo 24.
_PROGRESS_ACTIVE=0
progress_bar() {
    [[ -t 1 ]] || return 0            # sin TTY -> no dibujar (modo silencioso)
    local cur="$1" total="$2" label="$3" width=24 i
    (( total <= 0 )) && total=1
    local filled=$(( cur * width / total )) empty
    (( filled > width )) && filled=$width
    empty=$(( width - filled ))
    local b=""
    for ((i = 0; i < filled; i++)); do b+="▰"; done
    for ((i = 0; i < empty;  i++)); do b+="▱"; done
    printf '\r  %b%s%b %b%2d/%d%b  %b· %s%b\033[K' \
        "$C_SECTION" "$b" "$C_RESET" "$C_BOLD" "$cur" "$total" "$C_RESET" "$C_DIM" "$label" "$C_RESET"
    _PROGRESS_ACTIVE=1
}

# progress_clear — borra la linea de la barra (para imprimir un hito limpio encima)
progress_clear() {
    [[ -t 1 && "$_PROGRESS_ACTIVE" == 1 ]] || return 0
    printf '\r\033[K'
    _PROGRESS_ACTIVE=0
}

# ensure_base_deps — instala las dependencias base (curl/wget/unzip) que necesitan
# varias herramientas para descargarse/descomprimirse. NO estan en el catalogo (no
# son herramientas que el usuario elija): se resuelven solas y solo si faltan. En
# Fedora curl/wget suelen venir de fabrica; unzip a veces no. Silencioso si ya estan.
ensure_base_deps() {
    local dep missing=()
    for dep in curl wget unzip; do
        has_cmd "$dep" || missing+=("$dep")
    done
    [[ ${#missing[@]} -eq 0 ]] && return 0
    if [[ "$DRY_RUN" == true ]]; then
        log "[DryRun] Instalar dependencias base: ${missing[*]}" "SKIP"
        return 0
    fi
    if [[ "$PKG_MANAGER" == "none" ]]; then
        log "Faltan dependencias base (${missing[*]}) y no hay package manager" "WARN"
        WARNINGS+=("Instalar manualmente: ${missing[*]}")
        return 0
    fi
    run_step "Dependencias base (${missing[*]})" $PKG_INSTALL "${missing[@]}"
}

# ==============================================================================
# CATALOGO DE HERRAMIENTAS
# ------------------------------------------------------------------------------
# Fuente unica de verdad de lo que instala el bootstrap. Cada entrada es
# "id|grupo|descripcion". La deteccion de "ya instalado" vive en tool_installed()
# y el metodo de instalacion (que varia por distro) en install_tool().
#
# Grupos: core (basicas), shell (prompt/navegacion), dev (runtime + IA),
#         cloud (nube/git remoto), fonts (tipografias).
#
# Agregar una herramienta = una linea aca + su case en las dos funciones
# (tool_installed e install_tool). El selector (ver SELECTOR DE HERRAMIENTAS)
# decide cuales del catalogo se instalan.
# ==============================================================================

TOOLS_CATALOG=(
    "neovim|core|Editor de terminal"
    "ripgrep|core|Busqueda rapida (Telescope)"
    "fzf|core|Fuzzy finder (Ctrl+R)"
    "bash-completion|core|Autocompletado de bash"
    "oh-my-posh|shell|Prompt con tema"
    "zoxide|shell|cd inteligente con memoria"
    "eza|shell|Reemplazo moderno de ls"
    "lazygit|shell|UI de git en terminal"
    "yazi|shell|File manager TUI (preview de imagenes/PDF/video)"
    "blesh|shell|Syntax highlighting en bash (estilo PSReadLine)"
    "zsh|shell|Shell zsh (alternativa a bash)"
    "zsh-autosuggestions|shell|Sugerencias inline en zsh (estilo PSReadLine)"
    "zsh-syntax-highlighting|shell|Syntax highlighting en zsh (estilo ble.sh)"
    "node|dev|Runtime JS + npm"
    "codex|dev|Codex CLI (OpenAI)"
    "claude|dev|Claude Code CLI"
    "opencode|dev|opencode (SST)"
    "aws|cloud|AWS CLI (Bedrock)"
    "lazyssh|shell|TUI para gestionar conexiones SSH (estilo lazygit)"
    "gh|cloud|GitHub CLI (PRs/issues + clonado del vault)"
    "glab|cloud|GitLab CLI"
    "age|cloud|Encriptacion de claves SSH"
    "rclone|cloud|Sync nube (iCloud Drive, etc.) - ver icloud-mount"
    "firacode|fonts|FiraCode Nerd Font"
    "ulauncher|apps|Lanzador de apps (estilo Spotlight)"
    "samba|apps|Compartir carpetas por red (SMB, p.ej. app Archivos de iPhone)"
    "chrome|apps|Google Chrome (RPM oficial + repo para updates)"
    "openlogi|apps|Config de mouse Logitech MX (HID++, alternativa a Options+)"
    "flameshot|apps|Recortador de pantalla con anotaciones (atajo Super+Shift+S)"
    "remmina|apps|Cliente RDP/VNC (conexiones a servers Windows)"
)

# tool_installed <id> — devuelve 0 si la herramienta ya esta presente
tool_installed() {
    case "$1" in
        neovim)          has_cmd nvim ;;
        ripgrep)         has_cmd rg ;;
        fzf)             has_cmd fzf ;;
        bash-completion) [[ -f /usr/share/bash-completion/bash_completion ]] \
                            || rpm -q bash-completion &>/dev/null \
                            || dpkg -l bash-completion &>/dev/null ;;
        oh-my-posh)      has_cmd oh-my-posh ;;
        zoxide)          has_cmd zoxide ;;
        eza)             has_cmd eza ;;
        lazygit)         has_cmd lazygit ;;
        yazi)            has_cmd yazi ;;
        lazyssh)         has_cmd lazyssh ;;
        blesh)           [[ -f "$HOME/.local/share/blesh/ble.sh" ]] ;;
        zsh)                     has_cmd zsh ;;
        zsh-autosuggestions)     [[ -f "$HOME/.local/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] ;;
        zsh-syntax-highlighting) [[ -f "$HOME/.local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] ;;
        node)            has_cmd node ;;
        codex)           has_cmd codex ;;
        claude)          has_cmd claude ;;
        opencode)        has_cmd opencode ;;
        aws)             has_cmd aws ;;
        gh)              has_cmd gh ;;
        glab)            has_cmd glab ;;
        age)             has_cmd age ;;
        rclone)          has_cmd rclone ;;
        firacode)        # grep -c evita el SIGPIPE que 'fc-list | grep -q' dispara con pipefail
                         [[ "$(fc-list | grep -ci "FiraCode Nerd Font")" != "0" ]] ;;
        ulauncher)       has_cmd ulauncher ;;
        samba)           # listo si el paquete esta y el servicio quedo habilitado
                         rpm -q samba &>/dev/null && systemctl is-enabled smb &>/dev/null ;;
        chrome)          rpm -q google-chrome-stable &>/dev/null ;;
        openlogi)        rpm -q openlogi &>/dev/null ;;
        flameshot)       has_cmd flameshot ;;
        remmina)         has_cmd remmina ;;
        *)               return 1 ;;
    esac
}

# install_tool <id> — instala la herramienta (logica por distro preservada)
install_tool() {
    case "$1" in
        neovim|ripgrep|fzf|bash-completion|zsh|flameshot)
            run_step "Instalar $1" $PKG_INSTALL "$1"
            ;;
        zsh-autosuggestions)
            # Equivalente a ble.sh para zsh. No esta en repos con version/ruta
            # consistente entre distros; se clona a ~/.local/share (el zshrc lo cablea).
            run_step "Instalar zsh-autosuggestions" bash -c '
                dir="$HOME/.local/share/zsh-autosuggestions"
                if [[ -d "$dir/.git" ]]; then git -C "$dir" pull --ff-only --quiet
                else git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$dir"; fi
            '
            ;;
        zsh-syntax-highlighting)
            run_step "Instalar zsh-syntax-highlighting" bash -c '
                dir="$HOME/.local/share/zsh-syntax-highlighting"
                if [[ -d "$dir/.git" ]]; then git -C "$dir" pull --ff-only --quiet
                else git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$dir"; fi
            '
            ;;
        oh-my-posh)
            run_step "Instalar oh-my-posh" bash -c 'curl -s https://ohmyposh.dev/install.sh | bash -s'
            ;;
        zoxide)
            run_step "Instalar zoxide" bash -c 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
            ;;
        lazygit)
            # Fedora: COPR | Arch: repos | Debian/otros: binario
            if [[ "$PKG_MANAGER" == "dnf" ]]; then
                run_step "Instalar lazygit (COPR)" bash -c '
                    sudo dnf install -y dnf-plugins-core
                    sudo dnf copr enable -y atim/lazygit
                    sudo dnf install -y lazygit
                '
            elif [[ "$PKG_MANAGER" == "pacman" ]]; then
                run_step "Instalar lazygit" sudo pacman -S --noconfirm lazygit
            else
                run_step "Instalar lazygit (binario)" bash -c '
                    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po "\"tag_name\": \"v\K[^\"]*")
                    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
                    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
                    sudo install /tmp/lazygit /usr/local/bin
                    rm -f /tmp/lazygit /tmp/lazygit.tar.gz
                '
            fi
            ;;
        lazyssh)
            # TUI para SSH (lee/escribe ~/.ssh/config). No esta en repos de distro
            # ni en gestores; se baja el binario del release oficial a ~/.local/bin
            # (ya en PATH, sin sudo). El asset es lazyssh_<uname>_<arch>.tar.gz.
            run_step "Instalar lazyssh (binario)" bash -c '
                tag=$(curl -fsSL "https://api.github.com/repos/Adembc/lazyssh/releases/latest" | grep -Po "\"tag_name\": \"\K[^\"]*")
                tmp="$(mktemp -d)"
                curl -fsSL "https://github.com/Adembc/lazyssh/releases/download/${tag}/lazyssh_$(uname)_$(uname -m).tar.gz" -o "$tmp/lazyssh.tar.gz"
                tar xzf "$tmp/lazyssh.tar.gz" -C "$tmp"
                mkdir -p "$HOME/.local/bin"
                install "$tmp/lazyssh" "$HOME/.local/bin/lazyssh"
                rm -rf "$tmp"
            '
            ;;
        blesh)
            # ble.sh (Bash Line Editor): syntax highlighting + autosugerencias.
            # No esta en repos de distro; se instala desde el tarball de release
            # oficial (sin compilar) en ~/.local/share/blesh. El bashrc lo cablea.
            run_step "Instalar ble.sh" bash -c '
                tmp="$(mktemp -d)"
                curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz -o "$tmp/ble.tar.xz"
                tar xJf "$tmp/ble.tar.xz" -C "$tmp"
                bash "$tmp"/ble-nightly/ble.sh --install "$HOME/.local/share"
                rm -rf "$tmp"
            '
            ;;
        eza)
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
            ;;
        yazi)
            # yazi + bundle de deps de preview (mismo criterio que en Windows):
            #   poppler-utils / poppler -> preview de PDF (pdftoppm)
            #   ffmpeg                  -> thumbnails de video/audio
            #   ImageMagick             -> mas formatos de imagen
            #   p7zip / 7zip            -> navegar dentro de comprimidos
            #   file                    -> deteccion de MIME (suele venir de base)
            #   chafa                   -> preview de imagenes por bloques (fallback).
            # Sobre chafa: yazi elige adapter en orden kitty-protocol > sixel > chafa
            # segun lo que soporte el terminal. Ptyxis (nuestro default en Fedora) NO
            # soporta sixel ni kitty-protocol (limitacion del propio Ptyxis, no del
            # VTE), asi que cae SIEMPRE a chafa -> sin chafa no hay preview de imagen.
            # Es fallback universal inofensivo: si algun dia se usa un terminal con
            # sixel/kitty (Kitty, Ghostty, WezTerm...), yazi usa ese y chafa queda
            # sin usar, sin estorbar. Por eso se instala siempre.
            if [[ "$PKG_MANAGER" == "dnf" ]]; then
                # yazi NO esta en los repos base de Fedora: se habilita el COPR
                # oficial (lihaohong/yazi), mismo patron que lazygit (atim/lazygit).
                # yazi primero (critico); las deps van aparte para que el fallo de
                # una (p.ej. ffmpeg completo requiere RPM Fusion, en repos base solo
                # esta ffmpeg-free) no impida instalar el resto.
                run_step "Instalar yazi (COPR)" bash -c '
                    sudo dnf install -y dnf-plugins-core
                    sudo dnf copr enable -y lihaohong/yazi
                    sudo dnf install -y yazi
                '
                run_step "Instalar deps de preview de yazi" bash -c '
                    sudo dnf install -y poppler-utils ImageMagick p7zip file chafa || true
                    sudo dnf install -y ffmpeg || sudo dnf install -y ffmpeg-free || true
                '
            elif [[ "$PKG_MANAGER" == "pacman" ]]; then
                run_step "Instalar yazi + deps" sudo pacman -S --noconfirm \
                    yazi poppler ffmpeg imagemagick p7zip file chafa
            else
                log "yazi: instalar manualmente — https://yazi-rs.github.io/docs/installation" "WARN"
                WARNINGS+=("yazi no instalado — sin paquete para este gestor")
            fi
            ;;
        node)
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
            ;;
        codex)
            if has_cmd node; then
                run_step "Instalar Codex CLI" sudo npm install -g @openai/codex
                log "  Nota: para instalar Codex Desktop ejecuta 'codex app' (descarga el instalador automaticamente)" "INFO"
            else
                log "Node.js no disponible, no se puede instalar Codex CLI" "WARN"
                WARNINGS+=("Codex CLI no instalado — requiere Node.js")
            fi
            ;;
        claude)
            # Instalador nativo oficial (macOS/Linux/WSL). Auto-actualiza en background.
            run_step "Instalar Claude Code CLI" bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
            ;;
        opencode)
            run_step "Instalar opencode" bash -c 'curl -fsSL https://opencode.ai/install | bash'
            ;;
        aws)
            run_step "Instalar AWS CLI" bash -c '
                curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
                unzip -qo /tmp/awscliv2.zip -d /tmp
                sudo /tmp/aws/install --update
                rm -rf /tmp/aws /tmp/awscliv2.zip
            '
            ;;
        gh)
            # Fedora/Arch traen paquete nativo. En Debian/apt 'gh' no esta en los
            # repos base: hay que agregar el repo oficial de GitHub primero.
            if [[ "$PKG_MANAGER" == "dnf" ]]; then
                run_step "Instalar gh" $PKG_INSTALL gh
            elif [[ "$PKG_MANAGER" == "pacman" ]]; then
                run_step "Instalar gh" sudo pacman -S --noconfirm github-cli
            elif [[ "$PKG_MANAGER" == "apt" ]]; then
                run_step "Instalar gh (repo oficial GitHub)" bash -c '
                    sudo mkdir -p -m 755 /etc/apt/keyrings
                    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
                    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
                    sudo apt update && sudo apt install -y gh
                '
            else
                log "gh: instalar manualmente — https://github.com/cli/cli#installation" "WARN"
                WARNINGS+=("gh no instalado")
            fi
            ;;
        glab)
            if [[ "$PKG_MANAGER" == "dnf" || "$PKG_MANAGER" == "pacman" ]]; then
                run_step "Instalar glab" $PKG_INSTALL glab
            else
                # Repo oficial gitlab-org/cli (profclems/glab esta archivado desde 2021).
                # La version se consulta a la API de tags de GitLab y el asset es
                # glab_<ver>_linux_amd64.tar.gz (minusculas), con el binario en bin/glab.
                run_step "Instalar glab (binario)" bash -c '
                    GLAB_VERSION=$(curl -fsSL "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/repository/tags?per_page=1" | grep -Po "\"name\":\"v\K[^\"]*" | head -1)
                    curl -Lo /tmp/glab.tar.gz "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_amd64.tar.gz"
                    tar xf /tmp/glab.tar.gz -C /tmp
                    sudo install /tmp/bin/glab /usr/local/bin
                    rm -rf /tmp/bin /tmp/glab.tar.gz
                '
            fi
            ;;
        rclone)
            # rclone esta en repos de dnf/apt/pacman con version reciente
            # (Fedora 44 trae 1.74; el backend iclouddrive existe desde 1.69).
            # La config del remote 'icloud' es manual (rclone config, pide 2FA).
            if [[ "$PKG_MANAGER" == "dnf" || "$PKG_MANAGER" == "apt" || "$PKG_MANAGER" == "pacman" ]]; then
                run_step "Instalar rclone" $PKG_INSTALL rclone
            else
                run_step "Instalar rclone (script oficial)" bash -c 'curl -fsSL https://rclone.org/install.sh | sudo bash'
            fi
            ;;
        age)
            if [[ "$PKG_MANAGER" == "dnf" || "$PKG_MANAGER" == "apt" || "$PKG_MANAGER" == "pacman" ]]; then
                run_step "Instalar age" $PKG_INSTALL age
            else
                run_step "Instalar age (binario)" bash -c '
                    AGE_VERSION=$(curl -s "https://api.github.com/repos/FiloSottile/age/releases/latest" | grep -Po "\"tag_name\": \"v\K[^\"]*")
                    curl -Lo /tmp/age.tar.gz "https://github.com/FiloSottile/age/releases/latest/download/age-v${AGE_VERSION}-linux-amd64.tar.gz"
                    tar xf /tmp/age.tar.gz -C /tmp
                    sudo install /tmp/age/age /usr/local/bin
                    sudo install /tmp/age/age-keygen /usr/local/bin
                    rm -rf /tmp/age /tmp/age.tar.gz
                '
            fi
            ;;
        firacode)
            run_step "Instalar FiraCode Nerd Font" bash -c '
                FONT_DIR="$HOME/.local/share/fonts"
                mkdir -p "$FONT_DIR"
                NERD_FONTS_VERSION=$(curl -s "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" | grep -Po "\"tag_name\": \"v\K[^\"]*")
                curl -Lo /tmp/FiraCode.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
                unzip -qo /tmp/FiraCode.zip -d "$FONT_DIR"
                rm /tmp/FiraCode.zip
                fc-cache -fv > /dev/null
            '
            ;;
        ulauncher)
            # Fedora 44+: ya viene en los repos oficiales (dnf directo).
            # Debian/Ubuntu: no esta en repos base, hace falta el PPA.
            # Arch: AUR (no automatizable desde aqui).
            if [[ "$PKG_MANAGER" == "dnf" ]]; then
                run_step "Instalar ulauncher" $PKG_INSTALL ulauncher
            elif [[ "$PKG_MANAGER" == "apt" ]]; then
                run_step "Instalar ulauncher (PPA)" bash -c '
                    sudo add-apt-repository -y ppa:agornostal/ulauncher
                    sudo apt update && sudo apt install -y ulauncher
                '
            elif [[ "$PKG_MANAGER" == "pacman" ]]; then
                log "ulauncher: instalar manualmente desde AUR — yay -S ulauncher" "WARN"
                WARNINGS+=("ulauncher no instalado — disponible en AUR")
            else
                log "ulauncher: instalar manualmente — https://ulauncher.io" "WARN"
                WARNINGS+=("ulauncher no instalado")
            fi
            ;;
        samba)
            # Servidor SMB para compartir el home por red local (p.ej. la app
            # Archivos del iPhone, que solo habla SMB, no SFTP). El smb.conf por
            # defecto de Fedora ya trae el share [homes] con lectura/escritura, no
            # hace falta tocarlo. Solo en Fedora/dnf (servicio + firewalld + SELinux).
            # La contrasena SMB NO se versiona: es secreto, queda como paso manual
            # ('sudo smbpasswd -a <usuario>'), igual que las claves SSH.
            if [[ "$PKG_MANAGER" != "dnf" ]]; then
                log "samba: cableado solo para Fedora/dnf — instalar manualmente en esta distro" "WARN"
                WARNINGS+=("samba no configurado — distro no soportada por el bootstrap")
            else
                run_step "Instalar samba" $PKG_INSTALL samba
                run_step "Habilitar servicio smb" sudo systemctl enable --now smb
                # Firewall (firewalld): abrir el servicio samba de forma permanente
                if has_cmd firewall-cmd; then
                    run_step "Abrir samba en el firewall" bash -c '
                        sudo firewall-cmd --permanent --add-service=samba
                        sudo firewall-cmd --reload
                    '
                fi
                # SELinux: sin este booleano, compartir el home da permiso denegado
                if has_cmd setsebool; then
                    run_step "SELinux: permitir compartir home dirs" \
                        sudo setsebool -P samba_enable_home_dirs on
                fi
                log "  Falta tu contrasena SMB: corre 'sudo smbpasswd -a $USER'" "INFO"
                WARNINGS+=("Samba: define tu contrasena con 'sudo smbpasswd -a $USER' (no se versiona)")
            fi
            ;;
        chrome)
            # Google Chrome via el .rpm oficial de Google. Ese paquete deja el
            # repo de Google configurado solo, asi que las updates llegan despues
            # por 'dnf update'. Solo Fedora/dnf (rpm).
            if [[ "$PKG_MANAGER" != "dnf" ]]; then
                log "chrome: cableado solo para Fedora/dnf (.rpm) — instalar manual en esta distro" "WARN"
                WARNINGS+=("chrome no instalado — distro no soportada por el bootstrap")
            else
                run_step "Instalar Google Chrome (.rpm oficial)" \
                    sudo dnf install -y \
                    "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
            fi
            ;;
        openlogi)
            # Config de mouse Logitech MX por HID++ (alternativa nativa a Options+).
            # No esta en repos: se baja el .rpm firmado del release oficial. Trae
            # reglas udev (acceso sin sudo a /dev/hidraw*) y un servicio de usuario
            # (openlogi-agent) que hay que habilitar. Solo Fedora/dnf (rpm).
            if [[ "$PKG_MANAGER" != "dnf" ]]; then
                log "openlogi: cableado solo para Fedora/dnf (.rpm) — instalar manual en esta distro" "WARN"
                WARNINGS+=("openlogi no instalado — distro no soportada por el bootstrap")
            else
                run_step "Instalar openlogi (.rpm del release oficial)" bash -c '
                    url=$(curl -fsSL "https://api.github.com/repos/AprilNEA/OpenLogi/releases/latest" \
                          | grep -oE "https://[^\"]*linux-amd64\.rpm" | head -1)
                    [[ -n "$url" ]] || { echo "no se encontro el .rpm en el release"; exit 1; }
                    tmp="$(mktemp -d)"
                    curl -fsSL "$url" -o "$tmp/openlogi.rpm"
                    sudo rpm -i --replacepkgs "$tmp/openlogi.rpm"
                    rm -rf "$tmp"
                '
                # Servicio de usuario que intercepta los botones HID++
                run_step "Habilitar openlogi-agent (servicio de usuario)" \
                    systemctl --user enable --now openlogi-agent.service
            fi
            ;;
        remmina)
            # Cliente RDP/VNC para conectarse a servers Windows. El core no trae
            # los protocolos: van en paquetes de plugins aparte. Los nombres
            # difieren por distro (Fedora usa 'plugins' plural; Debian 'plugin'
            # singular; Arch los reparte entre remmina y freerdp).
            #   - rdp:    protocolo RDP (el que se usa contra Windows).
            #   - secret: guarda las credenciales en el keyring de GNOME.
            # Los perfiles de conexion (host/usuario/pass) NO se versionan aca:
            # son sensibles y van al vault, igual que las claves SSH.
            case "$PKG_MANAGER" in
                dnf)    run_step "Instalar Remmina + plugins RDP" \
                            $PKG_INSTALL remmina remmina-plugins-rdp remmina-plugins-secret ;;
                apt)    run_step "Instalar Remmina + plugins RDP" \
                            $PKG_INSTALL remmina remmina-plugin-rdp remmina-plugin-secret ;;
                pacman) run_step "Instalar Remmina + plugins RDP" \
                            $PKG_INSTALL remmina freerdp ;;
                *)      log "remmina: gestor no soportado — instalar manual en esta distro" "WARN"
                        WARNINGS+=("remmina no instalado — distro no soportada por el bootstrap") ;;
            esac
            ;;
        *)
            log "Herramienta desconocida: $1" "WARN"
            ;;
    esac
}

# ==============================================================================
# SELECTOR DE HERRAMIENTAS
# ------------------------------------------------------------------------------
# Decide que ids del catalogo se instalan y los deja en el array SELECTED_TOOLS.
# Prioridad:
#   1. --tools=id1,id2  -> exactamente esos (valida contra el catalogo)
#   2. --all-tools / --dry-run -> todo el catalogo, sin preguntar
#   3. terminal interactiva (hay /dev/tty) -> menu agrupado, pregunta siempre
#   4. sin terminal (CI/pipe sin tty) -> no instala nada; pide usar --tools/--all-tools
#
# El menu arranca SIN nada pre-marcado (opt-in): el usuario elige que instalar.
# Enter sin marcar nada = no instala nada. Coherente con opt-in: el modo no
# interactivo (sin /dev/tty) tampoco instala por sorpresa — hay que ser explicito.
# NOTA: este dotfiles es para maquinas de escritorio/laptop (uso interactivo real),
# no para servers headless; el caso sin-tty es un borde (CI/pipe), no el uso normal.
# ==============================================================================

SELECTED_TOOLS=()

# Devuelve el grupo de un id segun el catalogo (vacio si no existe)
_tool_group() {
    local entry
    for entry in "${TOOLS_CATALOG[@]}"; do
        [[ "${entry%%|*}" == "$1" ]] && { echo "$entry" | cut -d'|' -f2; return 0; }
    done
    return 1
}

# Valida una lista separada por comas contra el catalogo -> SELECTED_TOOLS
_select_from_csv() {
    local csv="$1" id unknown=()
    SELECTED_TOOLS=()
    IFS=',' read -ra _ids <<< "$csv"
    for id in "${_ids[@]}"; do
        id="${id// /}"   # sin espacios
        [[ -z "$id" ]] && continue
        if _tool_group "$id" >/dev/null; then
            SELECTED_TOOLS+=("$id")
        else
            unknown+=("$id")
        fi
    done
    if [[ ${#unknown[@]} -gt 0 ]]; then
        log "Ids desconocidos en --tools (ignorados): ${unknown[*]}" "WARN"
        WARNINGS+=("--tools tenia ids desconocidos: ${unknown[*]}")
    fi
}

# Orden de grupos en el selector. OJO: NO usar 'GROUPS' como nombre — es una
# variable especial de bash (los grupos del usuario) y se ignora silenciosamente.
_GRP_ORDER=(core shell dev cloud fonts apps)

# _grp_of <idx-catalogo> — grupo de una entrada
_grp_of() { local x="${TOOLS_CATALOG[$1]#*|}"; echo "${x%%|*}"; }
# _id_of / _desc_of <idx-catalogo>
_id_of()   { echo "${TOOLS_CATALOG[$1]%%|*}"; }
_desc_of() { echo "${TOOLS_CATALOG[$1]##*|}"; }

# Menu interactivo por GRUPOS (colapsable) sobre /dev/tty (funciona con 'curl|bash').
# Los grupos arrancan colapsados y sin nada marcado (opt-in). Navegacion:
#   ↑/↓ mover · →/l expandir · ←/h colapsar · espacio marcar (grupo o item) · Enter confirmar
# Checkbox de grupo tri-estado: ▰ todos · ▨ parcial · ▱ ninguno.
# Si la terminal no soporta modo raw, cae al modo por texto.
_select_interactive() {
    local i n="${#TOOLS_CATALOG[@]}"
    local -a MARK
    for ((i = 0; i < n; i++)); do MARK[i]=0; done   # opt-in: nada marcado

    # Estado expandido por grupo
    local -A EXP; local g
    for g in "${_GRP_ORDER[@]}"; do EXP[$g]=0; done

    # Modo raw sobre /dev/tty; si falla, fallback por texto
    local saved_stty
    saved_stty="$(stty -g < /dev/tty 2>/dev/null)" || saved_stty=""
    if [[ -z "$saved_stty" ]]; then
        _select_interactive_text
        return
    fi
    stty -echo -icanon min 1 time 0 < /dev/tty
    printf '\033[?25l' > /dev/tty

    # Estado de un grupo: 0=ninguno 1=todos 2=parcial ; y su conteo "on/tot"
    _grp_state() {
        local grp="$1" j tot=0 on=0
        for ((j = 0; j < n; j++)); do
            [[ "$(_grp_of "$j")" == "$grp" ]] || continue
            tot=$((tot + 1)); [[ "${MARK[j]}" == 1 ]] && on=$((on + 1))
        done
        (( on == 0 )) && { echo "0 $on $tot"; return; }
        (( on == tot )) && echo "1 $on $tot" || echo "2 $on $tot"
    }

    # Reconstruye ROWS (filas visibles): "G:grupo" o "I:idx"
    local -a ROWS
    _build_rows() {
        ROWS=(); local grp j
        for grp in "${_GRP_ORDER[@]}"; do
            ROWS+=("G:$grp")
            if [[ "${EXP[$grp]}" == 1 ]]; then
                for ((j = 0; j < n; j++)); do [[ "$(_grp_of "$j")" == "$grp" ]] && ROWS+=("I:$j"); done
            fi
        done
    }

    local cur=0 prev_n=0 first=1 FRAME FRAME_N
    # Arma el frame completo en un string (anti-flicker: un solo write, \033[K por linea)
    _build_frame() {
        _build_rows
        local nrows=${#ROWS[@]} r kind val total=0 j box ptr arrow st on tot out="" K=$'\033[K'
        for ((j = 0; j < n; j++)); do [[ "${MARK[j]}" == 1 ]] && total=$((total + 1)); done
        out+="  \033[1;36m▶ Elegí qué instalar\033[0m${K}"$'\n'
        out+="  \033[90m↑/↓ mover · → expandir · ← colapsar · espacio marcar · Enter confirmar\033[0m${K}"$'\n'
        out+="${K}"$'\n'
        for ((r = 0; r < nrows; r++)); do
            kind="${ROWS[r]%%:*}"; val="${ROWS[r]#*:}"
            if (( r == cur )); then ptr=$'\033[36m❯\033[0m'; else ptr=' '; fi
            if [[ "$kind" == G ]]; then
                read -r st on tot <<< "$(_grp_state "$val")"
                case "$st" in 1) box=$'\033[32m▰\033[0m';; 2) box=$'\033[33m▨\033[0m';; *) box=$'\033[90m▱\033[0m';; esac
                [[ "${EXP[$val]}" == 1 ]] && arrow='▾' || arrow='▸'
                out+="$(printf '  %b %s %b \033[1m%-8s\033[0m \033[90m(%s/%s)\033[0m' "$ptr" "$arrow" "$box" "$val" "$on" "$tot")${K}"$'\n'
            else
                if [[ "${MARK[val]}" == 1 ]]; then box=$'\033[32m▰\033[0m'; else box=$'\033[90m▱\033[0m'; fi
                out+="$(printf '      %b %b %-16s \033[90m%s\033[0m' "$ptr" "$box" "$(_id_of "$val")" "$(_desc_of "$val")")${K}"$'\n'
            fi
        done
        out+="${K}"$'\n'
        out+="  \033[36m${total}\033[0m\033[90m de ${n} seleccionadas\033[0m${K}"$'\n'
        FRAME_N=$(( nrows + 5 ))
        FRAME="$out"
    }

    local key rest kind val target j
    while true; do
        _build_frame
        if (( first == 0 )); then
            printf '\033[%dA\033[J%b' "$prev_n" "$FRAME" > /dev/tty
        else
            printf '%b' "$FRAME" > /dev/tty
        fi
        first=0; prev_n="$FRAME_N"

        IFS= read -rsn1 key < /dev/tty || break
        if [[ "$key" == $'\033' ]]; then read -rsn2 -t 0.01 rest < /dev/tty || true; key+="$rest"; fi
        _build_rows
        kind="${ROWS[cur]%%:*}"; val="${ROWS[cur]#*:}"
        case "$key" in
            $'\033[A'|k|K)  cur=$(( (cur - 1 + ${#ROWS[@]}) % ${#ROWS[@]} )) ;;
            $'\033[B'|j|J)  cur=$(( (cur + 1) % ${#ROWS[@]} )) ;;
            $'\033[C'|l|L)  [[ "$kind" == G ]] && EXP[$val]=1 ;;
            $'\033[D'|h|H)  [[ "$kind" == G ]] && EXP[$val]=0 ;;
            ' ')
                if [[ "$kind" == G ]]; then
                    read -r st _ _ <<< "$(_grp_state "$val")"
                    [[ "$st" == 1 ]] && target=0 || target=1
                    for ((j = 0; j < n; j++)); do [[ "$(_grp_of "$j")" == "$val" ]] && MARK[j]=$target; done
                else
                    MARK[val]=$(( 1 - MARK[val] ))
                fi ;;
            a|A)            for ((j = 0; j < n; j++)); do MARK[j]=1; done ;;
            n|N)            for ((j = 0; j < n; j++)); do MARK[j]=0; done ;;
            ''|$'\n')       break ;;
            q|Q)            break ;;
        esac
    done

    stty "$saved_stty" < /dev/tty 2>/dev/null || true
    printf '\033[?25h\n' > /dev/tty

    SELECTED_TOOLS=()
    for ((i = 0; i < n; i++)); do
        if [[ "${MARK[i]}" == "1" ]]; then SELECTED_TOOLS+=("${TOOLS_CATALOG[i]%%|*}"); fi
    done
    return 0
}

# Fallback por texto (terminales sin modo raw). Marca/desmarca por numero.
_select_interactive_text() {
    local -a marked
    local i n="${#TOOLS_CATALOG[@]}"
    for ((i = 0; i < n; i++)); do marked[i]=0; done   # nada pre-marcado (opt-in)

    local groups=(core shell dev cloud fonts apps)
    local g entry id grp desc

    while true; do
        printf '\n  \033[36m== Selector de herramientas ==\033[0m\n' > /dev/tty
        printf '  Marca/desmarca por numero. Enter sin nada = instalar lo marcado.\n\n' > /dev/tty
        for g in "${groups[@]}"; do
            printf '  \033[1m[%s]\033[0m\n' "$g" > /dev/tty
            for ((i = 0; i < n; i++)); do
                entry="${TOOLS_CATALOG[i]}"
                id="${entry%%|*}"
                grp="$(echo "$entry" | cut -d'|' -f2)"
                desc="${entry##*|}"
                [[ "$grp" == "$g" ]] || continue
                if [[ "${marked[i]}" == "1" ]]; then
                    printf '    \033[32m[x]\033[0m %2d) %-16s %s\n' "$((i + 1))" "$id" "$desc" > /dev/tty
                else
                    printf '    [ ] %2d) %-16s %s\n' "$((i + 1))" "$id" "$desc" > /dev/tty
                fi
            done
        done
        printf '\n  Comandos: numeros (ej "1 3 5") | grupo (core/shell/dev/cloud/fonts/apps) | todo | nada | ok\n' > /dev/tty
        printf '  > ' > /dev/tty

        local input
        read -r input < /dev/tty || input="ok"   # EOF -> aceptar lo marcado

        # Enter vacio u "ok" -> confirmar
        if [[ -z "$input" || "$input" == "ok" ]]; then
            break
        fi

        local tok
        for tok in $input; do
            case "$tok" in
                todo)  for ((i = 0; i < n; i++)); do marked[i]=1; done ;;
                nada)  for ((i = 0; i < n; i++)); do marked[i]=0; done ;;
                core|shell|dev|cloud|fonts|apps)
                    # Toggle de grupo: si esta todo marcado lo apaga, si no lo prende
                    local all_on=1
                    for ((i = 0; i < n; i++)); do
                        [[ "$(echo "${TOOLS_CATALOG[i]}" | cut -d'|' -f2)" == "$tok" ]] || continue
                        [[ "${marked[i]}" == "1" ]] || all_on=0
                    done
                    local target=$((all_on == 1 ? 0 : 1))
                    for ((i = 0; i < n; i++)); do
                        [[ "$(echo "${TOOLS_CATALOG[i]}" | cut -d'|' -f2)" == "$tok" ]] || continue
                        marked[i]=$target
                    done
                    ;;
                *[!0-9]*)
                    printf '    \033[33mEntrada ignorada: %s\033[0m\n' "$tok" > /dev/tty
                    ;;
                *)
                    # Numero: toggle de esa fila (1-based)
                    local idx=$((tok - 1))
                    if (( idx >= 0 && idx < n )); then
                        marked[idx]=$((marked[idx] == 1 ? 0 : 1))
                    else
                        printf '    \033[33mNumero fuera de rango: %s\033[0m\n' "$tok" > /dev/tty
                    fi
                    ;;
            esac
        done
    done

    SELECTED_TOOLS=()
    for ((i = 0; i < n; i++)); do
        if [[ "${marked[i]}" == "1" ]]; then SELECTED_TOOLS+=("${TOOLS_CATALOG[i]%%|*}"); fi
    done
    return 0
}

# Punto de entrada: resuelve SELECTED_TOOLS segun la prioridad documentada
select_tools() {
    if [[ -n "$TOOLS_ARG" ]]; then
        _select_from_csv "$TOOLS_ARG"
        log "Herramientas via --tools: ${SELECTED_TOOLS[*]:-(ninguna)}" "INFO"
    elif [[ "$ALL_TOOLS" == true || "$DRY_RUN" == true ]]; then
        SELECTED_TOOLS=(); for entry in "${TOOLS_CATALOG[@]}"; do SELECTED_TOOLS+=("${entry%%|*}"); done
        log "Instalando catalogo completo (${#SELECTED_TOOLS[@]} herramientas)" "INFO"
    elif [[ -e /dev/tty ]] && { : < /dev/tty; } 2>/dev/null; then
        _select_interactive
        log "Seleccionadas ${#SELECTED_TOOLS[@]}: ${SELECTED_TOOLS[*]:-(ninguna)}" "INFO"
    else
        SELECTED_TOOLS=()
        log "Sin terminal interactiva y sin --tools/--all-tools — no instalo nada" "WARN"
        log "  Volve a correr con --tools=id1,id2 (lista) o --all-tools (todo)" "INFO"
        WARNINGS+=("Sin tty: no se instalaron herramientas. Usa --tools=... o --all-tools")
    fi
}

# ==============================================================================
# PANTALLA DE BIENVENIDA
# ------------------------------------------------------------------------------
# Explica que hace el instalador y muestra el catalogo por grupo antes de arrancar.
# Solo en modo interactivo (con /dev/tty): con --tools/--all-tools/--dry-run o sin
# tty se saltea para no estorbar en flujos automatizados.
# ==============================================================================

welcome_screen() {
    # Detectar SO/pkg de forma ligera (el paso [1/8] hace la deteccion oficial)
    local distro="Linux" pkg="?"
    [[ -r /etc/os-release ]] && distro="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}")"
    if   has_cmd dnf;    then pkg="dnf"
    elif has_cmd apt;    then pkg="apt"
    elif has_cmd pacman; then pkg="pacman"; fi
    local vault_ok="✗ sin vault"; [[ -d "$VAULT_DIR" ]] && vault_ok="✓ vault presente"

    # Conteo por grupo (dinamico desde el catalogo)
    local g j c line
    printf '%b' "$C_SECTION" > /dev/tty
    cat > /dev/tty <<'EOF'
  ╭────────────────────────────────────────────────────────────╮
  │                                                              │
  │   ●  dotfiles · Setup de entorno                             │
  │      Linux · reproducible en cualquier máquina               │
  │                                                              │
  ╰────────────────────────────────────────────────────────────╯
EOF
    printf '%b\n' "$C_RESET" > /dev/tty
    printf '  %b%bQué hace%b\n\n' "$C_SECTION" "$C_BOLD" "$C_RESET" > /dev/tty
    printf '    %b1%b  Instala las herramientas que elijas   %b(shell, editor, git, nube…)%b\n' "$C_SECTION" "$C_RESET" "$C_DIM" "$C_RESET" > /dev/tty
    printf '    %b2%b  Crea los symlinks de tus configs      %b(bashrc, zshrc, git, nvim…)%b\n' "$C_SECTION" "$C_RESET" "$C_DIM" "$C_RESET" > /dev/tty
    printf '    %b3%b  Aplica lo sensible desde el vault     %b(claves SSH, identidades)%b\n' "$C_SECTION" "$C_RESET" "$C_DIM" "$C_RESET" > /dev/tty
    printf '    %b4%b  Restaura ajustes del sistema          %b(GNOME/Ptyxis vía dconf)%b\n' "$C_SECTION" "$C_RESET" "$C_DIM" "$C_RESET" > /dev/tty

    printf '\n  %b%bCatálogo%b  %b(%s herramientas · elegís qué instalar)%b\n\n' \
        "$C_SECTION" "$C_BOLD" "$C_RESET" "$C_DIM" "${#TOOLS_CATALOG[@]}" "$C_RESET" > /dev/tty
    for g in "${_GRP_ORDER[@]}"; do
        c=0; line=""
        for ((j = 0; j < ${#TOOLS_CATALOG[@]}; j++)); do
            [[ "$(_grp_of "$j")" == "$g" ]] || continue
            c=$((c + 1)); [[ ${#line} -lt 42 ]] && line+="${line:+ · }$(_id_of "$j")"
        done
        printf '    %b%-6s%b %b%2d%b  %b%s…%b\n' "$C_OK" "$g" "$C_RESET" "$C_BOLD" "$c" "$C_RESET" "$C_DIM" "$line" "$C_RESET" > /dev/tty
    done

    printf '\n  %b%bEntorno%b   %b✓ %s   ✓ %s   %s%b\n' "$C_SECTION" "$C_BOLD" "$C_RESET" "$C_OK" "$distro" "$pkg" "$vault_ok" "$C_RESET" > /dev/tty
    printf '\n  %b────────────────────────────────────────────────────────────%b\n' "$C_DIM" "$C_RESET" > /dev/tty
    printf '  %bEnter%b elegir herramientas  ·  %bCtrl+C%b cancelar\n' "$C_SECTION" "$C_RESET" "$C_SECTION" "$C_RESET" > /dev/tty
    read -r _ < /dev/tty 2>/dev/null || true
}

# ==============================================================================
# INICIO
# ==============================================================================

mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

# Bienvenida solo en modo interactivo real (no en --dry-run/--tools/--all-tools/sin-tty)
if [[ -z "$TOOLS_ARG" && "$ALL_TOOLS" == false && "$DRY_RUN" == false ]] \
   && [[ -e /dev/tty ]] && { : < /dev/tty; } 2>/dev/null; then
    welcome_screen
fi

banner "bootstrap.sh — Setup de entorno" "$(date '+%Y-%m-%d %H:%M:%S')$([[ "$DRY_RUN" == true ]] && echo '  ·  modo DryRun')"

# ==============================================================================
# 1. VERIFICAR REQUISITOS
# ==============================================================================

log "--- [1/8] Verificando requisitos ---" "SECTION"

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

log "--- [2/8] Instalando paquetes ---" "SECTION"

if [[ "$SKIP_PACKAGES" == true ]]; then
    log "skip-packages activado, saltando" "SKIP"
elif [[ "$PKG_MANAGER" == "none" ]]; then
    log "Sin package manager, saltando paquetes" "WARN"
    WARNINGS+=("Instalar paquetes manualmente: neovim, ripgrep, fzf, zoxide, lazygit")
else
    # Resuelve que herramientas instalar (--tools / --all-tools / menu / red de seguridad)
    select_tools

    if [[ ${#SELECTED_TOOLS[@]} -eq 0 ]]; then
        log "No se selecciono ninguna herramienta, saltando instalacion" "SKIP"
    else
        if [[ "$DRY_RUN" == false ]]; then
            log "Actualizando fuentes..." "INFO"
            $PKG_UPDATE 2>&1 | tail -1
        fi

        # Dependencias base (curl/wget/unzip): varias herramientas las necesitan
        # para descargarse. Se instalan primero y solo si faltan (no estan en el menu).
        ensure_base_deps

        # Recorre lo seleccionado con barra de progreso in-place. Anti-choclo:
        # lo "ya instalado" NO se imprime (solo va al log); solo se muestran los
        # hitos (lo que se instala nuevo) y el resumen final. El ruido de dnf/git
        # de install_tool sigue saliendo, pero los ya-presentes (la mayoria) no
        # ensucian. Contadores para el resumen.
        local_total=${#SELECTED_TOOLS[@]}
        _done=0 _already=0 _new=0
        for _tool_id in "${SELECTED_TOOLS[@]}"; do
            # OJO: _done=$((...)) y no ((_done++)) — con 'set -e', ((x++)) devuelve
            # exit 1 cuando x vale 0 y abortaria el script.
            _done=$((_done + 1))
            progress_bar "$_done" "$local_total" "$_tool_id"
            if tool_installed "$_tool_id"; then
                # Ya presente: al log, no a pantalla.
                echo "[$(date +%H:%M:%S)][SKIP] $_tool_id ya instalado" >> "$LOG_FILE" 2>/dev/null || true
                _already=$((_already + 1))
            else
                progress_clear
                install_tool "$_tool_id"
                _new=$((_new + 1))
            fi
        done
        progress_bar "$local_total" "$local_total" "listo"
        [[ -t 1 ]] && printf '\n'
        log "${_already} ya instaladas · ${_new} nuevas   (detalle en el log)" "INFO"
        unset _tool_id
    fi
fi

# ==============================================================================
# 3. CREAR ESTRUCTURA DE CARPETAS
# ==============================================================================

log "--- [3/8] Creando estructura de carpetas ---" "SECTION"

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

# Colapsado a resumen: lo "ya existe" va al log; solo se cuentan. Fallos se muestran.
_dirs_new=0 _dirs_had=0
for dir in "${DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "[$(date +%H:%M:%S)][SKIP] $dir ya existe" >> "$LOG_FILE" 2>/dev/null || true
        _dirs_had=$((_dirs_had + 1))
    else
        _QUIET_STEPS=1; run_step "Crear $dir" mkdir -p "$dir"; _QUIET_STEPS=0
        _dirs_new=$((_dirs_new + 1))
    fi
done
log "${_dirs_new} carpetas creadas · ${_dirs_had} ya existían" "OK"

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

log "--- [4/8] Migrando backups viejos ---" "SECTION"

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
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.gitconfig"
    "$HOME/.gitconfig-personal"
    "$HOME/.gitconfig-work"
    "$HOME/.gitconfig-cei_walle"
    "$HOME/.config/git/ignore"
    "$HOME/.ssh/config"
    "$HOME/.editorconfig"
    "$HOME/.claude/settings.json"
    "$HOME/.claude/settings.local.json"
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

log "--- [5/8] Copiando dotfiles ---" "SECTION"

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
        # OJO: el rm debe respetar --dry-run. Si se borra aca pero el ln se
        # saltea por DryRun, el symlink desaparece sin recrearse (rompe ~/.bashrc).
        if [[ "$DRY_RUN" == true ]]; then
            # Respeta el modo silencioso (paso [5/8] colapsado): al log, no a pantalla.
            if [[ "$_QUIET_STEPS" == 1 ]]; then
                echo "[$(date +%H:%M:%S)][SKIP] [DryRun] Symlink $1 → $dst" >> "$LOG_FILE" 2>/dev/null || true
                _QUIET_OK=$((_QUIET_OK + 1))
            else
                log "[DryRun] Symlink $1 → $dst" "SKIP"
            fi
        else
            [[ -e "$dst" || -L "$dst" ]] && rm -f "$dst"
            run_step "Symlink $1 → $dst" ln -s "$src" "$dst"
        fi
    else
        run_step "Copiar $1 → $dst" cp "$src" "$dst"
    fi
}

# Colapsar el ruido: los symlinks/copias van al log; solo se muestra un resumen
# (y cualquier fallo). Se desactiva antes de las claves SSH (que piden passphrase).
_QUIET_STEPS=1; _QUIET_OK=0

# Shell (symlinks: editar en el repo se ve al instante)
copy_dotfile "shell/bashrc"         "$HOME/.bashrc"        "link"
copy_dotfile "shell/bash_profile"   "$HOME/.bash_profile"  "link"
copy_dotfile "shell/zshrc"          "$HOME/.zshrc"         "link"
copy_dotfile "shell/zprofile"       "$HOME/.zprofile"      "link"

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

# rclone.conf (vault privado): contiene el token de iCloud Drive.
# Se COPIA (no symlink) porque rclone reescribe el archivo al refrescar el
# token de Apple, y un symlink ensuciaria el working tree del vault. El token
# 2FA caduca cada tanto: si rclone pide reautenticar, corre 'rclone config'
# y luego 'cp ~/.config/rclone/rclone.conf <vault>/rclone/' para reversionarlo.
if [[ -f "$VAULT_DIR/rclone/rclone.conf" ]]; then
    copy_dotfile "$VAULT_DIR/rclone/rclone.conf"  "$HOME/.config/rclone/rclone.conf"
    run_step "Permisos ~/.config/rclone/rclone.conf" chmod 600 "$HOME/.config/rclone/rclone.conf"
fi

# Pausa del modo silencioso para las claves SSH (piden passphrase, deben verse).
# Se reactiva después para la segunda tanda; el resumen total va al cierre del paso.
_QUIET_STEPS=0

# SSH keys (encriptadas con age, en el vault privado)
SSH_KEYS_DIR="$VAULT_DIR/ssh/keys"
SSH_KEYS_OK=0
if [[ -d "$SSH_KEYS_DIR" ]] && ls "$SSH_KEYS_DIR"/*.age &>/dev/null; then
    if [[ "$DRY_RUN" == true ]]; then
        # En dry-run NO pedir passphrase (era un efecto secundario real): solo simular.
        for age_file in "$SSH_KEYS_DIR"/*.age; do
            log "[DryRun] Desencriptar $(basename "$age_file" .age) → ~/.ssh/" "SKIP"
        done
    elif has_cmd age; then
        # Optimizacion + anti-choclo: si TODAS las claves privadas ya existen, ni
        # pedimos la passphrase. Si falta alguna, se pide una vez. Los "ya existe"
        # van al log; en pantalla solo un resumen (y los errores/desencriptados).
        _keys_missing=0 _keys_new=0
        for age_file in "$SSH_KEYS_DIR"/*.age; do
            [[ -f "$HOME/.ssh/$(basename "$age_file" .age)" ]] || _keys_missing=$((_keys_missing + 1))
        done

        if [[ "$_keys_missing" -eq 0 ]]; then
            for age_file in "$SSH_KEYS_DIR"/*.age; do
                echo "[$(date +%H:%M:%S)][SKIP] ~/.ssh/$(basename "$age_file" .age) ya existe" >> "$LOG_FILE" 2>/dev/null || true
                SSH_KEYS_OK=$((SSH_KEYS_OK + 1))
            done
        else
            log "Desencriptando claves SSH (se pide passphrase una sola vez)..." "INFO"
            read -s -p "Passphrase para claves SSH: " AGE_PASSPHRASE
            echo ""
            for age_file in "$SSH_KEYS_DIR"/*.age; do
                key_name="$(basename "$age_file" .age)"
                dst_key="$HOME/.ssh/$key_name"
                if [[ -f "$dst_key" ]]; then
                    echo "[$(date +%H:%M:%S)][SKIP] ~/.ssh/$key_name ya existe" >> "$LOG_FILE" 2>/dev/null || true
                    SSH_KEYS_OK=$((SSH_KEYS_OK + 1))
                elif printf '%s' "$AGE_PASSPHRASE" | age -d -o "$dst_key" "$age_file" 2>/dev/null; then
                    chmod 600 "$dst_key"
                    log "Desencriptado $key_name → ~/.ssh/$key_name" "OK"
                    SSH_KEYS_OK=$((SSH_KEYS_OK + 1)); _keys_new=$((_keys_new + 1))
                else
                    log "Error desencriptando $key_name (passphrase incorrecta?)" "ERROR"
                    ERRORS+=("Desencriptar SSH key $key_name")
                fi
            done
            unset AGE_PASSPHRASE
        fi

        # Copiar claves publicas (silencioso: al log, solo cuenta)
        for pub_file in "$SSH_KEYS_DIR"/*.pub; do
            [[ -f "$pub_file" ]] || continue
            dst_pub="$HOME/.ssh/$(basename "$pub_file")"
            if [[ -f "$dst_pub" ]]; then
                echo "[$(date +%H:%M:%S)][SKIP] $dst_pub ya existe" >> "$LOG_FILE" 2>/dev/null || true
            else
                cp "$pub_file" "$dst_pub" && chmod 644 "$dst_pub"
            fi
        done
        log "${SSH_KEYS_OK} claves SSH en ~/.ssh   (detalle en el log)" "OK"
    else
        log "age no instalado — no se pueden desencriptar las claves SSH" "WARN"
        WARNINGS+=("Instalar age para desencriptar claves SSH: curl -sSf https://dl.filippo.io/age/latest?for=linux/amd64 | tar xz")
    fi
else
    log "No hay claves .age en ssh/keys/, saltando" "SKIP"
fi

# Segunda tanda de symlinks/configs simples: también al log (modo silencioso).
# Se reactiva aca (se habia apagado para las claves SSH) y se cierra al final del
# paso, sumando al mismo contador _QUIET_OK para el resumen.
_QUIET_STEPS=1

# Editorconfig
copy_dotfile ".editorconfig"        "$HOME/.editorconfig"        "link"

# yazi (file manager TUI): config en ~/.config/yazi (en Windows va a %APPDATA%,
# ver bootstrap.ps1). Symlink: editar en el repo se versiona al instante. Solo
# si yazi esta instalado (evita crear un symlink huerfano en maquinas sin yazi).
if has_cmd yazi; then
    copy_dotfile "yazi/yazi.toml"   "$HOME/.config/yazi/yazi.toml"  "link"
fi

# Fontconfig: fuerza los emoji a color en Chrome/Chromium. Chrome en Linux NO usa
# el alias generico "emoji" de fontconfig; hace un match por cobertura de glifo,
# donde Symbola y Noto Emoji (monocromaticas) ganan y los emoji salen en B/N.
# El fonts.conf las desprioriza para que gane Noto Color Emoji. Symlink: editarlo
# en el repo se versiona al instante.
copy_dotfile "fontconfig/fonts.conf"  "$HOME/.config/fontconfig/fonts.conf"  "link"

# Claude Code
# settings.json va por symlink: editarlo en el repo (o cambios via /config que
# no sean per-maquina) se versionan al instante. El modelo por defecto es sonnet;
# los cambios de modelo se hacen en la sesion, no se persisten aca.
# settings.local.json NO se toca: es config por-maquina (permisos con rutas
# absolutas), cada PC mantiene el suyo. statusline.sh tampoco se copia: el
# settings.json lo referencia directo desde el repo (~/.dotfiles/.claude/statusline.sh).
copy_dotfile ".claude/settings.json"         "$HOME/.claude/settings.json"  "link"
# CLAUDE.md global: reglas para TODOS los proyectos (commits, etc). Symlink para
# que sea portable en cada instalacion. El CLAUDE.md de la raiz es del repo dotfiles.
copy_dotfile ".claude/CLAUDE.md"             "$HOME/.claude/CLAUDE.md"      "link"

# Tema oh-my-posh claude-code
_omp_themes_dst="${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-posh/themes"
_omp_src="$REPO_ROOT/shell/themes/claude-code.omp.json"
if [[ -f "$_omp_src" ]]; then
    mkdir -p "$_omp_themes_dst"
    run_step "Copiar tema claude-code.omp.json → oh-my-posh themes" \
        cp "$_omp_src" "$_omp_themes_dst/claude-code.omp.json"
fi
unset _omp_themes_dst _omp_src

# Ulauncher (lanzador estilo Spotlight) — solo si esta instalado.
# settings.json y shortcuts.json van por symlink: editarlos por la GUI se
# versiona al instante (mismo criterio que .claude/settings.json).
# El atajo Ctrl+Space NO se cablea aca: vive en gnome/media-keys.dconf y lo
# aplica el bloque de GNOME (dconf load). En Wayland el hotkey interno de
# Ulauncher no funciona, por eso lo dispara un atajo de GNOME -> ulauncher-toggle.
# El autostart se copia (no symlink) a ~/.config/autostart: GNOME reescribe ese
# .desktop si se togglea desde la GUI de "Aplicaciones al inicio".
if has_cmd ulauncher; then
    copy_dotfile "ulauncher/settings.json"   "$HOME/.config/ulauncher/settings.json"   "link"
    copy_dotfile "ulauncher/shortcuts.json"  "$HOME/.config/ulauncher/shortcuts.json"  "link"
    copy_dotfile "ulauncher/autostart.desktop" "$HOME/.config/autostart/ulauncher.desktop"
fi

# OpenLogi (config del mouse Logitech MX) — solo si esta instalado. El config.toml
# va por symlink: editarlo por la GUI se versiona al instante. OJO: el archivo
# tiene el serial del mouse y el unit_id del receptor incrustados en las claves,
# asi que es best-effort (sirve con el mismo mouse; si cambia, OpenLogi regenera).
if has_cmd openlogi; then
    copy_dotfile "openlogi/config.toml" "$HOME/.config/openlogi/config.toml" "link"
fi

# Google Chrome — deduplicar la entrada "Web" de Ajustes > Aplicaciones
# predeterminadas. El .rpm de Google instala DOS .desktop: google-chrome.desktop
# (historico) y com.google.Chrome.desktop (nuevo, formato reverse-DNS), y ambos
# declaran x-scheme-handler/http(s). El panel de GNOME NO respeta Hidden/NoDisplay
# (de hecho el .rpm ya marca el segundo con NoDisplay y aun asi aparece): lista
# cualquier .desktop que registre el esquema, asi que Chrome sale DOS veces. Se
# neutraliza con un override local de com.google.Chrome.desktop SIN los
# scheme-handlers (conserva PDF/imagenes), copiado a ~/.local/share/applications
# (tiene prioridad sobre /usr/share y sobrevive a los updates de Chrome). Si algun
# dia Google unifica los .desktop, basta con borrar el override.
_chrome_sys_desktop="/usr/share/applications/com.google.Chrome.desktop"
_chrome_override="$HOME/.local/share/applications/com.google.Chrome.desktop"
if has_cmd rpm && rpm -q google-chrome-stable &>/dev/null && [[ -f "$_chrome_sys_desktop" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        log "[DryRun] Override Chrome (dedup entrada Web de GNOME)" "SKIP"
    else
        mkdir -p "$(dirname "$_chrome_override")"
        sed -E 's#x-scheme-handler/(http|https|google-chrome);##g' \
            "$_chrome_sys_desktop" > "$_chrome_override"
        has_cmd update-desktop-database \
            && update-desktop-database "$(dirname "$_chrome_override")" &>/dev/null || true
        log "Override Chrome aplicado (una sola entrada Web en GNOME)" "OK"
    fi
fi
unset _chrome_sys_desktop _chrome_override

# Cierre del modo silencioso del paso [5/8]: resumen total de symlinks/configs.
# Lo que sigue (Ptyxis/GNOME dconf) SÍ se muestra: es restauración de sistema.
_QUIET_STEPS=0
log "${_QUIET_OK} archivos aplicados (symlinks/configs)   (detalle en el log)" "OK"

# Ptyxis — terminal por defecto en Fedora. La config vive en dconf (no en un
# archivo), asi que no se puede symlinkear: se restaura con 'dconf load'.
# El dump versionado se actualiza con el helper 'ptyxis-save' (ver bashrc).
_ptyxis_dump="$REPO_ROOT/terminal/ptyxis.dconf"
if has_cmd ptyxis && has_cmd dconf && [[ -f "$_ptyxis_dump" ]]; then
    run_step "Restaurar config de Ptyxis (dconf load)" \
        bash -c "dconf load /org/gnome/Ptyxis/ < '$_ptyxis_dump'"
fi
unset _ptyxis_dump

# Shell por defecto (login shell). Si zsh esta instalado, ofrecemos elegir entre
# bash y zsh con un menu de flechas (mismo estilo que el selector de herramientas)
# y aplicamos 'chsh' solo si la eleccion difiere del shell actual. Sin TTY
# (curl | bash) no se pregunta ni se toca el shell: red de seguridad.
_choose_default_shell() {
    has_cmd zsh || return 0          # sin zsh no hay nada que elegir
    [[ "$DRY_RUN" == true ]] && { log "[DryRun] Selector de shell por defecto" "SKIP"; return 0; }
    has_cmd chsh || { log "chsh no disponible — shell por defecto sin cambios" "SKIP"; return 0; }
    { [[ -e /dev/tty ]] && { : < /dev/tty; } 2>/dev/null; } || {
        log "Sin TTY interactiva — shell por defecto sin cambios" "SKIP"; return 0; }

    local zsh_path bash_path current
    zsh_path="$(command -v zsh)"
    bash_path="$(command -v bash)"
    current="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)"
    [[ -n "$current" ]] || current="$SHELL"

    # Opciones y cursor inicial sobre el shell actual
    local -a sh_names sh_paths
    sh_names=(bash zsh); sh_paths=("$bash_path" "$zsh_path")
    local cur=0
    [[ "$current" == "$zsh_path" ]] && cur=1

    local saved_stty
    saved_stty="$(stty -g < /dev/tty 2>/dev/null)" || saved_stty=""
    if [[ -z "$saved_stty" ]]; then
        # Fallback por texto si no hay modo raw
        printf '\n  Shell por defecto: 1) bash  2) zsh  [Enter = sin cambios]\n  > ' > /dev/tty
        local ans; read -r ans < /dev/tty || ans=""
        case "$ans" in
            1) cur=0 ;; 2) cur=1 ;; *) return 0 ;;
        esac
    else
        stty -echo -icanon min 1 time 0 < /dev/tty
        printf '\033[?25l' > /dev/tty
        local nlines=0 i key="" rest=""
        while true; do
            local out=$'\n  \033[1;36m▶ Shell por defecto\033[0m\n'
            out+=$'  \033[90m↑/↓ mover · Enter confirmar  (● = actual)\033[0m\n\n'
            for ((i = 0; i < 2; i++)); do
                local ptr box=$'\033[90m▱\033[0m'
                [[ "${sh_paths[i]}" == "$current" ]] && box=$'\033[32m●\033[0m'
                if (( i == cur )); then ptr=$'\033[36m❯\033[0m'; else ptr=' '; fi
                out+="  $ptr $box ${sh_names[i]}"$'\n'
            done
            if (( nlines > 0 )); then printf '\033[%dA\033[J' "$nlines" > /dev/tty; fi
            printf '%b' "$out" > /dev/tty
            local nl="${out//[^$'\n']/}"; nlines=${#nl}
            IFS= read -rsn1 key < /dev/tty || break
            if [[ "$key" == $'\033' ]]; then
                read -rsn2 -t 0.01 rest < /dev/tty || true
                key+="$rest"
            fi
            case "$key" in
                $'\033[A'|k|K) cur=$(( (cur - 1 + 2) % 2 )) ;;
                $'\033[B'|j|J) cur=$(( (cur + 1) % 2 )) ;;
                ''|$'\n')      break ;;
                q|Q)           cur=-1; break ;;
            esac
        done
        stty "$saved_stty" < /dev/tty 2>/dev/null || true
        printf '\033[?25h' > /dev/tty
        (( cur < 0 )) && return 0
    fi

    local target="${sh_paths[cur]}"
    if [[ "$target" == "$current" ]]; then
        log "Shell por defecto ya es ${sh_names[cur]} — sin cambios" "SKIP"
        return 0
    fi
    if chsh -s "$target"; then
        log "Shell por defecto cambiado a ${sh_names[cur]} ($target) — efectivo al reloguear" "OK"
    else
        log "No se pudo cambiar el shell (chsh fallo)" "WARN"
        WARNINGS+=("Cambiar shell manualmente: chsh -s $target")
    fi
}
_choose_default_shell

# GNOME — atajos, dock, extensiones y favoritos (solo si corre GNOME).
# Las extensiones de Fedora vienen como paquetes; primero se instalan, despues
# se aplican los dumps versionados. La config se actualiza con 'gnome-save'.
if has_cmd dconf && [[ -d "$REPO_ROOT/gnome" ]] && [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    # Extensiones (paquetes nativos en Fedora; en otras distros se omiten)
    if [[ "$PKG_MANAGER" == "dnf" ]]; then
        for _ext_pkg in gnome-shell-extension-dash-to-dock gnome-shell-extension-gpaste gnome-shell-extension-blur-my-shell; do
            if rpm -q "$_ext_pkg" &>/dev/null; then
                log "$_ext_pkg ya instalado" "SKIP"
            else
                run_step "Instalar $_ext_pkg" $PKG_INSTALL "$_ext_pkg"
            fi
        done
        unset _ext_pkg
    fi

    # Mapa "rama dconf : archivo" (espejo de _GNOME_DCONF_MAP en bashrc)
    _gnome_map=(
        "/org/gnome/settings-daemon/plugins/media-keys/:media-keys.dconf"
        "/org/gnome/desktop/wm/keybindings/:wm-keybindings.dconf"
        "/org/gnome/shell/extensions/dash-to-dock/:dash-to-dock.dconf"
        "/org/gnome/shell/extensions/blur-my-shell/:blur-my-shell.dconf"
        "/org/gnome/GPaste/:gpaste.dconf"
        "/org/gnome/shell/:shell.dconf"
    )
    for _entry in "${_gnome_map[@]}"; do
        _path="${_entry%%:*}"
        _file="$REPO_ROOT/gnome/${_entry##*:}"
        [[ -f "$_file" ]] || continue
        run_step "Restaurar GNOME: ${_entry##*:}" \
            bash -c "dconf load '$_path' < '$_file'"
    done
    unset _gnome_map _entry _path _file
fi

# ==============================================================================
# 6. CONFIGURAR AWS SSO (OPCIONAL)
# ==============================================================================

log "--- [6/8] Configuracion AWS SSO ---" "SECTION"

if [[ "$WITH_AWS" != true ]]; then
    log "Saltando configuracion AWS SSO (usa --with-aws para incluirla)" "SKIP"
    log "  Nota: AWS CLI ya esta instalado para claude-smg, pero SSO requiere --with-aws" "INFO"
else
    # Datos de la org (cuenta, portal SSO, rol) NO se versionan: son infra
    # privada. Se leen de ~/.env. Sin ellos no hay nada que preconfigurar.
    [[ -f "$HOME/.env" ]] && { set -a; . "$HOME/.env"; set +a; }
    : "${AWS_SSO_START_URL:=}" "${AWS_SSO_ACCOUNT_ID:=}"
    : "${AWS_SSO_ROLE_NAME:=Bedrock_Access}" "${AWS_SSO_REGION:=us-east-1}"

    if ! has_cmd aws; then
        log "AWS CLI no disponible — error inesperado" "ERROR"
        WARNINGS+=("AWS CLI deberia estar instalado pero no se encuentra")
    elif [[ -z "$AWS_SSO_ACCOUNT_ID" || -z "$AWS_SSO_START_URL" ]]; then
        log "Faltan AWS_SSO_START_URL / AWS_SSO_ACCOUNT_ID en ~/.env — salteo preconfig SSO" "WARN"
        WARNINGS+=("AWS SSO sin preconfigurar: defini AWS_SSO_START_URL, AWS_SSO_ACCOUNT_ID (y opcional AWS_SSO_ROLE_NAME) en ~/.env")
    else
        # Escribo ~/.aws/config con formato sso-session: habilita el flujo PKCE
        # (login por navegador sin codigo de 6 digitos). 'aws configure set' no
        # sabe escribir bloques [sso-session], por eso se escribe el archivo.
        log "Configurando perfil AWS SSO default (formato sso-session/PKCE)..." "INFO"
        mkdir -p "$HOME/.aws"
        [[ -f "$HOME/.aws/config" ]] && cp "$HOME/.aws/config" "$BACKUP_DIR/aws-config.bak" 2>/dev/null
        if [[ "$DRY_RUN" == true ]]; then
            log "[DryRun] Escribir ~/.aws/config (sso-session default)" "SKIP"
        else
            cat > "$HOME/.aws/config" <<AWSCFG
[sso-session default]
sso_start_url = $AWS_SSO_START_URL
sso_region = $AWS_SSO_REGION
sso_registration_scopes = sso:account:access

[default]
sso_session = default
sso_account_id = $AWS_SSO_ACCOUNT_ID
sso_role_name = $AWS_SSO_ROLE_NAME
region = $AWS_SSO_REGION
output = json
AWSCFG
            chmod 600 "$HOME/.aws/config"
            log "Perfil default pre-configurado" "OK"
        fi
        log "" "INFO"
        log "Iniciando AWS SSO login (se abrirá el navegador)..." "INFO"
        log "Seguí las instrucciones en el navegador para completar el login." "INFO"
        log "" "INFO"

        if [[ "$DRY_RUN" == false ]]; then
            # Intentar login SSO (abre navegador automáticamente)
            if aws sso login --profile default; then
                log "AWS SSO login completado exitosamente" "OK"
            else
                log "AWS SSO login falló o fue cancelado" "WARN"
                log "Podés completarlo después con: aws sso login --profile default" "WARN"
                WARNINGS+=("AWS SSO login incompleto — correr 'aws sso login --profile default'")
            fi
        else
            log "[DryRun] Saltando aws sso login" "SKIP"
        fi
    fi
fi

# ==============================================================================
# 7. VALIDACION POST-BOOTSTRAP
# ==============================================================================

log "" "INFO"
log "--- [7/8] Ejecutando validaciones post-bootstrap ---" "SECTION"

TEST_SCRIPT="$REPO_ROOT/test-bootstrap.sh"
if [[ -f "$TEST_SCRIPT" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        log "[DryRun] bash $TEST_SCRIPT" "SKIP"
    else
        # Anti-choclo: la salida completa (~90 [OK]) va al log. En pantalla solo
        # el resumen (PASS/FAIL/WARN) y, si hay fallos, las lineas [FAIL].
        _test_out="$(bash "$TEST_SCRIPT" 2>&1)"
        TEST_EXIT=$?
        printf '%s\n' "$_test_out" >> "$LOG_FILE" 2>/dev/null || true
        _p="$(printf '%s\n' "$_test_out" | grep -oE 'PASS: *[0-9]+' | grep -oE '[0-9]+' | head -1)"
        _f="$(printf '%s\n' "$_test_out" | grep -oE 'FAIL: *[0-9]+' | grep -oE '[0-9]+' | head -1)"
        if [[ "${_f:-0}" -ne 0 ]]; then
            log "Validaciones: ${_p:-?} OK · ${_f} con fallo — detalle abajo" "WARN"
            printf '%s\n' "$_test_out" | grep -iE 'FAIL|✗|\[X\]' | while IFS= read -r _l; do
                log "$_l" "ERROR"
            done
            WARNINGS+=("Validaciones post-bootstrap: ${_f} fallo(s) — ver log")
        else
            log "Validaciones: ${_p:-todas} OK   (detalle en el log)" "OK"
        fi
        unset _test_out _p _f
    fi
else
    log "test-bootstrap.sh no encontrado en $REPO_ROOT" "WARN"
fi

# ==============================================================================
# 8. RESUMEN FINAL
# ==============================================================================

log "--- [8/8] Resumen final ---" "SECTION"

# Titular segun resultado
if [[ ${#ERRORS[@]} -eq 0 ]]; then
    printf '  %b%s✓ Bootstrap completado%b\n' "$C_BOLD" "$C_OK" "$C_RESET"
else
    printf '  %b%s✗ Bootstrap terminó con %d error(es)%b\n' "$C_BOLD" "$C_ERROR" "${#ERRORS[@]}" "$C_RESET"
fi

# Linea de hitos (lo que efectivamente se hizo)
printf '\n    %b✓%b %s nuevas   %b✓%b %s configs   %b✓%b %s claves SSH\n' \
    "$C_OK" "$C_RESET" "${_new:-0}" \
    "$C_OK" "$C_RESET" "${_QUIET_OK:-0}" \
    "$C_OK" "$C_RESET" "${SSH_KEYS_OK:-0}"

# Warnings/errores destacados (siempre visibles)
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    printf '\n  %b⚠ Advertencias (%d):%b\n' "$C_WARN" "${#WARNINGS[@]}" "$C_RESET"
    for w in "${WARNINGS[@]}"; do printf '    %b·%b %s\n' "$C_WARN" "$C_RESET" "$w"; done
fi
if [[ ${#ERRORS[@]} -gt 0 ]]; then
    printf '\n  %b✗ Errores (%d):%b\n' "$C_ERROR" "${#ERRORS[@]}" "$C_RESET"
    for e in "${ERRORS[@]}"; do printf '    %b·%b %s\n' "$C_ERROR" "$C_RESET" "$e"; done
fi

printf '\n    %bLog:%b     %s\n' "$C_DIM" "$C_RESET" "$LOG_FILE"
printf '    %bBackups:%b %s\n' "$C_DIM" "$C_RESET" "$BACKUP_DIR"

banner "Proximos pasos"
log "1. Abri una terminal nueva para recargar el profile" "INFO"
log "2. Verifica tus claves SSH: ssh -T git@github.com-kevincharp" "INFO"
if [[ "$WITH_AWS" == true ]]; then
    log "3. Ejecuta: aws configure sso" "INFO"
fi
