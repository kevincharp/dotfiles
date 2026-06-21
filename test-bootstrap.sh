#!/usr/bin/env bash
# ==============================================================================
#   test-bootstrap.sh — Validacion post-bootstrap (Linux / bash)
#   Uso:   bash test-bootstrap.sh
# ==============================================================================

set -uo pipefail

# ==============================================================================
# CONFIG
# ==============================================================================

LOG_DIR="$HOME/.local/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/test-bootstrap-$(date +%Y%m%d-%H%M%S).log"

PASS=0
FAIL=0
WARN=0

# ==============================================================================
# HELPERS
# ==============================================================================

green()  { printf '\033[32m%s\033[0m\n' "$*"; }
red()    { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
cyan()   { printf '\033[36m%s\033[0m\n' "$*"; }

test_ok() {
    ((PASS++))
    green "[OK]   $1"
    echo "[OK]   $1" >> "$LOG_FILE"
}

test_fail() {
    ((FAIL++))
    red "[FAIL] $1: $2"
    echo "[FAIL] $1: $2" >> "$LOG_FILE"
}

test_warn() {
    ((WARN++))
    yellow "[WARN] $1: $2"
    echo "[WARN] $1: $2" >> "$LOG_FILE"
}

section() {
    echo ""
    cyan "--- $1 ---"
    echo "--- $1 ---" >> "$LOG_FILE"
}

has_cmd() {
    command -v "$1" &>/dev/null
}

# Identidades y aliases SSH esperados (desde el vault, misma fuente que el shell).
# Si el vault no esta, las secciones que dependen de el se saltean.
_GI_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/git-identities.sh"
declare -gA GIT_IDENTITIES_NAME GIT_IDENTITIES_EMAIL GIT_SSH_ALIASES
[[ -f "$_GI_FILE" ]] && . "$_GI_FILE"
VAULT_LOADED=$([[ ${#GIT_IDENTITIES_EMAIL[@]} -gt 0 ]] && echo true || echo false)

# ==============================================================================
# 1. DIRECTORIOS REQUERIDOS
# ==============================================================================

section "1. Directorios requeridos"

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
        test_ok "$dir existe"
    else
        test_fail "$dir" "no existe"
    fi
done

# ==============================================================================
# 2. DOTFILES COPIADOS Y NO VACIOS
# ==============================================================================

section "2. Dotfiles copiados"

DOTFILES=(
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.gitconfig"
    "$HOME/.gitconfig-personal"
    "$HOME/.gitconfig-work"
    "$HOME/.gitconfig-cei_walle"
    "$HOME/.config/git/ignore"
    "$HOME/.ssh/config"
    "$HOME/.editorconfig"
)

for f in "${DOTFILES[@]}"; do
    if [[ -f "$f" && -s "$f" ]]; then
        test_ok "$(basename "$f") presente y no vacio"
    elif [[ -f "$f" ]]; then
        test_fail "$(basename "$f")" "existe pero esta vacio"
    else
        test_fail "$(basename "$f")" "no encontrado en $f"
    fi
done

# Dotfiles de zsh: solo se exigen si zsh esta instalado (es opcional por maquina).
if has_cmd zsh; then
    for f in "$HOME/.zshrc" "$HOME/.zprofile"; do
        if [[ -f "$f" && -s "$f" ]]; then
            test_ok "$(basename "$f") presente y no vacio"
        elif [[ -f "$f" ]]; then
            test_fail "$(basename "$f")" "existe pero esta vacio"
        else
            test_fail "$(basename "$f")" "no encontrado en $f"
        fi
    done
fi

# ==============================================================================
# 3. COMANDOS EN PATH
# ==============================================================================

section "3. Comandos en PATH"

REQUIRED_CMDS=(git nvim node)
OPTIONAL_CMDS=(oh-my-posh zoxide fzf rg lazygit eza age zsh)

for cmd in "${REQUIRED_CMDS[@]}"; do
    if has_cmd "$cmd"; then
        test_ok "$cmd disponible"
    else
        test_fail "$cmd" "no encontrado en PATH"
    fi
done

for cmd in "${OPTIONAL_CMDS[@]}"; do
    if has_cmd "$cmd"; then
        test_ok "$cmd disponible"
    else
        test_warn "$cmd" "no encontrado en PATH (opcional)"
    fi
done

# ==============================================================================
# 4. PERMISOS ~/.ssh
# ==============================================================================

section "4. Permisos ~/.ssh"

if [[ -d "$HOME/.ssh" ]]; then
    perms=$(stat -c '%a' "$HOME/.ssh" 2>/dev/null)
    if [[ "$perms" == "700" ]]; then
        test_ok "~/.ssh permisos 700"
    else
        test_fail "~/.ssh permisos" "tiene $perms, esperado 700"
    fi
else
    test_fail "~/.ssh" "directorio no existe"
fi

# ==============================================================================
# 5. PERMISOS ~/.env
# ==============================================================================

section "5. Permisos ~/.env"

if [[ -f "$HOME/.env" ]]; then
    perms=$(stat -c '%a' "$HOME/.env" 2>/dev/null)
    if [[ "$perms" == "600" ]]; then
        test_ok "~/.env permisos 600"
    else
        test_fail "~/.env permisos" "tiene $perms, esperado 600"
    fi
else
    test_warn "~/.env" "no existe (crealo manualmente con tus tokens)"
fi

# ==============================================================================
# 6. SSH CONFIG: HOST ALIASES
# ==============================================================================

section "6. SSH config — host aliases"

SSH_CONFIG="$HOME/.ssh/config"

if [[ "$VAULT_LOADED" != true ]]; then
    test_warn "SSH host aliases" "vault no cargado ($_GI_FILE) — saltando"
elif [[ -f "$SSH_CONFIG" ]]; then
    for host_alias in "${!GIT_SSH_ALIASES[@]}"; do
        expected_key="${GIT_SSH_ALIASES[$host_alias]}"

        if grep -q "Host $host_alias" "$SSH_CONFIG"; then
            test_ok "SSH host $host_alias definido"
        else
            test_fail "SSH host $host_alias" "no encontrado en ssh/config"
            continue
        fi

        if grep -A5 "Host $host_alias" "$SSH_CONFIG" | grep -q "IdentityFile.*$expected_key"; then
            test_ok "SSH $host_alias → IdentityFile $expected_key"
        else
            test_fail "SSH $host_alias IdentityFile" "esperado $expected_key"
        fi

        if grep -A5 "Host $host_alias" "$SSH_CONFIG" | grep -q "IdentitiesOnly yes"; then
            test_ok "SSH $host_alias → IdentitiesOnly yes"
        else
            test_fail "SSH $host_alias IdentitiesOnly" "no tiene IdentitiesOnly yes"
        fi
    done
else
    test_fail "SSH config" "$SSH_CONFIG no existe"
fi

# ==============================================================================
# 7. GIT CONFIG: useConfigOnly + includeIf
# ==============================================================================

section "7. Git config — useConfigOnly + includeIf"

GITCONFIG="$HOME/.gitconfig"

if [[ -f "$GITCONFIG" ]]; then
    val=$(git config --file "$GITCONFIG" --get user.useConfigOnly 2>/dev/null)
    if [[ "$val" == "true" ]]; then
        test_ok "user.useConfigOnly = true"
    else
        test_fail "user.useConfigOnly" "valor: '$val', esperado: 'true'"
    fi

    if [[ "$VAULT_LOADED" != true ]]; then
        test_warn "includeIf patterns" "vault no cargado — saltando"
    else
        for host_alias in "${!GIT_SSH_ALIASES[@]}"; do
            if grep -q "git@$host_alias" "$GITCONFIG"; then
                test_ok "includeIf para git@$host_alias presente"
            else
                test_fail "includeIf git@$host_alias" "no encontrado en .gitconfig"
            fi
        done
    fi
else
    test_fail ".gitconfig" "no existe"
fi

# ==============================================================================
# 8. IDENTITY CONFIGS
# ==============================================================================

section "8. Identity configs — user.name y user.email"

# Valores esperados desde el vault (cargado al inicio del script).
if [[ "$VAULT_LOADED" != true ]]; then
    test_warn "Identity configs" "vault no cargado ($_GI_FILE) — saltando"
else
declare -A ID_NAME=(
    ["$HOME/.gitconfig-personal"]="${GIT_IDENTITIES_NAME[kevincharp]}"
    ["$HOME/.gitconfig-work"]="${GIT_IDENTITIES_NAME[work]}"
    ["$HOME/.gitconfig-cei_walle"]="${GIT_IDENTITIES_NAME[cei_walle]}"
)

declare -A ID_EMAIL=(
    ["$HOME/.gitconfig-personal"]="${GIT_IDENTITIES_EMAIL[kevincharp]}"
    ["$HOME/.gitconfig-work"]="${GIT_IDENTITIES_EMAIL[work]}"
    ["$HOME/.gitconfig-cei_walle"]="${GIT_IDENTITIES_EMAIL[cei_walle]}"
)

for cfg in "${!ID_NAME[@]}"; do
    label="$(basename "$cfg")"
    if [[ ! -f "$cfg" ]]; then
        test_fail "$label" "archivo no existe"
        continue
    fi

    actual_name=$(git config --file "$cfg" --get user.name 2>/dev/null)
    expected_name="${ID_NAME[$cfg]}"
    if [[ "$actual_name" == "$expected_name" ]]; then
        test_ok "$label user.name = $actual_name"
    else
        test_fail "$label user.name" "tiene '$actual_name', esperado '$expected_name'"
    fi

    actual_email=$(git config --file "$cfg" --get user.email 2>/dev/null)
    expected_email="${ID_EMAIL[$cfg]}"
    if [[ "$actual_email" == "$expected_email" ]]; then
        test_ok "$label user.email = $actual_email"
    else
        test_fail "$label user.email" "tiene '$actual_email', esperado '$expected_email'"
    fi
done
fi  # fin del check de vault cargado

# ==============================================================================
# 9. SSH KEYS EXISTEN
# ==============================================================================

section "9. SSH keys"

if [[ "$VAULT_LOADED" != true ]]; then
    test_warn "SSH keys" "vault no cargado — saltando"
else
    # Nombres de clave = valores de GIT_SSH_ALIASES (unicos)
    declare -A _seen_keys=()
    for host_alias in "${!GIT_SSH_ALIASES[@]}"; do
        key="${GIT_SSH_ALIASES[$host_alias]}"
        [[ -n "${_seen_keys[$key]:-}" ]] && continue
        _seen_keys[$key]=1
        if [[ -f "$HOME/.ssh/$key" ]]; then
            test_ok "SSH key ~/.ssh/$key existe"
        else
            test_fail "SSH key ~/.ssh/$key" "no encontrada"
        fi
    done
fi

# ==============================================================================
# 10. RESOLUCION DE IDENTIDAD GIT
# ==============================================================================

section "10. Resolucion de identidad git (includeIf + hasconfig)"

git_version=$(git --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
git_major=$(echo "$git_version" | cut -d. -f1)
git_minor=$(echo "$git_version" | cut -d. -f2)

if [[ "$git_major" -lt 2 ]] || { [[ "$git_major" -eq 2 ]] && [[ "$git_minor" -lt 36 ]]; }; then
    test_warn "Git version" "git $git_version < 2.36, hasconfig:remote no soportado — saltando"
else
    test_git_identity() {
        local remote_url="$1"
        local exp_name="$2"
        local exp_email="$3"
        local label="$4"
        local tmpdir
        tmpdir=$(mktemp -d)

        (
            cd "$tmpdir" || exit 1
            git init -b main >/dev/null 2>&1
            git remote add origin "$remote_url" 2>/dev/null
            actual_name=$(git config --get user.name 2>/dev/null)
            actual_email=$(git config --get user.email 2>/dev/null)

            if [[ "$actual_name" == "$exp_name" && "$actual_email" == "$exp_email" ]]; then
                echo "OK|$label"
            else
                echo "FAIL|$label|name='$actual_name' email='$actual_email' (esperado: '$exp_name' / '$exp_email')"
            fi
        )

        rm -rf "$tmpdir"
    }

    if [[ "$VAULT_LOADED" != true ]]; then
        test_warn "Resolucion de identidad" "vault no cargado — saltando"
    else
    while IFS='|' read -r status label detail; do
        if [[ "$status" == "OK" ]]; then
            test_ok "Identidad $label resuelta correctamente"
        else
            test_fail "Identidad $label" "$detail"
        fi
    done < <(
        for entry in "${GIT_PROFILE_REMOTES[@]}"; do
            IFS='|' read -r r_url r_profile r_label <<< "$entry"
            test_git_identity "$r_url" "${GIT_IDENTITIES_NAME[$r_profile]}" "${GIT_IDENTITIES_EMAIL[$r_profile]}" "$r_label"
        done
    )
    fi
fi

# ==============================================================================
# 11. FUNCIONES SHELL DISPONIBLES
# ==============================================================================

section "11. Funciones shell"

# Lista compartida: cada funcion debe existir en bash Y (si hay zsh) en zsh.
SHELL_FUNCTIONS=(gclone gset-profile ginit gremote gsw gsync gcoi gup gpsu \
                 port killport killdev claude-smg spf icloud-mount _load_dotenv \
                 pake-app)

# fn_in_file <funcion> <archivo> — 0 si la funcion esta definida ahi
fn_in_file() {
    grep -qE "^(function )?$1\s*\(\)" "$2" 2>/dev/null
}

for fn in "${SHELL_FUNCTIONS[@]}"; do
    if fn_in_file "$fn" "$HOME/.bashrc"; then
        test_ok "Funcion $fn definida en .bashrc"
    else
        test_fail "Funcion $fn" "no encontrada en .bashrc"
    fi
done

# ==============================================================================
# 12. PARIDAD BASH <-> ZSH
# ==============================================================================

section "12. Paridad bash <-> zsh"

if ! has_cmd zsh; then
    test_warn "Paridad zsh" "zsh no instalado — saltando"
elif [[ ! -f "$HOME/.zshrc" ]]; then
    test_fail "Paridad zsh" "~/.zshrc no existe pese a tener zsh instalado"
else
    # Cada funcion del set compartido debe estar tambien en .zshrc (espejo del bashrc)
    for fn in "${SHELL_FUNCTIONS[@]}"; do
        if fn_in_file "$fn" "$HOME/.zshrc"; then
            test_ok "Funcion $fn definida en .zshrc"
        else
            test_fail "Funcion $fn" "falta en .zshrc (paridad rota con .bashrc)"
        fi
    done

    # El .zshrc debe cargar sin errores de sintaxis ni en ejecucion interactiva.
    if zsh -n "$HOME/.zshrc" 2>/dev/null; then
        test_ok ".zshrc pasa chequeo de sintaxis (zsh -n)"
    else
        test_fail ".zshrc sintaxis" "zsh -n reporta errores"
    fi
    if zsh -ic 'exit' </dev/null &>/dev/null; then
        test_ok ".zshrc carga limpia (zsh -ic exit)"
    else
        test_warn ".zshrc carga" "zsh -ic salio con error (revisar plugins/paths)"
    fi
fi

# ==============================================================================
# RESUMEN
# ==============================================================================

echo ""
cyan "======================================================"
cyan "  RESUMEN"
cyan "======================================================"
echo ""
green "  PASS: $PASS"
[[ $FAIL -gt 0 ]] && red "  FAIL: $FAIL" || echo "  FAIL: $FAIL"
[[ $WARN -gt 0 ]] && yellow "  WARN: $WARN" || echo "  WARN: $WARN"
echo ""
echo "  Log: $LOG_FILE"
cyan "======================================================"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
