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
| `frontend-design` | `frontend-design` | Guía de diseño visual distintivo para UI | Oficial |
| `superpowers` | `superpowers` | Brainstorming y desarrollo dirigido por subagentes | Oficial |
| `code-review` | `code-review` | Revisión automatizada de PRs con specs múltiples | Oficial |
| `skill-creator` | `skill-creator` | Crear, mejorar y medir skills nuevas o existentes | Oficial |
| `landing-cro` | `landing-cro` | Genera una landing de venta directa (HTML autocontenido, CRO/conversión, mobile-first) a partir de una URL de referencia o de marketplace (AliExpress/Amazon/Temu/Alibaba) | **Propia** (`claude-skills/landing-cro`) |
| `landing-a-secciones` | `landing-a-secciones` | Convierte un HTML de landing (p. ej. el de `landing-cro`) en secciones `.liquid` del tema Dawn de Shopify | **Propia** (`claude-skills/landing-a-secciones`) |
| `diagram-design` | `diagram-design` | 40 tipos de diagramas técnicos (arquitectura, ER, UML, flowcharts, Gantt, Sankey…) como HTML+SVG autocontenido; redibuja `.drawio`/Mermaid/Excalidraw | Tercero (`diagram-design`, marketplace propio) |
| `taste-skill` | `design-taste-frontend`, `redesign-existing-projects`, `image-to-code`, `brandkit`, `brutalist-skill`, `minimalist-skill`, `soft-skill`, `stitch-skill`, `gpt-tasteskill`, `imagegen-frontend-web/mobile`, `output-skill`, `taste-skill-v1` | Guía anti-genérico por variante de estilo + dos capacidades únicas: `image-to-code` (mockup→código) y `redesign-skill` (mejorar un proyecto ya existente sin romperlo) | Tercero (`taste-skill`, marketplace propio) |
| `impeccable` | `impeccable` (24 comandos: `polish`, `audit`, `critique`, `animate`…) | Fluidez de diseño frontend: detección de anti-patrones + comandos de refinamiento. Ver nota de hook abajo | Tercero (`impeccable`, marketplace propio) |

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

## Deshabilitado a propósito: `example-skills`

`example-skills@anthropic-agent-skills` (el bundle de ejemplos oficiales de
Anthropic) traía 12 skills, pero **2 duplicaban** exactamente el contenido de
plugins standalone que ya teníamos (`frontend-design`, `skill-creator`) — se
listaban con el prefijo `example-skills:` en vez de pelado. Claude Code no
tiene forma de deshabilitar una sola skill dentro de un plugin-bundle
(confirmado contra la doc oficial: `enabledPlugins` es todo/nada por plugin
completo), así que se deshabilitó el bundle entero y se perdieron sin
reemplazo standalone en el marketplace oficial:

`algorithmic-art`, `brand-guidelines`, `canvas-design`, `doc-coauthoring`,
`internal-comms`, `mcp-builder`, `slack-gif-creator`, `theme-factory`,
`web-artifacts-builder`, `webapp-testing`.

De estas, las que más podrían servir a este uso son `webapp-testing`
(Playwright para probar lo que se despliega con `all-deploy`) y `mcp-builder`.
Si hacen falta: `claude plugin enable "example-skills@anthropic-agent-skills"`.

## No son plugins: built-ins del CLI

Estos vienen siempre con Claude Code, no dependen de ningún plugin ni de
`enabledPlugins`: `init`, `security-review`, `run`, `loop`, `update-config`,
`keybindings-help`, `workflow-authoring`, `fewer-permission-prompts`,
`dataviz`, `claude-api`.
