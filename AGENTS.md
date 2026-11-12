# AGENTS.md

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

**Sin backups:** bootstrap y uninstall no respaldan ni restauran nada. El repo
(y el vault) es el historial: un archivo o carpeta real en el destino de un
symlink se reemplaza sin copia previa. No reintroducir `BACKUP_DIR` ni
`~/.local/backups/`.

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
- **Contextos:** `personal`, `work` y `cei_walle` son a la vez las carpetas
  bajo `~/repositorios/` y los sufijos de `~/.gitconfig-<sufijo>`; están fijos
  en bootstrap, uninstall y tests.
- **`~/.env` en el vault:** opcional, cifrado con age en `env/env.age` (lo
  escribe `env-save`, paridad bash/zsh/pwsh). Bootstrap y `vault-sync` lo
  restauran **solo si falta** — nunca pisan un `~/.env` local.
- **Globs de `hasconfig`** (wildmatch): `*` no cruza `/` y `**` solo es especial
  delimitado por `/`. Para URLs scp (`user/repo`) usar `:*/*` y `:**/**` —
  nunca `:**` pelado (no matchea).

## Obsidian (`~/obsidian`)

Opcional (grupo `apps`/`extras`). La **bóveda es un repo privado aparte**, nunca
parte de este repo (son notas personales). El bootstrap solo la clona en
`~/obsidian` si `~/.env` define `OBSIDIAN_REPO` (URL con alias SSH) y la
carpeta no existe. Dentro de la bóveda, `.gitignore` excluye `workspace.json` y el `data.json` del plugin
Jira (cuenta); la sincronización entre PCs la hace el plugin Obsidian Git.

## Reglas por área

Lo que solo importa en un área vive en `.claude/rules/`, un archivo por área.
Claude Code carga cada uno solo al tocar los archivos de su `paths:`; con otro
agente (Codex, opencode), **leer el archivo del área antes de tocarla**. Una
regla nueva de área va a su archivo, no acá.

| Área | Reglas | Aplica a |
|---|---|---|
| `install.ps1` (ASCII puro, PowerShell 5.1) | [`.claude/rules/install-ps1.md`](.claude/rules/install-ps1.md) | `install.ps1` |
| dconf: Ptyxis y GNOME | [`.claude/rules/gnome-dconf.md`](.claude/rules/gnome-dconf.md) | `gnome/**`, `terminal/**` |
| Ulauncher / Flow Launcher | [`.claude/rules/launcher.md`](.claude/rules/launcher.md) | `ulauncher/**`, `flowlauncher/**`, `gnome/media-keys.dconf` |
| Claude Code, plugins y skills | [`.claude/rules/claude-code.md`](.claude/rules/claude-code.md) | `.claude/**`, `.claude-plugin/**`, `claude-skills/**`, `docs/agent-skills-catalogo.md`, `docs/skills-radar.md`, `AGENTS.md`, `CLAUDE.md` |
| Emojis a color en Chrome | [`.claude/rules/fontconfig.md`](.claude/rules/fontconfig.md) | `fontconfig/**` |
| Override del `.desktop` de Chrome | [`.claude/rules/chrome-predeterminado.md`](.claude/rules/chrome-predeterminado.md) | `bootstrap.sh`, `uninstall.sh` |
| Historial con fzf (flecha ↑) | [`.claude/rules/historial.md`](.claude/rules/historial.md) | `shell/**` |
| Flameshot y captura nativa | [`.claude/rules/capturas.md`](.claude/rules/capturas.md) | `gnome/**` |
| yazi y la función `y` | [`.claude/rules/yazi.md`](.claude/rules/yazi.md) | `yazi/**`, `shell/**` |
| Neovim | [`.claude/rules/neovim.md`](.claude/rules/neovim.md) | `nvim/**` |
| Firefox (perfiles, `user.js`) | [`.claude/rules/firefox.md`](.claude/rules/firefox.md) | `firefox/**` |

## Verificación

- Sintaxis: `bash -n shell/bashrc`, `zsh -n shell/zshrc`.
- `bash test-bootstrap.sh` tras cambios en shells/symlinks (verifica paridad).
- Tras tocar `nvim/`: prueba headless contra un fixture (ver la sección de
  Neovim) y `:checkhealth` para las dependencias externas.
