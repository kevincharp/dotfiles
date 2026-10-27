# Plantilla de `AGENTS.md` de proyecto

Se copia a la raíz de cada proyecto nuevo como `AGENTS.md` y se completa. Lo
leen Claude Code, Codex y opencode, así que no hay que mantener un archivo por
herramienta. Las reglas generales (commits, comentarios, secretos) ya viven en
el archivo global; este lleva solo lo propio del proyecto.

Lo usan sobre todo el Builder y el Revisor ([`molde-agente.md`](molde-agente.md)):
sin los comandos de test, el Builder adivina cómo probar el código.

**Verificado:** Claude Code lee un `AGENTS.md` de proyecto aunque exista el
`CLAUDE.md` global (probado en la versión instalada). Si algún día deja de
hacerlo, el arreglo es un `CLAUDE.md` de una línea con `@AGENTS.md`.

## Plantilla

```markdown
# <Nombre del proyecto>

<Qué es y para quién, en una o dos líneas.>

## Cómo correr y probar

- Correr: `<comando>`
- Tests: `<comando>`
- Linter o chequeos: `<comando>` (si hay)

## Stack

<Lenguaje, framework, base de datos, dónde se publica.>

## Definición de hecho

1. Cumple los criterios de aceptación del ticket.
2. Los tests pasan.
3. El cambio quedó simplificado.
4. Está commiteado.

## Frontend

<Reglas propias: framework, estilos, componentes, accesibilidad. Borrar la
sección si el proyecto no tiene frontend.>

## Backend

<Reglas propias: estructura, manejo de datos, errores. Borrar la sección si el
proyecto no tiene backend.>

## Fuera de alcance

<Lo que este proyecto NO va a hacer, para que nadie lo agregue.>

## Estacionamiento

<Ideas y mejoras que aparecieron mientras se trabajaba y no entran ahora.>
```

## Cómo usarla

1. Al crear el proyecto con `ginit`, copiar la plantilla como `AGENTS.md`.
2. Completar solo lo que se sabe; lo demás se agrega cuando aparece.
3. Dejar el archivo corto: si una regla es general, va al archivo global.
