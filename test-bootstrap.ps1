# ==============================================================================
#   test-bootstrap.ps1 — Validacion post-bootstrap (Windows / pwsh 7)
#   Uso:   pwsh -File test-bootstrap.ps1
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ==============================================================================
# CONFIG
# ==============================================================================

$LOG_DIR  = Join-Path $HOME ".local\logs"
New-Item -ItemType Directory -Path $LOG_DIR -Force -ErrorAction SilentlyContinue | Out-Null
$LOG_FILE = Join-Path $LOG_DIR "test-bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

$script:PASS = 0
$script:FAIL = 0
$script:WARN = 0

# ==============================================================================
# HELPERS
# ==============================================================================

function Test-OK($Name) {
    $script:PASS++
    Write-Host "[OK]   $Name" -ForegroundColor Green
    Add-Content -Path $LOG_FILE -Value "[OK]   $Name"
}

function Test-Fail($Name, $Detail) {
    $script:FAIL++
    Write-Host "[FAIL] ${Name}: $Detail" -ForegroundColor Red
    Add-Content -Path $LOG_FILE -Value "[FAIL] ${Name}: $Detail"
}

function Test-Warn($Name, $Detail) {
    $script:WARN++
    Write-Host "[WARN] ${Name}: $Detail" -ForegroundColor DarkYellow
    Add-Content -Path $LOG_FILE -Value "[WARN] ${Name}: $Detail"
}

function Write-Section($Title) {
    Write-Host ""
    Write-Host "--- $Title ---" -ForegroundColor Cyan
    Add-Content -Path $LOG_FILE -Value "--- $Title ---"
}

function Test-CommandExists($Cmd) {
    return [bool](Get-Command $Cmd -ErrorAction SilentlyContinue)
}

# Identidades y aliases esperados (desde el vault, misma fuente que el shell).
$GitIdentities  = @{}
$GitSshAliases  = @{}
$giFile = Join-Path ($env:XDG_CONFIG_HOME ?? (Join-Path $HOME '.config')) 'git-identities.ps1'
if (Test-Path -LiteralPath $giFile) { . $giFile }
$VaultLoaded = ($GitIdentities.Count -gt 0)

# ==============================================================================
# 1. DIRECTORIOS REQUERIDOS
# ==============================================================================

Write-Section "1. Directorios requeridos"

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

foreach ($dir in $DIRS) {
    if (Test-Path $dir) {
        Test-OK "$dir existe"
    } else {
        Test-Fail $dir "no existe"
    }
}

# ==============================================================================
# 2. DOTFILES COPIADOS Y NO VACIOS
# ==============================================================================

Write-Section "2. Dotfiles copiados"

$DOTFILES = @(
    "$HOME\.config\powershell\profile.ps1"
    "$HOME\.bashrc"
    "$HOME\.bash_profile"
    "$HOME\.gitconfig"
    "$HOME\.gitconfig-personal"
    "$HOME\.gitconfig-work"
    "$HOME\.gitconfig-cei_walle"
    "$HOME\.config\git\ignore"
    "$HOME\.ssh\config"
    "$HOME\.editorconfig"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
)

foreach ($f in $DOTFILES) {
    $name = Split-Path $f -Leaf
    if (Test-Path $f) {
        $item = Get-Item -LiteralPath $f -Force
        # En Windows, (Get-Item).Length de un symlink devuelve 0;
        # resolvemos el target para medir el archivo real.
        if ($item.LinkType -eq 'SymbolicLink') {
            $target = $item.Target
            if ($target -and -not [System.IO.Path]::IsPathRooted($target)) {
                $target = Join-Path (Split-Path $f -Parent) $target
            }
            $size = if ($target -and (Test-Path $target)) { (Get-Item -LiteralPath $target).Length } else { 0 }
        } else {
            $size = $item.Length
        }
        if ($size -gt 0) {
            Test-OK "$name presente y no vacio"
        } else {
            Test-Fail $name "existe pero esta vacio"
        }
    } else {
        Test-Fail $name "no encontrado en $f"
    }
}

# ==============================================================================
# 3. COMANDOS EN PATH
# ==============================================================================

Write-Section "3. Comandos en PATH"

$REQUIRED_CMDS = @('git', 'nvim', 'node')
$OPTIONAL_CMDS = @('oh-my-posh', 'zoxide', 'fzf', 'rg', 'lazygit', 'eza', 'age')

foreach ($cmd in $REQUIRED_CMDS) {
    if (Test-CommandExists $cmd) {
        Test-OK "$cmd disponible"
    } else {
        Test-Fail $cmd "no encontrado en PATH"
    }
}

foreach ($cmd in $OPTIONAL_CMDS) {
    if (Test-CommandExists $cmd) {
        Test-OK "$cmd disponible"
    } else {
        Test-Warn $cmd "no encontrado en PATH (opcional)"
    }
}

# ==============================================================================
# 4. PERMISOS ~/.ssh
# ==============================================================================

Write-Section "4. Permisos ~/.ssh"

$sshPath = "$HOME\.ssh"
if (Test-Path $sshPath) {
    $acl = Get-Acl $sshPath
    $isProtected = $acl.AreAccessRulesProtected
    $extraRules = $acl.Access | Where-Object {
        $_.IdentityReference.Value -notmatch "SYSTEM|Administrators|$([regex]::Escape($env:USERNAME))"
    }
    if ($isProtected -and -not $extraRules) {
        Test-OK "~/.ssh permisos restringidos correctamente"
    } else {
        $detail = if (-not $isProtected) { "herencia no deshabilitada" } else { "hay reglas de acceso extra" }
        Test-Fail "~/.ssh permisos" $detail
    }
} else {
    Test-Fail "~/.ssh" "directorio no existe"
}

# ==============================================================================
# 5. PERMISOS ~/.env
# ==============================================================================

Write-Section "5. Permisos ~/.env"

$envFile = Join-Path $HOME ".env"
if (Test-Path $envFile) {
    $acl = Get-Acl $envFile
    $isProtected = $acl.AreAccessRulesProtected
    $extraRules = $acl.Access | Where-Object {
        $_.IdentityReference.Value -notmatch "SYSTEM|Administrators|$([regex]::Escape($env:USERNAME))"
    }
    if ($isProtected -and -not $extraRules) {
        Test-OK "~/.env permisos restringidos correctamente"
    } else {
        $detail = if (-not $isProtected) { "herencia no deshabilitada" } else { "hay reglas de acceso extra" }
        Test-Fail "~/.env permisos" $detail
    }
} else {
    Test-Warn "~/.env" "no existe (crealo manualmente con tus tokens)"
}

# ==============================================================================
# 6. SSH CONFIG: HOST ALIASES
# ==============================================================================

Write-Section "6. SSH config — host aliases"

$sshConfig = "$HOME\.ssh\config"

if (-not $VaultLoaded) {
    Test-Warn "SSH host aliases" "vault no cargado ($giFile) — saltando"
} elseif (Test-Path $sshConfig) {
    $sshContent = Get-Content $sshConfig -Raw

    foreach ($hostAlias in $GitSshAliases.Keys) {
        $expectedKey = $GitSshAliases[$hostAlias]

        if ($sshContent -match "Host\s+$([regex]::Escape($hostAlias))") {
            Test-OK "SSH host $hostAlias definido"
        } else {
            Test-Fail "SSH host $hostAlias" "no encontrado en ssh/config"
            continue
        }

        if ($sshContent -match "(?s)Host\s+$([regex]::Escape($hostAlias)).*?IdentityFile.*?$([regex]::Escape($expectedKey))") {
            Test-OK "SSH $hostAlias → IdentityFile $expectedKey"
        } else {
            Test-Fail "SSH $hostAlias IdentityFile" "esperado $expectedKey"
        }

        if ($sshContent -match "(?s)Host\s+$([regex]::Escape($hostAlias)).*?IdentitiesOnly\s+yes") {
            Test-OK "SSH $hostAlias → IdentitiesOnly yes"
        } else {
            Test-Fail "SSH $hostAlias IdentitiesOnly" "no tiene IdentitiesOnly yes"
        }
    }
} else {
    Test-Fail "SSH config" "$sshConfig no existe"
}

# ==============================================================================
# 7. GIT CONFIG: useConfigOnly + includeIf
# ==============================================================================

Write-Section "7. Git config — useConfigOnly + includeIf"

$gitConfig = "$HOME\.gitconfig"

if (Test-Path $gitConfig) {
    $val = git config --file $gitConfig --get user.useConfigOnly 2>$null
    if ($val -eq 'true') {
        Test-OK "user.useConfigOnly = true"
    } else {
        Test-Fail "user.useConfigOnly" "valor: '$val', esperado: 'true'"
    }

    $gcContent = Get-Content $gitConfig -Raw
    $INCLUDE_PATTERNS = if ($VaultLoaded) { $GitSshAliases.Keys | ForEach-Object { "git@$_" } } else { @() }

    if (-not $VaultLoaded) {
        Test-Warn "includeIf patterns" "vault no cargado — saltando"
    }
    foreach ($pattern in $INCLUDE_PATTERNS) {
        if ($gcContent -match [regex]::Escape($pattern)) {
            Test-OK "includeIf para $pattern presente"
        } else {
            Test-Fail "includeIf $pattern" "no encontrado en .gitconfig"
        }
    }
} else {
    Test-Fail ".gitconfig" "no existe"
}

# ==============================================================================
# 8. IDENTITY CONFIGS
# ==============================================================================

Write-Section "8. Identity configs — user.name y user.email"

# Valores esperados desde el vault (cargado al inicio del script).
if (-not $VaultLoaded) {
    Test-Warn "Identity configs" "vault no cargado ($giFile) — saltando"
    $IDENTITIES = @()
} else {
    $IDENTITIES = @(
        @{ File="$HOME\.gitconfig-personal";  Name=$GitIdentities['kevincharp'].name; Email=$GitIdentities['kevincharp'].email }
        @{ File="$HOME\.gitconfig-work";      Name=$GitIdentities['work'].name;       Email=$GitIdentities['work'].email }
        @{ File="$HOME\.gitconfig-cei_walle"; Name=$GitIdentities['cei_walle'].name;  Email=$GitIdentities['cei_walle'].email }
    )
}

foreach ($id in $IDENTITIES) {
    $label = Split-Path $id.File -Leaf
    if (-not (Test-Path $id.File)) {
        Test-Fail $label "archivo no existe"
        continue
    }

    $actualName  = git config --file $id.File --get user.name 2>$null
    $actualEmail = git config --file $id.File --get user.email 2>$null

    if ($actualName -eq $id.Name) {
        Test-OK "$label user.name = $actualName"
    } else {
        Test-Fail "$label user.name" "tiene '$actualName', esperado '$($id.Name)'"
    }

    if ($actualEmail -eq $id.Email) {
        Test-OK "$label user.email = $actualEmail"
    } else {
        Test-Fail "$label user.email" "tiene '$actualEmail', esperado '$($id.Email)'"
    }
}

# ==============================================================================
# 9. SSH KEYS EXISTEN
# ==============================================================================

Write-Section "9. SSH keys"

if (-not $VaultLoaded) {
    Test-Warn "SSH keys" "vault no cargado — saltando"
} else {
    $SSH_KEYS = $GitSshAliases.Values | Sort-Object -Unique
    foreach ($key in $SSH_KEYS) {
        $keyPath = "$HOME\.ssh\$key"
        if (Test-Path $keyPath) {
            Test-OK "SSH key $keyPath existe"
        } else {
            Test-Fail "SSH key $keyPath" "no encontrada"
        }
    }
}

# ==============================================================================
# 10. RESOLUCION DE IDENTIDAD GIT
# ==============================================================================

Write-Section "10. Resolucion de identidad git (includeIf + hasconfig)"

$gitVer = git --version 2>$null
$gitVerMatch = [regex]::Match($gitVer, '(\d+)\.(\d+)')
$gitMajor = [int]$gitVerMatch.Groups[1].Value
$gitMinor = [int]$gitVerMatch.Groups[2].Value

if ($gitMajor -lt 2 -or ($gitMajor -eq 2 -and $gitMinor -lt 36)) {
    Test-Warn "Git version" "git $gitMajor.$gitMinor < 2.36, hasconfig:remote no soportado — saltando"
} else {
    function Test-GitIdentity($RemoteUrl, $ExpName, $ExpEmail, $Label) {
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("test-git-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        try {
            Push-Location $tmpDir
            git init -b main 2>&1 | Out-Null
            git remote add origin $RemoteUrl 2>&1 | Out-Null
            $actualName  = git config --get user.name 2>$null
            $actualEmail = git config --get user.email 2>$null

            if ($actualName -eq $ExpName -and $actualEmail -eq $ExpEmail) {
                Test-OK "Identidad $Label resuelta correctamente"
            } else {
                Test-Fail "Identidad $Label" "name='$actualName' email='$actualEmail' (esperado: '$ExpName' / '$ExpEmail')"
            }
        } finally {
            Pop-Location
            Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $VaultLoaded -or -not $GitProfileRemotes) {
        Test-Warn "Resolucion de identidad" "vault no cargado — saltando"
    } else {
        foreach ($r in $GitProfileRemotes) {
            Test-GitIdentity $r.url $GitIdentities[$r.profile].name $GitIdentities[$r.profile].email $r.label
        }
    }
}

# ==============================================================================
# 11. FUNCIONES SHELL DISPONIBLES
# ==============================================================================

Write-Section "11. Funciones shell"

$profilePs1 = "$HOME\.config\powershell\profile.ps1"

$PS_FUNCTIONS = @('gclone', 'gset-profile', 'ginit', 'gremote')

if (Test-Path $profilePs1) {
    $profileContent = Get-Content $profilePs1 -Raw
    foreach ($fn in $PS_FUNCTIONS) {
        if ($profileContent -match "function\s+$fn\b") {
            Test-OK "Funcion $fn definida en profile.ps1"
        } else {
            Test-Fail "Funcion $fn" "no encontrada en profile.ps1"
        }
    }
} else {
    Test-Fail "profile.ps1" "$profilePs1 no existe"
}

# ==============================================================================
# 12. PROFILE LOADER
# ==============================================================================

Write-Section "12. Profile loader de PowerShell"

$profilePath = $PROFILE
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw
    if ($content -match 'mainProfile') {
        Test-OK "Profile loader configurado en `$PROFILE"
    } else {
        Test-Fail "Profile loader" "no encontrado en $profilePath"
    }
} else {
    Test-Fail "Profile loader" "`$PROFILE no existe: $profilePath"
}

# ==============================================================================
# 13. OH-MY-POSH — tema accesible
# ==============================================================================

Write-Section "13. oh-my-posh tema claude-code"

if (-not (Test-CommandExists 'oh-my-posh')) {
    Test-Warn "oh-my-posh" "no instalado, no se puede validar el tema"
} else {
    # test-bootstrap.ps1 vive en la raiz del repo
    $repoRoot = $PSScriptRoot
    $expectedThemesPath = Join-Path $repoRoot "shell\themes"

    # POSH_THEMES_PATH debe apuntar al repo (estrategia unificada)
    if ($env:POSH_THEMES_PATH -eq $expectedThemesPath) {
        Test-OK "POSH_THEMES_PATH apunta al repo: $expectedThemesPath"
    } else {
        Test-Fail "POSH_THEMES_PATH" "esperado '$expectedThemesPath', actual '$($env:POSH_THEMES_PATH)' — correr bootstrap.ps1"
    }

    # No debe haber copia vieja del tema en Programs\oh-my-posh\themes\
    $legacyTheme = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\claude-code.omp.json"
    if (Test-Path $legacyTheme) {
        Test-Fail "Tema legacy" "existe copia vieja en $legacyTheme — bootstrap deberia haberla borrado"
    } else {
        Test-OK "Sin copia vieja del tema en Programs\oh-my-posh\themes"
    }

    # El tema debe existir en el repo
    $repoTheme = Join-Path $expectedThemesPath "claude-code.omp.json"
    if (Test-Path $repoTheme) {
        Test-OK "Tema claude-code.omp.json presente en el repo"
    } else {
        Test-Fail "Tema en repo" "no encontrado en $repoTheme"
    }
}

# ==============================================================================
# RESUMEN
# ==============================================================================

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  RESUMEN" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  PASS: $($script:PASS)" -ForegroundColor Green
if ($script:FAIL -gt 0) {
    Write-Host "  FAIL: $($script:FAIL)" -ForegroundColor Red
} else {
    Write-Host "  FAIL: $($script:FAIL)"
}
if ($script:WARN -gt 0) {
    Write-Host "  WARN: $($script:WARN)" -ForegroundColor DarkYellow
} else {
    Write-Host "  WARN: $($script:WARN)"
}
Write-Host ""
Write-Host "  Log: $LOG_FILE"
Write-Host "======================================================" -ForegroundColor Cyan

if ($script:FAIL -gt 0) { exit 1 } else { exit 0 }
