-- ============================================================================
-- sesiones.lua — retomar el proyecto donde lo dejaste (persistence.nvim)
-- ============================================================================
-- Guarda una sesión por directorio al salir; restaurar es manual. <leader>p y no
-- <leader>q, que ya es "cerrar ventana".
-- ============================================================================

return {
  'folke/persistence.nvim',
  -- BufReadPre: no crea sesión si nvim se abrió y cerró sin tocar nada.
  event = 'BufReadPre',
  keys = {
    {
      '<leader>ps',
      function() require('persistence').load() end,
      desc = 'Restaurar la sesión de este directorio',
    },
    {
      '<leader>pl',
      function() require('persistence').load({ last = true }) end,
      desc = 'Restaurar la última sesión',
    },
    {
      '<leader>pp',
      function() require('persistence').select() end,
      desc = 'Elegir una sesión de la lista',
    },
    {
      '<leader>pd',
      function() require('persistence').stop() end,
      desc = 'No guardar la sesión de esta salida',
    },
  },
  opts = {
    -- Una sesión por rama de git.
    branch = true,
  },
  init = function()
    -- Sin 'blank' ni 'terminal' (restauraría un shell muerto); 'skiprtp' porque el
    -- runtimepath lo administra lazy.nvim.
    vim.o.sessionoptions = 'buffers,curdir,folds,globals,help,skiprtp,tabpages,winsize'
  end,
}
