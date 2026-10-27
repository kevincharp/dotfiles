# ==============================================================================
#   uninstall.ps1 — Desinstalar dotfiles (Windows)
#   Autor: Kevin Charpentier
#   Uso:   pwsh -File uninstall.ps1 [-RemovePackages] [-DryRun] [-Force]
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$RemovePackages,   # desinstalar paquetes instalados por bootstrap (winget)
    [switch]$DryRun,           # mostrar que haria sin ejecutar
    [switch]$Force             # no pedir confirmacion (peligroso)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ==============================================================================
# CONFIGURACION
# ==============================================================================

$DOTFILES_DIR = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME '.dotfiles' }
$VAULT_DIR    = if ($env:VAULT_DIR)    { $env:VAULT_DIR }    else { Join-Path $HOME '.dotfiles-vault' }

# Symlinks/archivos creados por el bootstrap (espejo de $DOTFILES en bootstrap.ps1)
$DOTFILES_TARGETS = @(
    "$HOME\.config\powershell\profile.ps1"
    "$HOME\.bashrc"
    "$HOME\.bash_profile"
    "$HOME\.config\git\ignore"
    "$HOME\.gitconfig"
    "$HOME\.config\git-identities.ps1"
    "$HOME\.ssh\config"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$HOME\.editorconfig"
    "$HOME\.claude\settings.json"
    # settings.local.json NO va aca a proposito: bootstrap.ps1 nunca lo crea ni
    # lo symlinkea (es per-maquina, el usuario lo edita a mano). Si estuviera
    # en esta lista, el loop de abajo lo borraria como "archivo real" aunque
    # nunca lo haya instalado este repo.
    "$HOME\.claude\CLAUDE.md"
    "$HOME\.claude\agents"
    "$HOME\.codex\AGENTS.md"
    "$HOME\.config\opencode\AGENTS.md"
    "$env:APPDATA\yazi\config\yazi.toml"
    "$env:APPDATA\FlowLauncher\Settings\Settings.json"
    # Mismo condicional que bootstrap.ps1: si XDG_CONFIG_HOME esta seteada, el
    # symlink real quedo ahi, no en LOCALAPPDATA. Sin este if, esa maquina se
    # queda con el symlink de nvim huerfano tras desinstalar.
    $(if ($env:XDG_CONFIG_HOME) { Join-Path $env:XDG_CONFIG_HOME 'nvim' } else { Join-Path $env:LOCALAPPDATA 'nvim' })
    "$HOME\.local\bin\lazyssh.exe"
    "$HOME\.local\bin\lazysql.exe"
)

# Identidades git (~/.gitconfig-<sufijo>): los sufijos salen del vault si define
# $GitIdentityFiles, y SE SUMAN a los historicos en vez de reemplazarlos —
# desinstalar con el vault ya borrado debe limpiar igual los symlinks viejos.
$idSuffixes = @('personal', 'work', 'cei_walle')
$giVault = Join-Path $VAULT_DIR 'shell\git-identities.ps1'
if (Test-Path $giVault) {
    $GitIdentityFiles = $null
    . $giVault
    if ($GitIdentityFiles) { $idSuffixes += @($GitIdentityFiles.Keys) }
}
foreach ($s in ($idSuffixes | Sort-Object -Unique)) {
    $DOTFILES_TARGETS += "$HOME\.gitconfig-$s"
}
# Settings.json de los plugins de Flow Launcher: uno por carpeta del repo.
foreach ($flowPlugin in (Get-ChildItem -Directory (Join-Path $DOTFILES_DIR 'flowlauncher\Plugins') -ErrorAction SilentlyContinue).Name) {
    $DOTFILES_TARGETS += "$env:APPDATA\FlowLauncher\Settings\Plugins\$flowPlugin\Settings.json"
}
# Temas propios de Flow Launcher: un archivo .xaml por tema del repo.
foreach ($flowTheme in (Get-ChildItem -File (Join-Path $DOTFILES_DIR 'flowlauncher\Themes') -Filter *.xaml -ErrorAction SilentlyContinue).Name) {
    $DOTFILES_TARGETS += "$env:APPDATA\FlowLauncher\Themes\$flowTheme"
}

# Paquetes winget instalados por el bootstrap (Id winget). Solo con -RemovePackages.
$WINGET_PACKAGES = @(
    @{ Id='JanDeDobbeleer.OhMyPosh'; Name='Oh My Posh' }
    @{ Id='Neovim.Neovim';           Name='Neovim' }
    @{ Id='JesseDuffield.lazygit';   Name='LazyGit' }
    @{ Id='OpenJS.NodeJS.LTS';       Name='Node.js LTS' }
    @{ Id='BurntSushi.ripgrep.MSVC'; Name='ripgrep' }
    @{ Id='junegunn.fzf';            Name='fzf' }
    @{ Id='ajeetdsouza.zoxide';      Name='zoxide' }
    @{ Id='GLab.GLab';               Name='GitLab CLI (glab)' }
    @{ Id='FiloSottile.age';         Name='age' }
    @{ Id='SST.opencode';            Name='opencode' }
    @{ Id='sxyazi.yazi';             Name='yazi' }
    @{ Id='GitHub.cli';              Name='GitHub CLI (gh)' }
    @{ Id='Amazon.AWSCLI';           Name='AWS CLI' }
    @{ Id='OpenAI.Codex';            Name='Codex CLI' }
)

# ==============================================================================
# HELPERS
# ==============================================================================

# Forzar UTF-8 en la consola para que los iconos se vean (no rompe si ya lo esta)
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
# Iconos: UTF-8 si la consola lo soporta, si no ASCII
$script:ICONS = if ([Console]::OutputEncoding.CodePage -eq 65001) {
    @{ Section='▶'; Ok='✓'; Warn='⚠'; Err='✗'; Skip='⊘'; Bullet='✗' }
} else {
    @{ Section='>'; Ok='[OK]'; Warn='[!]'; Err='[X]'; Skip='[-]'; Bullet='*' }
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

# Item de preview: marca lo que se va a quitar (rojo)
function Write-Prev { param([string]$Text) Write-Host "    $($script:ICONS.Bullet) $Text" -ForegroundColor Red }

function Test-CommandAvailable {
    param([string]$Cmd)
    return [bool](Get-Command $Cmd -ErrorAction SilentlyContinue)
}

function Confirm-Action {
    param([string]$Prompt)
    if ($Force) { return $true }
    $reply = Read-Host "$Prompt [y/N]"
    return ($reply -match '^[Yy]$')
}

# ==============================================================================
# INICIO
# ==============================================================================

Write-Log 'uninstall.ps1 - Desinstalacion de dotfiles' 'SECTION'
if ($DryRun) { Write-Log 'modo DryRun' 'INFO' }

# ==============================================================================
# 1. VERIFICAR QUE EXISTEN LOS REPOS
# ==============================================================================

if (-not (Test-Path $DOTFILES_DIR) -and -not (Test-Path $VAULT_DIR)) {
    Write-Log 'No se encontraron dotfiles instalados en:' 'ERROR'
    Write-Log "  - $DOTFILES_DIR" 'ERROR'
    Write-Log "  - $VAULT_DIR" 'ERROR'
    Write-Log 'Nada que desinstalar.' 'INFO'
    exit 0
}

# ==============================================================================
# 2. PREVIEW Y CONFIRMACION
# ==============================================================================

Write-Log 'Preview - Que se va a desinstalar' 'SECTION'

Write-Log 'Symlinks/archivos a remover:' 'INFO'
foreach ($target in $DOTFILES_TARGETS) {
    if (Test-Path $target) { Write-Prev $target }
}

Write-Log 'Repositorios a borrar:' 'INFO'
if (Test-Path $DOTFILES_DIR) { Write-Prev $DOTFILES_DIR }
if (Test-Path $VAULT_DIR)    { Write-Prev $VAULT_DIR }

if ($RemovePackages) {
    Write-Log 'Paquetes a desinstalar (-RemovePackages):' 'INFO'
    foreach ($pkg in $WINGET_PACKAGES) {
        Write-Prev "$($pkg.Name) ($($pkg.Id))"
    }
}

if ($DryRun) {
    Write-Log '[DRY RUN] No se ejecutara ninguna accion destructiva.' 'SKIP'
    exit 0
}

Write-Host ''
if (-not (Confirm-Action 'Continuar con la desinstalacion?')) {
    Write-Log 'Desinstalacion cancelada por el usuario.' 'WARN'
    exit 0
}

# ==============================================================================
# 3. REMOVER SYMLINKS Y ARCHIVOS
# ==============================================================================

Write-Log '--- [1/3] Removiendo symlinks y archivos dotfiles ---' 'SECTION'

foreach ($target in $DOTFILES_TARGETS) {
    if (Test-Path $target) {
        $item = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        $isLink = $item -and ($item.LinkType -eq 'SymbolicLink')
        Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        if ($isLink) {
            Write-Log "Removido symlink: $target" 'OK'
        } else {
            Write-Log "Removido archivo: $target" 'OK'
        }
    }
}

# ==============================================================================
# 4. DESINSTALAR PAQUETES (OPCIONAL)
# ==============================================================================

Write-Log '--- [2/3] Desinstalando paquetes ---' 'SECTION'

if (-not $RemovePackages) {
    Write-Log 'Saltando desinstalacion de paquetes (usa -RemovePackages)' 'SKIP'
} elseif (-not (Test-CommandAvailable 'winget')) {
    Write-Log 'winget no disponible, saltando desinstalacion de paquetes' 'WARN'
} else {
    foreach ($pkg in $WINGET_PACKAGES) {
        # Mismos flags que bootstrap.ps1: sin ellos msstore puede frenar pidiendo
        # aceptar sus terminos con la salida redirigida (cuelgue silencioso).
        # Exit 0 de 'winget list' = instalado (mismo criterio que bootstrap.ps1:
        # el Id como texto puede venir recortado con '…' en la tabla).
        $global:LASTEXITCODE = 1
        $listOut = winget list --id $pkg.Id --exact --accept-source-agreements --disable-interactivity 2>$null
        $installed = ($LASTEXITCODE -eq 0) -or [bool]($listOut | Select-String -SimpleMatch $pkg.Id)
        if (-not $installed) {
            Write-Log "$($pkg.Name) no instalado, saltando" 'SKIP'
            continue
        }
        winget uninstall --id $pkg.Id -e --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Desinstalado: $($pkg.Name)" 'OK'
        } else {
            Write-Log "Fallo al desinstalar $($pkg.Name)" 'WARN'
        }
    }
}

# ==============================================================================
# 5. BORRAR REPOSITORIOS
# ==============================================================================

Write-Log '--- [3/3] Borrando repositorios ---' 'SECTION'

if (Test-Path $DOTFILES_DIR) {
    Remove-Item -LiteralPath $DOTFILES_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Borrado: $DOTFILES_DIR" 'OK'
}
if (Test-Path $VAULT_DIR) {
    Remove-Item -LiteralPath $VAULT_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Borrado: $VAULT_DIR" 'OK'
}

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================

Write-Log 'Desinstalacion completada' 'SECTION'
Write-Log 'Dotfiles desinstalados correctamente.' 'OK'
Write-Log 'Para reinstalar, ejecuta:' 'INFO'
Write-Log '  irm https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1 | iex' 'INFO'
