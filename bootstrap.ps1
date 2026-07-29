# ==============================================================================
#   bootstrap.ps1 — Setup completo de entorno de desarrollo (Windows / pwsh 7)
#   Autor: Kevin Charpentier
#   Uso:   pwsh -ExecutionPolicy Bypass -File bootstrap.ps1
#          [-WithAws] [-DryRun] [-SkipWinget] [-SkipModules] [-SkipDotfiles]
#          [-Tools a,b,c] [-AllTools] [-Pace 0.18 | -Fast]
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
    [switch]$SkipDotfiles,    # saltear copia de dotfiles
    [string]$Tools = '',      # instalar solo estas herramientas (csv de keys); vacio = preguntar
    [switch]$AllTools,        # instalar todo el catalogo sin preguntar
    [double]$Pace = 0.18,     # ritmo de la barra (seg. por accion); 0 = sin pausas
    [switch]$Fast             # barra sin pausas (equivale a -Pace 0; util en CI)
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
    "$env:APPDATA\yazi\config"
    "$HOME\.local\bin"
    "$HOME\.local\logs"
    "$HOME\.cache"
    "$HOME\.ssh"
)
# Carpetas de contexto de repos: si el vault define $GitContextDirs en
# git-identities.ps1 (lo escribe el asistente git-profiles), se usan esas;
# si no, las historicas (mismo criterio que bootstrap.sh).
$ctxDirs = @('personal', 'work', 'cei_walle')
# Sufijos de los ~/.gitconfig-<sufijo>: idem, del mapa $GitIdentityFiles del
# vault. Sin esto los perfiles de un vault ajeno no se symlinkean nunca.
$idSuffixes = @('personal', 'work', 'cei_walle')
$giVault = Join-Path $VAULT_DIR 'shell\git-identities.ps1'
if (Test-Path $giVault) {
    $GitContextDirs = $null
    $GitIdentityFiles = $null
    . $giVault
    if ($GitContextDirs) { $ctxDirs = @($GitContextDirs) }
    if ($GitIdentityFiles) { $idSuffixes = @($GitIdentityFiles.Keys) }
}
foreach ($c in $ctxDirs) { $DIRS += (Join-Path $HOME "repositorios\$c") }

# Paquetes winget — catalogo enriquecido (espejo del TOOLS_CATALOG de Linux)
# Formato: @{ Id='...'; Name='...'; Optional=$false; Key='...'; Group='...' }
#   Key   = identificador corto para -Tools y el selector (igual idea que en bash)
#   Group = core | shell | dev | cloud | fonts | extras
# NOTA: zsh (+ zsh-autosuggestions/zsh-syntax-highlighting) son Linux/macOS-only
# y por eso NO estan en este catalogo. En Windows el shell unificado es
# PowerShell + PSReadLine (ver profile.ps1), que ya replica la misma paleta.
$WINGET_PACKAGES = @(
    @{ Id='Microsoft.WindowsTerminal';      Name='Windows Terminal';        Optional=$false; Key='windows-terminal'; Group='core'   }
    @{ Id='Microsoft.PowerShell';           Name='PowerShell 7';            Optional=$false; Key='pwsh';             Group='core'   }
    @{ Id='Git.Git';                        Name='Git for Windows';         Optional=$false; Key='git';              Group='core'   }
    @{ Id='Neovim.Neovim';                  Name='Neovim';                  Optional=$false; Key='neovim';           Group='core'   }
    @{ Id='BurntSushi.ripgrep.MSVC';        Name='ripgrep';                 Optional=$false; Key='ripgrep';          Group='core'   }
    @{ Id='junegunn.fzf';                   Name='fzf';                     Optional=$false; Key='fzf';              Group='core'   }
    @{ Id='JanDeDobbeleer.OhMyPosh';        Name='Oh My Posh';              Optional=$false; Key='oh-my-posh';       Group='shell'  }
    @{ Id='ajeetdsouza.zoxide';             Name='zoxide';                  Optional=$false; Key='zoxide';           Group='shell'  }
    @{ Id='JesseDuffield.lazygit';          Name='LazyGit';                 Optional=$false; Key='lazygit';          Group='shell'  }
    @{ Id='sxyazi.yazi';                    Name='yazi (file manager TUI)'; Optional=$true ; Key='yazi';             Group='shell'  }
    @{ Id='OpenJS.NodeJS.LTS';              Name='Node.js LTS';             Optional=$false; Key='node';             Group='dev'    }
    @{ Id='SST.opencode';                   Name='opencode';                Optional=$true ; Key='opencode';         Group='dev'    }
    @{ Id='Amazon.AWSCLI';                  Name='AWS CLI';                 Optional=$true ; Key='aws';              Group='cloud'  }
    @{ Id='GitHub.cli';                     Name='GitHub CLI (gh)';         Optional=$true ; Key='gh';               Group='cloud'  }
    @{ Id='GLab.GLab';                      Name='GitLab CLI (glab)';       Optional=$true ; Key='glab';             Group='cloud'  }
    @{ Id='FiloSottile.age';                Name='age (encriptacion)';      Optional=$true ; Key='age';              Group='cloud'  }
    @{ Id='Flow-Launcher.Flow-Launcher';    Name='Flow Launcher';           Optional=$true ; Key='flowlauncher';     Group='extras' }
    @{ Id='Obsidian.Obsidian';              Name='Obsidian';                Optional=$true ; Key='obsidian';         Group='extras' }
    @{ Id='Logitech.OptionsPlus';           Name='Logitech Options+';       Optional=$true ; Key='logitech';         Group='extras' }
    @{ Id='Microsoft.Sysinternals.SDelete'; Name='SDelete (Sysinternals)';  Optional=$true ; Key='sdelete';          Group='extras' }
    @{ Id='Canonical.Ubuntu.2204';          Name='Ubuntu 22.04 (WSL)';      Optional=$true ; Key='wsl-ubuntu';       Group='extras' }
)

# Herramientas con instalacion propia (no via 'winget list'): se gatean por
# seleccion igual que los paquetes winget, pero su instalacion es custom.
#   codex    -> winget OpenAI.Codex + nota de Codex Desktop (seccion 3)
#   claude   -> instalacion manual (winget ID pendiente)            (seccion 3)
#   firacode -> descarga FiraCode Nerd Font y la registra (sin admin)
$EXTRA_TOOLS = @(
    @{ Key='codex';    Name='Codex CLI';            Group='dev'   }
    @{ Key='claude';   Name='Claude Code';          Group='dev'   }
    @{ Key='lazyssh';  Name='lazyssh (TUI SSH)';    Group='shell' }
    @{ Key='firacode'; Name='FiraCode Nerd Font';   Group='fonts' }
)

# Catalogo combinado, solo para el menu y la resolucion de --tools
$TOOLS_CATALOG = $WINGET_PACKAGES + $EXTRA_TOOLS

# ==============================================================================
# INSTALACIONES MANUALES REQUERIDAS
# ------------------------------------------------------------------------------
# Estos dos programas NO se instalan por winget adrede. Hay razones concretas:
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
# NOTA: Git for Windows SI se instala por winget (Id 'Git.Git', grupo core).
# Antes era manual para elegir en el wizard el editor, los line endings y el SSH,
# pero esas opciones hoy las fija el .gitconfig versionado del vault
# (core.editor=nvim, core.autocrlf=input), que tiene prioridad sobre los defaults
# del instalador. El SSH del server se resuelve con el OpenSSH nativo de Windows,
# no con el de Git. Ver [[git-for-windows-winget]] en las notas del repo.
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
    # Los perfiles (git\config-<sufijo>) se agregan abajo desde $idSuffixes.
    # Identidades para el shell pwsh (gclone/gset-profile)
    @{ Src='shell\git-identities.ps1'; Dst="$HOME\.config\git-identities.ps1"   ; Root='vault' }
    # SSH config (VAULT privado)
    @{ Src='ssh\config';              Dst="$HOME\.ssh\config"           ; Root='vault' }
    # Terminal (symlink: cambios en la GUI de Windows Terminal se ven al instante en el repo)
    @{ Src='terminal\settings.json';  Dst="$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"; Mode='link' }
    # Editorconfig (symlink)
    @{ Src='.editorconfig';           Dst="$HOME\.editorconfig"                  ; Mode='link' }
    # yazi (file manager TUI): en Windows la config vive en %APPDATA%\yazi\config
    # (NO en ~/.config como Linux). Symlink: editar en el repo se ve al instante.
    @{ Src='yazi\yazi.toml';          Dst="$env:APPDATA\yazi\config\yazi.toml"   ; Mode='link' }
    # Claude Code (settings.json por symlink: se versiona al editar en el repo.
    # OJO: un /model en cualquier sesion escribe a traves del symlink y modifica
    # el repo. settings.local.json NO se toca: es per-maquina (permisos con rutas
    # absolutas), no esta trackeado y cada PC mantiene el suyo — paridad con Linux.
    # CLAUDE.md global: reglas para TODOS los proyectos (commits, etc). Symlink para
    # que sea portable en cada instalacion (paridad con bootstrap.sh).
    @{ Src='.claude\CLAUDE.md';             Dst="$HOME\.claude\CLAUDE.md"             ; Mode='link' }
    @{ Src='.claude\settings.json';         Dst="$HOME\.claude\settings.json"         ; Mode='link' }
)
# Un perfil de identidad por sufijo del vault (ver $idSuffixes): con nombres
# propios (freelance, cliente-x...) antes no se symlinkeaba ninguno.
foreach ($s in $idSuffixes) {
    $DOTFILES += @{ Src="git\config-$s"; Dst="$HOME\.gitconfig-$s"; Mode='link'; Root='vault' }
}

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

# Paleta ANSI (espejo de bootstrap.sh). PowerShell 7 + Windows Terminal soportan
# truecolor, asi que la barra y los titulos usan el MISMO naranja #D4874E del
# prompt (oh-my-posh). El ESC se escribe con "`e" (PS 7+).
$ESC = [char]27
$script:C_RESET = "$ESC[0m"
$script:C_BAR   = "$ESC[38;2;212;135;78m"       # naranja plano (barra)
$script:C_SECT  = "$ESC[1;38;2;212;135;78m"     # naranja negrita (titulos/headers)
$script:C_DIM   = "$ESC[90m"
$script:C_OK    = "$ESC[32m"
$script:C_WARN  = "$ESC[33m"
$script:C_ERR   = "$ESC[31m"

# ── BARRA DE PROGRESO GLOBAL (espejo de gb_* en bootstrap.sh) ────────────────
# UNA sola barra que cruza los 9 pasos (0→100%), con dos lineas fijas abajo:
#   ▰▰▰▱▱  42%
#   [3/9] Codex/Claude/FiraCode · claude
# El % es global y ponderado (GB_WEIGHTS). En interacciones (selector, sudo N/A,
# passphrase, login AWS) se PAUSA (Suspend-Bar) y retoma en el proximo Step/Sub.
# Sin consola interactiva NO dibuja: cae a headers de texto '[N/9] ...'.
#
# Pesos por paso (suman 100). Instalar winget es lo mas largo -> pesa mas.
# Indice 1..9. GB_BASE = % acumulado ANTES de cada paso.
$script:GB_WEIGHTS = @(0, 4, 34, 14, 8, 6, 4, 18, 4, 8)
$script:GB_BASE    = @(0, 0, 4, 38, 52, 60, 66, 70, 88, 92)
$script:GB_STEP   = 0
$script:GB_LABEL  = ''
$script:GB_ACTION = ''
$script:GB_SUB    = 0
$script:GB_ACTIVE = $false
# Ritmo minimo por accion ("dwell"): -Fast o -Pace 0 lo desactivan.
$script:GB_DWELL  = if ($Fast) { 0 } else { $Pace }
# Solo dibuja con consola interactiva (humano). En CI/headless: headers de texto.
$script:GB_ENABLED = $false

function Get-BarConsoleWidth {
    try { $w = [Console]::WindowWidth; if ($w -gt 0) { return $w } } catch {}
    return 80
}

function Write-BarFrame {
    if (-not $script:GB_ENABLED) { return }
    $width = 40
    $base   = $script:GB_BASE[$script:GB_STEP]
    $weight = $script:GB_WEIGHTS[$script:GB_STEP]
    $pct = [int]($base + $weight * $script:GB_SUB / 100)
    if ($pct -gt 100) { $pct = 100 }
    if ($pct -lt 0)   { $pct = 0 }
    $filled = [int]($pct * $width / 100)
    if ($filled -gt $width) { $filled = $width }
    $bar = ('▰' * $filled) + ('▱' * ($width - $filled))
    $line2 = "[$($script:GB_STEP)/9] $($script:GB_LABEL)"
    if ($script:GB_ACTION) { $line2 += " · $($script:GB_ACTION)" }
    $maxw = (Get-BarConsoleWidth) - 6
    if ($maxw -lt 20) { $maxw = 20 }
    if ($line2.Length -gt $maxw) { $line2 = $line2.Substring(0, $maxw - 1) + '…' }
    # Dos lineas: barra+% y accion. `e[K limpia el resto; `e[1A vuelve a la barra.
    $pctStr = ('{0,3}' -f $pct)
    Write-Host ("`r  {0}{1} {2}%{3}$ESC[K" -f $script:C_BAR, $bar, $pctStr, $script:C_RESET) -NoNewline
    Write-Host ("`n  {0}{1}{2}$ESC[K$ESC[1A`r" -f $script:C_BAR, $line2, $script:C_RESET) -NoNewline
    $script:GB_ACTIVE = $true
}

function Step-Bar {
    param([int]$N, [string]$Label)
    $script:GB_STEP = $N; $script:GB_LABEL = $Label; $script:GB_SUB = 0; $script:GB_ACTION = ''
    Add-Content -Path $LOG_FILE -Value "[$(Get-Date -Format 'HH:mm:ss')] === [$N/9] $Label ===" -ErrorAction SilentlyContinue
    if ($script:GB_ENABLED) { Write-BarFrame }
    else { Write-Host ''; Write-Host "$($script:ICONS.Section) [$N/9] $Label" -ForegroundColor DarkYellow }
}

function Sub-Bar {
    param([int]$Sub, [string]$Action = $null)
    $changed = ($null -ne $Action -and $Action -ne $script:GB_ACTION)
    $script:GB_SUB = $Sub
    if ($null -ne $Action) { $script:GB_ACTION = $Action }
    if (-not $script:GB_ENABLED) { return }
    Write-BarFrame
    if ($changed -and $script:GB_DWELL -gt 0) { Start-Sleep -Seconds $script:GB_DWELL }
}

function Note-Bar {
    # Evento notable (nuevo/warn/error): queda escrito ARRIBA de la barra.
    param([string]$Color, [string]$Icon, [string]$Msg)
    if ($script:GB_ENABLED -and $script:GB_ACTIVE) {
        Write-Host "`r$ESC[K`n`r$ESC[K$ESC[1A`r" -NoNewline
    }
    Write-Host "  $Color$Icon$($script:C_RESET) $Msg"
    if ($script:GB_ENABLED) { Write-BarFrame }
}

function Suspend-Bar {
    # Borra la barra para una interaccion (selector/passphrase/login). Reaparece
    # sola en el proximo Step-Bar/Sub-Bar.
    if ($script:GB_ENABLED -and $script:GB_ACTIVE) {
        Write-Host "`r$ESC[K`n`r$ESC[K$ESC[1A`r" -NoNewline
    }
    $script:GB_ACTIVE = $false
}

function Complete-Bar {
    # Completa la barra al 100%, la limpia y deja el cursor listo para el resumen.
    if ($script:GB_ENABLED) {
        $script:GB_STEP = 9; $script:GB_SUB = 100; $script:GB_ACTION = ''
        Write-BarFrame
        Write-Host "`r$ESC[K`n`r$ESC[K$ESC[1A`r" -NoNewline
    }
    $script:GB_ACTIVE = $false
}

# Acceso a la consola física (CONIN$) — equivalente a /dev/tty en Linux.
# Permite leer el teclado real aunque stdin esté ocupado por 'irm | iex'.
Add-Type -Namespace Win32 -Name NativeConsole -MemberDefinition @'
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern System.IntPtr CreateFile(
        string lpFileName, uint dwDesiredAccess, uint dwShareMode,
        System.IntPtr lpSecurityAttributes, uint dwCreationDisposition,
        uint dwFlagsAndAttributes, System.IntPtr hTemplateFile);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(System.IntPtr hObject);
'@

function Read-Console {
    # Equivalente a 'read -r input < /dev/tty': lee una linea de la consola real.
    # Nota: [System.IO.File]::Open('CONIN$') funciona en pwsh 7 (.NET moderno)
    # pero NO en PowerShell 5.1, donde FileStream rechaza abrir dispositivos de
    # consola. Este script solo corre en pwsh 7, asi que se usa la via directa;
    # el fallback via CreateFile queda por robustez (y esta en install.ps1, que
    # SI arranca bajo 5.1).
    try {
        $fs = [System.IO.File]::Open('CONIN$', 'Open', 'Read', 'ReadWrite')
        $reader = [System.IO.StreamReader]::new($fs)
        try { return $reader.ReadLine() } finally { $reader.Dispose() }
    } catch {
        try {
            $h = [Win32.NativeConsole]::CreateFile('CONIN$', ([uint32]'0x80000000'), 3, [IntPtr]::Zero, 3, 0, [IntPtr]::Zero)
            if ($h -eq [IntPtr]::Zero -or $h.ToInt64() -eq -1) { return (Read-Host) }
            $safe = New-Object Microsoft.Win32.SafeHandles.SafeFileHandle($h, $true)
            $fs2  = New-Object System.IO.FileStream($safe, [System.IO.FileAccess]::Read)
            $sr   = New-Object System.IO.StreamReader($fs2)
            try { return $sr.ReadLine() } finally { $sr.Dispose() }
        } catch { return (Read-Host) }
    }
}

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    # Al archivo siempre con timestamp y nivel (traza completa)
    $ts = Get-Date -Format 'HH:mm:ss'
    Add-Content -Path $LOG_FILE -Value "[$ts][$Level] $Message" -ErrorAction SilentlyContinue

    # Con la barra global ACTIVA, la pantalla la maneja la barra: el ruido de
    # exito (OK/INFO/SKIP) ya quedo en el log, no se imprime. Solo lo notable
    # (WARN/ERROR) scrollea ARRIBA de la barra. SECTION se ignora (los headers los
    # pone Step-Bar). Sin barra, comportamiento normal de abajo.
    if ($script:GB_ACTIVE) {
        switch ($Level) {
            'WARN'  { Note-Bar $script:C_WARN $script:ICONS.Warn $Message }
            'ERROR' { Note-Bar $script:C_ERR  $script:ICONS.Err  $Message }
        }
        return
    }

    # A pantalla: iconos + jerarquia
    switch ($Level) {
        'SECTION' {
            $clean = ($Message -replace '^[\s=#-]+', '' -replace '[\s=#-]+$', '')
            if (-not $clean) { return }
            Write-Host ''
            Write-Host "$($script:ICONS.Section) $clean" -ForegroundColor DarkYellow
        }
        'OK'    { Write-Host "  $($script:ICONS.Ok) " -ForegroundColor Green      -NoNewline; Write-Host $Message }
        'WARN'  { Write-Host "  $($script:ICONS.Warn) " -ForegroundColor DarkYellow -NoNewline; Write-Host $Message }
        'ERROR' { Write-Host "  $($script:ICONS.Err) " -ForegroundColor Red        -NoNewline; Write-Host $Message }
        'SKIP'  { Write-Host "  $($script:ICONS.Skip) $Message" -ForegroundColor DarkGray }
        default { if (-not $Message) { Write-Host '' } else { Write-Host "    $Message" -ForegroundColor DarkGray } }
    }
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

function Test-DeveloperMode {
    # $true si se pueden crear symlinks sin admin: Modo de desarrollador activado
    # (flag AllowDevelopmentWithoutDevLicense) o proceso ya elevado.
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        if (([Security.Principal.WindowsPrincipal]$id).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)) { return $true }
    } catch {}
    try {
        $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        $val = Get-ItemPropertyValue -Path $key -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction Stop
        return ($val -eq 1)
    } catch { return $false }
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
        Write-Log "[DryRun] winget install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements" 'SKIP'
        return
    }

    $result = winget install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements 2>&1
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
# SELECTOR DE HERRAMIENTAS
# ------------------------------------------------------------------------------
# Espejo del selector de bootstrap.sh. Deja en $script:SELECTED_KEYS las Keys
# del catalogo a instalar. Prioridad:
#   1. -Tools "a,b,c"  -> exactamente esas (valida contra el catalogo)
#   2. -AllTools / -DryRun -> todo, sin preguntar
#   3. consola interactiva -> menu agrupado, pregunta siempre
#   4. sin consola (irm | iex no interactivo) -> no instala nada; pide -Tools/-AllTools
# El menu arranca SIN nada pre-marcado (opt-in): el usuario elige que instalar.
# Enter sin marcar nada = no instala nada. Coherente con opt-in: el modo no
# interactivo tampoco instala por sorpresa. Este dotfiles es para escritorio/laptop
# (uso interactivo real), no servers headless; el caso sin-consola es un borde.
# ==============================================================================

$script:SELECTED_KEYS = @()

function Test-Interactive {
    # $true si hay consola fisica adjunta (humano), aunque stdin venga por pipe.
    # Sondea CONIN$ (equivalente a [[ -e /dev/tty ]] en Linux): existe cuando hay
    # un humano, falta en CI/headless real -> ahi cae a la red de seguridad.
    # GENERIC_READ=0x80000000, FILE_SHARE_READ|WRITE=3, OPEN_EXISTING=3.
    # Nota: 0x80000000 se castea a [uint32] porque PowerShell lo toma como Int32 negativo.
    try {
        $h = [Win32.NativeConsole]::CreateFile('CONIN$', ([uint32]'0x80000000'), 3, [IntPtr]::Zero, 3, 0, [IntPtr]::Zero)
        if ($h -eq [IntPtr]::Zero -or $h.ToInt64() -eq -1) { return $false }
        [void][Win32.NativeConsole]::CloseHandle($h)
        return $true
    } catch { return $false }
}

function Select-ToolsInteractive {
    $keys   = $TOOLS_CATALOG | ForEach-Object { $_.Key }
    $groups = @('core', 'shell', 'dev', 'cloud', 'fonts', 'extras')
    # Estado de marcado por Key (opt-in: nada pre-marcado).
    $marked = @{}
    foreach ($k in $keys) { $marked[$k] = $false }
    # Solo grupos con al menos una herramienta en el catalogo.
    $groups = @($groups | Where-Object { @($TOOLS_CATALOG | Where-Object Group -eq $_).Count -gt 0 })
    # Estado expandido por grupo (arrancan colapsados).
    $expanded = @{}
    foreach ($g in $groups) { $expanded[$g] = $false }

    # Si la consola no soporta ReadKey crudo (host no interactivo), cae a texto.
    $rawOk = $true
    try { $null = $Host.UI.RawUI.KeyAvailable } catch { $rawOk = $false }
    if (-not $rawOk) { return Select-ToolsInteractiveText }

    # Estado de un grupo: 'all' | 'partial' | 'none' + conteo on/tot
    function Get-GroupState($g) {
        # @(...).Key sobre un grupo de 1 sola herramienta devuelve un string suelto
        # (no array); re-envolver en @() para que .Count exista bajo StrictMode.
        $gk = @(@($TOOLS_CATALOG | Where-Object Group -eq $g).Key)
        $on = @($gk | Where-Object { $marked[$_] }).Count
        $tot = $gk.Count
        $st = if ($on -eq 0) { 'none' } elseif ($on -eq $tot) { 'all' } else { 'partial' }
        return @{ State = $st; On = $on; Tot = $tot }
    }
    # Reconstruye filas visibles: header de grupo + items si esta expandido
    function Get-Rows {
        $r = @()
        foreach ($g in $groups) {
            $r += [pscustomobject]@{ Kind = 'G'; Group = $g; Key = $null; Name = $null }
            if ($expanded[$g]) {
                foreach ($t in ($TOOLS_CATALOG | Where-Object Group -eq $g)) {
                    $r += [pscustomobject]@{ Kind = 'I'; Group = $g; Key = $t.Key; Name = $t.Name }
                }
            }
        }
        return ,$r
    }

    Write-Host ''
    Write-Host "  $($script:C_SECT)▶ Elegí qué instalar$($script:C_RESET)"
    Write-Host '  ↑/↓ mover · → expandir · ← colapsar · espacio marcar · Enter confirmar' -ForegroundColor DarkGray
    Write-Host ''

    $cur = 0
    $firstDraw = $true
    $drawn = 0
    while ($true) {
        $rows = Get-Rows
        $m = $rows.Count
        if ($cur -ge $m) { $cur = $m - 1 }

        # Subir el cursor al inicio del frame anterior y borrar de ahi hasta el
        # final de pantalla (\e[0J). Sin el borrado, al COLAPSAR un grupo el frame
        # nuevo tiene menos lineas y las sobrantes del frame viejo quedan abajo
        # (efecto "menu duplicado"). PadRight solo limpia el ancho, no lineas de mas.
        if (-not $firstDraw) { Write-Host ("`e[$($drawn)A`e[0J") -NoNewline }
        $firstDraw = $false

        $drawn = 0
        for ($di = 0; $di -lt $m; $di++) {
            $row = $rows[$di]
            $ptr = if ($di -eq $cur) { '❯' } else { ' ' }
            if ($row.Kind -eq 'G') {
                $gs = Get-GroupState $row.Group
                $box = switch ($gs.State) { 'all' { '▰' } 'partial' { '▨' } default { '▱' } }
                $arrow = if ($expanded[$row.Group]) { '▾' } else { '▸' }
                $line = ("  {0} {1} {2} {3,-8} ({4}/{5})" -f $ptr, $arrow, $box, $row.Group, $gs.On, $gs.Tot)
                $color = if ($di -eq $cur) { 'DarkYellow' } elseif ($gs.State -eq 'all') { 'Green' } elseif ($gs.State -eq 'partial') { 'DarkYellow' } else { 'Gray' }
                Write-Host $line.PadRight(70) -ForegroundColor $color
            } else {
                $box = if ($marked[$row.Key]) { '▰' } else { '▱' }
                $line = ("      {0} {1} {2,-16} {3}" -f $ptr, $box, $row.Key, $row.Name)
                $color = if ($di -eq $cur) { 'DarkYellow' } elseif ($marked[$row.Key]) { 'Green' } else { 'Gray' }
                Write-Host $line.PadRight(70) -ForegroundColor $color
            }
            $drawn++
        }
        $total = @($keys | Where-Object { $marked[$_] }).Count
        Write-Host ("  {0} de {1} seleccionadas" -f $total, $keys.Count).PadRight(70) -ForegroundColor DarkYellow
        $drawn++

        $k = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        $row = $rows[$cur]
        switch ($k.VirtualKeyCode) {
            38 { $cur = ($cur - 1 + $m) % $m }                       # Up
            40 { $cur = ($cur + 1) % $m }                            # Down
            39 { if ($row.Kind -eq 'G') { $expanded[$row.Group] = $true } }   # Right -> expandir
            37 { if ($row.Kind -eq 'G') { $expanded[$row.Group] = $false } }  # Left  -> colapsar
            32 {                                                     # Space
                if ($row.Kind -eq 'G') {
                    $gk = @($TOOLS_CATALOG | Where-Object Group -eq $row.Group).Key
                    $target = -not ((Get-GroupState $row.Group).State -eq 'all')
                    foreach ($key in $gk) { $marked[$key] = $target }
                } else {
                    $marked[$row.Key] = (-not $marked[$row.Key])
                }
            }
            13 { return @($keys | Where-Object { $marked[$_] }) }    # Enter
            default {
                switch ([char]$k.Character) {
                    'k' { $cur = ($cur - 1 + $m) % $m }
                    'j' { $cur = ($cur + 1) % $m }
                    'l' { if ($row.Kind -eq 'G') { $expanded[$row.Group] = $true } }
                    'h' { if ($row.Kind -eq 'G') { $expanded[$row.Group] = $false } }
                    'a' { foreach ($key in $keys) { $marked[$key] = $true } }
                    'n' { foreach ($key in $keys) { $marked[$key] = $false } }
                    'q' { return @() }   # cancelar: salir sin nada (Enter es confirmar)
                }
            }
        }
    }
}

# Fallback por texto (hosts sin ReadKey crudo). Marca/desmarca por numero.
function Select-ToolsInteractiveText {
    $keys   = $TOOLS_CATALOG | ForEach-Object { $_.Key }
    $groups = @('core', 'shell', 'dev', 'cloud', 'fonts', 'extras')
    $marked = @{}
    foreach ($k in $keys) { $marked[$k] = $false }   # nada pre-marcado (opt-in)

    while ($true) {
        Write-Host ''
        Write-Host '  == Selector de herramientas ==' -ForegroundColor DarkYellow
        Write-Host '  Marca/desmarca por numero. Enter sin nada = instalar lo marcado.'
        Write-Host ''
        $idx = 0
        $rowKeys = @()   # mapea numero mostrado -> Key
        foreach ($g in $groups) {
            $inGroup = $TOOLS_CATALOG | Where-Object { $_.Group -eq $g }
            if (-not $inGroup) { continue }
            Write-Host "  [$g]" -ForegroundColor White
            foreach ($t in $inGroup) {
                $idx++
                $rowKeys += $t.Key
                $box = if ($marked[$t.Key]) { '[x]' } else { '[ ]' }
                $color = if ($marked[$t.Key]) { 'Green' } else { 'Gray' }
                Write-Host ("    {0} {1,2}) {2,-18} {3}" -f $box, $idx, $t.Key, $t.Name) -ForegroundColor $color
            }
        }
        Write-Host ''
        Write-Host '  Comandos: numeros (ej "1 3 5") | grupo (core/shell/dev/cloud/fonts/extras) | todo | nada | ok'
        Write-Host '  >: ' -NoNewline
        $reply = Read-Console

        if ([string]::IsNullOrWhiteSpace($reply) -or $reply -eq 'ok') { break }

        foreach ($tok in ($reply -split '\s+')) {
            if (-not $tok) { continue }
            switch -Regex ($tok) {
                '^todo$'  { foreach ($k in $keys) { $marked[$k] = $true } }
                '^nada$'  { foreach ($k in $keys) { $marked[$k] = $false } }
                '^(core|shell|dev|cloud|fonts|extras)$' {
                    $grpKeys = ($TOOLS_CATALOG | Where-Object { $_.Group -eq $tok }).Key
                    # Toggle de grupo: si todo el grupo esta marcado lo apaga, si no lo prende
                    $allOn = $true
                    foreach ($k in $grpKeys) { if (-not $marked[$k]) { $allOn = $false } }
                    foreach ($k in $grpKeys) { $marked[$k] = (-not $allOn) }
                }
                '^\d+$' {
                    $n = [int]$tok
                    if ($n -ge 1 -and $n -le $rowKeys.Count) {
                        $k = $rowKeys[$n - 1]
                        $marked[$k] = (-not $marked[$k])
                    } else {
                        Write-Host "    Numero fuera de rango: $tok" -ForegroundColor DarkYellow
                    }
                }
                default { Write-Host "    Entrada ignorada: $tok" -ForegroundColor DarkYellow }
            }
        }
    }

    return @($keys | Where-Object { $marked[$_] })
}

function Resolve-SelectedTools {
    $allKeys = $TOOLS_CATALOG | ForEach-Object { $_.Key }

    if ($Tools) {
        $requested = $Tools -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $valid   = @($requested | Where-Object { $allKeys -contains $_ })
        $unknown = @($requested | Where-Object { $allKeys -notcontains $_ })
        if ($unknown.Count -gt 0) {
            Write-Log "Keys desconocidas en -Tools (ignoradas): $($unknown -join ', ')" 'WARN'
            $WARNINGS.Add("-Tools tenia keys desconocidas: $($unknown -join ', ')")
        }
        $script:SELECTED_KEYS = $valid
        # Al log (no a pantalla): la barra global ya nombra cada herramienta.
        Add-Content -Path $LOG_FILE -Value "[$(Get-Date -Format 'HH:mm:ss')][INFO] Herramientas via -Tools: $($valid -join ', ')" -ErrorAction SilentlyContinue
    } elseif ($AllTools -or $DryRun) {
        $script:SELECTED_KEYS = @($allKeys)
        Add-Content -Path $LOG_FILE -Value "[$(Get-Date -Format 'HH:mm:ss')][INFO] Instalando catalogo completo ($($allKeys.Count) herramientas)" -ErrorAction SilentlyContinue
    } elseif (Test-Interactive) {
        $script:SELECTED_KEYS = @(Select-ToolsInteractive)
        Add-Content -Path $LOG_FILE -Value "[$(Get-Date -Format 'HH:mm:ss')][INFO] Seleccionadas $($script:SELECTED_KEYS.Count): $($script:SELECTED_KEYS -join ', ')" -ErrorAction SilentlyContinue
    } else {
        $script:SELECTED_KEYS = @()
        Write-Log 'Sin consola interactiva y sin -Tools/-AllTools - no instalo nada' 'WARN'
        Write-Log '  Volve a correr con -Tools "a,b,c" (lista) o -AllTools (todo)' 'INFO'
        $WARNINGS.Add('Sin consola: no se instalaron herramientas. Usa -Tools o -AllTools')
    }
}

# True si una Key fue seleccionada para instalar
function Test-ToolSelected {
    param([string]$Key)
    return ($script:SELECTED_KEYS -contains $Key)
}

# ==============================================================================
# PANTALLA DE BIENVENIDA (espejo de welcome_screen en bootstrap.sh)
# ------------------------------------------------------------------------------
# Explica que hace el instalador y muestra el catalogo por grupo. Solo en modo
# interactivo (no con -Tools/-AllTools/-DryRun ni sin consola).
# ==============================================================================
function Show-Welcome {
    $groups = @('core', 'shell', 'dev', 'cloud', 'fonts', 'extras')
    $total  = $TOOLS_CATALOG.Count
    $vault  = if (Test-Path $VAULT_DIR) { '✓ vault presente' } else { '✗ sin vault' }

    $o = $script:C_SECT; $r = $script:C_RESET; $d = $script:C_DIM; $gr = $script:C_OK
    Write-Host ''
    Write-Host "  $o╭──────────────────────────────────────────────────────────────╮$r"
    Write-Host "  $o│                                                              │$r"
    Write-Host "  $o│   ●  dotfiles · Setup de entorno                             │$r"
    Write-Host "  $o│      Windows · reproducible en cualquier máquina             │$r"
    Write-Host "  $o│                                                              │$r"
    Write-Host "  $o╰──────────────────────────────────────────────────────────────╯$r"
    Write-Host ''
    Write-Host "  ${o}Qué hace$r"
    Write-Host ''
    Write-Host '    1  Instala las herramientas que elijas   ' -NoNewline; Write-Host "$d(shell, editor, git, nube…)$r"
    Write-Host '    2  Crea los symlinks de tus configs      ' -NoNewline; Write-Host "$d(pwsh, git, nvim…)$r"
    Write-Host '    3  Aplica lo sensible desde el vault     ' -NoNewline; Write-Host "$d(claves SSH, identidades)$r"
    Write-Host ''
    Write-Host "  ${o}Catálogo$r  $d($total herramientas · elegís qué instalar)$r"
    Write-Host ''
    foreach ($g in $groups) {
        $items = @($TOOLS_CATALOG | Where-Object Group -eq $g)
        if ($items.Count -eq 0) { continue }
        $line = ($items | Select-Object -First 5 | ForEach-Object { $_.Key }) -join ' · '
        Write-Host ("    $gr{0,-6} {1,2}$r  " -f $g, $items.Count) -NoNewline
        Write-Host "$d$line…$r"
    }
    Write-Host ''
    Write-Host "  ${o}Entorno$r   " -NoNewline
    Write-Host "$gr✓ Windows   ✓ winget   $vault$r"
    Write-Host ''
    Write-Host "  $d────────────────────────────────────────────────────────────$r"
    Write-Host "  ${o}Enter$r elegir herramientas  ·  ${o}Ctrl+C$r cancelar"
    [void](Read-Console)
}

# ==============================================================================
# INICIO
# ==============================================================================

# Asegurar que existe el directorio de logs antes de escribir
New-Item -ItemType Directory -Path (Split-Path $LOG_FILE) -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Path $BACKUP_DIR -Force -ErrorAction SilentlyContinue | Out-Null

# Bienvenida solo en modo interactivo real (no en -DryRun/-Tools/-AllTools/sin consola)
if (-not $Tools -and -not $AllTools -and -not $DryRun -and (Test-Interactive)) {
    Show-Welcome
}

Write-Host ''
Write-Host "$($script:C_SECT)$($script:ICONS.Section) bootstrap.ps1 — Setup de entorno$($script:C_RESET)"
Write-Host "  $($script:C_DIM)$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')$(if ($DryRun) { '  ·  modo DryRun' })$($script:C_RESET)"
Add-Content -Path $LOG_FILE -Value "[$(Get-Date -Format 'HH:mm:ss')] === bootstrap.ps1 — Setup de entorno ===" -ErrorAction SilentlyContinue

# Recordatorio de instalaciones manuales (VSCode/Python). Va antes de la barra
# porque pide una confirmacion (Enter) — es interaccion, no ruido de progreso.
Write-Host ''
Write-Host "  $($script:C_WARN)$($script:ICONS.Warn)$($script:C_RESET) Instalaciones manuales requeridas antes de continuar"
Write-Host "    $($script:C_DIM)1. VSCode System Installer (x64) — https://code.visualstudio.com/docs/?dv=win64user$($script:C_RESET)"
Write-Host "    $($script:C_DIM)   (agrega 'code' al PATH global)$($script:C_RESET)"
Write-Host "    $($script:C_DIM)2. Python oficial amd64 — https://www.python.org/downloads/windows/$($script:C_RESET)"
Write-Host "    $($script:C_DIM)   (marca 'Add Python to PATH' — necesario para Neovim)$($script:C_RESET)"

if (-not $DryRun) { Write-Host "  ¿Ya los instalaste? Enter para continuar (Ctrl+C para salir): " -NoNewline; [void](Read-Console) }

# Activar la barra global solo con consola interactiva (humano). En CI/headless
# o sin consola, GB_ENABLED queda en $false y se cae a headers de texto.
if (Test-Interactive) { $script:GB_ENABLED = $true }

# ==============================================================================
# 1. VERIFICAR REQUISITOS
# ==============================================================================

Step-Bar 1 "Verificando requisitos"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Log "Se requiere PowerShell 7+. Versión actual: $($PSVersionTable.PSVersion)" 'ERROR'
    Write-Log "Instalá pwsh 7 con: winget install --id Microsoft.PowerShell --source winget" 'WARN'
    exit 1
}
Sub-Bar 50 "PowerShell $($PSVersionTable.PSVersion)"
Write-Log "PowerShell $($PSVersionTable.PSVersion) OK" 'OK'

if (-not (Test-WingetAvailable)) {
    Write-Log "winget no está disponible. Instalalo desde: https://aka.ms/getwinget" 'ERROR'
    exit 1
}
Sub-Bar 80 "winget disponible"
Write-Log "winget disponible" 'OK'

# Modo de desarrollador: sin el, crear symlinks requiere admin y CADA symlink
# de configs falla por separado (una docena de ERRORs en el resumen, con la causa
# real invisible). Se avisa una sola vez y claro, antes de intentarlo.
if (-not (Test-DeveloperMode)) {
    Write-Log "Modo de desarrollador desactivado — los symlinks de configs van a fallar" 'WARN'
    Write-Log "  Activalo en: Configuración → Sistema → Para desarrolladores → Modo de desarrollador" 'WARN'
    Write-Log "  (o corré esta consola como administrador). Despues re-corré el bootstrap." 'WARN'
    $WARNINGS.Add("Modo de desarrollador desactivado: los symlinks pueden no crearse")
} else {
    Write-Log "Modo de desarrollador activado (symlinks sin admin)" 'OK'
}
Sub-Bar 100 "requisitos verificados"

# ==============================================================================
# 2. INSTALAR PAQUETES WINGET
# ==============================================================================

Step-Bar 2 "Instalando paquetes"

# El selector pide pantalla completa: pausar la barra mientras se elige.
Suspend-Bar
# Resolver que herramientas instalar (-Tools / -AllTools / menu / red de seguridad)
Resolve-SelectedTools

if ($SkipWinget) {
    Step-Bar 2 "Instalando paquetes"
    Write-Log "SkipWinget activado, saltando instalacion de paquetes" 'SKIP'
} elseif ($script:SELECTED_KEYS.Count -eq 0) {
    Step-Bar 2 "Instalando paquetes"
    Write-Log "No se selecciono ninguna herramienta, saltando instalacion" 'SKIP'
} else {
    if (-not (Test-WingetAvailable)) {
        Step-Bar 2 "Instalando paquetes"
        Write-Log "winget no disponible, saltando paquetes" 'WARN'
    } else {
        # Retomar la barra ya con la seleccion hecha.
        Step-Bar 2 "Instalando paquetes"
        # Actualizar fuentes de winget primero
        Invoke-Step "Actualizar fuentes winget" {
            winget source update 2>&1 | Out-Null
        }

        # Solo iteramos los paquetes seleccionados, para que el % avance parejo.
        $wingetSel = @($WINGET_PACKAGES | Where-Object { Test-ToolSelected $_.Key })
        $wingetTot = [Math]::Max($wingetSel.Count, 1)
        $wingetIdx = 0
        foreach ($pkg in $wingetSel) {
            $wingetIdx++
            Sub-Bar ([int]($wingetIdx * 100 / $wingetTot)) $pkg.Name
            # WSL se instala diferente y su salida streamea: pausar la barra.
            if ($pkg.Id -eq 'Canonical.Ubuntu.2204') {
                if ($DryRun) {
                    Write-Log "[DryRun] wsl --install -d Ubuntu-22.04" 'SKIP'
                } else {
                    $wslCheck = wsl -l -v 2>$null | Select-String 'Ubuntu'
                    if ($wslCheck) {
                        Write-Log "WSL Ubuntu ya instalado, saltando" 'SKIP'
                    } else {
                        Suspend-Bar
                        Invoke-Step "Instalar WSL Ubuntu 22.04" {
                            wsl --install -d Ubuntu-22.04
                        }
                        Sub-Bar ([int]($wingetIdx * 100 / $wingetTot)) $pkg.Name
                    }
                }
                continue
            }
            Install-WingetPackage -Id $pkg.Id -Name $pkg.Name -Optional $pkg.Optional

            # yazi arrastra sus dependencias de preview (bundle): sin estas, yazi
            # funciona pero no previsualiza PDF/video/imagenes ni entra a comprimidos.
            #   poppler     -> preview de PDF (pdftoppm)
            #   ffmpeg      -> thumbnails de video/audio
            #   imagemagick -> mas formatos de imagen y mejor calidad (via Sixel)
            #   7zip        -> preview/navegacion dentro de .zip/.7z/.tar
            # OJO: algunas descargas vienen de GitHub releases y el proxy corporativo
            # puede bloquearlas; si pasa, quedan como WARN y se instalan a mano.
            # NOTA (paridad con Linux): en Linux se suma 'chafa' como fallback de
            # preview de imagen porque Ptyxis no soporta Sixel. Aca NO hace falta:
            # Windows Terminal soporta Sixel (>=1.22), asi que yazi usa Sixel directo
            # y chafa (que ademas no tiene paquete confiable en winget) no aplica.
            if ($pkg.Key -eq 'yazi') {
                $yaziDeps = @(
                    @{ Id='oschwartz10612.Poppler';    Name='poppler (yazi: PDF)'         }
                    @{ Id='Gyan.FFmpeg';               Name='ffmpeg (yazi: video)'        }
                    @{ Id='ImageMagick.ImageMagick';   Name='ImageMagick (yazi: imagenes)' }
                    @{ Id='7zip.7zip';                 Name='7-Zip (yazi: comprimidos)'   }
                )
                foreach ($dep in $yaziDeps) {
                    Install-WingetPackage -Id $dep.Id -Name $dep.Name -Optional $true
                }
            }
        }
    }
}

# ==============================================================================
# 3. HERRAMIENTAS CON INSTALACION PROPIA (Codex, Claude Code, FiraCode)
# ==============================================================================

Step-Bar 3 "Codex, Claude y FiraCode"

if ($SkipWinget) {
    Write-Log "SkipWinget activado, saltando" 'SKIP'
} else {
    # --- Codex CLI ---
    Sub-Bar 20 "codex"
    if (-not (Test-ToolSelected 'codex')) {
        Write-Log "Codex CLI no seleccionado, saltando" 'SKIP'
    } elseif (Test-CommandAvailable 'codex') {
        Write-Log "Codex CLI ya instalado" 'SKIP'
    } else {
        Install-WingetPackage -Id 'OpenAI.Codex' -Name 'Codex CLI' -Optional $false
        Write-Log "  Nota: para instalar Codex Desktop ejecuta 'codex app' (descarga el instalador automaticamente)" 'INFO'
    }

    # --- Claude Code ---
    Sub-Bar 40 "claude"
    if (-not (Test-ToolSelected 'claude')) {
        Write-Log "Claude Code no seleccionado, saltando" 'SKIP'
    } elseif (Test-CommandAvailable 'claude') {
        Write-Log "Claude Code ya instalado" 'SKIP'
    } else {
        # Paquete winget oficial. Nota: winget no auto-actualiza Claude Code;
        # se actualiza con 'winget upgrade Anthropic.ClaudeCode'.
        Install-WingetPackage -Id 'Anthropic.ClaudeCode' -Name 'Claude Code' -Optional $false
    }

    # --- FiraCode Nerd Font ---
    # Replica lo que hace Linux: baja el zip de nerd-fonts y registra los .ttf
    # para el usuario actual (sin admin). La terminal ya usa 'FiraCode Nerd Font'.
    Sub-Bar 65 "firacode"
    if (-not (Test-ToolSelected 'firacode')) {
        Write-Log "FiraCode Nerd Font no seleccionada, saltando" 'SKIP'
    } else {
        $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        $fontInstalled = Test-Path (Join-Path $fontDir 'FiraCodeNerdFont-Regular.ttf')
        if ($fontInstalled) {
            Write-Log "FiraCode Nerd Font ya instalada" 'SKIP'
        } elseif ($DryRun) {
            Write-Log "[DryRun] Descargar e instalar FiraCode Nerd Font" 'SKIP'
        } else {
            Invoke-Step "Instalar FiraCode Nerd Font" {
                $zip = Join-Path $env:TEMP 'FiraCode.zip'
                $ext = Join-Path $env:TEMP 'FiraCode-NerdFont'
                Invoke-WebRequest -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip' -OutFile $zip -UseBasicParsing
                if (Test-Path $ext) { Remove-Item $ext -Recurse -Force }
                Expand-Archive -Path $zip -DestinationPath $ext -Force

                New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
                $shell = New-Object -ComObject Shell.Application
                $regKey = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
                if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }

                foreach ($ttf in Get-ChildItem -Path $ext -Filter '*.ttf' -File) {
                    $dest = Join-Path $fontDir $ttf.Name
                    Copy-Item -LiteralPath $ttf.FullName -Destination $dest -Force
                    # Nombre de fuente para el registro (sin admin -> HKCU)
                    $fontName = $shell.Namespace($ext).ParseName($ttf.Name).ExtendedProperty('System.Title')
                    if (-not $fontName) { $fontName = $ttf.BaseName }
                    Set-ItemProperty -Path $regKey -Name "$fontName (TrueType)" -Value $dest -ErrorAction SilentlyContinue
                }
                Remove-Item $zip -Force -ErrorAction SilentlyContinue
                Remove-Item $ext -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # --- lazyssh (TUI para SSH) ---
    # No esta en winget/scoop: se baja el binario del release oficial a
    # ~/.local/bin (igual que en Linux) y se agrega ese dir al PATH de usuario.
    Sub-Bar 90 "lazyssh"
    if (-not (Test-ToolSelected 'lazyssh')) {
        Write-Log "lazyssh no seleccionado, saltando" 'SKIP'
    } elseif (Test-CommandAvailable 'lazyssh') {
        Write-Log "lazyssh ya instalado" 'SKIP'
    } elseif ($DryRun) {
        Write-Log "[DryRun] Descargar e instalar lazyssh" 'SKIP'
    } else {
        Invoke-Step "Instalar lazyssh (binario)" {
            $binDir = Join-Path $HOME '.local\bin'
            New-Item -ItemType Directory -Path $binDir -Force | Out-Null
            $tag = (Invoke-RestMethod -Uri 'https://api.github.com/repos/Adembc/lazyssh/releases/latest').tag_name
            $zip = Join-Path $env:TEMP 'lazyssh.zip'
            $ext = Join-Path $env:TEMP 'lazyssh-extract'
            $arch = if ([Environment]::Is64BitOperatingSystem) { 'x86_64' } else { 'i386' }
            Invoke-WebRequest -Uri "https://github.com/Adembc/lazyssh/releases/download/$tag/lazyssh_Windows_$arch.zip" -OutFile $zip -UseBasicParsing
            if (Test-Path $ext) { Remove-Item $ext -Recurse -Force }
            Expand-Archive -Path $zip -DestinationPath $ext -Force
            Copy-Item -LiteralPath (Join-Path $ext 'lazyssh.exe') -Destination (Join-Path $binDir 'lazyssh.exe') -Force
            Remove-Item $zip -Force -ErrorAction SilentlyContinue
            Remove-Item $ext -Recurse -Force -ErrorAction SilentlyContinue

            # Asegurar que ~/.local/bin este en el PATH de usuario
            $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
            if ($userPath -notlike "*$binDir*") {
                [Environment]::SetEnvironmentVariable('Path', "$userPath;$binDir", 'User')
                $env:Path += ";$binDir"
                Write-Log "  Agregado $binDir al PATH de usuario (reinicia la terminal)" 'INFO'
            }
        }
    }
}

# ==============================================================================
# 4. INSTALAR MODULOS DE POWERSHELL
# ==============================================================================

Step-Bar 4 "Módulos de PowerShell"

if ($SkipModules) {
    Write-Log "SkipModules activado, saltando módulos" 'SKIP'
} else {
    $modTot = [Math]::Max($PS_MODULES.Count, 1); $modIdx = 0
    foreach ($mod in $PS_MODULES) {
        $modIdx++
        Sub-Bar ([int]($modIdx * 100 / $modTot)) $mod
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
# 5. CREAR ESTRUCTURA DE CARPETAS
# ==============================================================================

Step-Bar 5 "Creando carpetas"

$dirTot = [Math]::Max($DIRS.Count, 1); $dirIdx = 0
foreach ($dir in $DIRS) {
    $dirIdx++
    $dirShort = $dir.Replace($HOME, '~')
    if (Test-Path $dir) {
        Sub-Bar ([int]($dirIdx * 100 / $dirTot)) "validando $dirShort"
        Write-Log "$dir ya existe, saltando" 'SKIP'
    } else {
        Sub-Bar ([int]($dirIdx * 100 / $dirTot)) "creando $dirShort"
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
# 6. MIGRAR BACKUPS VIEJOS (.bak-*) → BACKUP_DIR
# ==============================================================================

Step-Bar 6 "Migrando backups viejos"
Sub-Bar 50 "buscando backups previos"

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
# 7. COPIAR DOTFILES
# ==============================================================================

Step-Bar 7 "Copiando dotfiles"

if ($SkipDotfiles) {
    Write-Log "SkipDotfiles activado, saltando dotfiles" 'SKIP'
} else {
    Sub-Bar 15 "symlinks y configs"
    $dfTot = [Math]::Max($DOTFILES.Count, 1); $dfIdx = 0
    foreach ($df in $DOTFILES) {
        $dfIdx++
        Sub-Bar ([int]($dfIdx * 60 / $dfTot)) "$($df.Src)"
        # Resolver raiz: 'vault' (privado) o repo publico por defecto.
        # OJO: $df es un hashtable — sus claves NO son propiedades PSObject
        # (PSObject.Properties['Root'] da siempre $null); hay que usar ContainsKey.
        $root = if ($df.ContainsKey('Root') -and $df.Root -eq 'vault') { $VAULT_DIR } else { $REPO_ROOT }
        $src = Join-Path $root $df.Src
        $dst = $df.Dst

        if (-not (Test-Path $src)) {
            if ($df.ContainsKey('Root') -and $df.Root -eq 'vault') {
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

    # --- Reglas globales de agentes IA: AGENTS.md para Codex/opencode ---
    # El MISMO .claude\CLAUDE.md rige para todos los agentes: Codex y opencode
    # leen AGENTS.md (fuente unica, paridad con bootstrap.sh). Solo si el CLI
    # esta instalado.
    Sub-Bar 62 "reglas de agentes IA"
    $agentsSrc  = Join-Path $REPO_ROOT '.claude\CLAUDE.md'
    $agentsDsts = @()
    if (Test-CommandAvailable 'codex')    { $agentsDsts += (Join-Path $HOME '.codex\AGENTS.md') }
    if (Test-CommandAvailable 'opencode') { $agentsDsts += (Join-Path $HOME '.config\opencode\AGENTS.md') }
    foreach ($agDst in $agentsDsts) {
        $agItem   = if (Test-Path $agDst) { Get-Item -LiteralPath $agDst -Force } else { $null }
        $agIsLink = $agItem -and ($agItem.LinkType -eq 'SymbolicLink')
        if ($agIsLink -and $agItem.Target -eq $agentsSrc) {
            Write-Log "AGENTS.md ya symlinkeado ($agDst), saltando" 'SKIP'
        } elseif ($DryRun) {
            Write-Log "[DryRun] Symlink AGENTS.md → $agDst" 'SKIP'
        } else {
            $agDir = Split-Path $agDst
            if (-not (Test-Path $agDir)) { New-Item -ItemType Directory -Path $agDir -Force | Out-Null }
            Invoke-Step "Symlink AGENTS.md → $agDst" {
                if (Test-Path $agDst) { Remove-Item -LiteralPath $agDst -Force }
                New-Item -ItemType SymbolicLink -Path $agDst -Target $agentsSrc | Out-Null
            }
        }
    }

    # --- Neovim: config completa versionada (nvim/) ---
    # Symlink de DIRECTORIO a %LOCALAPPDATA%\nvim (path de nvim en Windows;
    # paridad con el link_dir de bootstrap.sh). Si habia config real previa,
    # se mueve entera al backup centralizado.
    Sub-Bar 65 "config de nvim"
    $nvimSrc = Join-Path $REPO_ROOT 'nvim'
    $nvimDst = Join-Path $env:LOCALAPPDATA 'nvim'
    if (Test-Path $nvimSrc) {
        $nvimItem   = if (Test-Path $nvimDst) { Get-Item -LiteralPath $nvimDst -Force } else { $null }
        $nvimIsLink = $nvimItem -and ($nvimItem.LinkType -eq 'SymbolicLink')
        if ($nvimIsLink -and $nvimItem.Target -eq $nvimSrc) {
            Write-Log "Config de nvim ya symlinkeada al repo, saltando" 'SKIP'
        } elseif ($DryRun) {
            Write-Log "[DryRun] Symlink nvim → $nvimDst" 'SKIP'
        } else {
            if ($nvimItem -and -not $nvimIsLink) {
                Invoke-Step "Backup $nvimDst → $BACKUP_DIR\nvim" {
                    Move-Item -LiteralPath $nvimDst -Destination (Join-Path $BACKUP_DIR 'nvim') -Force
                }
            } elseif ($nvimIsLink) {
                Remove-Item -LiteralPath $nvimDst -Force
            }
            Invoke-Step "Symlink nvim → $nvimDst" {
                New-Item -ItemType SymbolicLink -Path $nvimDst -Target $nvimSrc | Out-Null
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

        # NOTA: el auto-upgrade de oh-my-posh en Windows (MSIX no lo soporta) NO se
        # desactiva aca. 'oh-my-posh disable upgrade' no gana contra el auto:true
        # explicito del tema, que se relee en cada 'init --config'. El fix real vive
        # en profile.ps1: deriva una copia local del tema con upgrade apagado y
        # arranca contra ella (ver el bloque PROMPT & ESTETICA).
    }

    # --- SSH keys (encriptadas con age, en el vault privado) ---
    $sshKeysDir = Join-Path $VAULT_DIR "ssh\keys"
    $ageFiles = Get-ChildItem -Path $sshKeysDir -Filter "*.age" -File -ErrorAction SilentlyContinue

    Sub-Bar 70 "claves SSH"
    if ($ageFiles) {
        if (Test-CommandAvailable 'age') {
            # age NO lee la passphrase de stdin: la pide SIEMPRE de la consola
            # (igual que en Linux, ver vault-sync). Pasarla por pipe no funciona,
            # asi que se deja que age pregunte por cada clave FALTANTE (normalmente
            # falta 0-1, no molesta). La interaccion va fuera de la barra.
            $missingKeys = @($ageFiles | Where-Object { -not (Test-Path "$HOME\.ssh\$($_.BaseName)") })
            if ($missingKeys.Count -gt 0 -and -not $DryRun) {
                Suspend-Bar
                Write-Host "  Desencriptando claves SSH que faltan ($($missingKeys.Count)) — age pide la passphrase por cada una..."
            }

            foreach ($ageFile in $ageFiles) {
                $keyName = $ageFile.BaseName
                $dstKey  = "$HOME\.ssh\$keyName"

                if (Test-Path $dstKey) {
                    Write-Log "~/.ssh/$keyName ya existe, saltando" 'SKIP'
                } elseif ($DryRun) {
                    Write-Log "[DryRun] Desencriptar $keyName → ~/.ssh/$keyName" 'SKIP'
                } else {
                    Invoke-Step "Desencriptar $keyName → ~/.ssh/$keyName" {
                        age -d -o $dstKey $ageFile.FullName
                        if ($LASTEXITCODE -ne 0) {
                            Remove-Item -LiteralPath $dstKey -Force -ErrorAction SilentlyContinue
                            throw "Passphrase incorrecta o error de age"
                        }
                    }
                }
            }

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
    Sub-Bar 95 "limpieza de residuales"
    # .condarc residual
    $condarc = Join-Path $HOME ".condarc"
    if (Test-Path $condarc) {
        Invoke-Step "Eliminar .condarc residual" {
            Remove-Item $condarc -Force -ErrorAction SilentlyContinue
        }
    }
}

# ==============================================================================
# 8. CONFIGURAR AWS SSO (OPCIONAL)
# ==============================================================================

Step-Bar 8 "Configuración AWS SSO"

# Si no vino -WithAws pero es una sesion interactiva, preguntar: así el instalador
# GUÍA (en vez de exigir conocer el flag). En headless se saltea igual que antes.
if (-not $WithAws -and (Test-Interactive)) {
    Suspend-Bar
    Write-Host ''
    Write-Host "  $($script:C_SECT)▶ Claude Code con Bedrock (AWS SSO)$($script:C_RESET)"
    $awsAns = Read-Host "  ¿Configurar el acceso AWS/Bedrock para claude-smg? [s/N]"
    if ($awsAns -match '^[sSyY]') { $WithAws = $true }
}

if (-not $WithAws) {
    Sub-Bar 100 "saltado"
    Write-Log "Saltando configuración AWS (configurable luego con -WithAws)" 'SKIP'
} elseif (-not (Test-CommandAvailable 'aws')) {
    Suspend-Bar
    Write-Log "AWS CLI no está instalado, saltando configuración SSO" 'WARN'
    $WARNINGS.Add("AWS CLI no encontrado — instalalo y ejecutá 'aws configure sso' manualmente")
} else {
    # AWS con certificados + login por navegador: todo interactivo/verboso -> fuera
    # de la barra.
    Suspend-Bar
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

            # Buscar cacert.pem o descargarlo. OJO: descargar justamente un CA
            # bundle con la verificacion TLS apagada (curl -k) seria lo peor;
            # Invoke-WebRequest usa el cert store de Windows, que ya confia en
            # el certificado de Netskope, asi que valida el TLS sin -k.
            $cacert = Get-ChildItem -Path "$HOME\.vscode\extensions" -Recurse -Filter "cacert.pem" `
                        -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
            if (-not $cacert) {
                Write-Log "cacert.pem no encontrado en VSCode, descargando..." 'WARN'
                Invoke-WebRequest -Uri 'https://curl.se/ca/cacert.pem' -OutFile "$HOME\cacert.pem" -UseBasicParsing
                $cacert = "$HOME\cacert.pem"
            }

            Get-Content "$HOME\netskope-root.pem", $cacert | Set-Content "$HOME\combined-ca.pem"
            [System.Environment]::SetEnvironmentVariable("AWS_CA_BUNDLE", "$HOME\combined-ca.pem", "User")
            Write-Log "AWS_CA_BUNDLE configurado: $HOME\combined-ca.pem" 'OK'
        }
    } else {
        Write-Log "Cert Netskope no encontrado — máquina sin Netskope, SSL de AWS debería funcionar directo" 'INFO'
    }

    # Datos de la org (cuenta, portal SSO, rol) NO se versionan: son infra
    # privada. Se leen de ~/.env (KEY=VALUE). Sin ellos no hay que preconfigurar.
    $ssoStartUrl  = $env:AWS_SSO_START_URL
    $ssoAccountId = $env:AWS_SSO_ACCOUNT_ID
    $ssoRoleName  = if ($env:AWS_SSO_ROLE_NAME) { $env:AWS_SSO_ROLE_NAME } else { "Bedrock_Access" }
    $ssoRegion    = if ($env:AWS_SSO_REGION)    { $env:AWS_SSO_REGION }    else { "us-east-1" }
    # Nombre del perfil (y sso-session) que se escribe en ~/.aws/config; el mismo
    # que consume claude-smg. Cada usuario pone el suyo en ~/.env
    # (AWS_SSO_PROFILE=elteruel); fallback a CLAUDE_SMG_AWS_PROFILE (compat) y 'default'.
    $ssoProfile   = if ($env:AWS_SSO_PROFILE) { $env:AWS_SSO_PROFILE } elseif ($env:CLAUDE_SMG_AWS_PROFILE) { $env:CLAUDE_SMG_AWS_PROFILE } else { "default" }
    # Perfiles adicionales bajo la misma sso-session (formato ver más abajo).
    $ssoExtraProfiles = $env:AWS_EXTRA_PROFILES
    $envFileAws   = Join-Path $HOME ".env"
    if (Test-Path $envFileAws) {
        Get-Content $envFileAws | ForEach-Object {
            if ($_ -match '^\s*AWS_SSO_START_URL\s*=\s*(.+?)\s*$')  { $ssoStartUrl  = $Matches[1].Trim('"').Trim("'") }
            if ($_ -match '^\s*AWS_SSO_ACCOUNT_ID\s*=\s*(.+?)\s*$') { $ssoAccountId = $Matches[1].Trim('"').Trim("'") }
            if ($_ -match '^\s*AWS_SSO_ROLE_NAME\s*=\s*(.+?)\s*$')  { $ssoRoleName  = $Matches[1].Trim('"').Trim("'") }
            if ($_ -match '^\s*AWS_SSO_REGION\s*=\s*(.+?)\s*$')     { $ssoRegion    = $Matches[1].Trim('"').Trim("'") }
            if ($_ -match '^\s*AWS_SSO_PROFILE\s*=\s*(.+?)\s*$')    { $ssoProfile   = $Matches[1].Trim('"').Trim("'") }
            if ($_ -match '^\s*AWS_EXTRA_PROFILES\s*=\s*(.+?)\s*$') { $ssoExtraProfiles = $Matches[1].Trim('"').Trim("'") }
        }
    }

    # Faltan datos obligatorios y hay tty -> pedirlos y persistirlos al ~/.env
    # (así claude-smg y futuras corridas ya los tienen; la org no se versiona).
    if ((-not $ssoAccountId -or -not $ssoStartUrl) -and (Test-Interactive)) {
        Write-Log "Faltan datos de AWS SSO en ~/.env — te los pido ahora" 'INFO'
        if (-not $ssoStartUrl)  { $ssoStartUrl  = Read-Host "  Portal SSO (ej: https://tu-org.awsapps.com/start/#)" }
        if (-not $ssoAccountId) { $ssoAccountId = Read-Host "  Account ID" }
        $r = Read-Host "  Rol [$ssoRoleName]";        if ($r) { $ssoRoleName = $r }
        $p = Read-Host "  Tu usuario/perfil [$ssoProfile]"; if ($p) { $ssoProfile = $p }

        # Persistir solo las claves que aún no estén en ~/.env (evita duplicados).
        if ($ssoStartUrl -and $ssoAccountId) {
            if (-not (Test-Path $envFileAws)) { New-Item -ItemType File -Path $envFileAws -Force | Out-Null }
            # OJO: el cast [string] no es decorativo. Get-Content -Raw sobre un
            # archivo VACIO (el que se acaba de crear arriba) devuelve $null, y
            # PowerShell trata el $null de un cmdlet como coleccion: ahi
            # '-notmatch' FILTRA en vez de comparar y devuelve un Object[] vacio,
            # que en un 'if' es falso. Resultado: no se agregaba ni una clave,
            # el ~/.env quedaba vacio pese al "Datos AWS guardados" y claude-smg
            # caia al perfil 'default' inexistente. Con [string] es '' y compara.
            $envTxt = [string](Get-Content $envFileAws -Raw -ErrorAction SilentlyContinue)
            $toAdd = [System.Collections.Generic.List[string]]::new()
            if ($envTxt -notmatch '(?m)^AWS_SSO_START_URL=')  { $toAdd.Add("AWS_SSO_START_URL=$ssoStartUrl") }
            if ($envTxt -notmatch '(?m)^AWS_SSO_ACCOUNT_ID=') { $toAdd.Add("AWS_SSO_ACCOUNT_ID=$ssoAccountId") }
            if ($envTxt -notmatch '(?m)^AWS_SSO_ROLE_NAME=')  { $toAdd.Add("AWS_SSO_ROLE_NAME=$ssoRoleName") }
            if ($envTxt -notmatch '(?m)^AWS_SSO_REGION=')     { $toAdd.Add("AWS_SSO_REGION=$ssoRegion") }
            if ($envTxt -notmatch '(?m)^AWS_SSO_PROFILE=')    { $toAdd.Add("AWS_SSO_PROFILE=$ssoProfile") }
            if ($toAdd.Count -gt 0) {
                Add-Content -Path $envFileAws -Value ("`n# AWS SSO (Bedrock) — agregado por bootstrap`n" + ($toAdd -join "`n"))
                Write-Log "Datos AWS guardados en ~/.env" 'OK'
            }
        }
    }

    if (-not $ssoAccountId -or -not $ssoStartUrl) {
        Write-Log "Faltan AWS_SSO_START_URL / AWS_SSO_ACCOUNT_ID en ~/.env — salteo preconfig SSO" 'WARN'
        $WARNINGS.Add("AWS SSO sin preconfigurar: defini AWS_SSO_START_URL, AWS_SSO_ACCOUNT_ID (y opcional AWS_SSO_ROLE_NAME) en ~/.env")
    } else {
        # Escribo ~/.aws/config con formato sso-session: habilita el flujo PKCE
        # (login por navegador sin codigo de 6 digitos). 'aws configure set' no
        # sabe escribir bloques [sso-session], por eso se escribe el archivo.
        Invoke-Step "Pre-configurar perfil AWS SSO '$ssoProfile' (formato sso-session/PKCE)" {
            $awsDir = Join-Path $HOME ".aws"
            New-Item -ItemType Directory -Force -Path $awsDir | Out-Null
            # AWS nombra distinto el perfil default ([default]) y los nombrados
            # ([profile X]); la sso-session siempre es [sso-session X].
            $profileHeader = if ($ssoProfile -eq 'default') { '[default]' } else { "[profile $ssoProfile]" }
            $cfg = @"
[sso-session $ssoProfile]
sso_start_url = $ssoStartUrl
sso_region = $ssoRegion
sso_registration_scopes = sso:account:access

$profileHeader
sso_session = $ssoProfile
sso_account_id = $ssoAccountId
sso_role_name = $ssoRoleName
region = $ssoRegion
output = json
"@
            # Perfiles adicionales bajo la MISMA sso-session (reusan el login).
            # Formato en ~/.env: AWS_EXTRA_PROFILES="perfil:cuenta:rol[:region];..."
            # Ej: "pre:111111111111:MiRol;prod:222222222222:MiRol"
            $extraN = 0
            if ($ssoExtraProfiles) {
                foreach ($p in ($ssoExtraProfiles -split ';')) {
                    if (-not $p.Trim()) { continue }
                    $parts = $p.Trim() -split ':'
                    if ($parts.Count -lt 3 -or -not $parts[0] -or -not $parts[1] -or -not $parts[2]) {
                        Write-Log "AWS_EXTRA_PROFILES: entrada inválida '$p' (falta perfil/cuenta/rol) — la salteo" 'WARN'
                        continue
                    }
                    $preg = if ($parts.Count -ge 4 -and $parts[3]) { $parts[3] } else { $ssoRegion }
                    $cfg += @"

[profile $($parts[0])]
sso_session = $ssoProfile
sso_account_id = $($parts[1])
sso_role_name = $($parts[2])
region = $preg
output = json
"@
                    $extraN++
                }
            }
            Set-Content -Path (Join-Path $awsDir "config") -Value $cfg -Encoding ascii
            if ($extraN -gt 0) { Write-Log "Perfiles AWS extra pre-configurados: $extraN" 'OK' }
        }

        if ($DryRun) {
            Write-Log "[DryRun] Saltando aws sso login" 'SKIP'
        } else {
            Write-Log "Iniciando AWS SSO login (se abrirá el navegador)..." 'INFO'
            aws sso login --profile $ssoProfile
            if ($LASTEXITCODE -eq 0) {
                Write-Log "AWS SSO login completado exitosamente" 'OK'
            } else {
                Write-Log "AWS SSO login falló o fue cancelado" 'WARN'
                $WARNINGS.Add("AWS SSO login incompleto — correr 'aws sso login --profile $ssoProfile'")
            }
        }
    }
}

# ==============================================================================
# 9. CONFIGURAR PROFILE DE POWERSHELL + VALIDACIONES
# ==============================================================================

Step-Bar 9 "Perfil de PowerShell y validaciones"
Sub-Bar 20 "configurando `$PROFILE"

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

# --- Validaciones post-bootstrap (parte del paso 9) ---
Sub-Bar 70 "validaciones post-bootstrap"

$testScript = Join-Path $REPO_ROOT "test-bootstrap.ps1"
if (Test-Path $testScript) {
    if ($DryRun) {
        Write-Log "[DryRun] pwsh -File $testScript" 'SKIP'
    } else {
        # Anti-choclo: capturar la salida completa al log; en pantalla solo el
        # resumen (como hito arriba de la barra). Los fallos siempre se muestran.
        $testOut = & pwsh -File $testScript 2>&1
        $testExit = $LASTEXITCODE
        Add-Content -Path $LOG_FILE -Value ($testOut -join "`n") -ErrorAction SilentlyContinue
        Sub-Bar 90 "validaciones post-bootstrap"
        if ($testExit -ne 0) {
            Write-Log "Validaciones post-bootstrap: hay fallos (exit $testExit) — detalle en el log" 'WARN'
            $WARNINGS.Add("Validaciones post-bootstrap con fallos — revisar el log")
        } else {
            Note-Bar $script:C_OK $script:ICONS.Ok "validaciones post-bootstrap OK   (detalle en el log)"
        }
    }
} else {
    Write-Log "test-bootstrap.ps1 no encontrado en $REPO_ROOT" 'WARN'
}

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================

# Cierra la barra global al 100% y la limpia: lo que sigue es el resumen.
Complete-Bar
Add-Content -Path $LOG_FILE -Value "[$(Get-Date -Format 'HH:mm:ss')] === Resumen final ===" -ErrorAction SilentlyContinue

# Titular segun resultado (espejo del resumen de bootstrap.sh)
if ($ERRORS.Count -eq 0) {
    Write-Host "  $($script:C_SECT)$($script:ICONS.Ok) Bootstrap completado$($script:C_RESET)"
} else {
    Write-Host "  $($script:C_ERR)$($script:ICONS.Err) Bootstrap terminó con $($ERRORS.Count) error(es)$($script:C_RESET)"
}

# Warnings/errores destacados (siempre visibles)
if ($WARNINGS.Count -gt 0) {
    Write-Host ''
    Write-Host "  ⚠ Advertencias ($($WARNINGS.Count)):" -ForegroundColor DarkYellow
    foreach ($w in $WARNINGS) { Write-Host "    · $w" -ForegroundColor DarkYellow }
}
if ($ERRORS.Count -gt 0) {
    Write-Host ''
    Write-Host "  ✗ Errores ($($ERRORS.Count)):" -ForegroundColor Red
    foreach ($e in $ERRORS) { Write-Host "    · $e" -ForegroundColor Red }
}

Write-Host ''
Write-Host "    Log:     $LOG_FILE" -ForegroundColor DarkGray
Write-Host "    Backups: $BACKUP_DIR" -ForegroundColor DarkGray

Write-Host ''
Write-Host "$($script:C_SECT)$($script:ICONS.Section) Proximos pasos manuales$($script:C_RESET)"
$stepNum = 1
Write-Host "    $($script:C_DIM)$stepNum. Abri una terminal nueva para recargar el profile$($script:C_RESET)"
$stepNum++
if ($WithAws) {
    Write-Host "    $($script:C_DIM)$stepNum. Ejecuta: aws configure sso (completar datos de SMG)$($script:C_RESET)"
    $stepNum++
    Write-Host "    $($script:C_DIM)$stepNum. Ejecuta: aws sts get-caller-identity --profile tu_usuario$($script:C_RESET)"
    $stepNum++
}
Write-Host "    $($script:C_DIM)$stepNum. Verifica tus claves SSH: ssh -T git@github.com-kevincharp$($script:C_RESET)"
