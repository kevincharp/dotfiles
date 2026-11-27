#!/bin/bash
# Frena todo `git push` salvo `git push [-u] <remoto> <tipo/rama-del-ticket>`, el merge y la edición
# de PR/repos con `gh`, y las librerías instaladas fuera del proyecto (npm/pnpm -g, pip fuera de un
# entorno virtual). Devuelve 2 para bloquear. Es una red de seguridad: no ve variables, alias ni
# scripts propios; el respaldo real es la protección de rama en GitHub.
set -f
input=$(cat)
quoted='QQQ__QQQ'
if command -v jq >/dev/null 2>&1; then
    raw_command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    # El texto entre comillas se reemplaza por un marcador: un mensaje de commit que nombra un comando
    # no lo ejecuta, pero la posición del argumento sigue contando. Después, cada línea es un comando.
    command_line=$(printf '%s' "$raw_command" | sed -zE "s/\"[^\"]*\"/$quoted/g; s/'[^']*'/$quoted/g" |
        sed -E 's/(^|[[:space:]])#.*$//' | tr '\n' ';')
    raw_command=$(printf '%s' "$raw_command" | tr '\n' ' ')
else
    # Sin jq se revisa el JSON crudo: puede bloquear de más, nunca de menos.
    raw_command=$input
    command_line=$input
fi
# Tabs, paréntesis y llaves no esconden un comando; las redirecciones no son argumentos.
command_line=$(printf '%s' "$command_line" | tr '\t(){}' '     ' |
    sed -E 's/[0-9]*>>?[[:space:]]*(&[0-9]*|[^[:space:];|&]*)//g')

matches() { printf '%s' "$command_line" | grep -Eq "$1"; }
matches_i() { printf '%s' "$command_line" | grep -Eiq "$1"; }
raw_matches() { printf '%s' "$raw_command" | grep -Eq "$1"; }
block() { echo "Bloqueado: $1" >&2; exit 2; }
start='(^|[^[:alnum:]_.-])'
sp='[[:space:]]'
branch_re='^(feat|fix|docs|chore|refactor|test|perf|build|ci|style|revert)/[A-Za-z0-9._/-]+$'

# Un verbo de git o gh entre comillas, o una palabra armada con comillas, esconde lo que se ejecuta.
matches "${start}(git|gh)${sp}+$quoted|${start}git${sp}+-c${sp}*$quoted|${start}gh${sp}+(pr|repo|release|secret|ruleset|alias|extension)${sp}+$quoted|${start}(git|gh)${sp}[^|;&]*([[:alnum:]]$quoted|${quoted}[[:alnum:]])|${quoted}${sp}+(push|pr${sp}+merge)" &&
    block "no escribas el comando de git o gh entre comillas ni partido con comillas: escribilo directo."

# Cada `git push` debe ser: [-u|--set-upstream] <remoto> <tipo/descripcion>. Nada de main, HEAD, tags,
# refspecs, variables, marcadores de texto citado ni flags de fuerza o borrado.
while IFS= read -r full; do
    [[ "$full" =~ ${sp}(stash|subtree)${sp}+push ]] && continue
    push_args=${full#*[[:space:]]push}
    positional=()
    for word in $push_args; do
        case "$word" in
            -u|--set-upstream) ;;
            -*) block "solo se permite git push -u <remoto> <rama-del-ticket>: sin el flag $word." ;;
            *) positional+=("$word") ;;
        esac
    done
    [ "${#positional[@]}" -eq 2 ] || block "indicá remoto y rama: git push -u origin <tipo/rama-del-ticket>."
    remote=${positional[0]}
    branch=${positional[1]}
    [[ "$remote" =~ ^[A-Za-z0-9._-]+$ && "$remote" != . ]] ||
        block "el remoto tiene que ser un nombre (origin), no una URL ni una variable."
    [[ "$branch" =~ $branch_re && "$branch" != *..* && "$branch" != *//* && "$branch" != */ && "$branch" != *.lock ]] ||
        block "la rama tiene que ser tipo/descripcion (feat/, fix/, docs/…): el push de main, tags, HEAD o variables lo hace el usuario."
done < <(printf '%s' "$command_line" |
    grep -oE "${start}git(${sp}[^|;&]*)?${sp}push(${sp}[^|;&]*|\$|[|;&].*)")

# Lo que cambia el destino, la configuración o los alias del push.
matches "${start}git${sp}([^|;&]*${sp})?remote${sp}+(add|set-url|rename|remove|rm|set-head|set-branches|prune)" &&
    block "cambiar remotos lo hace el usuario."
if matches_i "${start}git${sp}([^|;&]*${sp})?config${sp}[^|;&]*(alias|remote[.]|url[.]|core[.]sshcommand|push[.])" &&
    ! matches "${start}git${sp}([^|;&]*${sp})?config${sp}+([^|;&]*${sp})?(--get|--get-all|--get-regexp|--list|-l|--show-origin)"; then
    block "no cambies la configuración de remotos, alias o push de git."
fi
matches "${start}git${sp}([^|;&]*${sp})?send-pack" && block "send-pack lo hace el usuario."
matches_i "${start}git${sp}+(-c${sp}*|--config-env=)(alias|remote|url|core[.]sshcommand|push)|GIT_CONFIG_(COUNT|KEY|PARAMETERS)" &&
    block "no pases configuración de alias, remotos o push por -c ni por variables de git."

# gh: el agente abre PRs, pero no los mergea ni los aprueba ni toca el repo.
matches "${start}gh${sp}([^|;&]*${sp})?pr${sp}+(merge|review)" &&
    block "el merge y la aprobación de un PR los hace el usuario desde GitHub."
matches "${start}gh${sp}([^|;&]*${sp})?(repo${sp}+(edit|delete|rename|archive)|release${sp}+(create|delete|edit)|secret|ruleset|alias|extension)" &&
    block "ese cambio en GitHub lo hace el usuario."
if matches "${start}gh${sp}([^|;&]*${sp})?api${sp}"; then
    # Leer esas rutas (GET) está bien; escribirlas (-X, o campos -f/-F que vuelven POST) no.
    if raw_matches '(-X|--method)[[:space:]=]*(PUT|PATCH|DELETE|POST)|[[:space:]](-f|-F|--field|--raw-field|--input)[[:space:]=]' &&
        raw_matches '/["'"'"']?(merge|reviews|contents|collaborators|keys|dispatches|rulesets|protection|hooks)|git/(refs|commits)|/branches/|/actions/secrets'; then
        block "gh api que escribe sobre merges, refs, ramas, rulesets, secretos, revisiones o contenido lo hace el usuario."
    fi
    raw_matches "mutation[^|;&]*(mergePullRequest|enablePullRequestAutoMerge|addPullRequestReview|deleteRef|updateRef|createRef|updateBranchProtectionRule|deleteBranchProtectionRule|deleteRepository|updateRepository|closePullRequest|createCommitOnBranch)" &&
        block "esa mutación de GitHub la hace el usuario."
    raw_matches "(-X|--method)[[:space:]=]*(PATCH|DELETE)" && raw_matches 'repos/[^/ ]+/[^/ ]+([[:space:]]|$)' &&
        block "modificar o borrar el repo con gh api lo hace el usuario."
fi
raw_matches 'api[.]github[.]com' && raw_matches "(curl|wget)" &&
    raw_matches "(-X|--request|--method)[[:space:]=]*(PUT|PATCH|DELETE|POST)" &&
    block "no llames a la API de GitHub con curl para escribir."

# Envolver el comando en sh -c, eval o xargs esconde el texto: se pide escribirlo directo.
if raw_matches "(^|[^[:alnum:]_])(((ba|z|da)?sh${sp}+-[a-z]*c)|eval|xargs|[|]${sp}*(ba|z|da)?sh)([[:space:]]|\$)" &&
    raw_matches "(^|[^[:alnum:]_])(git${sp}([^|;&]*${sp})?push|gh${sp}([^|;&]*${sp})?pr${sp}+merge)"; then
    block "no envuelvas un push ni un merge en sh -c, eval o xargs: escribilo directo."
fi

# Un PR o un issue en un repo público no lleva claves.
if raw_matches "gh${sp}([^|;&]*${sp})?(pr|issue)${sp}+(create|comment|edit)" &&
    raw_matches 'ghp_[A-Za-z0-9]{20,}|github_pat_|gho_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|AGE-SECRET-KEY-|age1[a-z0-9]{50,}'; then
    block "el texto del PR o del issue parece traer una clave."
fi

if matches "${start}(npm|pnpm|bun)( [^|;&]*)? (-g|--global)([ =]|\$)" &&
    matches ' (install|i|add|update|upgrade)( |$)'; then
    block "no instales librerías globales; declarálas en el package.json del proyecto."
fi
matches "${start}yarn( [^|;&]*)? global add" &&
    block "no instales librerías globales; declarálas en el package.json del proyecto."

# Un pip ya activado en otro comando no se ve: hace falta la ruta del entorno en el mismo comando.
if matches "${start}(pip3?|python3? -m pip3?) install( |\$)" && [ -z "${VIRTUAL_ENV:-}" ] &&
    ! matches "venv[/\\\\](bin|Scripts)|activate|${start}uv( |\$)"; then
    block "pip fuera de un entorno virtual; usá python3 -m venv .venv y .venv/bin/pip install."
fi
exit 0
