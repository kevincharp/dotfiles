-- ============================================================================
-- which-key.lua — menú de atajos (aparece al apretar el líder)
-- ============================================================================
-- Muestra los atajos disponibles con su desc (en español en cada map).
-- ============================================================================

return {
  'folke/which-key.nvim',
  event = 'VeryLazy', -- carga tras el arranque (no bloquea el inicio)
  opts = {
    -- 'helix' = estilo moderno: popup centrado abajo, prolijo. (Otros: 'classic'.)
    preset = 'helix',
    -- Retraso antes de mostrar el popup (ms). Coincide con timeoutlen de opciones.lua.
    delay = 400,
    icons = {
      -- Usar glifos de Nerd Font en el menú (ya la tenés instalada).
      mappings = vim.g.have_nerd_font,
    },
    -- Nombres de los grupos de atajos (los prefijos con líder). Así el popup
    -- muestra "+ git (hunks)" en vez de teclas sueltas sin contexto.
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
