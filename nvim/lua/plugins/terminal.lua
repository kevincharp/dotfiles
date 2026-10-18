-- ============================================================================
-- terminal.lua — terminal integrada dentro del editor (toggleterm)
-- ============================================================================
-- <C-\> abre/cierra; <leader>tf flotante, <leader>th horizontal.
-- <Esc><Esc> sale del modo terminal para volver a mover el cursor por nvim.
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
    -- Tecla para abrir/cerrar. Funciona también estando dentro de la terminal.
    open_mapping = [[<C-\>]],
    direction = 'horizontal', -- por defecto abajo, como el panel de VSCode
    size = 15,                -- alto en líneas cuando es horizontal
    shade_terminals = true,   -- oscurecer levemente el fondo de la terminal
    float_opts = { border = 'curved' }, -- borde redondeado en modo flotante
    -- Al entrar a la terminal, arrancar en modo insert (podés tipear directo).
    start_in_insert = true,
  },
  config = function(_, opts)
    require('toggleterm').setup(opts)
    -- Salir del modo terminal con <Esc><Esc> para volver a navegar por nvim.
    vim.api.nvim_create_autocmd('TermOpen', {
      pattern = 'term://*',
      callback = function()
        vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n>]], { buffer = 0, desc = 'Salir del modo terminal' })
      end,
    })
  end,
}
