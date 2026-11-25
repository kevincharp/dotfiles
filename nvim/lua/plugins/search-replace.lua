-- ============================================================================
-- buscar-reemplazar.lua — buscar y reemplazar en todo el proyecto (grug-far)
-- ============================================================================
-- Dentro del panel manda el líder local: \r aplicar, \s sincronizar, \q a la quickfix,
-- \c cerrar, g? ayuda.
-- ============================================================================

return {
  'MagicDuck/grug-far.nvim',
  cmd = { 'GrugFar', 'GrugFarWithin' },
  keys = {
    {
      '<leader>fR',
      function() require('grug-far').open() end,
      desc = 'Buscar y reemplazar en el proyecto',
    },
    {
      '<leader>fR',
      function() require('grug-far').with_visual_selection() end,
      mode = 'x',
      desc = 'Buscar y reemplazar (con la selección)',
    },
    {
      '<leader>fW',
      function() require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') } }) end,
      desc = 'Buscar y reemplazar la palabra bajo el cursor',
    },
  },
  opts = {
    windowCreationCommand = 'vsplit',
    -- --hidden para buscar en .github/ y similares; el .gitignore se respeta.
    engines = {
      ripgrep = { extraArgs = '--hidden' },
    },
  },
}
