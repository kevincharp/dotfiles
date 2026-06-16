# ==============================================================================
#   install.ps1 — Instalacion/actualizacion de dotfiles (modelo 2 repos)
#   Autor: Kevin Charpentier
#
#   Arquitectura:
#     - dotfiles        (PUBLICO)  -> scripts + configs no sensibles  [este repo]
#     - dotfiles-vault  (PRIVADO)  -> ssh keys, identidades git, bookmarks
#
#   Instalacion inicial (requiere Git for Windows ya instalado):
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
    [ValidateSet('gh', 'ssh', 'skip')]
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
# 1. VERIFICAR GIT
# ------------------------------------------------------------------------------
# En Windows Git se instala manualmente (Git for Windows) adrede: su instalador
# configura line endings, editor y SSH. No lo auto-instalamos via winget.
# ==============================================================================

Write-Log 'Verificando requisitos...' 'SECTION'

if (-not (Test-CommandAvailable 'git')) {
    Write-Log 'Git no esta instalado.' 'ERROR'
    Write-Log 'En Windows, instala Git for Windows manualmente primero:' 'WARN'
    Write-Log '  https://gitforwindows.org/' 'WARN'
    Write-Log '  (configura line endings, editor y SSH durante la instalacion)' 'WARN'
    exit 1
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
        git diff-index --quiet HEAD -- 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log 'Cambios locales detectados - stash automatico' 'WARN'
            git stash push -m "auto-stash install $(Get-Date -Format 'yyyyMMdd-HHmmss')" | Out-Null
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
        Write-Log 'El vault privado (dotfiles-vault) contiene tus claves SSH e identidades.' 'INFO'
        Write-Log 'Como queres autenticarte para clonarlo?' 'INFO'
        Write-Host '    1) gh (GitHub CLI, login por navegador)  [recomendado]'
        Write-Host '    2) SSH (si ya tenes una clave cargada)'
        Write-Host '    3) Saltar por ahora (instalo solo lo publico)'
        $choice = Read-Host 'Opcion [1/2/3]'
        switch ($choice) {
            '1'     { $method = 'gh' }
            '2'     { $method = 'ssh' }
            default { $method = 'skip' }
        }
    }

    if ($method -eq 'skip') {
        Write-Log "Vault saltado. Lo podes aplicar luego con: pwsh -File $DOTFILES_DIR\install.ps1" 'WARN'
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
        if ($LASTEXITCODE -eq 0) { return $true }
        Write-Log 'Error clonando vault con gh' 'ERROR'; return $false
    }

    if ($method -eq 'ssh') {
        git clone $VAULT_SSH $VAULT_DIR
        if ($LASTEXITCODE -eq 0) { return $true }
        Write-Log 'Error clonando vault via SSH (tenes la clave cargada?)' 'ERROR'; return $false
    }

    return $false
}

$VAULT_OK = $false
if ($SkipVault) {
    Write-Log '-SkipVault: omitiendo vault privado' 'WARN'
} elseif (Test-Path (Join-Path $VAULT_DIR '.git')) {
    Write-Log "Vault ya existe en $VAULT_DIR - actualizando" 'OK'
    Push-Location $VAULT_DIR
    try {
        git pull --rebase --autostash origin $BRANCH
        if ($LASTEXITCODE -eq 0) { $VAULT_OK = $true } else { Write-Log 'No se pudo actualizar el vault' 'WARN' }
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
    Write-Log 'Vault:   NO aplicado - claves SSH e identidades git pendientes' 'WARN'
    Write-Log "Para aplicarlo luego: pwsh -File $DOTFILES_DIR\install.ps1" 'INFO'
}

Write-Log 'Proximos pasos' 'SECTION'
Write-Log '1. Abri una terminal nueva para recargar el profile' 'INFO'
Write-Log '2. Si clonaste por HTTPS, cambia a SSH para no pedir credenciales:' 'INFO'
Write-Log "   cd $DOTFILES_DIR; git remote set-url origin $PUBLIC_SSH" 'INFO'
