-- ============================================================================
-- treesitter.lua — resaltado de sintaxis preciso (motor Tree-sitter)
-- ============================================================================
-- Tree-sitter analiza el código como un árbol sintáctico real (no con regex,
-- como el highlighter viejo de vim). De ahí sale el resaltado preciso tipo
-- VSCode, la indentación inteligente y la selección por bloque semántico.
--
-- Cada lenguaje necesita un "parser" (código C que se compila en la máquina).
-- En Linux ya hay gcc; en Windows hace falta un compilador C (zig o MSVC) — ver
-- la nota en CLAUDE.md. Los parsers se instalan en el data-dir, fuera del repo.
--
-- build = ':TSUpdate' → tras instalar/actualizar el plugin, recompila parsers.
-- ============================================================================

return {
  'nvim-treesitter/nvim-treesitter',
  -- OJO: el repo tiene dos ramas con APIs INCOMPATIBLES. 'main' es una reescritura
  -- nueva (aún inestable, otra API); 'master' es la estable y probada (la que usa
  -- kickstart). Fijamos 'master' a propósito: si no, lazy baja 'main' y esta config
  -- (require 'nvim-treesitter.configs') no existe ahí y rompe el arranque.
  branch = 'master',
  build = ':TSUpdate',
  main = 'nvim-treesitter.configs', -- módulo que recibe el opts de abajo
  opts = {
    -- Parsers a instalar automáticamente. Cubren el stack decidido:
    -- Web (JS/TS/React, HTML, CSS), Python, Shell/Bash y Lua (para el propio nvim).
    ensure_installed = {
      'javascript',
      'typescript',
      'tsx',        -- React (.tsx)
      'html',
      'css',
      'json',
      'python',
      'bash',       -- scripts de shell (bashrc/zshrc del repo)
      'lua',        -- la propia config de nvim
      'vim',        -- vimscript embebido
      'vimdoc',     -- ayuda de nvim (:help)
      'markdown',   -- READMEs y docs del repo
      'markdown_inline',
      'diff',       -- resaltado de diffs de git
      'gitcommit',  -- mensajes de commit
      'yaml',
      'toml',       -- configs .toml (yazi, etc.)
    },

    -- Instalar los parsers que falten al abrir nvim (sin bloquear el arranque).
    auto_install = true,

    highlight = {
      enable = true,
      -- No mezclar con el resaltado regex viejo de vim (evita doble-render y
      -- colores inconsistentes). Con esto manda solo tree-sitter.
      additional_vim_regex_highlighting = false,
    },

    -- Indentación basada en el árbol sintáctico (más lista que la de vim).
    indent = { enable = true },
  },
}
