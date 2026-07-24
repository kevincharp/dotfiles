# dotfiles

Entorno de desarrollo reproducible — **Linux (Fedora/Debian/Arch) + Windows**.
Un comando por sistema operativo, con paridad completa entre ambos.

| | Linux | Windows |
|---|---|---|
| Instalar / actualizar | `curl … install.sh \| bash` | `irm … install.ps1 \| iex` |
| Bootstrap (setup) | `bootstrap.sh` | `bootstrap.ps1` |
| Desinstalar | `uninstall.sh` | `uninstall.ps1` |

## Arquitectura: dos repos

| Repo | Visibilidad | Contiene |
|---|---|---|
| **`dotfiles`** (este) | público | scripts de setup + configs no sensibles (shell, terminal, git base) |
| **`dotfiles-vault`** | privado | claves SSH (encriptadas con `age`), identidades git con emails, bookmarks |

Lo sensible vive en el repo privado para que **este** pueda ser público sin exponer
secretos. El bootstrap los combina: aplica lo público y desencripta lo del vault.

---

## Instalación

El mismo comando **instala y actualiza** (detecta si el repo ya existe: clona o
hace `git pull`). Es **interactivo**: clona lo público y pregunta cómo autenticarte
para el vault privado (gh / SSH / saltar).

### Linux

```bash
# Instalar o actualizar (no requiere SSH: baja el repo público por HTTPS)
curl -fsSL https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.sh | bash

# Con el repo ya clonado
bash ~/.dotfiles/install.sh

# Solo actualizar repos, sin correr el bootstrap
bash ~/.dotfiles/install.sh --update-only
```

### Windows

Antes que nada, instalá **manualmente** estos dos (el resto los pone el bootstrap):

| Programa | Por qué manual |
|---|---|
| [**VSCode** System Installer x64](https://code.visualstudio.com/docs/?dv=win64user) | El System Installer agrega `code` al PATH global; el de winget usa User Installer y puede no quedar en el PATH. |
| [**Python** oficial amd64](https://www.python.org/downloads/windows/) | El oficial tiene "Add Python to PATH" (marcarlo); el de winget instala `py.exe` en su lugar. |

```powershell
# Instalar o actualizar (git se auto-instala por winget si falta)
irm https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1 | iex

# Con el repo ya clonado
pwsh -File "$HOME\.dotfiles\install.ps1"

# Solo actualizar repos, sin correr el bootstrap
pwsh -File "$HOME\.dotfiles\install.ps1" -UpdateOnly
```

> Si PowerShell bloquea el script por la Execution Policy:
> ```powershell
> powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/kevincharp/dotfiles/main/install.ps1 | iex"
> ```

> **No hay detección automática de SO:** en Linux corrés el `curl`, en Windows el
> `irm`. Ambos hacen lo mismo (clonar repos → bootstrap → selector de herramientas)
> con el gestor de paquetes nativo de cada sistema (dnf/apt/pacman vs winget).

### Pasos finales (ambos SO)

1. Abrir una terminal nueva para recargar el profile.
2. Crear `~/.env` con tus tokens (ver [Tokens y secretos](#tokens-y-secretos-env)).

---

## Cómo resuelve el arranque sin SSH

**Escenario:** instalaste el SO desde cero, no tenés claves SSH todavía.

1. **El repo público se baja sin credenciales** (curl / HTTPS). Trae los scripts.
2. **El vault privado necesita autenticación** — el instalador ofrece:
   - **gh** (recomendado): `gh auth login` por navegador, sin copiar tokens.
   - **SSH**: si ya cargaste una clave manualmente.
   - **saltar**: instala solo lo público; el vault se aplica después.
3. **El bootstrap desencripta las claves** del vault con `age` (pide la passphrase
   una vez) y las deja en `~/.ssh/`.
4. **De ahí en más usás SSH** para todo.

> El huevo-y-gallina (necesitás SSH para bajar las claves que dan SSH) se rompe con
> **una** credencial inicial: tu login de GitHub vía `gh`.

---

## Selector de herramientas

El bootstrap **pregunta qué instalar** con un selector **por grupos, colapsable**
(ambos SO), que arranca **sin nada marcado** (opt-in: elegís vos). Lo precede una
pantalla de bienvenida que explica qué hace el instalador y muestra el catálogo.

```
  ▶ Elegí qué instalar
  ↑/↓ mover · → expandir · ← colapsar · espacio marcar · Enter confirmar

  ❯ ▸ ▱ core     (0/4)
    ▸ ▱ shell    (0/10)
    ▸ ▨ dev      (2/4)
    ...
  2 de 30 seleccionadas
```

- **↑/↓** mover · **→ / ←** expandir / colapsar un grupo
- **espacio** marcar/desmarcar — sobre un **grupo** afecta todo el grupo; sobre un **ítem**, solo ese
- **a** / **n** marcar todo / nada · **Enter** confirma e instala
- Checkbox de grupo: `▱` ninguno · `▨` parcial · `▰` todos

Tras el selector, en Linux se pregunta también el **shell por defecto** (bash/zsh),
para juntar todas las decisiones al arranque. La barra de progreso global va de 0 a
100 % cruzando los 8 pasos; su ritmo se ajusta con `--pace`.

**Evitar la pregunta** (modo no interactivo):

| Quiero… | Linux | Windows |
|---|---|---|
| Todo, sin preguntar | `--all-tools` | `-AllTools` |
| Solo algunas | `--tools=neovim,glab` | `-Tools neovim,glab` |
| Nada de paquetes | `--skip-packages` | `-SkipWinget` |

> **Prioridad:** `--tools` → `--all-tools`/`--dry-run` → menú interactivo → si no hay
> terminal (`curl \| bash` no interactivo) **no instala nada** y pide usar
> `--tools`/`--all-tools` (coherente con opt-in: nunca instala por sorpresa).

> `curl`/`wget`/`unzip` **no aparecen** en el selector: son dependencias base que se
> instalan solas cuando alguna herramienta las necesita (p.ej. `unzip` para
> `firacode`). En Windows PowerShell descarga con `Invoke-WebRequest`.

---

## Catálogo de herramientas

Elegís cuáles instalar en el selector. **Linux: 30 · Windows: 25.** El método de
instalación es el gestor nativo de cada SO (dnf/apt/pacman vs winget) y cae a
binario/script solo como fallback donde no hay paquete.

**core** — base mínima
`neovim` · `ripgrep` · `fzf` · `bash-completion` (Linux) · `Windows Terminal` · `PowerShell 7` · `Git` (Windows)

**shell** — prompt y utilidades de terminal
`oh-my-posh` (prompt con tema `claude-code`) · `zoxide` · `lazygit` · `yazi` (file
manager TUI con preview) · `lazyssh` (TUI de conexiones SSH) · `eza` (Linux) ·
`ble.sh` + `zsh` + `zsh-autosuggestions` + `zsh-syntax-highlighting` (Linux)

**dev** — desarrollo
`node` · `codex` (OpenAI) · `claude` (Claude Code) · `opencode` (SST)

**cloud** — nube y CLIs remotas
`aws` (Bedrock) · `gh` (GitHub CLI) · `glab` (GitLab CLI) · `age` (encripta las
claves SSH) · `rclone` (sync nube, Linux)

**fonts**
`firacode` (FiraCode Nerd Font — glifos para oh-my-posh)

**apps** *(Linux)* / **extras** *(Windows)* — opcionales
Linux: `ulauncher` (launcher Spotlight) · `samba` (compartir por SMB) · `chrome` ·
`openlogi` (mouse Logitech MX por HID++) · `flameshot` (recortador, `Super+Shift+S`)
· `remmina` (RDP/VNC).
Windows: `Flow Launcher` · `Obsidian` · `Logitech Options+` · `SDelete` · `Ubuntu 22.04 (WSL)`.

> **Solo Linux (Fedora/GNOME):** `dash-to-dock` y `GPaste` son extensiones de GNOME
> que instala el bootstrap; su config se aplica desde `gnome/*.dconf` (ver más abajo).
> `flameshot`, `ulauncher`, `remmina` y `openlogi` son Linux; sus equivalentes en
> Windows son nativos o de la lista `extras` (`mstsc` para RDP, Flow Launcher, etc.).

> **Manuales en Windows** (ver arriba): VSCode y Python.

---

## Flags de los scripts

**Bootstrap** (setup principal):

| Linux (`bootstrap.sh`) | Windows (`bootstrap.ps1`) | Qué hace |
|---|---|---|
| `--with-aws` | `-WithAws` | Configuración AWS SSO (+ certificados Netskope en Windows) |
| `--dry-run` | `-DryRun` | Preview sin ejecutar |
| `--skip-packages` | `-SkipWinget` | Saltear instalación de paquetes |
| — | `-SkipModules` | Saltear módulos de PowerShell |
| — | `-SkipDotfiles` | Saltear copia de dotfiles |
| `--all-tools` | `-AllTools` | Instalar todo el catálogo sin preguntar |
| `--tools=id1,id2` | `-Tools id1,id2` | Instalar solo esas herramientas |
| `--pace=SEG` | `-Pace SEG` | Ritmo de la barra de progreso (seg. por acción, default 0.18) |
| `--fast` | `-Fast` | Barra sin pausas (equivale a `--pace=0` / `-Pace 0`; útil en CI) |

**Instalador** (`install.sh` / `install.ps1`):

| Linux | Windows | Qué hace |
|---|---|---|
| `--update-only` | `-UpdateOnly` | Solo actualizar repos, sin correr el bootstrap |
| `--skip-vault` | `-SkipVault` | No clonar/aplicar el vault privado |
| `--vault-auth=gh\|ssh\|skip` | `-VaultAuth gh\|ssh\|skip` | Método de auth no interactivo para el vault |

Los flags del bootstrap (`--with-aws`, `--tools`, etc.) también se pueden pasar al
instalador: los reenvía al bootstrap.

**Desinstalador** (`uninstall.sh` / `uninstall.ps1`) — remueve symlinks, restaura
backups y borra los repos:

| Linux | Windows | Qué hace |
|---|---|---|
| `--dry-run` | `-DryRun` | Preview sin ejecutar |
| `--remove-packages` | `-RemovePackages` | Desinstalar los paquetes instalados por el bootstrap |
| `--keep-backups` | `-KeepBackups` | No borrar `~/.local/backups/bootstrap/` |
| `--force` | `-Force` | Sin confirmación (peligroso) |

---

## Configuración de AWS SSO (solo laboral)

**Dos formas, y el bootstrap te guía si no configuraste nada:**

1. **Autoguiado (recomendado para un compañero nuevo):** corré el instalador normal.
   En el paso de AWS te pregunta *"¿Configurar el acceso AWS/Bedrock para claude-smg?"*.
   Si decís que sí y no tenés los datos en `~/.env`, **te los pide en el momento**
   (portal SSO, account id, rol, tu usuario) y los **guarda en `~/.env`** para las
   próximas veces. Cero pasos manuales previos.
2. **Anticipado (con el flag):** definí las variables en `~/.env` **antes** y corré
   con `--with-aws` / `-WithAws` para saltear la pregunta.

Los datos de la cuenta (account id, portal SSO, rol) son infra privada y **no se
versionan**: viven solo en tu `~/.env`. Las variables:

```bash
AWS_SSO_START_URL=https://<tu-org>.awsapps.com/start/#
AWS_SSO_ACCOUNT_ID=<id-de-cuenta>
AWS_SSO_ROLE_NAME=<rol>          # opcional (default: Bedrock_Access)
AWS_SSO_REGION=us-east-1         # opcional (default: us-east-1)
AWS_SSO_PROFILE=<tu-usuario>     # opcional (default: default) — ver abajo
```

El bootstrap escribe `~/.aws/config` en formato `sso-session` (flujo PKCE: el login
abre el navegador y confirma solo, sin código de 6 dígitos).

**`AWS_SSO_PROFILE` — un usuario, un perfil.** Es el nombre del perfil (y de la
`sso-session`) que el bootstrap escribe en `~/.aws/config`, y **el mismo** que usa
`claude-smg` y el comando de renovación. Así, si varias personas comparten la misma
org, cada una pone **solo su usuario** (p.ej. `AWS_SSO_PROFILE=elteruel`) y todo lo
demás del `.env` es idéntico. Si no lo definís, el perfil se llama `default`.

- Verificar: `aws sts get-caller-identity --profile <tu-usuario>`
- Renovar al expirar: `aws sso login --profile <tu-usuario>`

> Compat: si venías usando `CLAUDE_SMG_AWS_PROFILE`, sigue funcionando como
> fallback. `AWS_SSO_PROFILE` tiene prioridad.

**`AWS_EXTRA_PROFILES` — perfiles adicionales bajo la misma sso-session.** Si además
del perfil principal (Bedrock) trabajás con otras cuentas/roles de la misma org
(p.ej. ECS en NoProd y Prod), listalos acá y el bootstrap los escribe en
`~/.aws/config` **reusando el mismo login SSO** (no hay que loguear de nuevo).
Formato: `perfil:cuenta:rol[:region]` separados por `;` (la región es opcional,
default `AWS_SSO_REGION`):

```bash
AWS_EXTRA_PROFILES="ecs-pre:562722450811:Control_de_Cambios_e_Imp.;ecs-prod:245109378300:Control_de_Cambios_e_Imp."
```

Con eso, tras el bootstrap tenés `aws ... --profile ecs-pre` y `--profile ecs-prod`
funcionando en cualquier PC. Como todo vive en `~/.env` (no versionado), los datos
de cuentas no se filtran al repo. Las entradas mal formadas se saltean con warning.

---

## Tokens y secretos (.env)

Los tokens se cargan desde `~/.env` al iniciar la terminal. El archivo **nunca** se
sube al repo (está en `.gitignore`).

```bash
GITLAB_TOKEN_KECHARPEN=glpat-xxxxxxxxxxxx
GITLAB_TOKEN_CEI_WALLE=glpat-xxxxxxxxxxxx
GITLAB_TOKEN_KEVINCHARP=glpat-xxxxxxxxxxxx
GITHUB_TOKEN_KEVINCHARP=ghp_xxxxxxxxxxxx
```

---

## Perfiles de identidad Git

Los repos se organizan por carpeta; la identidad se aplica sola vía `includeIf`
según la URL del remoto. Las identidades concretas (nombre/email) viven en el vault
(`git/config-personal`, `config-work`, `config-cei_walle`).

| Carpeta | Perfil | SSH Alias |
|---|---|---|
| `~/repositorios/personal/` | personal | `github.com-kevincharp`, `gitlab.com-kevincharp` |
| `~/repositorios/work/` | work | `gitlab.com-<work>` |
| `~/repositorios/cei_walle/` | cei_walle | `gitlab.com-cei_walle` |

```bash
# Clonar con perfil automático
gclone -perfil work -remoteUrl git@gitlab.com-<work>:grupo/repo.git   # PowerShell
gclone -p work -u git@gitlab.com-<work>:grupo/repo.git                # Bash
```

---

## Claude Code

El bootstrap sincroniza la config de Claude Code entre máquinas:

- **`settings.json`** → **symlink** a `~/.claude/` (hooks, `enabledPlugins`, modelo, theme).
- **`statusline.sh`** → no se copia; `settings.json` lo referencia desde el repo.
- **`CLAUDE.md`** → instrucciones globales versionadas.
- **`settings.local.json`** → per-máquina (permisos con rutas absolutas), **no** se versiona.

**Plugins:** se declaran en `settings.json` (`enabledPlugins`); Claude Code instala
los faltantes al iniciar y mantiene su estado local (`installed_plugins.json`, con
rutas por-SO) fuera del repo. Si un plugin no aparece, `/plugins` refresca el cache.

---

## Ptyxis y GNOME (dconf) — no son symlinks

Las configs de **shell, oh-my-posh y Windows Terminal** son symlinks: editás el
archivo y el cambio ya está en el repo. Pero **Ptyxis y GNOME** guardan su config en
la base de datos `dconf` (no en archivos), así que el repo y el sistema son dos
copias separadas. Se sincronizan con helpers:

```bash
# Volcar sistema → repo (tras cambiar algo por la GUI)
gnome-save          # (o ptyxis-save para la terminal)
cd ~/.dotfiles && git diff gnome/ && git add gnome/ && git commit -m "feat(gnome): ..."

# Restaurar repo → sistema (deshacer un cambio, o en máquina nueva)
gnome-load          # (o ptyxis-load)
```

> `gnome-save`/`load` sincronizan **todas** las ramas versionadas de una vez. Para
> versionar una rama nueva, agregala a `_GNOME_DCONF_MAP` en `shell/bashrc` (y al
> mapa espejo en `bootstrap.sh`). `dconf load` es **aditivo**: solo escribe las
> claves del archivo, no borra el resto (por eso `shell.dconf` trae solo
> `favorite-apps` y `enabled-extensions` sin arrastrar el ruido del resto).

En una **máquina nueva** el bootstrap ya hace todo esto: instala las extensiones y
aplica cada `dconf load`.

**Qué hay versionado:**
- **Ptyxis** (`terminal/ptyxis.dconf`): FiraCode Nerd Font SemiBold size 10, tema oscuro.
- **GNOME** (`gnome/*.dconf`): atajos custom (`Ctrl+Alt+T` terminal, `Super+E/W/B/Q/C`,
  `Super+D` escritorio, `Super+Shift+S` Flameshot, `Alt+Super+V` GPaste), dock
  (dash-to-dock), favoritos y extensiones habilitadas.

---

## Referencia

<details>
<summary><strong>Estructura del repo</strong></summary>

```
.dotfiles/
├── install.sh / install.ps1      # Instalador interactivo (público + vault)
├── bootstrap.sh / bootstrap.ps1  # Setup automático (paquetes + symlinks + dconf)
├── uninstall.sh / uninstall.ps1  # Desinstalador
├── update.sh                     # Atajo: delega en install.sh
├── test-bootstrap.sh / .ps1      # Verifican paridad de funciones entre shells
├── .claude/                      # Config de Claude Code (settings.json symlink, CLAUDE.md, statusline.sh)
├── git/ignore                    # gitignore global
├── shell/
│   ├── bashrc · bash_profile     # Bash (Linux / Git Bash)
│   ├── zshrc · zprofile          # Zsh (espejo idiomático de bashrc)
│   ├── profile.ps1               # PowerShell 7 (Windows)
│   └── themes/claude-code.omp.json
├── terminal/
│   ├── settings.json             # Windows Terminal (symlink)
│   └── ptyxis.dconf              # Ptyxis / Fedora (dump dconf)
├── gnome/*.dconf                 # Escritorio GNOME (dumps dconf)
├── ulauncher/                    # Launcher Spotlight (solo Linux)
├── yazi/yazi.toml                # File manager TUI
├── fontconfig/fonts.conf         # Fuerza emoji a color en Chrome (Linux)
├── openlogi/config.toml          # Config mouse Logitech MX
└── docs/                         # Guías de tareas puntuales (no parte del bootstrap)
```

> Neovim se instala pelado (sin config en el repo). Las identidades git, `ssh/` y
> `bookmarks/` **no** están acá: viven en el vault privado.

</details>

<details>
<summary><strong>Shell — funciones y aliases</strong></summary>

Disponibles en PowerShell (`profile.ps1`), Bash (`bashrc`) y Zsh (`zshrc`). Listá
todas con `dothelp` (el «--help» del repo): las agrupa por categoría, con su
descripción y una plantilla de uso lista para copiar. Filtrá con `dothelp git`.

**Atajos estilo Linux** (en PowerShell): `cat`, `grep`, `find`, `head`, `tail`,
`tailf`, `lss`/`la`/`ll`, `touch`, `mkdirp`, `rmrf`, `which`, `less`, `z` (zoxide).

**Git helpers** (ambos shells):

| Comando | Descripción |
|---|---|
| `gs` / `gst` | `git status` / `-sb` |
| `glo` / `glg` | Log gráfico corto / completo |
| `gcmm "msg"` | `git commit -m` |
| `gco` / `gnew` / `gsw` | Checkout / checkout -b / switch inteligente |
| `gbr` / `gbra` | Branch -vv / -a -vv |
| `gsync` | Fetch + pull rebase + autostash |
| `gclone` / `gset-profile` / `ginit` | Clone / aplicar / init con identidad automática |
| `gup` / `gpsu` / `gremote` | Upstream / push -u / remote SSH |
| `gbrowser` | Listar repos GitLab/GitHub *(solo pwsh)* |

**Utilidades:**

| Comando | Descripción |
|---|---|
| `dothelp` / `dothelp git` | Listar comandos del repo por categoría / filtrar |
| `claude-smg` | Claude Code con Bedrock de SMG |
| `edit` / `open` | Abrir en VSCode (o nvim) / en el explorador |
| `y` | yazi con cd-on-exit (queda en el último directorio navegado) |
| `ptyxis-save` / `load`, `gnome-save` / `load` | Volcar/restaurar dconf *(Linux)* |

> **Zsh** es un espejo idiomático de `bashrc` (misma paleta, prompt, funciones). El
> equivalente a ble.sh son `zsh-autosuggestions` + `zsh-syntax-highlighting`.
> `test-bootstrap.sh` verifica la paridad de funciones entre `.bashrc` y `.zshrc`.

</details>

<details>
<summary><strong>Estructura de carpetas en HOME</strong></summary>

```
~/
├── .config/
│   ├── powershell/profile.ps1   # (solo Windows)
│   ├── git/ignore
│   └── lazygit/ · yazi/
├── .local/{bin,logs}            # logs del bootstrap en .local/logs
├── .cache/
├── .ssh/{config,*.pub,*}        # config + claves (desencriptadas del vault)
├── .bashrc · .bash_profile      # Linux / Git Bash
├── .zshrc · .zprofile           # si elegís zsh
├── .gitconfig{,-personal,-work,-cei_walle}
├── .env                         # tokens (NO en el repo)
└── repositorios/{personal,work,cei_walle}
```

</details>

<details>
<summary><strong>Windows Terminal</strong></summary>

Config en `terminal/settings.json`: perfil default PowerShell 7, FiraCode Nerd Font
Mono SemiBold, tema Ubuntu 22.04, opacidad 90 % acrylic. Atajos de paneles: `Alt+-`
split abajo, `Alt+.` split al lado, `Alt+W` cerrar panel, `Ctrl`+flechas mover.

</details>
