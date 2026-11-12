-- ============================================================================
-- which-key.lua — menú de atajos (aparece al apretar el líder)
-- ============================================================================

return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  opts = {
    preset = 'helix',
    -- Mismo valor que timeoutlen (opciones.lua).
    delay = 400,
    icons = {
      mappings = vim.g.have_nerd_font,
    },
    spec = {
      { '<leader>f', group = 'buscar (archivos y texto)' },
      { '<leader>s', group = 'buscar (símbolos y editor)' },
      { '<leader>g', group = 'git' },
      { '<leader>h', group = 'git (hunks)' },
      { '<leader>b', group = 'buffers (pestañas)' },
      { '<leader>p', group = 'proyecto (sesiones)' },
      { '<leader>t', group = 'terminal' },
      { '<leader>c', group = 'código (LSP y formateo)' },
      { '<leader>u', group = 'alternar (toggles)' },
    },
  },
  keys = {
    {
      '<leader>?',
      function()
        require('which-key').show({ global = false })
      end,
      desc = 'Ver atajos del buffer',
    },
  },
}
