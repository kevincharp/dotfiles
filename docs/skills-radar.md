# Radar de skills/plugins de IA

Catálogo de **todo** lo que se evaluó alguna vez para el stack de Claude Code
(y afines: Codex/opencode donde aplique), esté instalado o no. Objetivo:
antes de sumar una skill nueva, mirar acá primero — por categoría — para no
duplicar algo que ya se cubre o re-investigar algo que ya se descartó.

Este archivo es la fuente de verdad para "qué existe y en qué quedó" —
**versionado, viaja con el repo**. No confundir con
[`agent-skills-catalogo.md`](agent-skills-catalogo.md): ese es el detalle
técnico profundo de lo que está **instalado hoy** (mecanismos de invocación,
hooks, notas de solapamiento fino). Este archivo es más amplio pero más
superficial: cubre también lo evaluado-y-descartado y lo pendiente de mirar.

**Estado:** ✅ Instalada · 🔍 Evaluada, no instalada · 📋 Pendiente de investigar

**Pendiente de resolver (flujo, no herramienta):** cómo relevar los propios
repos de GitHub con ⭐ (starred) para volcarlos a esta tabla de forma
sistemática, en vez de ir agregando uno por uno a mano. Sin decidir todavía.

## Frontend / Diseño

| Nombre | Funcionalidad | Caso de uso | Estado | Repo |
|---|---|---|---|---|
| `ui-ux-pro-max` | Tokens, paletas, componentes shadcn, banners, slides | Necesitás una base de datos de diseño buscable | ✅ | `github.com/nextlevelbuilder/ui-ux-pro-max-skill` |
| `taste-skill` | Anti-genérico por estilo + genera `DESIGN.md` + image-to-code | Necesitás un `DESIGN.md` inventado a medida | ✅ | `github.com/Leonxlnx/taste-skill` |
| `impeccable` | Auditor/pulidor de frontend, corre solo tras cada edición | Vigilar calidad de UI mientras se construye | ✅ | `github.com/pbakaus/impeccable` |
| `premium-website-generator` | Sitios estáticos premium genéricos (HTML/CSS/JS vanilla) | Sitio de propósito general sin build | ✅ | Propia (`claude-skills/`) |
| `landing-cro` | Landing de venta directa desde URL de referencia/marketplace | Landing de conversión puntual | ✅ | Propia |
| `landing-a-secciones` | HTML de landing → secciones `.liquid` de Shopify | Pasar una landing ya armada a una tienda Shopify | ✅ | Propia |
| `landing-team` | 4 agentes (planner/builder/qa/security) del equipo de landing | Orquestar todo el pipeline de una landing sin microgestión manual | ✅ | Propia |
| `claude-webkit` | Plantilla clonable Next.js+Tailwind+shadcn con 21 skills | Ver nota abajo | 🔍 descartado | `github.com/hainrixz/claude-webkit` |
| `refero_skill` | Skill+MCP para investigar 150K screens/flows reales antes de implementar | Ver nota abajo | 🔍 sin decidir | `github.com/referodesign/refero_skill` |
| `google-labs-code/design.md` + `VoltAgent/awesome-design-md` | CLI+lint+export de tokens / galería de `DESIGN.md` reales | Validar/inspirar el `DESIGN.md` que ya generan `stitch-skill`/`impeccable` | 🔍 sin decidir | `github.com/google-labs-code/design.md`, `github.com/VoltAgent/awesome-design-md` |

## Documentación / Diagramas

| Nombre | Funcionalidad | Caso de uso | Estado | Repo |
|---|---|---|---|---|
| `diagram-design` | 40 tipos de diagramas técnicos HTML+SVG | Diagramas de arquitectura, ER, flowcharts | ✅ | `github.com/cathrynlavery/diagram-design` |

## Seguridad

| Nombre | Funcionalidad | Caso de uso | Estado | Repo |
|---|---|---|---|---|
| `cyber-neo` | Auditoría read-only rápida (SAST/SCA/secretos) | Pasada de rutina antes de commitear | ✅ | `github.com/Hainrixz/cyber-neo` |
| `security-audit-skill` | Auditoría adversarial en 6 fases, sub-agentes aislados | Auditoría seria antes de exponer algo a producción — **falta push+install**, ver [nota en agent-skills-catalogo.md](agent-skills-catalogo.md#notas-sobre-security-audit-skill-vs-cyber-neo) | ✅ (pendiente resolver) | `github.com/cloudflare/security-audit-skill` |
| `context-mode` | MCP de ahorro de contexto (sandbox de tools, SQLite) | Ver nota abajo | 🔍 descartado | `github.com/mksglu/context-mode` |

## Deploy / Infra / Plataforma

| Nombre | Funcionalidad | Caso de uso | Estado | Repo |
|---|---|---|---|---|
| `all-deploy` | Deploy a Vercel/Railway/Docker+VPS/cloudflared con auditoría previa | Publicar un proyecto con flujo preview→prod | ✅ | `github.com/Hainrixz/all-deploy` |
| `cloudflare` | Guía Workers/Durable Objects/Wrangler + MCP remoto | Construir/deployar en la plataforma Cloudflare específicamente | ✅ | `github.com/cloudflare/skills` |

## Backend / Lenguajes

| Nombre | Funcionalidad | Caso de uso | Estado | Repo |
|---|---|---|---|---|
| `rust-analyzer-lsp` | LSP de Rust (autocompletado/análisis en vivo) | Cualquier repo Rust | ✅ | Oficial |
| `dmmulroy/anti-slop` | Ruleset de Oxlint anti-patrones sloppy en TS/JS | Aplica el día que haya un proyecto TypeScript nuevo | 📋 | `github.com/dmmulroy/anti-slop` |

## Review / Calidad de código

| Nombre | Funcionalidad | Caso de uso | Estado | Repo |
|---|---|---|---|---|
| `code-review` | Revisión de PR genérica | Revisar un PR sin criterio propio definido | ✅ | Oficial |
| `thermos` | Doble review en paralelo (bugs/seguridad + mantenibilidad) | Revisión de branch antes de mergear | ✅ | Adaptado de Cursor, propio |
| `cursor/plugins` (resto, 17 skills) | `deslop`, `fix-merge-conflicts`, `weekly-review`, etc. | Sin explorar el contenido, solo el índice | 📋 | `github.com/cursor/plugins` |

## Metodología / Planificación / Productividad

| Nombre | Funcionalidad | Caso de uso | Estado | Repo |
|---|---|---|---|---|
| `superpowers` | Brainstorming + dev dirigido por subagentes | Arrancar una feature con proceso, no a ciegas | ✅ | Oficial |
| `mattpocock-skills` | TDD, debugging, spec→tickets, review paralelo | Disciplina de ingeniería real en un repo de trabajo | ✅ | Oficial (Matt Pocock) |
| `the-architect` | Entrevista + blueprints de construcción validados | Proyecto nuevo desde cero, con criterios de aceptación | ✅ | `github.com/Hainrixz/the-architect` |
| `claude-code-setup` | Recomienda automatizaciones para un repo | Onboarding de Claude Code a un repo nuevo | ✅ | Oficial |
| `gstack` | 23 comandos (CEO/eng-manager/QA/security/release) | Ver nota abajo | 🔍 referencia, no instalado | `github.com/garrytan/gstack` |
| `handshake` | Entrevista guiada de idea difusa → doc entregable | Ver nota abajo | 🔍 pausado | `flowstate.help` (sin repo público) |
| DEF Starter Kit | `CLAUDE.md` de proyecto + `LOOP/`/`Planning/` estilo GTD | Ver nota abajo | 🔍 pausado | `flowstate.help` (sin repo público) |

## MCP / Contexto

| Nombre | Funcionalidad | Caso de uso | Estado | Repo |
|---|---|---|---|---|
| `context7` | MCP de Upstash, docs actualizadas de librerías | Se preguntó dos veces si instalar, nunca se contestó | 📋 | `github.com/upstash/context7` |

## Bundle general (mixto, no una sola categoría)

| Nombre | Funcionalidad | Caso de uso | Estado | Repo |
|---|---|---|---|---|
| `example-skills` | 12 skills de ejemplo (arte, docs, MCP builder, Playwright...) | Casos puntuales (GIFs, co-escritura de docs, testing) | ✅ | Oficial (Anthropic) |

## Notas de las evaluadas (por qué quedaron así)

### `claude-webkit` — descartado

No es un plugin de Claude Code — es una plantilla de proyecto para clonar
entera (`git clone` → `cd` → `claude`), con Next.js 16 + Tailwind 4 +
shadcn/ui y un flujo guiado de 6 fases (preguntas de negocio → diseño →
build → deploy). Trae 21 skills **project-scoped** (13 propias + 8 de
[emilkowalski/skills](https://github.com/emilkowalski/skills), MIT, con
atribución). Publica a Vercel sin necesitar cuenta.

Se descartó porque solapa con lo que ya está armado en este repo
(`landing-team`/`landing-pipeline` + `landing-cro` + `premium-website-generator`
+ `landing-a-secciones`) — mismo caso de uso (sitio a partir de un brief, con
deploy), stack distinto (Next.js/React con build vs. HTML/CSS/JS vanilla sin
build, más liviano). Si algún día aparece la necesidad real de un sitio
Next.js/React (no estático), vale la pena reabrir esta evaluación.

### `refero_skill` — sin decidir

Empresa (Refero) con 150.000+ screens reales y 6.000+ flujos de apps bien
diseñadas, más una galería pública de ~2.000 estilos en
`styles.refero.design`. El repo de GitHub es solo el "adaptador" (metodología
`SKILL.md` + wiring del MCP) para que un agente de IA use Refero solo, sin
que el usuario copie nada a mano.

Tres capas, mismo producto: la web (`styles.refero.design`) es gratis y
manual (navegás, copiás un `DESIGN.md`); el repo es el traductor para que
Claude lo haga solo; el MCP (`api.refero.design/mcp`) es la base completa que
el traductor consulta en vivo, y **requiere plan pago + login OAuth**. Sin
pagar, instalar el repo no da más `DESIGN.md` que los que ya se pueden copiar
gratis a mano de la web — y la metodología/guías bundled ya se solapan con
`ui-ux-pro-max`/`taste-skill`/`impeccable`. Solo vale la pena instalarlo si se
paga el plan (ahí Claude busca solo sobre las 150K screens, algo que la
galería estática no permite).

### `gstack` — referencia, no instalado

Framework de Garry Tan (presidente de YC) — 23 comandos especializados (CEO
review, eng manager, designer anti-slop, QA con browser real, security
officer `/cso`, release engineering) + 8 power tools. No es un plugin del
marketplace: se instala clonando a `~/.claude/skills/gstack` + un script
`./setup` propio (bien escrito: umask 077, checksums verificados, "egress
ledger" para trackear llamadas de red — sin señales de mala fe).

No se instaló por invasividad: auto-update silencioso en cada sesión de
Claude Code, control de un browser real con sesiones logueadas (Aside browser
o Chromium propio) para QA/design review, `/cso` pull de imágenes Docker +
requiere toolchain nativo, y modo equipo que puede auto-commitear cambios a
`CLAUDE.md`/`.claude/` de un repo compartido marcándose `required`. Mismo
perfil de invasividad que `context-mode` (abajo). Además se superpone fuerte
con `mattpocock-skills`/`thermos`/`cyber-neo` ya instalados — instalarlo sería
más "cambiar de filosofía" que "sumar una pieza".

### `context-mode` — descartado

MCP de ahorro de contexto (`mksglu/context-mode`): sandboxea salidas de
tools, persiste sesión en SQLite, enruta hacia `ctx_execute`/etc. Es la
herramienta más invasiva evaluada: registra los 6 hooks del ciclo de vida
completo, enruta activamente lejos de Bash/Read/WebFetch nativos, y captura
cada prompt/decisión en una DB paralela a la memoria propia. El propio README
admite que `ctx_execute` (ejecución de código en 12 lenguajes) no es un
sandbox de SO real — hereda el filesystem del proceso y hace *credential
passthrough* de `gh`/`aws`/`gcloud`/`kubectl`/`docker`. Privacidad de red sí
está bien pensada (sin telemetría, redacción de secretos por regex), pero no
compensa el riesgo de "ejecución de código arbitrario con credenciales de
nube" enmascarado como feature de ahorro de contexto.

Alternativa intermedia si se quiere probar: modo MCP-only sin hooks
(`claude mcp add context-mode -- npx -y context-mode`), que evita el
enrutamiento forzado y la captura de sesión.

### `handshake` — pausado

Skill de `flowstate.help`: entrevista guiada de una idea difusa hasta un doc
entregable a un agente researcher/planner. Se inspeccionó el tarball
completo: contenido limpio, sin scripts ni llamadas de red, sin intento de
prompt injection. Pero la proveniencia no es verificable (dominio
desconocido, sin repo público, sin LICENSE, no auditable como un repo de
GitHub); si se instala tal cual en `~/.claude/skills/` no viaja entre
máquinas (carpeta no versionada a propósito); y solapa parcialmente con la
fase de entrevista que ya hace `architect` de `the-architect`.

### DEF Starter Kit — pausado

Mismo dominio `flowstate.help`, producto de "Flowstate Technologies".
Inspeccionado completo (18 archivos): 100% limpio, sin código ni red. No es
un skill/plugin — es un `CLAUDE.md` de **proyecto** + carpetas (`Teller.md`,
`Today.md`, `LOOP/`, `Planning/`) que convierte al agente en un operador
estilo GTD (bandeja única, memoria en archivos). Se pisaría con la memoria
nativa de Claude Code que ya se usa (dos sistemas en paralelo), y su regla
por defecto (sin jerga, sin paths de archivo en los resúmenes) apunta a un
usuario no técnico — el kit mismo dice "si sos ingeniero, suavizá o borrá esa
regla". Solo tendría sentido como `CLAUDE.md` de un proyecto nuevo, nunca en
dotfiles.

## Cómo mantener esto al día

- Antes de evaluar algo nuevo: buscar primero la categoría acá.
- Cuando se decida algo de estado 🔍/📋: actualizar su fila (o borrarla del
  todo si se descarta sin dejar rastro útil).
- Si algo pasa a instalarse: cambiar el Estado a ✅ acá **y** sumarlo a
  [`agent-skills-catalogo.md`](agent-skills-catalogo.md) con el detalle
  técnico (hooks, invocación, solapamientos finos).
