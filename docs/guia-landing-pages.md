# Guía: equipo de agentes para landing pages

Playbook para arrancar un proyecto de landing page (dropshipping o agencia)
usando el [catálogo de Agent Skills](agent-skills-catalogo.md) ya armado.
Pensado para uso recurrente (varias landings por mes), no para un caso único.

## El equipo

| Rol | Skill(s) | Cuándo actúa |
|---|---|---|
| **Planner** | `grill-me`/`grilling` (`mattpocock-skills`) para entrevistar, o la intake propia de `landing-cro` si el pedido ya es una URL | Antes de todo — produce el brief |
| **Builder** | `landing-cro` (dropship) o `premium-website-generator` (agencia) + `landing-a-secciones` si hace falta Shopify | Genera el HTML/CSS/JS completo en un solo paso |
| **Backend** | *(dormido — ver abajo)* | Solo si el brief pide formulario propio, checkout propio o integraciones |
| **QA** | `webapp-testing` (Playwright) + `/impeccable audit` | Después del build: ¿funciona? ¿se ve bien en mobile? |
| **Seguridad/Calidad** | `cyber-neo` + `code-review` (o `thermos` una vez instalado) | En paralelo con QA: ¿hay secretos filtrados? ¿el código es limpio? |
| **Deploy** | `all-deploy` | Última etapa — preview → health-check → prod |

`impeccable` (el hook automático) y el `disable-model-invocation` de las
skills de `taste-skill`/`ui-ux-pro-max` ya corren pasivamente durante el
Build, no son un paso explícito del equipo.

## Por qué la entrevista NO está en el Workflow

Los workflows corren en background y no pueden pausar a preguntar. El
Planner se parte en dos:

1. **Inline, en conversación normal** (con Claude, antes de invocar nada):
   grilling/interview → brief estructurado.
2. **Dentro del Workflow**: un agente liviano que solo clasifica el brief ya
   armado (dropship vs. agencia, `buildSkill`, si hace falta Shopify, si hay
   que flagear backend) — no vuelve a entrevistar.

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
bloqueante) → **Deploy**.

## Backend: punto de extensión, no código muerto

Hoy (2026-09) las landings son 100% estáticas. El Plan del workflow ya
detecta si el brief pide algo que necesite backend real (formulario propio,
checkout propio, integraciones) y lo marca en `needsBackendFlag` +
`backendReason`, pero **no construye nada** — se decidió no escribir una
fase "Backend" vacía. El día que haga falta: agregar una fase `Backend`
entre `Build` y `Review` en `landing-pipeline.js`, gateada por
`brief.needsBackendFlag`, con su propio agente.

## Antes de la primera corrida real: setup de mattpocock-skills

Muchas de las skills de `engineering/` (`to-spec`, `to-tickets`, `triage`)
necesitan `/setup-matt-pocock-skills` corrido una vez **en el repo del
proyecto de landing**, no en dotfiles (decisión ya tomada, ver
[catálogo](agent-skills-catalogo.md#notas-sobre-mattpocock-skills)). El
Planner/Builder de este pipeline no dependen de ese setup — son opcionales,
para cuando quieras trackear cada landing como ticket formal.

## Pendiente: hacerlo invocable por nombre desde cualquier máquina

Hoy hay que pasar `scriptPath` a mano porque el bootstrap solo symlinkea
`CLAUDE.md` y `settings.json`, no `.claude/workflows/`. Si esto se usa
seguido, vale la pena sumar ese symlink al bootstrap (con su chequeo de
paridad en `test-bootstrap.sh`) para poder invocarlo como
`Workflow({name: "landing-pipeline", args: {...}})` desde cualquier
proyecto, en cualquier máquina. No implementado todavía — evaluar cuando se
use un par de veces y se sienta el dolor de pasar la ruta a mano.
