#!/usr/bin/env bash
# ==============================================================================
#   git-profiles.sh — Asistente de perfiles de git + vault propio (Linux)
#   Uso:   bash ~/.dotfiles/git-profiles.sh
#
#   Para el usuario SIN vault: pregunta por consola tus contextos de trabajo
#   (personal, trabajo, ...) y con eso GENERA la misma estructura que un vault
#   hecho a mano (ver docs/adaptalo.md) y la APLICA en la maquina:
#     - ~/.gitconfig con identidad automatica por remoto (useConfigOnly+includeIf)
#     - ~/.gitconfig-<perfil> por cada contexto
#     - git-identities.sh / .ps1 (las consumen ginit/gclone y los tests)
#     - claves SSH por perfil (opcional) + Host alias en ssh/config
#     - carpetas ~/repositorios/<contexto> (GIT_CONTEXT_DIRS)
#   Al final ofrece crear el repo privado dotfiles-vault en GitHub (via gh).
#
#   Lo invoca install.sh (opcion "no tengo vault") y se puede correr suelto.
# ==============================================================================

set -euo pipefail
# Que los $(...) hereden set -e: sin esto, un fallo (EOF en ask) dentro de una
# sustitucion de comando no corta y los bucles de re-pregunta quedan infinitos.
shopt -s inherit_errexit 2>/dev/null || true

VAULT_DIR="${VAULT_DIR:-$HOME/.dotfiles-vault}"
BACKUP_DIR="$HOME/.local/backups/git-profiles/$(date +%Y%m%d-%H%M%S)"

# Entrada interactiva: /dev/tty (funciona bajo 'curl | bash'); para tests se
# puede inyectar un archivo de respuestas con GIT_PROFILES_INPUT.
_GP_IN="${GIT_PROFILES_INPUT:-/dev/tty}"
if [[ ! -r "$_GP_IN" ]]; then
    echo "git-profiles: no hay terminal interactiva (ni GIT_PROFILES_INPUT). Abortando." >&2
    exit 1
fi
exec 3< "$_GP_IN"

# --- Estilo (espejo de install.sh) --------------------------------------------
if [[ "${LANG:-}${LC_ALL:-}${LC_CTYPE:-}" == *[Uu][Tt][Ff]* ]]; then
    I_SECTION="▶"; I_OK="✓"; I_WARN="⚠"
else
    I_SECTION=">"; I_OK="[OK]"; I_WARN="[!]"
fi
C_RESET=$'\033[0m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'
C_DIM=$'\033[90m'; C_SECTION=$'\033[1;36m'

say()  { printf '%s\n' "$1"; }
head_() { printf '\n%s%s %s%s\n' "$C_SECTION" "$I_SECTION" "$1" "$C_RESET"; }
ok()   { printf '  %s%s%s %s\n' "$C_OK" "$I_OK" "$C_RESET" "$1"; }
warn() { printf '  %s%s%s %s\n' "$C_WARN" "$I_WARN" "$C_RESET" "$1"; }

# ask <prompt> [default] — lee una linea del fd 3 (tty o archivo de respuestas).
# El prompt va al tty (o a stderr si no hay): NUNCA a stdout, que es lo que
# captura el $(...) del llamador.
# Salida de prompts: /dev/tty si realmente se puede ABRIR (un [[ -w ]] no
# alcanza: sin terminal de control, existe pero abrirlo falla), si no stderr.
_GP_OUT=/dev/tty
{ : > /dev/tty; } 2>/dev/null || _GP_OUT=/dev/stderr

ask() {
    local prompt="$1" def="${2:-}" reply=""
    printf '%s' "$prompt" > "$_GP_OUT" 2>/dev/null || true
    # EOF (Ctrl+D / respuestas agotadas): abortar en vez de loopear con vacio.
    # El 'return 1' mata el script via set -e en la asignacion del llamador.
    if ! IFS= read -r -u 3 reply; then
        printf '\n%s%s%s entrada terminada (EOF) — abortando sin mas cambios\n' \
            "$C_WARN" "$I_WARN" "$C_RESET" >&2
        return 1
    fi
    printf '%s' "${reply:-$def}"
}

# ask_req <prompt> — insiste hasta obtener algo no vacio.
# OJO: corre dentro de un $(...) del llamador — todo lo que no sea el VALOR
# (warns) va a stderr, y un EOF de ask corta con exit (no re-preguntar).
ask_req() {
    local reply=""
    while [[ -z "$reply" ]]; do
        reply="$(ask "$1")" || exit 1
        [[ -z "$reply" ]] && warn "Este dato es obligatorio." >&2
    done
    printf '%s' "$reply"
}

# ==============================================================================
# BIENVENIDA + CHEQUEO DE VAULT EXISTENTE
# ==============================================================================

head_ "Asistente de perfiles de git"
say "  Configuremos tus identidades: por cada contexto (personal, trabajo, ...)"
say "  un perfil con su nombre/email, y git elige solo cual usar segun el remoto."
say "  ${C_DIM}Todo queda en un vault local ($VAULT_DIR) listo para versionar.${C_RESET}"

if [[ -f "$VAULT_DIR/git/config" ]]; then
    warn "Ya existe un vault con configuracion git en $VAULT_DIR"
    _ans="$(ask "  ¿Regenerar la config git del vault desde cero? [s/N] " "n")"
    case "$_ans" in [sSyY]*) : ;; *) say "  Sin cambios. Chau."; exit 0 ;; esac
fi

# ==============================================================================
# RECOLECCION DE PERFILES
# ==============================================================================

P_NAME=(); P_UNAME=(); P_EMAIL=(); P_PLAT=(); P_PUSER=(); P_KEY=()

_def_perfil="personal"
_prev_uname=""
while true; do
    head_ "Perfil $(( ${#P_NAME[@]} + 1 ))"

    # nombre del perfil/contexto, unico
    while true; do
        _perfil="$(ask "  Nombre del perfil/contexto [${_def_perfil}]: " "$_def_perfil")"
        _dup=0
        for _p in "${P_NAME[@]:-}"; do [[ "$_p" == "$_perfil" ]] && _dup=1; done
        [[ "$_dup" == 0 ]] && break
        warn "Ya cargaste un perfil '$_perfil' — elegi otro nombre."
    done

    if [[ -n "$_prev_uname" ]]; then
        _uname="$(ask "  Tu nombre para los commits [${_prev_uname}]: " "$_prev_uname")"
    else
        _uname="$(ask_req "  Tu nombre para los commits: ")"
    fi
    _email="$(ask_req "  Email para este perfil: ")"

    _plat="$(ask "  Plataforma [github/gitlab] (github): " "github")"
    case "$_plat" in
        [gG]it[lL]ab|gitlab) _plat="gitlab" ;;
        *)                   _plat="github" ;;
    esac
    _puser="$(ask_req "  Tu usuario en ${_plat}: ")"

    _key="$(ask "  ¿Generar una clave SSH para este perfil? [S/n] " "s")"
    case "$_key" in [nN]*) _key=0 ;; *) _key=1 ;; esac

    P_NAME+=("$_perfil"); P_UNAME+=("$_uname"); P_EMAIL+=("$_email")
    P_PLAT+=("$_plat");   P_PUSER+=("$_puser"); P_KEY+=("$_key")
    _prev_uname="$_uname"
    _def_perfil="trabajo"

    _more="$(ask "  ¿Agregar otro perfil? [s/N] " "n")"
    case "$_more" in [sSyY]*) continue ;; *) break ;; esac
done

# ==============================================================================
# RESUMEN + CONFIRMACION
# ==============================================================================

head_ "Resumen"
for i in "${!P_NAME[@]}"; do
    _alias="${P_PLAT[i]}.com-${P_PUSER[i]}"
    _keytxt=$([[ "${P_KEY[i]}" == 1 ]] && echo "clave SSH nueva" || echo "sin clave SSH")
    say "  ${C_OK}${P_NAME[i]}${C_RESET}  ${P_UNAME[i]} <${P_EMAIL[i]}>  ${C_DIM}${_alias} · ${_keytxt}${C_RESET}"
done
say "  ${C_DIM}Se genera el vault en $VAULT_DIR y se aplica en esta maquina"
say "  (lo que ya tengas se respalda en $BACKUP_DIR).${C_RESET}"
_go="$(ask "  ¿Continuar? [S/n] " "s")"
case "$_go" in [nN]*) say "  Cancelado. No se toco nada."; exit 0 ;; esac

# ==============================================================================
# GENERACION DEL VAULT
# ==============================================================================

head_ "Generando el vault"
mkdir -p "$VAULT_DIR/git" "$VAULT_DIR/shell" "$VAULT_DIR/ssh/keys" "$BACKUP_DIR"

# --- git/config-<perfil> (identidad de cada contexto) ---
for i in "${!P_NAME[@]}"; do
    cat > "$VAULT_DIR/git/config-${P_NAME[i]}" <<EOF
# Identidad del perfil '${P_NAME[i]}' — generado por git-profiles.sh
[user]
	name = ${P_UNAME[i]}
	email = ${P_EMAIL[i]}
EOF
done
ok "git/config-<perfil> (${#P_NAME[@]})"

# --- git/config (identidad automatica por remoto) ---
{
    cat <<'EOF'
# ~/.gitconfig — generado por git-profiles.sh (dotfiles)
# Identidad AUTOMATICA por remoto: segun la URL del origin, git carga el
# config-<perfil> correspondiente. Con useConfigOnly, un repo sin perfil
# aplicable NO comitea con una identidad equivocada: falla y avisa
# (se corrige con gset-profile <perfil> o ginit <perfil>).
[user]
	useConfigOnly = true
[init]
	defaultBranch = main
[core]
	editor = nvim
	autocrlf = input
[pull]
	rebase = true
[rebase]
	autostash = true
EOF
    # OJO con los globs de hasconfig (wildmatch): '*' NO cruza '/' y '**' solo
    # es especial delimitado por '/'. Por eso 'user/repo' se matchea con :*/*
    # (y :**/** para namespaces anidados de GitLab), no con ':**'.
    for i in "${!P_NAME[@]}"; do
        _alias="${P_PLAT[i]}.com-${P_PUSER[i]}"
        _host="${P_PLAT[i]}.com"
        printf '\n# perfil: %s\n' "${P_NAME[i]}"
        printf '[includeIf "hasconfig:remote.*.url:git@%s:*/*"]\n\tpath = ~/.gitconfig-%s\n' "$_alias" "${P_NAME[i]}"
        printf '[includeIf "hasconfig:remote.*.url:git@%s:**/**"]\n\tpath = ~/.gitconfig-%s\n' "$_alias" "${P_NAME[i]}"
        printf '[includeIf "hasconfig:remote.*.url:git@%s:%s/**"]\n\tpath = ~/.gitconfig-%s\n' "$_host" "${P_PUSER[i]}" "${P_NAME[i]}"
        printf '[includeIf "hasconfig:remote.*.url:https://%s/%s/**"]\n\tpath = ~/.gitconfig-%s\n' "$_host" "${P_PUSER[i]}" "${P_NAME[i]}"
    done
} > "$VAULT_DIR/git/config"
ok "git/config (useConfigOnly + includeIf por remoto)"

# --- shell/git-identities.sh (bash/zsh + tests) ---
{
    echo "# Identidades git — generado por git-profiles.sh"
    echo "# Lo consumen gclone/gset-profile/ginit (bash/zsh) y test-bootstrap.sh."
    for i in "${!P_NAME[@]}"; do
        printf 'GIT_IDENTITIES_NAME[%s]="%s"\n'  "${P_NAME[i]}" "${P_UNAME[i]}"
        printf 'GIT_IDENTITIES_EMAIL[%s]="%s"\n' "${P_NAME[i]}" "${P_EMAIL[i]}"
    done
    for i in "${!P_NAME[@]}"; do
        [[ "${P_KEY[i]}" == 1 ]] || continue
        printf 'GIT_SSH_ALIASES[%s.com-%s]="%s-%s"\n' "${P_PLAT[i]}" "${P_PUSER[i]}" "${P_PUSER[i]}" "${P_PLAT[i]}"
    done
    echo "GIT_PROFILE_REMOTES=("
    for i in "${!P_NAME[@]}"; do
        printf '    "git@%s.com-%s:%s/repo-de-prueba.git|%s|%s (%s)"\n' \
            "${P_PLAT[i]}" "${P_PUSER[i]}" "${P_PUSER[i]}" "${P_NAME[i]}" "${P_NAME[i]}" "${P_PLAT[i]}"
    done
    echo ")"
    printf 'GIT_CONTEXT_DIRS=(%s)\n' "${P_NAME[*]}"
    # Mapa archivo→perfil (~/.gitconfig-<sufijo> pertenece a <perfil>); en el
    # asistente es 1:1, pero permite vaults con sufijos historicos distintos.
    for i in "${!P_NAME[@]}"; do
        printf 'GIT_IDENTITY_FILES[%s]="%s"\n' "${P_NAME[i]}" "${P_NAME[i]}"
    done
} > "$VAULT_DIR/shell/git-identities.sh"
ok "shell/git-identities.sh"

# --- shell/git-identities.ps1 (PowerShell) ---
{
    echo "# Identidades git — generado por git-profiles.sh"
    echo "# Lo consumen gclone/gset-profile/ginit (pwsh) y test-bootstrap.ps1."
    echo '$GitIdentities = @{'
    for i in "${!P_NAME[@]}"; do
        printf "    '%s' = @{ name = '%s'; email = '%s' }\n" \
            "${P_NAME[i]}" "${P_UNAME[i]//\'/\'\'}" "${P_EMAIL[i]//\'/\'\'}"
    done
    echo '}'
    echo '$GitSshAliases = @{'
    for i in "${!P_NAME[@]}"; do
        [[ "${P_KEY[i]}" == 1 ]] || continue
        printf "    '%s.com-%s' = '%s-%s'\n" "${P_PLAT[i]}" "${P_PUSER[i]}" "${P_PUSER[i]}" "${P_PLAT[i]}"
    done
    echo '}'
    echo '$GitHostAliases = @{'
    for i in "${!P_NAME[@]}"; do
        if [[ "${P_PLAT[i]}" == "github" ]]; then
            _base="https://api.github.com"
        else
            _base="https://gitlab.com"
        fi
        _tokvar="$(echo "${P_PLAT[i]}_TOKEN_${P_PUSER[i]}" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9_\n' '_')"
        printf "    '%s.com-%s' = @{ platform = '%s'; base = '%s'; tokenEnv = '%s' }\n" \
            "${P_PLAT[i]}" "${P_PUSER[i]}" "${P_PLAT[i]}" "$_base" "$_tokvar"
    done
    echo '}'
    echo '$GitProfileRemotes = @('
    for i in "${!P_NAME[@]}"; do
        printf "    @{ url = 'git@%s.com-%s:%s/repo-de-prueba.git'; profile = '%s'; label = '%s (%s)' }\n" \
            "${P_PLAT[i]}" "${P_PUSER[i]}" "${P_PUSER[i]}" "${P_NAME[i]}" "${P_NAME[i]}" "${P_PLAT[i]}"
    done
    echo ')'
    printf '$GitContextDirs = @(%s)\n' "$(printf "'%s', " "${P_NAME[@]}" | sed 's/, $//')"
    echo '$GitIdentityFiles = @{'
    for i in "${!P_NAME[@]}"; do
        printf "    '%s' = '%s'\n" "${P_NAME[i]}" "${P_NAME[i]}"
    done
    echo '}'
} > "$VAULT_DIR/shell/git-identities.ps1"
ok "shell/git-identities.ps1"

# ==============================================================================
# CLAVES SSH (opcionales por perfil)
# ==============================================================================

_pending_age=()
_new_keys=()
_ssh_blocks=""
for i in "${!P_NAME[@]}"; do
    [[ "${P_KEY[i]}" == 1 ]] || continue
    _keyname="${P_PUSER[i]}-${P_PLAT[i]}"
    _alias="${P_PLAT[i]}.com-${P_PUSER[i]}"
    _keypath="$HOME/.ssh/$_keyname"

    mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
    if [[ -f "$_keypath" ]]; then
        warn "~/.ssh/$_keyname ya existe — la reuso (no genero una nueva)"
    else
        ssh-keygen -t ed25519 -f "$_keypath" -N '' -C "${P_NAME[i]}-$(hostname)" >/dev/null
        chmod 600 "$_keypath"; chmod 644 "$_keypath.pub"
        ok "clave generada: ~/.ssh/$_keyname"
    fi
    cp "$_keypath.pub" "$VAULT_DIR/ssh/keys/$_keyname.pub"
    _new_keys+=("$_keyname|${P_PLAT[i]}")

    # Privada cifrada al vault: solo si age esta disponible (pide passphrase).
    if command -v age &>/dev/null; then
        say "  ${C_DIM}Cifrando $_keyname con age (elegi UNA passphrase y usala para todas):${C_RESET}"
        if age -p -o "$VAULT_DIR/ssh/keys/$_keyname.age" "$_keypath" < /dev/tty; then
            ok "cifrada al vault: ssh/keys/$_keyname.age"
        else
            warn "no se pudo cifrar $_keyname — queda pendiente"
            _pending_age+=("$_keyname")
        fi
    else
        _pending_age+=("$_keyname")
    fi

    _ssh_blocks+="
# ${P_NAME[i]} (${P_PLAT[i]})
Host $_alias
    HostName ${P_PLAT[i]}.com
    User git
    IdentityFile ~/.ssh/$_keyname
    IdentitiesOnly yes
"
done

# ssh/config del vault: conserva el ~/.ssh/config previo del usuario (si habia)
# y suma los Host alias generados.
if [[ -n "$_ssh_blocks" ]]; then
    {
        if [[ -f "$HOME/.ssh/config" ]]; then
            cp "$HOME/.ssh/config" "$BACKUP_DIR/ssh-config.previo"
            cat "$HOME/.ssh/config"
            printf '\n# --- generado por git-profiles.sh ---\n'
        else
            printf '# ssh/config — generado por git-profiles.sh\n'
        fi
        printf '%s' "$_ssh_blocks"
    } > "$VAULT_DIR/ssh/config"
    ok "ssh/config (Host alias por perfil)"
fi

# ==============================================================================
# APLICAR EN ESTA MAQUINA (mismo criterio que el bootstrap)
# ==============================================================================

head_ "Aplicando en esta maquina"

_link() {  # _link <src> <dst> — symlink con backup del archivo real previo
    local src="$1" dst="$2"
    if [[ -f "$dst" && ! -L "$dst" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp "$dst" "$BACKUP_DIR/$(basename "$dst")"
    fi
    [[ -e "$dst" || -L "$dst" ]] && rm -f "$dst"
    ln -s "$src" "$dst"
}

_link "$VAULT_DIR/git/config" "$HOME/.gitconfig"
for i in "${!P_NAME[@]}"; do
    _link "$VAULT_DIR/git/config-${P_NAME[i]}" "$HOME/.gitconfig-${P_NAME[i]}"
done
ok "~/.gitconfig + perfiles enlazados al vault"

mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
cp "$VAULT_DIR/shell/git-identities.sh"  "${XDG_CONFIG_HOME:-$HOME/.config}/git-identities.sh"
cp "$VAULT_DIR/shell/git-identities.ps1" "${XDG_CONFIG_HOME:-$HOME/.config}/git-identities.ps1"
ok "identidades para los shells (git-identities.sh/.ps1)"

if [[ -f "$VAULT_DIR/ssh/config" ]]; then
    cp "$VAULT_DIR/ssh/config" "$HOME/.ssh/config" && chmod 600 "$HOME/.ssh/config"
    ok "~/.ssh/config aplicado"
fi

for _p in "${P_NAME[@]}"; do mkdir -p "$HOME/repositorios/$_p"; done
ok "carpetas de contexto: $(printf '~/repositorios/%s ' "${P_NAME[@]}")"

# ==============================================================================
# VAULT COMO REPO GIT (+ GITHUB OPCIONAL)
# ==============================================================================

head_ "Versionando el vault"
if [[ ! -d "$VAULT_DIR/.git" ]]; then
    git -C "$VAULT_DIR" init -b main >/dev/null
fi
git -C "$VAULT_DIR" add -A
if ! git -C "$VAULT_DIR" diff --cached --quiet; then
    git -C "$VAULT_DIR" -c user.name="${P_UNAME[0]}" -c user.email="${P_EMAIL[0]}" \
        commit -m "feat: perfiles de git generados por el asistente" >/dev/null
    ok "vault commiteado localmente"
fi

if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    _push="$(ask "  ¿Crear el repo PRIVADO dotfiles-vault en GitHub y pushear? [s/N] " "n")"
    case "$_push" in
        [sSyY]*)
            if gh repo create dotfiles-vault --private --source "$VAULT_DIR" --push; then
                ok "vault pusheado a GitHub (privado)"
            else
                warn "no se pudo crear/pushear (¿ya existe?) — hacelo a mano cuando quieras"
            fi ;;
        *) say "  ${C_DIM}Cuando quieras: gh repo create dotfiles-vault --private --source $VAULT_DIR --push${C_RESET}" ;;
    esac
else
    say "  ${C_DIM}Para respaldarlo en GitHub (privado) cuando tengas gh logueado:${C_RESET}"
    say "  ${C_DIM}  gh repo create dotfiles-vault --private --source $VAULT_DIR --push${C_RESET}"
fi

# ==============================================================================
# CIERRE
# ==============================================================================

head_ "Listo — proximos pasos"
say "  ${I_OK} La identidad de git ya es automatica por remoto; en repos nuevos usa"
say "     ginit <perfil> (o gclone -p <perfil> al clonar)."
_n=1
if [[ ${#_new_keys[@]} -gt 0 ]]; then
    say "  $_n. Carga tus claves PUBLICAS en cada plataforma:"
    for _k in "${_new_keys[@]}"; do
        _kn="${_k%%|*}"; _kp="${_k##*|}"
        if [[ "$_kp" == "github" ]]; then _url="https://github.com/settings/keys"; else _url="https://gitlab.com/-/user_settings/ssh_keys"; fi
        say "     ${C_DIM}$_url${C_RESET} ← ~/.ssh/$_kn.pub"
    done
    _n=$((_n + 1))
fi
if [[ ${#_pending_age[@]} -gt 0 ]]; then
    say "  $_n. Falto cifrar las privadas al vault (no habia 'age'). Instalalo y corre:"
    for _k in "${_pending_age[@]}"; do
        say "     ${C_DIM}age -p -o $VAULT_DIR/ssh/keys/$_k.age ~/.ssh/$_k${C_RESET}"
    done
    _n=$((_n + 1))
fi
say "  $_n. Backups de lo previo: ${C_DIM}$BACKUP_DIR${C_RESET}"
exec 3<&-
