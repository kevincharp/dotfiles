# Notas técnicas (bitácora de decisiones y forense de bugs)

Detalle completo de **por qué** las reglas de `CLAUDE.md` son como son: bugs
reales encontrados, alternativas evaluadas y descartadas, mecanismos
internos verificados byte a byte. `CLAUDE.md` se quedó solo con la regla
activa y corta ("qué hacer"); este archivo tiene el "por qué" — no hace
falta leerlo en cada sesión, solo cuando se toca de nuevo esa parte del
código y hace falta el contexto completo para no repetir un error ya
resuelto.

## `install.ps1`: el problema de fondo (`irm | iex`)

`iex` ejecuta el script **dentro de la sesión interactiva**, no como script
propio: ahí `exit` no termina el script sino **la sesión**, así que la
ventana se cierra y el usuario nunca lee el mensaje de error. Verificado:
con `iex`, nada de lo que sigue a un `exit` se ejecuta y la consola muere;
con `-File` la sesión sobrevive.

- **`install.ps1` se re-ejecuta como archivo** al detectar que vino por `iex`
  (sin `$PSCommandPath`): se escribe a `$env:TEMP` y se relanza con `-File`.
  Recién ahí los `exit` son seguros.
- La re-ejecución tiene **guarda anti-recursión** (`DOTFILES_INSTALL_REEXEC` +
  chequeo de que el texto sea realmente este script). Sin eso, con un `iex`
  anidado `$MyInvocation` devuelve el script **contenedor** y se relanza
  infinitamente — pasó, cuelga la máquina y deja procesos y temporales.
- El temporal se escribe con `-Encoding Default` (cp1252): es lo que 5.1
  espera, y el archivo es ASCII puro igual.
- Los `exit` del script pasan por **`Stop-Install`**: si la re-ejecución no
  pudo hacerse, corta con `break dotfilesInstall` (bloque etiquetado que
  envuelve todo el cuerpo) en vez de `exit`, para no matar la sesión. Con
  `throw` funcionaba pero dejaba un volcado rojo de excepción en pantalla.
- **`$MyInvocation` NO sirve para que el script se lea a sí mismo bajo
  `iex`**: devuelve el texto del script **contenedor**, no el propio
  (verificado: dos fragmentos distintos ejecutados por `iex` reportan el
  mismo largo). Por eso la re-ejecución **vuelve a descargar** `install.ps1`
  de su URL en vez de escribirse desde `$MyInvocation`.
- `DOTFILES_INLINE_MODE` se **inicializa** en el preámbulo: con
  `Set-StrictMode`, leer una variable no establecida lanza error.

## `[System.IO.File]::Open('CONIN$')` NO funciona en PowerShell 5.1

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

## Ptyxis: por qué `--new-window` es obligatorio

`ptyxis` pelado **no abre una ventana**: es `DBusActivatable`, así que manda
`activate` a la instancia ya corriendo y esa presenta la ventana **que ya
tenía abierta**. Si esa ventana está en otro escritorio, GNOME Shell no
cambia de workspace (prevención de robo de foco) y solo tira la notificación
*«Terminal está preparada»* → desde el otro escritorio parece que el
atajo/lanzador no hace nada. Verificado en Fedora.

- **Ulauncher / menú de apps:** lanzan el `Exec` del `.desktop` del sistema,
  que no se puede editar (lo pisan los updates). El bootstrap (paso 5) genera
  un **override** en `~/.local/share/applications/org.gnome.Ptyxis.desktop`
  con `Exec=ptyxis --new-window` y **sin `DBusActivatable`** — con activación
  D-Bus el `Exec` se ignora y vuelve el problema. Mismo patrón que el
  override de Chrome; `uninstall.sh` lo limpia.
- `--tab` reproduce el bug (usa la ventana activa, esté donde esté) y `-s`
  abre un proceso separado, que no es lo que se quiere.

## Ulauncher: por qué el atajo y el autostart no son symlink de config

- **Atajo `Ctrl+Space`** no va en `ulauncher/`. Vive en `gnome/media-keys.dconf`
  (`custom1` → `ulauncher-toggle`) porque en **Wayland el hotkey interno de
  Ulauncher no funciona**, así que lo dispara un atajo de GNOME.
- **Autostart** (`ulauncher/autostart.desktop`) es **copia**, no symlink, a
  `~/.config/autostart/`: GNOME reescribe ese `.desktop` desde su GUI.
- Se evaluó **Smile** (Flatpak, alternativa a GNOME Characters para emojis) y
  se descartó: bajo Wayland tiene el mismo comportamiento (app en dock,
  `Ctrl+V` porque su auto-paste vía xdotool no inyecta en apps Wayland
  nativas). Solo sumaba favoritos/tags a cambio de una dependencia extra.

## `keybindings.json`: por qué no se versiona, y por qué `shift+enter` es imposible en Ptyxis

Decisión: ambas máquinas usan los **defaults de Claude Code**, sin archivo. El
que había era un **volcado completo de los defaults** (ni un rebind propio)
que escribe Claude Code solo, y refleja los defaults de **la versión
instalada** → con versiones distintas en Linux y Windows los archivos
divergen y parece config propia. Versionar el dump es peor que no tenerlo:
congela los defaults de hoy y tapa los que agreguen versiones futuras.

- **Quién lo crea:** el comando **`/keybindings`**. Su mensaje dice *"Created
  ... with template"*, pero el "template" **es el dump completo de los
  defaults** — así que el archivo **reaparece** cada vez que se abre el
  comando y hay que volver a borrarlo si se lo quiere sin archivo. Al
  recrearlo en Windows quedó `"alt+v": "chat:imagePaste"` donde Fedora tenía
  `"ctrl+v"`: misma acción, tecla distinta según la versión instalada. Esa es
  la prueba de que el archivo refleja el CLI, no las preferencias del
  usuario.
- **`shift+enter` no lo necesita en Windows:** lo resuelve el terminal —
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
  Shift+Enter y Ctrl+Enter llegan al PTY como **el mismo byte `0x0d`** y
  ningún programa puede distinguirlos; **(b)** Ptyxis **no tiene acción de
  mandar bytes** — su lista de atajos es un enum fijo de acciones de UI, sin
  análogo al `sendInput` de Windows Terminal (lo único cercano son
  `backspace-binding`/`delete-binding`, y solo para esas dos teclas).
  Ghostty/Kitty/WezTerm sí lo soportan sin setup: si algún día se evalúa
  reemplazar Ptyxis, esto suma al argumento del preview de imágenes de yazi,
  que falla por la misma pobreza de protocolos de Ptyxis.

## Claude Code: mecanismos internos verificados

### `/cd` mueve el cwd, NO el proyecto de la sesión

El JSON que llega al statusline por stdin trae **los dos por separado**:
`workspace.current_dir` (el cwd, que `/cd` mueve) y `workspace.project_dir`
(fijo de por vida: es la carpeta desde la que se lanzó `claude`). Del
**proyecto** salen la memoria, el historial (`~/.claude/projects/<slug>/`) y
el `CLAUDE.md` de proyecto que se cargó al inicio — un `/cd` a otro repo
**no** los cambia. Por eso `statusline.sh` muestra los dos cuando difieren.

- **Los campos del payload se verificaron contra el binario, no contra la
  doc** (`grep`/`dd` sobre `~/.local/share/claude/versions/<v>`;
  internamente `current_dir = session.project.cwd` y
  `project_dir = session.project.originalCwd`). Además de los que se usan
  hay: `added_dirs`, `git_worktree`, `repo`, `cost.*`, `context_window.*`,
  `rate_limits.*`, `vim.mode`, `agent.name`, `pr.*`, `worktree.*`,
  `session_name`, `fast_mode`, `thinking.enabled`.
- **Sin jq hay que desambiguar por el padre:** el fallback grep/sed de Git
  Bash buscaba claves planas y `name` aparece en `output_style`, `agent` y
  `worktree`, igual que `used_percentage` en `context_window` **y** en
  `rate_limits`. Por eso `_json_get` recorta el JSON en cada padre antes de
  buscar la hija.
- **Redondear el porcentaje con `LC_ALL=C printf '%.0f'`:** con el locale
  `es_AR` la coma decimal rompe el formateo de un valor como `12.3456`.

### Instalar plugins en Windows: lo bloquea el SSL de git, no Claude Code

Detrás del proxy corporativo (Netskope) `/plugin marketplace add` **falla
siempre**, y el error engaña porque parece de permisos (`Could not read from
remote repository`). Son dos caminos tapados a la vez:

- **HTTPS:** el `gitconfig` **de sistema** de Git for Windows fija
  `http.sslbackend=openssl` con su propio `ca-bundle.crt`, que no tiene la CA
  de Netskope → `self-signed certificate in certificate chain`.
- **SSH:** acá los remotes usan **host aliases** (`github.com-kevincharp`),
  así que `git@github.com` pelado no engancha ninguna clave.

Lo arregla el paso 9 del bootstrap seteando **`GIT_SSL_CAINFO`** (variable de
usuario) al mismo `~/combined-ca.pem` que ya se armaba para AWS. Por qué así
y no de las formas obvias:

- `git config --global` escribiría DENTRO DEL VAULT (`~/.gitconfig` es
  symlink a `$VAULT_DIR/git/config`) y además viajaría a Fedora, que no
  necesita nada de esto.
- `http.sslBackend=schannel` también funciona (usa el almacén de Windows),
  pero es una opción sin sentido fuera de Windows y no hay `includeIf` por SO
  donde encerrarla.
- `GIT_SSL_CAINFO` es una variable **dedicada**: no secuestra
  `GIT_CONFIG_COUNT` y al ser variable de usuario de Windows no existe en
  Linux.

Para agregar un marketplace conviene la URL completa (`https://…/repo.git`):
la forma corta `owner/repo` puede resolver a SSH y volver a caer en el
problema.

## Emojis a color en Chrome: por qué fontconfig y no basta con instalar la fuente

`fontconfig/fonts.conf` fuerza los emoji a color en Chrome/Chromium. El
detalle no obvio: **Chrome en Linux NO usa el alias genérico `emoji` de
fontconfig** — para cada carácter hace un match por cobertura de glifo (como
`fc-match -s :charset=1f600`). En ese match, **Symbola** y **Noto Emoji**
(monocromáticas) rankean por encima de **Noto Color Emoji**, así que los
emoji salen en blanco y negro. El `fonts.conf` las desprioriza con
`rejectfont`.

- **Verificar el fix:** `fc-match -s ':charset=1f600' | head -1` debe dar
  `Noto Color Emoji` (NO `fc-match emoji`, que Chrome ignora).
- Tras cambiarlo: `fc-cache -f` y **reiniciar Chrome entero** (cachea la
  selección de fuentes por proceso; cerrar la ventana no alcanza).
- Arregla solo el **renderizado**. La **entrada** de emoji (Ctrl+. de GTK) no
  funciona dentro de Chrome en Wayland (los campos de Chrome no son widgets
  GTK) — por eso la entrada se resuelve aparte con un atajo a
  `gnome-characters` (`Super+.`, copiar y `Ctrl+V`; Wayland prohíbe que una
  app simule teclado en otra, así que ningún picker puede auto-insertar).

## Por qué el historial estilo PSReadLine y no otras alternativas

Réplica del ListView de PSReadLine: **↑** abre `fzf` con el historial en
lista vertical, solo el comando, filtrado por prefijo. Se descartaron:

- **`zsh-autocomplete`**: es una grilla de completados, no historial.
- **`atuin`**: columnas fecha/duración no removibles en su v18.

No es automático (no flota mientras se tipea) a propósito — en Linux
**ninguna** herramienta combina lista vertical minimalista *y* aparición
automática. Lo automático inline lo cubre `zsh-autosuggestions`/`ble.sh`
(gris). `Ctrl+R` sigue siendo la búsqueda difusa complementaria.

## yazi: por qué chafa y por qué el path de config difiere en Windows

- **`YAZI_FILE_ONE` (solo Windows):** yazi no encuentra el binario `file`
  solo y falla la detección de MIME. Se apunta a `file.exe` de Git Bash. En
  Linux `file` está en PATH y no hace falta.
- **Instalación en Fedora vía COPR** (`lihaohong/yazi`): yazi no está en los
  repos base de Fedora. Arch lo tiene en repos; Windows es winget
  `sxyazi.yazi`.
- **Preview de imágenes depende del protocolo gráfico de la terminal.** yazi
  elige adapter en orden **kitty-protocol > sixel > chafa**. Windows Terminal
  soporta Sixel (imagen real). **Ptyxis NO soporta sixel ni kitty-protocol**
  (deshabilitado adrede, no por falta de soporte del VTE que sí trae sixel
  compilado) — por eso en Linux yazi cae **siempre a chafa** (bloques de
  color) y sin chafa no se ve nada de imagen. chafa no se instala en Windows
  (Windows Terminal ya da Sixel, y chafa no tiene paquete confiable en
  winget).

## Neovim: por qué la rama `main` de treesitter, y sus reglas de atajos

### treesitter en rama `main`, no `master`

`master` está congelada y **rompe en nvim 0.12** (abrir un `.md` con un
bloque ` ```lua ` tiraba `query_predicates.lua:141: attempt to call method
'range'` — cambio de API en nvim 0.11+ donde `match[capture_id]` pasó a ser
una lista, no un nodo único). La rama `main` no se configura por `opts`, no
prende el resaltado sola y **no soporta carga diferida** → `lazy = false` es
obligatorio y el arranque subió de ~19 ms a ~30 ms, a cambio. Su instalador
de parsers además dependía de tarballs que ya dan 404 (el parser 'jsonc', que
en 'main' ni existe aparte: el filetype 'jsonc' resuelve al parser 'json').

- **Filetypes compuestos:** los compose se detectan como
  `yaml.docker-compose` (ver `lua/tipos-archivo.lua`) para que les enganchen
  **los dos** servidores (yamlls con su esquema + docker_compose_language_service).
  conform resuelve por el filetype **entero**, así que hay que nombrarlo tal
  cual en `formatters_by_ft`. Para treesitter,
  `vim.treesitter.language.get_lang()` traduce
  (`yaml.docker-compose`→`yaml`, `sh`→`bash`, `jsonc`→`json`).

### Compilador C en Windows: por qué zig + shim, no MSVC

`tree-sitter-cli` invoca literalmente un programa llamado `cc`. No entiende
`CC="zig cc"` — usa solo la primera palabra como programa y descarta el
resto, así que termina llamando `zig` con `-O2` como si fuera un subcomando,
y zig lo rechaza (`unknown command`). Hace falta un único ejecutable
`cc.exe` que reenvíe todo a `zig cc` — es `nvim/windows-cc-shim.c`, que el
bootstrap compila con `zig build-exe` a `~/.local/bin/cc.exe`.

`tree-sitter-cli` le pasa a `cc` el target triple con el que se compiló la
propia herramienta, en formato Rust/LLVM (`x86_64-pc-windows-msvc`). El
parser de targets de zig no tiene campo de *vendor* y no entiende ese string
tal cual (`UnknownOperatingSystem`). El shim lo reescribe a
`x86_64-windows-gnu`, que zig resuelve con sus propios headers de mingw-w64
embebidos, sin depender de Visual Studio.

`CC=cc` queda seteada a nivel de **usuario** (no solo para nvim) — cualquier
otra herramienta en la máquina que lea `CC` (make, cargo build scripts,
node-gyp…) va a compilar vía zig-como-gnu en vez de cl.exe/MSVC. Aceptado a
propósito: la alternativa es no tener resaltado de sintaxis en Windows.

## Chrome duplicado en "Aplicaciones predeterminadas → Web"

El `.rpm` oficial de Google instala **dos** `.desktop` en
`/usr/share/applications/` durante su migración de nombres:
`google-chrome.desktop` (histórico) y `com.google.Chrome.desktop` (nuevo,
reverse-DNS). Ambos declaran `x-scheme-handler/http(s)`, así que Chrome
aparece **dos veces** en el selector Web.

- **Detalle no obvio:** el panel de GNOME **NO respeta `Hidden`/`NoDisplay`**
  — el `.rpm` ya marca `com.google.Chrome.desktop` con `NoDisplay=true` y aun
  así sale en la lista. La única palanca real es el `MimeType`.
- **Fix (bootstrap.sh, paso 5):** genera un override local de
  `com.google.Chrome.desktop` quitándole los `x-scheme-handler/http|https|google-chrome`
  del `MimeType` (conserva PDF/imágenes). Se **regenera** en cada bootstrap,
  no se versiona una copia estática.
- Si Google unifica los `.desktop` en el futuro, el override puede estorbar:
  `rm ~/.local/share/applications/com.google.Chrome.desktop`.
