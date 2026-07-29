# Arquitectura y decisiones de diseño

Cómo está armado el repo y por qué. Útil si querés entender qué hace el
bootstrap por dentro, contribuir, o copiarte ideas para tus propios dotfiles.

---

## Dos repos: público + vault

| Repo | Visibilidad | Contiene |
|---|---|---|
| **`dotfiles`** (este) | público | scripts de setup + configs no sensibles |
| **`dotfiles-vault`** | privado | claves SSH cifradas con `age`, identidades git con emails, tokens |

La regla es simple: **nada sensible en el repo público, nunca**. El bootstrap
combina ambos y funciona igual si el vault no está (saltea esos pasos con un
aviso). Quien no tiene vault puede generarse uno con el **asistente**
(`git-profiles.sh`/`.ps1`), que produce exactamente la estructura esperada.
Detalle: [Adaptalo](adaptalo.md#el-vault).

## Symlink vs copia

La primitiva del bootstrap es `copy_dotfile <src> <dst> [link|copy]` (y
`link_dir` para directorios). El criterio para elegir modo:

| Modo | Cuándo | Ejemplos |
|---|---|---|
| **symlink** | El archivo es del repo y quiero que editar = versionar (en cualquiera de las dos puntas) | bashrc, zshrc, profile.ps1, gitconfig, nvim/ (dir), yazi.toml, settings de Windows Terminal, Ulauncher y Claude Code |
| **copia** | Un programa **reescribe** el archivo en runtime (un symlink ensuciaría el repo/vault) o el contenido es per-máquina | `ssh/config`, `rclone.conf` (rclone refresca el token adentro), autostart de Ulauncher (GNOME lo reescribe) |

Antes de pisar cualquier archivo tuyo preexistente, el bootstrap lo respalda en
`~/.local/backups/bootstrap/<timestamp>/` — el desinstalador restaura desde ahí.

### Gate por herramienta

Ninguna config se aplica por el solo hecho de estar en el repo: primero pasa por
la **decisión única** de si el usuario quiere esa herramienta —
`want_tool <id>` (bash) / `Test-ToolWanted <Key>` (pwsh), que dan verdadero si el
id está en la selección (`SELECTED_TOOLS` / `$SELECTED_KEYS`) **o** si ya está
instalado (`tool_installed` / `Test-ToolInstalled`).

Cuenta "ya instalado" a propósito: si la máquina tiene nvim de antes y el usuario
no lo marcó (no hacía falta reinstalarlo), igual quiere su config — es el caso
normal al re-correr el bootstrap.

En Windows el gate es declarativo: las entradas de `$DOTFILES` llevan una clave
`Tool` con el dueño de la config, y el loop saltea las que no correspondan. Sin
`Tool`, la config se aplica siempre (es config base: `profile.ps1`,
`.editorconfig`, `git/ignore`). La tabla de qué depende de qué está en
[adaptalo.md](adaptalo.md#solo-se-configura-lo-que-elegís).

<a name="dconf"></a>
## dconf no es un archivo (Ptyxis / GNOME)

Ptyxis y GNOME guardan su config en la base de datos **dconf**, no en archivos:
no se puede symlinkear. El repo versiona *volcados* (`terminal/ptyxis.dconf`,
`gnome/*.dconf`) y los sincroniza con helpers:

```bash
gnome-save   # sistema → repo (después de cambiar algo por la GUI)
gnome-load   # repo → sistema (máquina nueva, o deshacer)
ptyxis-save / ptyxis-load   # ídem para la terminal
```

Puntos finos:

- `dconf load` es **aditivo**: escribe las claves del archivo sin borrar el
  resto. Por eso `shell.dconf` trae solo claves selectas.
- Para versionar una rama nueva se agrega a `_GNOME_DCONF_MAP` en
  `shell/bashrc`/`zshrc` **y** al mapa espejo en `bootstrap.sh`.
- El dock (`favorite-apps`) **no** se versiona a propósito: es estado personal
  y restaurarlo pisaba la lista real.
- Si no corrés `gnome-save` tras cambiar algo por GUI, repo y sistema divergen
  en silencio — es el precio de que dconf no sea un archivo.

## Paridad entre shells

Regla del repo: **cualquier función o alias que se toque en un shell debe
replicarse en los otros** (`bashrc` ↔ `zshrc` ↔ `profile.ps1` cuando aplica).
La paridad es de comportamiento, no de copy-paste — cada shell usa su idioma:

| Pieza | bash | zsh | PowerShell |
|---|---|---|---|
| Syntax highlighting + sugerencias | ble.sh | zsh-autosuggestions + zsh-syntax-highlighting | PSReadLine |
| Historial ↑ (lista por prefijo) | fzf vía `ble-bind`/`bind -x` | fzf vía `zle`/`bindkey` | PSReadLine ListView nativo |
| Prompt | oh-my-posh (mismo tema `claude-code.omp.json` en los tres) | | |
| Ayuda | `dothelp` parsea comentarios anotados | ídem | `dothelp` parsea el comment-based help |

`test-bootstrap.sh` **verifica la paridad** bash↔zsh (misma lista de funciones
en ambos rc) y que los shells carguen limpios. Correlo tras tocar los shells;
el bootstrap lo corre solo al final.

La paleta de colores es una sola (la de Claude Code) y está replicada en
LS_COLORS/eza, fzf, ble.sh, zsh-syntax-highlighting, PSReadLine, el tema de
oh-my-posh y hasta la barra de progreso del bootstrap.

## El bootstrap es idempotente

Re-correr el instalador es siempre seguro: detecta lo ya instalado (lo saltea),
los symlinks ya correctos (no los toca), las claves ya desencriptadas (no pide
passphrase). Es también el mecanismo de **actualización**: `update.sh` solo
hace pull de ambos repos y re-corre el bootstrap.

Los scripts bash corren con `set -euo pipefail`; las trampas conocidas de ese
modo (y cómo evitarlas) están documentadas en el `CLAUDE.md` del repo.

## Decisiones no obvias (resumen)

El detalle completo de cada una vive en [`CLAUDE.md`](../CLAUDE.md) — acá el
mapa:

- **Historial ↑ = lista fzf por prefijo**: réplica del ListView de PSReadLine.
  Se descartaron atuin (columnas no removibles) y zsh-autocomplete (completados,
  no historial). `Ctrl+R` sigue siendo la búsqueda difusa complementaria.
- **Emojis a color en Chrome (Linux)**: Chrome ignora el alias `emoji` de
  fontconfig y matchea por cobertura de glifo; `fontconfig/fonts.conf`
  desprioriza las fuentes monocromáticas para que gane Noto Color Emoji.
- **Chrome duplicado en «Aplicaciones predeterminadas»**: el rpm oficial
  instala dos `.desktop`; el bootstrap genera un override local sin los
  scheme-handlers para que aparezca uno solo.
- **Previews de yazi**: dependen del protocolo gráfico de la terminal
  (kitty > sixel > chafa). Ptyxis no soporta sixel, así que en Linux se instala
  `chafa` como fallback; Windows Terminal ya trae Sixel.
- **Flameshot por atajo** (`Super+Shift+S`): es un daemon de bandeja y GNOME no
  tiene tray — lanzarlo «como app» no muestra nada; el atajo vive en dconf.
- **Un launcher por SO**: Ulauncher (Linux, con tema Liquid Glass + Blur My
  Shell) y Flow Launcher (Windows). En Wayland el hotkey interno de Ulauncher
  no funciona: lo dispara un atajo de GNOME.
- **VSCode y Python manuales en Windows**: los instaladores de winget no dejan
  `code`/`python` bien en el PATH — ver [instalación](instalacion.md#windows).

## Estructura del repo

```
.dotfiles/
├── install.sh / install.ps1      # Instalador interactivo (público + vault)
├── bootstrap.sh / bootstrap.ps1  # Setup: paquetes + symlinks + dconf
├── git-profiles.sh / .ps1        # Asistente de perfiles git + vault propio
├── uninstall.sh / uninstall.ps1  # Desinstalador (restaura backups)
├── update.sh                     # Atajo: pull de repos + re-bootstrap
├── test-bootstrap.sh / .ps1      # Validación post-install + paridad de shells
├── shell/                        # bashrc · zshrc · profile.ps1 · tema oh-my-posh
├── nvim/                         # Config de Neovim (symlink de directorio)
├── terminal/                     # Windows Terminal (symlink) · Ptyxis (dconf)
├── gnome/*.dconf                 # Atajos, dock, extensiones (dumps dconf)
├── ulauncher/                    # Launcher + temas Liquid Glass (Linux)
├── git/                          # gitignore global + plantilla para proyectos (ginit)
├── yazi/ · fontconfig/ · openlogi/          # Configs puntuales
├── .claude/                      # Config de Claude Code + reglas de agentes IA
│                                 #   (CLAUDE.md → symlink también como AGENTS.md
│                                 #    de Codex y opencode)
└── docs/                         # Esta documentación
```
