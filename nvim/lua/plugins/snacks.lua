-- ============================================================================
-- snacks.lua — módulos de folke (explorador, pickers, ayudas visuales)
-- ============================================================================
-- Apagados: image (Ptyxis no soporta el protocolo kitty), dashboard, notifier, zen,
-- dim. Dentro del árbol: a crear, d borrar, r renombrar, m mover, c/p copiar/pegar, ?
-- ayuda.
-- ============================================================================

return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  opts = {
    explorer = {
      enabled = true,
    },
    picker = {
      enabled = true,
      sources = {
        explorer = {
          -- position y width son del layout: puestos directo en la source, snacks los
          -- ignora.
          layout = { layout = { position = 'left', width = 32, min_width = 32 } },
          -- Ocultos e ignorados a la vista (dotfiles), salvo las carpetas pesadas. H e
          -- I alternan.
          hidden = true,
          ignored = true,
          exclude = { 'node_modules', '.git', '__pycache__', '.venv', '.mypy_cache' },
          follow_file = true,
        },
      },
    },
    input = {
      enabled = true,
    },

    indent = {
      enabled = true,
      scope = { enabled = true }, -- resalta el bloque actual
    },

    -- Resalta las apariciones del símbolo bajo el cursor (vía LSP); ]] y [[ saltan
    -- entre ellas.
    words = {
      enabled = true,
    },

    -- Número, signo de git, diagnóstico y plegado en una sola columna.
    statuscolumn = {
      enabled = true,
    },

    scroll = {
      enabled = true,
    },
  },
  keys = {
    { '<leader>e', function() Snacks.explorer() end, desc = 'Explorador de archivos (toggle)' },

    -- Mezcla abiertos, recientes y del proyecto, por frecuencia de uso.
    { '<leader><space>', function() Snacks.picker.smart() end, desc = 'Buscar archivo (inteligente)' },

    { '<leader>ff', function() Snacks.picker.files() end, desc = 'Buscar: archivos' },
    { '<leader>fg', function() Snacks.picker.grep() end, desc = 'Buscar: texto en el proyecto (grep)' },
    { '<leader>fb', function() Snacks.picker.buffers() end, desc = 'Buscar: buffers abiertos' },
    { '<leader>fr', function() Snacks.picker.recent() end, desc = 'Buscar: archivos recientes' },
    { '<leader>fl', function() Snacks.picker.lines() end, desc = 'Buscar: líneas del archivo actual' },
    { '<leader>fw', function() Snacks.picker.grep_word() end, desc = 'Buscar: palabra bajo el cursor', mode = { 'n', 'x' } },

    { '<leader>ss', function() Snacks.picker.lsp_symbols({ tree = true }) end, desc = 'Símbolos del archivo (outline)' },
    { '<leader>sS', function() Snacks.picker.lsp_workspace_symbols() end, desc = 'Símbolos de todo el proyecto' },
    { '<leader>sd', function() Snacks.picker.diagnostics() end, desc = 'Lista de errores del proyecto' },
    { '<leader>sk', function() Snacks.picker.keymaps() end, desc = 'Atajos de teclado' },
    { '<leader>sh', function() Snacks.picker.help() end, desc = 'Ayuda de nvim (:help)' },

    { '<leader>gg', function() Snacks.lazygit() end, desc = 'lazygit (git completo)' },
  },
}
