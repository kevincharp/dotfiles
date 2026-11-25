-- ============================================================================
-- todo-comments.lua — resaltar y listar TODO / FIXME / HACK
-- ============================================================================
-- Sin ]t / [t: son nativos (tag list).
-- ============================================================================

-- El patrón lo arma el plugin para que lista y resaltado coincidan. vim.schedule: el
-- setup del plugin es diferido y sin él la primera pulsación falla.
local function search_todos(keywords)
  vim.schedule(function()
    local cfg = require('todo-comments.config')
    Snacks.picker.grep({
      search = cfg.search_regex(keywords),
      regex = true,
      live = false, -- el patrón ya está armado
      title = keywords and 'Pendientes importantes' or 'Pendientes',
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
      function() search_todos() end,
      desc = 'Pendientes del proyecto (TODO, FIXME…)',
    },
    {
      '<leader>sT',
      function() search_todos({ 'TODO', 'FIX', 'FIXME' }) end,
      desc = 'Pendientes importantes (TODO / FIX / FIXME)',
    },
  },
  opts = {
    -- Sin signos: la columna ya la comparten git y los diagnósticos.
    signs = false,
    highlight = {
      -- Solo la palabra clave, no el comentario entero.
      keyword = 'wide_fg',
      after = '',
    },
  },
}
