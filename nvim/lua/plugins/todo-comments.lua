-- ============================================================================
-- todo-comments.lua — resaltar y listar los TODO / FIXME / HACK del código
-- ============================================================================
-- Es la extensión "Todo Tree" de VSCode: resalta las palabras clave de los
-- comentarios con su color e ícono (TODO azul, FIXME rojo, HACK naranja, NOTE
-- verde, PERF, WARN) y sabe listarlas todas juntas.
--
-- Encaja bien con este repo en particular: los comentarios largos que documentan
-- decisiones y deuda técnica son la norma, y hasta ahora encontrar los pendientes
-- era grepear a mano.
--
-- Atajos (en el grupo <leader>s, "buscar (símbolos y editor)"):
--   <leader>st   listar TODOS los pendientes del proyecto en el picker
--   <leader>sT   listar solo los que importan de verdad (TODO / FIX / FIXME)
--
-- Los dos van al picker de snacks por grep, NO al :TodoTelescope que sugiere el
-- README: Telescope no está instalado en esta config (el picker es snacks) y
-- snacks todavía no trae una fuente 'todo_comments' propia (verificado: no está
-- entre sus sources). Lo que se le pasa al grep es el patrón que arma el PROPIO
-- plugin, así que si algún día se agrega una palabra clave, los atajos la
-- encuentran sin tocar nada acá.
--
-- Deliberadamente NO se mapean ]t / [t para saltar al siguiente pendiente, que es
-- lo que sugiere el README del plugin: ]t y [t YA son nativos de nvim (:tnext /
-- :tprevious, navegar la tag list). Pisarlos va contra la regla de que los
-- nativos ganan, y para recorrer los pendientes el picker alcanza.
-- ============================================================================

-- Busca los pendientes con el grep del picker de snacks.
--
-- El patrón NO se escribe a mano acá: lo arma el propio plugin con
-- config.search_regex(), el MISMO que usa para resaltar. Así la lista y el
-- resaltado nunca se contradicen (p. ej. `WARN(x):` se resalta distinto que
-- `WARN:`, y con un patrón propio la lista mostraría cosas que no están
-- pintadas). Sin argumento devuelve las 20 palabras clave con sus alias
-- (TODO, FIXME, BUG, XXX…); con una lista, solo esas.
--
-- El vim.schedule NO es decorativo: el setup del plugin es DIFERIDO (verificado,
-- config.search_regex es nil en el mismo tick en que lazy.nvim lo carga y recién
-- aparece en el siguiente). Como estos atajos son justamente lo que dispara esa
-- carga, sin el schedule la primera pulsación reventaría con "attempt to call a
-- nil value".
local function buscar_pendientes(palabras)
  vim.schedule(function()
    local cfg = require('todo-comments.config')
    Snacks.picker.grep({
      search = cfg.search_regex(palabras),
      regex = true,
      live = false, -- búsqueda fija: el patrón ya está armado, no se tipea
      title = palabras and 'Pendientes importantes' or 'Pendientes',
    })
  end)
end

return {
  'folke/todo-comments.nvim',
  event = { 'BufReadPost', 'BufNewFile' },
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = {
    {
      '<leader>st',
      function() buscar_pendientes() end,
      desc = 'Pendientes del proyecto (TODO, FIXME…)',
    },
    {
      '<leader>sT',
      function() buscar_pendientes({ 'TODO', 'FIX', 'FIXME' }) end,
      desc = 'Pendientes importantes (TODO / FIX / FIXME)',
    },
  },
  opts = {
    -- Sin signos en la columna izquierda: esa columna ya la comparten los
    -- diagnósticos del LSP y las marcas de git (signcolumn = 'yes:2'), y un
    -- tercer inquilino la desborda. El resaltado del comentario ya se ve.
    signs = false,
    highlight = {
      -- Resaltar solo la palabra clave, no el comentario entero: los comentarios
      -- de este repo son párrafos, y pintarlos completos sería ilegible.
      keyword = 'wide_fg',
      after = '',
    },
  },
}
