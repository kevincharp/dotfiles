# Molde de agente y equipo estándar

Cómo se define un agente y qué equipo uso. Es **proceso, no herramienta**: vale
igual con Claude Code, Codex u opencode. El archivo concreto de cada
herramienta es un adaptador fino que copia estos campos (ver al final).

**Estado:** diseñado, sin probar todavía en un proyecto real.

## Cuándo vale la pena un agente aparte

Solo si se cumplen **las dos**:

1. Necesita permisos, herramientas o contexto distintos (p. ej. un revisor que
   **no puede editar** y arranca con contexto limpio).
2. Un error se repitió 3 veces y ni una línea de checklist ni un chequeo
   automático (linter, test, hook) lo habría evitado.

Si no, es una sección de un checklist. Saber de frontend o de backend es
**conocimiento**, no un permiso: va como sección del `CLAUDE.md` del proyecto.

## Molde

Todo agente se escribe con estos campos, en este orden:

- **Nombre y para qué:** una línea.
- **Cuándo se usa / cuándo no.**
- **Recibe:** un ticket (historia, criterios de aceptación, fuera de alcance).
- **Puede / no puede:** herramientas y permisos.
- **Nunca hace:** los límites duros.
- **Devuelve:** formato fijo y corto.
- **Hecho cuando:** la definición de hecho.

El traspaso entre agentes es siempre el mismo: entra un ticket, sale un
resumen. Es lo que evita que se pierda información entre agentes.

## Equipo estándar

| Agente | Qué lo distingue | Edita |
|---|---|---|
| Orquestador | Conversa conmigo y delega; lee resúmenes, no diffs | No |
| Explorador | Contexto aparte; investiga y resume | No |
| Builder | Implementa un ticket con TDD | Código |
| Revisor | Contexto limpio; checklist | No |
| DevOps | Acciones hacia afuera; confirma antes de cada una | Solo infra y deploy |
| Seguridad | Auditoría profunda, a demanda en cambios de riesgo | No |
| Documentador (opcional) | Solo `docs/` y `.md`; por hito, no por ticket | Solo documentación |

El Documentador entra únicamente si al cerrar hitos nadie documenta. Mientras
tanto lo hace el Builder como última tarea del hito.

Frontend y backend **no son agentes**: son secciones del `CLAUDE.md` del
proyecto. Se separan solo si un mismo proyecto tiene ambos con stacks muy
distintos y el contexto se llena con las dos cosas.

## Ejemplo: Builder

- **Para qué:** implementar un ticket.
- **Se usa:** hay un ticket con criterios de aceptación. **No:** idea sin
  ticket, o refactor que no está en el ticket.
- **Recibe:** el ticket y las reglas del `CLAUDE.md` del proyecto.
- **Puede:** leer y editar código, correr tests. **No puede:** commitear sin
  que pase la definición de hecho, tocar `docs/` salvo el README.
- **Nunca:** agrega lo que no está en el ticket, cambia un test para que pase,
  hace refactor mezclado con funcionalidad, escribe documentación nueva.
- **Devuelve:** qué cambió (archivos), qué decidió por su cuenta, qué dejó
  fuera. Máximo 10 líneas.
- **Hecho cuando:** cumple los criterios, los tests pasan, pasó la
  simplificación y está commiteado.

## Adaptadores por herramienta

| Herramienta | Dónde vive cada agente | Estado |
|---|---|---|
| Claude Code | Markdown con frontmatter (`name`, `description`, `tools`, `model`); empaquetado como plugin en este repo | A escribir |
| opencode | Markdown con frontmatter propio | Campos sin verificar |
| Codex | Formato propio | Sin verificar |

Los campos del molde se traducen uno a uno; lo que cambia es la sintaxis.
