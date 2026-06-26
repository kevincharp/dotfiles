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

## Launcher de apps (Ulauncher / Flow Launcher)

Lanzador estilo Spotlight, **uno por SO** (ninguno cruza): Linux → Ulauncher
(catálogo `apps`), Windows → Flow Launcher (winget, grupo `extras`).

Ulauncher tiene tres piezas, versionadas distinto:

- **Config** (`ulauncher/settings.json`, `shortcuts.json`) → **symlink** a
  `~/.config/ulauncher/` (cambios por GUI se versionan al instante).
- **Atajo `Ctrl+Space`** → NO va en `ulauncher/`. Vive en
  `gnome/media-keys.dconf` (`custom1` → `ulauncher-toggle`) y lo aplica el bloque
  GNOME del bootstrap. En **Wayland el hotkey interno de Ulauncher no funciona**,
  por eso lo dispara un atajo de GNOME. Para reversionarlo: `gnome-save`.
- **Autostart** (`ulauncher/autostart.desktop`) → **copia** (no symlink) a
  `~/.config/autostart/`: GNOME reescribe ese `.desktop` desde su GUI.
- **Temas** (`ulauncher/user-themes/`) → **symlink** a
  `~/.config/ulauncher/user-themes/`. Trae Liquid Glass (dark/light), vendorizado
  desde [kayozxo/ulauncher-liquid-glass]. El tema activo se fija con `theme-name`
  en `settings.json`. El efecto vidrio esmerilado real lo da la extensión GNOME
  **Blur My Shell** (`blur-my-shell@aunetx`), instalada por el bootstrap y con su
  config versionada en `gnome/blur-my-shell.dconf`. En **Wayland una extensión
  recién instalada no carga hasta reiniciar la sesión** (logout/login).

## Claude Code (`.claude/`)

Versiona la config de Claude Code para portabilidad. Ojo con el manejo distinto:

- `settings.json` → **symlink** (cambios se versionan al instante).
- `statusline.sh` → **no se copia**; `settings.json` lo referencia desde el repo.
- `settings.local.json` → **per-máquina** (permisos con rutas absolutas que
  difieren Linux/Windows). **No editarlo para resolver conflictos**: en un rebase,
  quedarse con la versión ya commiteada y descartar lo demás.

## Apps de escritorio (Pake) — `apps/`

Webs envueltas como apps nativas (Gmail/Outlook) vía Pake. Solo Linux.
(Teams **no** va por Pake: sus videollamadas no funcionan en WebKitGTK; se
instala por Flatpak — ver abajo.)

- **Receta versionada:** `apps/pake-apps.txt` (`id|Nombre|URL|icono[|flags]`).
  Agregar app = línea ahí + PNG en `apps/icons/`.
- **Compila con Rust/Tauri** (`npx pake-cli`): la categoría `apps` del bootstrap
  arrastra la cadena de deps vía `_ensure_pake_deps` (Rust + libs Tauri). Node
  está aparte en el catálogo.
- **`apps/build-pake-app.sh <id>`** compila e integra al menú (AppImage +
  `.desktop` + icono en `~/.local/share/`). También vía la función `pake-app`.
- Los AppImages **no son symlinks**: `uninstall.sh` los borra en su bloque propio,
  no en `DOTFILES_TARGETS`.

## Apps de escritorio (Flatpak) — `apps/`

Para apps que necesitan Chromium/Electron y que Pake (WebKitGTK) no cubre, p.ej.
**Teams** (las videollamadas sí funcionan acá). Solo Linux. Mismo patrón que Pake
pero sin compilar: Flatpak baja el binario y crea el `.desktop` solo.

- **Receta versionada:** `apps/flatpak-apps.txt` (`id|Nombre|app-id-de-flathub`).
  Agregar app = una línea ahí.
- **`apps/build-flatpak-app.sh <id>`** instala desde Flathub. También vía la
  función `flatpak-app`. Agrega el remote **flathub completo a nivel usuario**
  (el de Fedora viene `filtered` y no lista todas las apps).
- Las apps Flatpak **no son symlinks**: `uninstall.sh` las quita con
  `flatpak uninstall` recorriendo la receta, no en `DOTFILES_TARGETS`.

## Historial estilo PSReadLine (flecha ↑ → lista fzf)

Réplica del **ListView de PSReadLine**: al apretar **↑** se abre `fzf` con el
historial en lista vertical, mostrando **solo el comando** (sin fecha/índice/
duración) y **filtrado por prefijo** con lo ya tipeado (`cd` trae lo que empieza
con `cd`, no donde la `c` y la `d` aparecen sueltas — el `^` ancla la query).

- Implementado en `_fzf_history_widget` (función con paridad bash↔zsh).
- **No es automático** (no flota mientras tipeás): aparece al apretar ↑. Es una
  decisión consciente — en Linux **ninguna** herramienta combina lista vertical
  minimalista *y* aparición automática. Se descartaron `zsh-autocomplete` (grilla
  de completados, no historial) y `atuin` (columnas fecha/duración no removibles
  en su v18). Lo automático inline lo cubre `zsh-autosuggestions`/`ble.sh` (gris).
- `↑` reemplaza del todo el recorrido comando-por-comando; **Ctrl+R** sigue siendo
  la búsqueda difusa por cualquier parte del comando (complementaria al prefijo).
- **Paridad con matices:** mismo comportamiento, implementación distinta por shell.
  En zsh es `zle -N` + `bindkey '^[[A'`. En bash el editor lo maneja **ble.sh**,
  que captura las teclas con `ble-bind -x` (no el `bind` de readline); por eso el
  bloque detecta `$BLE_VERSION` y cae a `bind -x` si ble.sh no está.

## Verificación

- Sintaxis: `bash -n shell/bashrc`, `zsh -n shell/zshrc`, `bash -n apps/build-pake-app.sh`,
  `bash -n apps/build-flatpak-app.sh`.
- `bash test-bootstrap.sh` tras cambios en shells/symlinks (verifica paridad, incl.
  `pake-app` y `flatpak-app`).
