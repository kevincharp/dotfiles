# Reglas globales — agentes de IA (todos los proyectos)

Archivo único de reglas para cualquier agente: Claude Code lo lee como
`~/.claude/CLAUDE.md`; Codex y opencode lo leen como `AGENTS.md` (symlinks que
crea el bootstrap). Editar acá rige para todos.

## Idioma

- **Responder siempre en español.**
- Comentarios, docs y mensajes de commit **en español** (los identificadores
  del código siguen la convención del proyecto/lenguaje).

## Commits

- **Granulares:** uno por cambio lógico (separar por archivo/propósito).
- **Conventional Commits:** `tipo(scope): descripción` (`feat`, `fix`, `docs`,
  `refactor`, `chore`…).
- **En español.**
- **Sin** línea `Co-Authored-By` ni trailer de coautoría.
- **Commitear sin pedir autorización** tras cada cambio lógico terminado.
- **Nunca pushear:** el push lo hace el usuario manualmente.

## Git

- No crear ramas salvo pedido explícito.
- No reescribir historial ya publicado (rebase/amend de commits pusheados) ni
  usar `--force`; si un push forzado fuera imprescindible, `--force-with-lease`
  y solo a pedido.
- No commitear archivos ajenos al cambio (stagear por path, no `git add -A` a
  ciegas).

## Secretos

- Jamás commitear tokens, claves, ni datos de infra privada (account IDs, URLs
  internas de la empresa): van a `~/.env` o al vault privado.
- Si un secreto aparece en un diff o una salida, avisar en vez de propagarlo.

## Verificación

- Tras tocar código, correr la validación que el repo ya tenga (tests, linters,
  chequeos de sintaxis) antes de dar el cambio por terminado.
- No reportar algo como hecho/funcionando sin haberlo verificado; si no se pudo
  verificar (p. ej. requiere otro SO), decirlo explícitamente.
