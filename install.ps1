# ==============================================================================
#   install.ps1 — Instalacion/actualizacion de dotfiles (modelo 2 repos)
#   Autor: Kevin Charpentier
#
#   Arquitectura:
#     - dotfiles        (PUBLICO)  -> scripts + configs no sensibles  [este repo]
#     - dotfiles-vault  (PRIVADO)  -> ssh keys, identidades git, bookmarks
#
#   Instalacion inicial (git se auto-instala por winget si falta):
#     irm https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1 | iex
#
#   Actualizacion (con el repo ya clonado):
#     pwsh -File ~/.dotfiles/install.ps1
#
#   Opciones:
#     -WithAws        Incluir configuracion AWS
#     -DryRun         Simular sin ejecutar
#     -SkipPackages   Saltear instalacion de paquetes (winget)
#     -SkipVault      No clonar/aplicar el vault privado (solo lo publico)
#     -UpdateOnly     Solo actualizar repos, no ejecutar bootstrap
#     -VaultAuth X    Metodo de auth no interactivo: gh | ssh | skip
#     -Tools a,b,c    Instalar solo esas herramientas (se pasa al bootstrap)
#     -AllTools       Instalar todo el catalogo sin preguntar
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$WithAws,
    [switch]$DryRun,
    [switch]$SkipPackages,
    [switch]$SkipVault,
    [switch]$UpdateOnly,
    [ValidateSet('gh', 'ssh', 'skip', '')]
    [string]$VaultAuth = '',
    [string]$Tools = '',
    [switch]$AllTools
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ==============================================================================
# CONFIGURACION
# ==============================================================================

$GH_USER      = 'kevincharp'
$PUBLIC_HTTPS = "https://github.com/$GH_USER/dotfiles.git"
$PUBLIC_SSH   = "git@github.com:$GH_USER/dotfiles.git"
$VAULT_SSH    = "git@github.com:$GH_USER/dotfiles-vault.git"
# Host alias del ssh/config (engancha la clave kevincharp-github con
# IdentitiesOnly). Se usa como remote del vault tras clonar con gh, asi el
# proximo 'git pull' usa la clave SSH sin pedir credenciales (paridad install.sh).
$VAULT_SSH_ALIAS = "git@github.com-${GH_USER}:$GH_USER/dotfiles-vault.git"

$DOTFILES_DIR = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME '.dotfiles' }
$VAULT_DIR    = if ($env:VAULT_DIR)    { $env:VAULT_DIR }    else { Join-Path $HOME '.dotfiles-vault' }
$BRANCH       = if ($env:DOTFILES_BRANCH) { $env:DOTFILES_BRANCH } else { 'main' }

# ==============================================================================
# HELPERS
# ==============================================================================

# Forzar UTF-8 en la consola para que los iconos se vean (no rompe si ya lo esta)
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
# Iconos: UTF-8 si la consola lo soporta, si no ASCII
$script:ICONS = if ([Console]::OutputEncoding.CodePage -eq 65001) {
    @{ Section='▶'; Ok='✓'; Warn='⚠'; Err='✗'; Skip='⊘' }
} else {
    @{ Section='>'; Ok='[OK]'; Warn='[!]'; Err='[X]'; Skip='[-]' }
}

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    switch ($Level) {
        'SECTION' {
            $clean = ($Message -replace '^[\s=#-]+', '' -replace '[\s=#-]+$', '')
            if (-not $clean) { return }
            Write-Host ''
            Write-Host "$($script:ICONS.Section) $clean" -ForegroundColor Cyan
        }
        'OK'    { Write-Host "  $($script:ICONS.Ok) " -ForegroundColor Green      -NoNewline; Write-Host $Message }
        'WARN'  { Write-Host "  $($script:ICONS.Warn) " -ForegroundColor DarkYellow -NoNewline; Write-Host $Message }
        'ERROR' { Write-Host "  $($script:ICONS.Err) " -ForegroundColor Red        -NoNewline; Write-Host $Message }
        'SKIP'  { Write-Host "  $($script:ICONS.Skip) $Message" -ForegroundColor DarkGray }
        default { if (-not $Message) { Write-Host '' } else { Write-Host "    $Message" -ForegroundColor DarkGray } }
    }
}

function Test-CommandAvailable {
    param([string]$Cmd)
    return [bool](Get-Command $Cmd -ErrorAction SilentlyContinue)
}

# ==============================================================================
# 1. VERIFICAR GIT (bootstrap del bootstrap)
# ------------------------------------------------------------------------------
# Git hace falta ANTES que nada: este script clona el repo con 'git clone'. Como
# ya no lo instalamos manual (las opciones del wizard las cubre el .gitconfig del
# vault: core.editor=nvim, core.autocrlf=input), lo auto-instalamos por winget si
# falta. winget viene con Windows moderno, asi no queda ningun prerequisito manual.
# ==============================================================================

Write-Log 'Verificando requisitos...' 'SECTION'

if (-not (Test-CommandAvailable 'git')) {
    Write-Log 'Git no esta instalado - instalando via winget...' 'WARN'
    if (-not (Test-CommandAvailable 'winget')) {
        Write-Log 'winget tampoco esta disponible. Instala "App Installer" desde' 'ERROR'
        Write-Log 'la Microsoft Store (o Git manual: https://gitforwindows.org/) y reintenta.' 'ERROR'
        exit 1
    }
    winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
    # Refrescar el PATH del proceso actual: winget deja git en Program Files pero
    # esta sesion no lo ve hasta recargar el PATH de Machine + User.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (Test-CommandAvailable 'git')) {
        Write-Log 'Git se instalo pero no quedo en el PATH de esta sesion.' 'ERROR'
        Write-Log 'Cerra y reabri la terminal, y volve a correr install.ps1.' 'WARN'
        exit 1
    }
}
$gitVersion = (git --version) -replace 'git version ', ''
Write-Log "git $gitVersion OK" 'OK'

# ==============================================================================
# 2. CLONAR / ACTUALIZAR REPO PUBLICO
# ==============================================================================

Write-Log 'Repositorio publico (dotfiles)...' 'SECTION'

if (Test-Path (Join-Path $DOTFILES_DIR '.git')) {
    Write-Log "Ya existe en $DOTFILES_DIR - actualizando" 'OK'
    Push-Location $DOTFILES_DIR
    try {
        # Los cambios locales los maneja --autostash (stashea y REAPLICA al
        # terminar el rebase). No stashear a mano ademas: ese stash quedaba
        # huerfano y los cambios "desaparecian" del working tree sin aviso.
        git diff-index --quiet HEAD -- 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log 'Cambios locales detectados - autostash durante el pull' 'WARN'
        }
        git pull --rebase --autostash origin $BRANCH
        if ($LASTEXITCODE -ne 0) { Write-Log 'Error al actualizar publico' 'ERROR'; Pop-Location; exit 1 }
    } finally {
        Pop-Location
    }
} else {
    # Repo PUBLICO: HTTPS funciona sin credenciales. SSH si esta disponible.
    git clone $PUBLIC_SSH $DOTFILES_DIR 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Log 'Clonado publico via SSH' 'OK'
    } else {
        git clone $PUBLIC_HTTPS $DOTFILES_DIR
        if ($LASTEXITCODE -eq 0) {
            Write-Log 'Clonado publico via HTTPS' 'OK'
        } else {
            Write-Log 'Error al clonar el repo publico' 'ERROR'; exit 1
        }
    }
}

# ==============================================================================
# 3. CLONAR / ACTUALIZAR VAULT PRIVADO (interactivo)
# ==============================================================================

function Invoke-CloneVault {
    # Decide metodo de auth: parametro, o pregunta interactiva.
    $method = $VaultAuth
    if (-not $method) {
        Write-Log 'Vault privado: un 2do repo (dotfiles-vault) con TUS claves SSH e identidades git.' 'INFO'
        Write-Log 'Solo aplica si ya tenes uno propio (o forkeaste con el tuyo).' 'INFO'
        Write-Host '    1) Tengo mi vault - clonar con gh (login por navegador)'
        Write-Host '    2) Tengo mi vault - clonar por SSH (clave ya cargada)'
        Write-Host '    3) No tengo vault / saltar - instala igual todo lo publico  [default]'
        Write-Host '       (para crear el tuyo despues: docs/adaptalo.md)'
        $choice = Read-Host 'Opcion [1/2/3]'
        switch ($choice) {
            '1'     { $method = 'gh' }
            '2'     { $method = 'ssh' }
            default { $method = 'skip' }
        }
    }

    if ($method -eq 'skip') {
        Write-Log 'Sin vault: se instala todo lo publico igual (shells, herramientas, configs).' 'INFO'
        Write-Log 'Tu git y tu SSH quedan como estan. Para crear un vault propio: docs/adaptalo.md' 'INFO'
        Write-Log "Con vault listo, aplicalo con: pwsh -File $DOTFILES_DIR\install.ps1" 'INFO'
        return $false
    }

    if ($method -eq 'gh') {
        if (-not (Test-CommandAvailable 'gh')) {
            Write-Log 'gh no instalado - instalando via winget...' 'INFO'
            if (Test-CommandAvailable 'winget') {
                winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements | Out-Null
            } else {
                Write-Log 'winget no disponible - instala gh manualmente' 'ERROR'; return $false
            }
        }
        gh auth status 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log 'Autenticando con GitHub (segui las instrucciones)...' 'INFO'
            gh auth login
            if ($LASTEXITCODE -ne 0) { Write-Log 'Login con gh fallo' 'ERROR'; return $false }
        }
        gh repo clone "$GH_USER/dotfiles-vault" $VAULT_DIR
        if ($LASTEXITCODE -ne 0) {
            Write-Log 'Error clonando vault con gh' 'ERROR'
            Write-Log '  Si NO es tu vault (estas probando el repo de otra persona), es esperable:' 'INFO'
            Write-Log '  tu cuenta no tiene acceso. El resto se instala igual; ver docs/adaptalo.md' 'INFO'
            return $false
        }
        # gh clona via HTTPS: en la 2da corrida 'git pull' pediria credenciales
        # (GitHub ya no acepta password). Lo dejamos en el host alias SSH para
        # que las actualizaciones futuras usen la clave sin pedir nada. El
        # alias existe tras aplicar el ssh/config del vault (bootstrap).
        git -C $VAULT_DIR remote set-url origin $VAULT_SSH_ALIAS
        return $true
    }

    if ($method -eq 'ssh') {
        git clone $VAULT_SSH $VAULT_DIR
        if ($LASTEXITCODE -eq 0) { return $true }
        Write-Log 'Error clonando vault via SSH (tenes la clave cargada?)' 'ERROR'
        Write-Log '  Si NO es tu vault, es esperable. El resto se instala igual; ver docs/adaptalo.md' 'INFO'
        return $false
    }

    return $false
}

$VAULT_OK = $false
if ($SkipVault) {
    Write-Log '-SkipVault: omitiendo vault privado' 'WARN'
} elseif (Test-Path (Join-Path $VAULT_DIR '.git')) {
    # El vault ya esta clonado: su contenido ya esta disponible para el
    # bootstrap, haya o no conexion. Un pull fallido NO invalida el vault —
    # solo significa que se usa la version local (paridad con install.sh).
    Write-Log "Vault ya existe en $VAULT_DIR - actualizando" 'OK'
    $VAULT_OK = $true
    Push-Location $VAULT_DIR
    try {
        git pull --rebase --autostash origin $BRANCH
        if ($LASTEXITCODE -ne 0) { Write-Log 'No se pudo actualizar el vault - se usa la copia local' 'WARN' }
    } finally {
        Pop-Location
    }
} else {
    Write-Log 'Vault privado (dotfiles-vault)...' 'SECTION'
    if (Invoke-CloneVault) { $VAULT_OK = $true }
}

# ==============================================================================
# 4. EJECUTAR BOOTSTRAP
# ==============================================================================

if ($UpdateOnly) {
    Write-Log '-UpdateOnly: repos actualizados, no ejecuto bootstrap' 'OK'
    exit 0
}

Write-Log 'Ejecutando bootstrap...' 'SECTION'

$bootstrapScript = Join-Path $DOTFILES_DIR 'bootstrap.ps1'
if (-not (Test-Path $bootstrapScript)) {
    Write-Log "bootstrap.ps1 no encontrado en $DOTFILES_DIR" 'ERROR'; exit 1
}

# Mapear parametros de install.ps1 -> bootstrap.ps1
$bootstrapArgs = @{}
if ($WithAws)      { $bootstrapArgs['WithAws']    = $true }
if ($DryRun)       { $bootstrapArgs['DryRun']     = $true }
if ($SkipPackages) { $bootstrapArgs['SkipWinget'] = $true }
if ($AllTools)     { $bootstrapArgs['AllTools']   = $true }
if ($Tools)        { $bootstrapArgs['Tools']      = $Tools }

# Exporto VAULT_DIR para que bootstrap.ps1 encuentre lo sensible
$env:VAULT_DIR = $VAULT_DIR
& $bootstrapScript @bootstrapArgs

# ==============================================================================
# RESUMEN
# ==============================================================================

Write-Log 'Instalacion completada' 'SECTION'
Write-Log "Publico: $DOTFILES_DIR" 'OK'
if ($VAULT_OK) {
    Write-Log "Vault:   $VAULT_DIR" 'OK'
} else {
    Write-Log 'Vault:   sin aplicar - tu git/SSH quedan como estaban' 'WARN'
    Write-Log 'Para crear tu vault (identidades git + claves): docs/adaptalo.md' 'INFO'
    Write-Log "Con vault listo, aplicalo con: pwsh -File $DOTFILES_DIR\install.ps1" 'INFO'
}

Write-Log 'Proximos pasos' 'SECTION'
Write-Log '1. Abri una terminal nueva para recargar el profile' 'INFO'
Write-Log '2. Si clonaste por HTTPS, cambia a SSH para no pedir credenciales:' 'INFO'
Write-Log "   cd $DOTFILES_DIR; git remote set-url origin $PUBLIC_SSH" 'INFO'
