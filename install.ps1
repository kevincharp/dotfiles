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
# RE-EJECUCION COMO ARCHIVO (imprescindible bajo 'irm | iex')
# ------------------------------------------------------------------------------
# Bajo 'irm ... | iex' el script corre DENTRO de la sesion interactiva, no como
# script propio. Ahi 'exit' no termina el script: termina LA SESION, o sea que
# CIERRA LA VENTANA DE LA TERMINAL — el usuario ni llega a leer el mensaje de
# error (verificado: con iex, todo lo que sigue a un 'exit' no se ejecuta y la
# consola muere; con -File la sesion sobrevive).
#
# Solucion: si venimos por iex (no hay $PSCommandPath), nos escribimos a un
# archivo temporal y nos re-ejecutamos con -File en el MISMO PowerShell. Ahi
# 'exit' es seguro y todos los mensajes se leen. Se conserva el exit code.
# ==============================================================================

# DOTFILES_INSTALL_REEXEC es la guarda anti-recursion. Sin ella, si este script
# se ejecuta por iex ANIDADO dentro de otro script, $MyInvocation devuelve el
# texto del script CONTENEDOR y se re-lanzaria a si mismo para siempre.
if (-not $PSCommandPath -and -not $env:DOTFILES_INSTALL_REEXEC) {
    $self = $null
    try { $self = $MyInvocation.MyCommand.ScriptBlock.ToString() } catch {}
    # Verificar que el texto sea REALMENTE este script y no el del contenedor
    # (con un iex anidado $MyInvocation devuelve el script de afuera).
    if ($self -and $self -match 'GH_USER\s*=' -and $self -match 'CLONAR / ACTUALIZAR REPO PUBLICO') {
        $reexecOk = $false
        $tmpSelf = Join-Path $env:TEMP "dotfiles-install-$PID.ps1"
        try {
            # UTF8 sin BOM no sirve para 5.1 (lee ANSI): se escribe en Default
            # (cp1252), que es justo como 5.1 espera leerlo. El archivo es ASCII
            # puro por diseno (ver CLAUDE.md), asi que no hay perdida.
            Set-Content -LiteralPath $tmpSelf -Value $self -Encoding Default -ErrorAction Stop
            $exe = $null
            try { $exe = (Get-Process -Id $PID).Path } catch {}
            if (-not $exe) { $exe = 'powershell.exe' }
            $env:DOTFILES_INSTALL_REEXEC = '1'
            $reexecOk = $true
            # $LASTEXITCODE queda seteado por esta llamada: el usuario puede
            # consultarlo despues, igual que con cualquier comando.
            & $exe -NoProfile -ExecutionPolicy Bypass -File $tmpSelf
        } catch {
            Write-Host "  No se pudo re-ejecutar como archivo: $($_.Exception.Message)" -ForegroundColor DarkYellow
        } finally {
            Remove-Item -LiteralPath $tmpSelf -Force -ErrorAction SilentlyContinue
            Remove-Item Env:\DOTFILES_INSTALL_REEXEC -ErrorAction SilentlyContinue
        }
        # 'return' y no 'exit': aca seguimos dentro de la sesion del usuario.
        if ($reexecOk) { return }
        # Si la re-ejecucion fallo se sigue en linea, pero marcando que los
        # 'exit' son peligrosos (cerrarian la terminal): ver Stop-Install.
        $script:DOTFILES_INLINE_MODE = $true
    } else {
        $script:DOTFILES_INLINE_MODE = $true
    }
}

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
# Iconos: UTF-8 si la consola lo soporta, si no ASCII.
# Se construyen por CODIGO de caracter, no como literales del archivo: PowerShell
# 5.1 lee este .ps1 como ANSI (cp1252) y los literales multibyte saldrian como
# mojibake justo en el mensaje del gate de pwsh 7, que es lo unico que ve 5.1.
$script:ICONS = if ([Console]::OutputEncoding.CodePage -eq 65001 -and $PSVersionTable.PSVersion.Major -ge 7) {
    @{ Section=[char]0x25B6; Ok=[char]0x2713; Warn=[char]0x26A0; Err=[char]0x2717; Skip=[char]0x2298 }
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

function Stop-Install {
    # Termina el instalador SIN cerrarle la terminal al usuario.
    # Bajo 'irm | iex' un 'exit' pelado mata la sesion (cierra la ventana). Lo
    # normal es que la re-ejecucion como archivo ya nos haya puesto a salvo; si
    # no se pudo (DOTFILES_INLINE_MODE), se lanza una excepcion que corta el
    # script y deja la consola viva.
    param([int]$Code = 1)
    if ($script:DOTFILES_INLINE_MODE) {
        Write-Host ''
        Write-Host '  (instalacion interrumpida)' -ForegroundColor DarkGray
        throw [System.OperationCanceledException]::new('dotfiles-install-abort')
    }
    exit $Code
}

# Acceso a la consola fisica (CONIN$) — el equivalente a /dev/tty en Linux.
# OJO: [System.IO.File]::Open('CONIN$') NO SIRVE. FileStream rechaza abrir
# dispositivos de consola ("se solicito a FileStream que abriera un dispositivo
# que no era un archivo"), asi que fallaba SIEMPRE y Read-ConsoleLine devolvia
# $null: el instalador creia que no habia humano, se iba por la rama "sin consola"
# y hacia exit -> bajo 'irm | iex' eso CIERRA LA TERMINAL sin dejar contestar.
# La forma que si funciona es pedir el handle por CreateFileW y envolverlo.
Add-Type -Namespace Win32 -Name InstallConsole -MemberDefinition @'
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern System.IntPtr CreateFileW(
        string lpFileName, uint dwDesiredAccess, uint dwShareMode,
        System.IntPtr lpSecurityAttributes, uint dwCreationDisposition,
        uint dwFlagsAndAttributes, System.IntPtr hTemplateFile);
'@ -ErrorAction SilentlyContinue

function Test-ConsolePresent {
    # $true si hay una consola fisica adjunta (un humano), aunque stdin venga por
    # pipe (que es el caso de 'irm | iex').
    try {
        # 0x80000000 (GENERIC_READ) se castea a [uint32]: PowerShell lo toma como
        # Int32 negativo y la llamada falla al convertir el argumento.
        $h = [Win32.InstallConsole]::CreateFileW('CONIN$', ([uint32]'0x80000000'), 3, [IntPtr]::Zero, 3, 0, [IntPtr]::Zero)
        return ($h -ne [IntPtr]::Zero -and $h.ToInt64() -ne -1)
    } catch { return $false }
}

function Read-ConsoleLine {
    # Lee una linea del teclado REAL, no de stdin. Imprescindible bajo
    # 'irm | iex': ahi stdin es el pipe con el texto del script y Read-Host no
    # ve al usuario. Devuelve $null solo si de verdad no hay consola (CI).
    try {
        $h = [Win32.InstallConsole]::CreateFileW('CONIN$', ([uint32]'0x80000000'), 3, [IntPtr]::Zero, 3, 0, [IntPtr]::Zero)
        if ($h -eq [IntPtr]::Zero -or $h.ToInt64() -eq -1) { return $null }
        $safe = New-Object Microsoft.Win32.SafeHandles.SafeFileHandle($h, $true)
        $fs   = New-Object System.IO.FileStream($safe, [System.IO.FileAccess]::Read)
        $sr   = New-Object System.IO.StreamReader($fs)
        try { return $sr.ReadLine() } finally { $sr.Dispose() }
    } catch {
        # Si hay consola pero la lectura fallo, NO se puede asumir "no hay
        # humano": se cae a Read-Host, que al menos funciona cuando el script
        # corre como archivo (que es el caso tras la re-ejecucion).
        try { return Read-Host } catch { return $null }
    }
}

function Find-Pwsh7 {
    # Ubica pwsh.exe. Tras instalarlo por winget NO esta en el PATH de esta
    # sesion, asi que se buscan tambien las rutas fijas del instalador.
    $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in @(
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe"
    )) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

function Install-Winget {
    # Instala winget (App Installer) descargando el paquete oficial de GitHub.
    # No se puede asumir que winget exista: falta en Windows LTSC/Server, en
    # imagenes corporativas sin Microsoft Store y en Windows Sandbox. Es la
    # unica dependencia sin la cual no podemos instalar NADA mas.
    # Devuelve $true si al terminar winget esta disponible.
    #
    # Ojo: se instala con Add-AppxPackage (por usuario), no requiere admin.
    # VCLibs y UI.Xaml son dependencias del .msixbundle; si ya estan, el
    # Add-AppxPackage falla con "ya instalado" y se ignora.
    Write-Log 'Instalando winget (App Installer)...' 'INFO'
    Write-Log 'Son 3 descargas (~100 MB), puede tardar un rato.' 'INFO'

    # PowerShell 5.1 negocia TLS 1.0 por defecto y GitHub/aka.ms lo rechazan.
    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {}

    # Silenciar las barras de progreso de Invoke-WebRequest y Add-AppxPackage:
    # en 5.1 se dibujan sobre la pantalla y pisan el texto ya impreso (queda todo
    # desordenado), y ademas hacen la descarga MUCHO mas lenta. Se restaura al
    # salir de la funcion.
    $prevProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $tmp = Join-Path $env:TEMP "winget-setup-$PID"
    New-Item -ItemType Directory -Path $tmp -Force -ErrorAction SilentlyContinue | Out-Null

    # El orden importa: las dependencias van antes del bundle.
    $pkgs = @(
        @{ Name = 'VCLibs';  File = 'VCLibs.appx'
           Url  = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'; Required = $false }
        @{ Name = 'UI.Xaml'; File = 'UIXaml.appx'
           Url  = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx'; Required = $false }
        @{ Name = 'App Installer (winget)'; File = 'winget.msixbundle'
           Url  = 'https://aka.ms/getwinget'; Required = $true }
    )

    $n = 0
    foreach ($p in $pkgs) {
        $n = $n + 1
        $out = Join-Path $tmp $p.File
        Write-Log "[$n/$($pkgs.Count)] bajando $($p.Name)..." 'INFO'
        try {
            # -UseBasicParsing: 5.1 sin IE configurado falla sin esto.
            Invoke-WebRequest -Uri $p.Url -OutFile $out -UseBasicParsing -ErrorAction Stop
        } catch {
            if ($p.Required) {
                Write-Log "No se pudo descargar $($p.Name): $($_.Exception.Message)" 'ERROR'
                Write-Log 'Si es un error de certificado, puede ser un proxy corporativo.' 'INFO'
                $ProgressPreference = $prevProgress
                return $false
            }
            Write-Log "No se pudo bajar $($p.Name) (dependencia opcional, sigo)" 'WARN'
            continue
        }
        try {
            Add-AppxPackage -Path $out -ErrorAction Stop
            Write-Log "$($p.Name) instalado" 'OK'
        } catch {
            # Si ya estaba instalada (caso comun) no es un problema.
            if ($p.Required) {
                Write-Log "No se pudo instalar $($p.Name): $($_.Exception.Message)" 'WARN'
            }
        }
    }

    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    $ProgressPreference = $prevProgress

    # Refrescar el PATH: winget queda en WindowsApps, que esta en el PATH de
    # usuario pero esta sesion no lo releyo.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')

    if (Test-CommandAvailable 'winget') {
        Write-Log 'winget instalado' 'OK'
        return $true
    }

    # Recien instalado por Appx, a veces no aparece en el PATH heredado: se
    # agrega WindowsApps a mano (ahi vive el alias de ejecucion de winget) para
    # no obligar al usuario a reabrir la terminal.
    $wa = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if (Test-Path (Join-Path $wa 'winget.exe')) {
        $env:Path = "$env:Path;$wa"
        if (Test-CommandAvailable 'winget') {
            Write-Log 'winget instalado' 'OK'
            return $true
        }
        Write-Log 'winget se instalo pero no responde en esta sesion.' 'WARN'
        Write-Log 'Cerra y reabri la terminal, y volve a correr el one-liner.' 'WARN'
        return $false
    }
    Write-Log 'winget no quedo disponible tras la instalacion' 'ERROR'
    return $false
}

# ==============================================================================
# 0. VERIFICAR (Y OFRECER INSTALAR) POWERSHELL 7 — antes de tocar NADA
# ------------------------------------------------------------------------------
# La consola por defecto de Windows es PowerShell 5.1, asi que el one-liner
# 'irm | iex' arranca ahi por default. El bootstrap exige pwsh 7 y aborta — si
# ese chequeo llegara recien al final, el usuario ya habria instalado git,
# clonado el repo y contestado dos preguntas para nada.
#
# En vez de mandarlo a copiar comandos: se le ofrece instalar pwsh 7 y el script
# se RELANZA solo en pwsh, asi el one-liner sigue siendo un unico paso. pwsh 7
# ademas ya esta en el catalogo del bootstrap (grupo core), asi que instalarlo
# aca no agrega nada que no fuera a instalarse igual.
# ==============================================================================

if ($PSVersionTable.PSVersion.Major -lt 7) {
    $oneLiner = 'irm https://raw.githubusercontent.com/' + $GH_USER + '/dotfiles/main/install.ps1 | iex'

    Write-Log 'Requisitos' 'SECTION'
    Write-Log "Estas en PowerShell $($PSVersionTable.PSVersion) - el instalador necesita PowerShell 7+." 'WARN'

    $pwshPath = Find-Pwsh7

    if (-not $pwshPath) {
        # No esta: ofrecer instalarlo. Si winget tampoco esta, se ofrece instalar
        # LOS DOS en el mismo paso (una sola pregunta, no dos seguidas).
        $needWinget = -not (Test-CommandAvailable 'winget')

        Write-Log 'PowerShell 7 es parte del entorno que instala este repo (grupo core).' 'INFO'
        if ($needWinget) {
            Write-Log 'Tampoco esta winget (App Installer), que es el gestor de paquetes' 'WARN'
            Write-Log 'de Windows y lo que este instalador usa para todo lo demas.' 'WARN'
        }
        Write-Host ''
        # Sin '¿' a proposito: este texto lo imprime PowerShell 5.1, que lee el
        # archivo como cp1252 y lo mostraria como mojibake (ver CLAUDE.md).
        $prompt = if ($needWinget) {
            '  Instalo winget + PowerShell 7 y sigo con la instalacion? [S/n]: '
        } else {
            '  Lo instalo ahora y sigo con la instalacion? [S/n]: '
        }
        Write-Host $prompt -NoNewline
        $answer = Read-ConsoleLine

        # Comandos que se sugieren si el usuario dice no (o no hay consola).
        $manual = @()
        if ($needWinget) { $manual += '  Instala "App Installer" desde la Microsoft Store (https://aka.ms/getwinget)' }
        $manual += '  winget install --id Microsoft.PowerShell -e'
        $manual += "  pwsh -NoProfile -Command `"$oneLiner`""

        if ($null -eq $answer) {
            # Sin consola (CI/headless): no instalar por sorpresa.
            Write-Log 'Sin consola interactiva - no instalo nada por mi cuenta.' 'WARN'
            foreach ($m in $manual) { Write-Log $m 'INFO' }
            Stop-Install 1
        }
        if ($answer.Trim() -match '^[nN]') {
            Write-Log 'Entendido, no instalo nada. Cuando quieras:' 'INFO'
            foreach ($m in $manual) { Write-Log $m 'INFO' }
            Stop-Install 1
        }

        if ($needWinget) {
            if (-not (Install-Winget)) {
                Write-Log 'Sin winget no puedo seguir instalando.' 'ERROR'
                Write-Log 'Opciones: instalar "App Installer" desde la Microsoft Store' 'WARN'
                Write-Log '(https://aka.ms/getwinget), o PowerShell 7 a mano (https://aka.ms/powershell)' 'WARN'
                Write-Log 'y volver a correr el one-liner desde pwsh.' 'WARN'
                Stop-Install 1
            }
        }

        Write-Log 'Instalando PowerShell 7 via winget...' 'INFO'
        winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements
        # Refrescar el PATH del proceso: winget deja pwsh en Program Files pero
        # esta sesion no lo ve hasta recargar el PATH de Machine + User.
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                    [Environment]::GetEnvironmentVariable('Path', 'User')
        $pwshPath = Find-Pwsh7
        if (-not $pwshPath) {
            Write-Log 'PowerShell 7 se instalo pero no lo encuentro en esta sesion.' 'ERROR'
            Write-Log 'Cerra y reabri la terminal, y corre el one-liner desde pwsh:' 'WARN'
            Write-Log "  pwsh -NoProfile -Command `"$oneLiner`"" 'INFO'
            Stop-Install 1
        }
        Write-Log 'PowerShell 7 instalado' 'OK'
    } else {
        Write-Log "PowerShell 7 ya esta instalado ($pwshPath)" 'OK'
    }

    # Relanzar en pwsh 7 y salir con SU codigo: el usuario ve una sola corrida.
    Write-Log 'Continuando en PowerShell 7...' 'INFO'
    if ($PSCommandPath) {
        # Corriendo desde archivo: se reenvian los parametros tal como vinieron.
        $fwd = @()
        foreach ($kv in $PSBoundParameters.GetEnumerator()) {
            if ($kv.Value -is [switch]) { if ($kv.Value.IsPresent) { $fwd += "-$($kv.Key)" } }
            else { $fwd += @("-$($kv.Key)", [string]$kv.Value) }
        }
        & $pwshPath -NoProfile -File $PSCommandPath @fwd
    } else {
        # Vino por 'irm | iex' (no hay archivo): se rebaja el script en pwsh.
        # Este camino no lleva parametros porque el one-liner tampoco los acepta.
        & $pwshPath -NoProfile -Command $oneLiner
    }
    Stop-Install $LASTEXITCODE
}

# ==============================================================================
# 1. VERIFICAR GIT (bootstrap del bootstrap)
# ------------------------------------------------------------------------------
# Git hace falta ANTES que nada: este script clona el repo con 'git clone'. Como
# ya no lo instalamos manual (las opciones del wizard las cubre el .gitconfig del
# vault: core.editor=nvim, core.autocrlf=input), lo auto-instalamos por winget si
# falta — y si winget tampoco esta, se ofrece instalarlo (no se puede asumir:
# falta en LTSC/Server, imagenes corporativas sin Store y Windows Sandbox).
#
# Este bloque tambien cubre a quien YA tenia pwsh 7 pero no winget: en ese caso
# el gate de arriba no corrio y esta es la primera vez que se necesita winget.
# ==============================================================================

Write-Log 'Verificando requisitos...' 'SECTION'

if (-not (Test-CommandAvailable 'git')) {
    Write-Log 'Git no esta instalado.' 'WARN'
    if (-not (Test-CommandAvailable 'winget')) {
        Write-Log 'Tampoco esta winget, que es lo que se usa para instalarlo.' 'WARN'
        Write-Host ''
        Write-Host '  Instalo winget (App Installer) y sigo? [S/n]: ' -NoNewline
        $ans = Read-ConsoleLine
        if ($null -eq $ans -or $ans.Trim() -match '^[nN]') {
            if ($null -eq $ans) { Write-Log 'Sin consola interactiva - no instalo nada por mi cuenta.' 'WARN' }
            else { Write-Log 'Entendido, no instalo nada.' 'INFO' }
            Write-Log '  Instala "App Installer" desde la Microsoft Store (https://aka.ms/getwinget)' 'INFO'
            Write-Log '  o Git a mano (https://gitforwindows.org/), y reintenta.' 'INFO'
            Stop-Install 1
        }
        if (-not (Install-Winget)) {
            Write-Log 'Sin winget no puedo instalar git. Instalalo a mano y reintenta:' 'ERROR'
            Write-Log '  https://aka.ms/getwinget  (o git: https://gitforwindows.org/)' 'INFO'
            Stop-Install 1
        }
    }
    Write-Log 'Instalando git via winget...' 'INFO'
    winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
    # Refrescar el PATH del proceso actual: winget deja git en Program Files pero
    # esta sesion no lo ve hasta recargar el PATH de Machine + User.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (Test-CommandAvailable 'git')) {
        Write-Log 'Git se instalo pero no quedo en el PATH de esta sesion.' 'ERROR'
        Write-Log 'Cerra y reabri la terminal, y volve a correr install.ps1.' 'WARN'
        Stop-Install 1
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
    # BatchMode=yes es imprescindible: en una maquina nueva sin known_hosts, ssh
    # pregunta por la huella del host y espera respuesta — con stderr redirigido
    # a $null esa pregunta es INVISIBLE y el instalador parece colgado. Con
    # BatchMode falla al instante y cae a HTTPS.
    $prevSshCmd = $env:GIT_SSH_COMMAND
    $env:GIT_SSH_COMMAND = 'ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new'
    try {
        git clone $PUBLIC_SSH $DOTFILES_DIR 2>$null
    } finally {
        if ($null -eq $prevSshCmd) { Remove-Item Env:\GIT_SSH_COMMAND -ErrorAction SilentlyContinue }
        else { $env:GIT_SSH_COMMAND = $prevSshCmd }
    }
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
        Write-Host '    3) No tengo vault - crear mis perfiles de git AHORA (asistente guiado)'
        Write-Host '    4) Saltar - instala solo lo publico  [default]'
        Write-Host '       (asistente y vault propio, cuando quieras: docs/adaptalo.md)'
        $choice = Read-Host 'Opcion [1/2/3/4]'
        switch ($choice) {
            '1'     { $method = 'gh' }
            '2'     { $method = 'ssh' }
            '3'     { $method = 'wizard' }
            default { $method = 'skip' }
        }
    }

    if ($method -eq 'wizard') {
        # El asistente pregunta perfiles/claves y deja un vault local valido en
        # VAULT_DIR: el bootstrap despues lo aplica por el camino normal. Corre
        # como proceso aparte (usa 'exit' internamente).
        $wiz = Join-Path $DOTFILES_DIR 'git-profiles.ps1'
        $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
        & $shell -ExecutionPolicy Bypass -File $wiz
        if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $VAULT_DIR 'git\config'))) { return $true }
        Write-Log 'El asistente no completo - sigo sin vault' 'WARN'
        Write-Log "  Podes correrlo cuando quieras: pwsh -File $DOTFILES_DIR\git-profiles.ps1" 'INFO'
        return $false
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
    Stop-Install 0
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
$bootstrapRc = $LASTEXITCODE

# Si el bootstrap aborto (requisito faltante, cancelado), NO imprimir el resumen
# de exito: decia "Instalacion completada" sobre una instalacion que no paso.
if ($bootstrapRc -and $bootstrapRc -ne 0) {
    Write-Log 'Instalacion incompleta' 'SECTION'
    Write-Log "El bootstrap termino con error (codigo $bootstrapRc) - no se aplico todo." 'ERROR'
    Write-Log "El repo quedo clonado en $DOTFILES_DIR (re-correr es seguro, es idempotente)." 'INFO'
    Write-Log "Revisa el detalle en el log: $HOME\.local\logs\" 'INFO'
    Stop-Install $bootstrapRc
}

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
Write-Log '2. Proba dothelp para ver los comandos disponibles' 'INFO'

# El consejo de pasar el remote a SSH solo aplica si el repo es TUYO (o forkeaste
# y cambiaste GH_USER). Si estas probando el repo de otra persona, ese remote
# apunta a donde no podes pushear: mejor no sugerirlo.
$originUrl = git -C $DOTFILES_DIR remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0 -and $originUrl -like 'https://*') {
    Write-Log '3. Si es TU repo (o tu fork) y queres pushear sin credenciales, pasa el remote a SSH:' 'INFO'
    Write-Log "   cd $DOTFILES_DIR; git remote set-url origin $PUBLIC_SSH" 'INFO'
}
