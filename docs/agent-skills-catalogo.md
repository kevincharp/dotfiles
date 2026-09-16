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
se versiona. Detalle del mecanismo completo: sección "Claude Code (`.claude/`)"
del [`CLAUDE.md`](../CLAUDE.md) de este repo.

## Habilitados hoy

| Plugin | Skill(s) | Para qué sirve | Origen |
|---|---|---|---|
| `claude-code-setup` | `claude-automation-recommender` | Analiza el código y recomienda automatizaciones de Claude Code (hooks, subagents, skills, plugins, MCP) | Oficial (`claude-plugins-official`) |
| `the-architect` | `architect`, `architect-quick`, `architect-brownfield`, `architect-refresh`, `architect-audit`, `architect-next` | Entrevista, diseña y genera bundles de construcción para proyectos nuevos o cambios sobre un repo existente, con criterios de aceptación validados | Tercero (`soyenriquerocha`) |
| `cyber-neo` | `cyber-neo` | Auditoría de seguridad read-only (SAST, SCA, secretos, OWASP/CWE) | Tercero, envuelto en **este repo** (`kevincharp-dotfiles`) |
| `all-deploy` | `all-deploy` | Deploy a Vercel/Railway/Docker+VPS/cloudflared con auditoría previa y flujo preview→prod | Tercero, envuelto en **este repo** |
| `ui-ux-pro-max` | `banner-design`, `brand`, `design`, `design-system`, `slides`, `ui-styling`, `ui-ux-pro-max` | Diseño UI/UX: tokens, paletas, tipografías, componentes shadcn/Tailwind, banners, slides, brand voice | Tercero (`ui-ux-pro-max-skill`) |
| `rust-analyzer-lsp` | *(LSP, no es skill con `/`)* | Autocompletado/análisis de código Rust en vivo | Oficial |
| `premium-website-generator` | `premium-website-generator` | Genera sitios estáticos premium (HTML/CSS/JS vanilla) listos para Hostinger | **Propia** (`claude-skills/premium-website-generator`) |
| `superpowers` | `superpowers` | Brainstorming y desarrollo dirigido por subagentes | Oficial |
| `code-review` | `code-review` | Revisión automatizada de PRs con specs múltiples | Oficial |
| `example-skills` | `algorithmic-art`, `brand-guidelines`, `canvas-design`, `doc-coauthoring`, `frontend-design`, `internal-comms`, `mcp-builder`, `skill-creator`, `slack-gif-creator`, `theme-factory`, `web-artifacts-builder`, `webapp-testing` | Bundle de 12 skills de ejemplo de Anthropic — diseño visual, arte generativo, co-escritura de docs, comms internas, builder de MCP, testing con Playwright, artifacts, temas, GIFs de Slack. Se listan con el prefijo `example-skills:<nombre>` | Oficial (`anthropic-agent-skills`) |
| `landing-cro` | `landing-cro` | Genera una landing de venta directa (HTML autocontenido, CRO/conversión, mobile-first) a partir de una URL de referencia o de marketplace (AliExpress/Amazon/Temu/Alibaba) | **Propia** (`claude-skills/landing-cro`) |
| `landing-a-secciones` | `landing-a-secciones` | Convierte un HTML de landing (p. ej. el de `landing-cro`) en secciones `.liquid` del tema Dawn de Shopify | **Propia** (`claude-skills/landing-a-secciones`) |
| `diagram-design` | `diagram-design` | 40 tipos de diagramas técnicos (arquitectura, ER, UML, flowcharts, Gantt, Sankey…) como HTML+SVG autocontenido; redibuja `.drawio`/Mermaid/Excalidraw | Tercero (`diagram-design`, marketplace propio) |
| `taste-skill` | `design-taste-frontend`, `redesign-existing-projects`, `image-to-code`, `brandkit`, `brutalist-skill`, `minimalist-skill`, `soft-skill`, `stitch-skill`, `gpt-tasteskill`, `imagegen-frontend-web/mobile`, `output-skill`, `taste-skill-v1` | Guía anti-genérico por variante de estilo + dos capacidades únicas: `image-to-code` (mockup→código) y `redesign-skill` (mejorar un proyecto ya existente sin romperlo) | Tercero (`taste-skill`, marketplace propio) |
| `impeccable` | `impeccable` (24 comandos: `polish`, `audit`, `critique`, `animate`…) | Fluidez de diseño frontend: detección de anti-patrones + comandos de refinamiento. Ver nota de hook abajo | Tercero (`impeccable`, marketplace propio) |
| `mattpocock-skills` | **engineering:** `ask-matt`, `grill-with-docs`, `triage`, `improve-codebase-architecture`, `setup-matt-pocock-skills`, `to-spec`, `to-tickets`, `implement`, `wayfinder`, `prototype`, `diagnosing-bugs`, `research`, `tdd`, `domain-modeling`, `codebase-design`, `code-review`, `resolving-merge-conflicts`, `wizard` · **productivity:** `grill-me`, `handoff`, `teach`, `to-questionnaire`, `wait-what`, `grilling`, `writing-for-agents` · **misc (sin documentar en el README, no explorado):** `git-guardrails-claude-code`, `migrate-to-shoehorn`, `scaffold-exercises`, `setup-pre-commit` | Disciplina de ingeniería real: alineación por "grilling" antes de codear, TDD, diagnóstico de bugs, domain modeling, flujo spec→tickets→implement contra un issue tracker, review por Standards+Spec en paralelo. Requiere correr `/setup-matt-pocock-skills` una vez por repo | Oficial (`claude-plugins-official`, autor Matt Pocock/aihero.dev) |

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

## Vendorizado, pendiente de push + install: `thermos`

`thermos` ya está en `claude-skills/thermos/` y registrado en
`.claude-plugin/marketplace.json`, pero **todavía no aparece en la tabla de
arriba** porque `claude plugin install "thermos@kevincharp-dotfiles"` falla
hasta que esto se pushee — confirmado en vivo: el marketplace
`kevincharp-dotfiles` resuelve contra el `marketplace.json` **remoto**, no el
working tree (mismo comportamiento que ya documenta este `CLAUDE.md` sobre
este marketplace). Después del push, falta:

```
claude plugin install "thermos@kevincharp-dotfiles" -y
```

Qué trae: 3 skills (`thermo-nuclear-review` = audit de bugs/breaking changes/
seguridad/devex/feature-gate leaks acotado al diff;
`thermo-nuclear-code-quality-review` = mantenibilidad/estructura, la misma
rúbrica que la skill homónima de `code-review`-adyacentes; `thermos` =
orquestador) + 2 agentes propios
(`thermos:thermo-nuclear-review-subagent`,
`thermos:thermo-nuclear-code-quality-review-subagent`) para correr las dos
revisiones en paralelo. **Adaptado, no vendorizado tal cual:** el original de
Cursor (`github.com/cursor/plugins/tree/main/thermos`, MIT) orquesta con
`subagent_type` propios de Cursor (`shell`, `explore`,
`thermo-nuclear-*-subagent`) que no existen en Claude Code — se reescribió el
`SKILL.md` de `thermos` y se convirtió el frontmatter de los 2 agentes al
formato de Claude Code (`name`/`description`/`tools`/`model`) para que la
orquestación funcione de verdad, no solo el contenido de las 2 skills base
(esas sí son copia literal). Las 3 skills traen `disable-model-invocation:
true` en el frontmatter (campo de Cursor, fuera del spec base de
agentskills.io — no confirmado si Claude Code lo respeta), así que en teoría
no se autodisparan por descripción, solo por invocación explícita.

## Mecanismos de invocación (no todas las skills se llaman igual)

Confirmado leyendo los manifests instalados, no solo los README:

- **Auto por descripción** (la mayoría): Claude lee `name`+`description` de
  todas las skills habilitadas todo el tiempo y carga la que matchea, sin que
  la nombres. Así funcionan `frontend-design`, `ui-ux-pro-max`,
  `diagram-design` y las 12 sub-skills de `taste-skill`.
- **Slash command explícito**: además de lo anterior, algunas declaran
  `user-invocable: true` + `argument-hint` en el frontmatter y quedan
  disponibles como `/nombre <verbo> [target]`. Hoy solo `impeccable` lo hace
  (`/impeccable polish`, `/impeccable audit`, etc., 24 comandos).
- **Hook automático** (`hooks/hooks.json` del plugin, no el frontmatter de la
  skill): corre solo, disparado por un evento del sistema, no por relevancia
  de la tarea. Solo `impeccable` trae esto: `PostToolUse` con matcher
  `Edit|Write` (dispara su script tras **cualquier** edición de archivo, no
  solo de UI, timeout 5s) y `Stop` (pase profundo al terminar la respuesta,
  timeout 30s). Como `impeccable` está habilitado en el `settings.json`
  **global**, este hook corre en *todos* los proyectos donde se use Claude
  Code en cualquier máquina, no solo en trabajo de frontend — decisión
  consciente: se evaluó escoparlo a un proyecto puntual y se optó por dejarlo
  global.

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
