-- ============================================================================
-- which-key.lua — menú de atajos (aparece al apretar el líder)
-- ============================================================================
-- Al apretar <espacio> (líder) y esperar, muestra un popup con los atajos
-- disponibles y su descripción. Es la mejor forma de APRENDER los atajos
-- nativos sin memorizarlos: vas viendo qué hay a medida que tipeás.
--
-- Lee las descripciones (desc = ...) que definimos en cada map. Por eso vale la
-- pena poner desc en español en todos los atajos: which-key los muestra ahí.
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
      { '<leader>h', group = 'git (hunks)' },
      { '<leader>t', group = 'terminal' },
      { '<leader>c', group = 'código (LSP)' },
      { '<leader>r', group = 'renombrar (LSP)' },
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
