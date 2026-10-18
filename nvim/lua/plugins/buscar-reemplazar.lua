-- ============================================================================
-- buscar-reemplazar.lua — buscar y reemplazar en todo el proyecto (grug-far)
-- ============================================================================
-- <leader>fR abre el panel (en visual, con la selección); <leader>fW busca la
-- palabra bajo el cursor. Dentro manda el líder local \: \r aplicar, \s sincronizar,
-- \q a la quickfix, \c cerrar, g? ayuda. Por eso maplocalleader no es el espacio.
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
    -- Abrir en un split vertical a la derecha, como el panel de VSCode, en vez de
    -- robarse la ventana actual.
    windowCreationCommand = 'vsplit',
    -- Flags por defecto de ripgrep: --hidden para que encuentre en .github/ y
    -- similares (ripgrep los saltea por defecto). NO se agrega --no-ignore: el
    -- .gitignore se respeta a propósito, para no reemplazar dentro de
    -- node_modules ni de builds.
    engines = {
      ripgrep = { extraArgs = '--hidden' },
    },
  },
}
