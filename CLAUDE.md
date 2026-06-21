# CLAUDE.md

Dotfiles multiplataforma (Linux/Fedora + Windows). Configs de shell, terminal,
git y Claude Code, reproducibles en cualquier máquina vía `bootstrap`.

## Reglas del repo

(Convención de commits: ver el CLAUDE.md global.)

- **Idioma:** comentarios y docs en español.
- **No pushear ni commitear sin que el usuario lo pida.** En `main`, no crear
  ramas salvo que se indique.

## Paridad obligatoria

Cualquier función o alias que se toque en un shell **debe replicarse en los otros**:

- `shell/bashrc` ↔ `shell/zshrc` ↔ `shell/profile.ps1` (PowerShell, cuando aplique).
- `test-bootstrap.sh` verifica la paridad de funciones bash↔zsh. Correr tras tocar
  los shells: `bash test-bootstrap.sh`.

## Arquitectura

- **Dos repos:** este es el **público**. Lo sensible (claves SSH, identidades git,
  tokens) vive en `dotfiles-vault` (privado), referenciado vía `$VAULT_DIR`.
- **`bootstrap.sh`** (Linux) / **`bootstrap.ps1`** (Windows): instalan paquetes y
  crean los symlinks. `copy_dotfile <src> <dst> [link|copy]` es la primitiva.
  Flags: `--dry-run`, `--skip-packages`, `--with-aws`, `--all-tools`.

## dconf NO es archivo (Ptyxis / GNOME)

Ptyxis y GNOME guardan su config en la base de datos `dconf`, no en archivos, así
que **no se symlinkean**. Se sincronizan con helpers definidos en `bashrc`:

- `ptyxis-save` / `gnome-save`: sistema → repo (volcar al `.dconf` versionado).
- `ptyxis-load` / `gnome-load`: repo → sistema.

Tras cambiar atajos/tema por la GUI, hay que correr el `*-save` para versionarlo.
Editar el `.dconf` a mano no aplica nada hasta hacer `*-load`.

## Claude Code (`.claude/`)

Versiona la config de Claude Code para portabilidad. Ojo con el manejo distinto:

- `settings.json` → **symlink** (cambios se versionan al instante).
- `statusline.sh` → **no se copia**; `settings.json` lo referencia desde el repo.
- `settings.local.json` → **per-máquina** (permisos con rutas absolutas que
  difieren Linux/Windows). **No editarlo para resolver conflictos**: en un rebase,
  quedarse con la versión ya commiteada y descartar lo demás.

## Apps de escritorio (Pake) — `apps/`

Webs envueltas como apps nativas (Gmail/Outlook) vía Pake. Solo Linux.
(Teams se descartó: sus videollamadas no funcionan en WebKitGTK.)

- **Receta versionada:** `apps/pake-apps.txt` (`id|Nombre|URL|icono[|flags]`).
  Agregar app = línea ahí + PNG en `apps/icons/`.
- **Compila con Rust/Tauri** (`npx pake-cli`): la categoría `apps` del bootstrap
  arrastra la cadena de deps vía `_ensure_pake_deps` (Rust + libs Tauri). Node
  está aparte en el catálogo.
- **`apps/build-pake-app.sh <id>`** compila e integra al menú (AppImage +
  `.desktop` + icono en `~/.local/share/`). También vía la función `pake-app`.
- Los AppImages **no son symlinks**: `uninstall.sh` los borra en su bloque propio,
  no en `DOTFILES_TARGETS`.

## Verificación

- Sintaxis: `bash -n shell/bashrc`, `zsh -n shell/zshrc`, `bash -n apps/build-pake-app.sh`.
- `bash test-bootstrap.sh` tras cambios en shells/symlinks (verifica paridad, incl. `pake-app`).
