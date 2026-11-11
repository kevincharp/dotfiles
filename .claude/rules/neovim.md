---
paths:
  - "nvim/**"
---

# Neovim (`nvim/`)

Editor de código **principal** (VSCode queda como complemento para lo que nvim
hace peor, no como reemplazo). Config propia estilo kickstart: `init.lua` +
`lua/` (opciones, atajos, tipos-archivo, gestor) y **un archivo por plugin** en
`lua/plugins/`. Sumar un plugin = crear un archivo; sacarlo = borrarlo.

- **Symlink de DIRECTORIO, con path distinto por SO:** Linux →
  `~/.config/nvim`; Windows → **`%LOCALAPPDATA%\nvim`** (o
  `$env:XDG_CONFIG_HOME\nvim` si esa variable existe — Neovim la respeta
  también en Windows). Tiene que ser el directorio entero, no archivo por
  archivo, porque lazy.nvim escribe `lazy-lock.json` adentro.
- **Gateado por el selector:** si no elegiste neovim, el bootstrap NO crea el
  link.
- **En Windows el symlink necesita Modo de desarrollador.** Si está apagado, el
  paso se omite con WARN y nvim arranca con defaults (síntoma indistinguible de
  "nvim roto": sin tema, sin números de línea).
- **`lazy-lock.json` SE VERSIONA:** mismos plugins en la misma versión en
  Linux y Windows. Flujo al tocar plugins: `:Lazy sync` y **commitear el lock
  en su propio commit** (`chore(nvim): fijar …`).
- **Nada de lo que baja se versiona:** plugins, parsers de treesitter y
  binarios de Mason viven en el data-dir (`~/.local/share/nvim`).

## Requisitos de máquina

- **`tree-sitter-cli`** (>= 0.25): compila los parsers de la rama `main` de
  nvim-treesitter. Sin esto, **no hay resaltado de sintaxis**.
- **Compilador C:** Linux ya tiene gcc. Windows usa **zig** + un shim propio
  (`nvim/windows-cc-shim.c`, compilado a `~/.local/bin/cc.exe`) porque
  `tree-sitter-cli` invoca literalmente `cc` y no entiende `CC="zig cc"` como
  dos palabras — mecanismo completo (y por qué el target triple se reescribe):
  [`docs/notas-tecnicas.md`](../../docs/notas-tecnicas.md#compilador-c-en-windows-por-qué-zig--shim-no-msvc).
  `CC=cc` queda seteada a nivel de usuario — afecta cualquier otra herramienta
  que lea `CC` en esa máquina, aceptado a propósito.
- **node** para varios servidores de Mason. Detrás del proxy corporativo
  algunos paquetes no bajan; el síntoma es un servidor que nunca aparece.

## Atajos: dos reglas que ya nos mordieron

1. **Los nativos ganan.** No se pisan las teclas de vim ni las de nvim 0.12:
   `[b`/`]b`, `[q`/`]q`, `[t`/`]t`, `[c`/`]c`, `grn`/`gra`/`grr`/`gri`, `gO`, `K`,
   `gc`. Por eso todo lo propio vive detrás del líder (espacio), los saltos de
   pendientes NO usan `]t`/`[t` y el contexto fijo NO usa `[c`.
2. **Un atajo suelto BLOQUEA todo su prefijo.** Si `<leader>f` es una acción
   terminada, no puede existir `<leader>ff`. Pasó dos veces: el formateo se mudó
   de `<leader>f` a `<leader>cf` para liberar el grupo "buscar", y las sesiones
   usan `<leader>p` en vez del `<leader>q` que sugiere su README porque
   `<leader>q` ya es "cerrar ventana".

**Antes de crear un atajo hay que verificarlo sobre los mapeos REALES**, no de
memoria: `nvim --headless -u ~/.config/nvim/init.lua` + `nvim_get_keymap('n')`
filtrando por el prefijo. Y ojo con quién se queda la tecla primero: el
**terminal** (Alt+1..9 son las pestañas de Ptyxis, Ctrl+PageUp/Down son del
terminal) y **GNOME** (`Ctrl+Space` es Ulauncher).

## treesitter usa la rama `main`

`master` está congelada y rompe en nvim 0.12 — por eso `main`, que exige
`lazy = false` (no soporta carga diferida). Detalle de la migración forzada:
[`docs/notas-tecnicas.md`](../../docs/notas-tecnicas.md#treesitter-en-rama-main-no-master).

- **Filetypes compuestos:** los compose se detectan como `yaml.docker-compose`
  (ver `lua/tipos-archivo.lua`) para que les enganchen **los dos** servidores
  (yamlls con su esquema + docker_compose_language_service). conform resuelve
  por el filetype **entero** — nombrarlo tal cual en `formatters_by_ft`. Para
  treesitter, `vim.treesitter.language.get_lang()` traduce
  (`yaml.docker-compose`→`yaml`, `sh`→`bash`, `jsonc`→`json`).

## Ausencias deliberadas (no son olvidos)

Cada una está documentada en su archivo: **Telescope** (el picker es snacks),
**dashboard**, **DAP/debugger** y **runner de tests** (se descartaron
explícitamente), **sqls** (necesita un `config.yml` con la cadena de conexión, y
esto es un repo público), **dockerfmt** (se compila con Go, que no está; formatea
dockerls vía el `lsp_format = 'fallback'` de conform).

**Windows pendiente:** `vim.o.shell` sigue en `cmd.exe` (no se pasó a pwsh) y
nada de esto se puede verificar desde Linux.

## Verificar cambios de nvim sin abrir nvim

Se prueba **headless** contra un fixture, comparando contra la realidad (extmarks,
mapeos, items del picker), no contra el README del plugin. Dos trampas:

- **Un error dentro de `vim.defer_fn`/`vim.schedule` se come el `qa!`** y nvim
  headless, sin UI, **se cuelga para siempre**. Siempre `pcall` alrededor del
  cuerpo del test y `timeout 90` alrededor del comando.
- **El setup de un plugin de lazy.nvim es DIFERIDO:** en el mismo tick en que
  lazy lo carga, su config todavía no está armada (verificado con
  todo-comments: `config.search_regex` es `nil` y aparece un tick después). Si un
  atajo es lo que dispara la carga y necesita algo del setup, va dentro de
  `vim.schedule`.
