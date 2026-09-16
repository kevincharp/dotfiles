// Equipo de agentes para armar, revisar y deployar una landing page.
// No auto-descubierto todavia por Claude Code (el bootstrap solo symlinkea
// CLAUDE.md y settings.json, no .claude/workflows/) -- invocar con scriptPath:
//   Workflow({ scriptPath: "<esta ruta>", args: { brief: "...", projectPath: "..." } })
// El brief se arma ANTES de invocar esto, en conversacion normal (grill-me /
// grilling de mattpocock-skills, o la intake propia de landing-cro si el
// pedido ya es una URL de producto). El Workflow no entrevista: ejecuta.

export const meta = {
  name: 'landing-pipeline',
  description: 'Equipo de agentes para armar, revisar y deployar una landing page (dropshipping o agencia)',
  phases: [
    { title: 'Plan', detail: 'clasifica el tipo de landing y arma el brief estructurado' },
    { title: 'Build', detail: 'genera la landing con landing-cro o premium-website-generator' },
    { title: 'Review', detail: 'QA (Playwright + impeccable) y Seguridad/calidad (cyber-neo + code-review) en paralelo' },
    { title: 'Fix', detail: 'corrige los hallazgos bloqueantes del Review, si hay' },
    { title: 'Deploy', detail: 'despliega con all-deploy (preview -> health-check -> prod)' },
  ],
}

const BRIEF_SCHEMA = {
  type: 'object',
  properties: {
    landingType: { type: 'string', enum: ['dropship', 'agency'] },
    buildSkill: { type: 'string', enum: ['landing-cro', 'premium-website-generator'] },
    needsShopifySections: { type: 'boolean' },
    needsBackendFlag: { type: 'boolean' },
    backendReason: { type: 'string' },
    briefSummary: { type: 'string' },
    styleDirection: { type: 'string' },
  },
  required: ['landingType', 'buildSkill', 'needsShopifySections', 'needsBackendFlag', 'briefSummary'],
}

const BUILD_SCHEMA = {
  type: 'object',
  properties: {
    projectPath: { type: 'string' },
    summary: { type: 'string' },
  },
  required: ['projectPath', 'summary'],
}

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    blocking: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          area: { type: 'string' },
          issue: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['area', 'issue', 'fix'],
      },
    },
    notes: { type: 'string' },
  },
  required: ['blocking', 'notes'],
}

phase('Plan')
const brief = await agent(`
Sos el planner de una landing page. Este es el pedido crudo del usuario:

"""
${args.brief}
"""

Clasifica el tipo de landing: "dropship" (venta directa de un producto de
marketplace o de una marca de referencia, via la skill landing-cro) o
"agency" (sitio de marca/servicio/portfolio, via la skill
premium-website-generator). Decidi que skill de build corresponde
(buildSkill). Si el pedido menciona convertir a Shopify, marca
needsShopifySections=true (se usara la skill landing-a-secciones despues del
build). Si el pedido menciona algo que requiera backend real (formulario
propio que guarda datos, checkout propio, integraciones de pago/CRM), marca
needsBackendFlag=true y explica por que en backendReason -- NO intentes
construir ese backend, solo flagealo. Armá un briefSummary claro y, si el
pedido lo sugiere, una styleDirection (ej: minimalista, brutalista, alta
gama, editorial).
`, { schema: BRIEF_SCHEMA, phase: 'Plan' })

log(`Plan: ${brief.landingType} -> ${brief.buildSkill}${brief.needsShopifySections ? ' + landing-a-secciones' : ''}${brief.needsBackendFlag ? ' (backend flageado, no se construye en este pipeline)' : ''}`)

phase('Build')
const build = await agent(`
Usa la skill "${brief.buildSkill}" para construir la landing en ${args.projectPath}.

Brief: ${brief.briefSummary}
Direccion de estilo: ${brief.styleDirection || 'sin preferencia explicita, usa tu mejor criterio'}

${brief.needsShopifySections ? 'Al terminar el HTML, usa la skill "landing-a-secciones" para convertirlo en secciones .liquid del tema Dawn, y mencionalo en el resumen.' : ''}

Devolve la ruta del proyecto y un resumen de lo que construiste.
`, { schema: BUILD_SCHEMA, phase: 'Build' })

phase('Review')
const [qa, security] = await parallel([
  () => agent(`
Hace QA de la landing en ${build.projectPath}.
Usa Playwright (skill de testing de apps web) para: screenshot desktop y
mobile, revisar links rotos, errores de consola, y comportamiento responsive.
Corre tambien "/impeccable audit" sobre el proyecto para el chequeo de diseño
anti-generico.
Devolve SOLO los hallazgos bloqueantes (rompe la pagina, se ve mal en mobile,
link roto) en "blocking", y cualquier otra observacion en "notes".
`, { schema: FINDINGS_SCHEMA, phase: 'Review' }),
  () => agent(`
Hace una revision de seguridad y calidad de codigo de la landing en ${build.projectPath}.
Usa la skill de auditoria de seguridad (cyber-neo) para escanear secretos o
config expuesta (API keys de analytics, webhooks hardcodeados, etc.) y una
revision de code review general sobre el HTML/CSS/JS generado.
Devolve SOLO los hallazgos bloqueantes (secreto expuesto, vulnerabilidad
real) en "blocking", y cualquier otra observacion en "notes".
`, { schema: FINDINGS_SCHEMA, phase: 'Review' }),
])

const blocking = [...(qa?.blocking || []), ...(security?.blocking || [])]

let fixSummary = 'Sin hallazgos bloqueantes, no hizo falta arreglar nada.'
if (blocking.length) {
  phase('Fix')
  fixSummary = await agent(`
Corregi estos hallazgos bloqueantes en ${build.projectPath}, sin romper nada mas:

${blocking.map((b, i) => `${i + 1}. [${b.area}] ${b.issue} -- sugerencia: ${b.fix}`).join('\n')}
`, { phase: 'Fix' })
}

phase('Deploy')
const deploy = await agent(`
Deploya el proyecto en ${build.projectPath} usando la skill "all-deploy"
(con su auditoria previa y flujo preview -> health-check -> prod).
`, { phase: 'Deploy' })

return {
  brief,
  build,
  review: { qaNotes: qa?.notes, securityNotes: security?.notes, blocking },
  fix: fixSummary,
  deploy,
}
