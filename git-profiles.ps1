# ==============================================================================
#   git-profiles.ps1 — Asistente de perfiles de git + vault propio (Windows)
#   Uso:   pwsh -File ~/.dotfiles/git-profiles.ps1
#
#   Espejo de git-profiles.sh: para el usuario SIN vault, pregunta por consola
#   sus contextos (personal, trabajo, ...) y genera + aplica la misma
#   estructura que un vault hecho a mano (ver docs/adaptalo.md):
#     - ~/.gitconfig con identidad automatica por remoto (useConfigOnly+includeIf)
#     - ~/.gitconfig-<perfil> por contexto
#     - git-identities.sh / .ps1 (los consumen ginit/gclone y los tests)
#     - claves SSH por perfil (opcional) + Host alias en ssh/config
#     - carpetas ~/repositorios/<contexto> (GitContextDirs)
#   Al final ofrece crear el repo privado dotfiles-vault en GitHub (via gh).
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$VAULT_DIR  = if ($env:VAULT_DIR) { $env:VAULT_DIR } else { Join-Path $HOME '.dotfiles-vault' }
$BACKUP_DIR = Join-Path $HOME ".local\backups\git-profiles\$(Get-Date -Format 'yyyyMMdd-HHmmss')"

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Write-Head($t) { Write-Host ''; Write-Host "▶ $t" -ForegroundColor Cyan }
function Write-Ok($t)   { Write-Host "  ✓ $t" -ForegroundColor Green }
function Write-Warn2($t){ Write-Host "  ⚠ $t" -ForegroundColor DarkYellow }
function Write-Dim($t)  { Write-Host "  $t" -ForegroundColor DarkGray }

function Ask($prompt, $def = '') {
    $r = Read-Host $prompt
    if ([string]::IsNullOrWhiteSpace($r)) { return $def } else { return $r.Trim() }
}
function Ask-Req($prompt) {
    while ($true) {
        $r = Ask $prompt
        if ($r) { return $r }
        Write-Warn2 'Este dato es obligatorio.'
    }
}

# ==============================================================================
# BIENVENIDA + CHEQUEO
# ==============================================================================

Write-Head 'Asistente de perfiles de git'
Write-Host '  Configuremos tus identidades: por cada contexto (personal, trabajo, ...)'
Write-Host '  un perfil con su nombre/email, y git elige solo cual usar segun el remoto.'
Write-Dim  "Todo queda en un vault local ($VAULT_DIR) listo para versionar."

if (Test-Path (Join-Path $VAULT_DIR 'git\config')) {
    Write-Warn2 "Ya existe un vault con configuracion git en $VAULT_DIR"
    $ans = Ask '  ¿Regenerar la config git del vault desde cero? [s/N]' 'n'
    if ($ans -notmatch '^[sSyY]') { Write-Host '  Sin cambios. Chau.'; exit 0 }
}

# ==============================================================================
# RECOLECCION DE PERFILES
# ==============================================================================

$profiles = @()
$defPerfil = 'personal'
$prevName  = ''
while ($true) {
    Write-Head "Perfil $($profiles.Count + 1)"

    while ($true) {
        $perfil = Ask "  Nombre del perfil/contexto [$defPerfil]" $defPerfil
        if (-not ($profiles | Where-Object { $_.Perfil -eq $perfil })) { break }
        Write-Warn2 "Ya cargaste un perfil '$perfil' — elegi otro nombre."
    }

    $uname = if ($prevName) { Ask "  Tu nombre para los commits [$prevName]" $prevName }
             else           { Ask-Req '  Tu nombre para los commits' }
    $email = Ask-Req '  Email para este perfil'

    $plat = Ask '  Plataforma [github/gitlab] (github)' 'github'
    $plat = if ($plat -match '^git?lab$|^gitlab$') { 'gitlab' } else { 'github' }
    $puser = Ask-Req "  Tu usuario en $plat"

    $key = Ask '  ¿Generar una clave SSH para este perfil? [S/n]' 's'
    $key = ($key -notmatch '^[nN]')

    $profiles += [pscustomobject]@{
        Perfil = $perfil; Name = $uname; Email = $email
        Plat = $plat; PUser = $puser; Key = $key
        Alias = "$plat.com-$puser"; KeyName = "$puser-$plat"
    }
    $prevName  = $uname
    $defPerfil = 'trabajo'

    $more = Ask '  ¿Agregar otro perfil? [s/N]' 'n'
    if ($more -notmatch '^[sSyY]') { break }
}

# ==============================================================================
# RESUMEN + CONFIRMACION
# ==============================================================================

Write-Head 'Resumen'
foreach ($p in $profiles) {
    $keytxt = if ($p.Key) { 'clave SSH nueva' } else { 'sin clave SSH' }
    Write-Host "  $($p.Perfil)  $($p.Name) <$($p.Email)>  " -NoNewline -ForegroundColor Green
    Write-Host "$($p.Alias) · $keytxt" -ForegroundColor DarkGray
}
Write-Dim "Se genera el vault en $VAULT_DIR y se aplica en esta maquina"
Write-Dim "(lo que ya tengas se respalda en $BACKUP_DIR)."
$go = Ask '  ¿Continuar? [S/n]' 's'
if ($go -match '^[nN]') { Write-Host '  Cancelado. No se toco nada.'; exit 0 }

# ==============================================================================
# GENERACION DEL VAULT
# ==============================================================================

Write-Head 'Generando el vault'
foreach ($d in @('git', 'shell', 'ssh\keys')) {
    New-Item -ItemType Directory -Path (Join-Path $VAULT_DIR $d) -Force | Out-Null
}
New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null

# --- git/config-<perfil> ---
foreach ($p in $profiles) {
    @"
# Identidad del perfil '$($p.Perfil)' — generado por git-profiles.ps1
[user]
	name = $($p.Name)
	email = $($p.Email)
"@ | Set-Content -Path (Join-Path $VAULT_DIR "git\config-$($p.Perfil)") -Encoding UTF8
}
Write-Ok "git/config-<perfil> ($($profiles.Count))"

# --- git/config (identidad automatica por remoto) ---
# OJO con los globs de hasconfig (wildmatch): '*' NO cruza '/' y '**' solo es
# especial delimitado por '/'. Por eso 'user/repo' se matchea con :*/* (y
# :**/** para namespaces anidados), no con ':**'.
$cfg = @"
# ~/.gitconfig — generado por git-profiles.ps1 (dotfiles)
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
"@
foreach ($p in $profiles) {
    $cfg += @"


# perfil: $($p.Perfil)
[includeIf "hasconfig:remote.*.url:git@$($p.Alias):*/*"]
	path = ~/.gitconfig-$($p.Perfil)
[includeIf "hasconfig:remote.*.url:git@$($p.Alias):**/**"]
	path = ~/.gitconfig-$($p.Perfil)
[includeIf "hasconfig:remote.*.url:git@$($p.Plat).com:$($p.PUser)/**"]
	path = ~/.gitconfig-$($p.Perfil)
[includeIf "hasconfig:remote.*.url:https://$($p.Plat).com/$($p.PUser)/**"]
	path = ~/.gitconfig-$($p.Perfil)
"@
}
$cfg | Set-Content -Path (Join-Path $VAULT_DIR 'git\config') -Encoding UTF8
Write-Ok 'git/config (useConfigOnly + includeIf por remoto)'

# --- shell/git-identities.sh (bash/zsh) y .ps1 (pwsh) ---
$sh = [System.Collections.Generic.List[string]]::new()
$sh.Add('# Identidades git — generado por git-profiles.ps1')
$sh.Add('# Lo consumen gclone/gset-profile/ginit (bash/zsh) y test-bootstrap.sh.')
foreach ($p in $profiles) {
    $sh.Add("GIT_IDENTITIES_NAME[$($p.Perfil)]=`"$($p.Name)`"")
    $sh.Add("GIT_IDENTITIES_EMAIL[$($p.Perfil)]=`"$($p.Email)`"")
}
foreach ($p in ($profiles | Where-Object Key)) {
    $sh.Add("GIT_SSH_ALIASES[$($p.Alias)]=`"$($p.KeyName)`"")
}
$sh.Add('GIT_PROFILE_REMOTES=(')
foreach ($p in $profiles) {
    $sh.Add("    `"git@$($p.Alias):$($p.PUser)/repo-de-prueba.git|$($p.Perfil)|$($p.Perfil) ($($p.Plat))`"")
}
$sh.Add(')')
$sh.Add("GIT_CONTEXT_DIRS=($(($profiles | ForEach-Object Perfil) -join ' '))")
foreach ($p in $profiles) {
    $sh.Add("GIT_IDENTITY_FILES[$($p.Perfil)]=`"$($p.Perfil)`"")
}
($sh -join "`n") + "`n" | Set-Content -Path (Join-Path $VAULT_DIR 'shell\git-identities.sh') -Encoding UTF8 -NoNewline
Write-Ok 'shell/git-identities.sh'

$ps = [System.Collections.Generic.List[string]]::new()
$ps.Add('# Identidades git — generado por git-profiles.ps1')
$ps.Add('# Lo consumen gclone/gset-profile/ginit (pwsh) y test-bootstrap.ps1.')
$ps.Add('$GitIdentities = @{')
foreach ($p in $profiles) {
    $ps.Add("    '$($p.Perfil)' = @{ name = '$($p.Name -replace "'","''")'; email = '$($p.Email -replace "'","''")' }")
}
$ps.Add('}')
$ps.Add('$GitSshAliases = @{')
foreach ($p in ($profiles | Where-Object Key)) {
    $ps.Add("    '$($p.Alias)' = '$($p.KeyName)'")
}
$ps.Add('}')
$ps.Add('$GitHostAliases = @{')
foreach ($p in $profiles) {
    $base = if ($p.Plat -eq 'github') { 'https://api.github.com' } else { 'https://gitlab.com' }
    $tok  = ("$($p.Plat)_TOKEN_$($p.PUser)".ToUpper() -replace '[^A-Z0-9_]', '_')
    $ps.Add("    '$($p.Alias)' = @{ platform = '$($p.Plat)'; base = '$base'; tokenEnv = '$tok' }")
}
$ps.Add('}')
$ps.Add('$GitProfileRemotes = @(')
foreach ($p in $profiles) {
    $ps.Add("    @{ url = 'git@$($p.Alias):$($p.PUser)/repo-de-prueba.git'; profile = '$($p.Perfil)'; label = '$($p.Perfil) ($($p.Plat))' }")
}
$ps.Add(')')
$ps.Add("`$GitContextDirs = @($(($profiles | ForEach-Object { "'$($_.Perfil)'" }) -join ', '))")
$ps.Add('$GitIdentityFiles = @{')
foreach ($p in $profiles) {
    $ps.Add("    '$($p.Perfil)' = '$($p.Perfil)'")
}
$ps.Add('}')
($ps -join "`n") + "`n" | Set-Content -Path (Join-Path $VAULT_DIR 'shell\git-identities.ps1') -Encoding UTF8 -NoNewline
Write-Ok 'shell/git-identities.ps1'

# ==============================================================================
# CLAVES SSH (opcionales por perfil)
# ==============================================================================

$pendingAge = @()
$newKeys    = @()
$sshBlocks  = ''
$sshDir = Join-Path $HOME '.ssh'
foreach ($p in ($profiles | Where-Object Key)) {
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }
    $keyPath = Join-Path $sshDir $p.KeyName
    if (Test-Path $keyPath) {
        Write-Warn2 "~/.ssh/$($p.KeyName) ya existe — la reuso (no genero una nueva)"
    } else {
        ssh-keygen -t ed25519 -f $keyPath -N '""' -C "$($p.Perfil)-$env:COMPUTERNAME" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Fallo ssh-keygen para $($p.KeyName)" }
        Write-Ok "clave generada: ~/.ssh/$($p.KeyName)"
    }
    Copy-Item "$keyPath.pub" (Join-Path $VAULT_DIR "ssh\keys\$($p.KeyName).pub") -Force
    $newKeys += $p

    if (Get-Command age -ErrorAction SilentlyContinue) {
        Write-Dim "Cifrando $($p.KeyName) con age (elegi UNA passphrase y usala para todas):"
        age -p -o (Join-Path $VAULT_DIR "ssh\keys\$($p.KeyName).age") $keyPath
        if ($LASTEXITCODE -eq 0) { Write-Ok "cifrada al vault: ssh/keys/$($p.KeyName).age" }
        else { Write-Warn2 "no se pudo cifrar $($p.KeyName) — queda pendiente"; $pendingAge += $p.KeyName }
    } else {
        $pendingAge += $p.KeyName
    }

    $sshBlocks += "`n# $($p.Perfil) ($($p.Plat))`nHost $($p.Alias)`n    HostName $($p.Plat).com`n    User git`n    IdentityFile ~/.ssh/$($p.KeyName)`n    IdentitiesOnly yes`n"
}

if ($sshBlocks) {
    $sshCfgVault = Join-Path $VAULT_DIR 'ssh\config'
    $prevCfg = Join-Path $sshDir 'config'
    $content = if (Test-Path $prevCfg) {
        Copy-Item $prevCfg (Join-Path $BACKUP_DIR 'ssh-config.previo') -Force
        (Get-Content -Raw $prevCfg) + "`n# --- generado por git-profiles.ps1 ---`n" + $sshBlocks
    } else {
        "# ssh/config — generado por git-profiles.ps1`n" + $sshBlocks
    }
    $content | Set-Content -Path $sshCfgVault -Encoding UTF8 -NoNewline
    Write-Ok 'ssh/config (Host alias por perfil)'
}

# ==============================================================================
# APLICAR EN ESTA MAQUINA (mismo criterio que el bootstrap)
# ==============================================================================

Write-Head 'Aplicando en esta maquina'

function New-LinkOrCopy($src, $dst) {
    # symlink con backup del archivo real previo; si el symlink falla (sin
    # Modo de desarrollador), cae a copia con aviso.
    if ((Test-Path $dst) -and -not (Get-Item $dst -Force).LinkType) {
        Copy-Item $dst (Join-Path $BACKUP_DIR (Split-Path $dst -Leaf)) -Force
    }
    if (Test-Path $dst) { Remove-Item $dst -Force }
    try {
        New-Item -ItemType SymbolicLink -Path $dst -Target $src -ErrorAction Stop | Out-Null
    } catch {
        Copy-Item $src $dst -Force
        Write-Warn2 "sin permiso para symlinks (Modo de desarrollador) — $dst quedo como copia"
    }
}

New-LinkOrCopy (Join-Path $VAULT_DIR 'git\config') (Join-Path $HOME '.gitconfig')
foreach ($p in $profiles) {
    New-LinkOrCopy (Join-Path $VAULT_DIR "git\config-$($p.Perfil)") (Join-Path $HOME ".gitconfig-$($p.Perfil)")
}
Write-Ok '~/.gitconfig + perfiles enlazados al vault'

$cfgDir = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null
Copy-Item (Join-Path $VAULT_DIR 'shell\git-identities.sh')  (Join-Path $cfgDir 'git-identities.sh')  -Force
Copy-Item (Join-Path $VAULT_DIR 'shell\git-identities.ps1') (Join-Path $cfgDir 'git-identities.ps1') -Force
Write-Ok 'identidades para los shells (git-identities.sh/.ps1)'

if (Test-Path (Join-Path $VAULT_DIR 'ssh\config')) {
    Copy-Item (Join-Path $VAULT_DIR 'ssh\config') (Join-Path $sshDir 'config') -Force
    Write-Ok '~/.ssh/config aplicado'
}

foreach ($p in $profiles) {
    New-Item -ItemType Directory -Path (Join-Path $HOME "repositorios\$($p.Perfil)") -Force | Out-Null
}
Write-Ok ("carpetas de contexto: " + (($profiles | ForEach-Object { "~/repositorios/$($_.Perfil)" }) -join ' '))

# ==============================================================================
# VAULT COMO REPO GIT (+ GITHUB OPCIONAL)
# ==============================================================================

Write-Head 'Versionando el vault'
if (-not (Test-Path (Join-Path $VAULT_DIR '.git'))) {
    git -C $VAULT_DIR init -b main | Out-Null
}
git -C $VAULT_DIR add -A
git -C $VAULT_DIR diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git -C $VAULT_DIR -c user.name="$($profiles[0].Name)" -c user.email="$($profiles[0].Email)" `
        commit -m 'feat: perfiles de git generados por el asistente' | Out-Null
    Write-Ok 'vault commiteado localmente'
}

$ghOk = $false
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh auth status 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $ghOk = $true }
}
if ($ghOk) {
    $push = Ask '  ¿Crear el repo PRIVADO dotfiles-vault en GitHub y pushear? [s/N]' 'n'
    if ($push -match '^[sSyY]') {
        gh repo create dotfiles-vault --private --source $VAULT_DIR --push
        if ($LASTEXITCODE -eq 0) { Write-Ok 'vault pusheado a GitHub (privado)' }
        else { Write-Warn2 'no se pudo crear/pushear (¿ya existe?) — hacelo a mano cuando quieras' }
    } else {
        Write-Dim "Cuando quieras: gh repo create dotfiles-vault --private --source $VAULT_DIR --push"
    }
} else {
    Write-Dim 'Para respaldarlo en GitHub (privado) cuando tengas gh logueado:'
    Write-Dim "  gh repo create dotfiles-vault --private --source $VAULT_DIR --push"
}

# ==============================================================================
# CIERRE
# ==============================================================================

Write-Head 'Listo — proximos pasos'
Write-Host '  ✓ La identidad de git ya es automatica por remoto; en repos nuevos usa'
Write-Host '     ginit <perfil> (o gclone -perfil <perfil> al clonar).'
$n = 1
if ($newKeys.Count -gt 0) {
    Write-Host "  $n. Carga tus claves PUBLICAS en cada plataforma:"
    foreach ($p in $newKeys) {
        $url = if ($p.Plat -eq 'github') { 'https://github.com/settings/keys' } else { 'https://gitlab.com/-/user_settings/ssh_keys' }
        Write-Dim "$url ← ~/.ssh/$($p.KeyName).pub"
    }
    $n++
}
if ($pendingAge.Count -gt 0) {
    Write-Host "  $n. Falto cifrar las privadas al vault (no habia 'age'). Instalalo y corre:"
    foreach ($k in $pendingAge) {
        Write-Dim "age -p -o $VAULT_DIR\ssh\keys\$k.age $HOME\.ssh\$k"
    }
    $n++
}
Write-Host "  $n. Backups de lo previo: " -NoNewline; Write-Host $BACKUP_DIR -ForegroundColor DarkGray
