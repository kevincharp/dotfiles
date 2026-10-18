-- ============================================================================
-- todo-comments.lua — resaltar y listar TODO / FIXME / HACK
-- ============================================================================
-- <leader>st lista todos los pendientes en el picker de snacks; <leader>sT solo
-- TODO / FIX / FIXME. Sin ]t / [t: son nativos (tag list) y los nativos ganan.
-- ============================================================================

-- Busca los pendientes con el grep del picker de snacks. El patrón lo arma el
-- plugin (config.search_regex) para que lista y resaltado coincidan. El
-- vim.schedule es necesario: el setup del plugin es diferido y sin él la primera
-- pulsación falla con "attempt to call a nil value".
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
