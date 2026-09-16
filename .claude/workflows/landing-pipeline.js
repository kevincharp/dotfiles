// Equipo de agentes para armar y revisar una landing page. Deploy queda
// AFUERA a proposito: es un paso separado y explicito que se dispara aparte
// (skill "all-deploy"), nunca automatico dentro de este run -- production es
// dificil de revertir y un Workflow no puede pausar a mitad de camino a
// pedir un OK, asi que el OK se pide fuera de este script, despues de ver
// el resultado.
//
// Los 4 roles (planner/builder/qa/security) viven como agentes propios en
// el plugin "landing-team" (claude-skills/landing-team/agents/*.md), no
// inline en este script -- asi son reutilizables tambien fuera del
// Workflow: via el Agent tool directo, o con el patron manual de sesiones
// nombradas + SendMessage si algun dia se prefiere trabajar una landing
// particular a mano en vez de con este script.
//
// No auto-descubierto todavia por Claude Code (el bootstrap solo symlinkea
// CLAUDE.md y settings.json, no .claude/workflows/) -- invocar con scriptPath:
//   Workflow({ scriptPath: "<esta ruta>", args: { brief: "...", projectPath: "..." } })
// El brief se arma ANTES de invocar esto, en conversacion normal (grill-me /
// grilling de mattpocock-skills, o la intake propia de landing-cro si el
// pedido ya es una URL de producto). El Workflow no entrevista: ejecuta.

export const meta = {
  name: 'landing-pipeline',
  description: 'Equipo de agentes para armar y revisar una landing page (deploy es un paso aparte, explicito)',
  phases: [
    { title: 'Plan', detail: 'clasifica el tipo de landing y arma el brief estructurado' },
    { title: 'Build', detail: 'genera la landing con landing-cro o premium-website-generator' },
    { title: 'Review', detail: 'QA (Playwright + impeccable) y Seguridad/calidad (cyber-neo + code-review) en paralelo' },
    { title: 'Fix', detail: 'corrige los hallazgos bloqueantes del Review, si hay' },
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
Pedido crudo del usuario:

"""
${args.brief}
"""

Clasifica este pedido y arma el brief estructurado.
`, { schema: BRIEF_SCHEMA, phase: 'Plan', agentType: 'landing-team:planner' })

log(`Plan: ${brief.landingType} -> ${brief.buildSkill}${brief.needsShopifySections ? ' + landing-a-secciones' : ''}${brief.needsBackendFlag ? ' (backend flageado, no se construye en este pipeline)' : ''}`)

phase('Build')
const build = await agent(`
Carpeta de proyecto: ${args.projectPath}
Skill de build a usar: ${brief.buildSkill}
Brief: ${brief.briefSummary}
Direccion de estilo: ${brief.styleDirection || 'sin preferencia explicita, usa tu mejor criterio'}
Necesita secciones Shopify despues del build: ${brief.needsShopifySections}

Construi la landing.
`, { schema: BUILD_SCHEMA, phase: 'Build', agentType: 'landing-team:builder' })

phase('Review')
const [qa, security] = await parallel([
  () => agent(`Proyecto en ${build.projectPath}. Hace QA completo y reporta los hallazgos.`, {
    schema: FINDINGS_SCHEMA, phase: 'Review', agentType: 'landing-team:qa',
  }),
  () => agent(`Proyecto en ${build.projectPath}. Hace la revision de seguridad y calidad de codigo y reporta los hallazgos.`, {
    schema: FINDINGS_SCHEMA, phase: 'Review', agentType: 'landing-team:security',
  }),
])

const blocking = [...(qa?.blocking || []), ...(security?.blocking || [])]

let fixSummary = 'Sin hallazgos bloqueantes, no hizo falta arreglar nada.'
if (blocking.length) {
  phase('Fix')
  fixSummary = await agent(`
Corregi estos hallazgos bloqueantes en ${build.projectPath}, sin romper nada mas:

${blocking.map((b, i) => `${i + 1}. [${b.area}] ${b.issue} -- sugerencia: ${b.fix}`).join('\n')}
`, { phase: 'Fix', agentType: 'landing-team:builder' })
}

return {
  brief,
  build,
  review: { qaNotes: qa?.notes, securityNotes: security?.notes, blocking },
  fix: fixSummary,
  nextStep: `Listo para revisar a ojo. Cuando confirmes, deployar con la skill "all-deploy" sobre ${build.projectPath}.`,
}
