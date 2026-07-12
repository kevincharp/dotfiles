-- ============================================================================
-- terminal.lua — terminal integrada dentro del editor (toggleterm)
-- ============================================================================
-- El panel de terminal de VSCode (Ctrl+`): abre una terminal SIN salir de nvim.
-- Se abre/cierra con el mismo atajo (toggle) y recuerda su contenido entre togglers.
--
-- Atajos:
--   <C-\>          abrir/cerrar la terminal (toggle) — en cualquier modo
--   <leader>tf     terminal FLOTANTE (ventana centrada, tipo popup)
--   <leader>th     terminal HORIZONTAL (abajo, como el panel de VSCode)
--   <Esc><Esc>     salir del modo terminal (volver a normal para navegar)
--
-- Nota: dentro de la terminal, el teclado va a la shell. Para volver a mover el
-- cursor por nvim, salí del modo insert de la terminal con <Esc><Esc>.
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
