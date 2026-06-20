# dotfiles

Configuracion personal de entorno de desarrollo — Windows + Linux.

Un comando por sistema operativo, paridad completa entre ambos:

| | Linux | Windows |
|---|---|---|
| Instalar | `curl … install.sh \| bash` | `irm … install.ps1 \| iex` |
| Bootstrap | `bootstrap.sh` | `bootstrap.ps1` |
| Desinstalar | `uninstall.sh` | `uninstall.ps1` |

## Arquitectura: dos repos

| Repo | Visibilidad | Contiene |
|---|---|---|
| **`dotfiles`** (este) | publico | scripts de setup + configs no sensibles (shell, terminal, git principal) |
| **`dotfiles-vault`** | privado | claves SSH (encriptadas), identidades git con emails, bookmarks |

Lo sensible vive en el repo privado para que este pueda ser publico sin exponer secretos.

---

## Instalacion rapida

### Linux (Fedora / Debian / Arch)

**Instalacion inicial** (no requiere SSH; baja este repo publico via curl):

```bash
curl -fsSL https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.sh | bash
```

El instalador es **interactivo**: clona lo publico y te pregunta como autenticarte
para clonar el vault privado (gh / SSH / saltar).

**Actualizacion** (publico + vault):

```bash
bash ~/.dotfiles/install.sh
```

**Solo actualizar repos sin ejecutar bootstrap**:

```bash
bash ~/.dotfiles/install.sh --update-only
```

### Windows

**Instalacion inicial** (requiere Git for Windows ya instalado — ver Paso 1):

```powershell
irm https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1 | iex
```

Igual que en Linux, es **interactivo**: clona lo publico y te pregunta como
autenticarte para clonar el vault privado (gh / SSH / saltar).

> Si PowerShell bloquea el script por la Execution Policy, ejecutalo asi:
> ```powershell
> powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1 | iex"
> ```

**Actualizacion** (con el repo ya clonado):

```powershell
pwsh -File ~/.dotfiles/install.ps1
```

Ver detalles y flags en **Setup en maquina nueva → Windows** más abajo.

> **Un comando por sistema operativo.** No hay deteccion automatica de SO: en
> Linux corres el `curl`, en Windows el `irm`. Ambos hacen lo mismo
> (clonar repos + bootstrap + selector de herramientas), pero usan el gestor de
> paquetes nativo de cada sistema (dnf/apt/pacman vs winget).

---

## Estructura del repo (publico)

```
.dotfiles/
├── .editorconfig             # Formato: utf-8, LF, indent por lenguaje
├── .gitignore
├── install.sh                # Instalador interactivo Linux (publico + vault)
├── install.ps1               # Instalador interactivo Windows (publico + vault)
├── uninstall.sh              # Desinstalador Linux
├── uninstall.ps1             # Desinstalador Windows
├── update.sh                 # Atajo de actualizacion (delega en install.sh)
├── bootstrap.ps1             # Setup automatico (Windows)
├── bootstrap.sh              # Setup automatico (Linux)
├── README.md
├── .claude/                  # Claude Code configuration
│   ├── settings.json         # Global settings (hooks, plugins, model)
│   └── plugins/
│       └── installed_plugins.json  # Plugin tracking
├── git/
│   ├── config                # gitconfig principal (includeIf por remoto)
│   └── ignore                # gitignore global
├── shell/
│   ├── profile.ps1           # Perfil PowerShell 7 (Windows)
│   ├── bashrc                # Perfil Bash (Linux / Git Bash)
│   ├── bash_profile          # Loader de bashrc
│   ├── zshrc                 # Perfil Zsh (Linux / macOS) — espejo de bashrc
│   ├── zprofile              # Login shell zsh (carga ~/.profile)
│   ├── tmux.conf             # tmux → ~/.config/tmux/tmux.conf (symlink)
│   └── themes/
│       └── claude-code.omp.json  # Tema Oh My Posh custom
├── terminal/
│   ├── settings.json         # Windows Terminal (symlink)
│   └── ptyxis.dconf          # Ptyxis / Fedora (dump dconf)
└── gnome/                    # Config del escritorio GNOME (dumps dconf)
    ├── media-keys.dconf      # Atajos custom (Super+E/W/B/Q/C, Ctrl+Alt+T)
    ├── wm-keybindings.dconf   # Atajos de ventanas (Super+D)
    ├── dash-to-dock.dconf     # Config del dock
    ├── gpaste.dconf           # GPaste (Alt+Super+V, historial)
    └── shell.dconf            # Favoritos del dock + extensiones habilitadas
```

> **Terminales y GNOME usan dconf, no symlinks.** Windows Terminal y el shell
> se editan en el repo y se reflejan al instante (symlink). En cambio Ptyxis y
> GNOME guardan su config en la base de datos `dconf`, que no es un archivo: se
> sincroniza a mano con los helpers `ptyxis-save`/`gnome-save` (sistema → repo)
> y `ptyxis-load`/`gnome-load` (repo → sistema). Ver "Flujo de actualizacion".

> Las identidades git (`config-personal/work/cei_walle`), `ssh/` y `bookmarks/`
> NO estan aca: viven en el repo privado **dotfiles-vault**.

> Nota: Neovim se instala como binario (`dnf`/`winget`) pero **no** se incluye configuracion en el repo. Cada vez se arranca pelado para configurarlo desde cero segun la maquina.

---

## tmux (paneles en Linux)

Linux/Fedora usa **tmux** para tener paneles estilo Windows Terminal dentro de
Ptyxis (que solo trae pestañas). El `bashrc`/`zshrc` autoarranca una **sesion
unica `main`**: al abrir una terminal se hace `attach -t main || new -s main`,
asi siempre caes en la misma sesion (no se acumulan zombis). Al salir de tmux la
terminal se cierra (`exit`), sin loop de rearranque.

- **Persistencia:** cerrar la ventana (Alt+W / Alt+F4) hace _detach_, la sesion
  sigue viva; reabris y volves a donde estabas. Para matarla: `tmux kill-server`.
- **Desactivar el autoarranque** en una shell: `DOTFILES_NO_TMUX=1` antes de abrirla.
- **No aplica a Windows** (alla los paneles los da Windows Terminal nativo).

Atajos de **splits directos sin prefijo** (paridad con Windows Terminal: mismo
gesto en ambos SO). Se eligio `Alt+simbolo` y no `Ctrl++`/`` Ctrl+` `` porque esas
teclas no tienen codigo portable en tmux y la `` ` `` es tecla muerta en teclado
espanol. **Si cambias el mapeo, sincronizalo con `terminal/settings.json` (WT).**

| Accion | Atajo (directo) |
|---|---|
| Split horizontal (arriba/abajo) | `Alt` `-` |
| Split vertical (lado a lado) | `Alt` `.` |
| Moverse entre paneles | `Alt` + flechas (o clic, mouse activado) |
| Cerrar panel | `Alt` `W` (requiere liberar Alt+W en Ptyxis) |

El resto sigue por prefijo `Ctrl+b` (se puede pasar a `Ctrl+a` descomentando en `tmux.conf`):

| Accion | Atajo |
|---|---|
| Nueva ventana (pestaña) | `Ctrl+b` `c` |
| Split (respaldo memoria muscular tmux) | `Ctrl+b` `\|` / `Ctrl+b` `-` |
| Detach (salir dejando vivo) | `Ctrl+b` `d` |
| Recargar `tmux.conf` | `Ctrl+b` `r` |

---

## Como resuelve el arranque sin SSH

**Escenario**: instalaste Fedora desde cero, no tenes claves SSH todavia.

1. **El repo publico se baja sin credenciales** (curl / HTTPS). Trae los scripts.
2. **El vault privado necesita autenticacion** — el instalador te ofrece:
   - **gh** (recomendado): `gh auth login` por navegador, sin copiar tokens.
   - **SSH**: si ya cargaste una clave manualmente.
   - **saltar**: instala solo lo publico; aplicas el vault despues.
3. **El bootstrap desencripta las claves** del vault con `age` (pide la passphrase una vez)
   y las deja en `~/.ssh/`.
4. **De ahi en mas usas SSH** para todo:
   ```bash
   cd ~/.dotfiles && git remote set-url origin git@github.com:kevincharp/dotfiles.git
   ```

> El huevo-y-gallina (necesitas SSH para bajar las claves que dan SSH) se rompe
> aportando **una** credencial inicial: tu login de GitHub via `gh`.

---

## Setup en maquina nueva

### Linux (Fedora / Debian / Arch)

Usa el metodo de instalacion rapida descripto arriba. El script se encarga de todo.

### Windows

#### 1. Instalaciones manuales (hacer primero)

Estos programas se instalan manualmente adrede:

| Programa | Link | Por que manual |
|---|---|---|
| **VSCode** System Installer x64 | [Descargar](https://code.visualstudio.com/docs/?dv=win64user) | El System Installer agrega `code` al PATH global. El de winget usa el User Installer y puede no quedar en el PATH. |
| **Python** instalador oficial amd64 | [Descargar](https://www.python.org/downloads/windows/) | El instalador oficial tiene "Add Python to PATH". El de winget instala `py.exe` en su lugar. **Marcar "Add Python to PATH" durante la instalacion.** |
| **Git for Windows** | [Descargar](https://gitforwindows.org/) | El instalador permite configurar line endings, editor y SSH. Opciones recomendadas: editor Neovim, line endings "as-is", SSH incluido en Git. |

#### 2. Instalar

**Opcion recomendada — via `install.ps1`** (clona repos + vault + bootstrap):

```powershell
# Instalacion inicial (desde cualquier lado)
irm https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1 | iex

# Con el repo ya clonado
pwsh -File "$HOME\.dotfiles\install.ps1"

# Con AWS/Bedrock (maquina laboral)
pwsh -File "$HOME\.dotfiles\install.ps1" -WithAws

# Solo actualizar repos sin ejecutar bootstrap
pwsh -File "$HOME\.dotfiles\install.ps1" -UpdateOnly
```

**Opcion manual — clonar y correr el bootstrap directo** (si ya tenes el vault):

```powershell
git clone git@github.com-kevincharp:kevincharp/dotfiles.git "$HOME\.dotfiles"
cd "$HOME\.dotfiles"
pwsh -ExecutionPolicy Bypass -File bootstrap.ps1            # setup completo
pwsh -ExecutionPolicy Bypass -File bootstrap.ps1 -WithAws  # con AWS
pwsh -ExecutionPolicy Bypass -File bootstrap.ps1 -DryRun    # preview
```

#### Flags de install.ps1 (Windows)

| Flag | Descripcion |
|---|---|
| `-WithAws` | Pasa la config AWS al bootstrap |
| `-DryRun` | Preview sin ejecutar |
| `-SkipPackages` | Saltear paquetes (winget) |
| `-SkipVault` | No clonar/aplicar el vault privado |
| `-UpdateOnly` | Solo actualizar repos, no ejecutar bootstrap |
| `-VaultAuth gh\|ssh\|skip` | Metodo de auth no interactivo para el vault |
| `-Tools a,b,c` | Instalar solo esas herramientas (ver selector) |
| `-AllTools` | Instalar todo el catalogo sin preguntar |

#### Flags del bootstrap (Windows)

| Flag | Descripcion |
|---|---|
| `-WithAws` | Certificados Netskope + AWS SSO |
| `-DryRun` | Preview sin ejecutar |
| `-SkipWinget` | Saltear paquetes |
| `-SkipModules` | Saltear modulos PowerShell |
| `-SkipDotfiles` | Saltear copia de dotfiles |
| `-Tools a,b,c` | Instalar solo esas herramientas (ver selector) |
| `-AllTools` | Instalar todo el catalogo sin preguntar |

### Linux

```bash
git clone git@github.com-kevincharp:kevincharp/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Setup completo
bash bootstrap.sh

# Con AWS
bash bootstrap.sh --with-aws

# Solo ver que haria
bash bootstrap.sh --dry-run
```

#### Flags del bootstrap (Linux)

| Flag | Descripcion |
|---|---|
| `--with-aws` | Configuracion AWS SSO |
| `--dry-run` | Preview sin ejecutar |
| `--skip-packages` | Saltear instalacion de paquetes |
| `--all-tools` | Instalar todo el catalogo sin preguntar |
| `--tools=id1,id2` | Instalar solo esas herramientas (ver selector) |

### Selector de herramientas (ambos OS)

Al instalar, el bootstrap **pregunta que herramientas instalar** (util, por
ejemplo, para un Linux en pendrive donde solo queres `neovim` y poco mas). El
menu arranca con todo pre-marcado:

```
  == Selector de herramientas ==
  [core]
    [x]  1) neovim       Editor de terminal
    [x]  2) ripgrep      Busqueda rapida (Telescope)
    ...
  [shell]
    [x]  8) oh-my-posh   Prompt con tema
    ...
  Comandos: numeros (ej "1 3 5") | grupo (core/shell/dev/cloud/fonts) | todo | nada | ok
```

- **Numeros** (`1 3 5`): alterna esas filas
- **Grupo** (`core`, `shell`, `dev`, `cloud`, `fonts`; en Windows tambien `extras`): alterna el grupo entero
- **`todo`** / **`nada`**: marca / desmarca todo
- **Enter** vacio u **`ok`**: confirma e instala lo marcado

**Como evitar la pregunta** (no interactivo):

| Quiero... | Linux | Windows |
|---|---|---|
| Todo, sin preguntar | `--all-tools` | `-AllTools` |
| Solo algunas | `--tools=neovim,glab` | `-Tools neovim,glab` |
| Nada de paquetes | `--skip-packages` | `-SkipPackages` / `-SkipWinget` |

> Prioridad: `--tools` → `--all-tools`/`--dry-run` → menu interactivo → si no hay
> terminal (ej. `curl | bash` no interactivo) **instala todo** como red de
> seguridad, para no dejar un setup a medias.

### Pasos finales (ambos OS)

1. Abrir terminal nueva para recargar el profile
2. Configurar claves SSH en `~/.ssh/` (el `config` ya fue copiado)
3. Crear `~/.env` con tokens (ver seccion de tokens)

---

## Configuracion de AWS SSO (solo laboral)

Los datos de la cuenta (account id, portal SSO, rol) son infra privada y **no
se versionan**: se leen de `~/.env`. Defini estas variables antes de correr el
bootstrap con `--with-aws` / `-WithAws`:

```bash
AWS_SSO_START_URL=https://<tu-org>.awsapps.com/start/#
AWS_SSO_ACCOUNT_ID=<id-de-cuenta>
AWS_SSO_ROLE_NAME=<rol>          # opcional (default: Bedrock_Access)
AWS_SSO_REGION=us-east-1         # opcional (default: us-east-1)
```

El bootstrap escribe `~/.aws/config` en formato `sso-session` (flujo PKCE: el
login abre el navegador y confirma solo, sin pedir codigo de 6 digitos).

Verificar: `aws sts get-caller-identity --profile default`

Renovar cuando expira: `aws sso login --profile default`

---

## Tokens y secretos (.env)

Los tokens se cargan desde `~/.env` al iniciar la terminal. El archivo **nunca** se sube al repo.

```bash
GITLAB_TOKEN_KECHARPEN=glpat-xxxxxxxxxxxx
GITLAB_TOKEN_CEI_WALLE=glpat-xxxxxxxxxxxx
GITLAB_TOKEN_KEVINCHARP=glpat-xxxxxxxxxxxx
GITHUB_TOKEN_KEVINCHARP=ghp_xxxxxxxxxxxx
```

---

## Claude Code

El bootstrap copia `.claude/*` a `~/.claude/` para sincronizar configuración entre máquinas.

### Archivos versionados

- **`settings.json`**: Configuración global (hooks, plugins, modelo preferido, theme)
- **`settings.local.json`**: Permisos allow-list específicos de cada proyecto
- **`plugins/installed_plugins.json`**: Lista de plugins instalados y sus versiones

### Qué NO se versiona

El `.gitignore` excluye automáticamente:
- `history.jsonl` — Historial de conversaciones
- `sessions/` — Sesiones activas
- `cache/` — Caché de plugins y modelos
- `.credentials.json` — Credenciales API
- Todos los archivos temporales y sensibles

### Sincronización de plugins

El bootstrap copia `installed_plugins.json` a `~/.claude/plugins/`. Claude Code detecta e instala plugins faltantes al iniciar. Si un plugin no se instala automáticamente, ejecutá: `/plugin install <nombre>`

---

## Flujo de actualizacion

### Linux

Una vez instalado, podes actualizar los dotfiles de dos formas:

**Opcion 1: Script local** (mas rapido si ya tenes el repo):

```bash
bash ~/.dotfiles/install.sh
```

**Opcion 2: Via curl** (funciona desde cualquier lugar):

```bash
curl -fsSL https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.sh | bash
```

**Solo actualizar repo sin ejecutar bootstrap**:

```bash
bash ~/.dotfiles/install.sh --update-only
```

El script automaticamente:
- Detecta si el repo ya existe y hace `git pull` o clona desde cero
- Hace stash automatico si hay cambios sin commitear
- Ejecuta `bootstrap.sh` con los mismos parametros (`--with-aws`, `--skip-packages`, etc.)
- Usa HTTPS si no tenes SSH configurado (ideal para instalacion inicial)

### Guardar cambios de Ptyxis y GNOME (dconf)

Las configs de **shell, oh-my-posh y Windows Terminal** son symlinks: editas el
archivo y el cambio ya esta en el repo, solo falta `git commit`. Pero **Ptyxis y
GNOME** guardan su config en `dconf` (no en archivos), asi que el repo y el
sistema son dos copias separadas. Cuando cambias algo desde la GUI hay un paso
extra para capturarlo:

```bash
# 1. Cambiaste un atajo / el dock / un setting en la GUI de GNOME
gnome-save                    # vuelca dconf -> archivos del repo
                              # (ptyxis-save para la terminal)

# 2. Revisas y versionas el cambio
cd ~/.dotfiles
git diff gnome/               # ver que cambio realmente
git add gnome/ && git commit -m "feat(gnome): ..."
git push
```

**Si te arrepentis de un cambio:** el repo es tu "deshacer". Volves el archivo a
la version buena y lo re-aplicas al sistema con `gnome-load`:

```bash
# Cambio no guardado todavia: el repo aun tiene la version buena
gnome-load                    # pisa el cambio de la GUI con lo del repo

# Cambio ya commiteado: recuperas la version anterior y la re-aplicas
git checkout HEAD~1 -- gnome/media-keys.dconf
gnome-load
```

> `gnome-save`/`gnome-load` sincronizan **todas** las ramas versionadas de una
> sola vez. Para versionar una rama nueva, agregala a `_GNOME_DCONF_MAP` en
> `shell/bashrc` (y al mapa espejo en `bootstrap.sh`).
>
> `dconf load` es **aditivo**: solo escribe las claves del archivo, no borra el
> resto. Por eso `shell.dconf` trae solo `favorite-apps` y `enabled-extensions`
> (se edita a mano) sin arrastrar el ruido del resto de `/org/gnome/shell/`.

En una **maquina nueva**, el `curl` ya aplica todo esto automaticamente: el
bootstrap instala las extensiones de GNOME y hace `dconf load` de cada rama.

### Desinstalación (Linux)

Si necesitás desinstalar los dotfiles completamente (útil para testing o migración):

```bash
# Desinstalación completa (remueve symlinks, restaura backups, borra repos)
bash ~/.dotfiles/uninstall.sh

# Preview sin ejecutar
bash ~/.dotfiles/uninstall.sh --dry-run

# Desinstalar + remover paquetes instalados
bash ~/.dotfiles/uninstall.sh --remove-packages

# Sin confirmación (peligroso)
bash ~/.dotfiles/uninstall.sh --force
```

Flags disponibles:
- `--remove-packages` — Desinstala paquetes instalados por el bootstrap (neovim, ripgrep, etc.)
- `--keep-backups` — No borra `~/.local/backups/bootstrap/`
- `--dry-run` — Muestra qué haría sin ejecutar
- `--force` — No pide confirmación (peligroso)

El script automáticamente:
- Remueve todos los symlinks creados por el bootstrap
- Restaura archivos desde el backup más reciente
- Opcionalmente desinstala paquetes (con `--remove-packages`)
- Borra `.dotfiles` y `.dotfiles-vault`

### Windows

**Actualizar** (igual que en Linux, via `install.ps1`):

```powershell
# Desde cualquier lado
irm https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1 | iex

# Con el repo ya clonado
pwsh -File "$HOME\.dotfiles\install.ps1"

# Solo actualizar repos sin ejecutar bootstrap
pwsh -File "$HOME\.dotfiles\install.ps1" -UpdateOnly
```

### Desinstalación (Windows)

Espejo de `uninstall.sh`:

```powershell
# Desinstalacion completa (remueve symlinks, restaura backups, borra repos)
pwsh -File "$HOME\.dotfiles\uninstall.ps1"

# Preview sin ejecutar
pwsh -File "$HOME\.dotfiles\uninstall.ps1" -DryRun

# Desinstalar + remover paquetes winget instalados
pwsh -File "$HOME\.dotfiles\uninstall.ps1" -RemovePackages

# Sin confirmacion (peligroso)
pwsh -File "$HOME\.dotfiles\uninstall.ps1" -Force
```

Flags disponibles:
- `-RemovePackages` — Desinstala paquetes winget instalados por el bootstrap
- `-KeepBackups` — No borra `~/.local/backups/bootstrap/`
- `-DryRun` — Muestra qué haría sin ejecutar
- `-Force` — No pide confirmación (peligroso)

---

## Herramientas incluidas

### Instaladas por el bootstrap

| Herramienta | Para que | Windows | Linux (Fedora/dnf) | Otros (apt) |
|---|---|---|---|---|
| PowerShell 7 | Shell principal (Windows) | winget | - | - |
| Oh My Posh | Prompt con tema spaceship | winget | curl script | curl script |
| Neovim | Editor de terminal (sin config en este repo) | winget | dnf | apt |
| LazyGit | UI de Git en terminal | winget | dnf (COPR `atim/lazygit`) | binario GitHub |
| Node.js | Runtime JS/TS + npm | winget | dnf (`nodejs npm`) | NodeSource (LTS) |
| ripgrep | Busqueda rapida (Telescope) | winget | dnf | apt |
| fzf | Busqueda difusa (Ctrl+R) | winget | dnf | apt |
| zoxide | `cd` inteligente con memoria | winget | curl script | curl script |
| eza | Reemplazo moderno de `ls` | - | dnf | apt (repo gierens) |
| ble.sh | Syntax highlighting en la linea de input de bash (equivalente a PSReadLine) | - (PSReadLine nativo) | tarball release | tarball release |
| zsh | Shell alternativa a bash (opcional; el bootstrap ofrece elegir login shell) | - (PowerShell nativo) | dnf | apt |
| zsh-autosuggestions | Sugerencias inline en zsh (equivalente a PSReadLine prediction) | - | git clone | git clone |
| zsh-syntax-highlighting | Syntax highlighting en zsh (equivalente a ble.sh) | - | git clone | git clone |
| age | Encriptacion de claves SSH | winget | dnf | apt |
| glab | GitLab CLI | winget | dnf | binario GitLab |
| FiraCode Nerd Font | Fuente con glifos (oh-my-posh) | descarga nerd-fonts | descarga nerd-fonts | descarga nerd-fonts |
| Windows Terminal | Terminal con paneles y tabs | winget | - | - |
| AWS CLI | Acceso a Bedrock *(opcional)* | winget | installer oficial | installer oficial |
| GitHub CLI | PRs e issues + clonado del vault *(opcional)* | winget | dnf | repo oficial GitHub |
| dash-to-dock | Extension GNOME del dock | - | dnf | - |
| GPaste | Gestor de portapapeles GNOME | - | dnf | - |

> En Fedora todo lo que tiene paquete nativo se instala via `dnf` (para que se actualice con `dnf upgrade`). El método por binario/curl queda como fallback solo para distros sin el paquete en repos.

> Las extensiones de GNOME (dash-to-dock, GPaste) solo se instalan en Fedora con GNOME, y su configuracion se aplica desde `gnome/*.dconf` (ver seccion "Ptyxis y GNOME").

### Manuales (solo Windows, ver Paso 1)

| Herramienta | Para que |
|---|---|
| VSCode | Editor principal |
| Python | Scripts, herramientas |
| Git for Windows | Control de versiones + Git Bash |

---

## Perfiles de identidad Git

Los repos se organizan por carpeta. La identidad se aplica automaticamente via `includeIf` basado en la URL del remoto. Las identidades concretas (nombre/email) viven en el repo privado **dotfiles-vault** (`git/config-personal`, `config-work`, `config-cei_walle`):

| Carpeta | Perfil | SSH Alias |
|---|---|---|
| `~/repositorios/personal/` | personal | `github.com-kevincharp`, `gitlab.com-kevincharp` |
| `~/repositorios/work/` | work | `gitlab.com-<work>` |
| `~/repositorios/cei_walle/` | cei_walle | `gitlab.com-cei_walle` |

Clonar con perfil automatico:

```bash
# PowerShell
gclone -perfil work -remoteUrl git@gitlab.com-<work>:grupo/repo.git

# Bash
gclone -p work -u git@gitlab.com-<work>:grupo/repo.git
```

---

## Shell — Funciones y aliases

Disponibles en PowerShell (`profile.ps1`), Bash (`bashrc`) y Zsh (`zshrc`). Usar `spf` para listar todas.

> **Zsh (Linux/macOS).** `shell/zshrc` es un espejo idiomatico de `bashrc` con la misma
> paleta, prompt (oh-my-posh), funciones y aliases. El equivalente a ble.sh son
> `zsh-autosuggestions` + `zsh-syntax-highlighting` (clonados en `~/.local/share`). El
> bootstrap de Linux ofrece elegir el login shell (bash o zsh) y aplica `chsh`. Diferencias
> no-1:1 con bash: `HISTTIMEFORMAT` → `setopt EXTENDED_HISTORY` (se ve con `history -i`);
> `checkwinsize` es automatico en zsh; `cdspell` ≈ `setopt CORRECT`; y `~/.zprofile` **no**
> sourcea `~/.zshrc` (zsh lo carga solo en shells interactivos). `test-bootstrap.sh` verifica
> la paridad de funciones entre `.bashrc` y `.zshrc`.

### Atajos Linux (PowerShell)

| Comando | Equivalente |
|---|---|
| `cat`, `grep`, `find`, `head`, `tail`, `tailf` | Equivalentes directos |
| `lss` / `la` / `ll` | Variantes de `ls` |
| `touch`, `cd -`, `mkdirp` | Como en bash |
| `rmrf` | `rm -rf` (mata procesos primero) |
| `export VAR=valor`, `unset VAR` | Variables de entorno |
| `which`, `less`, `echolf` | Utilidades |
| `z` | Navegacion inteligente (zoxide) |

### Git helpers (ambos shells)

| Comando | Descripcion |
|---|---|
| `gs` / `gst` | `git status` / `git status -sb` |
| `glo` / `glg` | Log grafico corto / completo |
| `gcmm "msg"` | `git commit -m` |
| `gco rama` / `gnew rama` | Checkout / checkout -b |
| `gsw rama` | Switch inteligente (local/remota/nueva) |
| `gbr` / `gbra` | Branch -vv / branch -a -vv |
| `grls` | `git remote -v` |
| `gup` / `gpsu` | Set upstream / push -u origin |
| `gsync` | Fetch + pull rebase + autostash |
| `gclone` | Clone + identidad local automatica |
| `gset-profile` | Aplicar perfil a repo existente |
| `ginit` | git init + perfil |
| `gremote` | Agregar/actualizar remote SSH |
| `gbrowser` | Listar repos GitLab/GitHub *(solo pwsh)* |

### Utilidades

| Comando | Descripcion |
|---|---|
| `spf` | Listar funciones del profile |
| `spf -Type GIT` / `spf git` | Filtrar por tipo/nombre |
| `claude-smg` | Claude Code con Bedrock de SMG |
| `edit archivo` | Abrir en VSCode si esta, si no nvim |
| `open path` / `openh` | Abrir en explorador/app |
| `ptyxis-save` / `ptyxis-load` | Volcar/restaurar config de Ptyxis (dconf) *(Linux)* |
| `gnome-save` / `gnome-load` | Volcar/restaurar config de GNOME: atajos, dock, GPaste *(Linux)* |

---

## Windows Terminal

Configuracion en `terminal/settings.json`:

- Perfil default: PowerShell 7
- Font: FiraCode Nerd Font Mono **SemiBold** (size 7)
- Tema: Ubuntu 22.04 ColorScheme
- Opacidad: 90% con acrylic
- Perfiles: PowerShell, Git Bash, Linux (WSL), Ubuntu, CMD, Windows PowerShell, Azure Cloud Shell
- `Alt+Shift+D`: dividir panel

> FiraCode Nerd Font la instala el bootstrap automaticamente (descarga de
> nerd-fonts y la registra para el usuario) en Windows y Linux. Si la necesitas
> a mano: https://www.nerdfonts.com/font-downloads

---

## Ptyxis y GNOME (Linux / Fedora)

La terminal por defecto de Fedora es **Ptyxis**, y la config del escritorio
(atajos, dock, extensiones) vive en `dconf`. Como no son archivos, no se
symlinkean: se versionan como dumps y se sincronizan con helpers.

**Ptyxis** (`terminal/ptyxis.dconf`):
- Font: FiraCode Nerd Font Mono SemiBold (size 10) — alineada con Windows Terminal
- Tema oscuro, paleta `linux`, perfil `kevincharp`

**GNOME** (`gnome/*.dconf`), aplicado por el bootstrap en una maquina nueva:
- Atajos custom: `Ctrl+Alt+T` → Ptyxis, `Super+E` home, `Super+W` web,
  `Super+B` buscar, `Super+Q` email, `Super+C` panel de control, `Super+D` escritorio
- Dock (dash-to-dock): posicion abajo, transparencia dinamica, icon-size 32
- GPaste: `Alt+Super+V` para el historial del portapapeles
- Favoritos del dock + extensiones habilitadas (dash-to-dock, GPaste, background-logo)

> El peso de fuente (SemiBold) esta alineado entre Windows Terminal y Ptyxis.
> El tamaño difiere a proposito (Win 7 / Ptyxis 10) porque las unidades de
> tamaño no son equivalentes entre ambos sistemas.

> Para guardar/restaurar estos cambios ver "Flujo de actualizacion → Guardar
> cambios de Ptyxis y GNOME (dconf)".

---

## Estructura de carpetas en HOME

El bootstrap crea esta estructura inspirada en Linux:

```
~/
├── .config/
│   ├── powershell/profile.ps1        # (solo Windows)
│   ├── git/ignore
│   └── lazygit/
├── .local/
│   ├── bin/
│   └── logs/                         # logs del bootstrap
├── .cache/
├── .ssh/
│   ├── config                        # aliases SSH (del vault)
│   └── *.pub / *                     # claves (desencriptadas del vault)
├── .bashrc                           # (Linux / Git Bash)
├── .bash_profile                     # (Linux / Git Bash)
├── .zshrc                            # (Linux / macOS, si elegis zsh)
├── .zprofile                         # (Linux / macOS, si elegis zsh)
├── .gitconfig                        # git config principal
├── .gitconfig-personal
├── .gitconfig-work
├── .gitconfig-cei_walle
├── .editorconfig
├── .env                              # tokens (NO en el repo)
└── repositorios/
    ├── personal/
    ├── work/
    └── cei_walle/
```
