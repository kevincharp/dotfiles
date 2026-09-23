# CLAUDE.md

Dotfiles multiplataforma (Linux/Fedora + Windows). Configs de shell, terminal,
git y Claude Code, reproducibles en cualquier máquina vía `bootstrap`.

Este archivo tiene solo **reglas activas** (qué hacer). El "por qué" —bugs
reales, alternativas evaluadas y descartadas, forense byte a byte— vive en
[`docs/notas-tecnicas.md`](docs/notas-tecnicas.md); lo enlazo puntualmente
donde aplica.

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
5.1 lee los `.ps1` como **ANSI (cp1252)**, no UTF-8: un carácter no-ASCII
dentro de un string puede decodificarse como bytes que **cierran el string** y
tiran un error de parseo del archivo entero — el gate ni llega a ejecutarse.
Detalle completo (el bug de `iex`/`exit` y el de leer stdin en 5.1):
[`docs/notas-tecnicas.md`](docs/notas-tecnicas.md#installps1-el-problema-de-fondo-irm--iex).

- En `install.ps1`: **nada de no-ASCII en strings** (usar `-` en vez de `—`). En
  comentarios es inofensivo.
- Los iconos se construyen por código (`[char]0x2713`), no como literales, y
  caen a ASCII si no hay pwsh 7 + UTF-8.
- Verificar el gate con `powershell -NoProfile -File install.ps1` (5.1): debe
  imprimir el mensaje legible y salir 1. `bootstrap.ps1` no tiene la
  restricción: solo lo invoca pwsh 7.
- Bajo `irm | iex`, `exit` mata la terminal (no el script) — por eso
  `install.ps1` se re-ejecuta solo como archivo (`-File`) antes de usar
  `exit`. No tocar ese mecanismo sin leer la nota completa.
- Leer stdin bajo `irm | iex` en PowerShell 5.1 requiere abrir `CONIN$` con
  `CreateFileW` (`FileStream` normal no puede) — mecanismo frágil, no
  reescribir sin leer la nota completa.

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

**Ptyxis siempre con `--new-window`** (atajo `custom0` en
`gnome/media-keys.dconf`, y el override del `.desktop` sin `DBusActivatable`):
sin eso, la activación D-Bus reutiliza una ventana en otro escritorio y GNOME
no cambia de workspace — parece que el atajo no hace nada. Por qué:
[`docs/notas-tecnicas.md`](docs/notas-tecnicas.md#ptyxis-por-qué---new-window-es-obligatorio).

## Launcher de apps (Ulauncher / Flow Launcher)

Lanzador estilo Spotlight, **uno por SO** (ninguno cruza): Linux → Ulauncher
(catálogo `apps`), Windows → Flow Launcher (winget, grupo `extras`).

Ulauncher tiene tres piezas, versionadas distinto:

- **Config** (`ulauncher/settings.json`, `shortcuts.json`) → **symlink** a
  `~/.config/ulauncher/`.
- **Atajo `Ctrl+Space`** → NO va en `ulauncher/`. Vive en
  `gnome/media-keys.dconf` (`custom1` → `ulauncher-toggle`): en Wayland el
  hotkey interno de Ulauncher no funciona. Reversionar con `gnome-save`.
- **Autostart** (`ulauncher/autostart.desktop`) → **copia** (no symlink) a
  `~/.config/autostart/`: GNOME reescribe ese `.desktop` desde su GUI.
- **Temas** (`ulauncher/user-themes/`) → **symlink**. Trae Liquid Glass
  (dark/light), vendorizado desde [kayozxo/ulauncher-liquid-glass]. El vidrio
  esmerilado real lo da la extensión GNOME **Blur My Shell**, config en
  `gnome/blur-my-shell.dconf`. En Wayland una extensión recién instalada no
  carga hasta reiniciar sesión.

## Claude Code (`.claude/`)

Versiona la config de Claude Code para portabilidad. Ojo con el manejo distinto:

- `.claude/CLAUDE.md` → **fuente única de reglas para TODOS los agentes de IA**:
  symlinkeado a `~/.claude/CLAUDE.md` (Claude Code) y, si están instalados, a
  `~/.codex/AGENTS.md` (Codex) y `~/.config/opencode/AGENTS.md` (opencode).
  Editar ese archivo cambia las reglas de los tres. Claude Code ≥v2.1.277 lee
  `AGENTS.md` nativamente, pero solo cuando NO hay ningún `CLAUDE.md` en el
  working dir o arriba — con nuestro symlink siempre hay uno, así que el
  mecanismo real sigue siendo el symlink, no la lectura nativa.
- `settings.json` → **symlink** (cambios se versionan al instante).
- **Los plugins ya viajan solos, gratis:** `/plugin marketplace add` y
  `/plugin install` escriben `extraKnownMarketplaces` y `enabledPlugins` **dentro
  de `settings.json`**, o sea del archivo versionado. Registrar y habilitar un
  plugin en Windows queda aplicado en Fedora con un commit; lo único no versionado
  es el clon en `~/.claude/plugins/`, que se rebaja solo. **Las skills globales de
  `~/.claude/skills/` NO se versionan** (el bootstrap solo symlinkea `CLAUDE.md` y
  `settings.json`): lo que quieras portable va como plugin, no como carpeta suelta.
- **`.claude-plugin/marketplace.json` (raíz del repo) — marketplace envoltorio.**
  Muchos repos de skills útiles **no publican `marketplace.json`** (algunos ni
  siquiera `plugin.json`), y sin eso `/plugin marketplace add` no los toma: la
  única vía sería clonarlos sueltos en `~/.claude/skills/`, que NO se versiona.
  Este marketplace los declara apuntando a sus repos de origen
  (`"source": {"source": "url", "url": "https://…​.git"}`), así que quedan
  registrados en `settings.json` y viajan solos.
  - **Un `SKILL.md` en la RAÍZ del repo alcanza** — no hace falta
    `skills/<nombre>/SKILL.md`.
  - **El marketplace se declara con `source: github` + `repo`, nunca con una
    ruta local.** Un `claude plugin marketplace add <ruta>` guarda
    `{"source": "directory", "path": "C:\\…"}` — ruta **absoluta**, que en Fedora
    no existe. La forma `github` es la única portable.
  - **Consecuencia: hay que pushear antes de que resuelva.** Registrarlo lee el
    `marketplace.json` **del remoto**, no del working tree; sin push falla con
    `Marketplace file not found`. Los plugins nuevos se agregan editando el JSON
    → commit → push → reiniciar Claude Code.
  - **Nada se pinea a un sha** (a diferencia del marketplace oficial): se sigue
    la rama por default de cada repo upstream. El costo es que un cambio
    upstream entra sin revisión — son repos de terceros.
- **Catálogo de skills:** `docs/agent-skills-catalogo.md` documenta el detalle
  técnico de qué está **instalado** hoy y por qué (hooks, invocación,
  solapamientos finos); `docs/skills-radar.md` es el panorama más amplio (todo
  lo evaluado, instalado o no, por categoría funcional). **Actualizar el que
  corresponda en el mismo commit** que toque `enabledPlugins` (`settings.json`)
  o `.claude-plugin/marketplace.json`.
- `statusline.sh` → **no se copia**; `settings.json` lo referencia desde el repo.
  Lo verifica la **sección 14 de `test-bootstrap.sh`**. Muestra proyecto vs. cwd
  cuando difieren (`/cd` mueve el cwd, no el proyecto de la sesión — detalle de
  los campos del payload:
  [`docs/notas-tecnicas.md`](docs/notas-tecnicas.md#cd-mueve-el-cwd-no-el-proyecto-de-la-sesión)).
- `settings.local.json` → **per-máquina** (permisos con rutas absolutas que
  difieren Linux/Windows). **No está trackeado** (lo cubre el `.gitignore`).
- `keybindings.json` → **NO se versiona a propósito**: se usan los defaults de
  Claude Code en ambas máquinas. `Alt+Enter` en Ptyxis ya manda los mismos
  bytes que `shift+enter` en Windows Terminal, sin configurar nada — y
  `shift+enter` real es imposible en Ptyxis/VTE (limitación del terminal, no
  nuestra). Detalle: [`docs/notas-tecnicas.md`](docs/notas-tecnicas.md#keybindingsjson-por-qué-no-se-versiona-y-por-qué-shiftenter-es-imposible-en-ptyxis).
- **Atajos que "no funcionan"** casi nunca son un bug del archivo: los bindings
  son **por contexto** (`Task`, `Transcript`, `Scroll`…), no globales. Y el
  **terminal se queda las teclas antes** que Claude (`Ctrl+Shift+K` lo toma
  Windows Terminal, `Ctrl+Shift+C`/`B` los toma Ptyxis/GNOME, `ctrl+s` puede
  morir en el flow control del tty). Los warnings de validación salen con
  `claude --debug` (líneas `[keybindings]`).
- **Updates de plugins — `claude update` actualiza SOLO el CLI:**
  - **`"autoUpdate": true`** en cada entrada de `extraKnownMarketplaces` —
    hay que ponerlo **a mano** en marketplaces de terceros: el default sale de
    una allowlist de nombres oficiales hardcodeada en el binario. Cualquier
    otro nombre arranca en `false`, en silencio.
  - `claude plugin marketplace update [nombre]` refresca el índice;
    `claude plugin update <plugin>` actualiza el código, de a uno — no existe
    un "update all" de plugins.
  - **Trampa: el update compara el string `version`, no el commit.** Sin
    `version` en el manifest, Claude Code usa el sha corto y cada commit
    upstream es una versión nueva (agarra siempre). Con `version` fija, no
    actualiza hasta que el autor la bumpee — para forzar igual: reinstalar
    (`claude plugin install <plugin>@<marketplace> -y`).
  - `installed_plugins.json` guarda un `gitCommitSha` que **queda
    desactualizado** tras un update: no sirve para saber qué commit está
    instalado.
- **Instalar plugins en Windows tras un proxy corporativo** puede fallar por el
  SSL de git (no por Claude Code) — variable `GIT_SSL_CAINFO`, mecanismo
  completo: [`docs/notas-tecnicas.md`](docs/notas-tecnicas.md#instalar-plugins-en-windows-lo-bloquea-el-ssl-de-git-no-claude-code).

## Emojis a color en Chrome (`fontconfig/`)

`fontconfig/fonts.conf` → **symlink** a `~/.config/fontconfig/fonts.conf`.
Fuerza los emoji a color en Chrome/Chromium (Chrome no usa el alias genérico
`emoji` de fontconfig, matchea por cobertura de glifo y sin esto ganan fuentes
monocromáticas). Detalle y comando de verificación:
[`docs/notas-tecnicas.md`](docs/notas-tecnicas.md#emojis-a-color-en-chrome-por-qué-fontconfig-y-no-basta-con-instalar-la-fuente).

- Arregla solo el **renderizado**. La **entrada** de emoji se resuelve con
  `Super+.` → GNOME Caracteres (`custom4` en `gnome/media-keys.dconf`), copiar
  y pegar con `Ctrl+V` — Wayland prohíbe que una app simule teclado en otra,
  así que ningún picker auto-inserta.

## Chrome duplicado en "Aplicaciones predeterminadas → Web"

`bootstrap.sh` (paso 5) genera un override local de `com.google.Chrome.desktop`
en `~/.local/share/applications/` quitándole los `x-scheme-handler/*` del
`MimeType` (el panel de GNOME no respeta `NoDisplay`, la única palanca real es
el `MimeType`). Se regenera en cada bootstrap; `uninstall.sh` lo limpia. Tras
reaplicar, reabrir Ajustes (el panel cachea la lista). Detalle:
[`docs/notas-tecnicas.md`](docs/notas-tecnicas.md#chrome-duplicado-en-aplicaciones-predeterminadas--web).

## Historial estilo PSReadLine (flecha ↑ → lista fzf)

Réplica del **ListView de PSReadLine**: al apretar **↑** se abre `fzf` con el
historial en lista vertical, mostrando **solo el comando** y **filtrado por
prefijo** con lo ya tipeado. No es automático (aparece al apretar ↑, no flota
mientras se tipea) — decisión consciente, alternativas evaluadas en
[`docs/notas-tecnicas.md`](docs/notas-tecnicas.md#por-qué-el-historial-estilo-psreadline-y-no-otras-alternativas).

- Implementado en `_fzf_history_widget` (función con paridad bash↔zsh, `zle -N`
  en zsh / `ble-bind -x` en bash vía ble.sh).
- **Ctrl+R** sigue siendo la búsqueda difusa por cualquier parte del comando.
- **`clear-history`** (función con paridad): sin args vacía todo el historial
  (con confirmación); con un patrón borra solo las líneas que matcheen.

## Capturas de pantalla (Flameshot + nativo de GNOME)

Conviven **dos** recortadores, a propósito (paridad parcial con Windows):

- **Flameshot** (recortador con anotaciones) → atajo **`Super+Shift+S`** (el mismo
  que el recorte de Windows). Vive en `gnome/media-keys.dconf` como `custom3`.
  Flameshot NO es una app con ventana — es un daemon de bandeja, se usa **solo
  por atajo** (`flameshot gui`).
- **Captura nativa de GNOME** → sigue en **`Print`** (intacta): en el notebook
  Lenovo `Print` depende de `Fn`, así que se dejó como estaba.
- El teclado del Lenovo además dispara Flameshot con **`Fn+F10`** por un keysym
  de hardware (no es un atajo de dconf, no se versiona).

## File manager TUI (`yazi/`)

File manager de terminal con preview de imágenes/PDF/video, en **ambos SO**
(opcional, grupo `shell` del selector).

- **Config con path distinto por SO** (misma `yazi/yazi.toml` versionada):
  Linux → symlink a `~/.config/yazi/yazi.toml`; Windows → symlink a
  **`%APPDATA%\yazi\config\yazi.toml`** (NO `~/.config`). Solo redefine el
  **opener** para usar **nvim** al editar texto.
- **`YAZI_FILE_ONE` (solo Windows):** apunta a `file.exe` de Git Bash porque
  yazi no encuentra el binario `file` solo ahí. En Linux no hace falta.
- **Instalación en Fedora vía COPR** `lihaohong/yazi` (no está en repos base).
  Arch lo tiene en repos; Windows es winget `sxyazi.yazi`.
- **Deps de preview = bundle con yazi:** poppler (PDF), ffmpeg (video),
  ImageMagick (imágenes), 7zip (comprimidos) y —solo en Linux— **chafa**
  (Ptyxis no soporta sixel/kitty-protocol, sin chafa no se ve nada de imagen;
  detalle en [`docs/notas-tecnicas.md`](docs/notas-tecnicas.md#yazi-por-qué-chafa-y-por-qué-el-path-de-config-difiere-en-windows)).
  Requiere ancho suficiente en la ventana o yazi oculta la columna de preview.
- **Función `y` (cd-on-exit):** wrapper con paridad en los 3 shells. Lanza yazi
  con `--cwd-file` y al salir deja el shell en el último directorio navegado.

## Neovim (`nvim/`)

Editor de código **principal** (VSCode queda como complemento para lo que nvim
hace peor, no como reemplazo). Config propia estilo kickstart: `init.lua` +
`lua/` (opciones, atajos, tipos-archivo, gestor) y **un archivo por plugin** en
`lua/plugins/`. Sumar un plugin = crear un archivo; sacarlo = borrarlo.

- **Symlink de DIRECTORIO, con path distinto por SO:** Linux →
  `~/.config/nvim`; Windows → **`%LOCALAPPDATA%\nvim`** (o
  `$env:XDG_CONFIG_HOME\nvim` si esa variable existe — Neovim la respeta
  también en Windows). Tiene que ser el directorio entero, no archivo por
  archivo, porque lazy.nvim escribe `lazy-lock.json` adentro.
- **Gateado por el selector:** si no elegiste neovim, el bootstrap NO crea el
  link.
- **En Windows el symlink necesita Modo de desarrollador.** Si está apagado, el
  paso se omite con WARN y nvim arranca con defaults (síntoma indistinguible de
  "nvim roto": sin tema, sin números de línea).
- **`lazy-lock.json` SE VERSIONA:** mismos plugins en la misma versión en
  Linux y Windows. Flujo al tocar plugins: `:Lazy sync` y **commitear el lock
  en su propio commit** (`chore(nvim): fijar …`).
- **Nada de lo que baja se versiona:** plugins, parsers de treesitter y
  binarios de Mason viven en el data-dir (`~/.local/share/nvim`).

### Requisitos de máquina

- **`tree-sitter-cli`** (>= 0.25): compila los parsers de la rama `main` de
  nvim-treesitter. Sin esto, **no hay resaltado de sintaxis**.
- **Compilador C:** Linux ya tiene gcc. Windows usa **zig** + un shim propio
  (`nvim/windows-cc-shim.c`, compilado a `~/.local/bin/cc.exe`) porque
  `tree-sitter-cli` invoca literalmente `cc` y no entiende `CC="zig cc"` como
  dos palabras — mecanismo completo (y por qué el target triple se reescribe):
  [`docs/notas-tecnicas.md`](docs/notas-tecnicas.md#compilador-c-en-windows-por-qué-zig--shim-no-msvc).
  `CC=cc` queda seteada a nivel de usuario — afecta cualquier otra herramienta
  que lea `CC` en esa máquina, aceptado a propósito.
- **node** para varios servidores de Mason. Detrás del proxy corporativo
  algunos paquetes no bajan; el síntoma es un servidor que nunca aparece.

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

### treesitter usa la rama `main`

`master` está congelada y rompe en nvim 0.12 — por eso `main`, que exige
`lazy = false` (no soporta carga diferida). Detalle de la migración forzada:
[`docs/notas-tecnicas.md`](docs/notas-tecnicas.md#treesitter-en-rama-main-no-master).

- **Filetypes compuestos:** los compose se detectan como `yaml.docker-compose`
  (ver `lua/tipos-archivo.lua`) para que les enganchen **los dos** servidores
  (yamlls con su esquema + docker_compose_language_service). conform resuelve
  por el filetype **entero** — nombrarlo tal cual en `formatters_by_ft`. Para
  treesitter, `vim.treesitter.language.get_lang()` traduce
  (`yaml.docker-compose`→`yaml`, `sh`→`bash`, `jsonc`→`json`).

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
