-- ============================================================================
-- sesiones.lua — retomar el proyecto donde lo dejaste (persistence.nvim)
-- ============================================================================
-- Guarda una sesión por directorio al salir; restaurar es manual a propósito.
-- <leader>p: s restaura la de este directorio, l la última, p elige, d no guarda.
-- Es <leader>p y no <leader>q: ese ya es 'cerrar ventana' y un atajo suelto bloquea su prefijo.
-- ============================================================================

return {
  'folke/persistence.nvim',
  -- Carga al abrir el primer archivo real: ahí engancha su VimLeavePre para
  -- guardar. Con VeryLazy alcanzaba, pero BufReadPre evita crear sesión cuando
  -- nvim se abrió y cerró sin tocar nada.
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
    -- Una sesión por directorio Y POR RAMA de git. Es lo que uno quiere trabajando
    -- con ramas: los archivos de una feature no son los de main.
    branch = true,
  },
  init = function()
    -- sessionoptions (nativa de vim): se QUITAN 'blank' y 'terminal' (restaurar una
    -- terminal deja un shell muerto) y se AGREGAN 'globals' y 'skiprtp' (el runtimepath
    -- lo administra lazy.nvim y guardarlo rompe la restauración en otra máquina).
    vim.o.sessionoptions = 'buffers,curdir,folds,globals,help,skiprtp,tabpages,winsize'
  end,
}
