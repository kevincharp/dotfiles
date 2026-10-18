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
- **Mensaje breve:** una sola línea que diga el qué, sin cuerpo explicativo; la
  historia larga va a `docs/`.
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

## Worktrees (trabajo en paralelo con varios agentes)

`~/repositorios/<contexto>/` tiene **una entrada por repositorio**: un worktree
nunca se crea como carpeta hermana suelta del repo.

- **Ruta:** `~/repositorios/<contexto>/<proyecto>-worktrees/<rol>/`, dentro de la
  misma carpeta de contexto (así sigue aplicando la identidad git). El repo
  principal queda en `~/repositorios/<contexto>/<proyecto>/`.
- **Ramas:** `agent/<rol>` por worktree, e `integration` para unir el trabajo.
- **Artefactos** (AppImage, zips, binarios de prueba) en
  `<proyecto>-worktrees/artefactos/`, **nunca en `/tmp`** (es tmpfs: se vacía al
  reiniciar).
- **Efímeros** (diagnóstico, verificación): prefijo `tmp-` en la misma carpeta, y
  `git worktree remove` al terminar.
- **No mover un worktree con una sesión de agente abierta adentro**: cerrar todas
  antes de `git worktree move`. Acertar la ruta al crearlo evita moverlo después.
- **Mover cuesta caro:** las sesiones de Claude Code se guardan por ruta (el
  `--continue` pierde las conversaciones) y en proyectos Rust hay que hacer
  `cargo clean` en el worktree movido (`target/` guarda rutas absolutas).
- **Peso:** cada worktree trae su propio `node_modules` y `target/`. Con muchos
  de Rust, considerar un `CARGO_TARGET_DIR` compartido. Al revisar el proyecto,
  mirar `git worktree list` y los tamaños.

## Código

- **Comentarios cortos, con el porqué:** un comentario explica lo que no es
  obvio del código, en 1 a 3 líneas. Si hace falta más de ~6 líneas seguidas,
  sobra o va a `docs/`.
- **No narrar la historia:** intentos descartados, hallazgos y "probé X y falló"
  van en `docs/` (el commit lleva solo el qué), no en el código.
- **Sin código desactivado:** no dejar bloques comentados "por si acaso"; se
  borran y git los recuerda.
- **Hacer solo lo pedido:** sin funciones, parámetros, opciones ni capas de
  abstracción que nadie use todavía; lo que quede sin uso se borra.
- **Sin defensas imaginarias:** nada de validaciones ni manejo de errores para
  casos que no pueden ocurrir, ni docstrings en todo; nombres del dominio, no
  genéricos (`data`, `result`, `handler`).
- **Antes del commit, pasar `/simplify`** sobre el cambio (Claude Code); en otros
  agentes, releer el diff buscando lo mismo: duplicación, código de más y
  comentarios que sobran.

## Proyectos nuevos

- Crearlos bajo la **carpeta de contexto** que corresponda en `~/repositorios/`
  (la carpeta define qué identidad git aplica). Si el contexto no se deduce del
  pedido, **preguntar antes de crear nada**.
- Inicializar con **`ginit <perfil>`** — nunca `git init` pelado: aplica la
  identidad del vault y deja un `.gitignore` base (plantilla
  `git/gitignore-proyecto` de los dotfiles). Al clonar: `gclone <url> [dir]`
  (deduce el perfil; `-p <perfil>` lo fuerza).
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
  mínimo (qué es, cómo correr, cómo probar): corto y concreto, sin emojis ni
  listas de "características" infladas.
- Si el proyecto tiene lógica, llevar **tests y un workflow de CI** que los corra
  desde el primer commit; no darlo por terminado si fallan.

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
- **Deploy: Vercel y Cloudflare son mis plataformas por defecto** (Cloudflare
  para DNS/dominios/Workers/Pages, Vercel para frontends). Ante un despliegue
  nuevo sin destino explícito, proponer una de estas dos antes que otra opción
  (Railway, Docker+VPS, etc.).
