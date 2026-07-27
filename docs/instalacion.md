# Instalación a fondo

Guía completa del instalador: requisitos, qué hace cada paso, todos los flags,
modo no interactivo, secretos y solución de problemas. Para la versión corta,
volvé al [README](../README.md#instalación-rápida).

---

## Requisitos previos

### Linux

| Requisito | Notas |
|---|---|
| **Distro** | Fedora es la de referencia (soporte completo). Debian/Ubuntu y Arch funcionan para el núcleo (shell, git, CLIs); algunas apps son solo Fedora (Chrome vía rpm, Samba, OpenLogi, extensiones GNOME). |
| **bash + curl + sudo** | Vienen de fábrica en cualquier distro. `git` se auto-instala si falta. |
| **GNOME** (opcional) | Solo para la parte de escritorio (atajos, dock, extensiones vía dconf). En otros entornos ese bloque se saltea solo. |

### Windows

| Requisito | Notas |
|---|---|
| **Windows 10/11 con winget** | winget («App Installer») viene con Windows moderno. Si no está: [aka.ms/getwinget](https://aka.ms/getwinget). |
| **PowerShell 7** | El bootstrap lo exige (y lo instala el catálogo, pero para la *primera* corrida conviene tenerlo: `winget install Microsoft.PowerShell`). |
| **Modo de desarrollador** | Configuración → Sistema → Para desarrolladores. Necesario para crear **symlinks sin admin** (el repo los usa para todo). |
| **VSCode** ([System Installer x64](https://code.visualstudio.com/docs/?dv=win64user)) | Manual a propósito: el System Installer agrega `code` al PATH global; el de winget usa el User Installer y puede no quedar en el PATH. |
| **Python** ([instalador oficial amd64](https://www.python.org/downloads/windows/)) | Manual a propósito: el oficial tiene la checkbox «Add Python to PATH» (marcala); el de winget instala `py.exe` en su lugar y rompe la config de Neovim. |

---

## Qué hace el instalador, paso a paso

El mismo comando **instala y actualiza** (si el repo ya existe hace `git pull`).
`install.sh` / `install.ps1` orquestan; `bootstrap.sh` / `bootstrap.ps1` hacen el
trabajo. La secuencia:

1. **Verifica/instala git** y clona el repo público en `~/.dotfiles`.
2. **Pregunta por el vault privado**: si tenés uno, lo clona (`gh` por
   navegador o SSH); si **no** tenés, podés elegir **«crear mis perfiles de git
   ahora»** — un asistente por consola que arma tu propio vault (identidades,
   claves SSH, carpetas de contexto; ver [Adaptalo](adaptalo.md#el-vault)) — o
   **saltar** (instala solo lo público).
3. **Pantalla de bienvenida + selector de herramientas**: un menú por grupos,
   colapsable, que arranca **sin nada marcado** (opt-in — nada se instala por
   sorpresa). Elegís y confirmás con Enter; `q` cancela.
4. **Shell por defecto** (Linux): si elegiste zsh, pregunta si querés bash o zsh
   como shell de login. Todas las decisiones se toman al principio; después el
   resto corre solo con una barra de progreso.
5. **Instala lo seleccionado** con el gestor nativo (dnf/apt/pacman o winget),
   cayendo a binario/script oficial donde no hay paquete.
6. **Crea carpetas y symlinks** de las configs (shell, git, nvim, terminal…),
   con **backup automático** de cualquier archivo tuyo preexistente en
   `~/.local/backups/bootstrap/<timestamp>/`.
7. **Aplica el vault** si está: identidades git, `ssh/config` y desencripta las
   claves SSH con `age` (pide la passphrase por cada clave que falte).
8. **AWS SSO (opcional)**: pregunta si querés configurar Bedrock para
   `claude-smg`; si decís que no, sigue de largo. Detalle más abajo.
9. **Valida la instalación** (`test-bootstrap`) y muestra resumen final con
   warnings, errores, ruta del log y de los backups.

### El selector

```
  ▶ Elegí qué instalar
  ↑/↓ mover · → expandir · ← colapsar · espacio marcar · Enter confirmar

  ❯ ▸ ▱ core     (0/4)
    ▸ ▱ shell    (0/10)
    ▸ ▨ dev      (2/4)
  2 de 30 seleccionadas
```

- **espacio** sobre un grupo marca/desmarca el grupo entero; sobre un ítem, solo ese.
- **a** / **n** = todo / nada · **Enter** confirma · **q** cancela (sin instalar).
- Checkbox de grupo: `▱` ninguno · `▨` parcial · `▰` todos.

---

## Flags

**Instalador** (`install.sh` / `install.ps1`) — acepta también los flags del
bootstrap y se los reenvía:

| Linux | Windows | Qué hace |
|---|---|---|
| `--update-only` | `-UpdateOnly` | Solo actualizar repos, sin correr el bootstrap |
| `--skip-vault` | `-SkipVault` | No clonar/aplicar el vault privado |
| `--vault-auth=gh\|ssh\|skip` | `-VaultAuth gh\|ssh\|skip` | Método de auth del vault sin preguntar |

**Bootstrap** (`bootstrap.sh` / `bootstrap.ps1`):

| Linux | Windows | Qué hace |
|---|---|---|
| `--all-tools` | `-AllTools` | Instalar todo el catálogo sin preguntar |
| `--tools=id1,id2` | `-Tools id1,id2` | Instalar solo esas herramientas |
| `--skip-packages` | `-SkipWinget` | No instalar paquetes (solo symlinks/configs) |
| `--dry-run` | `-DryRun` | Simular: muestra todo lo que haría sin tocar nada |
| `--with-aws` | `-WithAws` | Configurar AWS SSO sin que lo pregunte |
| `--pace=SEG` | `-Pace SEG` | Ritmo de la barra (segundos por acción, default 0.18) |
| `--fast` | `-Fast` | Barra sin pausas (equivale a `--pace=0`; útil en CI) |
| — | `-SkipModules` | Saltear módulos de PowerShell |
| — | `-SkipDotfiles` | Saltear symlinks/copias de configs |

**Modo no interactivo:** sin terminal (pipe/CI) y sin `--tools`/`--all-tools`,
el selector **no instala nada** y lo avisa — coherente con el opt-in.

---

## Cómo se rompe el huevo-y-gallina del SSH

Máquina recién instalada, sin claves SSH: ¿cómo bajás el vault que *contiene*
tus claves SSH?

1. El repo público baja por **HTTPS sin credenciales**.
2. Para el vault, la opción `gh` hace login por **navegador** (una sola
   credencial: tu cuenta de GitHub).
3. El bootstrap desencripta las claves del vault con `age` (passphrase) y las
   deja en `~/.ssh/`.
4. De ahí en más, todo por SSH. El instalador deja el remote del vault apuntando
   al host alias SSH para que los próximos `git pull` no pidan nada.

---

## Tokens y secretos (`~/.env`)

Los tokens personales se cargan desde `~/.env` al iniciar cada terminal. El
archivo **nunca** entra al repo (está en `.gitignore`) y el bootstrap le fija
permisos `600`. Formato `KEY=VALUE` (se tolera `export KEY=VALUE`, espacios y
comillas):

```bash
GITHUB_TOKEN_MIUSUARIO=ghp_xxxxxxxxxxxx
GITLAB_TOKEN_MIUSUARIO=glpat-xxxxxxxxxxxx
```

---

## AWS SSO / Bedrock (opcional)

Solo relevante si usás Claude Code contra **AWS Bedrock** con SSO corporativo
(el comando `claude-smg`). Si no, respondé «no» cuando el instalador pregunte y
listo.

Dos formas de configurarlo:

1. **Autoguiado**: corré el instalador normal; en el paso de AWS respondé que
   sí y te pide los datos que falten (portal SSO, account id, rol, tu usuario) y
   los **guarda en `~/.env`** para la próxima.
2. **Anticipado**: definí las variables en `~/.env` antes y corré con
   `--with-aws` / `-WithAws`.

```bash
AWS_SSO_START_URL=https://<tu-org>.awsapps.com/start/#
AWS_SSO_ACCOUNT_ID=<id-de-cuenta>
AWS_SSO_ROLE_NAME=<rol>          # opcional (default: Bedrock_Access)
AWS_SSO_REGION=us-east-1         # opcional
AWS_SSO_PROFILE=<tu-usuario>     # opcional (default: default)
```

- **`AWS_SSO_PROFILE`** es el nombre del perfil (y de la `sso-session`) que se
  escribe en `~/.aws/config`, el mismo que usa `claude-smg`. Si varias personas
  comparten la org, cada una pone solo su usuario y el resto del `.env` es
  idéntico.
- **`AWS_EXTRA_PROFILES`** agrega perfiles extra bajo la misma sesión SSO
  (mismo login), formato `perfil:cuenta:rol[:region]` separados por `;`:

  ```bash
  AWS_EXTRA_PROFILES="ecs-pre:111111111111:MiRol;ecs-prod:222222222222:MiRol"
  ```

- Verificar: `aws sts get-caller-identity --profile <tu-usuario>` ·
  Renovar: `aws sso login --profile <tu-usuario>` (o dejá que `claude-smg` lo
  haga solo al detectar la sesión vencida).

El bootstrap escribe `~/.aws/config` en formato `sso-session` (flujo PKCE: el
login abre el navegador y confirma solo, sin código de 6 dígitos).

---

## Desinstalación

`uninstall.sh` / `uninstall.ps1` remueven los symlinks, **restauran los backups**
de tus archivos previos y borran los repos. Muestra un preview y pide
confirmación antes de tocar nada.

| Linux | Windows | Qué hace |
|---|---|---|
| `--dry-run` | `-DryRun` | Solo el preview, sin ejecutar |
| `--remove-packages` | `-RemovePackages` | Desinstalar también los paquetes que instaló el bootstrap |
| `--keep-backups` | `-KeepBackups` | Conservar `~/.local/backups/bootstrap/` |
| `--force` | `-Force` | Sin confirmación (peligroso) |

---

## Solución de problemas

| Síntoma | Causa / solución |
|---|---|
| *PowerShell bloquea el script* | Execution Policy: `powershell -ExecutionPolicy Bypass -Command "irm …/install.ps1 \| iex"` |
| *«Se requiere PowerShell 7+»* | El bootstrap corre solo en pwsh 7: `winget install Microsoft.PowerShell` y reintentá desde `pwsh`. |
| *Symlinks fallan en Windows* | Falta el Modo de desarrollador (o correr como admin una vez). |
| *El selector no aparece y no instala nada* | No hay terminal interactiva (pipe/CI): usá `--tools=...` o `--all-tools`. |
| *Descargas de GitHub bloqueadas (proxy corporativo)* | Algunas deps (p.ej. previews de yazi en Windows) quedan como WARN; instalalas a mano cuando puedas. |
| *`age` pide la passphrase varias veces* | Es por diseño: age la lee siempre de la consola, una vez por clave faltante. Normalmente falta 0-1. |
| *La validación final muestra WARNs de "vault no cargado"* | Esperable si instalaste sin vault: esos checks solo aplican con vault. La instalación está bien; para tener vault propio, corré el [asistente](adaptalo.md#el-vault). |
| *Prompt sin íconos / cuadrados* | La terminal no está usando una Nerd Font: seleccioná «FiraCode Nerd Font» (la instala el grupo `fonts`). |
| *Algo quedó a medias* | Todo queda logueado en `~/.local/logs/bootstrap-<timestamp>.log`; los archivos reemplazados están en `~/.local/backups/bootstrap/<timestamp>/`. Re-correr el bootstrap es seguro (es idempotente). |
