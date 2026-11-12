-- ============================================================================
-- contexto.lua — sticky scroll: la función en la que estás, fija arriba
-- ============================================================================
-- Muestra las líneas que abren el bloque actual. Sin [c: es nativo (diff).
-- ============================================================================

return {
  'nvim-treesitter/nvim-treesitter-context',
  event = { 'BufReadPost', 'BufNewFile' },
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  keys = {
    {
      '<leader>uc',
      function() require('treesitter-context').toggle() end,
      desc = 'Alternar contexto fijo (sticky scroll)',
    },
  },
  opts = {
    max_lines = 3,
    min_window_height = 20,
    separator = '─',
    mode = 'cursor',
  },
}
