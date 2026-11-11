---
paths:
  - ".claude/**"
  - ".claude-plugin/**"
  - "claude-skills/**"
  - "docs/agent-skills-catalogo.md"
  - "docs/skills-radar.md"
  - "AGENTS.md"
  - "CLAUDE.md"
---

# Claude Code (`.claude/`)

Versiona la config de Claude Code para portabilidad. Ojo con el manejo distinto:

- `.claude/CLAUDE.md` → **fuente única de reglas para TODOS los agentes de IA**:
  symlinkeado a `~/.claude/CLAUDE.md` (Claude Code) y, si están instalados, a
  `~/.codex/AGENTS.md` (Codex) y `~/.config/opencode/AGENTS.md` (opencode).
  Editar ese archivo cambia las reglas de los tres. Claude Code ≥v2.1.277 lee
  `AGENTS.md` nativamente, pero solo cuando NO hay ningún `CLAUDE.md` en el
  working dir o arriba — con nuestro symlink siempre hay uno, así que el
  mecanismo real sigue siendo el symlink, no la lectura nativa. Para los
  **proyectos** sí se usa la lectura nativa: verificado que un `AGENTS.md` de
  proyecto se lee aunque exista el `CLAUDE.md` global.
- `AGENTS.md` (raíz) → **reglas de este repo**, para cualquier agente. El
  `CLAUDE.md` de la raíz es una sola línea, `@AGENTS.md`: hace falta porque
  `.claude/CLAUDE.md` cuenta como `CLAUDE.md` del proyecto y, sin el import,
  Claude Code ignoraría el `AGENTS.md`. No agregarle contenido.
- `.claude/agents/` → **symlink de carpeta** a `~/.claude/agents/`: subagentes
  propios (explorador, builder, revisor, devops, seguridad). Agregar uno es
  crear un archivo. Molde, equipo y formato en otras herramientas:
  [`docs/molde-agente.md`](../../docs/molde-agente.md); flujo de uso:
  [`docs/playbook-desarrollo.md`](../../docs/playbook-desarrollo.md); plantilla del
  `AGENTS.md` de cada proyecto:
  [`docs/plantilla-agents-proyecto.md`](../../docs/plantilla-agents-proyecto.md).
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
  [`docs/notas-tecnicas.md`](../../docs/notas-tecnicas.md#cd-mueve-el-cwd-no-el-proyecto-de-la-sesión)).
- `settings.local.json` → **per-máquina** (permisos con rutas absolutas que
  difieren Linux/Windows). **No está trackeado** (lo cubre el `.gitignore`).
- `keybindings.json` → **NO se versiona a propósito**: se usan los defaults de
  Claude Code en ambas máquinas. `Alt+Enter` en Ptyxis ya manda los mismos
  bytes que `shift+enter` en Windows Terminal, sin configurar nada — y
  `shift+enter` real es imposible en Ptyxis/VTE (limitación del terminal, no
  nuestra). Detalle: [`docs/notas-tecnicas.md`](../../docs/notas-tecnicas.md#keybindingsjson-por-qué-no-se-versiona-y-por-qué-shiftenter-es-imposible-en-ptyxis).
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
  completo: [`docs/notas-tecnicas.md`](../../docs/notas-tecnicas.md#instalar-plugins-en-windows-lo-bloquea-el-ssl-de-git-no-claude-code).
