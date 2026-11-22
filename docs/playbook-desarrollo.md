# Playbook de desarrollo con agentes

Machete de "si pasa X, hago Y" para no depender de la memoria. El proceso es
independiente de la herramienta; lo específico de Claude Code está en la
columna **Hoy en Claude Code** y es lo único que se reescribe si cambio de
herramienta. Equipo y molde de agentes: [`molde-agente.md`](molde-agente.md).
Cada proyecto lleva su `AGENTS.md`, copiado de
[`plantilla-agents-proyecto.md`](plantilla-agents-proyecto.md). Los agentes
(`explorer`, `builder`, `verifier`, `reviewer`, `devops`, `security`) están en
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

Lo que se me ocurra además va al **backlog**, no a este ticket. Error
cero no existe: lo que sí existe es esta línea, y sin ella el pulido no para.

## Backlog

Lista (sección Backlog de `STATUS.local.md`, o etiqueta `idea` en los tickets)
donde anoto todo lo que se me ocurre mientras trabajo: mejoras, refactors,
diagramas, documentación. No se hace ahora; se revisa al cerrar el ticket o el
fin de semana.

## Presupuesto de documentación y código

- **Documentación:** README (qué es, cómo correr, cómo probar), una página de
  arquitectura con diagramas Mermaid, decisiones (ADR), glosario e índice.
  Cada documento responde una pregunta; si no hay una duda concreta que
  responda, va al backlog.
- **Quién la escribe:** el glosario y las decisiones salen de la entrevista
  previa a la especificación; el README lo toca el Builder solo si cambia
  cómo se corre o se prueba; la arquitectura y los diagramas, por hito (no por
  ticket); el Reviewer comprueba que la documentación coincida con el código.
- **Diagramas:** uno por flujo importante, no uno por funcionalidad.
- **Refactor:** solo si algo se repite 3 veces y con los tests en verde, en un
  commit aparte. Nunca mezclado con una funcionalidad.
- **Optimización:** solo con una medición que muestre el problema.
- **Pulido:** máximo 2 rondas por ticket; a la tercera se commitea y se sigue.
- **Especificaciones y planes de trabajo:** archivos `*.local.md`, descartables;
  no se commitean ni van a `docs/`. Un proyecto chico no los lleva: si una skill
  de planificación propone uno, se le dice que no.

## Flujo según el tamaño

| Tamaño | Ejemplo | Flujo |
|---|---|---|
| Chico | Un sitio estático, un script | Una sesión, sin tickets: idea → generar → pedidos de a uno → simplificar → commit → publicar |
| Mediano | App con varias funciones | Entrevista → especificación → tickets con dependencias (marcando el corte del MVP) → un ticket por sesión → revisión → publicar |
| Grande o confuso | No cabe en una sesión | Mapa de decisiones resueltas de a una, y después el flujo mediano |

Una sesión por ticket, no una por proyecto. La revisión siempre en contexto
limpio, nunca en el que escribió el código.

## Arrancar un proyecto

1. `ginit <perfil>` en la carpeta de contexto que corresponda.
2. Abrir una sesión y contar la idea.
3. **Entrevista corta, de a una pregunta, sobre mi situación y no sobre
   tecnologías:** quién lo usa, dónde se publica, si guarda datos, si hay login
   y de quién (empresa o personal).
4. **Stack:** el agente lo elige de [`stacks.md`](stacks.md); si no encaja,
   propone dos opciones con su motivo y yo elijo. Explica cada pieza que no
   conozca antes de usarla.
5. **Entrevista de contenido, antes de diseñar,** también de a una pregunta,
   para juntar todos los datos: logo, colores, tipografía, fotos y videos (con
   permiso de uso; los videos en MP4 H.264), precios y horarios confirmados por
   escrito, dirección, redes, formas de pago y quién escribe el "sobre mí". Con
   un cliente se usa [`git/brief-cliente.md`](../git/brief-cliente.md).
6. **Referencias de diseño:** pedir de 3 a 5 sitios que me gusten o le gusten al
   cliente, de cualquier rubro. Recién después se proponen las direcciones de
   diseño, y cada una dice de cuál sale. Al empezar, comprobar qué herramientas
   web tiene la sesión: si no hay búsqueda, las referencias las pongo yo.
7. Completar el `AGENTS.md` del proyecto **antes de escribir código** (cómo
   correr, stack, referencias, ramas y ambientes).
8. Seguir con la especificación y los tickets. Al armarlos, marcar cuál es el
   último del MVP (la versión más chica que ya le sirve a alguien): un milestone
   `MVP` si van como GitHub Issues, o una marca en el ticket si son archivos.

En un proyecto ya iniciado no hay entrevista sobre la idea: el agente lee el
código, informa el stack que ya tiene y propone cambios sin aplicarlos hasta que
los apruebe.

## Antes del primer push

Un proyecto nuevo vive en local hasta tener un MVP armado; el historial de esa
etapa es borrador y se publica aplanado. Mientras tanto, rigen las mismas
reglas (rama por ticket, commits granulares) y se respalda con
`git bundle create ../<proyecto>.bundle --all` al cerrar cada ticket.

El primer push se hace cuando se cumple todo esto:

1. **MVP:** hace lo principal y lo probé a mano.
2. **Clon limpio:** un clon desde el bundle arranca siguiendo el README.
3. **Pruebas y CI** (si tiene lógica) pasan en local.
4. **README y `AGENTS.md`** completos: cómo correr, cómo probar, stack.
5. **Sin ruido:** `.gitignore` completo y los registros de proceso fuera, en
   `*.local.md`.
6. **Historial aplanado:** un solo commit, `feat: versión inicial`; el historial
   previo queda en la etiqueta local `historial-previo`, que nunca se pushea.
7. **gitleaks** sobre el commit aplanado, sin hallazgos sin justificar. Las
   huellas de `.gitleaksignore` llevan el hash del commit: tras aplanar se
   regeneran.
8. **Identidad** del perfil correcto en el commit, y remoto con `gremote`.

Excepción: si alguien más tiene que trabajar en el proyecto antes del MVP, se
pushea antes, con los puntos 2 a 8.

## Trabajo con clientes

**Estado:** borrador sin probar; se ajusta con el primer cliente real.

### El tablero

Los posibles clientes y los clientes viven como tickets de GitHub Issues en un
repo privado, `dashboard-clients`, uno solo. **Un posible cliente es un ticket, no
un repo.** Cuando acepta la propuesta, el ticket se cierra como "convertido" con
el enlace al repo de su proyecto, que tiene sus propios tickets de desarrollo. Un
cambio en la misma página es un ticket de ese repo; un proyecto nuevo del mismo
cliente es un ticket nuevo en `dashboard-clients`.

- **El ticket** es de tipo **Client** y se da de alta con el formulario "Nuevo
  cliente" (nombre, descripción, canal, fuente, rubro y datos de contacto). El
  formulario lo asigna a mí y le pone la etiqueta `inbound`; si es un prospecto en
  frío, la cambio a `prospect`.
- **Los pasos** son sus sub-issues, de tipo **Task**, y se crean solos al abrir
  el ticket: contestar al cliente, completar el brief, armar direcciones y
  propuesta, y enviar la propuesta. Esperar la respuesta no es un paso: es la
  columna Esperando.
- **El campo Propuesta** (Pendiente, Aprobada, Rechazada, Cancelada) dice cómo
  terminó. Con Aprobada se crea la tarea de crear el repo del proyecto; con
  Rechazada o Cancelada el cliente se cierra.
- **El estado** se ve en el project "Dashboard Clients", en cuatro columnas: Por
  hacer, En curso (me toca a mí), Esperando (le toca al cliente) y Hecho. Cambia
  solo: el primer paso cerrado lo pasa a En curso, enviar la propuesta a
  Esperando, y crear el repo (o rechazar o cancelar) a Hecho. Lo hace un
  workflow de GitHub Actions del repo, con un token personal guardado como
  secreto; también se puede mover la tarjeta a mano.
- **Se cierra** desde el ticket: "Completed" si se convirtió en proyecto, "Not
  planned" si no avanzó. Todo lo que pasa se documenta como comentario.

### Cómo trabaja el agente con el tablero

En una sesión abierta en `dashboard-clients`: al empezar lista los tickets de
cliente abiertos, crea los pasos de los que no los tienen, elige el más urgente y
propone la próxima acción, que es **el primer paso abierto**, con un borrador. No
envía nada por su cuenta: reviso, copio y mando yo. Lo que le cuento (respuestas
del cliente, decisiones) lo documenta en el ticket, y cierra un paso solo cuando
yo digo que está hecho.

### Las etapas

| Etapa | Qué pasa | Quién |
|---|---|---|
| 0. Prospección | Elegir de 5 a 10 negocios con web floja o sin web; cada uno es un ticket "Prospecto" en `dashboard-clients` | Yo |
| 0b. Propuesta en frío | Auditoría de lo comprobable (capturas en celular y compu, HTTPS, si se ve bien en el celular, botón de contacto) y una dirección mejorada, antes y después, en una página HTML local | Agente |
| 0c. Contacto | Mensaje corto y personal, de a uno | Yo (el agente redacta) |
| 1. Brief | El cliente cuenta qué quiere y trae sus referencias; queda en el ticket y, al aceptar, en `BRIEF.local.md` del proyecto | Cliente y agente |
| 2. Propuesta | 2 o 3 direcciones lado a lado, cada una con su referencia, y la oferta | Agente |
| 3. Construcción | El flujo de desarrollo de este playbook, con enlace de vista previa | Agente |
| 4. Ronda de cambios | El cliente comenta; el agente devuelve una lista numerada y el cliente la confirma antes de tocar código | Cliente, yo y agente |
| 5. Aprobación | El cliente aprueba la lista final; las rondas tienen un tope acordado de antemano | Cliente |
| 6. Entrega | Publicación y traspaso | Yo, con `devops` |

Cada ronda es un ticket "Ronda N" en el repo del proyecto, con una casilla por
cambio.

### Lo que sale hacia el cliente

- El HTML de propuesta se manda como archivo o enlace privado, nunca como
  artefacto publicado.
- Las auditorías dicen solo lo comprobable; no se inventan defectos.
- Los datos de clientes y prospectos van en tickets del repo privado `dashboard-clients` o
  en `*.local.md`; nunca en un repo público ni en búsquedas. Una propuesta en
  frío no se publica con la marca del negocio en un enlace abierto.
- Mi oferta (qué incluye, precio, rondas y plazo) y mi nicho los defino yo y
  viven fuera de los dotfiles, que son públicos.
- Los contactos en frío se mandan de a uno y personalizados. La normativa de
  contacto comercial está por verificar.

## Ramas y ambientes

Una sola rama de larga vida (*trunk-based*): `main` es producción. Cada ticket
va en una rama corta `tipo/descripcion` que vuelve a `main` en horas o días. No
hay rama `dev`: se desincroniza y obliga a mantener dos líneas. Si un proyecto
se sale de esto, lo dice su `AGENTS.md`.

Dos tickets a la vez van cada uno en su worktree, con un Builder por ticket; el
worktree se borra al mergear. Conviene elegir tickets que no toquen los mismos
archivos.

El ambiente bajo depende de dónde se publica:

| Destino | Ambiente bajo | Cómo llega a producción |
|---|---|---|
| Vercel o Cloudflare | Preview automático de cada rama, en su propia URL | Al mergear a `main` |
| Servidor propio (Docker) | Pre fijo: se actualiza solo con cada merge a `main` | Promoviendo a mano la misma imagen ya probada en pre |

En las dos: el CI (plantillas `git/ci-github.yml` y `git/ci-gitlab.yml`: busca
secretos, y corre linter, tests y build) bloquea el merge si falla; el preview o pre
usa su propia base de datos y claves de prueba, nunca las de producción; y
volver atrás es republicar la versión anterior. Un cambio que lleva semanas se
mergea por partes, apagado detrás de un interruptor, en vez de dejar la rama
abierta.

## Si pasa X, hago Y

| Si… | Entonces… | Hoy en Claude Code |
|---|---|---|
| Tengo una idea de proyecto | Ubicarme en el flujo y afilar la idea con una entrevista | `/ask-matt`, `/grill-with-docs` |
| Es chico | Una sesión, sin tickets | La skill de diseño que sugiera `/bibliotecario` |
| Es mediano | Especificación → tickets con dependencias → un ticket por vez | `/to-spec`, `/to-tickets`, `/implement` |
| Voy a aprobar una especificación (proyecto mediano o grande) | Pasarla por el `reviewer` (subagente, contexto limpio): qué supuestos no están dichos y qué quedó ambiguo. En uno chico no hace falta | agente `reviewer` |
| Tengo un bug mío | Anotarlo como ticket; si es chico, diagnosticarlo ahora | `/triage`, `diagnosing-bugs` |
| Me llega un bug o pedido de otro | Pasarlo por triage | `/triage` |
| Quiero una funcionalidad | Ticket primero, nunca directo al código; después su rama | `/to-tickets` |
| Hay varios tickets y no sé cuál | El que menos bloquea, o el más chico que funcione de punta a punta | — |
| Se me ocurre una mejora en el medio | Backlog | — |
| Quiero refactorizar | ¿Se repite 3 veces? Si no, no | `/simplify` |
| Quiero documentar o diagramar | ¿Entra en el presupuesto? Si no, backlog | `diagram-design` para el principal |
| Necesito entender algo abstracto (base de datos, arquitectura, infra) o elegir entre opciones visuales | Pedir un informe visual en HTML (`*.local.html`), descartable y sin commitear; siempre archivo local: el `deny` de `Artifact` en la configuración global impide publicarlo | — |
| No entiendo lo que escribió el agente | Parar y preguntarle qué hace y por qué, antes de commitear | — |
| El agente se equivoca 2 veces en lo mismo | Anotarlo en "Errores repetidos" del `AGENTS.md` del proyecto | — |
| El agente hace cosas que no pedí | Pararlo y repetir el límite: solo lo del ticket | `/simplify` |
| La sesión se puso larga y confusa | Cerrar y abrir otra con un resumen corto | `/ask-matt` indica cuándo cortar |
| Antes de cada commit | Simplificar el cambio | `/simplify` |
| Terminé de implementar un ticket | Correr el verifier antes del reviewer, para confirmar que el comportamiento real coincide con `plan.md` o los criterios | agente `verifier` |
| Antes de mergear una rama | CI en verde, probarlo en el preview o en pre, y revisión en contexto limpio | `/code-review`, agente `reviewer` |
| El explorer reporta un problema de seguridad | Es una hipótesis: confirmarla con el agente `security` o con una prueba antes de abrir un ticket | agente `security` |
| Cambio de riesgo (login, pagos, algo expuesto) | Auditoría de seguridad profunda | `claude-security`, `security-audit-skill` |
| Antes de publicar | Tests en verde y deploy con revisión previa | agente `devops`; en Cloudflare, el plugin `cloudflare`; `all-deploy` si lo habilitás con `/bibliotecario` |
| Siento que falta algo para que quede perfecto | Releer la definición de hecho; si se cumple, está terminado | — |

Los informes visuales sirven para decidir y entender, no para documentar: lo que
queda en el repo sigue en Markdown.

Al pedir cosas al agente, con límite: "solo lo del ticket", "sin documentación
nueva", "sin refactor".

## Detalles de oficio

- **Servidor de prueba:** en un puerto libre y cerrado al terminar: uno que queda
  abierto rompe las pruebas siguientes.
- **Video:** correr `ffprobe` sobre cada archivo antes de prometerlo en la
  página. El ffmpeg que trae Fedora no decodifica HEVC, así que los videos se
  piden en MP4 H.264.

## Revisión según el riesgo

| El cambio es… | Pasa por… |
|---|---|
| Un botón, texto, estilo | Builder, tests, simplificar, mirarlo en el navegador |
| Una funcionalidad normal | Lo anterior y Reviewer con checklist |
| Login, pagos, permisos, algo expuesto | Lo anterior y Security |

Lo repetible va con código (linter, tests, hooks) antes que con un agente: da
siempre el mismo resultado. La experiencia de usuario la juzgo yo, con capturas
si hace falta.
