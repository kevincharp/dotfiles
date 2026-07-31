# Idea: convertir el repo en un generador de dotfiles

> **Estado: PAUSADA** (julio 2026). No hay nada implementado de esto. Documento de
> diseño para retomar la discusión sin volver a razonarla de cero.
>
> Lo único que sí se implementó de esta línea de pensamiento es el **gate de
> configs por herramienta** (`want_tool` / `Test-ToolWanted`), que resolvió el
> síntoma más molesto sin cambiar la arquitectura. Ver
> [arquitectura.md](arquitectura.md#gate-por-herramienta).

## El problema que la origina

Hoy el repo hace **dos trabajos a la vez**:

1. Es el **instalador** (scripts, catálogo, selector).
2. Es **la config del autor** (mis atajos de GNOME, el serial de mi mouse en
   `openlogi/config.toml`, mis reglas de trabajo en `.claude/CLAUDE.md`).

Un tercero se lleva las dos cosas juntas. El gate por herramienta evitó que se
le *apliquen* configs que no pidió, pero el repo clonado en su home sigue siendo
mío, con carpetas que en su SO no se usan.

## La idea

La herramienta deja de ser "mi config que podés copiar" y pasa a ser **un
generador**: pregunta qué querés, y te construye **tu** dotfiles — solo con las
herramientas que elegiste, con tus datos — y te lo ofrece versionar en tu propia
cuenta de GitHub/GitLab.

El flujo pensado:

1. El tercero corre el one-liner.
2. La herramienta valida y resuelve dependencias (pwsh 7, winget, git…).
3. Pregunta qué herramientas quiere (catálogo).
4. Pregunta lo del vault (identidades git, claves SSH) — el asistente que ya existe.
5. **Genera su dotfiles** con lo que eligió, y crea los symlinks apuntando ahí.
6. Ofrece: *«¿Versionamos tu dotfiles en tu GitHub?»* → primer commit + push.

### Precedente: esto ya funciona para el vault

No es un invento. `git-profiles.sh` **ya hace exactamente este modelo**, aplicado
a un solo dominio:

- pregunta los contextos de trabajo del usuario,
- **genera** un vault con *sus* identidades (no copia el mío),
- lo commitea (`git-profiles.sh:391`),
- ofrece `gh repo create dotfiles-vault --private --source ... --push` (`:399`).

Generalizar ese patrón al resto del repo es la idea completa.

## Rename: el nombre es parte del problema

Si el producto es «generá tu dotfiles», llamar `dotfiles` a la herramienta es lo
que la hizo terminar haciendo dos trabajos. Separar los nombres separa los roles:

| Rol | Nombre | Dueño |
|---|---|---|
| La herramienta | `dotfiles-forge` / `mkdotfiles` (a definir) | el autor — se actualiza sola |
| La config generada | `~/.dotfiles` | **el usuario** — va a su GitHub |
| Los secretos | `~/.dotfiles-vault` | el usuario (ya funciona así hoy) |

Esto además **libera el nombre `~/.dotfiles`** para el usuario, que es donde
chezmoi, yadm y stow esperan encontrar *su* config. Hoy ese path lo ocupa el repo
del autor, y ahí nace la confusión.

Propuesta de ubicación de la herramienta, para no mezclarla con la config:

```
~/.local/share/dotfiles-forge/   → la herramienta
~/.dotfiles                      → SU config  → SU GitHub
~/.dotfiles-vault                → SU vault
```

## ¿La herramienta se queda o se borra?

Se discutieron las dos. **Conclusión: se queda**, por la expectativa del usuario
(como `winget update lazygit`: una herramienta se instala, se queda y se
actualiza).

Pero conviene tener claro que **no hay ningún impedimento técnico para borrarla**
—y esto se verificó, no se supuso:

- Los scripts (`bootstrap.sh`, `install.ps1`, `git-profiles.sh`, el catálogo) **no
  se leen nunca después de instalar**.
- Lo que hoy se lee en runtime desde `~/.dotfiles` es **contenido**, no la
  herramienta, y en este modelo se muda al repo del usuario:
  `statusline.sh` (`.claude/settings.json:8`), `git/gitignore-proyecto`
  (`bashrc:686`), `terminal/ptyxis.dconf` (`bashrc:1230`), `gnome/`
  (`bashrc:1277`).
- Lo único que se pierde al borrarla es el atajo de `install.sh:141` (si existe
  `.git`, hace `git pull` en vez de clonar). Resoluble: el one-liner ya viene de
  la red y puede clonarse a un temporal — es lo que `install.ps1` ya hace con
  `$env:TEMP`.

O sea: que se quede es una **decisión de producto** (UX de actualización), no una
necesidad técnica.

## El problema difícil: updates sin pisar los cambios del usuario

Es la pregunta que hay que resolver **antes** de escribir código: si arreglo un
bug en el `bashrc`, ¿cómo le llega a alguien que generó su repo hace seis meses y
mientras tanto lo editó?

Hoy no hay forma de saberlo: solo existen **dos estados** (lo que dice la
plantilla y lo que hay en el disco). Con dos no se distingue «el usuario lo
cambió» de «la plantilla cambió».

### Solución propuesta: guardar el hash de lo generado

Al generar cada archivo, guardar el hash de lo que se generó. Eso da un **tercer
punto de comparación** y la decisión sale sola:

| ¿Disco ≠ hash guardado? | ¿Cambió la plantilla? | Acción |
|---|---|---|
| No | Sí | **Actualizar solo** (el usuario no lo tocó) |
| Sí | No | **No tocar** (es cambio suyo) |
| No | No | Nada |
| Sí | Sí | **Conflicto** → mostrar diff y preguntar |

Es el mecanismo de `dpkg`/`rpm` con los archivos de config, y el de `chezmoi` con
su estado. Solo el último caso molesta al usuario, y es el único con ambigüedad
real.

Un `.forge-state.json` en el repo del usuario:

```json
{
  "tool_version": "1.4.0",
  "files": {
    "shell/bashrc":  { "hash": "a3f2…", "template": "shell/bashrc@1.4.0" },
    "nvim/init.lua": { "hash": "9c1e…", "template": "nvim/init.lua@1.2.0" }
  }
}
```

**Matiz importante:** los symlinks ya resuelven parte de esto. Si `~/.bashrc` es
un symlink al repo del usuario y él edita el archivo, el cambio queda en su repo
y **`git status` ya se lo dice** — no hacen falta hashes. Los hashes hacen falta
para lo que se **copia** y para saber de qué versión de plantilla vino cada
archivo. Conviene apoyarse en git en vez de duplicar lo que ya hace.

### Dos comandos, no uno

`update.sh` hoy hace `exec install.sh`: re-corre el bootstrap entero. En este
modelo son dos cosas distintas:

- **`forge self-update`** → actualizar la herramienta (o directamente el gestor de
  paquetes, si algún día se publica en winget/dnf/brew).
- **`forge update`** → traer mejoras de plantilla a mi config, con la tabla de
  arriba y sin pisar nada en silencio.

## Triage por herramienta (la parte tediosa)

El vault es fácil de generar porque es **plantilla**: cuatro archivos con nombres
y emails. Las configs del repo **no lo son** — son configs concretas con cosas
cableadas adentro. Por cada herramienta hay que decidir una de tres cosas.

Clasificación propuesta del catálogo actual (~30, revisar al retomar):

### Copiar tal cual — buenos defaults, nada personal adentro

`neovim` (kickstart), `yazi`, `lazygit`, `fontconfig`, `.editorconfig`,
`git/ignore`, tema de oh-my-posh, Windows Terminal.

### Generar preguntando — hay datos del usuario

- **git / identidades** → ya lo hace `git-profiles.sh`.
- **shells** (`bashrc`/`zshrc`/`profile.ps1`) → ver «el caso incómodo» abajo.
- Posible: tema/paleta del prompt, carpeta de repos (`~/repositorios`).

### No copiar / omitir — es config del autor, inútil o molesta para un tercero

- `openlogi/config.toml` — tiene el **serial de mi mouse** y el `unit_id` del
  receptor incrustados en las claves.
- `gnome/*.dconf` — **mis** atajos, mi dock, mis extensiones.
- `terminal/ptyxis.dconf` — mi terminal, mis colores.
- `.claude/CLAUDE.md` — **mis reglas de trabajo** (proyectos en `~/repositorios/`,
  `ginit` con perfiles del vault, responder en español).
- `.claude/settings.json` — apunta a mi `statusline.sh` y a mis plugins.
- `ulauncher/settings.json` — mi tema, mi opacidad, mis shortcuts.

### El caso incómodo: los shells

`shell/bashrc` son ~200 KB con **todas** las funciones. Dos opciones, ninguna
gratis:

1. **Copiar entero** — simple, pero el usuario se lleva `ptyxis-save` sin tener
   Ptyxis, `icloud-mount` sin rclone, etc. Funciones muertas pero inofensivas
   (casi todas ya están gateadas por `has_cmd` adentro).
2. **Partir en módulos por herramienta** — correcto, pero es un refactor grande y
   hay que mantener la **paridad bash↔zsh↔pwsh** que ya cuesta hoy
   (`test-bootstrap.sh` la verifica).

Recomendación al retomar: arrancar por (1) y modularizar después solo si molesta.

## Orden de las preguntas

Corrección de secuencia respecto del flujo actual: hoy el vault se pregunta
**antes** del selector de herramientas. Conviene al revés — si el usuario no
elige `git`, no tiene sentido preguntarle por identidades git ni claves SSH.

## Plan sugerido para retomar

1. Resolver **primero** el mecanismo de update (la tabla de hashes). Si se define
   mal, obliga a rehacer todo lo demás.
2. Decidir el rename y los paths definitivos.
3. Cerrar el triage de las ~30 herramientas (la tabla de arriba, revisada).
4. Implementar por etapas, empezando por las de «copiar tal cual» (nvim, yazi,
   terminal, fontconfig) y dejando shells y GNOME para el final.
5. Definir qué pasa al re-correr el one-liner cuando el usuario **ya tiene** su
   repo generado.

## Referencias

- `git-profiles.sh` / `.ps1` — el precedente que ya implementa este modelo para
  el vault. Es el mejor punto de partida para leer antes de retomar.
- [arquitectura.md](arquitectura.md#gate-por-herramienta) — el gate por
  herramienta, lo que sí se implementó de esta línea.
- [chezmoi](https://www.chezmoi.io) — resuelve el problema de updates con
  plantillas + `chezmoi diff`. Vale mirar cómo modela el estado antes de
  inventar algo propio.
