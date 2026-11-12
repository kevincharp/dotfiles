#!/usr/bin/env bash
# ==============================================================================
#   bootstrap.sh — Setup completo de entorno de desarrollo (Linux / bash)
#   Uso:   bash bootstrap.sh [--with-aws] [--dry-run] [--skip-packages]
#                             [--all-tools] [--tools=id1,id2,...]
#                             [--pace=SEG | --fast]
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

_usage="Uso: bash bootstrap.sh [--with-aws] [--dry-run] [--skip-packages] [--all-tools] [--tools=id1,id2,...] [--pace=SEG] [--fast]"

# Dwell de la barra de progreso en segundos (BOOTSTRAP_PACE o --pace); 0 = sin pausas.
BOOTSTRAP_PACE="${BOOTSTRAP_PACE:-0.18}"
for arg in "$@"; do
    case "$arg" in
        --with-aws)       WITH_AWS=true ;;
        --dry-run)        DRY_RUN=true ;;
        --skip-packages)  SKIP_PACKAGES=true ;;
        --all-tools)      ALL_TOOLS=true ;;
        --tools=*)        TOOLS_ARG="${arg#*=}" ;;
        --pace=*)         BOOTSTRAP_PACE="${arg#*=}" ;;
        --fast)           BOOTSTRAP_PACE=0 ;;
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
# Vault privado (ssh, identidades git); si no esta, esos pasos se saltean.
VAULT_DIR="${VAULT_DIR:-$HOME/.dotfiles-vault}"
# ~/.env cifrado con age dentro del vault (lo genera env-save, paridad bash/zsh/pwsh)
VAULT_ENV_AGE="$VAULT_DIR/env/env.age"
LOG_DIR="$HOME/.local/logs"
LOG_FILE="$LOG_DIR/bootstrap-$(date +%Y%m%d-%H%M%S).log"
ERRORS=()
WARNINGS=()

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

C_RESET=$'\033[0m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERROR=$'\033[31m'
C_SKIP=$'\033[90m'; C_DIM=$'\033[90m'; C_BOLD=$'\033[1m'
# Naranja del prompt (#D4874E); sin truecolor degrada al 208.
if [[ "${COLORTERM:-}" == *truecolor* || "${COLORTERM:-}" == *24bit* ]]; then
    C_BAR=$'\033[38;2;212;135;78m'; C_SECTION=$'\033[1;38;2;212;135;78m'
else
    C_BAR=$'\033[38;5;208m';        C_SECTION=$'\033[1;38;5;208m'
fi

# ==============================================================================
# HELPERS
# ==============================================================================

log() {
    local msg="$1" level="${2:-INFO}"
    local ts; ts="$(date +%H:%M:%S)"

    echo "[$ts][$level] $msg" >> "$LOG_FILE" 2>/dev/null || true

    # Con la barra activa solo WARN/ERROR van a pantalla (via gb_note); el resto queda en el log.
    if [[ "${_GB_ACTIVE:-0}" == 1 ]]; then
        case "$level" in
            WARN)  gb_note "$C_WARN"  "$I_WARN"  "$msg" ;;
            ERROR) gb_note "$C_ERROR" "$I_ERROR" "$msg" ;;
        esac
        return 0
    fi

    case "$level" in
        SECTION)
            # Quita los bordes del banner; sin texto es un separador y se omite.
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

# Con _QUIET_STEPS=1 los run_step exitosos van solo al log y se cuentan en _QUIET_OK.
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

# age_decrypt_retry <src.age> <dst> — desencripta con hasta 3 intentos de passphrase.
# age la lee de /dev/tty, asi que reintentar es volver a invocarlo.
age_decrypt_retry() {
    local src="$1" dst="$2" try
    for try in 1 2 3; do
        if age -d -o "$dst" "$src" </dev/tty; then return 0; fi
        rm -f "$dst"
        if (( try < 3 )); then
            printf '  %sPassphrase incorrecta — intento %d de 3%s\n' "$C_WARN" "$((try + 1))" "$C_RESET" > /dev/tty
        fi
    done
    return 1
}

has_cmd() {
    command -v "$1" &>/dev/null
}

# ── BARRA DE PROGRESO GLOBAL ─────────────────────────────────────────────────
# Barra ponderada (_GB_WEIGHTS suma 100) con la accion actual en una segunda linea.
# Se pausa con gb_pause en las interacciones; sin TTY no dibuja.
_GB_WEIGHTS=(0 6 40 8 30 4 6 6)   # indice 1..7 (el 0 no se usa)
_GB_BASE=(0 0 6 46 54 84 88 94)  # % acumulado ANTES de cada paso (calculado a mano de _GB_WEIGHTS)
_GB_STEP=0 _GB_LABEL="" _GB_ACTION="" _GB_SUB=0 _GB_ACTIVE=0
_GB_ENABLED=0; [[ -t 1 ]] && _GB_ENABLED=1     # solo con TTY
# Dwell minimo por accion, para que cada paso se alcance a leer. Solo con TTY.
_GB_DWELL="${BOOTSTRAP_PACE:-0.18}"

# _gb_render — dibuja las 2 lineas y deja el cursor de vuelta en la barra.
_gb_render() {
    (( _GB_ENABLED )) || return 0
    local width=40 i pct base weight filled empty b="" cols maxw line2
    base=${_GB_BASE[$_GB_STEP]:-0}; weight=${_GB_WEIGHTS[$_GB_STEP]:-0}
    pct=$(( base + weight * _GB_SUB / 100 ))
    (( pct > 100 )) && pct=100; (( pct < 0 )) && pct=0
    filled=$(( pct * width / 100 )); (( filled > width )) && filled=$width
    empty=$(( width - filled ))
    for ((i=0;i<filled;i++)); do b+="▰"; done
    for ((i=0;i<empty;i++));  do b+="▱"; done
    cols="$(tput cols 2>/dev/null || echo 80)"; maxw=$(( cols - 6 ))
    (( maxw < 20 )) && maxw=20
    line2="[${_GB_STEP}/7] ${_GB_LABEL}"
    [[ -n "$_GB_ACTION" ]] && line2+=" · ${_GB_ACTION}"
    (( ${#line2} > maxw )) && line2="${line2:0:maxw-1}…"
    printf '\r  %b%s %3d%%%b\033[K\n  %b%s%b\033[K\033[1A\r' \
        "$C_BAR" "$b" "$pct" "$C_RESET" \
        "$C_BAR" "$line2" "$C_RESET"
    _GB_ACTIVE=1
}

# gb_step <n> <label> — entra al paso n (resetea sub a 0 y redibuja).
gb_step() {
    _GB_STEP="$1"; _GB_LABEL="$2"; _GB_SUB=0; _GB_ACTION=""
    echo "[$(date +%H:%M:%S)] === [$1/7] $2 ===" >> "$LOG_FILE" 2>/dev/null || true
    if (( _GB_ENABLED )); then _gb_render
    else printf '\n%s%s [%s/7] %s%s\n' "$C_SECTION" "$I_SECTION" "$1" "$2" "$C_RESET"; fi
}

# gb_sub <sub0..100> [accion] — avance dentro del paso. Duerme el dwell solo si cambio la accion.
gb_sub() {
    local changed=0
    [[ $# -ge 2 && "$2" != "$_GB_ACTION" ]] && changed=1
    _GB_SUB="$1"; [[ $# -ge 2 ]] && _GB_ACTION="$2"
    (( _GB_ENABLED )) || return 0
    _gb_render
    if (( changed )) && [[ "$_GB_DWELL" != "0" && -n "$_GB_DWELL" ]]; then
        sleep "$_GB_DWELL" 2>/dev/null || true
    fi
}

# gb_note <color> <icono> <msg> — escribe un evento arriba de la barra; sin TTY, linea normal.
gb_note() {
    if (( _GB_ENABLED )) && (( _GB_ACTIVE )); then printf '\r\033[K\n\r\033[K\033[1A\r'; fi
    printf '  %b%s%b %s\n' "$1" "$2" "$C_RESET" "$3"
    # Como 'if': un (( )) falso como ultimo comando seria el exit de la funcion y
    # set -e abortaria el bootstrap.
    if (( _GB_ENABLED )); then _gb_render; fi
}

# gb_pause — borra la barra para una interaccion; reaparece en la proxima gb_step/gb_sub.
gb_pause() {
    (( _GB_ENABLED )) && (( _GB_ACTIVE )) && printf '\r\033[K\n\r\033[K\033[1A\r'
    _GB_ACTIVE=0
}

# gb_end — completa la barra al 100%, la limpia y deja el cursor listo para el resumen.
gb_end() {
    if (( _GB_ENABLED )); then
        _GB_STEP=7; _GB_SUB=100; _GB_ACTION=""; _gb_render
        printf '\r\033[K\n\r\033[K\033[1A\r'
    fi
    _GB_ACTIVE=0
}

# ensure_base_deps — instala curl/wget/unzip si faltan; no estan en el catalogo.
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

# Catalogo de herramientas (TOOLS_CATALOG, tool_field).
source "$REPO_ROOT/catalogo.sh"

# tool_installed <id> — devuelve 0 si la herramienta ya esta presente
tool_installed() {
    case "$1" in
        bash-completion) [[ -f /usr/share/bash-completion/bash_completion ]] \
                            || rpm -q bash-completion &>/dev/null \
                            || dpkg -l bash-completion &>/dev/null ;;
        blesh)           [[ -f "$HOME/.local/share/blesh/ble.sh" ]] ;;
        zsh-autosuggestions)     [[ -f "$HOME/.local/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] ;;
        zsh-syntax-highlighting) [[ -f "$HOME/.local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] ;;
        firacode)        # grep -c evita el SIGPIPE que 'fc-list | grep -q' dispara con pipefail
                         [[ "$(fc-list | grep -ci "FiraCode Nerd Font")" != "0" ]] ;;
        samba)           # listo si el paquete esta y el servicio quedo habilitado
                         rpm -q samba &>/dev/null && systemctl is-enabled smb &>/dev/null ;;
        chrome)          rpm -q google-chrome-stable &>/dev/null ;;
        onlyoffice)      rpm -q onlyoffice-desktopeditors &>/dev/null ;;
        openlogi)        rpm -q openlogi &>/dev/null ;;
        obsidian)        has_cmd flatpak && flatpak info md.obsidian.Obsidian &>/dev/null ;;
        *)               local cmd; cmd="$(tool_field "$1" 3)" || return 1
                         [[ -n "$cmd" ]] && has_cmd "$cmd" ;;
    esac
}

# want_tool <id> — 0 si la herramienta se eligio en el selector o ya esta instalada.
# Es el gate de las configs del paso [4/7].
want_tool() {
    local id="$1" t
    for t in "${SELECTED_TOOLS[@]:-}"; do
        [[ "$t" == "$id" ]] && return 0
    done
    tool_installed "$id"
}

# install_tool <id> — instala la herramienta.
install_tool() {
    case "$1" in
        tree-sitter-cli|bash-completion)
            run_step "Instalar $1" $PKG_INSTALL "$1"
            ;;
        zsh-autosuggestions)
            # Sin paquete consistente entre distros: se clona a ~/.local/share.
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
            # Sin paquete: binario del release oficial a ~/.local/bin.
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
        lazysql)
            # Sin paquete: binario del release oficial a ~/.local/bin.
            run_step "Instalar lazysql (binario)" bash -c '
                tag=$(curl -fsSL "https://api.github.com/repos/jorgerojas26/lazysql/releases/latest" | grep -Po "\"tag_name\": \"\K[^\"]*")
                tmp="$(mktemp -d)"
                curl -fsSL "https://github.com/jorgerojas26/lazysql/releases/download/${tag}/lazysql_$(uname)_$(uname -m).tar.gz" -o "$tmp/lazysql.tar.gz"
                tar xzf "$tmp/lazysql.tar.gz" -C "$tmp"
                mkdir -p "$HOME/.local/bin"
                install "$tmp/lazysql" "$HOME/.local/bin/lazysql"
                rm -rf "$tmp"
            '
            ;;
        blesh)
            # Sin paquete: tarball del release oficial en ~/.local/share/blesh.
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
            # Deps de preview: poppler, ffmpeg, ImageMagick, p7zip, file y chafa (Ptyxis no
            # soporta sixel ni kitty-protocol).
            if [[ "$PKG_MANAGER" == "dnf" ]]; then
                # COPR oficial. Las deps van aparte para que el fallo de una no frene el resto.
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
                # El repo de Debian trae una version vieja: NodeSource para LTS.
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
            # En Debian gh no esta en los repos base: se agrega el repo oficial.
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
                # Repo oficial gitlab-org/cli; la version sale de la API de tags.
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
            # El remote 'icloud' se configura a mano (rclone config, pide 2FA).
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
                curl -Lo /tmp/FiraCode.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
                unzip -qo /tmp/FiraCode.zip -d "$FONT_DIR"
                rm /tmp/FiraCode.zip
                fc-cache -fv > /dev/null
            '
            ;;
        ulauncher)
            # Debian/Ubuntu necesitan el PPA; en Arch es AUR.
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
            # Servidor SMB para compartir el home (la app Archivos del iPhone solo habla SMB).
            # La contrasena queda como paso manual: sudo smbpasswd -a <usuario>.
            if [[ "$PKG_MANAGER" != "dnf" ]]; then
                log "samba: cableado solo para Fedora/dnf — instalar manualmente en esta distro" "WARN"
                WARNINGS+=("samba no configurado — distro no soportada por el bootstrap")
            else
                run_step "Instalar samba" $PKG_INSTALL samba
                run_step "Habilitar servicio smb" sudo systemctl enable --now smb
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
            # El .rpm oficial deja configurado el repo de Google para las updates.
            if [[ "$PKG_MANAGER" != "dnf" ]]; then
                log "chrome: cableado solo para Fedora/dnf (.rpm) — instalar manual en esta distro" "WARN"
                WARNINGS+=("chrome no instalado — distro no soportada por el bootstrap")
            else
                run_step "Instalar Google Chrome (.rpm oficial)" \
                    sudo dnf install -y \
                    "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
            fi
            ;;
        firefox)
            # Las web apps no funcionan en el Snap de Ubuntu: apt queda afuera.
            if [[ "$PKG_MANAGER" == "apt" ]]; then
                log "firefox: en apt instala Snap (sin web apps) — instalar manual desde Mozilla" "WARN"
                WARNINGS+=("firefox no instalado — en apt el paquete es Snap; instalar el de Mozilla a mano")
            else
                run_step "Instalar Firefox" $PKG_INSTALL firefox
            fi
            ;;
        onlyoffice)
            # .rpm oficial desde la URL directa; no agrega repo propio.
            if [[ "$PKG_MANAGER" != "dnf" ]]; then
                log "onlyoffice: cableado solo para Fedora/dnf (.rpm) — instalar manual en esta distro" "WARN"
                WARNINGS+=("onlyoffice no instalado — distro no soportada por el bootstrap")
            else
                run_step "Instalar OnlyOffice Desktop Editors (.rpm oficial)" \
                    sudo dnf install -y \
                    "https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors.x86_64.rpm"
            fi
            ;;
        openlogi)
            # .rpm del release oficial; trae reglas udev y un servicio de usuario a habilitar.
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
                run_step "Habilitar openlogi-agent (servicio de usuario)" \
                    systemctl --user enable --now openlogi-agent.service
            fi
            ;;
        remmina)
            # El core no trae los protocolos: rdp y secret (keyring) van como plugins, con
            # nombres distintos por distro. Los perfiles de conexion van al vault.
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
        obsidian)
            # Sin .rpm oficial para Fedora: Flatpak.
            if ! has_cmd flatpak; then
                run_step "Instalar flatpak" $PKG_INSTALL flatpak
            fi
            if has_cmd flatpak; then
                run_step "Agregar remote Flathub" \
                    sudo flatpak remote-add --if-not-exists flathub \
                    https://flathub.org/repo/flathub.flatpakrepo
                run_step "Instalar Obsidian (Flatpak)" \
                    sudo flatpak install -y flathub md.obsidian.Obsidian
            else
                log "obsidian: no se pudo instalar flatpak en esta distro" "WARN"
                WARNINGS+=("obsidian no instalado — falta flatpak")
            fi
            ;;
        vscode)
            # Repo oficial de Microsoft: clave GPG + repo yum, sin URL estable de .rpm.
            if [[ "$PKG_MANAGER" != "dnf" ]]; then
                log "vscode: cableado solo para Fedora/dnf (repo yum) — instalar manual en esta distro" "WARN"
                WARNINGS+=("vscode no instalado — distro no soportada por el bootstrap")
            else
                run_step "Importar clave GPG de Microsoft" \
                    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                run_step "Agregar repo de VS Code" bash -c '
                    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" \
                        | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
                '
                run_step "Instalar VS Code" sudo dnf install -y code
            fi
            ;;
        *)
            local pkg; pkg="$(tool_field "$1" 4 || true)"
            if [[ -n "$pkg" ]]; then
                run_step "Instalar $1" $PKG_INSTALL "$pkg"
            else
                log "Herramienta desconocida: $1" "WARN"
            fi
            ;;
    esac
}

# ==============================================================================
# SELECTOR DE HERRAMIENTAS
# ------------------------------------------------------------------------------
# Deja en SELECTED_TOOLS los ids a instalar. Prioridad: 1) --tools=a,b (valida contra
# el catalogo), 2) --all-tools / --dry-run (todo), 3) terminal interactiva (menu
# agrupado, opt-in: arranca sin nada marcado), 4) sin tty (CI/pipe): no instala nada y
# pide --tools/--all-tools. Es para escritorio/laptop, no para servers headless.
# ==============================================================================

SELECTED_TOOLS=()

# Valida una lista separada por comas contra el catalogo -> SELECTED_TOOLS
_select_from_csv() {
    local csv="$1" id unknown=()
    SELECTED_TOOLS=()
    IFS=',' read -ra _ids <<< "$csv"
    for id in "${_ids[@]}"; do
        id="${id// /}"   # sin espacios
        [[ -z "$id" ]] && continue
        if tool_field "$id" 2 >/dev/null; then
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

# No llamarlo GROUPS: es una variable especial de bash.
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
        out+="  ${C_SECTION}▶ Elegí qué instalar${C_RESET}${K}"$'\n'
        out+="  \033[90m↑/↓ mover · → expandir · ← colapsar · espacio marcar · Enter confirmar\033[0m${K}"$'\n'
        out+="  \033[90ma marcar todas · n desmarcar todas · q cancelar\033[0m${K}"$'\n'
        out+="${K}"$'\n'
        for ((r = 0; r < nrows; r++)); do
            kind="${ROWS[r]%%:*}"; val="${ROWS[r]#*:}"
            if (( r == cur )); then ptr="${C_BAR}❯${C_RESET}"; else ptr=' '; fi
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
        out+="  ${C_BAR}${total}${C_RESET}\033[90m de ${n} seleccionadas\033[0m${K}"$'\n'
        FRAME_N=$(( nrows + 6 ))
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
            q|Q)            # cancelar: salir sin marcar nada (Enter es confirmar)
                            for ((j = 0; j < n; j++)); do MARK[j]=0; done
                            break ;;
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
        printf '\n  %b== Selector de herramientas ==%b\n' "$C_SECTION" "$C_RESET" > /dev/tty
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

# Punto de entrada: resuelve SELECTED_TOOLS.
select_tools() {
    if [[ -n "$TOOLS_ARG" ]]; then
        _select_from_csv "$TOOLS_ARG"
        echo "[$(date +%H:%M:%S)][INFO] Herramientas via --tools: ${SELECTED_TOOLS[*]:-(ninguna)}" >> "$LOG_FILE" 2>/dev/null || true
    elif [[ "$ALL_TOOLS" == true || "$DRY_RUN" == true ]]; then
        SELECTED_TOOLS=(); for entry in "${TOOLS_CATALOG[@]}"; do SELECTED_TOOLS+=("${entry%%|*}"); done
        echo "[$(date +%H:%M:%S)][INFO] Instalando catalogo completo (${#SELECTED_TOOLS[@]} herramientas)" >> "$LOG_FILE" 2>/dev/null || true
    elif [[ -e /dev/tty ]] && { : < /dev/tty; } 2>/dev/null; then
        _select_interactive
        echo "[$(date +%H:%M:%S)][INFO] Seleccionadas ${#SELECTED_TOOLS[@]}: ${SELECTED_TOOLS[*]:-(ninguna)}" >> "$LOG_FILE" 2>/dev/null || true
    else
        SELECTED_TOOLS=()
        log "Sin terminal interactiva y sin --tools/--all-tools — no instalo nada" "WARN"
        log "  Volve a correr con --tools=id1,id2 (lista) o --all-tools (todo)" "INFO"
        WARNINGS+=("Sin tty: no se instalaron herramientas. Usa --tools=... o --all-tools")
    fi
}

# _ask_default_shell — pregunta el shell por defecto y lo guarda en DEFAULT_SHELL_TARGET;
# _apply_default_shell lo aplica despues, con zsh ya instalado.
DEFAULT_SHELL_TARGET=""
_ask_default_shell() {
    # Solo en el flujo interactivo.
    [[ -z "$TOOLS_ARG" && "$ALL_TOOLS" == false && "$DRY_RUN" == false ]] || return 0
    # zsh disponible: ya instalado, o elegido en el selector (se instalara en [2/7]).
    local zsh_selected=0 t
    for t in "${SELECTED_TOOLS[@]}"; do [[ "$t" == "zsh" ]] && zsh_selected=1; done
    { has_cmd zsh || (( zsh_selected )); } || return 0
    { [[ -e /dev/tty ]] && { : < /dev/tty; } 2>/dev/null; } || return 0   # sin tty: no preguntar

    local zsh_path bash_path current
    zsh_path="$(command -v zsh 2>/dev/null || echo /usr/bin/zsh)"
    bash_path="$(command -v bash 2>/dev/null || echo /bin/bash)"
    current="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)"
    [[ -n "$current" ]] || current="$SHELL"

    local -a sh_names sh_paths
    sh_names=(bash zsh); sh_paths=("$bash_path" "$zsh_path")
    local cur=0
    [[ "$current" == "$zsh_path" ]] && cur=1

    local saved_stty
    saved_stty="$(stty -g < /dev/tty 2>/dev/null)" || saved_stty=""
    if [[ -z "$saved_stty" ]]; then
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
            local out=$'\n  '"$C_BAR"$'▶ Shell por defecto'"$C_RESET"$'\n'
            out+=$'  \033[90m↑/↓ mover · Enter confirmar  (● = actual)\033[0m\n\n'
            for ((i = 0; i < 2; i++)); do
                local ptr box=$'\033[90m▱\033[0m'
                [[ "${sh_paths[i]}" == "$current" ]] && box=$'\033[32m●\033[0m'
                if (( i == cur )); then ptr="$C_BAR"$'❯'"$C_RESET"; else ptr=' '; fi
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
    DEFAULT_SHELL_TARGET="${sh_paths[cur]}"
    echo "[$(date +%H:%M:%S)][INFO] Shell por defecto elegido: ${sh_names[cur]} ($DEFAULT_SHELL_TARGET)" >> "$LOG_FILE" 2>/dev/null || true
}

# ==============================================================================
# PANTALLA DE BIENVENIDA
# ------------------------------------------------------------------------------
# Explica que hace el instalador y muestra el catalogo por grupo antes de arrancar.
# Solo en modo interactivo (con /dev/tty): con --tools/--all-tools/--dry-run o sin
# tty se saltea para no estorbar en flujos automatizados.
# ==============================================================================

welcome_screen() {
    # Detectar SO/pkg de forma ligera (el paso [1/7] hace la deteccion oficial)
    local distro="Linux" pkg="?"
    [[ -r /etc/os-release ]] && distro="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}")"
    if   has_cmd dnf;    then pkg="dnf"
    elif has_cmd apt;    then pkg="apt"
    elif has_cmd pacman; then pkg="pacman"; fi
    local vault_ok="✗ sin vault"; [[ -d "$VAULT_DIR" ]] && vault_ok="✓ vault presente"

    local g j c line
    printf '%b' "$C_SECTION" > /dev/tty
    cat > /dev/tty <<'EOF'
  ╭──────────────────────────────────────────────────────────────╮
  │                                                              │
  │   ●  dotfiles · Setup de entorno                             │
  │      Linux · reproducible en cualquier máquina               │
  │                                                              │
  ╰──────────────────────────────────────────────────────────────╯
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

if [[ -z "$TOOLS_ARG" && "$ALL_TOOLS" == false && "$DRY_RUN" == false ]] \
   && [[ -e /dev/tty ]] && { : < /dev/tty; } 2>/dev/null; then
    welcome_screen
fi

banner "bootstrap.sh — Setup de entorno" "$(date '+%Y-%m-%d %H:%M:%S')$([[ "$DRY_RUN" == true ]] && echo '  ·  modo DryRun')"

# Sin ~/.env local ni cifrado en el vault: avisar antes de arrancar.
if [[ ! -f "$HOME/.env" && ! -f "$VAULT_ENV_AGE" ]]; then
    printf '  %s⚠ ~/.env con tus tokens: no esta en esta maquina ni en el vault.%s\n' "$C_WARN" "$C_RESET"
    printf '  %s  Si venis de otra maquina, copialo ahora a ~/.env (o alla corre env-save\n' "$C_DIM"
    printf '    para que viaje cifrado en el vault). Sin el, AWS/Bedrock te pide los datos a mano.%s\n' "$C_RESET"
    if [[ "$DRY_RUN" == false && -z "$TOOLS_ARG" && "$ALL_TOOLS" == false ]] \
       && [[ -e /dev/tty ]] && { : < /dev/tty; } 2>/dev/null; then
        printf '  Enter para continuar (Ctrl+C para salir): ' > /dev/tty
        read -r _ < /dev/tty || true
    fi
fi

# ==============================================================================
# 1. VERIFICAR REQUISITOS
# ==============================================================================

gb_step 1 "Verificando requisitos"

if ! has_cmd git; then
    log "Git no esta instalado" "ERROR"
    exit 1
fi
gb_sub 40 "git $(git --version | cut -d' ' -f3)"
log "git $(git --version | cut -d' ' -f3) OK" "OK"

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
gb_sub 100 "package manager: $PKG_MANAGER"
log "Package manager: $PKG_MANAGER" "OK"

# ==============================================================================
# 2. INSTALAR PAQUETES
# ==============================================================================

gb_step 2 "Instalando paquetes"

if [[ "$SKIP_PACKAGES" == true ]]; then
    log "skip-packages activado, saltando" "SKIP"
elif [[ "$PKG_MANAGER" == "none" ]]; then
    log "Sin package manager, saltando paquetes" "WARN"
    WARNINGS+=("Instalar paquetes manualmente: neovim, tree-sitter-cli, ripgrep, fzf, zoxide, lazygit")
else
    # El selector y (en dnf) el sudo del update piden pantalla: pausamos la barra.
    gb_pause
    select_tools
    # El shell por defecto se pregunta aca y se aplica en [4/7].
    _ask_default_shell

    if [[ ${#SELECTED_TOOLS[@]} -eq 0 ]]; then
        gb_step 2 "Instalando paquetes"
        log "No se selecciono ninguna herramienta, saltando instalacion" "SKIP"
    else
        if [[ "$DRY_RUN" == false ]]; then
            # PKG_UPDATE lleva '|| true' adentro: va via bash -c para que sea un operador.
            printf '  %sActualizando fuentes (puede pedir contraseña sudo)...%s\n' "$C_DIM" "$C_RESET"
            bash -c "$PKG_UPDATE" 2>&1 | tail -1 || true
        fi

        ensure_base_deps

        # Lo ya instalado va al log; lo nuevo se anota arriba de la barra.
        gb_step 2 "Instalando paquetes"
        local_total=${#SELECTED_TOOLS[@]}
        _done=0 _already=0 _new=0
        for _tool_id in "${SELECTED_TOOLS[@]}"; do
            # No ((_done++)): con set -e devuelve 1 cuando vale 0 y aborta.
            _done=$((_done + 1))
            gb_sub $(( _done * 100 / local_total )) "$_tool_id"
            if tool_installed "$_tool_id"; then
                echo "[$(date +%H:%M:%S)][SKIP] $_tool_id ya instalado" >> "$LOG_FILE" 2>/dev/null || true
                _already=$((_already + 1))
            else
                # install_tool imprime salida propia: se pausa la barra.
                gb_pause
                install_tool "$_tool_id"
                _new=$((_new + 1))
                gb_sub $(( _done * 100 / local_total )) "$_tool_id"
                gb_note "$C_OK" "$I_OK" "$_tool_id instalado"
            fi
        done
        log "${_already} ya instaladas · ${_new} nuevas   (detalle en el log)" "INFO"
        unset _tool_id
    fi
fi

# ==============================================================================
# 3. CREAR ESTRUCTURA DE CARPETAS
# ==============================================================================

gb_step 3 "Creando carpetas"

DIRS=(
    "$HOME/.config/git"
    "$HOME/.local/bin"
    "$HOME/.local/logs"
    "$HOME/.cache"
    "$HOME/.ssh"
)
# Como 'if': 'want_tool x && ...' deja $? en 1 y envenena chequeos posteriores.
if want_tool lazygit; then
    DIRS+=("$HOME/.config/lazygit")
fi

for _c in personal work cei_walle; do DIRS+=("$HOME/repositorios/$_c"); done
unset _c

_dirs_new=0 _dirs_had=0
_dirs_total=${#DIRS[@]}; _dirs_i=0
for dir in "${DIRS[@]}"; do
    _dirs_i=$((_dirs_i + 1))
    if [[ -d "$dir" ]]; then
        gb_sub $(( _dirs_i * 100 / _dirs_total )) "validando ${dir/#$HOME/\~}"
        echo "[$(date +%H:%M:%S)][SKIP] $dir ya existe" >> "$LOG_FILE" 2>/dev/null || true
        _dirs_had=$((_dirs_had + 1))
    else
        gb_sub $(( _dirs_i * 100 / _dirs_total )) "creando ${dir/#$HOME/\~}"
        _QUIET_STEPS=1; run_step "Crear $dir" mkdir -p "$dir"; _QUIET_STEPS=0
        _dirs_new=$((_dirs_new + 1))
    fi
done
unset _dirs_total _dirs_i
# Permisos de .ssh y .env, en silencio.
_QUIET_STEPS=1
run_step "Permisos ~/.ssh" chmod 700 "$HOME/.ssh"
if [[ -f "$HOME/.env" ]]; then
    run_step "Permisos ~/.env" chmod 600 "$HOME/.env"
fi
_QUIET_STEPS=0

log "${_dirs_new} carpetas creadas · ${_dirs_had} ya existían · permisos aplicados" "OK"

if [[ ! -f "$HOME/.env" && -f "$VAULT_ENV_AGE" ]]; then
    log "~/.env no existe — se restaura desde el vault (env/env.age) con las claves SSH" "INFO"
elif [[ ! -f "$HOME/.env" ]]; then
    log "~/.env no existe — crealo con tus tokens y guardalo en el vault con env-save" "WARN"
    WARNINGS+=("~/.env no encontrado — crealo y corre env-save para que viaje cifrado en el vault")
fi

# ==============================================================================
# 4. COPIAR DOTFILES
# ==============================================================================

gb_step 4 "Copiando dotfiles"

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

    local dst_dir
    dst_dir="$(dirname "$dst")"
    [[ -d "$dst_dir" ]] || mkdir -p "$dst_dir"

    if [[ "$mode" == "link" ]]; then
        # El rm respeta --dry-run: si no, el symlink se borra sin recrearse.
        if [[ "$DRY_RUN" == true ]]; then
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

# link_dir <src-relativo> <dst> — symlink de directorio, idempotente. Un directorio
# real en el destino se reemplaza.
link_dir() {
    local src="$1" dst="$2"
    [[ "$src" == /* ]] || src="$REPO_ROOT/$src"

    if [[ ! -d "$src" ]]; then
        log "Origen no encontrado: $src" "WARN"
        WARNINGS+=("$src no encontrado")
        return
    fi
    if [[ "$DRY_RUN" == true ]]; then
        if [[ "$_QUIET_STEPS" == 1 ]]; then
            echo "[$(date +%H:%M:%S)][SKIP] [DryRun] Symlink dir $1 → $dst" >> "$LOG_FILE" 2>/dev/null || true
            _QUIET_OK=$((_QUIET_OK + 1))
        else
            log "[DryRun] Symlink dir $1 → $dst" "SKIP"
        fi
        return
    fi
    if [[ -L "$dst" && "$(readlink -f "$dst" 2>/dev/null)" == "$(readlink -f "$src")" ]]; then
        echo "[$(date +%H:%M:%S)][SKIP] $dst ya apunta a $src" >> "$LOG_FILE" 2>/dev/null || true
        [[ "$_QUIET_STEPS" == 1 ]] && _QUIET_OK=$((_QUIET_OK + 1))
        return
    fi
    if [[ -d "$dst" && ! -L "$dst" ]]; then
        run_step "Quitar $dst (se reemplaza por symlink)" rm -rf "$dst"
    fi
    [[ -L "$dst" ]] && rm -f "$dst"
    mkdir -p "$(dirname "$dst")"
    run_step "Symlink dir $1 → $dst" ln -s "$src" "$dst"
}

# Symlinks y copias van al log; se muestra solo un resumen y los fallos.
_QUIET_STEPS=1; _QUIET_OK=0

gb_sub 15 "symlinks de shell y git"
copy_dotfile "shell/bashrc"         "$HOME/.bashrc"        "link"
copy_dotfile "shell/bash_profile"   "$HOME/.bash_profile"  "link"
if want_tool zsh; then
    copy_dotfile "shell/zshrc"      "$HOME/.zshrc"         "link"
    copy_dotfile "shell/zprofile"   "$HOME/.zprofile"      "link"
fi

copy_dotfile "git/ignore"           "$HOME/.config/git/ignore"    "link"

# Git config e identidades (vault).
if [[ -d "$VAULT_DIR/git" ]]; then
    copy_dotfile "$VAULT_DIR/git/config"           "$HOME/.gitconfig"            "link"
    for _s in personal work cei_walle; do
        copy_dotfile "$VAULT_DIR/git/config-$_s" "$HOME/.gitconfig-$_s" "link"
    done
    unset _s
else
    log "Vault no encontrado en $VAULT_DIR — saltando git config e identidades" "WARN"
    WARNINGS+=("~/.gitconfig e identidades no aplicados — sin vault")
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
    WARNINGS+=("~/.ssh/config no aplicado — sin vault")
fi

# Se copia: rclone reescribe el archivo al refrescar el token. Si pide reautenticar,
# correr 'rclone config' y copiar el resultado de vuelta al vault.
if [[ -f "$VAULT_DIR/rclone/rclone.conf" ]]; then
    copy_dotfile "$VAULT_DIR/rclone/rclone.conf"  "$HOME/.config/rclone/rclone.conf"
    run_step "Permisos ~/.config/rclone/rclone.conf" chmod 600 "$HOME/.config/rclone/rclone.conf"
fi

# Las claves SSH piden passphrase: fuera del modo silencioso.
_QUIET_STEPS=0

gb_sub 40 "claves SSH"
# SSH keys (encriptadas con age, en el vault privado)
SSH_KEYS_DIR="$VAULT_DIR/ssh/keys"
SSH_KEYS_OK=0
if [[ -d "$SSH_KEYS_DIR" ]] && ls "$SSH_KEYS_DIR"/*.age &>/dev/null; then
    if [[ "$DRY_RUN" == true ]]; then
        # En dry-run no se pide passphrase.
        for age_file in "$SSH_KEYS_DIR"/*.age; do
            log "[DryRun] Desencriptar $(basename "$age_file" .age) → ~/.ssh/" "SKIP"
        done
    elif has_cmd age; then
        # Si no falta ninguna clave privada no se invoca age.
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
            # age lee la passphrase de /dev/tty, una vez por clave faltante.
            gb_pause
            printf '  %sDesencriptando claves SSH que faltan (%d)...%s\n' "$C_DIM" "$_keys_missing" "$C_RESET"
            for age_file in "$SSH_KEYS_DIR"/*.age; do
                key_name="$(basename "$age_file" .age)"
                dst_key="$HOME/.ssh/$key_name"
                if [[ -f "$dst_key" ]]; then
                    echo "[$(date +%H:%M:%S)][SKIP] ~/.ssh/$key_name ya existe" >> "$LOG_FILE" 2>/dev/null || true
                    SSH_KEYS_OK=$((SSH_KEYS_OK + 1))
                elif age_decrypt_retry "$age_file" "$dst_key"; then
                    chmod 600 "$dst_key"
                    log "Desencriptado $key_name → ~/.ssh/$key_name" "OK"
                    SSH_KEYS_OK=$((SSH_KEYS_OK + 1)); _keys_new=$((_keys_new + 1))
                else
                    log "Error desencriptando $key_name (3 intentos fallidos)" "ERROR"
                    ERRORS+=("Desencriptar SSH key $key_name")
                    rm -f "$dst_key"
                fi
            done
        fi

        # Claves publicas.
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

# ~/.env solo se restaura si falta: el local puede tener tokens mas nuevos.
if [[ ! -f "$VAULT_ENV_AGE" ]]; then
    echo "[$(date +%H:%M:%S)][SKIP] No hay env/env.age en el vault" >> "$LOG_FILE" 2>/dev/null || true
elif [[ -f "$HOME/.env" ]]; then
    echo "[$(date +%H:%M:%S)][SKIP] ~/.env ya existe, no se pisa con el del vault" >> "$LOG_FILE" 2>/dev/null || true
elif ! has_cmd age; then
    log "age no instalado — no se puede restaurar ~/.env del vault" "WARN"
elif [[ "$DRY_RUN" == true ]]; then
    log "[DryRun] Desencriptar env/env.age → ~/.env" "SKIP"
else
    gb_pause
    printf '  %sRestaurando ~/.env desde el vault — age pide la passphrase...%s\n' "$C_DIM" "$C_RESET"
    if ( umask 077; age_decrypt_retry "$VAULT_ENV_AGE" "$HOME/.env" ); then
        chmod 600 "$HOME/.env"
        log "~/.env restaurado desde el vault" "OK"
    else
        log "Error restaurando ~/.env desde el vault (3 intentos fallidos)" "ERROR"
        ERRORS+=("Restaurar ~/.env desde el vault")
    fi
fi

# Boveda de Obsidian: repo privado cuya URL sale de OBSIDIAN_REPO en ~/.env.
# Se clona en ~/obsidian (OBSIDIAN_DIR) si no existe; va despues de las claves SSH.
if want_tool obsidian; then
    _obs_repo="${OBSIDIAN_REPO:-}"
    if [[ -z "$_obs_repo" && -f "$HOME/.env" ]]; then
        _obs_repo="$(sed -n 's/^\(export \)\{0,1\}OBSIDIAN_REPO=//p' "$HOME/.env" | head -1 | tr -d "\"'" | tr -d '\r')"
    fi
    _obs_dir="${OBSIDIAN_DIR:-$HOME/obsidian}"
    if [[ -z "$_obs_repo" ]]; then
        echo "[$(date +%H:%M:%S)][SKIP] OBSIDIAN_REPO no definido en ~/.env, no se clona la boveda" >> "$LOG_FILE" 2>/dev/null || true
    elif [[ -d "$_obs_dir/.git" ]]; then
        echo "[$(date +%H:%M:%S)][SKIP] $_obs_dir ya existe, no se clona la boveda" >> "$LOG_FILE" 2>/dev/null || true
    elif [[ "$DRY_RUN" == true ]]; then
        log "[DryRun] Clonar la boveda de Obsidian $_obs_repo → $_obs_dir" "SKIP"
    elif git clone "$_obs_repo" "$_obs_dir" >> "$LOG_FILE" 2>&1; then
        log "Boveda de Obsidian clonada en $_obs_dir" "OK"
    else
        log "No se pudo clonar la boveda de Obsidian ($_obs_repo)" "WARN"
        WARNINGS+=("Boveda de Obsidian sin clonar — revisa las claves SSH y corre: git clone $_obs_repo $_obs_dir")
    fi
fi

# Segunda tanda en modo silencioso.
_QUIET_STEPS=1
gb_sub 60 "configs de apps"

copy_dotfile ".editorconfig"        "$HOME/.editorconfig"        "link"

# Symlink de directorio: lazy.nvim escribe lazy-lock.json directo en el repo.
if want_tool neovim; then
    link_dir "nvim" "$HOME/.config/nvim"
fi

if want_tool yazi; then
    copy_dotfile "yazi/yazi.toml"   "$HOME/.config/yazi/yazi.toml"  "link"
fi

# Los perfiles tienen carpetas aleatorias: los resuelve firefox/aplicar-perfiles.sh.
# Sale 3 si algo quedo sin aplicar (advertencia, no fallo).
if want_tool firefox; then
    _ff_args=()
    if [[ "$DRY_RUN" == true ]]; then _ff_args=(--dry-run); fi
    _ff_rc=0
    _ff_out="$(bash "$REPO_ROOT/firefox/aplicar-perfiles.sh" ${_ff_args[@]+"${_ff_args[@]}"} 2>&1)" || _ff_rc=$?
    printf '%s\n' "$_ff_out" >> "$LOG_FILE" 2>/dev/null || true
    if [[ "$_ff_rc" -eq 0 ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log "[DryRun] Firefox: config de perfiles" "SKIP"
        else
            log "Firefox: config de perfiles aplicada" "OK"
        fi
    elif [[ "$_ff_rc" -eq 3 ]]; then
        log "Firefox: config incompleta (detalle en los avisos del final)" "WARN"
        while IFS= read -r _ff_linea; do
            WARNINGS+=("${_ff_linea#*\[WARN\] }")
        done < <(grep -F '[WARN]' <<< "$_ff_out" || true)
    else
        log "Firefox: aplicar-perfiles.sh fallo (rc=$_ff_rc)" "ERROR"
        ERRORS+=("Firefox: aplicar-perfiles.sh fallo (rc=$_ff_rc)")
    fi
    unset _ff_args _ff_rc _ff_out _ff_linea
fi

# Fuerza los emoji a color en Chrome (ver .claude/rules/fontconfig.md). Solo con
# Chrome/Chromium: es una preferencia de fuentes de todo el sistema.
if want_tool chrome || has_cmd chromium; then
    copy_dotfile "fontconfig/fonts.conf"  "$HOME/.config/fontconfig/fonts.conf"  "link"
fi

# settings.json por symlink (un /model tambien escribe ahi: revisar el diff).
# settings.local.json es por maquina; statusline.sh se referencia desde el repo.
if want_tool claude; then
    copy_dotfile ".claude/settings.json"         "$HOME/.claude/settings.json"  "link"
    # Reglas globales para todos los proyectos.
    copy_dotfile ".claude/CLAUDE.md"             "$HOME/.claude/CLAUDE.md"      "link"
    link_dir ".claude/agents"                    "$HOME/.claude/agents"
fi
# Codex y opencode leen el mismo archivo como AGENTS.md.
if want_tool codex; then
    copy_dotfile ".claude/CLAUDE.md"         "$HOME/.codex/AGENTS.md"       "link"
fi
if want_tool opencode; then
    copy_dotfile ".claude/CLAUDE.md"         "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/AGENTS.md"  "link"
fi

_omp_themes_dst="${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-posh/themes"
_omp_src="$REPO_ROOT/shell/themes/claude-code.omp.json"
if [[ -f "$_omp_src" ]] && want_tool oh-my-posh; then
    mkdir -p "$_omp_themes_dst"
    run_step "Copiar tema claude-code.omp.json → oh-my-posh themes" \
        cp "$_omp_src" "$_omp_themes_dst/claude-code.omp.json"
fi
unset _omp_themes_dst _omp_src

# Ulauncher: settings y shortcuts por symlink. El atajo vive en gnome/media-keys.dconf.
# El autostart se copia: GNOME reescribe ese .desktop.
if want_tool ulauncher; then
    copy_dotfile "ulauncher/settings.json"   "$HOME/.config/ulauncher/settings.json"   "link"
    copy_dotfile "ulauncher/shortcuts.json"  "$HOME/.config/ulauncher/shortcuts.json"  "link"
    copy_dotfile "ulauncher/autostart.desktop" "$HOME/.config/autostart/ulauncher.desktop"
    # Sin este symlink el theme-name apunta a un tema inexistente.
    link_dir "ulauncher/user-themes" "$HOME/.config/ulauncher/user-themes"
fi

# El config.toml lleva el serial del mouse: sirve solo con el mismo mouse.
if want_tool openlogi; then
    copy_dotfile "openlogi/config.toml" "$HOME/.config/openlogi/config.toml" "link"
fi

# No se symlinkea settings.json: Settings Sync pisa el archivo y puede traer datos
# privados. Las claves de telemetria se setean a mano una vez.
if want_tool vscode; then
    log "  VS Code: aplica a mano las 2 claves de telemetria (ver vscode/settings.json); con Settings Sync activo se propagan solas al resto de tus maquinas" "INFO"
    WARNINGS+=("VS Code: telemetria no se symlinkea (choca con Settings Sync) — aplicar vscode/settings.json a mano")
fi

# Chrome instala dos .desktop con scheme-handlers y aparece duplicado en "Web".
# Override local sin scheme-handlers y con Hidden=true (.claude/rules/chrome-predeterminado.md).
_chrome_sys_desktop="/usr/share/applications/com.google.Chrome.desktop"
_chrome_override="$HOME/.local/share/applications/com.google.Chrome.desktop"
if has_cmd rpm && rpm -q google-chrome-stable &>/dev/null && [[ -f "$_chrome_sys_desktop" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        log "[DryRun] Override Chrome (dedup entrada Web de GNOME)" "SKIP"
    else
        mkdir -p "$(dirname "$_chrome_override")"
        sed -E 's#x-scheme-handler/(http|https|google-chrome);##g' \
            "$_chrome_sys_desktop" > "$_chrome_override"
        sed -i '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nHidden=true/' "$_chrome_override"
        has_cmd update-desktop-database \
            && update-desktop-database "$(dirname "$_chrome_override")" &>/dev/null || true
        log "Override Chrome aplicado (una sola entrada Web/Abrir con en GNOME)" "OK"
    fi
fi
unset _chrome_sys_desktop _chrome_override

# Mismo caso: google-maps-geo-handler.desktop duplica a org.gnome.Maps. Override con Hidden=true.
_maps_sys_desktop="/usr/share/applications/google-maps-geo-handler.desktop"
_maps_override="$HOME/.local/share/applications/google-maps-geo-handler.desktop"
if [[ -f "$_maps_sys_desktop" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        log "[DryRun] Override Google Maps geo-handler (dedup Abrir con)" "SKIP"
    else
        mkdir -p "$(dirname "$_maps_override")"
        cp "$_maps_sys_desktop" "$_maps_override"
        sed -i '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nHidden=true/' "$_maps_override"
        has_cmd update-desktop-database \
            && update-desktop-database "$(dirname "$_maps_override")" &>/dev/null || true
        log "Override Google Maps geo-handler aplicado (una sola entrada Mapas)" "OK"
    fi
fi
unset _maps_sys_desktop _maps_override

# La config de Ptyxis vive en dconf: se restaura con 'dconf load' (ptyxis-save la vuelca).
_ptyxis_dump="$REPO_ROOT/terminal/ptyxis.dconf"
if has_cmd ptyxis && has_cmd dconf && [[ -f "$_ptyxis_dump" ]]; then
    run_step "Restaurar config de Ptyxis (dconf load)" \
        bash -c "dconf load /org/gnome/Ptyxis/ < '$_ptyxis_dump'"
fi
unset _ptyxis_dump

# Override del .desktop con --new-window y sin DBusActivatable: el del sistema solo
# activa la ventana ya abierta (docs/notas-tecnicas.md).
_ptyxis_sys_desktop="/usr/share/applications/org.gnome.Ptyxis.desktop"
_ptyxis_override="$HOME/.local/share/applications/org.gnome.Ptyxis.desktop"
if has_cmd ptyxis && [[ -f "$_ptyxis_sys_desktop" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        log "[DryRun] Override Ptyxis (lanzadores -> ventana nueva)" "SKIP"
    else
        mkdir -p "$(dirname "$_ptyxis_override")"
        sed -E 's#^Exec=ptyxis$#Exec=ptyxis --new-window#; /^DBusActivatable=true$/d' \
            "$_ptyxis_sys_desktop" > "$_ptyxis_override"
        has_cmd update-desktop-database \
            && update-desktop-database "$(dirname "$_ptyxis_override")" &>/dev/null || true
        log "Override Ptyxis aplicado (lanzadores abren ventana nueva)" "OK"
    fi
fi
unset _ptyxis_sys_desktop _ptyxis_override

_QUIET_STEPS=0
gb_sub 75 "configs aplicadas"
log "${_QUIET_OK} archivos aplicados (symlinks/configs/dconf)   (detalle en el log)" "INFO"

# Aplica el shell elegido en _ask_default_shell.
_apply_default_shell() {
    [[ -n "${DEFAULT_SHELL_TARGET:-}" ]] || return 0   # no se eligio nada
    has_cmd chsh || { log "chsh no disponible — shell por defecto sin cambios" "SKIP"; return 0; }
    local current
    current="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)"
    [[ -n "$current" ]] || current="$SHELL"
    if [[ "$DEFAULT_SHELL_TARGET" == "$current" ]]; then
        echo "[$(date +%H:%M:%S)][SKIP] Shell por defecto ya es $DEFAULT_SHELL_TARGET — sin cambios" >> "$LOG_FILE" 2>/dev/null || true
        return 0
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo "[$(date +%H:%M:%S)][SKIP] [DryRun] chsh -s $DEFAULT_SHELL_TARGET" >> "$LOG_FILE" 2>/dev/null || true
        return 0
    fi
    if chsh -s "$DEFAULT_SHELL_TARGET"; then
        gb_note "$C_OK" "$I_OK" "shell por defecto → $(basename "$DEFAULT_SHELL_TARGET") (efectivo al reloguear)"
    else
        log "No se pudo cambiar el shell (chsh fallo)" "WARN"
        WARNINGS+=("Cambiar shell manualmente: chsh -s $DEFAULT_SHELL_TARGET")
    fi
}
_apply_default_shell

# GNOME: se instalan las extensiones y despues se cargan los dumps (gnome-save los vuelca).
if has_cmd dconf && [[ -d "$REPO_ROOT/gnome" ]] && [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    _QUIET_STEPS=1; _QUIET_OK=0
    _gnome_ext_new=0

    # Extensiones (paquetes nativos en Fedora; en otras distros se omiten)
    if [[ "$PKG_MANAGER" == "dnf" ]]; then
        for _ext_pkg in gnome-shell-extension-dash-to-dock gnome-shell-extension-blur-my-shell; do
            if rpm -q "$_ext_pkg" &>/dev/null; then
                echo "[$(date +%H:%M:%S)][SKIP] $_ext_pkg ya instalado" >> "$LOG_FILE" 2>/dev/null || true
            else
                gb_pause   # dnf escupe salida: fuera de la barra
                run_step "Instalar $_ext_pkg" $PKG_INSTALL "$_ext_pkg"
                _gnome_ext_new=$((_gnome_ext_new + 1))
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
        "/org/gnome/shell/:shell.dconf"
    )
    _gnome_total=${#_gnome_map[@]}; _gnome_i=0
    for _entry in "${_gnome_map[@]}"; do
        _path="${_entry%%:*}"
        _file="$REPO_ROOT/gnome/${_entry##*:}"
        _gnome_i=$((_gnome_i + 1))
        [[ -f "$_file" ]] || continue
        gb_sub $(( 75 + _gnome_i * 25 / _gnome_total )) "GNOME: ${_entry##*:}"
        run_step "Restaurar GNOME: ${_entry##*:}" \
            bash -c "dconf load '$_path' < '$_file'"
    done
    _QUIET_STEPS=0
    if (( _gnome_ext_new > 0 )); then
        log "GNOME restaurado: ${_gnome_total} ajustes · ${_gnome_ext_new} extensiones nuevas   (detalle en el log)" "INFO"
    else
        log "GNOME restaurado: ${_gnome_total} ajustes dconf   (detalle en el log)" "INFO"
    fi
    unset _gnome_map _entry _path _file _gnome_total _gnome_i _gnome_ext_new
fi

# ==============================================================================
# 6. CONFIGURAR AWS SSO (OPCIONAL)
# ==============================================================================

gb_step 5 "Configuración AWS SSO"

# Sin --with-aws y con tty: preguntar.
if [[ "$WITH_AWS" != true ]] && [[ -e /dev/tty ]] && { : < /dev/tty; } 2>/dev/null; then
    gb_pause
    printf '\n  %b▶ Claude Code con Bedrock (AWS SSO)%b\n' "$C_BAR" "$C_RESET" > /dev/tty
    printf '  ¿Configurar el acceso AWS/Bedrock para claude-smg? [s/N] ' > /dev/tty
    _aws_ans=""; read -r _aws_ans < /dev/tty || _aws_ans=""
    case "$_aws_ans" in [sSyY]*) WITH_AWS=true ;; esac
    unset _aws_ans
fi

if [[ "$WITH_AWS" != true ]]; then
    gb_sub 100 "saltado"
    log "Saltando configuracion AWS SSO" "SKIP"
    log "  Podés configurarlo luego con: bootstrap --with-aws" "INFO"
else
    gb_pause   # el login SSO abre navegador y es interactivo
    # Los datos de la org son infra privada: se leen de ~/.env.
    [[ -f "$HOME/.env" ]] && { set -a; . "$HOME/.env"; set +a; }
    : "${AWS_SSO_START_URL:=}" "${AWS_SSO_ACCOUNT_ID:=}"
    : "${AWS_SSO_ROLE_NAME:=Bedrock_Access}" "${AWS_SSO_REGION:=us-east-1}"
    # Nombre del perfil y de la sso-session; el mismo que usa claude-smg.
    AWS_SSO_PROFILE="${AWS_SSO_PROFILE:-${CLAUDE_SMG_AWS_PROFILE:-default}}"

    # Faltan datos y hay tty: pedirlos y guardarlos en ~/.env.
    if [[ -z "$AWS_SSO_ACCOUNT_ID" || -z "$AWS_SSO_START_URL" ]] \
       && [[ -e /dev/tty ]] && { : < /dev/tty; } 2>/dev/null; then
        log "Faltan datos de AWS SSO en ~/.env — te los pido ahora" "INFO"
        if [[ -z "$AWS_SSO_START_URL" ]]; then
            printf '  Portal SSO (ej: https://tu-org.awsapps.com/start/#): ' > /dev/tty
            read -r AWS_SSO_START_URL < /dev/tty || true
        fi
        if [[ -z "$AWS_SSO_ACCOUNT_ID" ]]; then
            printf '  Account ID: ' > /dev/tty
            read -r AWS_SSO_ACCOUNT_ID < /dev/tty || true
        fi
        printf '  Rol [%s]: ' "$AWS_SSO_ROLE_NAME" > /dev/tty
        read -r _r < /dev/tty || true; [[ -n "$_r" ]] && AWS_SSO_ROLE_NAME="$_r"; unset _r
        printf '  Tu usuario/perfil [%s]: ' "$AWS_SSO_PROFILE" > /dev/tty
        read -r _p < /dev/tty || true; [[ -n "$_p" ]] && AWS_SSO_PROFILE="$_p"; unset _p

        # Persistir solo las claves que aún no estén en ~/.env (evita duplicados).
        if [[ -n "$AWS_SSO_START_URL" && -n "$AWS_SSO_ACCOUNT_ID" ]]; then
            # umask 077: si el archivo nace aca no debe quedar legible por otros.
            _env="$HOME/.env"; ( umask 077; touch "$_env" ); chmod 600 "$_env"; _aws_add=""
            grep -q '^AWS_SSO_START_URL='  "$_env" || _aws_add+="AWS_SSO_START_URL=$AWS_SSO_START_URL"$'\n'
            grep -q '^AWS_SSO_ACCOUNT_ID=' "$_env" || _aws_add+="AWS_SSO_ACCOUNT_ID=$AWS_SSO_ACCOUNT_ID"$'\n'
            grep -q '^AWS_SSO_ROLE_NAME='  "$_env" || _aws_add+="AWS_SSO_ROLE_NAME=$AWS_SSO_ROLE_NAME"$'\n'
            grep -q '^AWS_SSO_REGION='     "$_env" || _aws_add+="AWS_SSO_REGION=$AWS_SSO_REGION"$'\n'
            grep -q '^AWS_SSO_PROFILE='    "$_env" || _aws_add+="AWS_SSO_PROFILE=$AWS_SSO_PROFILE"$'\n'
            if [[ -n "$_aws_add" ]]; then
                printf '\n# AWS SSO (Bedrock) — agregado por bootstrap\n%s' "$_aws_add" >> "$_env"
                log "Datos AWS guardados en ~/.env" "OK"
            fi
            unset _env _aws_add
        fi
    fi

    if ! has_cmd aws; then
        log "AWS CLI no instalada (no se marco 'aws' en el selector) — salteo la config SSO" "WARN"
        WARNINGS+=("AWS CLI ausente: corre 'bash bootstrap.sh --tools=aws --with-aws' para instalarla y configurar SSO")
    elif [[ -z "$AWS_SSO_ACCOUNT_ID" || -z "$AWS_SSO_START_URL" ]]; then
        log "Faltan AWS_SSO_START_URL / AWS_SSO_ACCOUNT_ID en ~/.env — salteo preconfig SSO" "WARN"
        WARNINGS+=("AWS SSO sin preconfigurar: defini AWS_SSO_START_URL, AWS_SSO_ACCOUNT_ID (y opcional AWS_SSO_ROLE_NAME) en ~/.env")
    else
        # Se escribe el archivo: 'aws configure set' no sabe crear bloques [sso-session].
        log "Configurando perfil AWS SSO '$AWS_SSO_PROFILE' (formato sso-session/PKCE)..." "INFO"
        mkdir -p "$HOME/.aws"
        # AWS nombra distinto el perfil default ([default]) y los nombrados
        # ([profile X]); la sso-session siempre es [sso-session X].
        if [[ "$AWS_SSO_PROFILE" == "default" ]]; then
            aws_profile_header="[default]"
        else
            aws_profile_header="[profile $AWS_SSO_PROFILE]"
        fi
        if [[ "$DRY_RUN" == true ]]; then
            log "[DryRun] Escribir ~/.aws/config (sso-session $AWS_SSO_PROFILE)" "SKIP"
        else
            cat > "$HOME/.aws/config" <<AWSCFG
[sso-session $AWS_SSO_PROFILE]
sso_start_url = $AWS_SSO_START_URL
sso_region = $AWS_SSO_REGION
sso_registration_scopes = sso:account:access

$aws_profile_header
sso_session = $AWS_SSO_PROFILE
sso_account_id = $AWS_SSO_ACCOUNT_ID
sso_role_name = $AWS_SSO_ROLE_NAME
region = $AWS_SSO_REGION
output = json
AWSCFG
            # Perfiles adicionales bajo la MISMA sso-session (reusan el login).
            # Formato en ~/.env: AWS_EXTRA_PROFILES="perfil:cuenta:rol[:region];..."
            # Ej: "pre:111111111111:MiRol;prod:222222222222:MiRol"
            if [[ -n "${AWS_EXTRA_PROFILES:-}" ]]; then
                _extra_n=0
                _oldifs="$IFS"; IFS=';'
                for _p in $AWS_EXTRA_PROFILES; do
                    [[ -z "$_p" ]] && continue
                    IFS=':' read -r _pn _pa _pr _preg <<< "$_p"
                    [[ -z "$_pn" || -z "$_pa" || -z "$_pr" ]] && {
                        log "AWS_EXTRA_PROFILES: entrada inválida '$_p' (falta perfil/cuenta/rol) — la salteo" "WARN"
                        continue
                    }
                    [[ -z "$_preg" ]] && _preg="$AWS_SSO_REGION"
                    {
                        printf '\n[profile %s]\n' "$_pn"
                        printf 'sso_session = %s\n' "$AWS_SSO_PROFILE"
                        printf 'sso_account_id = %s\n' "$_pa"
                        printf 'sso_role_name = %s\n' "$_pr"
                        printf 'region = %s\n' "$_preg"
                        printf 'output = json\n'
                    } >> "$HOME/.aws/config"
                    _extra_n=$((_extra_n + 1))
                done
                IFS="$_oldifs"
                unset _p _pn _pa _pr _preg _oldifs
                [[ "$_extra_n" -gt 0 ]] && log "Perfiles AWS extra pre-configurados: $_extra_n" "OK"
                unset _extra_n
            fi
            chmod 600 "$HOME/.aws/config"
            log "Perfil '$AWS_SSO_PROFILE' pre-configurado" "OK"
        fi
        log "" "INFO"
        log "Iniciando AWS SSO login (se abrirá el navegador)..." "INFO"
        log "Seguí las instrucciones en el navegador para completar el login." "INFO"
        log "" "INFO"

        if [[ "$DRY_RUN" == false ]]; then
            if aws sso login --profile "$AWS_SSO_PROFILE"; then
                log "AWS SSO login completado exitosamente" "OK"
            else
                log "AWS SSO login falló o fue cancelado" "WARN"
                log "Podés completarlo después con: aws sso login --profile $AWS_SSO_PROFILE" "WARN"
                WARNINGS+=("AWS SSO login incompleto — correr 'aws sso login --profile $AWS_SSO_PROFILE'")
            fi
        else
            log "[DryRun] Saltando aws sso login" "SKIP"
        fi
    fi
fi

# ==============================================================================
# 7. VALIDACION POST-BOOTSTRAP
# ==============================================================================

gb_step 6 "Validaciones post-bootstrap"
gb_sub 30 "ejecutando test-bootstrap.sh"

TEST_SCRIPT="$REPO_ROOT/test-bootstrap.sh"
if [[ -f "$TEST_SCRIPT" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        log "[DryRun] bash $TEST_SCRIPT" "SKIP"
    else
        # La salida completa va al log. El '|| TEST_EXIT=$?' evita que set -e aborte si hay FAILs.
        TEST_EXIT=0
        _test_out="$(bash "$TEST_SCRIPT" 2>&1)" || TEST_EXIT=$?
        printf '%s\n' "$_test_out" >> "$LOG_FILE" 2>/dev/null || true
        _p="$(printf '%s\n' "$_test_out" | grep -oE 'PASS: *[0-9]+' | grep -oE '[0-9]+' | head -1)"
        _f="$(printf '%s\n' "$_test_out" | grep -oE 'FAIL: *[0-9]+' | grep -oE '[0-9]+' | head -1)"
        gb_sub 100 "test-bootstrap.sh"
        if [[ "${_f:-0}" -ne 0 ]]; then
            log "Validaciones: ${_p:-?} OK · ${_f} con fallo — detalle abajo" "WARN"
            printf '%s\n' "$_test_out" | grep -iE 'FAIL|✗|\[X\]' | while IFS= read -r _l; do
                log "$_l" "ERROR"
            done
            WARNINGS+=("Validaciones post-bootstrap: ${_f} fallo(s) — ver log")
        else
            gb_note "$C_OK" "$I_OK" "${_p:-todas} validaciones OK   (detalle en el log)"
        fi
        unset _test_out _p _f
    fi
else
    log "test-bootstrap.sh no encontrado en $REPO_ROOT" "WARN"
fi

# ==============================================================================
# 8. RESUMEN FINAL
# ==============================================================================

gb_step 7 "Finalizando"
gb_sub 100 "escribiendo resumen"
gb_end
echo "[$(date +%H:%M:%S)] === [7/7] Resumen final ===" >> "$LOG_FILE" 2>/dev/null || true

if [[ ${#ERRORS[@]} -eq 0 ]]; then
    printf '  %b%s✓ Bootstrap completado%b\n' "$C_BOLD" "$C_OK" "$C_RESET"
else
    printf '  %b%s✗ Bootstrap terminó con %d error(es)%b\n' "$C_BOLD" "$C_ERROR" "${#ERRORS[@]}" "$C_RESET"
fi

printf '\n    %b✓%b %s nuevas   %b✓%b %s configs   %b✓%b %s claves SSH\n' \
    "$C_OK" "$C_RESET" "${_new:-0}" \
    "$C_OK" "$C_RESET" "${_QUIET_OK:-0}" \
    "$C_OK" "$C_RESET" "${SSH_KEYS_OK:-0}"

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    printf '\n  %b⚠ Advertencias (%d):%b\n' "$C_WARN" "${#WARNINGS[@]}" "$C_RESET"
    for w in "${WARNINGS[@]}"; do printf '    %b·%b %s\n' "$C_WARN" "$C_RESET" "$w"; done
fi
if [[ ${#ERRORS[@]} -gt 0 ]]; then
    printf '\n  %b✗ Errores (%d):%b\n' "$C_ERROR" "${#ERRORS[@]}" "$C_RESET"
    for e in "${ERRORS[@]}"; do printf '    %b·%b %s\n' "$C_ERROR" "$C_RESET" "$e"; done
fi

printf '\n    %bLog:%b     %s\n' "$C_DIM" "$C_RESET" "$LOG_FILE"

banner "Proximos pasos"
log "1. Abri una terminal nueva para recargar el profile" "INFO"
_ssh_alias_hint="$(bash -c '
    declare -A GIT_IDENTITIES_NAME GIT_IDENTITIES_EMAIL GIT_SSH_ALIASES
    GIT_PROFILE_REMOTES=()
    source "$1" >/dev/null 2>&1 || true
    for _a in "${!GIT_SSH_ALIASES[@]}"; do echo "$_a"; done | sort | head -1
' _ "$VAULT_DIR/shell/git-identities.sh" 2>/dev/null)" || _ssh_alias_hint=""
log "2. Verifica tus claves SSH: ssh -T git@${_ssh_alias_hint:-<host-alias>}" "INFO"
unset _ssh_alias_hint
if [[ "$WITH_AWS" == true ]]; then
    log "3. Ejecuta: aws configure sso" "INFO"
fi
