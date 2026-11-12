-- ============================================================================
-- treesitter.lua — resaltado de sintaxis preciso (Tree-sitter)
-- ============================================================================
-- Rama 'main': 'master' está congelada y rompe en nvim 0.12. No soporta carga
-- diferida y compila los parsers con tree-sitter-cli (>= 0.25) + un compilador C.
-- Detalle: docs/notas-tecnicas.md (treesitter en rama main).
-- ============================================================================

local PARSERS = {
  'javascript',
  'typescript',
  'tsx',
  'html',
  'css',
  'json', -- también cubre jsonc
  'python',
  'bash',
  'lua',
  'luadoc',
  'vim',
  'vimdoc',
  'markdown',
  'markdown_inline',
  'diff',
  'gitcommit',
  'yaml',
  'toml',
  'dockerfile', -- los compose usan el parser de yaml
  'sql',
  'query', -- los .scm de tree-sitter
  'regex',
}

return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  -- 'main' no soporta carga diferida.
  lazy = false,
  build = ':TSUpdate',
  config = function()
    local ts = require('nvim-treesitter')

    ts.setup({
      -- Fuera del repo: son binarios de esta máquina.
      install_dir = vim.fn.stdpath('data') .. '/site',
    })

    -- Asíncrona: no bloquea el arranque.
    ts.install(PARSERS)

    -- En 'main' el resaltado se prende por buffer con vim.treesitter.start().
    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('treesitter-arranque', { clear = true }),
      callback = function(ev)
        local ft = vim.bo[ev.buf].filetype
        -- get_lang traduce el filetype al parser ('sh' → 'bash', 'yaml.docker-compose'
        -- → 'yaml').
        local lang = vim.treesitter.language.get_lang(ft)
        if not lang then
          return
        end
        -- pcall: sin el parser instalado, start() lanza y abortaría el FileType.
        if not pcall(vim.treesitter.start, ev.buf, lang) then
          return
        end
        -- Experimental en 'main'.
        vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
