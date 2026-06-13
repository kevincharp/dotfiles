# ==============================================================================
#   bootstrap.ps1 — Setup completo de entorno de desarrollo (Windows / pwsh 7)
#   Autor: Kevin Charpentier
#   Uso:   pwsh -ExecutionPolicy Bypass -File bootstrap.ps1
# ==============================================================================
#   Qué hace:
#     1. Verifica requisitos (pwsh 7, winget)
#     2. Instala herramientas vía winget
#     3. Instala módulos de PowerShell
#     4. Crea estructura de carpetas (~/.config, ~/.local, etc.)
#     5. Copia dotfiles del repo a sus ubicaciones correctas
#     6. Configura AWS CLI (opcional, si se pasa -WithAws)
#     7. Configura Windows Terminal
#     8. Loguea errores y genera resumen final
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$WithAws,         # incluir configuracion de AWS SSO
    [switch]$DryRun,          # mostrar qué haría sin ejecutar nada
    [switch]$SkipWinget,      # saltear instalacion de paquetes
    [switch]$SkipModules,     # saltear instalacion de modulos PS
    [switch]$SkipDotfiles     # saltear copia de dotfiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ==============================================================================
# CONFIGURACION
# ==============================================================================

$REPO_ROOT   = $PSScriptRoot   # raiz del repo publico clonado
# Vault privado (ssh, identidades git, bookmarks). Override via env VAULT_DIR.
$VAULT_DIR   = if ($env:VAULT_DIR) { $env:VAULT_DIR } else { Join-Path $HOME ".dotfiles-vault" }
$LOG_FILE    = Join-Path $HOME ".local\logs\bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$ERRORS      = [System.Collections.Generic.List[string]]::new()
$WARNINGS    = [System.Collections.Generic.List[string]]::new()
$BACKUP_TS   = Get-Date -Format 'yyyyMMdd-HHmmss'
$BACKUP_DIR  = Join-Path $HOME ".local\backups\bootstrap\$BACKUP_TS"

# Estructura de carpetas a crear
$DIRS = @(
    "$HOME\.config\powershell"
    "$HOME\.config\git"
    "$HOME\.config\lazygit"
    "$HOME\.local\bin"
    "$HOME\.local\logs"
    "$HOME\.cache"
    "$HOME\.ssh"
    "$HOME\repositorios\personal"
    "$HOME\repositorios\work"
    "$HOME\repositorios\cei_walle"
)

# Paquetes winget
# Formato: @{ Id='...'; Name='...'; Optional=$false }
$WINGET_PACKAGES = @(
    @{ Id='Microsoft.WindowsTerminal';      Name='Windows Terminal';        Optional=$false }
    @{ Id='Microsoft.PowerShell';           Name='PowerShell 7';            Optional=$false }
    @{ Id='JanDeDobbeleer.OhMyPosh';        Name='Oh My Posh';              Optional=$false }
    @{ Id='Neovim.Neovim';                  Name='Neovim';                  Optional=$false }
    @{ Id='JesseDuffield.lazygit';          Name='LazyGit';                 Optional=$false }
    @{ Id='OpenJS.NodeJS.LTS';              Name='Node.js LTS';             Optional=$false }
    @{ Id='BurntSushi.ripgrep.MSVC';        Name='ripgrep';                 Optional=$false }
    @{ Id='junegunn.fzf';                   Name='fzf';                     Optional=$false }
    @{ Id='ajeetdsouza.zoxide';             Name='zoxide';                  Optional=$false }
    @{ Id='Amazon.AWSCLI';                  Name='AWS CLI';                 Optional=$true  }
    @{ Id='GitHub.cli';                     Name='GitHub CLI (gh)';         Optional=$true  }
    @{ Id='GLab.GLab';                      Name='GitLab CLI (glab)';       Optional=$true  }
    @{ Id='FiloSottile.age';                Name='age (encriptacion)';      Optional=$true  }
    @{ Id='Obsidian.Obsidian';              Name='Obsidian';                Optional=$true  }
    @{ Id='SST.opencode';                   Name='opencode';                Optional=$true  }
    @{ Id='Logitech.OptionsPlus';           Name='Logitech Options+';       Optional=$true  }
    @{ Id='Microsoft.Sysinternals.SDelete'; Name='SDelete (Sysinternals)';  Optional=$true  }
    @{ Id='Canonical.Ubuntu.2204';          Name='Ubuntu 22.04 (WSL)';      Optional=$true  }
)

# ==============================================================================
# INSTALACIONES MANUALES REQUERIDAS
# ------------------------------------------------------------------------------
# Estos tres programas NO se instalan por winget adrede. Hay razones concretas:
#
#  1. VSCode — System Installer (x64)
#     Descargá: https://code.visualstudio.com/docs/?dv=win64user
#     ¿Por qué manual? El System Installer instala VSCode en Program Files y
#     agrega el comando `code` al PATH del sistema para todos los usuarios y
#     contextos (scripts, WSL, terminales). El instalador de winget usa el
#     User Installer que instala en AppData y puede no quedar en el PATH global.
#
#  2. Python — Instalador oficial amd64
#     Descargá: https://www.python.org/downloads/windows/ (Windows installer 64-bit)
#     ¿Por qué manual? El instalador oficial tiene una checkbox explícita
#     "Add Python to PATH" y configura correctamente python.exe en el PATH.
#     El de winget históricamente instala el launcher py.exe en lugar de
#     python.exe directo, lo que rompe la configuración de Neovim
#     (python3_host_prog necesita el path exacto del ejecutable).
#     IMPORTANTE: durante la instalación marcá "Add Python to PATH".
#
#  3. Git — Git for Windows
#     Descargá: https://gitforwindows.org/
#     ¿Por qué manual? El instalador oficial te permite configurar opciones
#     críticas: editor por defecto, manejo de line endings (CRLF/LF),
#     integración con el shell de Windows, y si agregar Git Bash al PATH.
#     Por winget esas opciones vienen con defaults que pueden no ser los correctos
#     para tu flujo de trabajo.
#     Opciones recomendadas durante la instalación:
#       - Editor: Neovim (o VSCode si preferís)
#       - Line endings: "Checkout as-is, commit as-is" (manejamos con .gitconfig)
#       - SSH: usar el SSH incluido en Git
# ==============================================================================

# Modulos de PowerShell
$PS_MODULES = @(
    'PSReadLine'
    'posh-git'
    'Terminal-Icons'
)

# Dotfiles: origen (relativo al repo) -> destino
$DOTFILES = @(
    # Shell (symlinks: editar en el repo se ve al instante)
    @{ Src='shell\profile.ps1';       Dst="$HOME\.config\powershell\profile.ps1"; Mode='link' }
    @{ Src='shell\bashrc';            Dst="$HOME\.bashrc"                       ; Mode='link' }
    @{ Src='shell\bash_profile';      Dst="$HOME\.bash_profile"                 ; Mode='link' }
    # Git ignore (publico)
    @{ Src='git\ignore';              Dst="$HOME\.config\git\ignore"             ; Mode='link' }
    # Git config + identidades (VAULT privado: namespaces y emails)
    @{ Src='git\config';              Dst="$HOME\.gitconfig"            ; Mode='link'; Root='vault' }
    @{ Src='git\config-personal';     Dst="$HOME\.gitconfig-personal"   ; Mode='link'; Root='vault' }
    @{ Src='git\config-work';         Dst="$HOME\.gitconfig-work"       ; Mode='link'; Root='vault' }
    @{ Src='git\config-cei_walle';    Dst="$HOME\.gitconfig-cei_walle"  ; Mode='link'; Root='vault' }
    # Identidades para el shell pwsh (gclone/gset-profile)
    @{ Src='shell\git-identities.ps1'; Dst="$HOME\.config\git-identities.ps1"   ; Root='vault' }
    # SSH config (VAULT privado)
    @{ Src='ssh\config';              Dst="$HOME\.ssh\config"           ; Root='vault' }
    # Terminal (symlink: cambios en la GUI de Windows Terminal se ven al instante en el repo)
    @{ Src='terminal\settings.json';  Dst="$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"; Mode='link' }
    # Editorconfig (symlink)
    @{ Src='.editorconfig';           Dst="$HOME\.editorconfig"                  ; Mode='link' }
    # Claude Code
    @{ Src='.claude\settings.json';         Dst="$HOME\.claude\settings.json"         }
    @{ Src='.claude\settings.local.json';   Dst="$HOME\.claude\settings.local.json"   }
    @{ Src='.claude\plugins\installed_plugins.json'; Dst="$HOME\.claude\plugins\installed_plugins.json" }
)

# ==============================================================================
# HELPERS
# ==============================================================================

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts   = Get-Date -Format 'HH:mm:ss'
    $line = "[$ts][$Level] $Message"

    $color = switch ($Level) {
        'OK'      { 'Green'      }
        'WARN'    { 'DarkYellow' }
        'ERROR'   { 'Red'        }
        'SKIP'    { 'DarkGray'   }
        'SECTION' { 'Cyan'       }
        default   { 'White'      }
    }

    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LOG_FILE -Value $line -ErrorAction SilentlyContinue
}

function Invoke-Step {
    param([string]$Name, [scriptblock]$Action)
    if ($DryRun) {
        Write-Log "[DryRun] $Name" 'SKIP'
        return
    }
    try {
        & $Action
        Write-Log "$Name" 'OK'
    } catch {
        $msg = "$Name → $($_.Exception.Message)"
        Write-Log $msg 'ERROR'
        $ERRORS.Add($msg)
    }
}

function Test-WingetAvailable {
    return [bool](Get-Command winget -ErrorAction SilentlyContinue)
}

function Test-CommandAvailable {
    param([string]$Cmd)
    return [bool](Get-Command $Cmd -ErrorAction SilentlyContinue)
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Name,
        [bool]$Optional = $false
    )

    $installed = winget list --id $Id --exact 2>$null | Select-String $Id
    if ($installed) {
        Write-Log "$Name ya instalado, saltando" 'SKIP'
        return
    }

    Write-Log "Instalando $Name ($Id)..." 'INFO'

    if ($DryRun) {
        Write-Log "[DryRun] winget install --id $Id -e --accept-package-agreements --accept-source-agreements" 'SKIP'
        return
    }

    $result = winget install --id $Id -e --accept-package-agreements --accept-source-agreements 2>&1
    if ($LASTEXITCODE -ne 0) {
        $msg = "Error instalando $Name`: $result"
        if ($Optional) {
            Write-Log "$msg (opcional, continuando)" 'WARN'
            $WARNINGS.Add($msg)
        } else {
            Write-Log $msg 'ERROR'
            $ERRORS.Add($msg)
        }
    } else {
        Write-Log "$Name instalado correctamente" 'OK'
    }
}

# ==============================================================================
# INICIO
# ==============================================================================

# Asegurar que existe el directorio de logs antes de escribir
New-Item -ItemType Directory -Path (Split-Path $LOG_FILE) -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Path $BACKUP_DIR -Force -ErrorAction SilentlyContinue | Out-Null

Write-Log "======================================================" 'SECTION'
Write-Log "  bootstrap.ps1 — Inicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 'SECTION'
Write-Log "  DryRun: $DryRun" 'SECTION'
Write-Log "======================================================" 'SECTION'
Write-Log "" 'INFO'
Write-Log "INSTALACIONES MANUALES REQUERIDAS ANTES DE CONTINUAR" 'WARN'
Write-Log "  Estos programas NO se instalan automaticamente (hay razones):" 'WARN'
Write-Log "  1. VSCode System Installer (x64)" 'WARN'
Write-Log "     https://code.visualstudio.com/docs/?dv=win64user" 'WARN'
Write-Log "     Razon: el System Installer agrega 'code' al PATH global." 'WARN'
Write-Log "  2. Python (instalador oficial amd64)" 'WARN'
Write-Log "     https://www.python.org/downloads/windows/" 'WARN'
Write-Log "     Razon: marca 'Add Python to PATH' - necesario para Neovim." 'WARN'
Write-Log "  3. Git for Windows" 'WARN'
Write-Log "     https://gitforwindows.org/" 'WARN'
Write-Log "     Razon: el instalador permite configurar line endings y SSH." 'WARN'
Write-Log "" 'INFO'
Write-Log "  Ya los instalaste? Si no, presiona Ctrl+C y hacelo primero." 'WARN'
Write-Log "" 'INFO'

if (-not $DryRun) { Read-Host "  Presiona Enter para continuar" }

# ==============================================================================
# 1. VERIFICAR REQUISITOS
# ==============================================================================

Write-Log "--- [1/9] Verificando requisitos ---" 'SECTION'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Log "Se requiere PowerShell 7+. Versión actual: $($PSVersionTable.PSVersion)" 'ERROR'
    Write-Log "Instalá pwsh 7 con: winget install --id Microsoft.PowerShell --source winget" 'WARN'
    exit 1
}
Write-Log "PowerShell $($PSVersionTable.PSVersion) OK" 'OK'

if (-not (Test-WingetAvailable)) {
    Write-Log "winget no está disponible. Instalalo desde: https://aka.ms/getwinget" 'ERROR'
    exit 1
}
Write-Log "winget disponible" 'OK'

# ==============================================================================
# 2. INSTALAR PAQUETES WINGET
# ==============================================================================

Write-Log "--- [2/9] Instalando paquetes winget ---" 'SECTION'

if ($SkipWinget) {
    Write-Log "SkipWinget activado, saltando instalacion de paquetes" 'SKIP'
} else {
    if (-not (Test-WingetAvailable)) {
        Write-Log "winget no disponible, saltando paquetes" 'WARN'
    } else {
        # Actualizar fuentes de winget primero
        Invoke-Step "Actualizar fuentes winget" {
            winget source update 2>&1 | Out-Null
        }

        foreach ($pkg in $WINGET_PACKAGES) {
            # WSL se instala diferente
            if ($pkg.Id -eq 'Canonical.Ubuntu.2204') {
                if ($DryRun) {
                    Write-Log "[DryRun] wsl --install -d Ubuntu-22.04" 'SKIP'
                } else {
                    $wslCheck = wsl -l -v 2>$null | Select-String 'Ubuntu'
                    if ($wslCheck) {
                        Write-Log "WSL Ubuntu ya instalado, saltando" 'SKIP'
                    } else {
                        Invoke-Step "Instalar WSL Ubuntu 22.04" {
                            wsl --install -d Ubuntu-22.04
                        }
                    }
                }
                continue
            }
            Install-WingetPackage -Id $pkg.Id -Name $pkg.Name -Optional $pkg.Optional
        }
    }
}

# ==============================================================================
# 3. INSTALAR CODEX CLI Y CLAUDE CODE (via winget)
# ==============================================================================

Write-Log "--- [3/9] Instalando Codex CLI y Claude Code ---" 'SECTION'

if (Test-CommandAvailable 'codex') {
    Write-Log "Codex CLI ya instalado" 'SKIP'
} else {
    Install-WingetPackage -Id 'OpenAI.Codex' -Name 'Codex CLI' -Optional $false
}

Write-Log "  Nota: para instalar Codex Desktop ejecuta 'codex app' (descarga el instalador automaticamente)" 'INFO'

if (Test-CommandAvailable 'claude') {
    Write-Log "Claude Code ya instalado" 'SKIP'
} else {
    # Claude Code: instalacion manual por ahora (winget ID pendiente de confirmar)
    Write-Log "Claude Code no instalado — instalar manualmente desde https://claude.ai/download" 'WARN'
    $WARNINGS.Add("Claude Code no instalado — descargar desde https://claude.ai/download")
}

# ==============================================================================
# 4. INSTALAR MODULOS DE POWERSHELL
# ==============================================================================

Write-Log "--- [4/9] Instalando modulos de PowerShell ---" 'SECTION'

if ($SkipModules) {
    Write-Log "SkipModules activado, saltando módulos" 'SKIP'
} else {
    foreach ($mod in $PS_MODULES) {
        if (Get-Module -ListAvailable -Name $mod) {
            Write-Log "Módulo '$mod' ya instalado, saltando" 'SKIP'
        } else {
            Invoke-Step "Instalar módulo $mod" {
                Install-Module $mod -Scope CurrentUser -Force -ErrorAction Stop
            }
        }
    }
}

# ==============================================================================
# 4. CREAR ESTRUCTURA DE CARPETAS
# ==============================================================================

Write-Log "--- [5/9] Creando estructura de carpetas ---" 'SECTION'

foreach ($dir in $DIRS) {
    if (Test-Path $dir) {
        Write-Log "$dir ya existe, saltando" 'SKIP'
    } else {
        Invoke-Step "Crear $dir" {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

# Permisos seguros para .ssh
Invoke-Step "Asegurar permisos de ~/.ssh" {
    $sshPath = "$HOME\.ssh"
    $acl     = Get-Acl $sshPath
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $env:USERNAME, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
    )
    $acl.SetAccessRule($rule)
    Set-Acl $sshPath $acl
}

# Permisos seguros para .env (solo tu usuario puede leerlo)
$envFile = Join-Path $HOME ".env"
if (Test-Path $envFile) {
    Invoke-Step "Asegurar permisos de ~/.env" {
        $acl = Get-Acl $envFile
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME, 'FullControl', 'None', 'None', 'Allow'
        )
        $acl.SetAccessRule($rule)
        Set-Acl $envFile $acl
    }
} else {
    Write-Log "~/.env no existe — crealo manualmente con tus tokens" 'WARN'
    $WARNINGS.Add("~/.env no encontrado — crealo y volvé a ejecutar el bootstrap para asegurar permisos")
}

# ==============================================================================
# 5. MIGRAR BACKUPS VIEJOS (.bak-*) → BACKUP_DIR
# ==============================================================================

Write-Log "--- [6/9] Migrando backups viejos ---" 'SECTION'

if ($SkipDotfiles) {
    Write-Log "SkipDotfiles activado, saltando migracion de backups" 'SKIP'
} elseif ($DryRun) {
    Write-Log "[DryRun] Migrar backups viejos" 'SKIP'
} else {
    $BAK_DESTINATIONS = $DOTFILES | ForEach-Object { $_.Dst }
    $migratedCount = 0

    foreach ($dst in $BAK_DESTINATIONS) {
        $dstDir  = Split-Path $dst
        $dstName = Split-Path $dst -Leaf

        if (-not (Test-Path $dstDir)) { continue }

        $oldBaks = Get-ChildItem -Path $dstDir -Filter "$dstName.bak-*" -File -ErrorAction SilentlyContinue

        foreach ($oldBak in $oldBaks) {
            # Calcular ruta relativa a HOME
            $homePath = $HOME.TrimEnd('\', '/')
            if ($dst.StartsWith($homePath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relPath = $dst.Substring($homePath.Length).TrimStart('\', '/')
            } else {
                $relPath = "_external\$dstName"
            }

            # Extraer timestamp del nombre del backup
            $ts = if ($oldBak.Name -match '(\d{8}-\d{6})') { $Matches[1] } else { 'unknown' }
            $targetDir = Join-Path $BACKUP_DIR "_migrated\$ts"
            $targetFile = Join-Path $targetDir $relPath
            $targetParent = Split-Path $targetFile

            Invoke-Step "Migrar $($oldBak.FullName) → $targetFile" {
                if (-not (Test-Path $targetParent)) {
                    New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
                }
                Move-Item -LiteralPath $oldBak.FullName -Destination $targetFile -Force
            }
            $migratedCount++
        }
    }

    if ($migratedCount -gt 0) {
        Write-Log "Migrados $migratedCount backups viejos a $BACKUP_DIR\_migrated\" 'OK'
    } else {
        Write-Log "No se encontraron backups viejos para migrar" 'SKIP'
    }
}

# ==============================================================================
# 6. COPIAR DOTFILES
# ==============================================================================

Write-Log "--- [7/9] Copiando dotfiles ---" 'SECTION'

if ($SkipDotfiles) {
    Write-Log "SkipDotfiles activado, saltando dotfiles" 'SKIP'
} else {
    foreach ($df in $DOTFILES) {
        # Resolver raiz: 'vault' (privado) o repo publico por defecto
        $root = if ($df.PSObject.Properties['Root'] -and $df.Root -eq 'vault') { $VAULT_DIR } else { $REPO_ROOT }
        $src = Join-Path $root $df.Src
        $dst = $df.Dst

        if (-not (Test-Path $src)) {
            if ($df.PSObject.Properties['Root'] -and $df.Root -eq 'vault') {
                $msg = "Vault no disponible: $($df.Src) (falta $VAULT_DIR)"
            } else {
                $msg = "Origen no encontrado: $src"
            }
            Write-Log $msg 'WARN'
            $WARNINGS.Add($msg)
            continue
        }

        $dstExists = Test-Path $dst
        $dstItem   = if ($dstExists) { Get-Item -LiteralPath $dst -Force } else { $null }
        $dstIsLink = $dstItem -and ($dstItem.LinkType -eq 'SymbolicLink')
        if ($dstExists -and -not $dstIsLink) {
            # Backup centralizado en BACKUP_DIR
            $homePath = $HOME.TrimEnd('\', '/')
            if ($dst.StartsWith($homePath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relPath = $dst.Substring($homePath.Length).TrimStart('\', '/')
            } else {
                $relPath = "_external\$([System.IO.Path]::GetFileName($dst))"
            }
            $bakDst = Join-Path $BACKUP_DIR $relPath

            if ($DryRun) {
                Write-Log "[DryRun] Backup $dst → $bakDst" 'SKIP'
            } else {
                Invoke-Step "Backup $dst → $bakDst" {
                    $bakDir = Split-Path $bakDst
                    if (-not (Test-Path $bakDir)) {
                        New-Item -ItemType Directory -Path $bakDir -Force | Out-Null
                    }
                    Copy-Item -LiteralPath $dst -Destination $bakDst -Force
                }
            }
        }

        $mode = if ($df.ContainsKey('Mode')) { $df.Mode } else { 'copy' }

        if ($DryRun) {
            $estado = if ($dstExists) { "SOBREESCRIBIR" } else { "CREAR" }
            $accion = if ($mode -eq 'link') { 'SYMLINK' } else { 'COPIAR' }
            Write-Log "[DryRun] [$estado][$accion] $($df.Src) → $dst" 'SKIP'
        } else {
            $dstDir = Split-Path $dst
            if (-not (Test-Path $dstDir)) {
                New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            }
            if ($mode -eq 'link') {
                Invoke-Step "Symlink $($df.Src) → $dst" {
                    if ($dstExists) { Remove-Item -LiteralPath $dst -Force -Recurse }
                    New-Item -ItemType SymbolicLink -Path $dst -Target $src | Out-Null
                }
            } else {
                Invoke-Step "Copiar $($df.Src) → $dst" {
                    if ($dstIsLink) { Remove-Item -LiteralPath $dst -Force }
                    Copy-Item -LiteralPath $src -Destination $dst -Force
                }
            }
        }
    }

    # --- Tema oh-my-posh (claude-code) ---
    # Estrategia unificada: el repo es la unica fuente de verdad.
    # 1. POSH_THEMES_PATH apunta SIEMPRE a <repo>\shell\themes.
    # 2. Si quedo una copia vieja en %LOCALAPPDATA%\Programs\oh-my-posh\themes\
    #    de instalaciones previas, la borramos para evitar drift.
    $ompSrc          = Join-Path $REPO_ROOT "shell\themes\claude-code.omp.json"
    $ompThemesLocal  = Join-Path $REPO_ROOT "shell\themes"
    $ompLegacyTheme  = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\claude-code.omp.json"

    if (Test-Path $ompSrc) {
        # Setear POSH_THEMES_PATH al repo (idempotente)
        if ($env:POSH_THEMES_PATH -ne $ompThemesLocal) {
            if ($DryRun) {
                Write-Log "[DryRun] Setear POSH_THEMES_PATH → $ompThemesLocal" 'SKIP'
            } else {
                Invoke-Step "Setear POSH_THEMES_PATH → $ompThemesLocal" {
                    [Environment]::SetEnvironmentVariable("POSH_THEMES_PATH", $ompThemesLocal, "User")
                    $env:POSH_THEMES_PATH = $ompThemesLocal
                }
            }
        } else {
            Write-Log "POSH_THEMES_PATH ya apunta al repo, saltando" 'SKIP'
        }

        # Limpiar copia vieja si existe (evita drift entre repo y filesystem)
        if (Test-Path $ompLegacyTheme) {
            if ($DryRun) {
                Write-Log "[DryRun] Eliminar copia vieja: $ompLegacyTheme" 'SKIP'
            } else {
                Invoke-Step "Eliminar copia vieja del tema en Programs\oh-my-posh\themes" {
                    Remove-Item -LiteralPath $ompLegacyTheme -Force
                }
            }
        }
    }

    # --- SSH keys (encriptadas con age, en el vault privado) ---
    $sshKeysDir = Join-Path $VAULT_DIR "ssh\keys"
    $ageFiles = Get-ChildItem -Path $sshKeysDir -Filter "*.age" -File -ErrorAction SilentlyContinue

    if ($ageFiles) {
        if (Test-CommandAvailable 'age') {
            Write-Log "Desencriptando claves SSH (se pide passphrase una sola vez)..." 'INFO'
            $secPass = Read-Host "Passphrase para claves SSH" -AsSecureString
            $agePassphrase = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPass)
            )

            foreach ($ageFile in $ageFiles) {
                $keyName = $ageFile.BaseName
                $dstKey  = "$HOME\.ssh\$keyName"

                if (Test-Path $dstKey) {
                    Write-Log "~/.ssh/$keyName ya existe, saltando" 'SKIP'
                } elseif ($DryRun) {
                    Write-Log "[DryRun] Desencriptar $keyName → ~/.ssh/$keyName" 'SKIP'
                } else {
                    Invoke-Step "Desencriptar $keyName → ~/.ssh/$keyName" {
                        $agePassphrase | age -d -o $dstKey $ageFile.FullName 2>$null
                        if ($LASTEXITCODE -ne 0) { throw "Passphrase incorrecta o error de age" }
                    }
                }
            }

            # Limpiar passphrase de memoria
            $agePassphrase = $null
            [System.GC]::Collect()

            # Copiar claves publicas
            $pubFiles = Get-ChildItem -Path $sshKeysDir -Filter "*.pub" -File -ErrorAction SilentlyContinue
            foreach ($pubFile in $pubFiles) {
                $dstPub = "$HOME\.ssh\$($pubFile.Name)"
                if (Test-Path $dstPub) {
                    Write-Log "~/.ssh/$($pubFile.Name) ya existe, saltando" 'SKIP'
                } else {
                    Invoke-Step "Copiar $($pubFile.Name) → ~/.ssh/" {
                        Copy-Item -LiteralPath $pubFile.FullName -Destination $dstPub -Force
                    }
                }
            }
        } else {
            Write-Log "age no instalado — no se pueden desencriptar las claves SSH" 'WARN'
            $WARNINGS.Add("Instalar age: winget install FiloSottile.age")
        }
    } else {
        Write-Log "No hay claves .age en ssh/keys/, saltando" 'SKIP'
    }

    # --- Limpieza de archivos residuales ---
    Write-Log "" 'INFO'
    Write-Log "--- Limpieza de archivos residuales ---" 'SECTION'

    # .condarc residual
    $condarc = Join-Path $HOME ".condarc"
    if (Test-Path $condarc) {
        Invoke-Step "Eliminar .condarc residual" {
            Remove-Item $condarc -Force -ErrorAction SilentlyContinue
        }
    }
}

# ==============================================================================
# 6. CONFIGURAR AWS SSO (OPCIONAL)
# ==============================================================================

Write-Log "--- [8/9] Configuración AWS ---" 'SECTION'

if (-not $WithAws) {
    Write-Log "Saltando configuración AWS (usá -WithAws para incluirla)" 'SKIP'
} elseif (-not (Test-CommandAvailable 'aws')) {
    Write-Log "AWS CLI no está instalado, saltando configuración SSO" 'WARN'
    $WARNINGS.Add("AWS CLI no encontrado — instalalo y ejecutá 'aws configure sso' manualmente")
} else {
    # Configurar combined-ca.pem para Netskope (solo si existe el cert)
    $netskopeThumb = (Get-ChildItem -Path Cert:\LocalMachine\Root |
                      Where-Object { $_.Subject -match "Netskope" } |
                      Select-Object -First 1).Thumbprint

    if ($netskopeThumb) {
        Invoke-Step "Exportar cert Netskope y crear combined-ca.pem" {
            $cert  = Get-ChildItem -Path Cert:\LocalMachine\Root |
                     Where-Object { $_.Thumbprint -eq $netskopeThumb }
            $bytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
            [System.IO.File]::WriteAllBytes("$HOME\netskope-root.cer", $bytes)
            certutil -encode "$HOME\netskope-root.cer" "$HOME\netskope-root.pem" | Out-Null

            # Buscar cacert.pem o descargarlo
            $cacert = Get-ChildItem -Path "$HOME\.vscode\extensions" -Recurse -Filter "cacert.pem" `
                        -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
            if (-not $cacert) {
                Write-Log "cacert.pem no encontrado en VSCode, descargando..." 'WARN'
                curl.exe -k -s -o "$HOME\cacert.pem" https://curl.se/ca/cacert.pem
                $cacert = "$HOME\cacert.pem"
            }

            Get-Content "$HOME\netskope-root.pem", $cacert | Set-Content "$HOME\combined-ca.pem"
            [System.Environment]::SetEnvironmentVariable("AWS_CA_BUNDLE", "$HOME\combined-ca.pem", "User")
            Write-Log "AWS_CA_BUNDLE configurado: $HOME\combined-ca.pem" 'OK'
        }
    } else {
        Write-Log "Cert Netskope no encontrado — máquina sin Netskope, SSL de AWS debería funcionar directo" 'INFO'
    }

    Write-Log "" 'INFO'
    Write-Log "Para completar la configuración de AWS SSO ejecutá manualmente:" 'WARN'
    Write-Log "  aws configure sso" 'WARN'
    Write-Log "  SSO start URL : https://<tu-org>.awsapps.com/start/#" 'WARN'
    Write-Log "  SSO region    : us-east-1" 'WARN'
    Write-Log "  Cuenta        : DATA" 'WARN'
    Write-Log "  Profile name  : tu_usuario_de_red" 'WARN'
}

# ==============================================================================
# 7. CONFIGURAR PROFILE DE POWERSHELL
# ==============================================================================

Write-Log "--- [9/9] Configurando perfil de PowerShell ---" 'SECTION'

$loaderProfile = $PROFILE
$loaderContent = @"
# Loader — carga el profile real desde ~/.config/powershell
`$profileRoot = Join-Path `$HOME ".config\powershell"
`$mainProfile = Join-Path `$profileRoot "profile.ps1"
if (Test-Path `$mainProfile) {
    . `$mainProfile
} else {
    Write-Host "⚠️  Profile principal no encontrado: `$mainProfile" -ForegroundColor Yellow
}
"@

if (Test-Path $loaderProfile) {
    $existing = Get-Content $loaderProfile -Raw -ErrorAction SilentlyContinue
    if ($existing -match 'mainProfile') {
        Write-Log "Loader de profile ya configurado, saltando" 'SKIP'
    } else {
        Invoke-Step "Agregar loader al `$PROFILE" {
            Add-Content $loaderProfile "`n$loaderContent"
        }
    }
} else {
    Invoke-Step "Crear `$PROFILE con loader" {
        New-Item -ItemType File -Path $loaderProfile -Force | Out-Null
        Set-Content $loaderProfile $loaderContent
    }
}

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================

Write-Log "" 'INFO'
Write-Log "======================================================" 'SECTION'
# ==============================================================================
# VALIDACION POST-BOOTSTRAP
# ==============================================================================

Write-Log "" 'INFO'
Write-Log "--- Ejecutando validaciones post-bootstrap ---" 'SECTION'

$testScript = Join-Path $REPO_ROOT "test-bootstrap.ps1"
if (Test-Path $testScript) {
    if ($DryRun) {
        Write-Log "[DryRun] pwsh -File $testScript" 'SKIP'
    } else {
        & pwsh -File $testScript
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Validaciones post-bootstrap: hay fallos (exit $LASTEXITCODE)" 'WARN'
            $WARNINGS.Add("Validaciones post-bootstrap con fallos — revisar output arriba")
        } else {
            Write-Log "Validaciones post-bootstrap: todo OK" 'OK'
        }
    }
} else {
    Write-Log "test-bootstrap.ps1 no encontrado en $REPO_ROOT" 'WARN'
}

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================

Write-Log "  RESUMEN FINAL" 'SECTION'
Write-Log "======================================================" 'SECTION'

if ($ERRORS.Count -eq 0 -and $WARNINGS.Count -eq 0) {
    Write-Log "Bootstrap completado sin errores." 'OK'
} else {
    if ($WARNINGS.Count -gt 0) {
        Write-Log "Advertencias ($($WARNINGS.Count)):" 'WARN'
        foreach ($w in $WARNINGS) { Write-Log "  ⚠  $w" 'WARN' }
    }
    if ($ERRORS.Count -gt 0) {
        Write-Log "Errores ($($ERRORS.Count)):" 'ERROR'
        foreach ($e in $ERRORS) { Write-Log "  ✗  $e" 'ERROR' }
    }
}

Write-Log "" 'INFO'
Write-Log "Backups almacenados en: $BACKUP_DIR" 'INFO'
Write-Log "Log completo en: $LOG_FILE" 'INFO'
Write-Log "" 'INFO'
Write-Log "Próximos pasos manuales:" 'SECTION'
$stepNum = 1
Write-Log "  $stepNum. Abrí una terminal nueva para recargar el profile" 'INFO'
$stepNum++
if ($WithAws) {
    Write-Log "  $stepNum. Ejecutá: aws configure sso (completar datos de SMG)" 'INFO'
    $stepNum++
    Write-Log "  $stepNum. Ejecutá: aws sts get-caller-identity --profile tu_usuario" 'INFO'
    $stepNum++
}
Write-Log "  $stepNum. Verificá tus claves SSH: ssh -T git@github.com-kevincharp" 'INFO'
Write-Log "======================================================" 'SECTION'
