# dotfiles

Configuracion personal de entorno de desarrollo — Windows + Linux.

Dos bootstraps: `bootstrap.ps1` (Windows/PowerShell 7) y `bootstrap.sh` (Linux/Bash).

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

Ver sección **Setup en maquina nueva → Windows** más abajo.

---

## Estructura del repo (publico)

```
.dotfiles/
├── .editorconfig             # Formato: utf-8, LF, indent por lenguaje
├── .gitignore
├── install.sh                # Instalador interactivo (publico + vault)
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
│   └── themes/
│       └── claude-code.omp.json  # Tema Oh My Posh custom
└── terminal/
    └── settings.json         # Windows Terminal
```

> Las identidades git (`config-personal/work/cei_walle`), `ssh/` y `bookmarks/`
> NO estan aca: viven en el repo privado **dotfiles-vault**.

> Nota: Neovim se instala como binario (`dnf`/`winget`) pero **no** se incluye configuracion en el repo. Cada vez se arranca pelado para configurarlo desde cero segun la maquina.

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

#### 2. Clonar y ejecutar

```powershell
git clone git@github.com-kevincharp:kevincharp/dotfiles.git "$HOME\.dotfiles"
cd "$HOME\.dotfiles"

# Setup completo
pwsh -ExecutionPolicy Bypass -File bootstrap.ps1

# Con AWS/Bedrock (maquina laboral)
pwsh -ExecutionPolicy Bypass -File bootstrap.ps1 -WithAws

# Solo ver que haria
pwsh -ExecutionPolicy Bypass -File bootstrap.ps1 -DryRun
```

#### Flags del bootstrap (Windows)

| Flag | Descripcion |
|---|---|
| `-WithAws` | Certificados Netskope + AWS SSO |
| `-DryRun` | Preview sin ejecutar |
| `-SkipWinget` | Saltear paquetes |
| `-SkipModules` | Saltear modulos PowerShell |
| `-SkipDotfiles` | Saltear copia de dotfiles |

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

### Pasos finales (ambos OS)

1. Abrir terminal nueva para recargar el profile
2. Configurar claves SSH en `~/.ssh/` (el `config` ya fue copiado)
3. Crear `~/.env` con tokens (ver seccion de tokens)

---

## Configuracion de AWS SSO (solo laboral)

Si se uso `-WithAws` / `--with-aws`, completar manualmente:

```bash
aws configure sso
```

| Campo | Valor |
|---|---|
| SSO session name | `tu_usuario_de_red` |
| SSO start URL | `https://<tu-org>.awsapps.com/start/#` |
| SSO region | `us-east-1` |
| Cuenta | **DATA** |
| Profile name | `tu_usuario_de_red` |

Verificar: `aws sts get-caller-identity --profile tu_usuario_de_red`

Renovar cuando expiran: `aws sso login --profile tu_usuario_de_red`

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

### Windows

En Windows usas `bootstrap.ps1` directamente:

```powershell
cd $HOME\.dotfiles
git pull
.\bootstrap.ps1
```

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
| age | Encriptacion de claves SSH | - | dnf | apt |
| glab | GitLab CLI | - | dnf | binario GitLab |
| Windows Terminal | Terminal con paneles y tabs | winget | - | - |
| AWS CLI | Acceso a Bedrock *(opcional)* | winget | installer oficial | installer oficial |
| GitHub CLI | PRs e issues desde terminal *(opcional)* | winget | - | - |

> En Fedora todo lo que tiene paquete nativo se instala via `dnf` (para que se actualice con `dnf upgrade`). El método por binario/curl queda como fallback solo para distros sin el paquete en repos.

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

Disponibles en PowerShell (`profile.ps1`) y Bash (`bashrc`). Usar `spf` para listar todas.

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
| `ginit` | git init + perfil *(solo pwsh)* |
| `gremote` | Agregar/actualizar remote SSH *(solo pwsh)* |
| `gbrowser` | Listar repos GitLab/GitHub *(solo pwsh)* |

### Utilidades

| Comando | Descripcion |
|---|---|
| `spf` | Listar funciones del profile |
| `spf -Type GIT` / `spf git` | Filtrar por tipo/nombre |
| `claude-smg` | Claude Code con Bedrock de SMG |
| `edit archivo` | Abrir en VSCode *(solo pwsh)* |
| `open path` / `openh` | Abrir en explorador/app |

---

## Windows Terminal

Configuracion en `terminal/settings.json`:

- Perfil default: PowerShell 7
- Font: FiraCode Nerd Font Mono (size 7)
- Tema: Ubuntu 22.04 ColorScheme
- Opacidad: 90% con acrylic
- Perfiles: PowerShell, Git Bash, Linux (WSL), Ubuntu, CMD, Windows PowerShell, Azure Cloud Shell
- `Alt+Shift+D`: dividir panel

> FiraCode Nerd Font hay que instalarla manualmente: https://www.nerdfonts.com/font-downloads

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
