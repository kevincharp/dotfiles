# ==============================================================================
#   install.ps1 - Instala o actualiza los dotfiles (repo publico + vault privado)
#
#   irm https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1 | iex
#   pwsh -File ~/.dotfiles/install.ps1
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

# Tiene que existir desde el arranque (StrictMode). $true = corriendo via iex, donde
# un 'exit' cerraria la terminal; $false = corriendo como archivo.
$script:DOTFILES_INLINE_MODE = $false
$script:DOTFILES_EXIT_CODE   = 0

# ==============================================================================
# RE-EJECUCION COMO ARCHIVO (imprescindible bajo 'irm | iex')
# ------------------------------------------------------------------------------
# Bajo iex un 'exit' cierra la ventana del usuario: el script se baja a un temporal y
# se re-ejecuta con -File. Se baja de nuevo porque $MyInvocation, bajo iex, no es este script.
# ==============================================================================

# DOTFILES_INSTALL_REEXEC es la guarda anti-recursion (el hijo no vuelve a entrar).
if (-not $PSCommandPath -and -not $env:DOTFILES_INSTALL_REEXEC) {
    $reexecOk  = $false
    $selfUrl   = 'https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1'
    $tmpSelf   = Join-Path $env:TEMP "dotfiles-install-$PID.ps1"
    try {
        try {
            [Net.ServicePointManager]::SecurityProtocol =
                [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        } catch {}
        $prevPP = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $selfUrl -OutFile $tmpSelf -UseBasicParsing -ErrorAction Stop
        } finally { $ProgressPreference = $prevPP }

        # Sanity check: que lo bajado sea de verdad este instalador.
        $txt = Get-Content -LiteralPath $tmpSelf -Raw -ErrorAction Stop
        if ($txt -notmatch 'GH_USER\s*=' -or $txt -notmatch 'CLONAR / ACTUALIZAR REPO PUBLICO') {
            throw 'el archivo descargado no parece ser install.ps1'
        }

        $exe = $null
        try { $exe = (Get-Process -Id $PID).Path } catch {}
        if (-not $exe) { $exe = 'powershell.exe' }
        $env:DOTFILES_INSTALL_REEXEC = '1'
        $reexecOk = $true
        # $LASTEXITCODE queda seteado por esta llamada.
        & $exe -NoProfile -ExecutionPolicy Bypass -File $tmpSelf
    } catch {
        # Sin red o URL caida: se sigue en linea. Los 'exit' quedan marcados como
        # peligrosos (cerrarian la terminal) via DOTFILES_INLINE_MODE.
        Write-Host "  (no se pudo re-ejecutar como archivo: $($_.Exception.Message))" -ForegroundColor DarkGray
    } finally {
        Remove-Item -LiteralPath $tmpSelf -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\DOTFILES_INSTALL_REEXEC -ErrorAction SilentlyContinue
    }
    # 'return' y no 'exit': aca seguimos dentro de la sesion del usuario.
    if ($reexecOk) { return }
    $script:DOTFILES_INLINE_MODE = $true
}

# ==============================================================================
# CONFIGURACION
# ==============================================================================

$GH_USER      = 'kevincharp'
$PUBLIC_HTTPS = "https://github.com/$GH_USER/dotfiles.git"
$PUBLIC_SSH   = "git@github.com:$GH_USER/dotfiles.git"
$VAULT_SSH    = "git@github.com:$GH_USER/dotfiles-vault.git"
# Con el host alias del ssh/config, 'git pull' del vault no pide credenciales.
$VAULT_SSH_ALIAS = "git@github.com-${GH_USER}:$GH_USER/dotfiles-vault.git"

$DOTFILES_DIR = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME '.dotfiles' }
$VAULT_DIR    = if ($env:VAULT_DIR)    { $env:VAULT_DIR }    else { Join-Path $HOME '.dotfiles-vault' }
$BRANCH       = if ($env:DOTFILES_BRANCH) { $env:DOTFILES_BRANCH } else { 'main' }

# ==============================================================================
# HELPERS
# ==============================================================================

# Forzar UTF-8 en la consola para que los iconos se vean (no rompe si ya lo esta)
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
# Iconos por codigo de caracter, no como literales: PowerShell 5.1 lee este archivo
# como ANSI y los multibyte saldrian como mojibake.
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
    # Termina el instalador sin cerrar la terminal: si no se pudo re-ejecutar como archivo,
    # corta con 'break' sobre la etiqueta del bloque principal en vez de 'exit'.
    param([int]$Code = 1)
    if ($script:DOTFILES_INLINE_MODE) {
        Write-Host ''
        Write-Host '  (instalacion interrumpida)' -ForegroundColor DarkGray
        $script:DOTFILES_EXIT_CODE = $Code
        break dotfilesInstall
    }
    exit $Code
}

# Consola fisica (CONIN$), el /dev/tty de Windows. File.Open('CONIN$') no sirve en 5.1
# (FileStream rechaza dispositivos de consola): se pide el handle por CreateFileW.
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
    # Lee una linea del teclado real: bajo 'irm | iex' stdin es el pipe con el script.
    # Devuelve $null solo si no hay consola.
    try {
        $h = [Win32.InstallConsole]::CreateFileW('CONIN$', ([uint32]'0x80000000'), 3, [IntPtr]::Zero, 3, 0, [IntPtr]::Zero)
        if ($h -eq [IntPtr]::Zero -or $h.ToInt64() -eq -1) { return $null }
        $safe = New-Object Microsoft.Win32.SafeHandles.SafeFileHandle($h, $true)
        $fs   = New-Object System.IO.FileStream($safe, [System.IO.FileAccess]::Read)
        $sr   = New-Object System.IO.StreamReader($fs)
        try { return $sr.ReadLine() } finally { $sr.Dispose() }
    } catch {
        # Con consola pero lectura fallida no se asume "sin humano": se cae a Read-Host.
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
    # Instala winget (App Installer) desde GitHub, por usuario: falta en LTSC/Server, imagenes
    # sin Store y Sandbox. Devuelve $true si al terminar winget esta disponible.
    Write-Log 'Instalando winget (App Installer)...' 'INFO'
    Write-Log 'Son 4 descargas (~80 MB en total): 3 dependencias y el bundle.' 'INFO'

    # PowerShell 5.1 negocia TLS 1.0 por defecto y GitHub/aka.ms lo rechazan.
    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {}

    # Sin barras de progreso: en 5.1 pisan el texto impreso y hacen la descarga mas lenta.
    $prevProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $tmp = Join-Path $env:TEMP "winget-setup-$PID"
    New-Item -ItemType Directory -Path $tmp -Force -ErrorAction SilentlyContinue | Out-Null

    # Las dependencias van antes del bundle. El App Installer 1.29+ necesita
    # WindowsAppRuntime 1.8, que no viene en una imagen limpia (0x80073CF3).
    $pkgs = @(
        @{ Name = 'VCLibs';  File = 'VCLibs.appx'
           Url  = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'; Required = $false }
        @{ Name = 'UI.Xaml'; File = 'UIXaml.appx'
           Url  = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx'; Required = $false }
        @{ Name = 'WindowsAppRuntime'; File = 'WinAppRuntime.exe'
           Url  = 'https://aka.ms/windowsappsdk/1.8/latest/windowsappruntimeinstall-x64.exe'; Required = $false; Installer = 'exe' }
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
            if ($p.ContainsKey('Installer') -and $p.Installer -eq 'exe') {
                # WindowsAppRuntime viene como .exe, no como appx.
                $proc = Start-Process -FilePath $out -ArgumentList '--quiet' -Wait -PassThru -ErrorAction Stop
                if ($proc.ExitCode -ne 0) { throw "el instalador devolvio $($proc.ExitCode)" }
            } else {
                Add-AppxPackage -Path $out -ErrorAction Stop
            }
            Write-Log "$($p.Name) instalado" 'OK'
        } catch {
            $msg = $_.Exception.Message
            if (-not $p.Required) {
                # Si ya estaba instalada (caso comun) no es un problema.
                Write-Log "$($p.Name): no se instalo, sigo ($($msg.Split([char]10)[0]))" 'WARN'
                continue
            }
            # Si el bundle falla por dependencia (0x80073CF3) se reintenta con una version anterior,
            # que no necesita WindowsAppRuntime.
            Write-Log "No se pudo instalar $($p.Name)." 'WARN'
            Write-Log $msg.Split([char]10)[0] 'INFO'
            if ($msg -match '0x80073CF3|marco que no se encontro|framework') {
                Write-Log 'Reintentando con una version anterior de winget (sin esa dependencia)...' 'INFO'
                $legacyUrl = 'https://github.com/microsoft/winget-cli/releases/download/v1.9.25200/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
                $legacyOut = Join-Path $tmp 'winget-legacy.msixbundle'
                try {
                    Invoke-WebRequest -Uri $legacyUrl -OutFile $legacyOut -UseBasicParsing -ErrorAction Stop
                    Add-AppxPackage -Path $legacyOut -ErrorAction Stop
                    Write-Log 'winget (version 1.9) instalado' 'OK'
                } catch {
                    Write-Log "El reintento tambien fallo: $($_.Exception.Message.Split([char]10)[0])" 'WARN'
                }
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

    # Recien instalado puede no estar en el PATH heredado: se agrega WindowsApps a mano.
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

function Install-Pwsh7Msi {
    # Instala PowerShell 7 desde su MSI oficial, sin winget: plan B cuando winget no se
    # puede instalar. El MSI va por maquina y puede pedir elevacion.
    param([string]$Version = '7.4.6')

    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    $url  = "https://github.com/PowerShell/PowerShell/releases/download/v$Version/PowerShell-$Version-win-$arch.msi"
    $msi  = Join-Path $env:TEMP "PowerShell-$Version-win-$arch.msi"

    Write-Log "Instalando PowerShell 7 desde el MSI oficial (~100 MB)..." 'INFO'
    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {}

    $prevPP = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Log "No se pudo descargar el MSI: $($_.Exception.Message)" 'ERROR'
        $ProgressPreference = $prevPP
        return $false
    } finally { $ProgressPreference = $prevPP }

    Write-Log 'Ejecutando el instalador (puede pedir permisos de administrador)...' 'INFO'
    try {
        $args = @('/i', "`"$msi`"", '/quiet', '/norestart',
                  'ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=0', 'ENABLE_PSREMOTING=0', 'REGISTER_MANIFEST=1')
        $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList $args -Wait -PassThru -ErrorAction Stop
        # 3010 = instalado, requiere reinicio (no hace falta para usar pwsh).
        if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
            Write-Log "msiexec devolvio $($proc.ExitCode)" 'WARN'
        }
    } catch {
        Write-Log "No se pudo ejecutar el MSI: $($_.Exception.Message)" 'ERROR'
        return $false
    } finally {
        Remove-Item -LiteralPath $msi -Force -ErrorAction SilentlyContinue
    }

    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
    if (Find-Pwsh7) {
        Write-Log 'PowerShell 7 instalado' 'OK'
        return $true
    }
    Write-Log 'El MSI corrio pero no encuentro pwsh 7.' 'WARN'
    return $false
}

# Bloque etiquetado que envuelve todo el cuerpo, para que Stop-Install pueda cortar
# con 'break dotfilesInstall'. Se cierra al final del archivo.
:dotfilesInstall do {

# ==============================================================================
# 0. VERIFICAR (Y OFRECER INSTALAR) POWERSHELL 7 — antes de tocar NADA
# ------------------------------------------------------------------------------
# 'irm | iex' arranca en PowerShell 5.1 y el bootstrap exige pwsh 7: se ofrece
# instalarlo y el script se relanza solo en pwsh.
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
        # archivo como cp1252 y lo mostraria como mojibake (ver AGENTS.md).
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

        # Sin winget no se aborta: pwsh 7 tiene un MSI que no depende de el.
        $wingetOk = $true
        if ($needWinget) { $wingetOk = Install-Winget }

        if ($wingetOk) {
            Write-Log 'Instalando PowerShell 7 via winget (~100 MB, es la parte mas larga)...' 'INFO'
            # La primera corrida de winget ademas sincroniza sus indices de fuentes,
            # lo que suma bastante: se avisa para que no parezca colgado.
            if ($needWinget) { Write-Log 'winget recien instalado: la primera vez sincroniza sus fuentes.' 'INFO' }
            # --source winget: si 'msstore' falla (Sandbox, proxy), winget ve dos fuentes y no elige.
            winget install --id Microsoft.PowerShell -e --source winget --accept-package-agreements --accept-source-agreements
            # Refrescar el PATH del proceso: winget deja pwsh en Program Files pero
            # esta sesion no lo ve hasta recargar el PATH de Machine + User.
            $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                        [Environment]::GetEnvironmentVariable('Path', 'User')
            $pwshPath = Find-Pwsh7
        } else {
            Write-Log 'No se pudo instalar winget, pero PowerShell 7 no lo necesita:' 'WARN'
            Write-Log 'se usa su instalador MSI oficial. winget se puede instalar despues' 'INFO'
            Write-Log 'desde la Microsoft Store (https://aka.ms/getwinget).' 'INFO'
            if (Install-Pwsh7Msi) { $pwshPath = Find-Pwsh7 }
        }

        if (-not $pwshPath) {
            # Ultimo intento: si winget estaba pero su install de pwsh fallo, se
            # prueba el MSI antes de rendirse.
            if ($wingetOk -and (Install-Pwsh7Msi)) {
                $pwshPath = Find-Pwsh7
            }
        }
        if (-not $pwshPath) {
            Write-Log 'No se pudo dejar PowerShell 7 disponible en esta sesion.' 'ERROR'
            Write-Log 'Instalalo a mano (https://aka.ms/powershell), reabri la terminal' 'WARN'
            Write-Log 'y corre el one-liner desde pwsh:' 'WARN'
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
# Git hace falta para clonar el repo: se instala por winget y, si winget falta, se ofrece instalarlo.
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
    # --source winget: ver nota en el gate de pwsh 7 (sin esto, si msstore falla
    # winget no elige fuente y no instala nada).
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    # Refrescar el PATH del proceso actual: winget deja git en Program Files pero
    # esta sesion no lo ve hasta recargar el PATH de Machine + User.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (Test-CommandAvailable 'git')) {
        # El PATH de Machine tarda en propagarse: se agregan a mano las rutas fijas de Git for Windows.
        foreach ($gitDir in @(
            "$env:ProgramFiles\Git\cmd",
            "${env:ProgramFiles(x86)}\Git\cmd",
            "$env:LOCALAPPDATA\Programs\Git\cmd"
        )) {
            if ($gitDir -and (Test-Path (Join-Path $gitDir 'git.exe'))) {
                $env:Path = "$env:Path;$gitDir"
                break
            }
        }
    }
    if (-not (Test-CommandAvailable 'git')) {
        Write-Log 'Git se instalo pero no quedo en el PATH de esta sesion.' 'ERROR'
        Write-Log 'Cerra y reabri la terminal, y volve a correr install.ps1.' 'WARN'
        Stop-Install 1
    }
    Write-Log 'git instalado' 'OK'
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
            Write-Log 'Cambios locales detectados - autostash durante el pull' 'WARN'
        }
        git pull --rebase --autostash origin $BRANCH
        if ($LASTEXITCODE -ne 0) { Write-Log 'Error al actualizar publico' 'ERROR'; Pop-Location; exit 1 }
    } finally {
        Pop-Location
    }
} else {
    # BatchMode: sin known_hosts ssh pregunta por la huella y, con stderr descartado,
    # el instalador parece colgado. Asi falla y cae a HTTPS.
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
        Write-Log 'Vault privado (dotfiles-vault): claves SSH e identidades git.' 'INFO'
        Write-Host '    1) Clonar con gh (login por navegador)'
        Write-Host '    2) Clonar por SSH (clave ya cargada)'
        Write-Host '    3) Saltar - instala solo lo publico  [default]'
        $choice = Read-Host 'Opcion [1/2/3]'
        switch ($choice) {
            '1'     { $method = 'gh' }
            '2'     { $method = 'ssh' }
            default { $method = 'skip' }
        }
    }

    if ($method -eq 'skip') {
        Write-Log "Sin vault: git y SSH quedan como estan. Para aplicarlo despues: pwsh -File $DOTFILES_DIR\install.ps1" 'INFO'
        return $false
    }

    if ($method -eq 'gh') {
        if (-not (Test-CommandAvailable 'gh')) {
            Write-Log 'gh no instalado - instalando via winget...' 'INFO'
            if (Test-CommandAvailable 'winget') {
                winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements | Out-Null
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
            return $false
        }
        # gh clona por HTTPS; el remote pasa al host alias SSH, el unico que el ssh/config
        # del vault asocia a la clave.
        git -C $VAULT_DIR remote set-url origin $VAULT_SSH_ALIAS
        return $true
    }

    if ($method -eq 'ssh') {
        git clone $VAULT_SSH $VAULT_DIR
        if ($LASTEXITCODE -eq 0) { return $true }
        Write-Log 'Error clonando vault via SSH (tenes la clave cargada?)' 'ERROR'
        return $false
    }

    return $false
}

$VAULT_OK = $false
if ($SkipVault) {
    Write-Log '-SkipVault: omitiendo vault privado' 'WARN'
} elseif (Test-Path (Join-Path $VAULT_DIR '.git')) {
    # Un pull fallido no invalida el vault: se usa la copia local.
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
    Write-Log "Vault:   sin aplicar - git/SSH quedan como estaban (aplicarlo: pwsh -File $DOTFILES_DIR\install.ps1)" 'WARN'
}

Write-Log 'Proximos pasos' 'SECTION'
Write-Log '1. Abri una terminal nueva para recargar el profile' 'INFO'
Write-Log '2. Proba dothelp para ver los comandos disponibles' 'INFO'

$originUrl = git -C $DOTFILES_DIR remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0 -and $originUrl -like 'https://*') {
    Write-Log '3. Para pushear sin credenciales, pasa el remote a SSH:' 'INFO'
    Write-Log "   cd $DOTFILES_DIR; git remote set-url origin $PUBLIC_SSH" 'INFO'
}

# Cierre del bloque etiquetado :dotfilesInstall (ver arriba). El 'while ($false)'
# lo hace correr una sola vez; existe solo para que 'break' tenga a que salir.
} while ($false)
