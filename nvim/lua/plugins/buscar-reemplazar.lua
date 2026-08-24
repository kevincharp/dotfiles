-- ============================================================================
-- buscar-reemplazar.lua — buscar y reemplazar en TODO el proyecto (grug-far)
-- ============================================================================
-- Es el panel "Search & Replace" de VSCode (Ctrl+Shift+H): escribís qué buscar y
-- con qué reemplazar, ves los resultados de todos los archivos en vivo, y aplicás
-- el cambio a todo de una. Lo que faltaba: el picker de snacks BUSCA (<leader>fg)
-- pero no reemplaza, y el `:%s/.../.../` de vim es por archivo.
--
-- No es un buffer raro: es un buffer NORMAL de nvim. Escribís en los campos con
-- las teclas de siempre y los resultados se refrescan mientras tipeás (usa el
-- ripgrep que ya instala el bootstrap).
--
-- Atajos:
--   <leader>fR   abrir el panel (en modo visual, prefijado con la selección)
--   <leader>fW   abrir el panel buscando la palabra bajo el cursor
-- Dentro del panel manda el LÍDER LOCAL (que ahora es \, ver init.lua):
--   \r  aplicar el reemplazo       \s  sincronizar los cambios hechos a mano
--   \q  mandar los resultados a la quickfix    \c  cerrar el panel
--   g?  ayuda con la lista completa de atajos del panel
-- (Esos \ son la prueba de por qué había que sacar el líder local del espacio:
--  con maplocalleader = ' ', \s habría sido <space>s, o sea el prefijo del grupo
--  "buscar" de which-key.)
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
