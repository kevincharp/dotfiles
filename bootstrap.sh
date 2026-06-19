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
C_SKIP=$'\033[90m'; C_SECTION=$'\033[1;36m'; C_DIM=$'\033[90m'

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
    "curl|core|Cliente HTTP"
    "wget|core|Descargas"
    "unzip|core|Descompresion"
    "bash-completion|core|Autocompletado de bash"
    "oh-my-posh|shell|Prompt con tema"
    "zoxide|shell|cd inteligente con memoria"
    "eza|shell|Reemplazo moderno de ls"
    "lazygit|shell|UI de git en terminal"
    "blesh|shell|Syntax highlighting en bash (estilo PSReadLine)"
    "node|dev|Runtime JS + npm"
    "codex|dev|Codex CLI (OpenAI)"
    "claude|dev|Claude Code CLI"
    "opencode|dev|opencode (SST)"
    "aws|cloud|AWS CLI (Bedrock)"
    "gh|cloud|GitHub CLI (PRs/issues + clonado del vault)"
    "glab|cloud|GitLab CLI"
    "age|cloud|Encriptacion de claves SSH"
    "rclone|cloud|Sync nube (iCloud Drive, etc.) - ver icloud-mount"
    "firacode|fonts|FiraCode Nerd Font"
)

# tool_installed <id> — devuelve 0 si la herramienta ya esta presente
tool_installed() {
    case "$1" in
        neovim)          has_cmd nvim ;;
        ripgrep)         has_cmd rg ;;
        fzf)             has_cmd fzf ;;
        curl)            has_cmd curl ;;
        wget)            has_cmd wget ;;
        unzip)           has_cmd unzip ;;
        bash-completion) [[ -f /usr/share/bash-completion/bash_completion ]] \
                            || rpm -q bash-completion &>/dev/null \
                            || dpkg -l bash-completion &>/dev/null ;;
        oh-my-posh)      has_cmd oh-my-posh ;;
        zoxide)          has_cmd zoxide ;;
        eza)             has_cmd eza ;;
        lazygit)         has_cmd lazygit ;;
        blesh)           [[ -f "$HOME/.local/share/blesh/ble.sh" ]] ;;
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
        *)               return 1 ;;
    esac
}

# install_tool <id> — instala la herramienta (logica por distro preservada)
install_tool() {
    case "$1" in
        neovim|ripgrep|fzf|curl|wget|unzip|bash-completion)
            run_step "Instalar $1" $PKG_INSTALL "$1"
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
#   4. sin terminal (curl | bash sin tty) -> todo, como red de seguridad
#
# El menu arranca con TODO pre-marcado: Enter directo = instalar todo. Se
# alterna por numero, por grupo (core/shell/dev/cloud/fonts) o con todo/nada.
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

# Menu interactivo sobre /dev/tty (funciona con 'curl | bash')
_select_interactive() {
    # Estado de marcado: indice del catalogo -> 1 (marcado) / 0
    local -a marked
    local i n="${#TOOLS_CATALOG[@]}"
    for ((i = 0; i < n; i++)); do marked[i]=1; done   # todo pre-marcado

    local groups=(core shell dev cloud fonts)
    local g entry id grp desc

    while true; do
        # --- Pintar menu agrupado ---
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
        printf '\n  Comandos: numeros (ej "1 3 5") | grupo (core/shell/dev/cloud/fonts) | todo | nada | ok\n' > /dev/tty
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
                core|shell|dev|cloud|fonts)
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
        [[ "${marked[i]}" == "1" ]] && SELECTED_TOOLS+=("${TOOLS_CATALOG[i]%%|*}")
    done
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
        SELECTED_TOOLS=(); for entry in "${TOOLS_CATALOG[@]}"; do SELECTED_TOOLS+=("${entry%%|*}"); done
        log "Sin terminal interactiva — instalando catalogo completo (red de seguridad)" "INFO"
    fi
}

# ==============================================================================
# INICIO
# ==============================================================================

mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

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

        # Recorre solo lo seleccionado: instala lo que falte, saltea lo ya presente.
        for _tool_id in "${SELECTED_TOOLS[@]}"; do
            if tool_installed "$_tool_id"; then
                log "$_tool_id ya instalado" "SKIP"
            else
                install_tool "$_tool_id"
            fi
        done
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
            log "[DryRun] Symlink $1 → $dst" "SKIP"
        else
            [[ -e "$dst" || -L "$dst" ]] && rm -f "$dst"
            run_step "Symlink $1 → $dst" ln -s "$src" "$dst"
        fi
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

# rclone.conf (vault privado): contiene el token de iCloud Drive.
# Se COPIA (no symlink) porque rclone reescribe el archivo al refrescar el
# token de Apple, y un symlink ensuciaria el working tree del vault. El token
# 2FA caduca cada tanto: si rclone pide reautenticar, corre 'rclone config'
# y luego 'cp ~/.config/rclone/rclone.conf <vault>/rclone/' para reversionarlo.
if [[ -f "$VAULT_DIR/rclone/rclone.conf" ]]; then
    copy_dotfile "$VAULT_DIR/rclone/rclone.conf"  "$HOME/.config/rclone/rclone.conf"
    run_step "Permisos ~/.config/rclone/rclone.conf" chmod 600 "$HOME/.config/rclone/rclone.conf"
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
# settings.local.json NO se copia: es config por-maquina (permisos con rutas
# absolutas), cada PC mantiene el suyo. statusline.sh tampoco: el settings.json
# lo referencia directo desde el repo (~/.dotfiles/.claude/statusline.sh).
copy_dotfile ".claude/settings.json"         "$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude/plugins"
copy_dotfile ".claude/plugins/installed_plugins.json"  "$HOME/.claude/plugins/installed_plugins.json"
copy_dotfile ".claude/plugins/known_marketplaces.json" "$HOME/.claude/plugins/known_marketplaces.json"

# Tema oh-my-posh claude-code
_omp_themes_dst="${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-posh/themes"
_omp_src="$REPO_ROOT/shell/themes/claude-code.omp.json"
if [[ -f "$_omp_src" ]]; then
    mkdir -p "$_omp_themes_dst"
    run_step "Copiar tema claude-code.omp.json → oh-my-posh themes" \
        cp "$_omp_src" "$_omp_themes_dst/claude-code.omp.json"
fi
unset _omp_themes_dst _omp_src

# Ptyxis — terminal por defecto en Fedora. La config vive en dconf (no en un
# archivo), asi que no se puede symlinkear: se restaura con 'dconf load'.
# El dump versionado se actualiza con el helper 'ptyxis-save' (ver bashrc).
_ptyxis_dump="$REPO_ROOT/terminal/ptyxis.dconf"
if has_cmd ptyxis && has_cmd dconf && [[ -f "$_ptyxis_dump" ]]; then
    run_step "Restaurar config de Ptyxis (dconf load)" \
        bash -c "dconf load /org/gnome/Ptyxis/ < '$_ptyxis_dump'"
fi
unset _ptyxis_dump

# GNOME — atajos, dock, extensiones y favoritos (solo si corre GNOME).
# Las extensiones de Fedora vienen como paquetes; primero se instalan, despues
# se aplican los dumps versionados. La config se actualiza con 'gnome-save'.
if has_cmd dconf && [[ -d "$REPO_ROOT/gnome" ]] && [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    # Extensiones (paquetes nativos en Fedora; en otras distros se omiten)
    if [[ "$PKG_MANAGER" == "dnf" ]]; then
        for _ext_pkg in gnome-shell-extension-dash-to-dock gnome-shell-extension-gpaste; do
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
# 8. RESUMEN FINAL
# ==============================================================================

banner "[8/8] Resumen final"

if [[ ${#ERRORS[@]} -eq 0 && ${#WARNINGS[@]} -eq 0 ]]; then
    log "Bootstrap completado sin errores." "OK"
else
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        log "Advertencias (${#WARNINGS[@]}):" "WARN"
        for w in "${WARNINGS[@]}"; do
            log "$w" "WARN"
        done
    fi
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        log "Errores (${#ERRORS[@]}):" "ERROR"
        for e in "${ERRORS[@]}"; do
            log "$e" "ERROR"
        done
    fi
fi

log "" "INFO"
log "Backups en: $BACKUP_DIR" "INFO"
log "Log en:     $LOG_FILE" "INFO"

banner "Proximos pasos"
log "1. Abri una terminal nueva para recargar el profile" "INFO"
log "2. Verifica tus claves SSH: ssh -T git@github.com-kevincharp" "INFO"
if [[ "$WITH_AWS" == true ]]; then
    log "3. Ejecuta: aws configure sso" "INFO"
fi
