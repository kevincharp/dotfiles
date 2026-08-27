# CLAUDE.md

Dotfiles multiplataforma (Linux/Fedora + Windows). Configs de shell, terminal,
git y Claude Code, reproducibles en cualquier máquina vía `bootstrap`.

## Reglas del repo

(Commits, push, ramas, idioma y secretos: rigen las reglas del CLAUDE.md
**global** — commits granulares sin pedir permiso, nunca pushear, sin ramas
salvo pedido.)

## Reglas de `set -e` (bootstrap/install/uninstall)

Los scripts corren con `set -euo pipefail`; tres trampas ya nos mordieron y
están prohibidas:

- **`((x++))`** devuelve exit 1 cuando `x` vale 0 y aborta el script. Usar
  `x=$((x + 1))`.
- **`var="$(comando)"`** hereda el exit del comando: si puede fallar
  legítimamente (p.ej. un test con FAILs), capturar con `|| rc=$?`.
- **Operadores dentro de variables** (`CMD="algo || true"`) no funcionan al
  expandir sin comillas: `||` llega como argumento literal. Ejecutar con
  `bash -c "$CMD"`.

## `install.ps1` debe ser ASCII puro (lo lee PowerShell 5.1)

`install.ps1` es el **único** script que corre bajo la consola por defecto de
Windows (5.1), porque su primer trabajo es cortar si no hay pwsh 7. PowerShell
5.1 lee los `.ps1` como **ANSI (cp1252)**, no UTF-8: un `—` dentro de un string
se decodifica como 3 bytes donde el último es `’`, que **cierra el string** y
tira un error de parseo del archivo entero — el gate ni llega a ejecutarse.

- En `install.ps1`: **nada de no-ASCII en strings** (usar `-` en vez de `—`). En
  comentarios es inofensivo.
- Los iconos se construyen por código (`[char]0x2713`), no como literales, y
  caen a ASCII si no hay pwsh 7 + UTF-8.
- Verificar el gate con `powershell -NoProfile -File install.ps1` (5.1): debe
  imprimir el mensaje legible y salir 1. `bootstrap.ps1` no tiene la
  restricción: solo lo invoca pwsh 7.

### Bajo `irm | iex`, `exit` CIERRA LA TERMINAL

`iex` ejecuta el script **dentro de la sesión interactiva**, no como script
propio: ahí `exit` no termina el script sino **la sesión**, así que la ventana
se cierra y el usuario nunca lee el mensaje de error. Verificado: con `iex`,
nada de lo que sigue a un `exit` se ejecuta y la consola muere; con `-File` la
sesión sobrevive.

- **`install.ps1` se re-ejecuta como archivo** al detectar que vino por `iex`
  (sin `$PSCommandPath`): se escribe a `$env:TEMP` y se relanza con `-File`.
  Recién ahí los `exit` son seguros.
- La re-ejecución tiene **guarda anti-recursión** (`DOTFILES_INSTALL_REEXEC` +
  chequeo de que el texto sea realmente este script). Sin eso, con un `iex`
  anidado `$MyInvocation` devuelve el script **contenedor** y se relanza
  infinitamente — pasó, cuelga la máquina y deja procesos y temporales.
- El temporal se escribe con `-Encoding Default` (cp1252): es lo que 5.1 espera,
  y el archivo es ASCII puro igual.
- Los `exit` del script pasan por **`Stop-Install`**: si la re-ejecución no pudo
  hacerse, corta con `break dotfilesInstall` (bloque etiquetado que envuelve todo
  el cuerpo) en vez de `exit`, para no matar la sesión. Con `throw` funcionaba
  pero dejaba un volcado rojo de excepción en pantalla.
- **`$MyInvocation` NO sirve para que el script se lea a sí mismo bajo `iex`**:
  devuelve el texto del script **contenedor**, no el propio (verificado: dos
  fragmentos distintos ejecutados por `iex` reportan el mismo largo). Por eso la
  re-ejecución **vuelve a descargar** `install.ps1` de su URL en vez de
  escribirse desde `$MyInvocation`.
- `DOTFILES_INLINE_MODE` se **inicializa** en el preámbulo: con `Set-StrictMode`,
  leer una variable no establecida lanza error.

### `[System.IO.File]::Open('CONIN$')` NO funciona en PowerShell 5.1

Para leer el teclado bajo `irm | iex` (stdin es el pipe, `Read-Host` no ve al
usuario) hay que abrir la consola física. Pero `FileStream` **rechaza abrir
dispositivos de consola** en .NET Framework: *"se solicitó a FileStream que
abriera un dispositivo que no era un archivo"*. En **pwsh 7 (.NET moderno) sí
funciona** — por eso `bootstrap.ps1` nunca falló, solo corre en pwsh 7.

Esto causó el bug más difícil de la instalación en Windows limpio: la lectura
fallaba siempre, `Read-ConsoleLine` devolvía `$null`, el instalador concluía
«no hay consola interactiva» y hacía `exit` → **la terminal se cerraba sin
dejar contestar** la pregunta de instalar pwsh 7/winget.

- La forma que **sí** funciona en 5.1: pedir el handle con **`CreateFileW`** y
  envolverlo en `SafeFileHandle` + `FileStream` + `StreamReader`.
- `GENERIC_READ` (`0x80000000`) debe castearse a **`[uint32]`**: PowerShell lo
  toma como `Int32` negativo y la llamada falla al convertir el argumento.
- Verificar con stdin redirigido (`< /dev/null` o un pipe): `IsInputRedirected`
  da `True` y aun así el handle de `CONIN$` debe ser válido.

## Paridad obligatoria

Cualquier función o alias que se toque en un shell **debe replicarse en los otros**:

- `shell/bashrc` ↔ `shell/zshrc` ↔ `shell/profile.ps1` (PowerShell, cuando aplique).
- `test-bootstrap.sh` verifica la paridad de funciones bash↔zsh. Correr tras tocar
  los shells: `bash test-bootstrap.sh`.

## Arquitectura

- **Dos repos:** este es el **público**. Lo sensible (claves SSH, identidades git,
  tokens) vive en `dotfiles-vault` (privado), referenciado vía `$VAULT_DIR`.
- **`bootstrap.sh`** (Linux) / **`bootstrap.ps1`** (Windows): instalan paquetes y
  crean los symlinks. Primitivas: `copy_dotfile <src> <dst> [link|copy]` para
  archivos y `link_dir <src> <dst>` para directorios (nvim, user-themes).
  Flags: `--dry-run`, `--skip-packages`, `--with-aws`, `--all-tools`.
- **`git-profiles.sh` / `.ps1`**: asistente que GENERA un vault válido para
  terceros sin vault (lo invoca install como opción del paso de vault). Testeable
  sin tty: `GIT_PROFILES_INPUT=<archivo-de-respuestas>`.
- **Contrato del vault** (`shell/git-identities.sh`/`.ps1`): además de nombres/
  emails/aliases, dos variables opcionales que bootstrap y tests consumen:
  `GIT_CONTEXT_DIRS` (carpetas bajo `~/repositorios/`; fallback
  personal/work/cei_walle) y `GIT_IDENTITY_FILES` (mapa sufijo→perfil de los
  `~/.gitconfig-<sufijo>`; fallback al mapeo histórico). El vault propio no las
  define — no agregarlas ahí sin motivo.
- **Globs de `hasconfig`** (wildmatch): `*` no cruza `/` y `**` solo es especial
  delimitado por `/`. Para URLs scp (`user/repo`) usar `:*/*` y `:**/**` —
  nunca `:**` pelado (no matchea).

## dconf NO es archivo (Ptyxis / GNOME)

Ptyxis y GNOME guardan su config en la base de datos `dconf`, no en archivos, así
que **no se symlinkean**. Se sincronizan con helpers definidos en `bashrc`:

- `ptyxis-save` / `gnome-save`: sistema → repo (volcar al `.dconf` versionado).
- `ptyxis-load` / `gnome-load`: repo → sistema.

Tras cambiar atajos/tema por la GUI, hay que correr el `*-save` para versionarlo.
Editar el `.dconf` a mano no aplica nada hasta hacer `*-load`.

### Abrir Ptyxis SIEMPRE requiere `--new-window`

`ptyxis` pelado **no abre una ventana**: es `DBusActivatable`, así que manda
`activate` a la instancia ya corriendo y esa presenta la ventana **que ya tenía
abierta**. Si esa ventana está en otro escritorio, GNOME Shell no cambia de
workspace (prevención de robo de foco) y solo tira la notificación *«Terminal
está preparada»* → desde el otro escritorio parece que el atajo/lanzador no hace
nada. Verificado en Fedora.

- **Atajo de teclado:** `gnome/media-keys.dconf` → `custom0` usa
  `ptyxis --new-window`. Reversionar con `gnome-save`.
- **Ulauncher / menú de apps:** lanzan el `Exec` del `.desktop` del sistema, que
  no se puede editar (lo pisan los updates). El bootstrap (paso 5) genera un
  **override** en `~/.local/share/applications/org.gnome.Ptyxis.desktop` con
  `Exec=ptyxis --new-window` y **sin `DBusActivatable`** — con activación D-Bus
  el `Exec` se ignora y vuelve el problema. Mismo patrón que el override de
  Chrome; `uninstall.sh` lo limpia.
- `--tab` reproduce el bug (usa la ventana activa, esté donde esté) y `-s` abre
  un proceso separado, que no es lo que se quiere.

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

- `.claude/CLAUDE.md` → **fuente única de reglas para TODOS los agentes de IA**:
  symlinkeado a `~/.claude/CLAUDE.md` (Claude Code) y, si están instalados, a
  `~/.codex/AGENTS.md` (Codex) y `~/.config/opencode/AGENTS.md` (opencode).
  Editar ese archivo cambia las reglas de los tres.
- `settings.json` → **symlink** (cambios se versionan al instante).
- **Los plugins ya viajan solos, gratis:** `/plugin marketplace add` y
  `/plugin install` escriben `extraKnownMarketplaces` y `enabledPlugins` **dentro
  de `settings.json`**, o sea del archivo versionado. Registrar y habilitar un
  plugin en Windows queda aplicado en Fedora con un commit; lo único no versionado
  es el clon en `~/.claude/plugins/`, que se rebaja solo. **Las skills globales de
  `~/.claude/skills/` NO se versionan** (el bootstrap solo symlinkea `CLAUDE.md` y
  `settings.json`): lo que quieras portable va como plugin, no como carpeta suelta.
- `statusline.sh` → **no se copia**; `settings.json` lo referencia desde el repo.
  Lo verifica la **sección 14 de `test-bootstrap.sh`** (le mete el JSON por stdin,
  con jq y con un `PATH` sin jq para ejercitar el fallback de Git Bash).
- `settings.local.json` → **per-máquina** (permisos con rutas absolutas que
  difieren Linux/Windows). **No está trackeado** (lo cubre el `.gitignore`):
  cada PC mantiene el suyo y nunca entra en commits ni rebases.
- `keybindings.json` → **NO se versiona a propósito** (lo cubre `.claude/*`).
  Decisión: ambas máquinas usan los **defaults de Claude Code**, sin archivo. El
  que había era un **volcado completo de los defaults** (ni un rebind propio) que
  escribe Claude Code solo, y refleja los defaults de **la versión instalada** →
  con versiones distintas en Linux y Windows los archivos divergen y parece
  config propia. Versionar el dump es peor que no tenerlo: congela los defaults
  de hoy y tapa los que agreguen versiones futuras. Si algún día hace falta
  customizar, va un archivo **mínimo** con solo los rebinds (y ahí sí evaluar
  symlinkearlo), no el dump.
  - **Quién lo crea:** el comando **`/keybindings`**. Su mensaje dice *"Created
    ... with template"*, pero el "template" **es el dump completo de los
    defaults** — así que el archivo **reaparece** cada vez que se abre el comando
    y hay que volver a borrarlo si se lo quiere sin archivo. Al recrearlo en
    Windows quedó `"alt+v": "chat:imagePaste"` donde Fedora tenía `"ctrl+v"`:
    misma acción, tecla distinta según la versión instalada. Esa es la prueba de
    que el archivo refleja el CLI, no las preferencias del usuario.
  - **`shift+enter` no lo necesita:** en Windows lo resuelve el terminal —
    `terminal/settings.json` mapea `shift+enter` a un `sendInput` con ESC+CR
    (bytes `0x1b 0x0d`), que Claude lee como salto de línea. Un `chat:newline`
    en `keybindings.json` sería redundante: la tecla nunca le llega.
  - **En Linux (Ptyxis) el equivalente es `Alt+Enter`, sin configurar nada.**
    VTE aplica el prefijo meta ESC, así que Alt+Enter manda **los mismos bytes
    `0x1b 0x0d`** que el `sendInput` de Windows Terminal. Verificado en Ptyxis
    50.1 / VTE 0.84 (`cat -v` imprime `^[^M`). Más amigable que el `Ctrl+J` que
    Claude trae por default; tampoco necesita `keybindings.json`.
  - **`shift+enter` es IMPOSIBLE en Ptyxis** (y en cualquier terminal VTE, p.ej.
    gnome-terminal — los docs de Claude Code lo listan como *"Not available"*).
    Dos razones independientes: **(a)** VTE **no implementa** el protocolo de
    teclado de kitty ni el `modifyOtherKeys` de xterm (`strings
    libvte-2.91-gtk4.so.0 | grep -i modifyotherkeys` → 0 hits), así que Enter,
    Shift+Enter y Ctrl+Enter llegan al PTY como **el mismo byte `0x0d`** y ningún
    programa puede distinguirlos; **(b)** Ptyxis **no tiene acción de mandar
    bytes** — su lista de atajos es un enum fijo de acciones de UI, sin análogo
    al `sendInput` de Windows Terminal (lo único cercano son
    `backspace-binding`/`delete-binding`, y solo para esas dos teclas).
    Ghostty/Kitty/WezTerm sí lo soportan sin setup: si algún día se evalúa
    reemplazar Ptyxis, esto suma al argumento del preview de imágenes de yazi
    (ver `yazi/`), que falla por la misma pobreza de protocolos de Ptyxis.
- **Atajos que "no funcionan"** casi nunca son un bug del archivo: los bindings
  son **por contexto** (`Task`, `Transcript`, `Scroll`…), no globales — `ctrl+b`
  solo manda a background si hay una tarea en foreground, y `ctrl+e` hace tres
  cosas distintas según el foco. Gana el contexto más específico (`up` en el chat
  es historial, salvo que esté abierto el autocomplete). `cmd+*` es de macOS.
  Y el **terminal se queda las teclas antes** que Claude: `Ctrl+Shift+K` lo toma
  Windows Terminal (limpia buffer), `Ctrl+Shift+C`/`B` los toma Ptyxis/GNOME, y
  `ctrl+s` puede morir en el flow control del tty (`stty -a | grep ixon`).
  Los warnings de validación salen con `claude --debug` (líneas `[keybindings]`).

### `/cd` mueve el cwd, NO el proyecto de la sesión

El JSON que llega al statusline por stdin trae **los dos por separado**:
`workspace.current_dir` (el cwd, que `/cd` mueve) y `workspace.project_dir` (fijo
de por vida: es la carpeta desde la que se lanzó `claude`). Del **proyecto** salen
la memoria, el historial (`~/.claude/projects/<slug>/`) y el `CLAUDE.md` de
proyecto que se cargó al inicio — un `/cd` a otro repo **no** los cambia.

Por eso `statusline.sh` muestra los dos cuando difieren (`proyecto ⚠️ cwd`, el cwd
en amarillo) y la ruta relativa cuando el cwd está dentro del proyecto. Sin eso la
línea decía solo el cwd y trabajar en un repo con las reglas y la memoria de otro
no se notaba (menos todavía si ambos están en `main`).

- **Los campos del payload se verificaron contra el binario, no contra la doc**
  (`grep`/`dd` sobre `~/.local/share/claude/versions/<v>`; internamente
  `current_dir = session.project.cwd` y `project_dir = session.project.originalCwd`).
  Además de los que se usan hay: `added_dirs`, `git_worktree`, `repo`, `cost.*`,
  `context_window.*`, `rate_limits.*`, `vim.mode`, `agent.name`, `pr.*`,
  `worktree.*`, `session_name`, `fast_mode`, `thinking.enabled`.
- **Sin jq hay que desambiguar por el padre:** el fallback grep/sed de Git Bash
  buscaba claves planas y `name` aparece en `output_style`, `agent` y `worktree`,
  igual que `used_percentage` en `context_window` **y** en `rate_limits`. Por eso
  `_json_get` recorta el JSON en cada padre antes de buscar la hija.
- **Redondear el porcentaje con `LC_ALL=C printf '%.0f'`:** con el locale `es_AR`
  la coma decimal rompe el formateo de un valor como `12.3456`.

### Instalar plugins en Windows: lo bloquea el SSL de git, no Claude Code

Detrás del proxy corporativo (Netskope) `/plugin marketplace add` **falla siempre**,
y el error engaña porque parece de permisos (`Could not read from remote repository`).
Son dos caminos tapados a la vez:

- **HTTPS:** el `gitconfig` **de sistema** de Git for Windows fija
  `http.sslbackend=openssl` con su propio `ca-bundle.crt`, que no tiene la CA de
  Netskope → `self-signed certificate in certificate chain`.
- **SSH:** acá los remotes usan **host aliases** (`github.com-kevincharp`), así que
  `git@github.com` pelado no engancha ninguna clave.

Lo arregla el paso 9 del bootstrap seteando **`GIT_SSL_CAINFO`** (variable de
usuario) al mismo `~/combined-ca.pem` que ya se armaba para AWS — ahora lo produce
`Get-NetskopeCaBundle`, que se llama desde los pasos 8 y 9. Por qué así y no de las
formas obvias:

- **`git config --global` escribiría DENTRO DEL VAULT** (`~/.gitconfig` es symlink a
  `$VAULT_DIR/git/config`) y además viajaría a Fedora, que no necesita nada de esto.
- `http.sslBackend=schannel` también funciona (usa el almacén de Windows), pero es
  una opción sin sentido fuera de Windows y **no hay `includeIf` por SO** donde
  encerrarla.
- `GIT_SSL_CAINFO` es una variable **dedicada**: no secuestra `GIT_CONFIG_COUNT`
  (que pisaría cualquier otra herramienta que la use) y al ser variable de usuario
  de Windows no existe en Linux.

Para agregar un marketplace conviene la URL completa (`https://…/repo.git`): la
forma corta `owner/repo` puede resolver a SSH y volver a caer en el problema.

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

### Entrada de emojis: atajo `Super+.` → GNOME Caracteres

Como el picker nativo de GTK (`Ctrl+.`) no engancha con Chrome/PWAs bajo Wayland,
la entrada se resuelve con un **atajo a `gnome-characters`** (app nativa que ya
viene con Fedora, `Super+.` como en Windows/KDE). Flujo: abrís, elegís, **copia al
portapapeles** y pegás con `Ctrl+V`. Vive en `gnome/media-keys.dconf` como
`custom4` y lo aplica el bloque GNOME del bootstrap (`dconf load`). Reversionar:
`gnome-save`.

- **No hay nada que instalar:** `gnome-characters` es parte de Fedora, no está en
  el catálogo del bootstrap.
- **Por qué NO auto-inserta (siempre `Ctrl+V`):** Wayland **prohíbe que una app
  simule teclado en otra** (aislamiento). Ningún picker (Caracteres, Smile con su
  auto-paste vía xdotool, etc.) puede insertar directo en Chrome/Outlook web bajo
  Wayland — todos terminan en copiar→pegar.
- **Por qué aparece como app (dock + overview):** cualquier ventana normal sale en
  el dock/multitarea; lo decide el compositor, no la app. El panel de emojis de
  Windows no es una app sino parte del shell. Replicar ese "no-app" en GNOME
  requeriría una **extensión de shell**, no una app.
- **Por qué Caracteres y no Smile:** se evaluó **Smile** (Flatpak) y se descartó —
  bajo Wayland tiene el **mismo** comportamiento (app en dock, `Ctrl+V` porque su
  auto-paste xdotool no inyecta en apps Wayland nativas). Solo sumaba favoritos/tags
  a cambio de una dependencia extra; Caracteres ya está y cubre además **todo
  Unicode** (símbolos, flechas, matemáticas), no solo emojis.

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

## Neovim (`nvim/`)

Editor de código **principal** (VSCode queda como complemento para lo que nvim
hace peor, no como reemplazo). Config propia estilo kickstart: `init.lua` +
`lua/` (opciones, atajos, tipos-archivo, gestor) y **un archivo por plugin** en
`lua/plugins/`. Sumar un plugin = crear un archivo; sacarlo = borrarlo.

- **Symlink de DIRECTORIO, con path distinto por SO:** Linux →
  `~/.config/nvim`; Windows → **`%LOCALAPPDATA%\nvim`** (no `~/.config`), salvo
  que la máquina tenga `$XDG_CONFIG_HOME` seteada a mano (algunas la fijan
  para que varias apps usen paths estilo Linux también en Windows): Neovim la
  respeta también en Windows y resuelve `stdpath('config')` ahí, así que
  `bootstrap.ps1` symlinkea a
  `$env:XDG_CONFIG_HOME\nvim` cuando existe esa variable, no a
  `%LOCALAPPDATA%\nvim` a secas — symlinkear el segundo en esa máquina deja a
  nvim sin encontrar la config (arranca con defaults, sin tema ni lualine).
  Tiene que ser el directorio entero, no archivo por archivo, porque lazy.nvim
  escribe el `lazy-lock.json` adentro y así el cambio queda versionado al
  instante.
- **Gateado por el selector:** si no elegiste neovim, el bootstrap NO crea el
  link. Sin el gate, quien no lo quería se llevaba un `~/.config/nvim` apuntando
  acá y el día que instalara nvim arrancaba con ESTA config.
- **En Windows el symlink necesita Modo de desarrollador.** Si está apagado, el
  paso se omite con WARN y **no se toca la config previa** — nvim arranca con
  defaults, y el síntoma (sin tema, sin números de línea) es indistinguible de
  "nvim roto".
- **`lazy-lock.json` SE VERSIONA:** es lo que hace que Linux y Windows tengan los
  mismos plugins en la misma versión. Flujo al tocar plugins: `:Lazy sync` y
  **commitear el lock en su propio commit** (`chore(nvim): fijar …`).
- **Nada de lo que baja se versiona:** plugins, parsers de treesitter y binarios
  de Mason viven en el data-dir (`~/.local/share/nvim`), fuera del repo.

### Requisitos de máquina (fáciles de olvidar)

- **`tree-sitter-cli`** (>= 0.25): nvim-treesitter rama `main` compila los
  parsers con él. Está en el catálogo `core` del bootstrap (Fedora lo tiene en
  repos base; Windows es winget). Sin esto **no hay resaltado de sintaxis**.
- **Compilador C:** en Linux ya hay gcc. En Windows no viene de fábrica — el
  bootstrap instala **zig** (catálogo `core`, `zig.zig`) porque es liviano (un
  binario vía winget, sin Visual Studio), pero zig solo **no alcanza**: hacen
  falta dos ajustes más, hechos en el paso "shim de compilador" de
  `bootstrap.ps1`:
  1. `tree-sitter-cli` invoca literalmente un programa llamado `cc` (ver su
     `do_compile`). No entiende `CC="zig cc"` — usa solo la primera palabra
     como programa y descarta el resto, así que termina llamando `zig` con
     `-O2` (u otro flag) como si fuera un subcomando, y zig lo rechaza
     (`unknown command`). Hace falta un único ejecutable `cc.exe` que reenvíe
     todo a `zig cc` — es `nvim/windows-cc-shim.c`, que el bootstrap compila
     con `zig build-exe` a `~/.local/bin/cc.exe`.
  2. `tree-sitter-cli` le pasa a `cc` el target triple con el que se compiló
     la propia herramienta, en formato Rust/LLVM (`x86_64-pc-windows-msvc`).
     El parser de targets de zig no tiene campo de *vendor* y no entiende ese
     string tal cual (`UnknownOperatingSystem`). El shim lo reescribe a
     `x86_64-windows-gnu`, que zig resuelve con sus propios headers de
     mingw-w64 embebidos, sin depender de Visual Studio.
  `CC=cc` queda seteada a nivel de **usuario** (no solo para nvim) — cualquier
  otra herramienta en la máquina que lea `CC` (make, cargo build scripts,
  node-gyp…) va a compilar vía zig-como-gnu en vez de cl.exe/MSVC. Aceptado a
  propósito: la alternativa es no tener resaltado de sintaxis en Windows.
- **node** para varios servidores de Mason. Detrás del **proxy corporativo**
  algunos paquetes de Mason no bajan; el síntoma es un servidor que nunca
  aparece, no un error visible.

### Atajos: dos reglas que ya nos mordieron

1. **Los nativos ganan.** No se pisan las teclas de vim ni las de nvim 0.12:
   `[b`/`]b`, `[q`/`]q`, `[t`/`]t`, `[c`/`]c`, `grn`/`gra`/`grr`/`gri`, `gO`, `K`,
   `gc`. Por eso todo lo propio vive detrás del líder (espacio), los saltos de
   pendientes NO usan `]t`/`[t` y el contexto fijo NO usa `[c`.
2. **Un atajo suelto BLOQUEA todo su prefijo.** Si `<leader>f` es una acción
   terminada, no puede existir `<leader>ff`. Pasó dos veces: el formateo se mudó
   de `<leader>f` a `<leader>cf` para liberar el grupo "buscar", y las sesiones
   usan `<leader>p` en vez del `<leader>q` que sugiere su README porque
   `<leader>q` ya es "cerrar ventana".

**Antes de crear un atajo hay que verificarlo sobre los mapeos REALES**, no de
memoria: `nvim --headless -u ~/.config/nvim/init.lua` + `nvim_get_keymap('n')`
filtrando por el prefijo. Y ojo con quién se queda la tecla primero: el
**terminal** (Alt+1..9 son las pestañas de Ptyxis, Ctrl+PageUp/Down son del
terminal) y **GNOME** (`Ctrl+Space` es Ulauncher).

### treesitter usa la rama `main`, y eso cambia las reglas

`master` está congelada y **rompe en nvim 0.12** (abrir un `.md` con un bloque
` ```lua ` tiraba `query_predicates.lua:141: attempt to call method 'range'`).
La rama `main` no se configura por `opts`, no prende el resaltado sola y **no
soporta carga diferida** → `lazy = false` es obligatorio y el arranque subió de
~19 ms a ~30 ms, a cambio. El detalle está en `nvim/lua/plugins/treesitter.lua`.

- **Filetypes compuestos:** los compose se detectan como `yaml.docker-compose`
  (ver `lua/tipos-archivo.lua`) para que les enganchen **los dos** servidores
  (yamlls con su esquema + docker_compose_language_service). conform resuelve por
  el filetype **entero**, así que hay que nombrarlo tal cual en
  `formatters_by_ft`. Para treesitter, `vim.treesitter.language.get_lang()`
  traduce (`yaml.docker-compose`→`yaml`, `sh`→`bash`, `jsonc`→`json`).

### Ausencias deliberadas (no son olvidos)

Cada una está documentada en su archivo: **Telescope** (el picker es snacks),
**dashboard**, **DAP/debugger** y **runner de tests** (se descartaron
explícitamente), **sqls** (necesita un `config.yml` con la cadena de conexión, y
esto es un repo público), **dockerfmt** (se compila con Go, que no está; formatea
dockerls vía el `lsp_format = 'fallback'` de conform).

**Windows pendiente:** `vim.o.shell` sigue en `cmd.exe` (no se pasó a pwsh) y
nada de esto se puede verificar desde Linux.

### Verificar cambios de nvim sin abrir nvim

Se prueba **headless** contra un fixture, comparando contra la realidad (extmarks,
mapeos, items del picker), no contra el README del plugin. Dos trampas:

- **Un error dentro de `vim.defer_fn`/`vim.schedule` se come el `qa!`** y nvim
  headless, sin UI, **se cuelga para siempre**. Siempre `pcall` alrededor del
  cuerpo del test y `timeout 90` alrededor del comando.
- **El setup de un plugin de lazy.nvim es DIFERIDO:** en el mismo tick en que
  lazy lo carga, su config todavía no está armada (verificado con
  todo-comments: `config.search_regex` es `nil` y aparece un tick después). Si un
  atajo es lo que dispara la carga y necesita algo del setup, va dentro de
  `vim.schedule`.

## Verificación

- Sintaxis: `bash -n shell/bashrc`, `zsh -n shell/zshrc`.
- `bash test-bootstrap.sh` tras cambios en shells/symlinks (verifica paridad).
- Tras tocar `nvim/`: prueba headless contra un fixture (ver la sección de
  Neovim) y `:checkhealth` para las dependencias externas.
