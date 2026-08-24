-- ============================================================================
-- treesitter.lua — resaltado de sintaxis preciso (motor Tree-sitter)
-- ============================================================================
-- Tree-sitter analiza el código como un árbol sintáctico real (no con regex,
-- como el highlighter viejo de vim). De ahí sale el resaltado preciso tipo
-- VSCode, la indentación inteligente, los pliegues (folds) y la selección por
-- bloque semántico. Lo consumen además dropbar, aerial, autopairs, ts-autotag y
-- render-markdown.
--
-- ---------------------------------------------------------------------------
-- POR QUÉ ESTE ARCHIVO USA LA RAMA 'main' (y antes decía lo contrario)
-- ---------------------------------------------------------------------------
-- El repo tiene dos ramas con APIs INCOMPATIBLES. Hasta acá esta config fijaba
-- 'master', que era el consejo correcto cuando se escribió. Ya no lo es:
--
--   * 'master' está CONGELADA y su propio README declara nvim 0.12 no soportado.
--   * Rompe de verdad, no en teoría: abrir cualquier .md con un bloque de código
--     con lenguaje (```lua) tiraba un error de query_predicates.lua:141,
--     "attempt to call method 'range' (a nil value)". La causa es que en nvim
--     0.11+ `match[capture_id]` pasó a ser una LISTA de nodos y la rama congelada
--     lo sigue tratando como un nodo solo. Se reproducía sin ningún otro plugin
--     en juego, así que no había forma de esquivarlo desde acá.
--   * Y su instalador de parsers depende de tarballs que ya devuelven 404 (por eso
--     el parser 'jsonc' era imposible de bajar).
--
-- La migración NO es cambiar una línea: 'main' no configura nada por opts, no
-- prende el resaltado sola y no soporta carga diferida. De ahí la forma de abajo.
--
-- ---------------------------------------------------------------------------
-- QUÉ NECESITA LA MÁQUINA
-- ---------------------------------------------------------------------------
-- 'main' compila los parsers con el CLI de tree-sitter, así que suma una
-- dependencia externa nueva: `tree-sitter-cli` (>= 0.25). Se instala por gestor
-- de paquetes, NO por npm — en Fedora está en los repos base (dnf install
-- tree-sitter-cli) y el bootstrap lo agrega junto con neovim. Más un compilador C:
-- en Linux ya hay gcc; en Windows hace falta zig o MSVC.
-- ============================================================================

-- Parsers a instalar. Cubren el stack decidido: Web (JS/TS/React, HTML, CSS),
-- Python, Shell/Bash, Lua (la propia config), Docker, SQL y los formatos de datos
-- y documentación del repo.
local PARSERS = {
  'javascript',
  'typescript',
  'tsx',        -- React (.tsx)
  'html',
  'css',
  'json',        -- también cubre jsonc (tsconfig.json): en 'main' el filetype
                 -- 'jsonc' resuelve al parser 'json', no hay parser aparte
                 -- (verificado con vim.treesitter.language.get_lang). Justo lo que
                 -- en 'master' era imposible porque el tarball de 'jsonc' da 404.
  'python',
  'bash',       -- scripts de shell (bashrc/zshrc del repo)
  'lua',        -- la propia config de nvim
  'luadoc',     -- las anotaciones ---@param de Lua
  'vim',        -- vimscript embebido
  'vimdoc',     -- ayuda de nvim (:help)
  'markdown',   -- READMEs y docs del repo
  'markdown_inline',
  'diff',       -- resaltado de diffs de git
  'gitcommit',  -- mensajes de commit
  'yaml',
  'toml',       -- configs .toml (yazi, etc.)
  'dockerfile', -- Dockerfile (los compose usan el parser de yaml)
  'sql',        -- consultas .sql
  'query',      -- los .scm de tree-sitter (para depurar queries)
  'regex',      -- resalta las expresiones regulares embebidas en otros lenguajes
}

return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  -- lazy = false es OBLIGATORIO, no una preferencia: 'main' no declara eventos ni
  -- soporta que lazy.nvim la cargue a demanda (lo dice su propio README).
  lazy = false,
  -- Al actualizar el plugin, recompilar los parsers con el CLI nuevo.
  build = ':TSUpdate',
  config = function()
    local ts = require('nvim-treesitter')

    ts.setup({
      -- Los parsers van al data-dir, FUERA del repo (no se versionan: son
      -- binarios compilados para esta máquina y este SO).
      install_dir = vim.fn.stdpath('data') .. '/site',
    })

    -- Instalar lo que falte. install() es ASÍNCRONA en 'main', así que no bloquea
    -- el arranque; los parsers nuevos quedan listos para el próximo archivo que
    -- abras de ese lenguaje. Es el reemplazo del auto_install de 'master'.
    ts.install(PARSERS)

    -- ---------------------------------------------------------------------
    -- Prender el resaltado y la indentación. En 'master' esto era
    -- `highlight = { enable = true }`; en 'main' no existe: hay que llamar a
    -- vim.treesitter.start() por buffer, y el lugar correcto es un FileType.
    -- ---------------------------------------------------------------------
    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('treesitter-arranque', { clear = true }),
      callback = function(ev)
        local ft = vim.bo[ev.buf].filetype
        -- El filetype no siempre se llama igual que el lenguaje: 'sh' usa el
        -- parser 'bash', y los compuestos como 'yaml.docker-compose' resuelven a
        -- 'yaml'. get_lang() hace esa traducción.
        local lang = vim.treesitter.language.get_lang(ft)
        if not lang then
          return
        end
        -- pcall porque si el parser todavía no terminó de instalarse (o el
        -- lenguaje no está en la lista), start() lanza error y abortaría el
        -- FileType entero — o sea, se caería el resto de la config del buffer.
        if not pcall(vim.treesitter.start, ev.buf, lang) then
          return
        end
        -- Indentación por árbol sintáctico. Es OPCIONAL en 'main' (y su README la
        -- marca como experimental), pero es lo que en 'master' venía en
        -- `indent = { enable = true }` y se usa a diario con `==` y `=`.
        vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
