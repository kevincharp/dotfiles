# Playbook de desarrollo con agentes

Machete de "si pasa X, hago Y" para no depender de la memoria. El proceso es
independiente de la herramienta; lo específico de Claude Code está en la
columna **Hoy en Claude Code** y es lo único que se reescribe si cambio de
herramienta. Equipo y molde de agentes: [`molde-agente.md`](molde-agente.md).
Cada proyecto lleva su `AGENTS.md`, copiado de
[`plantilla-agents-proyecto.md`](plantilla-agents-proyecto.md). Los agentes
(`explorador`, `builder`, `revisor`, `devops`, `seguridad`) están en
`.claude/agents/`; se usan pidiéndole a la sesión que delegue en ellos por
nombre.

**Estado:** armado leyendo la documentación de las skills, sin probar todavía
en un proyecto real. Ajustar las filas con el uso.

## Definición de hecho

Un ticket está terminado cuando se cumplen estas cuatro cosas, y nada más:

1. Cumple sus criterios de aceptación.
2. Los tests pasan.
3. Pasó la simplificación del cambio.
4. Está commiteado.

Lo que se me ocurra además va al **estacionamiento**, no a este ticket. Error
cero no existe: lo que sí existe es esta línea, y sin ella el pulido no para.

## Estacionamiento

Lista (archivo o etiqueta `idea` en los tickets) donde anoto todo lo que se me
ocurre mientras trabajo: mejoras, refactors, diagramas, documentación. No se
hace ahora; se revisa al cerrar el ticket o el fin de semana.

## Presupuesto de documentación y código

- **Documentación:** README (qué es, cómo correr, cómo probar), una página de
  arquitectura con diagramas Mermaid, decisiones (ADR), glosario e índice.
  Cada documento responde una pregunta; si no hay una duda concreta que
  responda, va al estacionamiento.
- **Quién la escribe:** el glosario y las decisiones salen de la entrevista
  previa a la especificación; el README lo toca el Builder solo si cambia
  cómo se corre o se prueba; la arquitectura y los diagramas, por hito (no por
  ticket); el Revisor comprueba que la documentación coincida con el código.
- **Diagramas:** uno por flujo importante, no uno por funcionalidad.
- **Refactor:** solo si algo se repite 3 veces y con los tests en verde, en un
  commit aparte. Nunca mezclado con una funcionalidad.
- **Optimización:** solo con una medición que muestre el problema.
- **Pulido:** máximo 2 rondas por ticket; a la tercera se commitea y se sigue.

## Flujo según el tamaño

| Tamaño | Ejemplo | Flujo |
|---|---|---|
| Chico | Un sitio estático, un script | Una sesión, sin tickets: idea → generar → pedidos de a uno → simplificar → commit → publicar |
| Mediano | App con varias funciones | Entrevista → especificación → tickets con dependencias → un ticket por sesión → revisión → publicar |
| Grande o confuso | No cabe en una sesión | Mapa de decisiones resueltas de a una, y después el flujo mediano |

Una sesión por ticket, no una por proyecto. La revisión siempre en contexto
limpio, nunca en el que escribió el código.

## Si pasa X, hago Y

| Si… | Entonces… | Hoy en Claude Code |
|---|---|---|
| Tengo una idea de proyecto | Ubicarme en el flujo y afilar la idea con una entrevista | `/ask-matt`, `/grill-with-docs` |
| Es chico | Una sesión, sin tickets | Skill de sitio (`premium-website-generator`) |
| Es mediano | Especificación → tickets con dependencias → un ticket por vez | `/to-spec`, `/to-tickets`, `/implement` |
| Tengo un bug mío | Anotarlo como ticket; si es chico, diagnosticarlo ahora | `/triage`, `diagnosing-bugs` |
| Me llega un bug o pedido de otro | Pasarlo por triage | `/triage` |
| Quiero una funcionalidad | Ticket primero, nunca directo al código | `/to-tickets` |
| Hay varios tickets y no sé cuál | El que menos bloquea, o el más chico que funcione de punta a punta | — |
| Se me ocurre una mejora en el medio | Estacionamiento | — |
| Quiero refactorizar | ¿Se repite 3 veces? Si no, no | `/simplify` |
| Quiero documentar o diagramar | ¿Entra en el presupuesto? Si no, estacionamiento | `diagram-design` para el principal |
| No entiendo lo que escribió el agente | Parar y preguntarle qué hace y por qué, antes de commitear | — |
| El agente hace cosas que no pedí | Pararlo y repetir el límite: solo lo del ticket | `/simplify` |
| La sesión se puso larga y confusa | Cerrar y abrir otra con un resumen corto | `/ask-matt` indica cuándo cortar |
| Antes de cada commit | Simplificar el cambio | `/simplify` |
| Antes de mergear una rama | Revisión en contexto limpio | `/code-review`, `thermos` |
| Cambio de riesgo (login, pagos, algo expuesto) | Auditoría de seguridad profunda | `claude-security`, `security-audit-skill` |
| Antes de publicar | Tests en verde y deploy con revisión previa | `all-deploy` |
| Siento que falta algo para que quede perfecto | Releer la definición de hecho; si se cumple, está terminado | — |

Al pedir cosas al agente, con límite: "solo lo del ticket", "sin documentación
nueva", "sin refactor".

## Revisión según el riesgo

| El cambio es… | Pasa por… |
|---|---|
| Un botón, texto, estilo | Builder, tests, simplificar, mirarlo en el navegador |
| Una funcionalidad normal | Lo anterior y Revisor con checklist |
| Login, pagos, permisos, algo expuesto | Lo anterior y Seguridad |

Lo repetible va con código (linter, tests, hooks) antes que con un agente: da
siempre el mismo resultado. La experiencia de usuario la juzgo yo, con capturas
si hace falta.
