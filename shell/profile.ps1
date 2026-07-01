# ==============================================================================
#   profile.ps1 — Perfil unificado Kevin Charpentier (pwsh 7)
#   Portable: Windows personal / Windows laboral / cualquier máquina nueva
# ==============================================================================

if ($PSCommandPath) { $global:__ProfileFile = $PSCommandPath }

# ==============================================================================
# HELPERS DE ARRANQUE
# ==============================================================================

<#
.SYNOPSIS importar módulo sin bloquear el arranque
#>
function _TryImportModule {
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Quiet
    )
    try {
        Import-Module $Name -ErrorAction Stop
    } catch {
        if (-not $Quiet) {
            Write-Verbose "Módulo '$Name' no disponible: $($PSItem.Exception.Message)"
        }
    }
}

<#
.SYNOPSIS evaluar la salida de un `init` cacheada a disco
.DESCRIPTION Muchas herramientas (oh-my-posh, zoxide) generan su script de
init lanzando un proceso externo en cada arranque. Cacheamos esa salida y solo
regeneramos si alguno de los archivos "fuente" (binario, tema) es más nuevo que
el cache. Ahorra el costo de arrancar el proceso en cada terminal nueva.
#>
function _Invoke-CachedInit {
    param(
        [Parameter(Mandatory)][string]$Key,        # nombre del archivo de cache
        [Parameter(Mandatory)][scriptblock]$Generate, # genera el script de init
        [string[]]$Sources = @()                    # rutas que invalidan el cache
    )
    $cacheDir = Join-Path ($env:LOCALAPPDATA ?? $env:TEMP) 'pwsh-init-cache'
    if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
    $cacheFile = Join-Path $cacheDir "$Key.ps1"

    $stale = $true
    if (Test-Path $cacheFile) {
        $cacheTime = (Get-Item $cacheFile).LastWriteTimeUtc
        $newest = $Sources |
            Where-Object { $_ -and (Test-Path $_) } |
            ForEach-Object { (Get-Item $_).LastWriteTimeUtc } |
            Sort-Object -Descending | Select-Object -First 1
        $stale = $newest -and ($newest -gt $cacheTime)
    }

    if ($stale) {
        try { (& $Generate | Out-String) | Set-Content -LiteralPath $cacheFile -Encoding UTF8 }
        catch { return }
    }
    . $cacheFile
}

<#
.SYNOPSIS verificar existencia de módulo, avisar si falta
#>
function Ensure-Module {
    param([Parameter(Mandatory)][string]$Name)

    if (Get-Module -ListAvailable -Name $Name) { return $true }

    Write-Host "Módulo '$Name' no instalado." -ForegroundColor DarkYellow
    Write-Host "  → Install-Module $Name -Scope CurrentUser" -ForegroundColor DarkYellow
    return $false
}

# ==============================================================================
# PROMPT & ESTÉTICA
# ==============================================================================

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    # Si profile.ps1 es symlink, derivamos la raiz del repo desde su target
    # para no hardcodear la ubicacion del clon.
    $_profileItem = Get-Item -LiteralPath $PSCommandPath -ErrorAction SilentlyContinue
    $_repoRoot = if ($_profileItem -and $_profileItem.LinkType -eq 'SymbolicLink') {
        Split-Path (Split-Path $_profileItem.Target -Parent) -Parent
    } else { $null }

    $_ompTheme = if ($env:POSH_THEMES_PATH -and (Test-Path "$env:POSH_THEMES_PATH\claude-code.omp.json")) {
        "$env:POSH_THEMES_PATH\claude-code.omp.json"
    } elseif ($_repoRoot -and (Test-Path "$_repoRoot\shell\themes\claude-code.omp.json")) {
        "$_repoRoot\shell\themes\claude-code.omp.json"
    } else { $null }
    if ($_ompTheme) {
        # El tema (symlink compartido con Linux) trae upgrade.auto/notice=true, util
        # solo en Linux. En Windows oh-my-posh se instala como paquete MSIX/Appx y NO
        # puede autoactualizarse: cada arranque tira "upgrade is not supported when
        # installed as a MSIX package". El toggle 'oh-my-posh disable upgrade' no gana
        # contra el auto:true explicito del JSON, asi que derivamos una copia LOCAL del
        # tema con upgrade apagado y arrancamos contra ella. El symlink no se toca (Linux
        # sigue autoactualizando). La copia se regenera si el tema original cambia.
        $_ompLocal = Join-Path ($env:LOCALAPPDATA ?? $env:TEMP) 'pwsh-init-cache\claude-code.omp.json'
        try {
            $_srcTime = (Get-Item $_ompTheme).LastWriteTimeUtc
            if (-not (Test-Path $_ompLocal) -or (Get-Item $_ompLocal).LastWriteTimeUtc -lt $_srcTime) {
                $_ompDir = Split-Path $_ompLocal -Parent
                if (-not (Test-Path $_ompDir)) { New-Item -ItemType Directory -Path $_ompDir -Force | Out-Null }
                $_ompJson = Get-Content -Raw -LiteralPath $_ompTheme | ConvertFrom-Json
                if ($_ompJson.PSObject.Properties.Name -contains 'upgrade') {
                    $_ompJson.upgrade.auto = $false
                    $_ompJson.upgrade.notice = $false
                }
                $_ompJson | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $_ompLocal -Encoding UTF8
            }
        } catch {
            $_ompLocal = $_ompTheme  # si algo falla, caer al tema original
        }
        $_ompBin = (Get-Command oh-my-posh).Source
        _Invoke-CachedInit -Key 'oh-my-posh' -Sources @($_ompBin, $_ompLocal) -Generate {
            oh-my-posh init pwsh --config $_ompLocal
        }.GetNewClosure()
    } else {
        Write-Host "oh-my-posh tema no encontrado — ejecutar bootstrap.ps1" -ForegroundColor DarkYellow
    }
    Remove-Variable _ompTheme, _ompLocal, _ompJson, _ompDir, _srcTime, _profileItem, _repoRoot, _ompBin -ErrorAction SilentlyContinue

    # Le indica a PSReadLine cual es el ultimo glifo del prompt para que no
    # lo re-pinte con su color default (verde) al editar la linea.
    if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
        Set-PSReadLineOption -PromptText '❯ ', '❯ '
    }
} else {
    Write-Host "oh-my-posh no instalado → winget install JanDeDobbeleer.OhMyPosh" -ForegroundColor DarkYellow
}

# Terminal-Icons: carga diferida. Importarlo al arranque costaba ~500ms;
# lo posponemos a la primera vez que se listan archivos con objetos (ll).
$global:__TerminalIconsLoaded = $false
function _Ensure-TerminalIcons {
    if ($global:__TerminalIconsLoaded) { return }
    $global:__TerminalIconsLoaded = $true
    _TryImportModule Terminal-Icons -Quiet
}

# ==============================================================================
# ZOXIDE (cd inteligente con memoria)
# Si no está instalado, cd funciona normal. Si está, z reemplaza cd.
# Instalación: winget install ajeetdsouza.zoxide
# ==============================================================================

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    $_zoxideBin = (Get-Command zoxide).Source
    _Invoke-CachedInit -Key 'zoxide' -Sources @($_zoxideBin) -Generate {
        zoxide init powershell
    }
    Remove-Variable _zoxideBin -ErrorAction SilentlyContinue
} else {
    Write-Verbose "zoxide no instalado — cd funcionando en modo normal"
}

# ==============================================================================
# FZF (búsqueda difusa — Ctrl+R para historial como en bash)
# Instalación: winget install junegunn.fzf
# ==============================================================================

if (Get-Command fzf -ErrorAction SilentlyContinue) {
    # Ctrl+R: búsqueda en historial con fzf (igual que bash)
    Set-PSReadLineKeyHandler -Chord "Ctrl+r" -ScriptBlock {
        $history = Get-Content (Get-PSReadLineOption).HistorySavePath |
                   Where-Object { $_ -ne '' } |
                   Sort-Object -Unique |
                   Select-Object -Last 5000
        $selected = $history | fzf --tac --no-sort --height 40% --border --prompt "historial> "
        if ($selected) {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selected)
        }
    }
} else {
    Write-Verbose "fzf no instalado — Ctrl+R usando PSReadLine básico"
}

# ==============================================================================
# PSREADLINE
# ==============================================================================

_TryImportModule PSReadLine -Quiet

if (Get-Module PSReadLine -ErrorAction SilentlyContinue) {
    try {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction Stop
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction Stop
    } catch {
        # Ignorar errores en contextos no interactivos (ej: Claude Code)
    }
    Set-PSReadLineOption -EditMode Windows -ErrorAction SilentlyContinue
    Set-PSReadLineOption -MaximumHistoryCount 10000 -ErrorAction SilentlyContinue
    # OJO: -HistoryNoDuplicates NO deduplica el archivo en disco, solo la
    # NAVEGACION (salta duplicados al recorrer con ↑ / buscar). El archivo
    # (ConsoleHost_history.txt) igual acumula cada repeticion. La dedup real del
    # archivo (paridad con erasedups de bash / HIST_IGNORE_ALL_DUPS de zsh) se
    # hace mas abajo, al arrancar (ver bloque "DEDUP DEL HISTORIAL").
    Set-PSReadLineOption -HistoryNoDuplicates -ErrorAction SilentlyContinue
    Set-PSReadLineOption -BellStyle None -ErrorAction SilentlyContinue
    Set-PSReadLineOption -Colors @{
        Command              = '#C79BFF'
        Parameter            = '#7AB8FF'
        String               = '#86E89A'
        Variable             = '#FFDF61'
        Keyword              = '#C79BFF'
        Number               = '#FFDF61'
        Operator             = '#56B6C2'
        Type                 = '#7AB8FF'
        Member               = '#E8E0D4'
        Error                = '#FF7A7A'
        Comment              = '#6B5448'
        Default              = '#E8E0D4'
        Emphasis             = '#D4874E'
        InlinePrediction     = '#6B5448'
        ListPrediction       = '#A89890'
        ListPredictionSelected = "`e[48;2;58;46;42m"
    } -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord "Ctrl+RightArrow" -Function AcceptNextSuggestionWord -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord "Ctrl+Spacebar"   -Function MenuComplete -ErrorAction SilentlyContinue

    # --- DEDUP DEL HISTORIAL (paridad real con erasedups / HIST_IGNORE_ALL_DUPS) ---
    # PSReadLine NO deduplica el archivo (ConsoleHost_history.txt): -HistoryNoDuplicates
    # solo afecta la navegacion. Asi que al arrancar limpiamos el archivo dejando la
    # ocurrencia MAS RECIENTE de cada comando (igual que erasedups en bash). Recorremos
    # de abajo hacia arriba (lo mas nuevo primero) quedandonos con la primera vista de
    # cada linea, y luego reinvertimos para conservar el orden cronologico.
    try {
        $histPath = (Get-PSReadLineOption).HistorySavePath
        if ($histPath -and (Test-Path -LiteralPath $histPath)) {
            $lines = @(Get-Content -LiteralPath $histPath -ErrorAction Stop)
            $seen = [System.Collections.Generic.HashSet[string]]::new()
            $keptRev = [System.Collections.Generic.List[string]]::new()
            for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                $ln = $lines[$i]
                # No deduplicar lineas vacias ni continuaciones (backtick al final):
                # colapsarlas romperia comandos multilinea.
                if ([string]::IsNullOrWhiteSpace($ln) -or $ln.EndsWith('`')) {
                    $keptRev.Add($ln); continue
                }
                if ($seen.Add($ln)) { $keptRev.Add($ln) }
            }
            if ($keptRev.Count -lt $lines.Count) {
                $keptRev.Reverse()
                Set-Content -LiteralPath $histPath -Value $keptRev -Encoding UTF8 -ErrorAction Stop
            }
        }
    } catch {
        # En contextos raros (archivo bloqueado, sin permisos) no vale la pena romper el prompt.
    }
}

# FZF — colores Claude Code
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_OPTS = (
        "--height 40% --border rounded --layout=reverse --prompt ' '" +
        " --color=bg+:#3A2E2A,bg:#1E1A18,spinner:#D4874E,hl:#C79BFF" +
        " --color=fg:#E8E0D4,header:#7AB8FF,info:#FFDF61,pointer:#D4874E" +
        " --color=marker:#86E89A,fg+:#E8E0D4,prompt:#D4874E,hl+:#E8935A" +
        " --color=border:#5C4A44,label:#A89890,query:#E8E0D4"
    )
}

# ==============================================================================
# EDITOR DE TERMINAL
# ==============================================================================

Set-Alias vi   nvim
Set-Alias vim  nvim
Set-Alias nano nvim

# yazi (file manager TUI): en Windows no encuentra el binario 'file' solo, hay
# que apuntarlo con YAZI_FILE_ONE o falla la deteccion de MIME ("Cannot find
# file's MIME type"). Se usa el 'file.exe' de Git Bash (paridad con bashrc).
if ($IsWindows -and -not $env:YAZI_FILE_ONE) {
    $_fileOne = Get-Command file.exe -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Source
    if (-not $_fileOne) {
        $_gitFile = Join-Path $env:ProgramFiles 'Git\usr\bin\file.exe'
        if (Test-Path $_gitFile) { $_fileOne = $_gitFile }
    }
    if ($_fileOne) { $env:YAZI_FILE_ONE = $_fileOne }
}

# ==============================================================================
# RUTAS BASE
# ==============================================================================

$repos     = Join-Path $HOME 'repositorios'
$personal  = Join-Path $repos 'personal'
$work      = Join-Path $repos 'work'
$cei_walle = Join-Path $repos 'cei_walle'

# ==============================================================================
# UTILIDADES GENERALES
# ==============================================================================

Set-Alias openh open-here

<#
.SYNOPSIS abrir explorador aquí
.EXAMPLE openh
#>
function open-here {
    if ($IsWindows) {
        Start-Process explorer.exe (Get-Location)
    } elseif ($IsLinux) {
        Start-Process xdg-open -ArgumentList (Get-Location)
    } else {
        Start-Process open -ArgumentList (Get-Location)
    }
}

<#
.SYNOPSIS yazi con cd-on-exit (paridad con la funcion 'y' de bashrc/zshrc)
.DESCRIPTION Lanza yazi y, al salir con 'q', deja el shell parado en el ultimo
directorio navegado (yazi escribe el cwd en un temporal via --cwd-file).
.EXAMPLE y
#>
if (Get-Command yazi -ErrorAction SilentlyContinue) {
    function y {
        $tmp = [System.IO.Path]::GetTempFileName()
        yazi $args --cwd-file="$tmp"
        $cwd = Get-Content -LiteralPath $tmp -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
            Set-Location -LiteralPath $cwd
        }
        Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
}

<#
.SYNOPSIS actualizar todo lo que winget no cubre, en un solo comando
.DESCRIPTION Espejo del update-all de bash/zsh (paridad). winget cubre la mayoria
de las apps; esta funcion suma npm (codex). Claude Code se autoactualiza solo;
lazyssh (binario GitHub) se actualiza re-corriendo el bootstrap.
#>
function update-all {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "==> winget (apps del sistema)" -ForegroundColor Cyan
        winget upgrade --all --accept-package-agreements --accept-source-agreements
    }
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "==> npm (paquetes globales, p.ej. codex)" -ForegroundColor Cyan
        npm update -g
    }
    Write-Host "Listo. Nota: lazyssh (binario GitHub) se actualiza re-corriendo el bootstrap;"
    Write-Host "Claude Code se autoactualiza solo."
}

<#
.SYNOPSIS abrir directorio o archivo
.EXAMPLE open path
#>
function open {
    param([string[]]$f)

    foreach ($p in $f) {
        if (Test-Path -LiteralPath $p) {
            $i = Get-Item -LiteralPath $p
            if ($i.PSIsContainer) {
                if ($IsWindows) {
                    Start-Process explorer.exe $p
                } elseif ($IsLinux) {
                    Start-Process xdg-open -ArgumentList $p
                } else {
                    Start-Process open -ArgumentList $p
                }
            } else {
                Invoke-Item -LiteralPath $p
            }
        } else {
            Write-Error "No existe: $p"
        }
    }
}

<#
.SYNOPSIS editar archivo (VSCode si existe, sino Notepad)
.EXAMPLE edit archivo
#>
function edit {
    param([Parameter(Mandatory)][string]$File)

    if (Get-Command code -ErrorAction SilentlyContinue) {
        code $File
    } else {
        notepad $File
    }
}

<#
.SYNOPSIS limpiar el historial de PSReadLine (todo o por patron)
.DESCRIPTION Espejo del clear-history de bash/zsh (paridad). Sin args vacia TODO el
historial (con confirmacion); con un patron borra solo las lineas que lo contengan
(util si pegaste un token/secreto). Opera sobre el archivo de PSReadLine
(HistorySavePath) y limpia la sesion actual. Nota: 'Clear-History' nativo de
PowerShell solo vacia la sesion, no el archivo; por eso esta funcion lo reemplaza.
.EXAMPLE clear-history            # vacia todo (pregunta y/N)
.EXAMPLE clear-history AWS_SECRET # borra solo lineas con ese texto
#>
function clear-history {
    param([string]$Pattern)

    $hist = (Get-PSReadLineOption).HistorySavePath
    if (-not $hist -or -not (Test-Path -LiteralPath $hist)) {
        Write-Host "No se encontro el archivo de historial de PSReadLine."
        return
    }

    if ($Pattern) {
        $kept = Get-Content -LiteralPath $hist | Where-Object { $_ -notlike "*$Pattern*" }
        Set-Content -LiteralPath $hist -Value $kept
        [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
        Write-Host "Historial: borradas las lineas que matcheaban '$Pattern'."
    } else {
        $ans = Read-Host "Vaciar TODO el historial ($hist)? [y/N]"
        if ($ans -eq 'y' -or $ans -eq 'Y') {
            Clear-Content -LiteralPath $hist
            [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
            Write-Host "Historial vaciado."
        } else {
            Write-Host "Cancelado."
        }
    }
}

<#
.SYNOPSIS abrir el archivo de historial en el editor
.DESCRIPTION Espejo del edit-history de bash/zsh (paridad). Reusa la funcion
'edit' (VSCode si esta, si no Notepad). PowerShell guarda el historial en el
archivo de PSReadLine (HistorySavePath). Ojo: la sesion actual reescribe el
archivo al salir, asi que editarlo en vivo puede pisarse con lo que tipees.
.EXAMPLE edit-history
#>
function edit-history {
    $hist = (Get-PSReadLineOption).HistorySavePath
    if (-not $hist -or -not (Test-Path -LiteralPath $hist)) {
        Write-Host "No se encontro el archivo de historial de PSReadLine."
        return
    }
    edit $hist
}

# ==============================================================================
# ATAJOS LINUX
# ==============================================================================

<#
.SYNOPSIS escribir texto con LF
.EXAMPLE echolf "hola mundo" > archivo.txt
#>
function echolf {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Text)
    [Console]::Out.WriteLine(($Text -join " ") -replace "`r?`n","`n")
}

<#
.SYNOPSIS listar simple (sin ocultos)
.EXAMPLE lss
#>
function lss {
    $w      = [Console]::BufferWidth
    $it     = @(Get-ChildItem -Name | Where-Object { -not $_.StartsWith('.') } | Sort-Object -CaseSensitive)
    if (!$it) { return }
    $minCol  = 2
    $maxColW = 30
    $colw    = [Math]::Min($maxColW, $w / $minCol)
    $cols    = [Math]::Max([Math]::Floor($w / $colw), $minCol)
    $rows    = [Math]::Ceiling($it.Count / $cols)

    for ($r = 0; $r -lt $rows; $r++) {
        $line = ""
        for ($c = 0; $c -lt $cols; $c++) {
            $i = $r + $c * $rows
            if ($i -lt $it.Count) {
                $n = $it[$i]
                if ($n.Length -gt $colw - 2) { $n = $n.Substring(0, $colw - 3) + '…' }
                $line += $n.PadRight($colw)
            }
        }
        $line
    }
}

<#
.SYNOPSIS listar simple con ocultos
.EXAMPLE la
#>
function la {
    $w    = [Console]::BufferWidth
    $it   = @(Get-ChildItem -Name -Force | Sort-Object -CaseSensitive)
    if (!$it) { return }
    $max  = ($it | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $colw = [Math]::Max([Math]::Min($max + 2, $w), 2)
    $cols = [Math]::Max([Math]::Floor($w / $colw), 1)
    $rows = [Math]::Ceiling($it.Count / $cols)

    for ($r = 0; $r -lt $rows; $r++) {
        $line = ""
        for ($c = 0; $c -lt $cols; $c++) {
            $i = $r + $c * $rows
            if ($i -lt $it.Count) {
                $n = $it[$i]
                if ($n.Length -gt $colw - 2) { $n = $n.Substring(0, $colw - 3) + '…' }
                $line += $n.PadRight($colw)
            }
        }
        $line
    }
}

<#
.SYNOPSIS listar detalles
.EXAMPLE ll
#>
function ll {
    _Ensure-TerminalIcons
    Get-ChildItem -Force | Sort-Object @{e='PSIsContainer';Descending=$true},Name
}

<#
.SYNOPSIS crear o actualizar archivo (touch)
.EXAMPLE touch archivo1 archivo2
#>
function touch {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Path)
    foreach ($p in $Path) {
        $targets = @(Get-ChildItem $p -ErrorAction SilentlyContinue)
        if (-not $targets) {
            New-Item -ItemType File -Path $p -Force | Out-Null
            $targets = Get-Item $p
        }
        foreach ($t in $targets) { $t.LastWriteTime = Get-Date }
    }
}

<#
.SYNOPSIS cambiar directorio con soporte a "cd -"
.EXAMPLE cd path | cd -
#>
function cd {
    param([string]$Path)

    if ($Path -eq '-') {
        if ($global:OLDPWD) {
            $tmp = $PWD
            Microsoft.PowerShell.Management\Set-Location $global:OLDPWD
            $global:OLDPWD = $tmp
        } else {
            Write-Warning "No hay directorio anterior."
        }
    } elseif ([string]::IsNullOrWhiteSpace($Path)) {
        Microsoft.PowerShell.Management\Set-Location $HOME
    } else {
        $global:OLDPWD = $PWD
        Microsoft.PowerShell.Management\Set-Location $Path
    }
}
$global:OLDPWD = $PWD

<#
.SYNOPSIS definir variable de entorno (export)
.EXAMPLE export VAR=valor
#>
function export {
    foreach ($exp in $args) {
        $parts = $exp -split '=', 2
        if ($parts.Count -eq 2 -and $parts[0] -match '^[A-Za-z_][A-Za-z0-9_]*$') {
            Set-Item "Env:$($parts[0])" $parts[1]
        } else {
            Write-Error "Uso: export VAR=valor"
        }
    }
}

<#
.SYNOPSIS eliminar variable de entorno (unset)
.EXAMPLE unset VAR1 VAR2
#>
function unset {
    foreach ($name in $args) {
        if (Test-Path Env:$name) {
            Remove-Item Env:$name -ErrorAction SilentlyContinue
        } else {
            Write-Warning "Variable no encontrada: $name"
        }
    }
}

<#
.SYNOPSIS buscar texto (grep)
.EXAMPLE grep "error" .\*.log -r -i
#>
function grep {
    param(
        [string]$Pattern,
        [string[]]$Path = @('-'),
        [switch]$r,
        [switch]$i,
        [switch]$n,
        [switch]$o
    )

    $o2 = @{ Pattern = $Pattern }
    if ($Path -ne @('-')) { $o2.Path = $Path } else { $o2.InputObject = $input }
    if ($r) { $o2.Recurse = $true }
    $o2.CaseSensitive = -not $i

    $res = Select-String @o2
    if ($o) { $res.Matches.Value }
    else    { if ($n) { $res } else { $res | ForEach-Object { $_.Line } } }
}

<#
.SYNOPSIS emula find de Linux
.EXAMPLE find . -type d -name "wiki-gs-smg"
#>
function find {
    param(
        [string]$path = '.',
        [string]$name = '*',
        [string]$type
    )

    $it = Get-ChildItem -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue -Filter $name
    if ($type -eq 'f')    { $it = $it | Where-Object { -not $_.PSIsContainer } }
    elseif ($type -eq 'd'){ $it = $it | Where-Object { $_.PSIsContainer } }
    $it
}

<#
.SYNOPSIS primeras líneas (head)
.EXAMPLE head .\log.txt -n 20
#>
function head {
    param([string]$p, [int]$n = 10)
    Get-Content -LiteralPath $p -TotalCount $n
}

<#
.SYNOPSIS últimas líneas (tail)
.EXAMPLE tail .\log.txt -n 50
#>
function tail {
    param([string]$p, [int]$n = 10)
    Get-Content -LiteralPath $p -Tail $n
}

<#
.SYNOPSIS seguir archivo (tail -f)
.EXAMPLE tailf .\app.log
#>
function tailf {
    param([string]$p, [int]$n = 50)
    Get-Content -LiteralPath $p -Tail $n -Wait
}

<#
.SYNOPSIS ruta de comando (which)
.EXAMPLE which nvim
#>
function which {
    param([string]$name)
    (Get-Command $name -ErrorAction SilentlyContinue).Source
}

<#
.SYNOPSIS mkdir -p
.EXAMPLE mkdirp .\a\b\c
#>
function mkdirp {
    param([string]$p)
    New-Item -ItemType Directory -Path $p -Force | Out-Null
}

Set-Alias r  rmrf
Set-Alias rf rmrf

<#
.SYNOPSIS rm -rf (mata procesos que usen el path antes de borrar)
.EXAMPLE rmrf .\build .\dist
#>
function rmrf {
    param([string[]]$p)

    foreach ($path in $p) {
        Get-Process | Where-Object { $_.Path -and $_.Path -like "*$path*" } |
            Stop-Process -Force -ErrorAction SilentlyContinue | Out-Null
    }
    Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
}

<#
.SYNOPSIS ver archivo (cat)
.EXAMPLE cat .\README.md
#>
function cat {
    param([string[]]$p)
    Get-Content -LiteralPath $p
}

<#
.SYNOPSIS paginador tipo less
.EXAMPLE less .\README.md
#>
function less {
    param([string]$p)
    Get-Content -LiteralPath $p | more
}

# ==============================================================================
# GIT HELPERS
# ==============================================================================

Set-Alias g git

<#
.SYNOPSIS git clone
.EXAMPLE gcl url
#>
function gcl {
    param([string]$url, [string]$dir)
    if ($dir) { git clone $url $dir } else { git clone $url }
}

<#
.SYNOPSIS git status
.EXAMPLE gs
#>
function gs { git status }

<#
.SYNOPSIS git status corto
.EXAMPLE gst
#>
function gst { git status -sb }

<#
.SYNOPSIS git log gráfico corto
.EXAMPLE glo
#>
function glo { git log --oneline --graph --decorate -n 30 }

<#
.SYNOPSIS git log gráfico completo
.EXAMPLE glg
#>
function glg { git log --oneline --graph --all --decorate }

<#
.SYNOPSIS git commit -m
.EXAMPLE gcmm "mensaje"
#>
function gcmm {
    param([string]$m)
    git commit -m $m
}

<#
.SYNOPSIS git checkout
.EXAMPLE gco rama
#>
function gco {
    param($b)
    git checkout $b
}

<#
.SYNOPSIS git checkout -b
.EXAMPLE gnew rama
#>
function gnew {
    param([string]$b)
    git checkout -b $b
}

<#
.SYNOPSIS git switch (crea rama si no existe local ni remota)
.EXAMPLE gsw rama
#>
function gsw {
    param([string]$b)

    git fetch --prune *> $null
    git show-ref --verify --quiet "refs/heads/$b" `
        && git switch $b `
        || (git show-ref --verify --quiet "refs/remotes/origin/$b" `
            && git switch -t "origin/$b" `
            || git switch -c $b)
}

<#
.SYNOPSIS git branch -vv
.EXAMPLE gbr
#>
function gbr { git branch -vv }

<#
.SYNOPSIS git branch -a -vv
.EXAMPLE gbra
#>
function gbra { git branch -a -vv }

<#
.SYNOPSIS git remote -v
.EXAMPLE grls
#>
function grls { git remote -v }

<#
.SYNOPSIS git remote add / listar
.EXAMPLE grem origin url
#>
function grem {
    param([string]$name, [string]$url)
    if ($name -and $url) { git remote add $name $url } else { git remote -v }
}

<#
.SYNOPSIS git remote set-url
.EXAMPLE grurl origin url
#>
function grurl {
    param([string]$name, [string]$url)
    git remote set-url $name $url
}

<#
.SYNOPSIS set upstream de la rama actual
.EXAMPLE gup
#>
function gup {
    $b = git rev-parse --abbrev-ref HEAD
    git branch --set-upstream-to=origin/$b $b
}

<#
.SYNOPSIS push inicial con tracking
.EXAMPLE gpsu
#>
function gpsu {
    $b = git rev-parse --abbrev-ref HEAD
    git push -u origin $b
}

<#
.SYNOPSIS sync limpio (fetch + pull rebase + autostash)
.EXAMPLE gsync
#>
function gsync {
    git fetch --all --prune
    git pull --rebase --autostash
}

<#
.SYNOPSIS borra branches locales cuyo remote tracking ya no existe
.DESCRIPTION fetch --prune y luego elimina los branches en estado "[gone]"
.EXAMPLE gcleanbranches
#>
function gcleanbranches {
    git fetch --prune
    $gone = git branch -vv | Where-Object { $_ -match '\[[^\]]*: gone\]' } |
            ForEach-Object { ($_ -replace '^\*?\s+', '' -split '\s+')[0] }
    if (-not $gone) {
        Write-Host "Sin branches para limpiar." -ForegroundColor DarkGray
        return
    }
    foreach ($b in $gone) {
        git branch -d $b
    }
}

# ==============================================================================
# PUERTOS (dev workflow)
# ==============================================================================

<#
.SYNOPSIS lista el proceso escuchando en un puerto
.EXAMPLE port 3000
#>
function port {
    param([Parameter(Mandatory=$true)][int]$Port)
    $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if (-not $conns) {
        Write-Host "Nada escuchando en puerto $Port" -ForegroundColor DarkGray
        return
    }
    $conns | ForEach-Object {
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        [pscustomobject]@{
            Port = $_.LocalPort
            PID  = $_.OwningProcess
            Name = if ($proc) { $proc.ProcessName } else { '<desconocido>' }
        }
    } | Format-Table -AutoSize
}

<#
.SYNOPSIS mata el proceso que escucha en un puerto
.EXAMPLE killport 3000
#>
function killport {
    param([Parameter(Mandatory=$true)][int]$Port)
    $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if (-not $conns) {
        Write-Host "Nada escuchando en puerto $Port" -ForegroundColor DarkGray
        return
    }
    $conns | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object {
        Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
        Write-Host "Killed PID $_ (puerto $Port)" -ForegroundColor DarkYellow
    }
}

<#
.SYNOPSIS mata procesos en puertos comunes de desarrollo
.EXAMPLE killdev
#>
function killdev {
    $devPorts = @(3000, 3001, 4200, 5173, 8080, 8090, 8443)
    foreach ($p in $devPorts) { killport $p }
}

# ==============================================================================
# GIT — CLONE + PERFILES DE IDENTIDAD
# ==============================================================================

# Identidades (nombre/email por perfil) viven en el vault privado.
# El bootstrap las copia a ~/.config/git-identities.ps1. Si no estan,
# las funciones git de perfil avisan que falta el vault.
$script:GitIdentities  = @{}
$script:GitHostAliases = @{}
$_giFile = Join-Path ($env:XDG_CONFIG_HOME ?? (Join-Path $HOME '.config')) 'git-identities.ps1'
if (Test-Path -LiteralPath $_giFile) {
    . $_giFile
    if ($GitIdentities)  { $script:GitIdentities  = $GitIdentities }
    if ($GitHostAliases) { $script:GitHostAliases = $GitHostAliases }
}

function Resolve-GitIdentity {
    param([string]$Perfil)
    if ($script:GitIdentities.Count -eq 0) {
        throw "Identidades git no cargadas (falta el vault: $_giFile)"
    }
    if (-not $script:GitIdentities.ContainsKey($Perfil)) {
        throw "Perfil desconocido: $Perfil. Validos: $($script:GitIdentities.Keys -join ', ')"
    }
    return $script:GitIdentities[$Perfil]
}

<#
.SYNOPSIS Clonar repo y configurar identidad local automáticamente
.EXAMPLE gclone -perfil work -remoteUrl git@gitlab.com-xxx:grupo/repo.git
#>
function gclone {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("cei_walle","work","kevincharp","kevincharp-gl")]
        [string]$perfil,
        [Parameter(Mandatory=$true)]
        [string]$remoteUrl,
        [string]$targetDir = ""
    )

    if ($remoteUrl -notmatch '^(?:git@[\w.-]+:.+(?:\.git)?|ssh://git@[\w.-]+/.+(?:\.git)?|https://[\w.-]+/.+(?:\.git)?)$') {
        throw "URL inválida: $remoteUrl"
    }

    $originHost = if ($remoteUrl -match '.*@([^:]+):') { $Matches[1] }
                  elseif ($remoteUrl -match '^https?://([^/]+)/') { $Matches[1] }
                  else { '' }
    $repoName   = [IO.Path]::GetFileNameWithoutExtension(($remoteUrl -replace '^[^:]+:|^https?://[^/]+/',''))
    $cloneDir   = if ([string]::IsNullOrWhiteSpace($targetDir)) { Join-Path (Get-Location) $repoName } else { $targetDir }

    if (Test-Path -LiteralPath $cloneDir) {
        if ((Get-ChildItem -LiteralPath $cloneDir -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
            throw "El destino ya existe y no está vacío: $cloneDir"
        }
    } else {
        New-Item -ItemType Directory -Path $cloneDir -Force | Out-Null
    }

    $identity = Resolve-GitIdentity $perfil

    if ($PSCmdlet.ShouldProcess($cloneDir, "git clone $remoteUrl")) {
        git clone $remoteUrl $cloneDir | Out-Null
    }

    Push-Location $cloneDir
    try {
        git config --local user.useConfigOnly true
        git config --local user.name          $identity.name
        git config --local user.email         $identity.email
        git config --local core.autocrlf      input
        git config --local pull.rebase        true
        git config --local rebase.autostash   true
        git remote -v | Out-Null

        [pscustomobject]@{
            Repository = $repoName
            Host       = $originHost
            Path       = $cloneDir
            Profile    = $perfil
            UserName   = (git config --local user.name)
            UserEmail  = (git config --local user.email)
            Remote     = (git remote get-url origin 2>$null)
        }
    } finally {
        Pop-Location
    }
}

# $GitProfiles ahora se resuelve desde el vault (ver $script:GitIdentities arriba).
# gset-profile/ginit usan Resolve-GitIdentity para obtener name/email/signKey/sshKey.

<#
.SYNOPSIS aplicar perfil git a repo ya existente
.EXAMPLE gset-profile -Perfil work
#>
function gset-profile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][ValidateSet('cei_walle','work','kevincharp','kevincharp-gl')] [string]$Perfil,
        [string]$Path = (Get-Location),
        [switch]$Sign,
        [switch]$SetSsh
    )

    $p = Resolve-Path -LiteralPath $Path
    if ($PSCmdlet.ShouldProcess($p, "Aplicar perfil $Perfil")) {
        Push-Location $p
        try {
            git rev-parse --is-inside-work-tree 2>$null | Out-Null
            if ($LASTEXITCODE) { throw "No es un repo Git: $p" }

            $identity = Resolve-GitIdentity $Perfil
            git config --local user.name  $identity.name
            git config --local user.email $identity.email

            if ($Sign -and $identity.signKey) {
                git config --local commit.gpgsign   true
                git config --local user.signingkey  $identity.signKey
            }
            if ($SetSsh -and $identity.sshKey) {
                git config --local core.sshCommand ("ssh -i " + $identity.sshKey)
            }

            Write-Host "Perfil '$Perfil' aplicado en $p" -ForegroundColor Green
        } finally {
            Pop-Location
        }
    }
}

<#
.SYNOPSIS git init + aplicar perfil de identidad
.EXAMPLE ginit work
#>
function ginit {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][ValidateSet('cei_walle','work','kevincharp','kevincharp-gl')] [string]$Perfil,
        [string]$Path = (Get-Location),
        [switch]$Sign,
        [switch]$SetSsh
    )

    $p = Resolve-Path -LiteralPath $Path
    if ($PSCmdlet.ShouldProcess($p, "git init + perfil $Perfil")) {
        Push-Location $p
        try {
            if (-not (Test-Path .git)) { git init -b main | Out-Null }
            gset-profile -Perfil $Perfil -Path $p -Sign:$Sign -SetSsh:$SetSsh
            git config --local --unset-all pull.rebase         2>$null
            git config --local --unset-all init.defaultbranch  2>$null
            git config --local --unset-all core.autocrlf       2>$null
            git config --local --unset-all core.editor         2>$null
        } finally {
            Pop-Location
        }
    }
}

<#
.SYNOPSIS agregar/actualizar remoto con alias SSH
.EXAMPLE gremote -Alias gitlab.com-<mi-alias> -PathNs mi-grupo/mi-repo
#>
function gremote {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Alias,
        [Parameter(Mandatory)][string]$PathNs,
        [string]$Name = 'origin'
    )

    $ssh = "git@${Alias}:$PathNs.git"
    if ($PSCmdlet.ShouldProcess((Get-Location), "git remote add/set $Name $ssh")) {
        if (git remote get-url $Name 2>$null) {
            git remote set-url $Name $ssh | Out-Null
        } else {
            git remote add $Name $ssh | Out-Null
        }
        Write-Host "Remote '$Name' → $ssh" -ForegroundColor Cyan
    }
}

# ==============================================================================
# GBROWSER + .ENV LOADER
# ==============================================================================

function Load-DotEnv {
    param([string]$Path = (Join-Path $HOME ".env"))
    if (-not (Test-Path $Path)) { return @{} }
    $map = @{}
    Get-Content -Raw -Path $Path -EA SilentlyContinue -Encoding UTF8 |
        ForEach-Object {
            $_ -split "`n" | ForEach-Object {
                $line = $_.Trim()
                if ($line -eq '' -or $line.StartsWith('#')) { return }
                $kv = $line -split '=', 2
                if ($kv.Count -eq 2) {
                    $k = $kv[0].Trim()
                    $v = $kv[1].Trim().Trim('"').Trim("'")
                    $map[$k] = $v
                }
            }
        }
    return $map
}
$__DOTENV = Load-DotEnv

function Get-SecretFromEnv {
    param([string]$Name)
    if ($__DOTENV.ContainsKey($Name)) { return $__DOTENV[$Name] }
    $t = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($t)) { $t = [Environment]::GetEnvironmentVariable($Name, 'User') }
    if ([string]::IsNullOrWhiteSpace($t)) { $t = [Environment]::GetEnvironmentVariable($Name, 'Machine') }
    return $t
}

$env:GITLAB_TOKEN_KECHARPEN  = Get-SecretFromEnv 'GITLAB_TOKEN_KECHARPEN'
$env:GITLAB_TOKEN_CEI_WALLE  = Get-SecretFromEnv 'GITLAB_TOKEN_CEI_WALLE'
$env:GITLAB_TOKEN_KEVINCHARP = Get-SecretFromEnv 'GITLAB_TOKEN_KEVINCHARP'
$env:GITHUB_TOKEN_KEVINCHARP = Get-SecretFromEnv 'GITHUB_TOKEN_KEVINCHARP'

# AWS / Claude SMG
$env:CLAUDE_SMG_AWS_PROFILE = Get-SecretFromEnv 'CLAUDE_SMG_AWS_PROFILE'
$env:CLAUDE_SMG_AWS_REGION  = Get-SecretFromEnv 'CLAUDE_SMG_AWS_REGION'
$env:CLAUDE_SMG_MODEL       = Get-SecretFromEnv 'CLAUDE_SMG_MODEL'
$env:CLAUDE_SMG_SMALL_MODEL = Get-SecretFromEnv 'CLAUDE_SMG_SMALL_MODEL'

<#
.SYNOPSIS consultar repos de un namespace en GitLab o GitHub
.EXAMPLE gbrowser gitlab.com-<mi-alias>:grupo/subgrupo
.EXAMPLE gbrowser github.com-<mi-alias>:owner -Recurse -Json
#>
function gbrowser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RemotePath,
        [switch]$Recurse,
        [switch]$Json,
        [string]$Token
    )

    if ($RemotePath -notmatch '^(?<alias>[^:]+):(?<ns>.+)$') {
        throw "Formato inválido. Ej: <alias-ssh>:grupo/subgrupo"
    }

    $alias = $Matches.alias
    $ns    = ($Matches.ns).Trim('/')
    if ($alias -like 'git@*') { $alias = $alias -replace '^git@','' }

    # Mapa de aliases cargado desde el vault ($script:GitHostAliases)
    $CFG = $script:GitHostAliases
    if ($CFG.Count -eq 0) {
        throw "Host-aliases no cargados (falta el vault: git-identities.ps1)."
    }
    if (-not $CFG.ContainsKey($alias)) {
        throw "Alias desconocido: $alias. Agregalo en GitHostAliases en el vault."
    }

    $plat   = $CFG[$alias].platform
    $base   = $CFG[$alias].base
    $tokEnv = $CFG[$alias].tokenEnv
    $token  = if ($Token) { $Token } else { Get-SecretFromEnv $tokEnv }

    if ($plat -eq 'gitlab' -and [string]::IsNullOrWhiteSpace($token)) {
        throw "Falta token ($tokEnv) para alias '$alias'."
    }

    $results = [System.Collections.Generic.List[object]]::new()

    if ($plat -eq 'gitlab') {
        $api = "$base/api/v4"
        $H   = @{ 'PRIVATE-TOKEN' = $token }

        function _gl-get($u) {
            try { ,(Invoke-RestMethod -Headers $H -Uri $u -Method GET -EA Stop) }
            catch { throw "GitLab API error: $($_.Exception.Message) ($u)" }
        }

        $isGroup = $false; $groupId = $null; $userId = $null

        try {
            $groupId = (_gl-get "$api/groups/$([uri]::EscapeDataString($ns))").id
            $isGroup = $true
        } catch {
            $u = _gl-get "$api/users?username=$([uri]::EscapeDataString($ns))"
            if ($u -and $u.Count -ge 1) { $userId = $u[0].id }
            else { throw "No se encontró grupo ni usuario '$ns' en $base" }
        }

        function _gl-addProject($p, [string]$alias, [string]$base, [System.Collections.Generic.List[object]]$results) {
            $results.Add([pscustomobject]@{
                Platform = 'GitLab'
                Name     = $p.name
                Path     = $p.path_with_namespace
                SSH      = "git@${alias}:$($p.path_with_namespace).git"
                HTTPS    = "$($base.TrimEnd('/'))/$($p.path_with_namespace).git"
                Web      = $p.web_url
            })
        }

        if ($isGroup) {
            function _gl-listProjects([int]$g, [string]$alias, [string]$api, [string]$base, [System.Collections.Generic.List[object]]$results) {
                $page = 1
                while ($true) {
                    $b = _gl-get "$api/groups/$g/projects?per_page=100&page=$page&order_by=path&simple=true"
                    if (-not $b -or $b.Count -eq 0) { break }
                    foreach ($p in $b) { _gl-addProject $p $alias $base $results }
                    $page++
                }
            }
            function _gl-listSubgroups([int]$g, [string]$alias, [string]$api, [string]$base, [System.Collections.Generic.List[object]]$results, [switch]$Recurse) {
                $page = 1
                while ($true) {
                    $b = _gl-get "$api/groups/$g/subgroups?per_page=100&page=$page&order_by=path"
                    if (-not $b -or $b.Count -eq 0) { break }
                    foreach ($sg in $b) {
                        _gl-listProjects $sg.id $alias $api $base $results
                        if ($Recurse) { _gl-listSubgroups $sg.id $alias $api $base $results -Recurse:$Recurse }
                    }
                    $page++
                }
            }
            _gl-listProjects  $groupId $alias $api $base $results
            _gl-listSubgroups $groupId $alias $api $base $results -Recurse:$Recurse
        } else {
            $page = 1
            while ($true) {
                $b = _gl-get "$api/users/$userId/projects?per_page=100&page=$page&order_by=path&simple=true"
                if (-not $b -or $b.Count -eq 0) { break }
                foreach ($p in $b) { _gl-addProject $p $alias $base $results }
                $page++
            }
        }

    } else {
        $api = $base
        $H   = @{ 'User-Agent'='gbrowser'; 'X-GitHub-Api-Version'='2022-11-28' }
        if (-not [string]::IsNullOrWhiteSpace($token)) { $H['Authorization'] = "Bearer $token" }

        function _gh-get($u) {
            try { ,(Invoke-RestMethod -Headers $H -Uri $u -Method GET -EA Stop) }
            catch { throw "GitHub API error: $($_.Exception.Message) ($u)" }
        }

        $owner, $prefix = if ($ns -match '^[^/]+/') { $ns.Split('/', 2) } else { @($ns, $null) }

        $page = 1
        while ($true) {
            try { $b = _gh-get "$api/orgs/$owner/repos?per_page=100&page=$page&sort=full_name&direction=asc&type=public" }
            catch { $b = $null }
            if (-not $b -or $b.Count -eq 0) { break }
            foreach ($r in $b) {
                if ($prefix -and ($r.name -notlike "$prefix*")) { continue }
                $path = "$owner/$($r.name)"
                $results.Add([pscustomobject]@{
                    Platform='GitHub'; Name=$r.name; Path=$path
                    SSH="git@${alias}:$path.git"; HTTPS="https://github.com/$path.git"; Web=$r.html_url
                })
            }
            $page++
        }

        if ($results.Count -eq 0) {
            $page = 1
            while ($true) {
                $b = _gh-get "$api/users/$owner/repos?per_page=100&page=$page&sort=full_name&direction=asc&type=owner"
                if (-not $b -or $b.Count -eq 0) { break }
                foreach ($r in $b) {
                    if ($prefix -and ($r.name -notlike "$prefix*")) { continue }
                    $path = "$owner/$($r.name)"
                    $results.Add([pscustomobject]@{
                        Platform='GitHub'; Name=$r.name; Path=$path
                        SSH="git@${alias}:$path.git"; HTTPS="https://github.com/$path.git"; Web=$r.html_url
                    })
                }
                $page++
            }
        }
    }

    $out = $results | Sort-Object Path
    if ($Json) {
        @{ alias=$alias; namespace=$ns; count=$out.Count; items=$out } | ConvertTo-Json -Depth 5
    } else {
        $out | Format-Table -AutoSize Platform,Name,Path,SSH
        Write-Host ("Total de repositorios en {0}:{1} → {2}" -f $alias, $ns, $out.Count) -ForegroundColor DarkCyan
    }
}

# ==============================================================================
# AWS / CLAUDE CODE SMG
# ==============================================================================

<#
.SYNOPSIS lanzar Claude Code con perfil Bedrock de SMG
.EXAMPLE claude-smg
#>
function claude-smg {
    # El perfil AWS se toma de $env:CLAUDE_SMG_AWS_PROFILE (defini en ~/.env); fallback 'default'
    $env:CLAUDE_CODE_USE_BEDROCK = "1"
    $env:AWS_PROFILE             = if ($env:CLAUDE_SMG_AWS_PROFILE) { $env:CLAUDE_SMG_AWS_PROFILE } else { 'default' }
    $env:AWS_REGION              = if ($env:CLAUDE_SMG_AWS_REGION)  { $env:CLAUDE_SMG_AWS_REGION }  else { 'us-east-1' }
    # Modelos Bedrock (inference profiles us.*). Overridables desde ~/.env.
    $env:ANTHROPIC_MODEL            = if ($env:CLAUDE_SMG_MODEL)       { $env:CLAUDE_SMG_MODEL }       else { 'us.anthropic.claude-opus-4-8' }
    $env:ANTHROPIC_SMALL_FAST_MODEL = if ($env:CLAUDE_SMG_SMALL_MODEL) { $env:CLAUDE_SMG_SMALL_MODEL } else { 'us.anthropic.claude-haiku-4-5-20251001-v1:0' }

    $cleanup = {
        Remove-Item Env:CLAUDE_CODE_USE_BEDROCK    -ErrorAction SilentlyContinue
        Remove-Item Env:AWS_PROFILE                -ErrorAction SilentlyContinue
        Remove-Item Env:AWS_REGION                 -ErrorAction SilentlyContinue
        Remove-Item Env:ANTHROPIC_MODEL            -ErrorAction SilentlyContinue
        Remove-Item Env:ANTHROPIC_SMALL_FAST_MODEL -ErrorAction SilentlyContinue
    }

    aws sts get-caller-identity --profile $env:AWS_PROFILE *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Sesion SSO caducada o ausente, ejecutando: aws sso login --profile $($env:AWS_PROFILE)" -ForegroundColor Yellow
        aws sso login --profile $env:AWS_PROFILE
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Fallo el login SSO, abortando."
            & $cleanup
            return
        }
        # Revalidar: si el perfil esta incompleto (falta sso_account_id/sso_role_name),
        # el login funciona pero no hay credenciales y entrariamos en loop.
        aws sts get-caller-identity --profile $env:AWS_PROFILE *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "El login SSO funciono pero el perfil '$($env:AWS_PROFILE)' no obtiene credenciales (revisa sso_account_id / sso_role_name con: aws configure sso)."
            & $cleanup
            return
        }
    }

    claude @args
    & $cleanup
}

# ==============================================================================
# SPF — listado de funciones del profile
# ==============================================================================

if (-not $global:__ProfileFile) {
    $global:__ProfileFile = if (Test-Path $PROFILE.AllUsersAllHosts) { $PROFILE.AllUsersAllHosts } else { $PROFILE }
}

<#
.SYNOPSIS listar funciones definidas en el profile
.EXAMPLE spf -Type GIT
.EXAMPLE spf -Filter clone -Scope Todo
#>
function spf {
    [CmdletBinding()]
    param(
        [string]$Filter = '',
        [ValidateSet('Nombre','Resumen','Sintaxis','Todo')]
        [string]$Scope = 'Nombre',
        [ValidateSet('GIT','Linux')]
        [string]$Type,
        [switch]$All,
        [switch]$IncludeFolder
    )

    $profilePath = $global:__ProfileFile
    if (-not $profilePath) {
        $profilePath = if (Test-Path $PROFILE.AllUsersAllHosts) { $PROFILE.AllUsersAllHosts } else { $PROFILE }
    }

    $files = @($profilePath)
    if ($IncludeFolder) {
        $dir = Split-Path -Parent $profilePath
        if ($dir) { $files += (Get-ChildItem $dir -Filter *.ps1 -Recurse).FullName }
    }
    $files = $files | Select-Object -Unique

    $rxCbh  = [regex]'(?ms)<#(.*?)#>\s*(?:\r?\n|\r|\n)*\s*function\s+([A-Za-z0-9_.-]+)\s*(?:\(|\{)'
    $rxFunc = [regex]'(?m)^\s*function\s+([A-Za-z0-9_.-]+)\s*(?:\(|\{)'

    function Get-ExampleFromCbh($cbhBlock) {
        if (-not $cbhBlock) { return $null }
        $m = [regex]::Match($cbhBlock, '(?ms)\.EXAMPLE\s+(.+?)(?:\r?\n\s*\.\w+|$)')
        if ($m.Success) { return ($m.Groups[1].Value -replace '\s+',' ').Trim() }
        $m2 = [regex]::Match($cbhBlock, '(?ms)\.SYNTAX\s+(.+?)(?:\r?\n\s*\.\w+|$)')
        if ($m2.Success) { return ($m2.Groups[1].Value -replace '\s+',' ').Trim() }
        return $null
    }

    function BuildSimpleSyntax($name, $text, $funcIdx) {
        $tail = $text.Substring($funcIdx, [Math]::Min(4000, $text.Length - $funcIdx))
        $pm = [regex]::Match($tail, '(?ms)\bparam\s*\((.*?)\)')
        if (-not $pm.Success) { return "$name" }
        $params = @()
        foreach ($line in ($pm.Groups[1].Value -split '\r?\n')) {
            $pname = [regex]::Match($line, '^\s*\[\w.*?\]\s*\$(\w+)').Groups[1].Value
            if (-not $pname) { $pname = [regex]::Match($line, '\$(\w+)').Groups[1].Value }
            if ($pname) {
                $isMandatory = [regex]::IsMatch($line, '\[Parameter\([^\)]*Mandatory\s*=\s*true', 'IgnoreCase')
                $params += if ($isMandatory) { "<$pname>" } else { "[$pname]" }
            }
        }
        if ($params.Count -eq 0) { return "$name" }
        return "$name " + ($params -join ' ')
    }

    function InferType($name, $synopsis, $bodySample) {
        if ($name -match '^(git|g[a-z])' -or $synopsis -match '\bgit\b' -or $bodySample -match '\bgit\s') { 'GIT' }
        else { 'Linux' }
    }

    function GetSpfRange($text) {
        $m = [regex]::Match($text, '(?ms)^\s*function\s+spf\b.*?\{')
        if (-not $m.Success) { return ,@(-1,-1) }
        $start = $m.Index; $i = $m.Index + $m.Length; $depth = 1
        while ($i -lt $text.Length -and $depth -gt 0) {
            if ($text[$i] -eq '{') { $depth++ } elseif ($text[$i] -eq '}') { $depth-- }
            $i++
        }
        return @($start, $i)
    }

    $skipNames = @('BuildSimpleSyntax','Get-ExampleFromCbh','InferType','GetSpfRange')
    $map = @{}

    foreach ($f in $files) {
        $text = Get-Content -Raw -LiteralPath $f -ErrorAction SilentlyContinue
        if (-not $text) { continue }

        $range    = GetSpfRange $text
        $spfStart = $range[0]
        $spfEnd   = $range[1]

        foreach ($m in $rxCbh.Matches($text)) {
            $cbh  = $m.Groups[1].Value
            $name = $m.Groups[2].Value
            if ($name -in $skipNames) { continue }
            if ($spfStart -ge 0 -and $m.Index -ge $spfStart -and $m.Index -lt $spfEnd -and $name -ne 'spf') { continue }

            $synopsis   = ([regex]::Match($cbh, '(?ms)\.SYNOPSIS\s+(.+?)(?:\r?\n\s*\.\w+|$)').Groups[1].Value -replace '\s+',' ').Trim()
            $example    = Get-ExampleFromCbh $cbh
            if (-not $example) { $example = BuildSimpleSyntax $name $text $m.Index }
            $bodySample = $text.Substring($m.Index, [Math]::Min(1000, $text.Length - $m.Index))
            $tipo       = InferType $name $synopsis $bodySample

            $map[$name] = [pscustomobject]@{
                Nombre  = $name
                Resumen = ($synopsis ? $synopsis : "function $name")
                Sintaxis= $example
                Tipo    = $tipo
            }
        }

        foreach ($m in $rxFunc.Matches($text)) {
            $name = $m.Groups[1].Value
            if ($name -in $skipNames) { continue }
            if ($spfStart -ge 0 -and $m.Index -ge $spfStart -and $m.Index -lt $spfEnd -and $name -ne 'spf') { continue }
            if (-not $map.ContainsKey($name)) {
                $example    = BuildSimpleSyntax $name $text $m.Index
                $bodySample = $text.Substring($m.Index, [Math]::Min(1000, $text.Length - $m.Index))
                $tipo       = InferType $name '' $bodySample
                $map[$name] = [pscustomobject]@{
                    Nombre  = $name
                    Resumen = "function $name"
                    Sintaxis= $example
                    Tipo    = $tipo
                }
            }
        }
    }

    $items = $map.GetEnumerator() | ForEach-Object { $_.Value } | Sort-Object Nombre -Unique
    if (-not $All)  { $items = $items | Where-Object { $_.Nombre -notmatch '^_' } }
    if ($Type)      { $items = $items | Where-Object { $_.Tipo -eq $Type } }

    if ($Filter) {
        $rx = [regex]::new($Filter, 'IgnoreCase')
        $items = switch ($Scope) {
            'Nombre'   { $items | Where-Object { $rx.IsMatch($_.Nombre) } }
            'Resumen'  { $items | Where-Object { $rx.IsMatch($_.Resumen) } }
            'Sintaxis' { $items | Where-Object { $rx.IsMatch($_.Sintaxis) } }
            'Todo'     { $items | Where-Object { $rx.IsMatch($_.Nombre) -or $rx.IsMatch($_.Resumen) -or $rx.IsMatch($_.Sintaxis) } }
        }
    }

    $items |
        Select-Object @{l='Comando';e='Nombre'},
                      @{l='Resumen';e='Resumen'},
                      @{l='Sintaxis';e='Sintaxis'},
                      @{l='Tipo';e='Tipo'} |
        Format-Table -AutoSize
}
