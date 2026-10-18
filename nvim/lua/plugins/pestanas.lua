-- ============================================================================
-- pestanas.lua — pestañas de archivos abiertos (bufferline)
-- ============================================================================
-- Un tab por buffer, con ícono, estado y errores del LSP (look de VSCode).
-- ]b / [b redefinen los nativos para seguir el orden visual; <leader>1..9 va a la
-- pestaña N; <leader>bd cerrar, bo cerrar otras, bp fijar, b< / b> mover.
-- Sin Shift+H/L (pisan nativos) ni Ctrl+PageUp/Down (los toma la terminal).
-- ============================================================================

return {
  'akinsho/bufferline.nvim',
  event = 'VeryLazy',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  keys = {
    { ']b', '<cmd>BufferLineCycleNext<CR>', desc = 'Pestaña siguiente' },
    { '[b', '<cmd>BufferLineCyclePrev<CR>', desc = 'Pestaña anterior' },
    { '<leader>bd', function() Snacks.bufdelete() end, desc = 'Cerrar pestaña (sin cerrar la ventana)' },
    { '<leader>bo', function() Snacks.bufdelete.other() end, desc = 'Cerrar las otras pestañas' },
    { '<leader>bp', '<cmd>BufferLineTogglePin<CR>', desc = 'Fijar / soltar la pestaña' },
    { '<leader>b>', '<cmd>BufferLineMoveNext<CR>', desc = 'Mover la pestaña a la derecha' },
    { '<leader>b<', '<cmd>BufferLineMovePrev<CR>', desc = 'Mover la pestaña a la izquierda' },
  },
  opts = {
    options = {
      -- 'buffers' = un tab por archivo abierto (lo de VSCode). El otro modo,
      -- 'tabs', usa las tabpages de vim, que son grupos de ventanas: otra cosa.
      mode = 'buffers',
      -- Errores/avisos del LSP dentro del tab, como los puntitos de VSCode.
      diagnostics = 'nvim_lsp',
      diagnostics_indicator = function(_, _, diag)
        local iconos = { error = '󰅚 ', warning = '󰀪 ' }
        local partes = {}
        if diag.error then table.insert(partes, iconos.error .. diag.error) end
        if diag.warning then table.insert(partes, iconos.warning .. diag.warning) end
        return table.concat(partes, ' ')
      end,
      -- La X para cerrar con el mouse tiene que borrar el buffer sin tocar el
      -- layout (mismo motivo que <leader>bd).
      close_command = function(n) Snacks.bufdelete(n) end,
      right_mouse_command = function(n) Snacks.bufdelete(n) end,
      -- Corre la barra a la derecha mientras el explorador está abierto, para que
      -- las pestañas no queden montadas encima de él. El filetype es el de la
      -- lista del picker de snacks (el explorador ES un picker, ver snacks.lua).
      offsets = {
        {
          filetype = 'snacks_picker_list',
          text = 'Explorador',
          highlight = 'Directory',
          separator = true,
        },
      },
      separator_style = 'thin',
      show_buffer_close_icons = true,
      show_close_icon = false,       -- la X global de "cerrar todo" no hace falta
      always_show_bufferline = true, -- mostrar la barra aun con un solo archivo
      -- Un archivo nuevo se abre JUSTO A LA DERECHA del actual, no al final de la
      -- fila: así "ir a la definición" en otro archivo lo deja al lado del que
      -- venías leyendo. Es el orden que usa VSCode.
      sort_by = 'insert_after_current',
    },
  },
  config = function(_, opts)
    require('bufferline').setup(opts)
    -- Ir directo a la pestaña N. Se generan en el bucle para no repetir 9 líneas
    -- iguales; van acá y no en `keys` porque son mapeos triviales y el plugin ya
    -- está cargado en este punto.
    for i = 1, 9 do
      vim.keymap.set('n', '<leader>' .. i, function()
        require('bufferline').go_to(i, true)
      end, { desc = 'Ir a la pestaña ' .. i })
    end
  end,
}
