# Reglas globales — agentes de IA (todos los proyectos)

Archivo único de reglas para cualquier agente: Claude Code lo lee como
`~/.claude/CLAUDE.md`; Codex y opencode lo leen como `AGENTS.md` (symlinks que
crea el bootstrap). Editar acá rige para todos.

Estructura: todo lo de arriba es **base funcional** — sirve tal cual para
cualquiera que adopte estos dotfiles porque se apoya en los mecanismos del repo
(perfiles del vault, helpers de shell), no en nombres propios. La última
sección, **Preferencias**, es personal: editala a tu gusto.

## Commits

- **Granulares:** uno por cambio lógico (separar por archivo/propósito).
- **Conventional Commits:** `tipo(scope): descripción` (`feat`, `fix`, `docs`,
  `refactor`, `chore`…).
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

## Proyectos nuevos

- Crearlos bajo la **carpeta de contexto** que corresponda en `~/repositorios/`
  (la carpeta define qué identidad git aplica). Si el contexto no se deduce del
  pedido, **preguntar antes de crear nada**.
- Inicializar con **`ginit <perfil>`** — nunca `git init` pelado: aplica la
  identidad del vault y deja un `.gitignore` base (plantilla
  `git/gitignore-proyecto` de los dotfiles). Al clonar: `gclone -p <perfil>`.
  Si el shell no tiene esas funciones, los perfiles están en
  `~/.config/git-identities.sh` (o `.ps1`) para aplicar con
  `git config --local`.
- Si un commit falla por identidad ausente (`useConfigOnly` está activo), es un
  perfil sin aplicar: corregir con `gset-profile <perfil>` — **no** setear
  `user.name`/`user.email` a mano con cualquier valor.
- Los remotes se dan de alta con el **host alias SSH** del perfil
  (`gremote <alias> <namespace/repo>`), nunca `github.com`/`gitlab.com`
  pelados (no enganchan la clave correcta).
- Completar el `.gitignore` con lo específico del stack y crear un README
  mínimo (qué es, cómo correr, cómo probar).

## Secretos

- Jamás commitear tokens, claves, ni datos de infra privada (account IDs, URLs
  internas): van a `~/.env` o al vault privado.
- Si un secreto aparece en un diff o una salida, avisar en vez de propagarlo.

## Verificación

- Tras tocar código, correr la validación que el repo ya tenga (tests, linters,
  chequeos de sintaxis) antes de dar el cambio por terminado.
- No reportar algo como hecho/funcionando sin haberlo verificado; si no se pudo
  verificar (p. ej. requiere otro SO), decirlo explícitamente.

## Preferencias (editá a tu gusto)

- **Responder siempre en español.**
- Comentarios, docs y mensajes de commit **en español** (los identificadores
  del código siguen la convención del proyecto/lenguaje).
