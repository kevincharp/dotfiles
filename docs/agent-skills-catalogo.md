# Catálogo de Agent Skills

Inventario de las skills y plugins que tenemos habilitados en Claude Code, y
de dónde sale cada uno. No se llama "catálogo de skills de Claude" a propósito:
**Agent Skills es un formato abierto** (spec en
[agentskills.io/specification](https://agentskills.io/specification),
mantenido por la org `agentskills`, no por Anthropic en solitario) — un
`SKILL.md` con frontmatter + markdown que en teoría puede leer cualquier
agente que implemente la spec, no solo Claude.

Lo que **sí es específico de Claude Code** es la capa de distribución que
usamos para instalar casi todo esto: `.claude-plugin/marketplace.json`,
`enabledPlugins` en `settings.json`, el comando `/plugin`. Codex y opencode
(que comparten nuestro `CLAUDE.md`/`AGENTS.md` vía symlink — ver
[arquitectura](arquitectura.md)) no tienen ese sistema de marketplace. Si algún
día se quiere reusar una skill **propia** (las de `claude-skills/`) desde otro
agente, hay que apuntar directo al `SKILL.md`, no al mecanismo de `/plugin`.

## Cómo viaja esto entre máquinas

`settings.json` es symlink versionado (`.claude/settings.json` en este repo),
así que `enabledPlugins` y `extraKnownMarketplaces` llegan solos con un
`git pull`. El binario clona el contenido a `~/.claude/plugins/` solo, eso no
se versiona. Detalle del mecanismo completo:
[`.claude/rules/claude-code.md`](../.claude/rules/claude-code.md).

## Globales (activos en todo proyecto)

Solo lo que sirve en cualquier proyecto; el resto se instala donde haga falta.
Costo fijo medido con `claude plugin details`: ~2.600 tokens por sesión (eran
~10.100 con los 22 plugins en alcance user).

| Plugin | Skill(s) | Para qué sirve | Origen |
|---|---|---|---|
| `security-guidance` | *(hooks, sin skills)* | Revisión de seguridad automática mientras se trabaja: regex en cada edición (sin modelo), revisión del diff al final de cada turno y revisión agéntica en cada `git commit`/`push` de Claude. No bloquea: pasa los hallazgos a Claude. Consume uso (Python 3.10+). Capas apagables con `ENABLE_PATTERN_RULES=0`, `ENABLE_STOP_REVIEW=0`, `ENABLE_COMMIT_REVIEW=0` o `SECURITY_GUIDANCE_DISABLE=1` | Oficial (`claude-plugins-official`) |
| `claude-security` | `claude-security` | Escaneo multiagente de vulnerabilidades del repo o de un diff/rama/PR (`/claude-security`), con verificación independiente y parches sugeridos que nunca se aplican solos; reporte MD/JSONL/SARIF. Pide plan pago o API y consume uso (Python 3.9+) | Oficial (`claude-plugins-official`) |
| `superpowers` | `superpowers` | Brainstorming y desarrollo dirigido por subagentes | Oficial |
| `code-review` | `code-review` | Revisión automatizada de PRs con specs múltiples | Oficial |
| `mattpocock-skills` | **engineering:** `ask-matt`, `grill-with-docs`, `triage`, `improve-codebase-architecture`, `setup-matt-pocock-skills`, `to-spec`, `to-tickets`, `implement`, `wayfinder`, `prototype`, `diagnosing-bugs`, `research`, `tdd`, `domain-modeling`, `codebase-design`, `code-review`, `resolving-merge-conflicts`, `wizard` · **productivity:** `grill-me`, `handoff`, `teach`, `to-questionnaire`, `wait-what`, `grilling`, `writing-for-agents` · **misc (sin documentar en el README, no explorado):** `git-guardrails-claude-code`, `migrate-to-shoehorn`, `scaffold-exercises`, `setup-pre-commit` | Disciplina de ingeniería real: alineación por "grilling" antes de codear, TDD, diagnóstico de bugs, domain modeling, flujo spec→tickets→implement contra un issue tracker, review por Standards+Spec en paralelo. Requiere correr `/setup-matt-pocock-skills` una vez por repo | Oficial (`claude-plugins-official`, autor Matt Pocock/aihero.dev) |
| `watch` | `watch` (`/watch`) | Deja que Claude "mire" un video: descarga (yt-dlp), extrae frames (ffmpeg), transcribe y entrega todo al contexto | Tercero (`bradautomates/claude-video`, MIT), marketplace propio `claude-video` con **`autoUpdate` desactivado** |
| `bibliotecario` | `bibliotecario` (`/bibliotecario`) | Recomienda plugins, skills y repos con estrella para el proyecto actual (tres fuentes: marketplaces, radar y listas de GitHub) e instala por proyecto tras confirmación | **Propia** (`claude-skills/bibliotecario`). Pendiente de instalar en alcance user: requiere push |

## Biblioteca (se instalan por proyecto)

No están en `enabledPlugins`: su marketplace sigue registrado, así que se
instalan en el proyecto que los necesite con
`claude plugin install <plugin>@<marketplace> --scope local` (solo para mí) o
`--scope project` (queda en el `.claude/settings.json` del repo).

| Plugin | Skill(s) | Para qué sirve | Origen |
|---|---|---|---|
| `claude-code-setup` | `claude-automation-recommender` | Analiza el código y recomienda automatizaciones de Claude Code (hooks, subagents, skills, plugins, MCP) | Oficial (`claude-plugins-official`) |
| `cyber-neo` | `cyber-neo` | Auditoría de seguridad read-only (SAST, SCA, secretos, OWASP/CWE) | Tercero, envuelto en **este repo** (`kevincharp-dotfiles`) |
| `security-audit-skill` | `security-audit` | Auditoría de seguridad adversarial en 6 fases con sub-agentes aislados (recon → hunting con cobertura → validación adversarial → salida estructurada → re-verificación independiente → reporte). Ver nota de solapamiento con `cyber-neo` abajo | Tercero, envuelto en **este repo** (`kevincharp-dotfiles`) |
| `all-deploy` | `all-deploy` | Deploy a Vercel/Railway/Docker+VPS/cloudflared con auditoría previa y flujo preview→prod | Tercero, envuelto en **este repo** |
| `ui-ux-pro-max` | `banner-design`, `brand`, `design`, `design-system`, `slides`, `ui-styling`, `ui-ux-pro-max` | Diseño UI/UX: tokens, paletas, tipografías, componentes shadcn/Tailwind, banners, slides, brand voice | Tercero (`ui-ux-pro-max-skill`) |
| `rust-analyzer-lsp` | *(LSP, no es skill con `/`)* | Autocompletado/análisis de código Rust en vivo | Oficial |
| `example-skills` | `algorithmic-art`, `brand-guidelines`, `canvas-design`, `doc-coauthoring`, `frontend-design`, `internal-comms`, `mcp-builder`, `skill-creator`, `slack-gif-creator`, `theme-factory`, `web-artifacts-builder`, `webapp-testing` | Bundle de 12 skills de ejemplo de Anthropic — diseño visual, arte generativo, co-escritura de docs, comms internas, builder de MCP, testing con Playwright, artifacts, temas, GIFs de Slack. Se listan con el prefijo `example-skills:<nombre>` | Oficial (`anthropic-agent-skills`) |
| `diagram-design` | `diagram-design` | 40 tipos de diagramas técnicos (arquitectura, ER, UML, flowcharts, Gantt, Sankey…) como HTML+SVG autocontenido; redibuja `.drawio`/Mermaid/Excalidraw | Tercero (`diagram-design`, marketplace propio) |
| `taste-skill` | `design-taste-frontend`, `redesign-existing-projects`, `image-to-code`, `brandkit`, `brutalist-skill`, `minimalist-skill`, `soft-skill`, `stitch-skill`, `gpt-tasteskill`, `imagegen-frontend-web/mobile`, `output-skill`, `taste-skill-v1` | Guía anti-genérico por variante de estilo + dos capacidades únicas: `image-to-code` (mockup→código) y `redesign-skill` (mejorar un proyecto ya existente sin romperlo) | Tercero (`taste-skill`, marketplace propio) |
| `cloudflare` | `agents-sdk`, `cloudflare-email-service`, `cloudflare-one-migrations`, `cloudflare-one`, `cloudflare`, `durable-objects`, `nextjs-on-cloudflare`, `sandbox-migrate-to-next`, `sandbox-next`, `sandbox-stable`, `turnstile-spin`, `web-perf`, `workers-best-practices`, `wrangler` | Guía oficial de la plataforma Cloudflare (Workers, Durable Objects, Agents SDK, Wrangler, Cloudflare One, etc.). También registra el MCP server remoto `mcp.cloudflare.com/mcp` — la primera vez que se use pide conectar la cuenta real de Cloudflare | Tercero (`cloudflare`, marketplace propio) |

`landing-team`, `landing-cro` y `landing-a-secciones` se eliminaron del repo
(2026-11-11): el equipo de landing duplicaba a los agentes base, y las otras dos
eran de dropshipping/Shopify, que ya no se hace. Quedan en el historial de git.

`premium-website-generator` también se eliminó (2026-11-11): imponía su propio
proceso (decisiones en silencio, Hostinger por FTP, librerías sin preguntar) y
chocaba con el flujo de tickets. Para diseño web, instalar `taste-skill` o
`example-skills` (`frontend-design`) en el proyecto. Sus reglas de robustez y su
`verify_project.py` se pueden rescatar del historial si hacen falta.

`thermos` también se eliminó (2026-11-11): su doble revisión ya la cubren
`/code-review`, `/simplify` y los agentes `revisor` y `seguridad`; sus dos
criterios propios (archivos de más de 1000 líneas, cambios del entorno local)
pasaron al checklist del `revisor`. El original sigue en `cursor/plugins`.

`the-architect` se desinstaló y se quitó su marketplace (`soyenriquerocha`):
se solapa con `superpowers` y la experiencia de uso fue mala. Sigue en las
estrellas de GitHub (`Hainrixz/the-architect`).

### Notas sobre `watch` (claude-video)

- **Auditado antes de sumarlo** (v0.3.2, commit `03ceb42`, solo lectura): sin
  comportamiento malicioso, telemetría ni TLS debilitado; los riesgos son de
  configuración. Un solo mantenedor y sin PRs mergeados, por eso **`autoUpdate:
  false`** (excepción a los demás marketplaces) y hay que re-auditar al subir de
  versión. No se verificó si el marketplace admite fijar `ref`/sha.
- **Lo único que corre solo** es un hook `SessionStart` (`check-setup.sh`, 5 s)
  que solo avisa si falta configuración. No instala nada al registrarse.
- **Qué sale de la máquina:** con una clave Gemini/Groq/OpenAI en el entorno o en
  `~/.config/watch/.env`, un `/watch` normal sube video o audio a esa API. Para
  mantenerlo local: `WATCH_ENGINE=local` y `WATCH_WHISPER_BACKEND=whisperx|none`
  en ese `.env`, y **no exportar claves** en bashrc/zshrc/`profile.ps1`.
- **Inyección por contenido:** título, subtítulos y transcripción de un video
  llegan al contexto y el skill declara `allowed-tools: Bash`. Usarlo solo con
  videos de confianza y no pegar claves en el chat.
- **Requisitos:** `ffmpeg` (ya está, `ffmpeg-free` 9.0.2: rechaza `-vsync` pero el
  plugin detecta y usa `-fps_mode`), `yt-dlp` (`sudo dnf install yt-dlp`) y
  `python3`. En Windows no se probó.

### Notas sobre `mattpocock-skills`

- **Dos filosofías de instalación, no mezclar.** El propio README lo advierte:
  el plugin de Claude Code (lo que instalamos, `/plugin install
  mattpocock-skills`) es un bundle gestionado de solo lectura que se
  actualiza solo. La alternativa (`npx skills@latest add mattpocock/skills`)
  copia archivos editables **dentro de un proyecto puntual**, sin
  auto-update, con selección skill por skill — es otro modelo de
  distribución, no encaja con "el stack global" que veníamos armando en
  `settings.json`. Instalar las dos deja cada skill duplicada.
- **Solapamientos reales a tener en cuenta:**
  - `code-review` (acá adentro) vs `code-review@claude-plugins-official`
    (ya instalado): mismo nombre, ejes distintos (Standards+fidelidad-al-spec
    en paralelo vs. review genérico de PR). Convive como `code-review` y
    `mattpocock-skills:code-review`.
  - `grill-me`/`grilling` es casi seguro lo que la skill pendiente
    **"handshake"** (`flowstate.help`, ver memoria de pendientes) esperaba
    como paso siguiente — su propio doc decía literalmente "run `/grill-me`
    on the doc". Con esto instalado, `handshake` pierde prioridad.
  - `handoff` hace lo mismo que la memoria nativa de Claude Code que ya
    usamos y que `LOOP/CURRENT.md` del "DEF Starter Kit" (pendiente):
    comprimir la sesión en un doc para continuar después.
- **Requiere un paso de setup POR REPO**, no es plug-and-play ni global:
  correr `/setup-matt-pocock-skills` una vez por repo (pregunta issue
  tracker, labels de triage, dónde guardar docs) antes de que el resto de
  las skills de `engineering/` tengan dónde escribir. Le agrega una sección
  `## Agent skills` a `CLAUDE.md`/`AGENTS.md` **del repo donde se corre** y
  crea `docs/agents/*.md` ahí — no es algo que se configure una vez para
  todas las máquinas vía `settings.json`.
  **Decisión (2026-09-16): NO correrlo en dotfiles.** El plan original era
  para "el desarrollo web que quiero arrancar" (un proyecto que todavía no
  existe), no para este repo. Queda pendiente correrlo el día que ese
  proyecto exista — no confundir con "instalar el plugin", que ya está hecho
  y es global.

## Notas sobre `security-audit-skill` vs `cyber-neo`

**Decisión (2026-09-22): convivir, no reemplazar.** Se evaluaron ambos y son
complementarios, no duplicados: `cyber-neo` es una pasada rápida read-only
(SAST/SCA/secretos/config contra OWASP-CWE, un solo agente); `security-audit-skill`
es una auditoría adversarial mucho más cara — orquesta sub-agentes aislados que se
verifican entre sí (el que encuentra un hallazgo nunca es el que lo valida) y
exige un **sandbox sin red externa** para ejecutar builds/tests/fuzzers del
target real. Para un pase rápido de rutina, `cyber-neo`; para una auditoría
seria antes de exponer algo a producción, `security-audit-skill`.

No trae `marketplace.json` propio (`skills/security-audit/SKILL.md` suelto en el
repo), por eso está envuelto en el `marketplace.json` de este repo igual que
`cyber-neo`/`all-deploy` — mismo mecanismo, mismo costo: **hay que pushear antes
de que `claude plugin install security-audit-skill@kevincharp-dotfiles -y` (o el
`marketplace update`) resuelva**, porque lee el remoto, no el working tree.

## Mecanismos de invocación (no todas las skills se llaman igual)

Confirmado leyendo los manifests instalados, no solo los README:

- **Auto por descripción** (la mayoría): Claude lee `name`+`description` de
  todas las skills habilitadas todo el tiempo y carga la que matchea, sin que
  la nombres. Así funcionan `frontend-design`, `ui-ux-pro-max`,
  `diagram-design` y las 12 sub-skills de `taste-skill`.
- **Slash command explícito**: además de lo anterior, algunas declaran
  `user-invocable: true` + `argument-hint` en el frontmatter y quedan
  disponibles como `/nombre <verbo> [target]`. Hoy ninguna de las instaladas
  lo hace (lo hacía `impeccable`, desinstalado: ver abajo).
- **Hook automático** (`hooks/hooks.json` del plugin, no el frontmatter de la
  skill): corre solo, disparado por un evento del sistema, no por relevancia
  de la tarea. Hoy no hay ninguno. `impeccable` lo traía (`PostToolUse` tras
  cualquier `Edit|Write` y `Stop` al terminar cada respuesta), global en todos
  los proyectos. Se **desinstaló** porque su motor se baja de GitHub Releases y
  el proxy corporativo lo bloquea (`CRYPT_E_NO_REVOCATION_CHECK`): el hook
  fallaba en cada turno sin hacer su trabajo. Para volver:
  `/plugin marketplace add pbakaus/impeccable` + `/plugin install
  impeccable@impeccable`, y resolver antes la descarga del motor (bajarlo a
  mano y apuntar `IMPECCABLE_BIN`, o `IMPECCABLE_HOME`).

## Desinstalados a propósito: `frontend-design` y `skill-creator` standalone

`example-skills@anthropic-agent-skills` (el bundle de ejemplos oficiales de
Anthropic) trae 12 skills, y **2 duplicaban** exactamente el contenido de
plugins standalone que se habían agregado por separado (`frontend-design`,
`skill-creator`). Claude Code no tiene forma de sacar una sola skill de
adentro de un plugin-bundle (confirmado contra la doc oficial: `enabledPlugins`
es todo/nada por plugin completo), así que se decidió al revés de lo que se
probó primero: en vez de apagar el bundle entero (perdiendo las otras 10
skills sin reemplazo en el marketplace oficial), se dejó `example-skills`
prendido y se **desinstalaron los 2 plugins standalone**
(`claude plugin uninstall "frontend-design@claude-plugins-official"` /
`... "skill-creator@claude-plugins-official"`) — no solo deshabilitados: ya no
figuran en `enabledPlugins` en absoluto.

Costo aceptado: esas dos ahora solo se listan con el prefijo
`example-skills:frontend-design` / `example-skills:skill-creator`, no peladas.
Si en algún momento se prioriza el nombre limpio por sobre las 10 skills extra,
es al revés: `claude plugin disable "example-skills@anthropic-agent-skills"` +
`claude plugin install "frontend-design@claude-plugins-official" -y` +
`claude plugin install "skill-creator@claude-plugins-official" -y`.

## No son plugins: built-ins del CLI

Estos vienen siempre con Claude Code, no dependen de ningún plugin ni de
`enabledPlugins`: `init`, `security-review`, `run`, `loop`, `update-config`,
`keybindings-help`, `workflow-authoring`, `fewer-permission-prompts`,
`dataviz`, `claude-api`.
