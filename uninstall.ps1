# ==============================================================================
#   uninstall.ps1 — Desinstalar dotfiles y restaurar estado previo (Windows)
#   Autor: Kevin Charpentier
#   Uso:   pwsh -File uninstall.ps1 [-RemovePackages] [-KeepBackups] [-DryRun] [-Force]
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$RemovePackages,   # desinstalar paquetes instalados por bootstrap (winget)
    [switch]$KeepBackups,      # no borrar ~/.local/backups/bootstrap/
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
$BACKUPS_DIR  = Join-Path $HOME '.local\backups\bootstrap'

# Symlinks/archivos creados por el bootstrap (espejo de $DOTFILES en bootstrap.ps1)
$DOTFILES_TARGETS = @(
    "$HOME\.config\powershell\profile.ps1"
    "$HOME\.bashrc"
    "$HOME\.bash_profile"
    "$HOME\.config\git\ignore"
    "$HOME\.gitconfig"
    "$HOME\.gitconfig-personal"
    "$HOME\.gitconfig-work"
    "$HOME\.gitconfig-cei_walle"
    "$HOME\.config\git-identities.ps1"
    "$HOME\.ssh\config"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$HOME\.editorconfig"
    "$HOME\.claude\settings.json"
    "$HOME\.claude\settings.local.json"
)

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
# 2. ENCONTRAR BACKUP MAS RECIENTE
# ==============================================================================

$LATEST_BACKUP = $null
if (Test-Path $BACKUPS_DIR) {
    $latest = Get-ChildItem -Path $BACKUPS_DIR -Directory -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) {
        $LATEST_BACKUP = $latest.FullName
        Write-Log "Backup mas reciente encontrado: $LATEST_BACKUP" 'OK'
    } else {
        Write-Log "No se encontraron backups en $BACKUPS_DIR" 'WARN'
    }
} else {
    Write-Log "Directorio de backups no existe: $BACKUPS_DIR" 'WARN'
}

# ==============================================================================
# 3. PREVIEW Y CONFIRMACION
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

if ($LATEST_BACKUP) {
    Write-Log 'Archivos a restaurar desde backup:' 'INFO'
    $backupFiles = @(Get-ChildItem -Path $LATEST_BACKUP -Recurse -File -ErrorAction SilentlyContinue)
    $backupFiles | Select-Object -First 10 | ForEach-Object {
        Write-Host "    ↺ $($_.FullName.Substring($LATEST_BACKUP.Length))" -ForegroundColor DarkGray
    }
    if ($backupFiles.Count -gt 10) {
        Write-Log "... y $($backupFiles.Count - 10) mas" 'INFO'
    }
}

if (-not $KeepBackups) {
    Write-Log 'Backups a borrar:' 'INFO'
    Write-Prev $BACKUPS_DIR
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
# 4. REMOVER SYMLINKS Y ARCHIVOS
# ==============================================================================

Write-Log '--- [1/5] Removiendo symlinks y archivos dotfiles ---' 'SECTION'

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
# 5. RESTAURAR BACKUPS
# ==============================================================================

Write-Log '--- [2/5] Restaurando backups ---' 'SECTION'

if ($LATEST_BACKUP -and (Test-Path $LATEST_BACKUP)) {
    $restoredCount = 0
    $backupFiles = Get-ChildItem -Path $LATEST_BACKUP -Recurse -File -ErrorAction SilentlyContinue
    foreach ($backupFile in $backupFiles) {
        $relativePath = $backupFile.FullName.Substring($LATEST_BACKUP.Length).TrimStart('\', '/')
        # Saltar lo migrado (_migrated\...): no son dotfiles activos
        if ($relativePath -like '_migrated*') { continue }
        $dest    = Join-Path $HOME $relativePath
        $destDir = Split-Path $dest
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -LiteralPath $backupFile.FullName -Destination $dest -Force
        $restoredCount++
    }
    Write-Log "Restaurados $restoredCount archivos desde backup" 'OK'
} else {
    Write-Log 'No hay backups para restaurar, saltando' 'SKIP'
}

# ==============================================================================
# 6. DESINSTALAR PAQUETES (OPCIONAL)
# ==============================================================================

Write-Log '--- [3/5] Desinstalando paquetes ---' 'SECTION'

if (-not $RemovePackages) {
    Write-Log 'Saltando desinstalacion de paquetes (usa -RemovePackages)' 'SKIP'
} elseif (-not (Test-CommandAvailable 'winget')) {
    Write-Log 'winget no disponible, saltando desinstalacion de paquetes' 'WARN'
} else {
    foreach ($pkg in $WINGET_PACKAGES) {
        $installed = winget list --id $pkg.Id --exact 2>$null | Select-String $pkg.Id
        if (-not $installed) {
            Write-Log "$($pkg.Name) no instalado, saltando" 'SKIP'
            continue
        }
        winget uninstall --id $pkg.Id -e --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Desinstalado: $($pkg.Name)" 'OK'
        } else {
            Write-Log "Fallo al desinstalar $($pkg.Name)" 'WARN'
        }
    }
}

# ==============================================================================
# 7. BORRAR REPOSITORIOS
# ==============================================================================

Write-Log '--- [4/5] Borrando repositorios ---' 'SECTION'

if (Test-Path $DOTFILES_DIR) {
    Remove-Item -LiteralPath $DOTFILES_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Borrado: $DOTFILES_DIR" 'OK'
}
if (Test-Path $VAULT_DIR) {
    Remove-Item -LiteralPath $VAULT_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Borrado: $VAULT_DIR" 'OK'
}

# ==============================================================================
# 8. BORRAR BACKUPS (OPCIONAL)
# ==============================================================================

Write-Log '--- [5/5] Borrando backups ---' 'SECTION'

if ($KeepBackups) {
    Write-Log "Conservando backups en $BACKUPS_DIR (-KeepBackups)" 'SKIP'
} elseif (Test-Path $BACKUPS_DIR) {
    Remove-Item -LiteralPath $BACKUPS_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Borrado: $BACKUPS_DIR" 'OK'
} else {
    Write-Log 'No hay backups para borrar' 'SKIP'
}

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================

Write-Log 'Desinstalacion completada' 'SECTION'
Write-Log 'Dotfiles desinstalados correctamente.' 'OK'
Write-Log 'Para reinstalar, ejecuta:' 'INFO'
Write-Log '  irm https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1 | iex' 'INFO'
