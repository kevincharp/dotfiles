-- ============================================================================
-- pestanas.lua — pestañas de archivos abiertos (bufferline)
-- ============================================================================
-- ]b / [b redefinen los nativos para seguir el orden visual. Sin Shift+H/L (pisan
-- nativos) ni Ctrl+PageUp/Down (los toma la terminal).
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
      mode = 'buffers',
      diagnostics = 'nvim_lsp',
      diagnostics_indicator = function(_, _, diag)
        local iconos = { error = '󰅚 ', warning = '󰀪 ' }
        local partes = {}
        if diag.error then table.insert(partes, iconos.error .. diag.error) end
        if diag.warning then table.insert(partes, iconos.warning .. diag.warning) end
        return table.concat(partes, ' ')
      end,
      -- Borra el buffer sin tocar el layout de ventanas.
      close_command = function(n) Snacks.bufdelete(n) end,
      right_mouse_command = function(n) Snacks.bufdelete(n) end,
      -- Deja libre el ancho del explorador (su filetype es el de la lista del picker).
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
      show_close_icon = false,
      always_show_bufferline = true,
      -- Un archivo nuevo se abre a la derecha del actual, como en VSCode.
      sort_by = 'insert_after_current',
    },
  },
  config = function(_, opts)
    require('bufferline').setup(opts)
    for i = 1, 9 do
      vim.keymap.set('n', '<leader>' .. i, function()
        require('bufferline').go_to(i, true)
      end, { desc = 'Ir a la pestaña ' .. i })
    end
  end,
}
