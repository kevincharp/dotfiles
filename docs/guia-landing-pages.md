# Guía: equipo de agentes para landing pages

Playbook para arrancar un proyecto de landing page (dropshipping o agencia)
usando el [catálogo de Agent Skills](agent-skills-catalogo.md) ya armado.
Pensado para uso recurrente (varias landings por mes), no para un caso único.

## El equipo

4 roles viven como agentes propios en el plugin **`landing-team`**
(`claude-skills/landing-team/agents/*.md`), con `tools` restringidos —
mismo criterio que un setup manual de sesiones nombradas: los roles que
solo evalúan (planner/QA/seguridad) son de lectura, solo `builder` escribe
código:

| Rol | Agente | Tools | Skill(s) que usa | Cuándo actúa |
|---|---|---|---|---|
| **Planner** | `landing-team:planner` | Read, Grep, Glob, Bash | clasifica el brief ya armado | Dentro del Workflow, después de la entrevista inline |
| **Builder** | `landing-team:builder` | Read, Write, Edit, Bash, Grep, Glob | `landing-cro`/`premium-website-generator` + `landing-a-secciones` si hace falta Shopify | Genera el HTML/CSS/JS completo en un solo paso, y aplica los fixes que pida Review |
| **Backend** | *(no existe todavía — ver abajo)* | — | — | Solo si el brief pide formulario propio, checkout propio o integraciones |
| **QA** | `landing-team:qa` | Read, Grep, Glob, Bash | `webapp-testing` (Playwright) + `/impeccable audit` | En paralelo con Seguridad, después del build |
| **Seguridad/Calidad** | `landing-team:security` | Read, Grep, Glob, Bash | `cyber-neo` + `code-review` (o `thermos` una vez instalado) | En paralelo con QA |

`impeccable` (el hook automático) y las skills de `taste-skill`/`ui-ux-pro-max`
ya corren pasivamente durante el Build, no son un paso explícito del equipo.

**Deploy queda afuera del Workflow a propósito** — no hay agente ni fase
para eso. Es un paso separado y explícito: una vez que ves el resultado de
Plan→Build→Review→Fix, si te convence, le decís a Claude que deploye y ahí
se invoca la skill `all-deploy` (que ya trae su propia auditoría +
preview→health-check→prod con confirmación). Un Workflow corre en
background y no puede pausar a mitad de camino a pedir un OK — por eso
producción no puede estar en el mismo run automático que el resto.

## Por qué la entrevista NO está en el Workflow

Los workflows corren en background y no pueden pausar a preguntar. El
Planner se parte en dos:

1. **Inline, en conversación normal** (con Claude, antes de invocar nada):
   `grill-me`/`grilling` de `mattpocock-skills`, o la intake propia de
   `landing-cro` si el pedido ya es una URL → brief estructurado.
2. **Dentro del Workflow** (`landing-team:planner`): solo clasifica el brief
   ya armado (dropship vs. agencia, `buildSkill`, si hace falta Shopify, si
   hay que flagear backend) — no vuelve a entrevistar.

## Cómo se compara con tu patrón manual de sesiones nombradas

Si ya armaste un equipo a mano alguna vez (agentes propios en
`.claude/agents/`, una sesión por rol con `/rename`, `SendMessage` entre
ellas, worktrees cuando dos roles tocan los mismos archivos en paralelo):
este Workflow hace lo mismo que ese patrón, pero:

- **Automatizado, no manual**: no abrís sesiones ni relayeás nada — un
  script dispara los 4 agentes en el momento que corresponde.
- **De una sola pasada, no persistente**: los agentes del Workflow no
  quedan vivos para retomarlos en otro momento — hacen su tarea y
  desaparecen. Para algo repetible y acotado como una landing, alcanza. Para
  un proyecto grande con ida y vuelta de días (tipo integración
  backend+frontend), tu patrón manual sigue siendo mejor — ahí sí conviene
  supervisar paso a paso.
- **Sin worktrees**: el Build es un solo agente (no hay dos escribiendo el
  mismo archivo a la vez) y Review es de solo lectura, así que no hace falta
  la isolación que sí necesitás cuando varios roles mutan el mismo repo en
  simultáneo. El día que Backend se vuelva real y corra en paralelo con
  Builder, ahí sí habría que sumar `isolation: 'worktree'` a esos agentes,
  igual que en tu setup manual.

Los 4 agentes de `landing-team` no están atados al Workflow — también se
pueden invocar sueltos con el Agent tool (`subagent_type:
"landing-team:builder"`, etc.), o manejarlos a mano con tu propio patrón de
sesiones nombradas + `SendMessage` si algún día preferís supervisar una
landing particular paso a paso en vez de dejarla correr sola.

## Cómo correrlo

El script vive en `.claude/workflows/landing-pipeline.js` (no
auto-descubierto todavía — ver "Pendiente" abajo). Se invoca con
`scriptPath`, pasando el brief ya armado y la carpeta del proyecto:

```
Workflow({
  scriptPath: "<ruta absoluta a>/.claude/workflows/landing-pipeline.js",
  args: {
    brief: "<el brief ya armado, o la URL del producto si es dropship>",
    projectPath: "/ruta/al/proyecto/vacio/o/existente"
  }
})
```

Fases: **Plan** (clasifica) → **Build** (genera) → **Review** (QA +
Seguridad/Calidad en paralelo) → **Fix** (solo si Review encontró algo
bloqueante). Deploy, como se explicó arriba, es aparte.

## Backend: punto de extensión, no código muerto

Hoy (2026-09) las landings son 100% estáticas. El Plan del workflow ya
detecta si el brief pide algo que necesite backend real (formulario propio,
checkout propio, integraciones) y lo marca en `needsBackendFlag` +
`backendReason`, pero **no construye nada** — no existe todavía un agente
`landing-team:backend` ni una fase para eso, a propósito (no tiene sentido
un rol sin nada que hacer). El día que haga falta:

1. Crear `claude-skills/landing-team/agents/backend.md` (tools completos,
   igual que `builder`).
2. Agregar una fase `Backend` entre `Build` y `Review` en
   `landing-pipeline.js`, gateada por `brief.needsBackendFlag`.
3. Si Backend y Builder van a tocar el mismo repo en paralelo, sumar
   `isolation: 'worktree'` a esos dos `agent()` calls (ver sección de
   arriba).

## Antes de la primera corrida real: setup de mattpocock-skills

Muchas de las skills de `engineering/` (`to-spec`, `to-tickets`, `triage`)
necesitan `/setup-matt-pocock-skills` corrido una vez **en el repo del
proyecto de landing**, no en dotfiles (decisión ya tomada, ver
[catálogo](agent-skills-catalogo.md#notas-sobre-mattpocock-skills)). El
equipo de este pipeline no depende de ese setup — es opcional, para cuando
quieras trackear cada landing como ticket formal.

## Estado: instalado (2026-09-16)

`thermos` y `landing-team` ya están pusheados e instalados
(`claude plugin install "<nombre>@kevincharp-dotfiles" -y`, después de
`claude plugin marketplace update kevincharp-dotfiles`).

**Corrección a lo que decía antes:** apenas se instaló `landing-team`,
`landing-pipeline` apareció solo como skill invocable por nombre — sin
pasar `scriptPath`. La invocación por nombre (`Workflow({name:
"landing-pipeline", args: {...}})`) parece resolverse **relativa al
proyecto actual** (`.claude/workflows/` del cwd), no globalmente: funciona
así, sin nada más, cuando se trabaja **desde este mismo repo** (dotfiles).

**Sigue sin confirmar** si esa resolución por nombre funciona también desde
la carpeta de un proyecto de landing real (fuera de dotfiles) — ahí el cwd
no tiene su propio `.claude/workflows/landing-pipeline.js`. Si al probarlo
`{name: "landing-pipeline"}` no resuelve desde otro proyecto, usar
`scriptPath` con la ruta absoluta como respaldo seguro:

```
Workflow({
  scriptPath: "<ruta absoluta a>/.claude/workflows/landing-pipeline.js",
  args: { brief: "...", projectPath: "..." }
})
```

Si hace falta invocarlo por nombre desde cualquier proyecto y no alcanza con
lo anterior, la vía sería sumar el symlink de `.claude/workflows/` al
bootstrap (con su chequeo de paridad en `test-bootstrap.sh`) — no
implementado, evaluar si se siente el dolor en el uso real.
