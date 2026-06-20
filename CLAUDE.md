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
- Atajos de paneles: `shell/tmux.conf` (Linux) ↔ `terminal/settings.json` (Windows
  Terminal). Mismo gesto en ambos SO — si cambiás uno, sincronizá el otro.
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

## tmux (Linux)

Paneles dentro de Ptyxis (que solo trae pestañas). Detalles no obvios:

- Autoarranque en `bashrc`/`zshrc`: sesión única `main` persistente. Al salir de
  tmux la terminal se cierra (`exit`). Desactivar: `DOTFILES_NO_TMUX=1`.
- Prefijo `Ctrl+a`. Splits directos sin prefijo: `Alt+-` / `Alt+.`. Mover panel:
  `Ctrl+a`+flecha (NO `Ctrl+flecha`, choca con TUIs).
- **Guarda TUI** (`is_tui` en `tmux.conf`): los binds `bind -n` (tabla root)
  interceptan teclas antes de pasarlas a la app. Apps de pantalla completa
  (Claude/nvim/lazygit) podían disparar un bind y cerrar la terminal. La guarda
  reenvía la tecla cruda a la app cuando hay una TUI en foco. Al agregar binds
  root nuevos, considerá si necesitan esta guarda.

## Verificación

- Sintaxis: `bash -n shell/bashrc`, `zsh -n shell/zshrc`.
- tmux carga: `tmux -f shell/tmux.conf new-session -d -s _t && tmux kill-session -t _t`.
- `bash test-bootstrap.sh` tras cambios en shells/symlinks.
