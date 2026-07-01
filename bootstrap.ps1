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
    [switch]$SkipDotfiles,    # saltear copia de dotfiles
    [string]$Tools = '',      # instalar solo estas herramientas (csv de keys); vacio = preguntar
    [switch]$AllTools         # instalar todo el catalogo sin preguntar
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
    @{ Id='Neovim.Neovim';                  Name='Neovim';                  Optional=$false; Key='neovim';           Group='core'   }
    @{ Id='BurntSushi.ripgrep.MSVC';        Name='ripgrep';                 Optional=$false; Key='ripgrep';          Group='core'   }
    @{ Id='junegunn.fzf';                   Name='fzf';                     Optional=$false; Key='fzf';              Group='core'   }
    @{ Id='JanDeDobbeleer.OhMyPosh';        Name='Oh My Posh';              Optional=$false; Key='oh-my-posh';       Group='shell'  }
    @{ Id='ajeetdsouza.zoxide';             Name='zoxide';                  Optional=$false; Key='zoxide';           Group='shell'  }
    @{ Id='JesseDuffield.lazygit';          Name='LazyGit';                 Optional=$false; Key='lazygit';          Group='shell'  }
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
    # Claude Code (settings.json por symlink: se versiona al editar en el repo.
    # Modelo por defecto sonnet; los cambios de modelo se hacen en sesion.
    # settings.local.json queda copia: es per-maquina.)
    @{ Src='.claude\settings.json';         Dst="$HOME\.claude\settings.json"         ; Mode='link' }
    @{ Src='.claude\settings.local.json';   Dst="$HOME\.claude\settings.local.json"   }
)

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
    $fs = [System.IO.File]::Open('CONIN$', 'Open', 'Read', 'ReadWrite')
    $reader = [System.IO.StreamReader]::new($fs)
    try { return $reader.ReadLine() } finally { $reader.Dispose() }
}

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    # Al archivo siempre con timestamp y nivel (traza completa)
    $ts = Get-Date -Format 'HH:mm:ss'
    Add-Content -Path $LOG_FILE -Value "[$ts][$Level] $Message" -ErrorAction SilentlyContinue

    # A pantalla: iconos + jerarquia
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
# SELECTOR DE HERRAMIENTAS
# ------------------------------------------------------------------------------
# Espejo del selector de bootstrap.sh. Deja en $script:SELECTED_KEYS las Keys
# del catalogo a instalar. Prioridad:
#   1. -Tools "a,b,c"  -> exactamente esas (valida contra el catalogo)
#   2. -AllTools / -DryRun -> todo, sin preguntar
#   3. consola interactiva -> menu agrupado, pregunta siempre
#   4. sin consola (irm | iex no interactivo) -> todo, como red de seguridad
# El menu arranca con TODO pre-marcado: Enter = instalar todo.
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
    # Estado de marcado por Key (nada pre-marcado: el usuario elige que instalar).
    $marked = @{}
    foreach ($k in $keys) { $marked[$k] = $false }

    # Filas navegables en orden de display (solo herramientas, no headers)
    $rows = @()
    foreach ($g in $groups) {
        foreach ($t in ($TOOLS_CATALOG | Where-Object { $_.Group -eq $g })) {
            $rows += [pscustomobject]@{ Key = $t.Key; Name = $t.Name; Group = $g }
        }
    }
    $m = $rows.Count

    # Si la consola no soporta ReadKey crudo (host no interactivo), cae a texto.
    $rawOk = $true
    try { $null = $Host.UI.RawUI.KeyAvailable } catch { $rawOk = $false }
    if (-not $rawOk) { return Select-ToolsInteractiveText }

    # El titulo se pinta una sola vez (queda fijo arriba del menu).
    Write-Host ''
    Write-Host '  == Selector de herramientas ==' -ForegroundColor Cyan
    Write-Host '  ↑/↓ mover · espacio marcar · a todo · n nada · g grupo · Enter instalar' -ForegroundColor DarkGray
    Write-Host ''

    $cur = 0
    $firstDraw = $true
    $drawn = 0
    while ($true) {
        # --- Reposicionar cursor para redibujar en el lugar ---
        # Movimiento RELATIVO (subir $drawn lineas con ANSI), NO absoluto: el menu
        # es mas alto que la ventana y la consola scrollea, asi que una coordenada
        # absoluta (SetCursorPosition) quedaria desalineada y apilaria copias del
        # menu en cada tecla. Subir N lineas respeta el scroll y sobreescribe.
        if (-not $firstDraw) {
            Write-Host ("`e[$($drawn)A") -NoNewline
        }
        $firstDraw = $false

        # --- Pintar filas agrupadas (contando lineas para el proximo redibujo) ---
        $drawn = 0
        $prevG = ''
        for ($di = 0; $di -lt $m; $di++) {
            $row = $rows[$di]
            if ($row.Group -ne $prevG) {
                Write-Host ("  [{0}]" -f $row.Group).PadRight(60) -ForegroundColor White
                $prevG = $row.Group
                $drawn++
            }
            $box = if ($marked[$row.Key]) { '[x]' } else { '[ ]' }
            $ptr = if ($di -eq $cur) { '>' } else { ' ' }
            $color = if ($di -eq $cur) { 'Cyan' } elseif ($marked[$row.Key]) { 'Green' } else { 'Gray' }
            Write-Host ("  {0} {1} {2,-18} {3}" -f $ptr, $box, $row.Key, $row.Name).PadRight(60) -ForegroundColor $color
            $drawn++
        }

        # --- Leer tecla ---
        $k = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        switch ($k.VirtualKeyCode) {
            38 { $cur = ($cur - 1 + $m) % $m }                       # Up
            40 { $cur = ($cur + 1) % $m }                            # Down
            32 { $key = $rows[$cur].Key; $marked[$key] = (-not $marked[$key]) }  # Space
            13 { return @($keys | Where-Object { $marked[$_] }) }    # Enter
            default {
                switch ([char]$k.Character) {
                    'k' { $cur = ($cur - 1 + $m) % $m }
                    'j' { $cur = ($cur + 1) % $m }
                    'a' { foreach ($key in $keys) { $marked[$key] = $true } }
                    'n' { foreach ($key in $keys) { $marked[$key] = $false } }
                    'g' {
                        $cg = $rows[$cur].Group
                        $grpKeys = ($rows | Where-Object { $_.Group -eq $cg }).Key
                        $allOn = $true
                        foreach ($key in $grpKeys) { if (-not $marked[$key]) { $allOn = $false } }
                        foreach ($key in $grpKeys) { $marked[$key] = (-not $allOn) }
                    }
                    'q' { return @($keys | Where-Object { $marked[$_] }) }
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
        Write-Host '  == Selector de herramientas ==' -ForegroundColor Cyan
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
        Write-Log "Herramientas via -Tools: $($valid -join ', ')" 'INFO'
    } elseif ($AllTools -or $DryRun) {
        $script:SELECTED_KEYS = @($allKeys)
        Write-Log "Instalando catalogo completo ($($allKeys.Count) herramientas)" 'INFO'
    } elseif (Test-Interactive) {
        $script:SELECTED_KEYS = @(Select-ToolsInteractive)
        Write-Log "Seleccionadas $($script:SELECTED_KEYS.Count): $($script:SELECTED_KEYS -join ', ')" 'INFO'
    } else {
        $script:SELECTED_KEYS = @($allKeys)
        Write-Log 'Sin consola interactiva - instalando catalogo completo (red de seguridad)' 'INFO'
    }
}

# True si una Key fue seleccionada para instalar
function Test-ToolSelected {
    param([string]$Key)
    return ($script:SELECTED_KEYS -contains $Key)
}

# ==============================================================================
# INICIO
# ==============================================================================

# Asegurar que existe el directorio de logs antes de escribir
New-Item -ItemType Directory -Path (Split-Path $LOG_FILE) -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Path $BACKUP_DIR -Force -ErrorAction SilentlyContinue | Out-Null

Write-Log "bootstrap.ps1 — Setup de entorno" 'SECTION'
Write-Log "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')$(if ($DryRun) { '  ·  modo DryRun' })" 'INFO'
Write-Log "" 'INFO'
Write-Log "Instalaciones manuales requeridas antes de continuar" 'WARN'
Write-Log "Estos programas NO se instalan automaticamente (hay razones):" 'INFO'
Write-Log "1. VSCode System Installer (x64)" 'INFO'
Write-Log "   https://code.visualstudio.com/docs/?dv=win64user" 'INFO'
Write-Log "   Razon: el System Installer agrega 'code' al PATH global." 'INFO'
Write-Log "2. Python (instalador oficial amd64)" 'INFO'
Write-Log "   https://www.python.org/downloads/windows/" 'INFO'
Write-Log "   Razon: marca 'Add Python to PATH' - necesario para Neovim." 'INFO'
Write-Log "3. Git for Windows" 'INFO'
Write-Log "   https://gitforwindows.org/" 'INFO'
Write-Log "   Razon: el instalador permite configurar line endings y SSH." 'INFO'
Write-Log "" 'INFO'
Write-Log "Ya los instalaste? Si no, presiona Ctrl+C y hacelo primero." 'WARN'

if (-not $DryRun) { Write-Host "  Presiona Enter para continuar: " -NoNewline; [void](Read-Console) }

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

# Resolver que herramientas instalar (-Tools / -AllTools / menu / red de seguridad)
Resolve-SelectedTools

if ($SkipWinget) {
    Write-Log "SkipWinget activado, saltando instalacion de paquetes" 'SKIP'
} elseif ($script:SELECTED_KEYS.Count -eq 0) {
    Write-Log "No se selecciono ninguna herramienta, saltando instalacion" 'SKIP'
} else {
    if (-not (Test-WingetAvailable)) {
        Write-Log "winget no disponible, saltando paquetes" 'WARN'
    } else {
        # Actualizar fuentes de winget primero
        Invoke-Step "Actualizar fuentes winget" {
            winget source update 2>&1 | Out-Null
        }

        foreach ($pkg in $WINGET_PACKAGES) {
            # Saltar lo no seleccionado
            if (-not (Test-ToolSelected $pkg.Key)) {
                Write-Log "$($pkg.Name) no seleccionado, saltando" 'SKIP'
                continue
            }
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
# 3. HERRAMIENTAS CON INSTALACION PROPIA (Codex, Claude Code, FiraCode)
# ==============================================================================

Write-Log "--- [3/9] Codex CLI, Claude Code y FiraCode Nerd Font ---" 'SECTION'

if ($SkipWinget) {
    Write-Log "SkipWinget activado, saltando" 'SKIP'
} else {
    # --- Codex CLI ---
    if (-not (Test-ToolSelected 'codex')) {
        Write-Log "Codex CLI no seleccionado, saltando" 'SKIP'
    } elseif (Test-CommandAvailable 'codex') {
        Write-Log "Codex CLI ya instalado" 'SKIP'
    } else {
        Install-WingetPackage -Id 'OpenAI.Codex' -Name 'Codex CLI' -Optional $false
        Write-Log "  Nota: para instalar Codex Desktop ejecuta 'codex app' (descarga el instalador automaticamente)" 'INFO'
    }

    # --- Claude Code ---
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

        # NOTA: el auto-upgrade de oh-my-posh en Windows (MSIX no lo soporta) NO se
        # desactiva aca. 'oh-my-posh disable upgrade' no gana contra el auto:true
        # explicito del tema, que se relee en cada 'init --config'. El fix real vive
        # en profile.ps1: deriva una copia local del tema con upgrade apagado y
        # arranca contra ella (ver el bloque PROMPT & ESTETICA).
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

    # Datos de la org (cuenta, portal SSO, rol) NO se versionan: son infra
    # privada. Se leen de ~/.env (KEY=VALUE). Sin ellos no hay que preconfigurar.
    $ssoStartUrl  = $env:AWS_SSO_START_URL
    $ssoAccountId = $env:AWS_SSO_ACCOUNT_ID
    $ssoRoleName  = if ($env:AWS_SSO_ROLE_NAME) { $env:AWS_SSO_ROLE_NAME } else { "Bedrock_Access" }
    $ssoRegion    = if ($env:AWS_SSO_REGION)    { $env:AWS_SSO_REGION }    else { "us-east-1" }
    $envFileAws   = Join-Path $HOME ".env"
    if (Test-Path $envFileAws) {
        Get-Content $envFileAws | ForEach-Object {
            if ($_ -match '^\s*AWS_SSO_START_URL\s*=\s*(.+?)\s*$')  { $ssoStartUrl  = $Matches[1].Trim('"').Trim("'") }
            if ($_ -match '^\s*AWS_SSO_ACCOUNT_ID\s*=\s*(.+?)\s*$') { $ssoAccountId = $Matches[1].Trim('"').Trim("'") }
            if ($_ -match '^\s*AWS_SSO_ROLE_NAME\s*=\s*(.+?)\s*$')  { $ssoRoleName  = $Matches[1].Trim('"').Trim("'") }
            if ($_ -match '^\s*AWS_SSO_REGION\s*=\s*(.+?)\s*$')     { $ssoRegion    = $Matches[1].Trim('"').Trim("'") }
        }
    }

    if (-not $ssoAccountId -or -not $ssoStartUrl) {
        Write-Log "Faltan AWS_SSO_START_URL / AWS_SSO_ACCOUNT_ID en ~/.env — salteo preconfig SSO" 'WARN'
        $WARNINGS.Add("AWS SSO sin preconfigurar: defini AWS_SSO_START_URL, AWS_SSO_ACCOUNT_ID (y opcional AWS_SSO_ROLE_NAME) en ~/.env")
    } else {
        # Escribo ~/.aws/config con formato sso-session: habilita el flujo PKCE
        # (login por navegador sin codigo de 6 digitos). 'aws configure set' no
        # sabe escribir bloques [sso-session], por eso se escribe el archivo.
        Invoke-Step "Pre-configurar perfil AWS SSO default (formato sso-session/PKCE)" {
            $awsDir = Join-Path $HOME ".aws"
            New-Item -ItemType Directory -Force -Path $awsDir | Out-Null
            $cfg = @"
[sso-session default]
sso_start_url = $ssoStartUrl
sso_region = $ssoRegion
sso_registration_scopes = sso:account:access

[default]
sso_session = default
sso_account_id = $ssoAccountId
sso_role_name = $ssoRoleName
region = $ssoRegion
output = json
"@
            Set-Content -Path (Join-Path $awsDir "config") -Value $cfg -Encoding ascii
        }

        if ($DryRun) {
            Write-Log "[DryRun] Saltando aws sso login" 'SKIP'
        } else {
            Write-Log "Iniciando AWS SSO login (se abrirá el navegador)..." 'INFO'
            aws sso login --profile default
            if ($LASTEXITCODE -eq 0) {
                Write-Log "AWS SSO login completado exitosamente" 'OK'
            } else {
                Write-Log "AWS SSO login falló o fue cancelado" 'WARN'
                $WARNINGS.Add("AWS SSO login incompleto — correr 'aws sso login --profile default'")
            }
        }
    }
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
# VALIDACION POST-BOOTSTRAP
# ==============================================================================

Write-Log "Validaciones post-bootstrap" 'SECTION'

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

Write-Log "Resumen final" 'SECTION'

if ($ERRORS.Count -eq 0 -and $WARNINGS.Count -eq 0) {
    Write-Log "Bootstrap completado sin errores." 'OK'
} else {
    if ($WARNINGS.Count -gt 0) {
        Write-Log "Advertencias ($($WARNINGS.Count)):" 'WARN'
        foreach ($w in $WARNINGS) { Write-Log $w 'WARN' }
    }
    if ($ERRORS.Count -gt 0) {
        Write-Log "Errores ($($ERRORS.Count)):" 'ERROR'
        foreach ($e in $ERRORS) { Write-Log $e 'ERROR' }
    }
}

Write-Log "" 'INFO'
Write-Log "Backups en: $BACKUP_DIR" 'INFO'
Write-Log "Log en:     $LOG_FILE" 'INFO'

Write-Log "Proximos pasos manuales" 'SECTION'
$stepNum = 1
Write-Log "$stepNum. Abri una terminal nueva para recargar el profile" 'INFO'
$stepNum++
if ($WithAws) {
    Write-Log "$stepNum. Ejecuta: aws configure sso (completar datos de SMG)" 'INFO'
    $stepNum++
    Write-Log "$stepNum. Ejecuta: aws sts get-caller-identity --profile tu_usuario" 'INFO'
    $stepNum++
}
Write-Log "$stepNum. Verifica tus claves SSH: ssh -T git@github.com-kevincharp" 'INFO'
