-- ============================================================================
-- terminal.lua — terminal integrada dentro del editor (toggleterm)
-- ============================================================================

return {
  'akinsho/toggleterm.nvim',
  version = '*',
  cmd = { 'ToggleTerm', 'TermExec' },
  keys = {
    { '<C-\\>', desc = 'Terminal (toggle)' },
    { '<leader>tf', '<cmd>ToggleTerm direction=float<CR>', desc = 'Terminal flotante' },
    { '<leader>th', '<cmd>ToggleTerm direction=horizontal<CR>', desc = 'Terminal horizontal (abajo)' },
  },
  opts = {
    -- Funciona también desde dentro de la terminal.
    open_mapping = [[<C-\>]],
    direction = 'horizontal',
    size = 15,
    shade_terminals = true,
    float_opts = { border = 'curved' },
    start_in_insert = true,
  },
  config = function(_, opts)
    require('toggleterm').setup(opts)
    vim.api.nvim_create_autocmd('TermOpen', {
      pattern = 'term://*',
      callback = function()
        vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n>]], { buffer = 0, desc = 'Salir del modo terminal' })
      end,
    })
  end,
}
