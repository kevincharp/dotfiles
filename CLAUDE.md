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

## Emojis a color en Chrome (`fontconfig/`)

`fontconfig/fonts.conf` → **symlink** a `~/.config/fontconfig/fonts.conf`. Fuerza
los emoji a color en Chrome/Chromium. El detalle no obvio: **Chrome en Linux NO usa
el alias genérico `emoji` de fontconfig** — para cada carácter hace un match por
cobertura de glifo (como `fc-match -s :charset=1f600`). En ese match, **Symbola** y
**Noto Emoji** (monocromáticas) rankean por encima de **Noto Color Emoji**, así que
los emoji salen en blanco y negro. El `fonts.conf` las desprioriza con `rejectfont`.

- **Verificar el fix:** `fc-match -s ':charset=1f600' | head -1` debe dar
  `Noto Color Emoji` (NO `fc-match emoji`, que Chrome ignora).
- Tras cambiarlo: `fc-cache -f` y **reiniciar Chrome entero** (cachea la selección
  de fuentes por proceso; cerrar la ventana no alcanza).
- Arregla solo el **renderizado**. La **entrada** de emoji (Ctrl+. de GTK) no
  funciona dentro de Chrome en Wayland (los campos de Chrome no son widgets GTK).

## Chrome duplicado en "Aplicaciones predeterminadas → Web"

El `.rpm` oficial de Google instala **dos** `.desktop` en `/usr/share/applications/`
durante su migración de nombres: `google-chrome.desktop` (histórico) y
`com.google.Chrome.desktop` (nuevo, formato reverse-DNS). Ambos declaran
`x-scheme-handler/http(s)`, así que Chrome aparece **dos veces** en el selector Web.

- **Detalle no obvio:** el panel de GNOME **NO respeta `Hidden`/`NoDisplay`** — el
  `.rpm` ya marca `com.google.Chrome.desktop` con `NoDisplay=true` y aun así sale en
  la lista. El selector muestra **cualquier** `.desktop` que registre el esquema
  `https`; la única palanca real es el `MimeType`.
- **Fix (en `bootstrap.sh`, paso 5):** genera un override local de
  `com.google.Chrome.desktop` en `~/.local/share/applications/` quitándole los
  `x-scheme-handler/http|https|google-chrome` del `MimeType` (conserva PDF/imágenes).
  Tiene prioridad sobre `/usr/share` y **sobrevive a los `dnf update`** de Chrome.
- Se **regenera** desde el `.desktop` del sistema en cada bootstrap (no se versiona
  una copia estática: si Google cambia los MimeTypes, el override no queda viejo).
- **Si algún día Google unifica los `.desktop`** (deja uno solo), el override puede
  estorbar: borralo con `rm ~/.local/share/applications/com.google.Chrome.desktop`.
  `uninstall.sh` ya lo limpia al desinstalar `google-chrome-stable`.
- Tras reaplicar, **reabrir Ajustes**: el panel cachea la lista hasta reabrirse.

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
- **`clear-history`** (función con paridad): sin args vacía todo el historial (con
  confirmación); con un patrón borra solo las líneas que matcheen (p.ej. un token).
- **Paridad con matices:** mismo comportamiento, implementación distinta por shell.
  En zsh es `zle -N` + `bindkey '^[[A'`. En bash el editor lo maneja **ble.sh**,
  que captura las teclas con `ble-bind -x` (no el `bind` de readline); por eso el
  bloque detecta `$BLE_VERSION` y cae a `bind -x` si ble.sh no está.

## Capturas de pantalla (Flameshot + nativo de GNOME)

Conviven **dos** recortadores, a propósito (paridad parcial con Windows):

- **Flameshot** (recortador con anotaciones) → atajo **`Super+Shift+S`** (el mismo
  que el recorte de Windows). Vive en `gnome/media-keys.dconf` como `custom3` y lo
  aplica el bloque GNOME del bootstrap (`dconf load`). El paquete está en el
  catálogo `apps` del bootstrap (dnf/pacman simple).
- **Captura nativa de GNOME** → sigue en **`Print`** (intacta). NO se le quita la
  tecla: en el notebook Lenovo `Print` depende de `Fn`, así que se dejó como estaba.
- **Detalle no obvio (Wayland):** Flameshot NO es una app con ventana — es un daemon
  de bandeja. GNOME no tiene system tray por defecto, así que lanzarlo desde el menú
  "no abre nada" (corre en background). Se usa **solo por atajo** (`flameshot gui`).
- El teclado del Lenovo además dispara Flameshot con **`Fn+F10`** por un keysym de
  hardware (no es un atajo de dconf, no se versiona).

## File manager TUI (`yazi/`)

File manager de terminal con preview de imágenes/PDF/video, en **ambos SO**
(opcional, grupo `shell` del selector). Detalles no obvios:

- **Config con path distinto por SO** (misma `yazi/yazi.toml` versionada):
  Linux → symlink a `~/.config/yazi/yazi.toml`; Windows → symlink a
  **`%APPDATA%\yazi\config\yazi.toml`** (NO `~/.config`). El `yazi.toml` solo
  redefine el **opener** para que "abrir/editar" texto use **nvim** (el built-in
  de yazi en Windows abre con `code`). Keymap/theme quedan en los defaults.
- **`YAZI_FILE_ONE` (solo Windows):** yazi no encuentra el binario `file` solo y
  falla la detección de MIME (*"Cannot find file's MIME type"*). Se apunta a
  `file.exe` de Git Bash. Lo setean `bashrc` y `profile.ps1` (paridad); en Linux
  `file` está en PATH y no hace falta.
- **Instalación en Fedora vía COPR:** yazi **no está en los repos base** de
  Fedora; el bootstrap habilita el COPR oficial **`lihaohong/yazi`** antes del
  `dnf install` (mismo patrón que lazygit con `atim/lazygit`). Arch lo tiene en
  repos; Windows es winget `sxyazi.yazi`.
- **Deps de preview = bundle con yazi** (no items sueltos del menú): al instalar
  yazi el bootstrap suma **poppler** (PDF), **ffmpeg** (video), **ImageMagick**
  (imágenes), **7zip** (comprimidos) y —solo en Linux— **chafa** (ver abajo). En
  Windows algunas bajan de GitHub releases y **el proxy corporativo puede
  bloquearlas** (quedan como WARN, se instalan a mano). En Fedora `ffmpeg`
  completo requiere **RPM Fusion** (repos base solo traen `ffmpeg-free`); por eso
  las deps se instalan aparte de yazi con fallback, para que el fallo de una no
  tumbe al resto.
- **Preview de imágenes: depende del protocolo gráfico de la terminal.** yazi
  elige adapter en orden **kitty-protocol > sixel > chafa** según lo que soporte
  el terminal. **Windows Terminal** soporta **Sixel** (imagen real). **Ptyxis
  (nuestro default en Fedora) NO soporta sixel ni kitty-protocol** — es una
  limitación del propio Ptyxis (deshabilitado adrede), no del VTE (que sí trae
  sixel compilado). Por eso en Linux yazi cae **siempre a chafa** (preview por
  bloques de color, no nítido) y **sin chafa no se ve NADA de imagen** → el
  bootstrap instala chafa en Linux. chafa es fallback universal inofensivo: si
  algún día se usa un terminal con sixel/kitty (Kitty, Ghostty, WezTerm…), yazi
  usa ese y chafa queda sin usar, sin estorbar. En Windows chafa no se instala
  (Windows Terminal ya da Sixel, y chafa no tiene paquete confiable en winget).
  Requiere ancho suficiente: con la ventana angosta yazi oculta la columna de
  preview.
- **Función `y` (cd-on-exit):** wrapper con paridad en los 3 shells (`bashrc`,
  `zshrc`, `profile.ps1`). Lanza yazi con `--cwd-file` y al salir deja el shell
  en el último directorio navegado. Solo se define si `yazi` está instalado.

## Verificación

- Sintaxis: `bash -n shell/bashrc`, `zsh -n shell/zshrc`.
- `bash test-bootstrap.sh` tras cambios en shells/symlinks (verifica paridad).
