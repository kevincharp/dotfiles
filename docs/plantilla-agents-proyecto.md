# Plantilla de `AGENTS.md` de proyecto

Base del `AGENTS.md` de cada proyecto nuevo. Lo leen Claude Code, Codex y
opencode, así que no hay que mantener un archivo por herramienta. Las reglas generales (commits, comentarios, secretos) ya viven en
el archivo global; este lleva solo lo propio del proyecto.

Lo usan sobre todo el Builder y el Revisor ([`molde-agente.md`](molde-agente.md)):
sin los comandos de test, el Builder adivina cómo probar el código.

**Verificado:** Claude Code lee un `AGENTS.md` de proyecto aunque exista el
`CLAUDE.md` global (probado en la versión instalada). Si algún día deja de
hacerlo, el arreglo es un `CLAUDE.md` de una línea con `@AGENTS.md`.

## Plantilla

Vive en [`git/agents-proyecto.md`](../git/agents-proyecto.md) (el archivo que
copia `ginit`), junto a `git/gitignore-proyecto`. Editarla ahí cambia los
proyectos nuevos; los ya creados no se tocan.

## Cómo usarla

1. `ginit` la copia como `AGENTS.md` al crear el proyecto (nunca pisa uno
   existente).
2. El agente la completa en la primera sesión, con lo que cuentes del proyecto;
   lo que no se sabe se deja para cuando aparezca. La primera línea avisa que
   falta completarlo y se borra al terminar.
3. Dejar el archivo corto: si una regla es general, va al archivo global.
